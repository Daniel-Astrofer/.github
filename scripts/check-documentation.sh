#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
github_repo_root=$(cd "$script_dir/.." && pwd)
workspace_dir="${KEROSENE_WORKSPACE_ROOT:-$(cd "$github_repo_root/.." && pwd)}"
repo_filter=""
explicit_repo=0
if [ "$#" -ge 2 ] && [ "$1" = "--repo" ]; then
  repo_filter="$2"
  explicit_repo=1
fi

failures=0

# Documentation is canonical by default. These directory names are reserved
# for VCS internals, generated/third-party dependencies, or workspace backups.
find_markdown_files() {
  root="$1"
  find "$root" \
    \( -path "$workspace_dir/archive" -o -type d \( \
      -name '.worktrees' -o \
      -name '.git' -o \
      -name '.venv' -o \
      -name '.dart_tool' -o \
      -name '.gradle' -o \
      -name '.pytest_cache' -o \
      -name '.mypy_cache' -o \
      -name '.ruff_cache' -o \
      -name '__pycache__' -o \
      -name 'target' -o \
      -name 'node_modules' -o \
      -name 'build' -o \
      -name 'dist' -o \
      -name 'coverage' -o \
      -name 'out' -o \
      -name 'web-admin-build' -o \
      -name 'third_party' -o \
      -name 'vendor' -o \
      -name 'backups' -o \
      -name '.backups' -o \
      -name '.codex-backups' \
    \) -prune \) -o \
    -type f -name '*.md' -print0
}

check_metadata() {
  file="$1"
  for key in status audience owner source_of_truth last_reviewed; do
    if ! sed -n '1,16p' "$file" | grep -Eq "(^|[[:space:];])${key}:"; then
      echo "MISSING DOCUMENTATION METADATA: $file ($key)"
      failures=$((failures + 1))
    fi
  done
}

check_agent_guide() {
  file="$1"
  if [ ! -f "$file" ]; then
    echo "MISSING AGENT GUIDE: $file"
    failures=$((failures + 1))
    return
  fi
  for heading in '## Scope' '## Documentation' '## Verification'; do
    if ! grep -Fq "$heading" "$file"; then
      echo "INCOMPLETE AGENT GUIDE: $file ($heading)"
      failures=$((failures + 1))
    fi
  done
}

check_repo() {
  repo="$1"
  echo "Checking $repo"
  check_agent_guide "$repo/docs/agents/AGENTS.md"

  if [ ! -f "$repo/README.md" ]; then
    echo "MISSING REPOSITORY ENTRYPOINT: $repo/README.md"
    failures=$((failures + 1))
  else
    check_metadata "$repo/README.md"
  fi

  if [ "$(basename "$repo")" = ".github" ]; then
    if [ ! -f "$repo/docs/system/README.md" ]; then
      echo "MISSING DOCUMENTATION ENTRYPOINT: $repo/docs/system/README.md"
      failures=$((failures + 1))
    fi
  else
    if [ ! -f "$repo/docs/quickstart/README.md" ]; then
      echo "MISSING DOCUMENTATION PORTAL: $repo/docs/quickstart/README.md"
      failures=$((failures + 1))
    else
      check_metadata "$repo/docs/quickstart/README.md"
    fi
    if [ ! -f "$repo/docs/quickstart/QUICKSTART.md" ]; then
      echo "MISSING DOCUMENTATION QUICKSTART: $repo/docs/quickstart/QUICKSTART.md"
      failures=$((failures + 1))
    fi
  fi

  while IFS= read -r -d '' markdown; do
    check_metadata "$markdown"
  done < <(
    find_markdown_files "$repo" |
      grep -zv '/AGENTS\.md$'
  )

  if [ "$(basename "$repo")" != ".github" ]; then
    while IFS= read -r root_markdown; do
      if ! sed -n '1,16p' "$root_markdown" | grep -Eq '^status: (deprecated|historical)$'; then
        echo "NONCANONICAL DOCUMENT ROOT: $root_markdown (move it into a documentation category)"
        failures=$((failures + 1))
      fi
    done < <(
      find "$repo/docs" -maxdepth 1 -type f -name '*.md' -print 2>/dev/null
    )
  fi

  while IFS="$(printf '\t')" read -r source target; do
    [ -z "$target" ] && continue
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    target=$(printf '%s' "$target" | sed 's/#.*$//')
    [ -z "$target" ] && continue
    source_dir=$(dirname "$source")
    resolved="$source_dir/$target"
    if [ ! -e "$resolved" ]; then
      echo "BROKEN LINK: $source -> $target"
      failures=$((failures + 1))
    fi
  done < <(
    find_markdown_files "$repo" |
      grep -zv '/docs/history/' |
      xargs -0 -r perl -ne 'while (/\[[^\]]*\]\(([^)]+)\)/g) { print "$ARGV\t$1\n" }'
  )

  find_markdown_files "$repo/docs" 2>/dev/null |
    xargs -0 -r sha256sum |
    sort -k1,1 |
    awk 'previous == $1 { print "DUPLICATE WARNING: " previous_file " == " $2 } { previous = $1; previous_file = $2 }'
}

check_cross_repo_duplicates() {
  find_markdown_files "$workspace_dir" |
    grep -z '/docs/.*\.md$' |
    xargs -0 -r sha256sum |
    sort -k1,1 |
    awk 'previous == $1 { print "DUPLICATE WARNING: " previous_file " == " $2 } { previous = $1; previous_file = $2 }'
}

if [ "$explicit_repo" -eq 1 ]; then
  case "$repo_filter" in
    .)
      if git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
        repo_filter=$(git -C "$PWD" rev-parse --show-toplevel)
      else
        repo_filter="$github_repo_root"
      fi
      ;;
    /*) ;;
    *) repo_filter="$workspace_dir/$(printf '%s' "$repo_filter" | sed 's|^\./||')" ;;
  esac
  check_repo "$repo_filter"
else
  for name in .github shared vault financial-rails discoveryng-node deploy users-authentication clients krinse-engine contracts server-administration; do
    dir="$workspace_dir/$name"
    if [ ! -d "$dir" ]; then
      case "$name" in
        financial-rails) dir="$workspace_dir/rails" ;;
        discoveryng-node) dir="$workspace_dir/node" ;;
        users-authentication) dir="$workspace_dir/core" ;;
        krinse-engine) dir="$workspace_dir/kfe" ;;
        server-administration) dir="$workspace_dir/admin" ;;
      esac
    fi
    if [ -d "$dir" ]; then
      check_repo "$dir"
    fi
  done
  check_cross_repo_duplicates
fi

if [ -f "$workspace_dir/WORKSPACE.md" ]; then
  check_metadata "$workspace_dir/WORKSPACE.md"
fi

if [ "$failures" -gt 0 ]; then
  echo "documentation gate failed: $failures issue(s)" >&2
  exit 1
fi

echo "documentation gate passed"
