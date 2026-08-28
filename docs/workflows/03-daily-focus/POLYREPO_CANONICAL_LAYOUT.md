# Canonical Polyrepo Layout

Issue: [#6](https://github.com/Daniel-Astrofer/.github/issues/6)

## Goal

Make every Kerosene repository independently buildable and remove local-path
assumptions inherited from the monorepo.

## Repository ownership

| Repository | Canonical source |
|---|---|
| `kerosene-core` | Auth, sessions, notifications and public gateway |
| `kerosene-kfe` | Ledger, wallets, reconciliation and financial execution |
| `kerosene-shared` | Neutral Java runtime utilities |
| `kerosene-rails` | Bitcoin Core and LND adapters |
| `kerosene-admin` | Operator-facing administrative clients |
| `kerosene-vault` | Vault Rust domain, signer and custody scripts |
| `kerosene-node` | Identity, discovery, membership and consensus |
| `kerosene-contracts` | Protocol schemas and generated artifacts |
| `kerosene-clients` | Flutter applications and client packages |
| `kerosene-deploy` | Compose, Kubernetes and release orchestration |
| `.github` | Shared CI and repository policy |

The archived monorepo is never a build input.

## Execution

- [x] Create tracking issue and Project item.
- [x] Rename the Core application module to `auth-service`.
- [x] Document root layouts for the single-crate Vault and Flutter client.
- [x] Add a Deploy workspace resolver for sibling repositories.
- [x] Remove absolute monorepo paths from active deployment manifests.
- [x] Add guardrails against new monorepo path dependencies.
- [x] Validate isolated builds and cross-repository compatibility.
- [x] Organize local clones under `workspaces/kerosene`.
- [x] Move the monorepo clone to `archive` and mark it read-only locally.
- [x] Open independent pull requests and record validation evidence.

## Canonical local workspace

```text
workspaces/kerosene/
├── services/
│   ├── kerosene-core/
│   ├── kerosene-kfe/
│   ├── kerosene-rails/
│   ├── kerosene-node/
│   └── kerosene-vault/
├── platform/
│   ├── kerosene-clients/
│   ├── kerosene-contracts/
│   ├── kerosene-shared/
│   ├── kerosene-admin/
│   ├── kerosene-deploy/
│   └── kerosene-github/
└── archive/
    └── Kerosene-monorepo/
```

Deploy resolves these paths through explicit environment variables. It must not
read source files from the archived monorepo.

## Contracts transition

`kerosene-contracts` is the canonical source. Core consumes it through a
Gradle composite build; the former copied compatibility module was removed.
Production still requires publishing and pinning an immutable artifact instead
of the current snapshot coordinate.

## Delivery evidence

| Repository | Pull request | Result |
|---|---:|---|
| `kerosene-core` | [#3](https://github.com/Daniel-Astrofer/kerosene-core/pull/3) | Merged; Java, security and compatibility checks passed |
| `kerosene-vault` | [#6](https://github.com/Daniel-Astrofer/kerosene-vault/pull/6) | Merged; Rust, security and compatibility checks passed |
| `kerosene-node` | [#5](https://github.com/Daniel-Astrofer/kerosene-node/pull/5) | Merged; security and compatibility checks passed |
| `kerosene-contracts` | [#3](https://github.com/Daniel-Astrofer/kerosene-contracts/pull/3) | Merged; Java, security and compatibility checks passed |
| `kerosene-clients` | [#4](https://github.com/Daniel-Astrofer/kerosene-clients/pull/4) | Merged; Flutter, security and compatibility checks passed |
| `kerosene-deploy` | [#4](https://github.com/Daniel-Astrofer/kerosene-deploy/pull/4) | Merged; architecture, security and compatibility checks passed |

After moving the clones, `scripts/check-polyrepo-workspace.sh`,
`scripts/check_architecture_guardrails.sh`, and `bash infra/test.sh` all passed
from the canonical Deploy location.
