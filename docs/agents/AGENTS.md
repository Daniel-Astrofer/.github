# Agent guide — Kerosene GitHub configuration

## Scope

This repository owns reusable CI workflows, cross-repository governance and the
platform documentation catalog. It does not own service behavior or production
deployment state.

## Documentation

- Start at `docs/PLATFORM_DOCUMENTATION_CATALOG.md`.
- Keep policy in `docs/`; keep each service's facts in its owning repository.
- Follow `docs/DOCUMENTATION_GOVERNANCE.md` and update the documentation gate
  when the standard changes.

## Safety and workflow rules

- Keep reusable workflows generic and least-privileged.
- Never add production secrets, signing shares, macaroons, seed phrases, Onion
  private keys or TPM key material.
- Prefer `workflow_call`, typed inputs and callers pinned by immutable SHA.
- Release workflows may publish candidates but must never activate Vault signers.

## Verification

Validate YAML and a caller example. Run `bash scripts/check-documentation.sh`
after documentation changes.
