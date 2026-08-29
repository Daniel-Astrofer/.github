# Plano de implementação da comunicação segura entre serviços

Status: proposta normativa para execução. Este documento define o estado alvo,
a ordem de implementação e as evidências mínimas para produção. Ele não declara
que os controles já existem.

## Resultado esperado

Kerosene deve operar em Kubernetes ou em máquinas independentes sem confiar na
rede, no DNS, no endereço IP ou no simples fato de um processo estar dentro do
cluster. Cada workload deve possuir identidade criptográfica curta e verificável;
cada chamada deve ser autorizada para uma operação específica; descoberta deve
localizar serviços sem conceder autoridade; e operações financeiras devem ser
íntegras, idempotentes, auditáveis e resistentes a replay.

Nenhum desenho protege contra "todas" as formas de ataque. O objetivo é reduzir
risco com defesa em profundidade, limitar o impacto de uma credencial ou máquina
comprometida, detectar abuso e manter recuperação testada.

## Decisões arquiteturais

1. **Zero Trust:** nenhuma confiança implícita por rede, namespace, IP, máquina
   ou conexão Tor. Autenticação e autorização acontecem em toda conexão.
2. **Identidade de workload:** SPIFFE/SPIRE será o mecanismo canônico para
   workloads em Kubernetes e hosts independentes. `cert-manager` permanece
   adequado para TLS público/Ingress, não como fonte principal de identidade
   entre serviços.
3. **Transporte:** TLS 1.3 com mTLS para tráfego interno. Produção não aceita
   HTTP, segredo compartilhado, certificado autoassinado desconhecido, token de
   laboratório ou fallback silencioso.
4. **Autorização:** mTLS prova a identidade do processo, mas não autoriza uma
   transação financeira. Cada servidor aplica política por SPIFFE ID, método,
   recurso, ambiente, rede e contexto assinado da operação.
5. **Descoberta:** DNS, Kubernetes Service, endereço IP e Onion são apenas
   localização. Confiança vem do trust bundle, da identidade mTLS e de um roster
   versionado e assinado.
6. **Separação de planos:** usuário/Auth, execução financeira/KFE,
   custody/Vault, consenso/Node e operação/Deploy permanecem domínios separados.
7. **Fail closed:** ausência, expiração ou divergência de identidade, contrato,
   clock, roster, política ou evidência interrompe a operação sensível.

## Identidades e PKI

Trust domains separados impedem que credenciais de desenvolvimento sejam
aceitas em produção:

```text
spiffe://dev.kerosene/service/auth
spiffe://staging.kerosene/service/kfe
spiffe://prod.kerosene/service/vault/node/<node-id>
spiffe://prod.kerosene/service/node/validator/<validator-id>
spiffe://prod.kerosene/service/admin
```

Regras obrigatórias:

- raiz de confiança offline e intermediárias distintas por ambiente;
- emissão após attestation do workload/host, não após conhecer um segredo
  estático;
- SVID X.509 de curta duração, renovado automaticamente antes de um terço da
  validade restante;
- chave privada não exportável quando TPM/TEE/HSM estiver disponível;
- validação do URI SAN exato e do trust domain; CN e hostname isoladamente não
  representam identidade de serviço;
- remoção imediata da registration entry em incidente, distribuição de novo
  trust bundle e validade curta para limitar revogação tardia;
- procedimento ensaiado de rotação de raiz/intermediária com período de dupla
  confiança e rollback;
- nenhum certificado, chave, share, macaroon ou bootstrap token em Git, imagem,
  ConfigMap, log ou variável exibida pelo processo.

Topologia SPIRE proposta:

- dois ou mais SPIRE Servers por ambiente de produção, com datastore protegido;
- SPIRE Agent por nó Kubernetes e por host independente;
- node attestation específica da plataforma; bootstrap manual e auditado para
  hosts sem identidade de nuvem;
- federation somente entre trust domains explicitamente aprovados;
- socket da Workload API montado apenas nos workloads que precisam de SVID.

