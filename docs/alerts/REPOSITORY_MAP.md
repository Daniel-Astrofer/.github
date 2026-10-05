<!--
Kerosene documentation metadata
status: review-required
audience: internal
owner: platform
source_of_truth: platform
last_reviewed: 2026-09-03
-->

# Mapa dos repositórios Kerosene

## Fluxo de responsabilidade

`clients` → `core/auth` → contratos remotos → `kfe` → `vault` → `node`/Bitcoin/Lightning

`deploy` provisiona e opera esses componentes. `contracts` define os formatos
interoperáveis. `shared` contém apenas código compartilhável aprovado entre
serviços. `admin` opera APIs administrativas e `rails` encapsula adaptadores
de infraestrutura.

O diagrama acima é uma direção lógica, não uma autorização para importar o
código de um serviço em outro. Comunicação entre processos deve ocorrer por
contratos de rede versionados e transporte autenticado.

## Checkouts e remotos observados em 2026-09-03

Todos os componentes ativos possuem um repositório Git independente e um
`origin` configurado. A branch local não é presumida como `main`: automações
devem usar o upstream da branch atual e bloquear quando ele não existir.

| Diretório | Origin | Branch local | Upstream observado |
| --- | --- | --- | --- |
| `.github` | `Daniel-Astrofer/.github` | `docs/secure-interservice-plan` | não configurado |
| `admin` | `Daniel-Astrofer/admin` | `main` | `origin/main` |
| `clients` | `Daniel-Astrofer/clients` | `main` | `origin/main` |
| `contracts` | `Daniel-Astrofer/contracts` | `main` | `origin/main` |
| `core` | `Daniel-Astrofer/core` | `main` | `origin/main` |
| `deploy` | `Daniel-Astrofer/deploy` | `fix/kfe-jwt-secret-property` | não configurado |
| `kfe` | `Daniel-Astrofer/kfe` | `main` | `origin/main` |
| `node` | `Daniel-Astrofer/node` | `refactor/clean-architecture` | não configurado |
| `rails` | `Daniel-Astrofer/rails` | `main` | `origin/main` |
| `shared` | `Daniel-Astrofer/shared` | `main` | `origin/main` |
| `vault` | `Daniel-Astrofer/vault` | `refactor/clean-architecture` | `origin/refactor/clean-architecture` |

Esta tabela registra configuração local, não afirma que uma branch foi
publicada, revisada ou sincronizada. Use
`deploy/infra/scripts/sync-polyrepo-workspace.sh --check` depois de configurar
os upstreams ausentes e somente com árvores limpas.

## Limites

| Serviço | Pode possuir | Não deve possuir |
| --- | --- | --- |
| Core | Auth, sessão, gateway e políticas | implementação KFE/Vault/Node |
| KFE | orquestração de execução/settlement | banco de identidade do Auth |
| Vault | custódia, assinatura e mesh | consenso do Node |
| Node | ledger, membership e consenso definido | chaves privadas do Vault |
| Deploy | manifests, imagens, secrets refs e runbooks | código-fonte copiado dos serviços |

## Itens que ainda não são capacidade pronta

O mapa descreve a separação estrutural, não declara prontidão de produção.
Contratos imutáveis, mTLS ponta a ponta, descoberta distribuída, decisão de
ownership do consenso, evidência criptográfica independente e um bootstrap de
fork limpo continuam sendo gates explícitos dos repositórios responsáveis.
