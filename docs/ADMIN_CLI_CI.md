# Admin CLI reusable CI

Consumers call `admin-cli-ci.yml` pinned to a reviewed commit SHA. The workflow
tests and packages only the requested CLI. Artifacts contain binaries or an
application distribution; credentials and deployment authority are never
available to the job.

## Inputs

| Input | Type | Required | Description |
|---|---|---|---|
| `language` | string | yes | `rust` or `java` |
| `package` | string | yes | Cargo package or Gradle project name |
| `working-directory` | string | no | Working directory (default: `.`) |

## Validation

The workflow validates inputs before running the language-specific job:

- **Language** must be `rust` or `java`; any other value exits with code 2.
- **Package** must be non-empty.
- **Package convention**: Rust packages and Java projects should follow the
  `kerosene-` prefix convention (logged as a warning, not enforced).
- **Actionlint**: All caller workflow files are validated for syntax correctness
  before the language-specific CI runs.

## Caller examples

### Rust CLI

```yaml
jobs:
  rsctl:
    uses: Daniel-Astrofer/.github/.github/workflows/admin-cli-ci.yml@<sha>
    with:
      language: rust
      package: kerosene-rsctl
```

### Java CLI

```yaml
jobs:
  jctl:
    uses: Daniel-Astrofer/.github/.github/workflows/admin-cli-ci.yml@<sha>
    with:
      language: java
      package: kerosene-jctl
```

### With working directory

```yaml
jobs:
  rsctl:
    uses: Daniel-Astrofer/.github/.github/workflows/admin-cli-ci.yml@<sha>
    with:
      language: rust
      package: kerosene-rsctl
      working-directory: cli
```

## Artifact promotion

Artifacts produced by `admin-cli-ci.yml` are intermediate build outputs. To
promote an artifact to a release:

1. Verify the CI artifact hash matches the local build:
   ```bash
   sha256sum target/release/kerosene-rsctl
   ```
2. Download the artifact from the CI run page.
3. Attach it to a GitHub Release via the UI or the `gh` CLI:
   ```bash
   gh release upload v0.1.0 kerosene-rsctl
   ```
4. Run the `rust-release.yml` or corresponding release workflow to produce
   signed release artifacts with provenance attestation.

## Artifact revocation

If a CI artifact is found to be compromised or incorrectly built:

1. **Delete the artifact** from the CI run:
   ```bash
   gh run view <run-id> --log
   gh api -X DELETE "/repos/${{ github.repository }}/actions/artifacts/<artifact-id>"
   ```
2. **Retract from any releases** that included the artifact:
   ```bash
   gh release delete v0.1.0 --cleanup-tag
   ```
   or use `gh release edit v0.1.0` to remove specific assets.
3. **Notify consumers** via the repository's security advisory process if the
   artifact was distributed externally.
4. **File a postmortem** and update CI guards to prevent recurrence.

## Security

Publishing a GitHub release remains a separate, protected workflow. Passing CI
does not deploy a CLI to a bastion and does not authorize any production
operation.
