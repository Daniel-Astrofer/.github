# Agent rules

- Keep reusable workflows generic and least-privileged.
- Never add production secrets, signing shares, macaroons, seed phrases, Onion
  private keys or TPM key material.
- Prefer `workflow_call` and typed inputs.
- Consumers must pin this repository by commit SHA.
- Changes require YAML validation and a caller example.
- Release and deploy workflows may publish candidates, but must not activate
  Vault signers automatically.
