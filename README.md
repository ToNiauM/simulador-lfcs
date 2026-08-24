# Simulador LFCS

Simulador de provas práticas para a certificação **Linux Foundation Certified System Administrator (LFCS)**. Tarefas determinísticas rodam em VM Linux descartável e são corrigidas pelo estado final do sistema.

> O LLM é opcional: gera feedback pedagógico, mas não atribui nota nem executa comandos no laboratório.

## Princípios

- VM, não container: LVM, filesystem, `/etc/fstab`, systemd e boot requerem um SO completo.
- Variação determinística: um `seed` muda parâmetros sem comprometer a correção.
- Reboot obrigatório: configuração que não sobrevive ao reboot não pontua.
- Correção objetiva: checkers versionados retornam JSON por critério.
- LLM sem autoridade: APIs OpenAI-compatíveis, Anthropic ou gateway próprio apenas explicam o resultado.

## Estado atual

| Componente | Situação |
| --- | --- |
| Contrato e schemas de task pack | Pronto |
| Tarefa LVM + montagem persistente | Pronta |
| Gerador determinístico por seed | Pronto |
| Checker JSON e regressão do pack | Pronto |
| Adaptadores LLM | Prontos |
| Orquestrador KVM/libvirt | Próxima etapa |

## Estrutura

- `bin/`: validação, renderização e feedback LLM.
- `docs/`: contratos públicos do projeto.
- `lfcs_simulator/`: código Python compartilhado.
- `schemas/`: schemas para metadados e resultados.
- `tasks/`: banco de tarefas versionadas.
- `tests/`: testes do núcleo.

## Início rápido

Pré-requisitos: Python 3.11+, `PyYAML` e `jsonschema`.

```bash
git clone https://github.com/ToNiauM/simulador-lfcs.git
cd simulador-lfcs
./bin/validate-task-pack tasks/storage/lvm-persistent-mount
./bin/render-task tasks/storage/lvm-persistent-mount meu-seed /tmp/lfcs-task.json
python3 -m unittest discover -s tests -v
```

## Tarefa LVM em VM descartável

O primeiro pack usa exclusivamente `/dev/vdb` como disco de dados. Execute-o apenas em uma VM com `lvm2` instalado.

```bash
export LFCS_GUEST_LAB=1
tasks/storage/lvm-persistent-mount/tests/e2e-in-guest.sh prepare
reboot
tasks/storage/lvm-persistent-mount/tests/e2e-in-guest.sh verify
```

`prepare` prova que o checker falha em estado limpo e aplica a solução de referência. Após o reboot real, `verify` exige nota máxima.

## Feedback com qualquer LLM

Há adaptadores para OpenAI-compatível, Anthropic, gateway HTTP canônico e cliente de linha de comando. Veja o [contrato de provedores](docs/llm-provider-contract.md).

```bash
export LFCS_LLM_PROVIDER=openai-compatible
export LFCS_LLM_BASE_URL=https://api.exemplo.com/v1
export LFCS_LLM_API_KEY='sua-chave'
./bin/llm-feedback resultado.json enunciado.md nome-do-modelo
```

Não versione chaves: use variáveis de ambiente ou um gerenciador de segredos.

## Criando tarefas

Cada task pack possui `meta.yaml`, `setup.sh`, `solve.sh`, `check.sh`, enunciado e gerador de parâmetros. Leia o [contrato de task pack](docs/task-pack-contract.md). Toda tarefa nova deve falhar em estado limpo e passar depois da solução de referência seguida de reboot.

## Segurança

Setup e solução recusam execução fora de um guest marcado com `LFCS_GUEST_LAB=1`. Isso reduz acidentes, mas não substitui uma VM descartável: nunca rode packs de Storage no host.

## Roadmap

1. Orquestrador KVM/libvirt com cloud-init, snapshot e cronômetro.
2. Seleção de 17–20 tarefas ponderadas por domínio LFCS.
3. Relatório consolidado e modo de simulado completo.
4. Banco de tarefas ampliado e CI em guests efêmeros.

## Contribuindo

Contribuições são bem-vindas. Valide o pack alterado e execute os testes antes do pull request. Tarefas novas precisam incluir checker e prova automatizada de falha/passagem.

## Licença

Distribuído sob a [Licença MIT](LICENSE). Você pode usar, modificar e redistribuir o projeto, inclusive comercialmente, preservando o aviso de copyright e licença.
