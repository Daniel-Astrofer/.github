# Kerosene restructuring plan

## Decision: initialization model

Each service must be runnable directly by its native toolchain. The canonical
interfaces are:

| Scope | Canonical command | Script role |
|---|---|---|
| Rust service | `cargo build/test/run` | checks, reproducible local env and release metadata |
| Java service | `./gradlew bootRun`, `./gradlew test` or the Core-specific `./gradlew :auth-service:bootRun` | checks, dependency discovery and packaging |
| Flutter client | `flutter run/test/build` | checks and platform setup only |
| Local integration | `docker compose` or `docker compose --profile ...` | resolver/validation/smoke orchestration |
| Kubernetes | `kubectl kustomize/apply` | render, preflight, evidence and smoke orchestration |

Scripts must not hide the real command, invent a second deployment system, or
contain secrets. A script is justified when it is deterministic, idempotent,
reviewable and does one of: resolve polyrepo paths, validate prerequisites,
render/validate manifests, run a documented smoke test, or collect release
evidence. Scripts that only wrap one native command should be removed or
replaced by Make targets/documented commands.

The service repositories remain independently buildable and releasable. The
deploy repository is the integration boundary; it may orchestrate versions but
must not copy source code or own service logic.

## Multi-agent work plan

### Wave 0 — inventory and freeze

- Freeze deletions and production promotion.
- Capture Git status, tracked files, ignored/generated files and repository
  remotes for every sibling repository.
- Mark sensitive material (keys, shares, transcripts, databases, logs) before
  any cleanup.

### Wave 1 — parallel audits

1. Documentation agent: audit every tracked Markdown/text document, detect
   stale phrases, links, monorepo paths and contradictory claims.
2. Runtime agent: audit scripts, Compose, Kustomize and workflows; build a
   reference graph from command invocations and CI callers.
3. Archive agent: classify `archive/Kerosene-monorepo` and generated data by
   retention, deletion and external-storage policy.
4. Contract agent: map Auth/KFE/Vault/Node traffic, contracts and compatibility
   versions; identify dead configuration and unsafe fallbacks.

Agents report first and do not delete. Implementation agents only start after
the reports are reviewed and have disjoint write scopes.

### Wave 2 — canonical layout

- Keep each active service repository independent.
- Put human-facing Portuguese documentation in `docs/pt-BR/`.
- Put short, precise operator/developer documentation in `docs/en/`.
- Keep one README per repository as an index, not as a second manual.
- Move operational runbooks to `kerosene-deploy/docs/ops/`; keep service docs
  limited to service behavior, APIs, build and security boundaries.
- Add a per-service `SERVICE_STATUS.md` with current, legacy and pending
  sections.

For each migrated document, the English version is the normative compact
reference. The Portuguese version explains the same behavior for humans and
must not introduce different commands, defaults or security guarantees.

### Wave 3 — cleanup

Delete only after reference-graph review:

- generated build/cache directories and local logs;
- duplicate scripts whose callers were removed;
- obsolete monorepo paths and copied source trees;
- dead compose profiles and manifests with no active caller;
- archive data after its retention decision and, for sensitive material,
  rotation/revocation confirmation.

Never delete cryptographic material merely because it is ignored by Git. Move
it to an approved secure location or destroy it through the operational
procedure, then record the result without recording the secret itself.

### Wave 4 — production gates

- Every service builds/tests independently from a clean checkout.
- A fork can configure repository URLs, image registry and secrets without
  editing source code.
- Local boot uses documented native commands; integration boot uses one
  documented Compose/Kubernetes entry point.
- Staging proves authenticated Auth↔KFE and KFE↔Vault flows.
- Production rejects lab tokens, dealer mode, stubs and mutable image tags.
- CI checks broken links, forbidden legacy phrases/paths, orphan scripts,
  secret patterns and compatibility manifests.

## Definition of done

The restructuring is complete only when every active file has an owner and a
reason to exist, every deleted file has a recorded rationale, every service has
English and Portuguese documentation, and a clean fork passes build, test,
render, security and smoke gates without relying on `archive/`.
