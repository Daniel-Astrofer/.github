# Kerosene shared GitHub configuration

Reusable CI workflows and repository policy for the Kerosene polyrepo.

Consumers must pin reusable workflows to an immutable commit SHA. Major tags
shown in this repository are used only for upstream GitHub Actions.

## Workflows

- `rust-ci.yml`: Rust format, check and clippy gates.
- `java-ci.yml`: Java 21/Gradle verification.
- `flutter-ci.yml`: Flutter analyze and tests.
- `container-build.yml`: Docker build verification.
- `security-scan.yml`: repository secret scanning with Gitleaks.
- `compatibility-ci.yml`: cross-repository contract-version gate.
- `release-attestation.yml`: GitHub artifact provenance.
- `sbom.yml`: SPDX SBOM generation.

No workflow receives production secrets or deploys signing infrastructure.

## Cross-repository compatibility

Each Kerosene repository owns a `compatibility/kerosene.json` manifest. Contracts
lists the versions it provides; Core, Vault, Node, Clients and Deploy list the
versions they accept. On every pull request, `compatibility-ci.yml` uses the
caller's revision and the `main` revision of the public peers. The check fails
when any public consumer has no version in common with Contracts.

Caller example, pinned to the commit that contains the workflow:

```yaml
jobs:
  compatibility:
    uses: Daniel-Astrofer/.github/.github/workflows/compatibility-ci.yml@<commit-sha>
    with:
      component: core
```

Deploy is private. Its pull requests are checked as callers, but public
repositories do not receive credentials to inspect it.

Breaking changes use a two-phase rollout:

1. consumers add the new version while retaining the old version;
2. Contracts provides both versions;
3. consumers migrate and remove the old version;
4. Contracts removes the old version only after no consumer requires it.

This preserves compatibility without requiring atomic merges across
repositories.
