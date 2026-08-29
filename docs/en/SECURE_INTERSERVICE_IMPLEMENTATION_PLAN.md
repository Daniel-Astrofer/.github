# Secure inter-service implementation plan

Status: normative target; not a statement of current readiness.

## Security invariants

- Network location, DNS, IP, Kubernetes namespace and Onion address MUST NOT
  grant trust.
- Production service traffic MUST use TLS 1.3 mutual authentication.
- SPIFFE/SPIRE MUST provide short-lived workload identity across Kubernetes and
  independent hosts; public ingress TLS MAY use cert-manager separately.
- Every server MUST authorize the caller SPIFFE ID, method, resource, contract
  version, environment and operation context.
- Discovery MUST locate endpoints but MUST NOT authorize them. A discovered
  identity MUST match a signed, versioned, non-expired roster.
- Missing identity, policy, contract, roster, clock validity or cryptographic
  evidence MUST fail closed.
- Production MUST reject HTTP, shared-secret fallbacks, lab tokens, dealer
  mode, attestation stubs and mutable images.

## Required flows

| Flow | Transport identity | Application authorization |
| --- | --- | --- |
| Client → Auth | public TLS + user/device identity | session, device binding, scope, object authorization |
| Auth ↔ KFE | SPIFFE mTLS | asymmetric delegated token with audience, scope, JTI and short expiry |
| KFE → Vault | SPIFFE mTLS, including over Tor | signed `SigningIntent`, policy hash, durable replay protection |
| Vault ↔ Vault | node-specific SPIFFE mTLS | FROST session epoch, participants, commitments and transcript hash |
| KFE → Node | SPIFFE mTLS | versioned, scoped contract |
| Node ↔ Node | P2P/validator identity | signed membership and validator-set epoch |
| Admin → service | operator/bastion SPIFFE mTLS | least-privilege RBAC and strong approval |

## Cryptographic custody

- Vault MUST pin and test one audited FROST implementation/ciphersuite.
- FROST nonces MUST be random, single-use, zeroized and tracked against reuse.
- A signing session MUST bind group key, epoch, participants, PSBT/message hash,
  commitments and transcript hash.
- Shares MUST remain sealed in the Vault trust boundary and MUST NOT enter KFE,
  Node, CI or a generic operational secret manager.
- DKG and reshare MUST require authenticated ceremony, quorum approval,
  evidence and tested recovery. Lab dealer mode MUST NOT compile into a
  production artifact.

## Discovery and consensus

Initial bootstrap provides only a trust bundle and approved directory/seeds.
The Node directory returns a signed roster containing epoch, expiry, network,
identities and endpoints. Consumers MUST verify the roster and then verify that
the endpoint presents the exact listed identity.

CometBFT validators SHOULD use sentry nodes and reviewed persistent peers; PEX
MUST be disabled for validators. ABCI SHOULD use a Unix socket or local
loopback; a remote ABCI channel MUST use mTLS. Validator keys MUST be isolated
from both the Node process where feasible and all Vault FROST shares.

## Delivery order and gates

1. Inventory endpoints, identities, secrets and threats.
2. Fix/pin FROST and publish immutable contracts and test vectors.
3. Deploy highly available SPIRE in staging; prove issuance, rotation and
   revocation.
4. Replace Auth↔KFE HTTP/shared secret with mTLS and explicit authorization.
5. Standardize KFE↔Vault on `/v1/sign`, one port contract and signed intents;
   enable the real staging path.
6. Implement signed discovery roster, admission quorum and revocation.
7. Implement/pin ABCI/CometBFT, sentry topology and validator-key isolation.
8. Enforce network, workload, supply-chain, backup and observability controls.
9. Pass adversarial staging, clean-fork, rollback, rotation and restore tests.

No phase is complete from code presence alone. Required evidence includes
negative identity/authorization tests, replay after restart, malformed and
resource-exhaustion inputs, FROST nonce/transcript failures, forged/stale
membership, consensus partition/recovery, signed artifact verification and a
real backup restore.

The detailed Portuguese plan is authoritative for execution sequencing and
acceptance evidence:
`docs/pt-BR/PLANO_IMPLEMENTACAO_COMUNICACAO_SEGURA.md`.