## Contrato de cada comunicação

| Origem → destino | Identidade | Autorização de aplicação | Descoberta |
| --- | --- | --- | --- |
| Cliente → Auth | TLS público + identidade do usuário/dispositivo | sessão curta, passkey/device binding, escopo e rate limit | DNS público controlado |
| Auth → KFE | mTLS SPIFFE | token delegado assimétrico com `iss`, `aud`, `sub`, `jti`, escopo e expiração curta | Service/roster configurado |
| KFE → Auth | mTLS SPIFFE | apenas APIs internas explicitamente permitidas | Service configurado |
| KFE → Vault | mTLS SPIFFE, inclusive sobre Tor | `SigningIntent` assinado, policy hash, idempotência e quorum | roster Vault assinado |
| Vault → Vault | mTLS SPIFFE entre IDs de nós aprovados | sessão FROST, transcript hash, participantes e commitments | roster fixado por epoch |
| KFE → Node | mTLS SPIFFE | consultas/comandos versionados e escopados | bootstrap + roster assinado |
| Node ↔ Node | identidade P2P/validator + rede privada | membership e conjunto de validadores por epoch | seeds/persistent peers aprovados |
| Admin → serviço | mTLS SPIFFE de operador/bastion | RBAC, aprovação forte e trilha de auditoria | endpoint administrativo privado |

### Auth ↔ KFE

- remover `http://kfe-service:8080` e o shared secret como defaults;
- KFE aceita somente a identidade `service/auth` nas rotas destinadas ao Auth;
- Auth aceita somente `service/kfe` nas callbacks internas;
- o contexto do usuário usa token assimétrico, `aud` específico do KFE,
  expiração curta e `jti` de uso controlado; ele nunca substitui mTLS;
- claims externas não são repassadas sem normalização e validação de schema;
- toda rota tem autorização de objeto e função, limite de tamanho, timeout,
  rate limit e erro sanitizado.

### KFE → Vault Mesh

O contrato canônico deve ser `POST /v1/sign`; a rota legada `/sign` será
mantida apenas durante uma janela explícita e removida quando nenhum consumidor
a utilizar. A porta interna canônica será definida em `kerosene-contracts` e o
Deploy apenas fará mappings externos quando necessário.

O `SigningIntent` precisa conter, no mínimo:

```text
contract_version, request_id, intent_id, network_id, wallet_id,
psbt_hash, policy_hash, amount/fee bounds, participant_epoch,
issued_at, expires_at, nonce, caller_spiffe_id
```

Vault deve validar novamente PSBT, rede, outputs, fee bounds, policy hash,
epoch, expiração e identidade do KFE. Nenhuma URL fornecida pelo cliente pode
ser buscada pelo Vault. `request_id`, `intent_id` e nonce recebem restrição de
unicidade durável para impedir replay.

### Vault ↔ Vault e FROST

- primeiro corrigir e fixar a versão da biblioteca FROST;
- implementar contra vetores conhecidos e manter a ciphersuite explícita;
- nonce FROST é aleatório, de uso único, zeroizado e nunca reconstruído após
  falha; commitments usados são persistidos para detectar replay/reuso;
- toda sessão fixa group key, epoch, participantes, message/PSBT hash,
  commitments e transcript hash antes de produzir shares;
- falha de transporte, commitment inválido, participante desconhecido ou
  divergência de transcript aborta a sessão;
- DKG/reshare exige cerimônia autenticada, aprovação de quorum, evidência e
  plano de recuperação; dealer de laboratório é proibido em produção;
- shares permanecem selados no domínio do Vault e nunca entram no KFE, Node,
  CI, backup genérico ou secret manager operacional.

### Descoberta e membership

Não haverá "autodescoberta que confia automaticamente". O primeiro boot recebe
somente um trust bundle e um conjunto mínimo de bootstrap endpoints aprovados.
Depois:

