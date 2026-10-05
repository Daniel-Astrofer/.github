<!--
Kerosene documentation metadata
status: review-required
audience: internal
owner: .github
source_of_truth: .github
last_reviewed: 2026-09-03
-->

# Documentation exposure matrix

status: current  
audience: internal  
owner: security + architecture  
last_reviewed: 2026-09-02

This matrix classifies documentation and runtime surfaces. A route appearing in code is not automatically public or production-supported.

| Repository | Public or safe-to-share | Internal | Restricted | Never store in Git |
|---|---|---|---|---|
| core | concepts, safe health, public Auth contract | service integration, gateway behavior | admin policy, recovery and production diagnostics | JWT secrets, real user data, production endpoints |
| kfe | safe API concepts and local examples | authenticated financial integration | admin, internal rails, audit integrity, reserve and PSBT operations | balances/customer data, tokens, production configuration |
| vault | purpose, boundary and safe readiness | integration concepts | ceremonies, mesh topology, threat model, recovery | keys, roster, certificates, real endpoints/evidence |
| node | identity/discovery concepts | readiness and integration behavior | peer/membership topology, mTLS/Tor operations | private keys, peer data, production topology |
| rails | generic adapter concepts and safe health | KFE adapter integration | wallet, send, macaroon, admin and idempotency procedures | macaroons, TLS keys, node credentials |
| contracts | stable schemas and public protocol definitions | internal contracts and compatibility results | unreleased or security-sensitive protocol details | customer data or production secrets |
| deploy | profile concepts and safe prerequisites | generic troubleshooting | manifests, rollout, rollback, cluster and recovery runbooks | secret values, certs, cluster credentials, signing material |
| clients | design system and public UI concepts | feature/API mapping and local sync design | internal admin surfaces and release operations | tokens, user data, private endpoints |
| admin | none by default | tool architecture | command reference, bastion, mTLS, scopes and audit | credentials, bastion names, customer data |
| shared | library purpose and stable usage | approved API and compatibility | internal implementation details | secrets or service data |

## Classification rule

If a document describes how to reach, authenticate, recover or sign in a real environment, default to restricted. If it contains a value that can authenticate, identify a customer or recover custody, keep it outside Git entirely.
