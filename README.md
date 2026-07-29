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
- `release-attestation.yml`: GitHub artifact provenance.
- `sbom.yml`: SPDX SBOM generation.

No workflow receives production secrets or deploys signing infrastructure.
