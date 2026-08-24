"""Small dependency-free LLM provider layer for post-exam feedback."""
from __future__ import annotations

import json
import os
import subprocess
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


class ProviderError(RuntimeError):
    pass


@dataclass(frozen=True)
class Completion:
    text: str
    provider: str
    model: str


def _post_json(url: str, headers: dict[str, str], body: dict[str, Any], timeout: int) -> dict[str, Any]:
    request = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", **headers}, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise ProviderError(f"LLM request failed: {exc}") from exc


def openai_compatible(messages: list[dict[str, str]], model: str, timeout: int, base_url: str, api_key: str) -> Completion:
    data = _post_json(base_url.rstrip("/") + "/chat/completions", {"Authorization": f"Bearer {api_key}"}, {"model": model, "messages": messages}, timeout)
    try:
        text = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ProviderError("OpenAI-compatible response has no choices[0].message.content") from exc
    return Completion(str(text), "openai-compatible", model)


def anthropic(messages: list[dict[str, str]], model: str, timeout: int, base_url: str, api_key: str) -> Completion:
    system = ""
    user_messages = []
    for message in messages:
        if message["role"] == "system":
            system += message["content"] + "\n"
        else:
            user_messages.append(message)
    data = _post_json(base_url.rstrip("/") + "/v1/messages", {"x-api-key": api_key, "anthropic-version": "2023-06-01"}, {"model": model, "max_tokens": 1000, "system": system, "messages": user_messages}, timeout)
    try:
        text = "".join(part["text"] for part in data["content"] if part["type"] == "text")
    except (KeyError, TypeError) as exc:
        raise ProviderError("Anthropic response has no text content") from exc
    return Completion(text, "anthropic", model)


def http_json(messages: list[dict[str, str]], model: str, timeout: int, url: str, headers: dict[str, str]) -> Completion:
    """Adapter for a small gateway in front of any non-standard LLM API."""
    data = _post_json(url, headers, {"model": model, "messages": messages}, timeout)
    if not isinstance(data.get("text"), str):
        raise ProviderError("http-json response has no string text field")
    return Completion(data["text"], str(data.get("provider", "http-json")), str(data.get("model", model)))


def command(messages: list[dict[str, str]], model: str, timeout: int, command_line: str) -> Completion:
    """Escape hatch: an arbitrary API client reads canonical JSON from stdin."""
    try:
        result = subprocess.run(command_line, shell=True, text=True, input=json.dumps({"model": model, "messages": messages}), capture_output=True, timeout=timeout, check=True)
        data = json.loads(result.stdout)
        return Completion(str(data["text"]), str(data.get("provider", "command")), str(data.get("model", model)))
    except (subprocess.SubprocessError, json.JSONDecodeError, KeyError) as exc:
        raise ProviderError(f"custom provider failed: {exc}") from exc


def generate(messages: list[dict[str, str]], model: str, timeout_seconds: int = 30) -> Completion:
    """Dispatch from environment; keys remain outside source, reports and prompts."""
    provider = os.environ.get("LFCS_LLM_PROVIDER", "openai-compatible")
    if provider == "openai-compatible":
        return openai_compatible(messages, model, timeout_seconds, os.environ["LFCS_LLM_BASE_URL"], os.environ["LFCS_LLM_API_KEY"])
    if provider == "anthropic":
        return anthropic(messages, model, timeout_seconds, os.environ.get("LFCS_LLM_BASE_URL", "https://api.anthropic.com"), os.environ["LFCS_LLM_API_KEY"])
    if provider == "http-json":
        try:
            headers = json.loads(os.environ.get("LFCS_LLM_HEADERS_JSON", "{}"))
        except json.JSONDecodeError as exc:
            raise ProviderError("LFCS_LLM_HEADERS_JSON must be JSON") from exc
        if not isinstance(headers, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in headers.items()):
            raise ProviderError("LFCS_LLM_HEADERS_JSON must be an object of string pairs")
        return http_json(messages, model, timeout_seconds, os.environ["LFCS_LLM_URL"], headers)
    if provider == "command":
        return command(messages, model, timeout_seconds, os.environ["LFCS_LLM_COMMAND"])
    raise ProviderError(f"unsupported LFCS_LLM_PROVIDER: {provider}")