1. o workload obtém uma identidade após attestation;
2. conecta por mTLS ao diretório do Node;
3. recebe roster assinado, versionado, com epoch, expiração, IDs e endpoints;
4. valida assinatura, network ID, monotonicidade de epoch e identidade do
   diretório;
5. conecta ao endpoint descoberto e exige que o SPIFFE ID corresponda ao roster;
6. rejeita peer removido, roster antigo, downgrade de contrato e endpoint com
   identidade divergente.

Kubernetes DNS é aceitável como endpoint de bootstrap. Em hosts independentes,
DNS privado, IP ou Onion podem ser usados. Nenhum deles substitui a validação
de identidade. Cache de roster deve possuir expiração e política explícita para
partição: leitura limitada pode continuar; mudanças financeiras e membership
falham fechadas.

### Node e CometBFT

- definir `kerosene-node` como dono do adaptador ABCI e da configuração de
  consenso, sem importar custody ou lógica financeira do KFE;
- ABCI deve usar Unix socket/local loopback; se remoto, mTLS e allowlist exata;
- validadores usam sentry nodes, firewall e persistent peers aprovados;
- PEX fica desativado nos validadores; peers privados/incondicionais são
  versionados e revisados;
- chave do validador fica fora do processo principal, preferencialmente em
  signer/HSM dedicado; nunca junto de share FROST;
- genesis, chain ID e validator set são artefatos assinados e imutáveis por
  release;
- testes cobrem equivocation, double-sign prevention, partição, restart,
  estado corrompido e recuperação de snapshot.

## Defesa em profundidade

| Camada/ataque | Controles obrigatórios | Evidência |
| --- | --- | --- |
| DDoS, brute force e bots | CDN/LB, quotas, rate limits por identidade/recurso, filas limitadas e backpressure | testes de carga e alertas acionados |
| BOLA/BFLA e escalada | autorização de objeto/função em toda rota, RBAC/ABAC e testes com duas identidades | suíte OWASP API negativa |
| MITM/impersonação | TLS 1.3, mTLS SPIFFE, URI SAN, trust domains separados, rotação | testes com CA/ID/certificado inválidos |
| Replay/double spend | `jti`, nonce, timestamp, expiry, idempotência durável, state machine | replay concorrente e após restart |
| SSRF | egress deny-by-default, allowlist fixa, sem URL arbitrária, proxy de egress | payloads SSRF e auditoria de egress |
| DoS de parser/recursos | schema estrito, limites de corpo/profundidade, timeouts, circuit breaker e quotas | fuzz, payload gigante, slowloris |
| Compromisso de pod | non-root, rootfs read-only, seccomp, capabilities removidas, NetworkPolicy e secret mounts mínimos | policy gate no manifest |
| Exfiltração de segredo | SVID curto, TPM/TEE/HSM, zeroização, logs redigidos, egress controlado | scan de logs/memória e teste de rotação |
| Supply chain | dependências pinadas, SBOM, provenance SLSA, imagem assinada e deploy por digest | verificação obrigatória no admission/deploy |
| Insider/CI comprometido | ambientes protegidos, OIDC, duas aprovações para signer/release, runners efêmeros | audit trail e teste de permissão |
| Ledger/consenso | sentry, validator key isolada, peers aprovados, snapshots verificados | testes de Byzantine/partição/restart |
| Perda/ransomware | backup cifrado, imutável, offsite e restore ensaiado | RPO/RTO medidos e relatório de restore |

## Ordem de implementação

### Fase 0 — baseline e ameaça

Repos: `.github`, `contracts`, todos os serviços.

- congelar promoção de produção;
- inventariar endpoints, portas, callers, identities e secrets;
- criar threat model por fluxo e classificar dados/chaves;
- transferir a issue da rota `/sign` para KFE agora que o repositório existe;
- fechar duplicatas somente após vincular a issue sucessora.

Gate: nenhum endpoint sem owner, contrato, autenticação e classificação.

