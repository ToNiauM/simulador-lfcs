# Simulador LFCS

Simulador de provas práticas para a certificação **Linux Foundation Certified System Administrator (LFCS)**. Tarefas determinísticas rodam em VM Linux descartável e são corrigidas pelo estado final do sistema. Os enunciados são em inglês, no formato do exame real.

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
| Banco de 101 tarefas nos 5 domínios | Pronto (validação estrutural; e2e em VM pendente) |
| Gerador determinístico por seed | Pronto |
| Checker JSON e regressão do pack | Pronto |
| Adaptadores LLM | Prontos |
| Orquestrador KVM/libvirt | Próxima etapa |

## Banco de tarefas

101 task packs distribuídos conforme os pesos oficiais do exame:

| Domínio | Tarefas | Peso no LFCS |
| --- | --- | --- |
| `operations-deployment` | 25 | 25% |
| `networking` | 25 | 25% |
| `storage` | 21 | 20% |
| `essential-commands` | 20 | 20% |
| `users-groups` | 10 | 10% |

Enunciados em inglês no estilo da prova ("Task: …", imperativo, "must persist across reboots"). Cada pack varia por seed (nomes, tamanhos, portas, IPs de redes de documentação) e o checker aceita qualquer solução válida, não apenas a de referência. Regras de segurança do conteúdo: Storage só toca `/dev/vdb`; Networking nunca altera a NIC primária nem a rota default; nenhum script depende de Internet — ferramentas como `nginx`, `podman` e `mdadm` devem estar pré-instaladas na imagem do guest (ver `requires` no `meta.yaml` de cada pack).

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

## Testando um pack em VM descartável

Os packs de Storage usam exclusivamente `/dev/vdb` como disco de dados. Execute os testes apenas em uma VM com os pacotes listados em `requires` instalados. Exemplo com o pack LVM:

```bash
export LFCS_GUEST_LAB=1
tasks/storage/lvm-persistent-mount/tests/e2e-in-guest.sh prepare
reboot
tasks/storage/lvm-persistent-mount/tests/e2e-in-guest.sh verify
```

`prepare` prova que o checker falha em estado limpo e aplica a solução de referência. Após o reboot real, `verify` exige nota máxima. Todo pack do banco tem o mesmo par `prepare`/`verify`; o pack LVM já passou por esse ciclo completo, e a execução em lote dos demais depende do orquestrador (roadmap).

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
2. Seleção de 17–20 tarefas ponderadas por domínio LFCS (ou filtro por temática).
3. Relatório consolidado e modo de simulado completo.
4. Prova e2e (falha limpa → solve → reboot → nota máxima) de todo o banco em guests efêmeros, com CI.

## Contribuindo

Contribuições são bem-vindas. Valide o pack alterado e execute os testes antes do pull request. Tarefas novas precisam incluir checker e prova automatizada de falha/passagem.

## Licença

Distribuído sob a [Licença MIT](LICENSE). Você pode usar, modificar e redistribuir o projeto, inclusive comercialmente, preservando o aviso de copyright e licença.

## Resumo operacional

Do primeiro ao último comando, um ciclo completo de questão. Precisa de: uma VM descartável Ubuntu com segundo disco `/dev/vdb`, acesso SSH como root, e os pacotes do `requires` do pack instalados.

```bash
# Clonar o repositório no host
git clone https://github.com/ToNiauM/simulador-lfcs.git
# Entrar no diretório do projeto
cd simulador-lfcs
# Validar o pack escolhido
./bin/validate-task-pack tasks/storage/lvm-persistent-mount
# Gerar os parâmetros da tentativa (o seed define a variante)
./bin/render-task tasks/storage/lvm-persistent-mount tentativa-01 /tmp/lfcs-task.json
# Copiar o pack para a VM descartável
scp -r tasks/storage/lvm-persistent-mount root@IP-DA-VM:/root/pack
# Copiar os parâmetros para a VM
scp /tmp/lfcs-task.json root@IP-DA-VM:/root/lfcs-task.json
# Entrar na VM
ssh root@IP-DA-VM
# Habilitar o modo laboratório (na VM, como root)
export LFCS_GUEST_LAB=1
# Apontar a tarefa, o seed e os parâmetros
export LFCS_TASK_ID=storage/lvm-persistent-mount LFCS_SEED=tentativa-01 LFCS_PARAMS_FILE=/root/lfcs-task.json
# Preparar o cenário inicial da questão
/root/pack/setup.sh
# Ler o enunciado (substitua mentalmente os {{placeholders}} pelos valores do lfcs-task.json)
cat /root/pack/instructions.md.tmpl /root/lfcs-task.json
# >>> Resolver a tarefa você mesmo, como na prova <<<
# Reiniciar para provar que a configuração persiste
reboot
# Entrar de novo na VM após o boot
ssh root@IP-DA-VM
# Reexportar as variáveis da tentativa
export LFCS_GUEST_LAB=1 LFCS_TASK_ID=storage/lvm-persistent-mount LFCS_PARAMS_FILE=/root/lfcs-task.json
# Corrigir pelo estado final e gravar a nota
/root/pack/check.sh > /root/resultado.json
# Ver a nota por critério
cat /root/resultado.json
# Sair da VM
exit
# Copiar o resultado de volta para o host
scp root@IP-DA-VM:/root/resultado.json /tmp/resultado.json
# (Opcional) Configurar o provedor LLM para feedback
export LFCS_LLM_PROVIDER=anthropic LFCS_LLM_API_KEY='sua-chave'
# (Opcional) Gerar feedback pedagógico do resultado
./bin/llm-feedback /tmp/resultado.json tasks/storage/lvm-persistent-mount/instructions.md.tmpl claude-sonnet-5
# Destruir a VM descartável (exemplo com libvirt)
virsh destroy lfcs-vm ; virsh undefine lfcs-vm --remove-all-storage
```
