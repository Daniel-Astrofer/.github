# Admin CLI reusable CI

Consumers call `admin-cli-ci.yml` pinned to a reviewed commit SHA. The workflow
tests and packages only the requested CLI. Artifacts contain binaries or an
application distribution; credentials and deployment authority are never
available to the job.

```yaml
jobs:
  rsctl:
    uses: Daniel-Astrofer/.github/.github/workflows/admin-cli-ci.yml@<sha>
    with:
      language: rust
      package: kerosene-rsctl
```

```yaml
jobs:
  jctl:
    uses: Daniel-Astrofer/.github/.github/workflows/admin-cli-ci.yml@<sha>
    with:
      language: java
      package: kerosene-jctl
      working-directory: kerosene-jctl
```

Publishing a GitHub release remains a separate, protected workflow. Passing CI
does not deploy a CLI to a bastion and does not authorize any production
operation.
