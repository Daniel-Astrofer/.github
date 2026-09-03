<!--
Kerosene documentation metadata
status: review-required
audience: internal
owner: .github
source_of_truth: .github
last_reviewed: 2026-09-03
-->

# Kerosene: arquitetura e comunicação entre serviços

Este documento descreve o estado observado nos repositórios polyrrepo. Ele é
o mapa operacional atual; quando houver diferença entre documentação antiga e
os manifests de deploy, os manifests e os testes de guardrail são a referência
até que a divergência seja corrigida.

## Repositórios e responsabilidades

| Repositório | Responsabilidade | Não deve fazer |
|---|---|---|
| `kerosene-contracts` | contratos versionados, schemas, vetores e tipos compartilhados | duplicar DTO/schema em outro repositório |
| `kerosene-core` | `auth-service`: identidade, sessão, notificações e gateway público | executar finanças ou custodiar shares FROST |
| `kerosene-kfe` | ledger, carteiras, reconciliação e execução financeira | possuir identidade, sessão ou código Vault |
| `kerosene-shared` | utilitários Java neutros usados por Auth e KFE | possuir regras de negócio ou protocolos externos |
| `kerosene-rails` | adapters de Bitcoin Core e LND | possuir Auth, KFE ou configuração de ambiente |
| `kerosene-admin` | clientes administrativos para operadores | acessar bancos diretamente ou assumir autoridade do servidor |
| `kerosene-vault` | nós da Vault Mesh, DKG, quorum, FROST, custody e identidade mTLS | receber secrets genéricos de infraestrutura ou depender de HashiCorp Vault |
| `kerosene-node` | descoberta/membership, roster e atestado do plano Vault | executar lógica financeira ou custodiar shares |
| `kerosene-clients` | aplicações Flutter e clientes | acessar Vault diretamente |
| `kerosene-deploy` | Docker, Kubernetes, políticas, overlays, observabilidade e runbooks | fabricar secrets reais ou ativar signer automaticamente |
| `.github` | workflows reutilizáveis, compatibilidade e política da organização | receber credenciais de produção |

## Fluxo de comunicação

```text
Cliente/Web
   │ HTTPS
   ▼
web-page / ingress
   ├── rotas de autenticação, sessão e API ──► server (auth-service)
   └── rotas /kfe/*                         ──► kfe-service

server (Auth) ◄──── HTTP interno ────► kfe-service
     │                                      │
     │                                      ├── Postgres / Redis
     │                                      ├── Bitcoin Core / LND
     │                                      ├── Kerosene Node (discovery/roster)
     │                                      └── HTTPS + mTLS + transporte Tor ──► Vault Mesh
     │                                                                                 │
     └──────── JWT/claims e diretório de usuário ──────────────────────────────────────┘

Vault Mesh (3 nós, quorum) ──► somente operações de custody/signing governadas
HashiCorp Vault/Kubernetes Secrets ──► somente secrets operacionais, se habilitado
```

### Auth ↔ KFE

No Kubernetes base, `kfe-service` usa `AUTH_REMOTE_BASE_URL=http://server:8080`.
O `server` usa `KFE_REMOTE_BASE_URL=http://kfe-service:8080`. A NetworkPolicy
permite apenas esses fluxos nas portas internas esperadas. O cliente nunca deve
receber essas URLs internas nem chamar um serviço de backend diretamente.

### KFE ↔ Vault Mesh

O caminho de produção/staging é:

1. KFE recebe o endpoint/coordenador e a lista de Vaults através de configuração
   autenticada de discovery, não por DNS arbitrário de pod.
2. KFE usa transporte Tor quando o overlay exigir e HTTPS com certificado de
   cliente (`KFE_VAULTMESH_TLS_*`).
3. Vault exige mTLS (`KFE_VAULTMESH_REQUIRE_MTLS=true`) e valida CA, hostname e
   identidade permitida. Token estático é somente laboratório.
4. KFE envia intents, reservas, aprovações e pedidos PSBT conforme os contratos
   versionados. A Mesh retorna receipts/provas; shares nunca saem dos Vaults.
5. Rotação/reshare é uma operação de quorum. Não é um cron independente em cada
   Vault; o coordenador autorizado dispara o fluxo.

### O que “Vault” significa

Há dois conceitos que não podem ser misturados:

- `kerosene-vault` / Vault Mesh: serviço Rust de custody e signing.
- HashiCorp Vault: opcional para secrets de operação (JWT, DB, API keys e
  certificados), nunca para shares FROST, chaves PQ ou material de carteira.

O runtime ativo não declara HashiCorp Vault, porta `8200` ou o antigo serviço
Raft. Se um gerenciador de secrets for adotado no futuro, ele continuará fora
do plano de custody e nunca será o canal KFE → Vault Mesh.

## Runtime publicado

Deploy publica um único contrato operacional: produção controlada em Bitcoin
`testnet3`, com overlay privado, imagens imutáveis, Tor, mTLS e evidência
assinada. Modos lab/staging permanecem somente como doubles e testes dentro do
repositório que os possui; eles não são entrypoints públicos de Deploy e nunca
podem ser promovidos.

## Fonte de verdade

- Contratos: `kerosene-contracts` e seus manifests de compatibilidade.
- Fiação/runtime: base pública e gate em `kerosene-deploy/infra/`; o overlay
  concreto pertence ao checkout privado de operações.
- Cliente Vault: `kerosene-kfe` e propriedades `kfe-service-vaultmesh-*`.
- Regras de segurança Vault: `kerosene-vault/AGENTS.md`, configuração de
  bootstrap e testes focados.

Alterações de protocolo devem começar em `kerosene-contracts`, ter versão,
vetores e rollout compatível antes de atualizar consumidores.