### Fase 1 — desbloqueio criptográfico e contratos

Repos: `vault`, `contracts`, `kfe`.

- corrigir Vault/FROST e pinar versões;
- publicar contratos versionados para identity, roster e `SigningIntent`;
- escolher porta e `/v1/sign` canônicos;
- adicionar vetores multi-linguagem e testes de compatibilidade.

Gate: Vault compila sem features de laboratório, vetores passam e consumidores
aceitam a mesma revisão imutável de Contracts.

### Fase 2 — plano de identidade

Repos: `deploy`, `core`, `kfe`, `vault`, `node`, `admin`.

- provisionar SPIRE HA em staging;
- registrar IDs/selectors por workload;
- integrar clientes/servidores TLS com hot reload de SVID/bundle;
- aplicar allowlists de SPIFFE ID por rota;
- ensaiar rotação, revogação e expiração.

Gate: matriz negativa de mTLS passa; nenhum serviço inicia em perfil production
sem identidade válida.

### Fase 3 — Auth ↔ KFE

Repos: `core`, `kfe`, `contracts`, `deploy`.

- remover HTTP/shared secret e gateway público que injeta segredo interno;
- implementar token delegado assimétrico e autorização por método/recurso;
- corrigir fail-open, JWT startup validation, DoS de headers e rate limiting.

Gate: shared secret ausente do código/manifests; captura de tráfego demonstra
TLS; identidade errada, token errado e replay recebem negação.

### Fase 4 — KFE ↔ Vault

Repos: `kfe`, `vault`, `contracts`, `deploy`.

- migrar para `/v1/sign` e porta canônica;
- implementar `SigningIntent` e validação independente no Vault;
- ativar o Vault Mesh real em staging, sem token/dealer/stub;
- provar quorum e recibo ponta a ponta sobre mTLS/Tor.

Gate: assinatura de testnet valida; um único Vault não assina; CA/ID/PSBT/epoch
incorretos e replay são rejeitados e alertados.

### Fase 5 — discovery e membership

Repos: `node`, `contracts`, `kfe`, `vault`, `deploy`.

- implementar roster assinado e monotônico;
- admission m-de-n, revogação, rotação e expiry;
- bootstrap para Kubernetes e hosts independentes;
- testar partições e stale roster.

Gate: serviço novo recebe identidade e encontra peers aprovados após fornecer
somente bootstrap bundle/config; peer não aprovado nunca entra no roster.

### Fase 6 — CometBFT e ledger

Repos: `node`, `contracts`, `deploy`.

- implementar/pinar ABCI e CometBFT;
- configurar sentry topology e key isolation;
- definir genesis/upgrade/snapshot/recovery;
- testar Byzantine, double-sign e network partition.

Gate: consenso reproduzível com perda de nó dentro do modelo de falha e sem
misturar validator keys com shares Vault.

### Fase 7 — plataforma, supply chain e operação

Repos: `deploy`, `.github`, todos os produtores de imagem.

- NetworkPolicy e egress deny-by-default;
- Pod Security/Admission, seccomp e recursos limitados;
- imagens mínimas, SBOM, assinatura, provenance e digest obrigatório;
- backup/restore, alerting, log retention, certificate expiry e incident
  response operacionais.

Gate: manifests falham quando contêm tag mutável, privilégio, HTTP interno,
secret default, identidade ausente ou imagem sem assinatura.

### Fase 8 — staging adversarial e fork limpo

Repos: `deploy` e todos os serviços.

- executar clean checkout/fork usando somente secrets externos;
- pentest de APIs e serviços internos;
- chaos: perda de Vault, Node, DB, Redis, CA, relógio e rede;
- testar rollback, revogação emergencial, restore e rotação completa;
- produzir pacote de evidências sem secrets.

Gate: todos os P0 fechados por evidência, zero fallback de laboratório e
aprovação independente de segurança/operação.

## Mapeamento inicial do backlog

