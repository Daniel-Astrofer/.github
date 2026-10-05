<!--
Kerosene documentation metadata
status: current
audience: internal
owner: .github
source_of_truth: .github
last_reviewed: 2026-09-03
-->

# What is Kerosene

The Kerosene codebase is maintained as independent repositories. The local
workspace may contain them as sibling directories, but there is no source
monorepo.

| Repository | Responsibility |
| --- | --- |
| `kerosene-core` | Auth, sessions and application gateway |
| `kerosene-kfe` | KFE execution and settlement service |
| `kerosene-vault` | Custody, FROST and Vault Mesh |
| `kerosene-node` | Ledger, membership and consensus boundary |
| `kerosene-deploy` | Images, Kubernetes manifests and runbooks |
| `kerosene-contracts` | Versioned interoperability contracts |
| `kerosene-shared` | Approved shared library surface |
| `kerosene-admin` | Administrative CLI |
| `kerosene-rails` | Bitcoin and Lightning adapters |
| `kerosene-clients` | Flutter clients |

`kerosene-deploy` composes and operates the services; it must not copy their
source code. Inter-service communication must use versioned network contracts
and authenticated transport. The archived `Kerosene-monorepo` is historical
only and must not participate in builds.

This map documents repository boundaries. It does not claim that mTLS,
FROST, CometBFT or distributed discovery are production-complete. Those
capabilities remain governed by the open repository issues and production
gates.
