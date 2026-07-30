# Kerosene shared GitHub configuration

Reusable CI workflows and repository policy for the Kerosene polyrepo.

Consumers must pin reusable workflows to an immutable commit SHA. Major tags
shown in this repository are used only for upstream GitHub Actions.

## Workflows

- `rust-ci.yml`: Rust format, check, clippy, tests, RustSec/cargo-deny and
  unused-dependency gates.
- `java-ci.yml`: Java 21/Gradle verification with optional OWASP dependency audit.
- `flutter-ci.yml`: Flutter analyze and tests.
- `container-build.yml`: Docker build verification.
- `security-scan.yml`: Gitleaks, dependency review, Semgrep and optional CodeQL.
- `compatibility-ci.yml`: released and edge cross-repository contract-version checks.
- `rust-release.yml`: tested Rust binary, checksum, SBOM, Sigstore signature,
  build metadata and GitHub provenance.
- `release-attestation.yml`: GitHub artifact provenance.
- `sbom.yml`: SPDX SBOM generation.

No workflow receives production secrets or deploys signing infrastructure.
The optional `nvd-api-key` secret is only a public-vulnerability-feed API key;
Java callers should map a repository `NVD_API_KEY` secret to avoid NVD rate
limits.

## Cross-repository compatibility

Each Kerosene repository owns a `compatibility/kerosene.json` manifest. Contracts
lists the versions it provides; Core, Vault, Node, Clients and Deploy list the
versions they accept.

Every pull request calls the compatibility workflow twice:

- `released` compares the caller revision with the immutable revisions in
  `compatibility/released.json` and is a required gate.
- `edge` compares the caller revision with the peers' `main` branches. The job is
  allowed to fail so changes made after a pull request starts cannot block it.

The released manifest accepts only full commit SHAs or fully qualified immutable
tag refs. It is updated in the same reviewed change that publishes a component.
The current `bootstrap` baseline records the last known revisions because these
repositories did not yet have an official GitHub Release on 2026-07-29. After
the first release of each component, replace its entry with the published tag's
peeled commit and change `status` to `published`.

Caller example, pinned to the commit that contains the workflow:

```yaml
jobs:
  compatibility-released:
    uses: Daniel-Astrofer/.github/.github/workflows/compatibility-ci.yml@<commit-sha>
    with:
      component: core
      baseline: released

  compatibility-edge:
    uses: Daniel-Astrofer/.github/.github/workflows/compatibility-ci.yml@<commit-sha>
    with:
      component: core
      baseline: edge
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

## Rust releases

Vault and Node release workflows must call `rust-release.yml` from a GitHub
`release.published` event. The reusable workflow rejects forbidden features,
requires the Git tag to match the Cargo package version, reruns formatting,
clippy and tests, and publishes:

- the binary and `SHA256SUMS`;
- a keyless Sigstore bundle;
- an SPDX JSON SBOM;
- GitHub build provenance;
- the source commit/ref, Rust toolchain, compiled features and test-run link.

Vault callers must explicitly pass `dealer_lab` as forbidden and set the
`tee-hw` and `tpm` metadata flags to match the selected Cargo features.