| Frente | Issues existentes | Ajuste necessário |
| --- | --- | --- |
| Auth ↔ KFE | Core `#52`, `#71`–`#76` | manter no Core o que é gateway/Auth; criar espelho no KFE para o servidor interno |
| API/porta Vault | Core `#77`, Deploy `#32` | transferir a implementação de cliente para o novo repositório KFE |
| KFE → Vault mTLS | Deploy `#31` | criar subtarefas de aplicação em KFE e Vault, mantendo Deploy como prova E2E |
| FROST/custody | Vault `#15`–`#17` | separar compilação/API, nonce lifecycle e TPM/TEE em PRs independentes |
| Discovery/membership | Deploy `#33`, Node `#16`–`#18` | adicionar contrato de roster em Contracts e bootstrap em Deploy |
| Fork e operação | Deploy `#23`–`#30`, `#34` | transformar cada gate em teste/evidência automatizada |
| Contratos/release | Contracts `#12`–`#14` | publicar revisão imutável antes de migrar consumidores |

Issues não devem ser fechadas porque o código "existe". O fechamento exige o
gate da fase correspondente, link para CI/evidência e confirmação de que não
restou fallback inseguro.

## Estratégia de rollout e rollback

Cada mudança de protocolo usa expansão/contração:

1. Contracts publica a nova versão sem remover a anterior.
2. Servidores aceitam ambas, mas produzem a antiga por default.
3. Clientes passam a produzir a nova versão e métricas provam adoção.
4. Produção rejeita a antiga após prazo e rollback ensaiado.
5. O código legado é removido somente quando telemetria e compatibility gates
   provarem ausência de consumidores.

Rotação de CA usa trust bundle antigo+novo, emissão apenas pela nova CA,
renovação total, remoção da antiga e teste de rollback. Nenhum rollback pode
reativar HTTP, token estático, dealer, stub ou imagem mutável.

## Evidências mínimas de segurança

- teste de mTLS válido e negativos para CA, SAN, service ID, ambiente,
  expiração, rotação e revogação;
- autorização com identidades legítimas mas sem escopo;
- replay simultâneo e após restart;
- fuzz/property tests dos parsers e contratos;
- scan SAST/SCA/secrets, SBOM e provenance verificados;
- teste de SSRF/egress e resource exhaustion;
- teste de FROST nonce reuse, transcript mismatch e quorum incompleto;
- teste de membership stale/forjado/revogado;
- teste de CometBFT partition/double-sign/recovery;
- restore real de backup e medição de RPO/RTO;
- relatório de pentest com reteste de todos os achados críticos/altos.

## Definition of done para produção

Produção só pode ser aprovada quando:

- todos os fluxos internos usam identidade mTLS e autorização explícita;
- não existem defaults de segredo, HTTP interno ou fallback de laboratório;
- Vault/FROST compila, passa vetores e mantém nonces/shares protegidos;
- discovery encontra endpoints sem confiar neles automaticamente;
- membership e consenso possuem revogação, recuperação e evidência;
- contratos e imagens são imutáveis, assinados e verificados por digest;
- observabilidade detecta negações, replay, expiração e degradação sem registrar
  dados sensíveis;
- backup, restore, rollback, rotação e resposta a incidente foram ensaiados;
- um fork limpo reproduz staging usando apenas configuração e secrets externos.

## Referências normativas

- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final)
- [SPIFFE standards and workload identity](https://spiffe.io/docs/latest/spiffe-specs/)
- [Kubernetes Security Checklist](https://kubernetes.io/docs/concepts/security/security-checklist/)
- [RFC 8446 — TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446.html)
- [RFC 9591 — FROST](https://www.rfc-editor.org/rfc/rfc9591.html)
- [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x03-introduction/)
- [SLSA build requirements](https://slsa.dev/spec/v1.2/build-requirements)
- [CometBFT P2P configuration](https://docs.cometbft.com/main/spec/p2p/legacy-docs/config)
