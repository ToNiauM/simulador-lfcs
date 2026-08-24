# Contrato de task pack LFCS v1

Cada pacote é um diretório versionado em Git. O identificador do diretório e `meta.yaml.id` devem ser iguais. Todos os scripts executam na VM descartável; não podem depender de Internet, histórico de shell ou estado do host.

## Arquivos obrigatórios

| Arquivo | Responsabilidade |
| --- | --- |
| `meta.yaml` | Identidade, domínio, pontuação, requisitos e parâmetros. |
| `setup.sh` | Prepara o estado inicial da VM. |
| `solve.sh` | Solução de referência, usada somente para testar o pacote. |
| `check.sh` | Inspeciona apenas o estado final e escreve um JSON no stdout. |
| `instructions.md.tmpl` | Enunciado a renderizar para o candidato. |
| `generate_params.py` | Gera parâmetros determinísticos a partir do seed. |

O orquestrador fornece `LFCS_TASK_ID`, `LFCS_SEED`, `LFCS_PARAMS_FILE` (JSON absoluto) e `LFCS_GUEST_LAB=1`. Setup e solução devem recusar execução sem essa última variável. O checker não pode modificar o sistema avaliado.

`meta.yaml` obedece a `schemas/task-meta.schema.json`. Os domínios válidos são `operations-deployment`, `networking`, `storage`, `essential-commands` e `users-groups`.

## Resultado de `check.sh`

O stdout deve conter exatamente um JSON compatível com `schemas/check-result.schema.json`; diagnósticos vão para stderr. `result` só é `pass` quando todos os critérios obrigatórios passam. `score` é a soma de pontos observada e `max_score` a soma máxima.

## Prova obrigatória

Todo pacote tem um teste automatizado dentro de VM limpa:

1. `setup.sh` seguido de `check.sh` deve falhar;
2. `solve.sh`, reboot forçado pelo host, e depois `check.sh` deve passar.

Não se aceita configuração aplicada antes do reboot como prova de persistência.
