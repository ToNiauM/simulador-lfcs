# Contrato de provedores LLM v1

LLMs são opcionais e intercambiáveis. Eles recebem o enunciado, o resultado JSON do checker e a solicitação de feedback; retornam texto para o candidato. Nunca recebem autoridade para atribuir nota, executar comandos na VM ou alterar task packs.

Cada provedor implementa `generate(messages, model, timeout_seconds) -> {text, model, provider}`.

Os adaptadores incluídos cobrem APIs compatíveis com OpenAI (`/v1/chat/completions`), Anthropic Messages e um gateway `http-json`. Esse gateway aceita o pedido canônico `{"model":"...","messages":[...]}` e deve retornar `{"text":"..."}`; portanto permite qualquer LLM por trás de uma API própria. Há ainda um adaptador de comando para clientes locais. Variáveis de ambiente guardam segredos; nenhuma chave entra em relatório, prompt ou Git.

Configuração mínima:

```bash
# OpenAI, Ollama, vLLM, LiteLLM e APIs compatíveis
export LFCS_LLM_PROVIDER=openai-compatible
export LFCS_LLM_BASE_URL=https://servidor.exemplo/v1
export LFCS_LLM_API_KEY=...

# Qualquer API, com um gateway fino que converta para/de o contrato canônico
export LFCS_LLM_PROVIDER=http-json
export LFCS_LLM_URL=https://gateway.exemplo/generate
export LFCS_LLM_HEADERS_JSON='{"Authorization":"Bearer ..."}'
```
