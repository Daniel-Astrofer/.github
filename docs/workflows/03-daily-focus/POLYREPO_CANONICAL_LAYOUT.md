# Canonical Polyrepo Layout

Issue: [#6](https://github.com/Daniel-Astrofer/.github/issues/6)

## Goal

Make every Kerosene repository independently buildable and remove local-path
assumptions inherited from the monorepo.

## Repository ownership

| Repository | Canonical source |
|---|---|
| `kerosene-core` | Auth, KFE, shared Java and rail adapters |
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
- [ ] Organize local clones under `workspaces/kerosene`.
- [ ] Move the monorepo clone to `archive` and mark it read-only locally.
- [ ] Open independent pull requests and record validation evidence.

## Canonical local workspace

```text
workspaces/kerosene/
├── services/
│   ├── kerosene-core/
│   ├── kerosene-node/
│   └── kerosene-vault/
├── platform/
│   ├── kerosene-clients/
│   ├── kerosene-contracts/
│   ├── kerosene-deploy/
│   └── kerosene-github/
└── archive/
    └── Kerosene-monorepo/
```

Deploy resolves these paths through explicit environment variables. It must not
read source files from the archived monorepo.

## Contracts transition

`kerosene-contracts` is the canonical source. The Core compatibility module is
removed only after version `0.1.0` is published and the Java build consumes the
artifact. This prevents a path-only reorganization from breaking isolated
builds.
