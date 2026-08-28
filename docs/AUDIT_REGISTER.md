# Kerosene audit register

This register began with the first multi-agent audit and now records the
physical migration completed on 2026-08-28. Generated artifacts and verified
source copies were removed only after ownership and build validation.

Extracted repositories: `kerosene-admin`, `kerosene-rails`, `kerosene-kfe` and
`kerosene-shared`. Core now owns Auth/gateway only. Contracts and Docker helper
copies were removed from Core.

## Immediate production blockers

| Priority | Finding | Evidence | Required action |
|---|---|---|---|
| P0 | KFE settlement still calls legacy `POST /sign/{id}/{hash}` while Vault has `POST /v1/sign` | `kerosene-kfe/.../KfeVaultMeshSettlementClient.java`; `kerosene-vault/crates/vault-core/src/adapters/http.rs` | migrate client and tests; deprecate/remove legacy route only after consumers are gone |
| P0 | Vault port is inconsistent: lab `7701`, Kubernetes `7801`, Java defaults both | KFE properties, Compose and Vault manifests | choose one internal contract and make environment-specific mapping explicit |
| P0 | Staging imports go-live properties but sets `KFE_VAULTMESH_ENABLED=false` | `kerosene-deploy/infra/kubernetes/overlays/staging/patch-staging.yaml` | enable and test the real mTLS path, or rename the environment honestly |
| P0 | Vault Rust build is broken against the resolved FROST API | `kerosene-vault/crates/vault-signer` | perform a focused cryptographic API migration and tests before release work |
| P1 | Contracts are resolved from different Git commits | Node, Vault and fuzz `Cargo.toml` files | publish one immutable contracts revision and enforce it in CI |
| P1 | Core consumes a snapshot Contracts coordinate through a sibling composite build | `kerosene-core/settings.gradle.kts`, `kerosene-contracts/build.gradle.kts` | publish and pin an immutable release before production |
| P1 | KFE ↔ Node is disabled and one staging overlay uses a Kubernetes DNS endpoint where onion HTTPS is required | KFE defaults and `staging-vault/vault.yaml` | define one discovery transport contract and enable an end-to-end test |
| P1 | Internal Auth ↔ KFE secret has an insecure hardcoded default | `KfeGatewayController.java` | fail closed when missing; inject from external secret storage |

## Documentation cleanup

The audit covered 168 tracked documentation files and found stale monorepo
paths, broken links, duplicated normative documents, mixed languages and
current/planned/legacy states presented together. Cleanup order:

1. fix links and paths (`backend/kerosene`, `frontend`, `scripts/vault`);
2. create one `STATUS.md` per repository;
3. move history and plans out of operational indexes;
4. keep contracts only in `kerosene-contracts` and deploy runbooks only in
   `kerosene-deploy`;
5. create compact `docs/en/` and human-facing `docs/pt-BR/` trees;
6. add CI checks for broken links, forbidden legacy phrases and missing docs.

Known contradictions include staging fallback to lab, deprecated Kustomize
fields, the typo `Krinse Financial Engine`, and an incorrect deploy command
(`scripts/check-polyrepo-workspace.sh` instead of `infra/scripts/...`).

## Script cleanup policy

The active deploy repository has too many wrapper layers and two competing
startup trees (Kubernetes and legacy/local Compose). Keep native commands as
the canonical interface. Retain only thin wrappers for validation, path
resolution, deterministic smoke tests, release evidence and explicit local
bootstrap. Candidate scripts must be proven unreferenced by GitHub workflows,
parent scripts, Compose, Kustomize, tests and supported documentation before
removal.

## Archive decision

`archive/Kerosene-monorepo` is historical, not an active workspace. Audit
results estimate ~85 GB, including generated builds/caches and sensitive
Bitcoin/Lightning state. Classification:

- remove after confirmation: build, target, `.dart_tool`, Gradle caches, IDE
  metadata, temporary virtual environments and transient logs;
- preserve: source history, migration decisions, security tests/vectors and
  Git history until the polyrepo is verified;
- export to encrypted restricted storage before removal: wallets, seeds,
  `wallet.dat`, macaroons, TLS keys, channel state and node databases;
- require explicit confirmation: scripts, infrastructure, third-party code,
  snapshots and anything with evidentiary value.

No recursive deletion is authorized by this register. Sensitive material must
be rotated/revoked or retained under an approved operational procedure first.
