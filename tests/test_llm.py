import json
import unittest
from unittest.mock import patch

from lfcs_simulator.llm import anthropic, http_json, openai_compatible


class Response:
    def __init__(self, payload): self.payload = payload
    def read(self): return json.dumps(self.payload).encode()
    def __enter__(self): return self
    def __exit__(self, *_): return False


class ProviderTests(unittest.TestCase):
    @patch("urllib.request.urlopen")
    def test_openai_compatible(self, request):
        request.return_value = Response({"choices": [{"message": {"content": "ok"}}]})
        response = openai_compatible([{"role": "user", "content": "x"}], "model", 1, "https://example.test/v1", "key")
        self.assertEqual(response.text, "ok")
        self.assertEqual(response.provider, "openai-compatible")

    @patch("urllib.request.urlopen")
    def test_anthropic(self, request):
        request.return_value = Response({"content": [{"type": "text", "text": "ok"}]})
        response = anthropic([{"role": "user", "content": "x"}], "model", 1, "https://example.test", "key")
        self.assertEqual(response.text, "ok")

    @patch("urllib.request.urlopen")
    def test_http_json_gateway(self, request):
        request.return_value = Response({"text": "ok", "provider": "my-api"})
        response = http_json([{"role": "user", "content": "x"}], "model", 1, "https://example.test/generate", {"X-Key": "key"})
        self.assertEqual((response.text, response.provider), ("ok", "my-api"))


if __name__ == "__main__":
    unittest.main()
