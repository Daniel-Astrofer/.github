#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
github_repo_root=$(cd "$script_dir/.." && pwd)
workspace_dir="${KEROSENE_WORKSPACE_ROOT:-$(cd "$github_repo_root/.." && pwd)}"
review_date=${DOCUMENTATION_REVIEW_DATE:-2026-09-04}
dry_run=0
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=1
fi

metadata_marker="Kerosene documentation metadata"
processed=0
stamped=0
skipped=0
upgraded=0

has_complete_metadata() {
  file="$1"
  for key in status audience owner source_of_truth last_reviewed; do
    if ! sed -n '1,16p' "$file" | grep -Eq "(^|[[:space:];])${key}:"; then
      return 1
    fi
  done
}

owner_for() {
  file="$1"
  case "$file" in
    "$workspace_dir"/docs/*) printf '%s' "platform" ;;
    "$workspace_dir"/.github/docs/*) printf '%s' ".github" ;;
    "$workspace_dir"/README.md|"$workspace_dir"/WORKSPACE.md) printf '%s' "platform" ;;
    "$workspace_dir"/*/README.md)
      relative=${file#"$workspace_dir"/}
      printf '%s' "${relative%%/*}"
      ;;
    "$workspace_dir"/*/docs/*)
      relative=${file#"$workspace_dir"/}
      printf '%s' "${relative%%/*}"
      ;;
    "$workspace_dir"/*/*)
      relative=${file#"$workspace_dir"/}
      printf '%s' "${relative%%/*}"
      ;;
    *) printf '%s' "unknown" ;;
  esac
}

audience_for() {
  file="$1"
  case "$file" in
    */history/*|*/plans/*|*/ops/*|*/security/*|*THREAT*|*PRODUCTION*|*RUNBOOK*|*CEREMONY*|*AUDIT*|*GATES*)
      printf '%s' "internal/restricted"
      ;;
    *) printf '%s' "internal" ;;
  esac
}

source_of_truth_for() {
  file="$1"
  owner=$(owner_for "$file")
  printf '%s' "$owner"
}

status_for() {
  file="$1"
  case "$file" in
    */history/*|*.legacy.md) printf '%s' "historical"; return ;;
  esac
  if sed -n '1,24p' "$file" | grep -Eiq 'Historical|deprecated plan|historical design record|status:[[:space:]]*historical'; then
    printf '%s' "historical"
  else
    printf '%s' "review-required"
  fi
}

stamp_file() {
  file="$1"
  owner=$(owner_for "$file")
  audience=$(audience_for "$file")
  status=$(status_for "$file")
  source_of_truth=$(source_of_truth_for "$file")
  tmp="${file}.documentation-metadata.tmp"

  {
    printf '<!--\n'
    printf '%s\n' "$metadata_marker"
    printf 'status: %s\n' "$status"
    printf 'audience: %s\n' "$audience"
    printf 'owner: %s\n' "$owner"
    printf 'source_of_truth: %s\n' "$source_of_truth"
    printf 'last_reviewed: %s\n' "$review_date"
    printf '%s\n\n' '-->'
    cat "$file"
  } > "$tmp"
  mv "$tmp" "$file"
}

upgrade_file() {
  file="$1"
  if sed -n '1,14p' "$file" | grep -q '^source_of_truth:' &&
     sed -n '1,14p' "$file" | grep -q "^last_reviewed: $review_date$"; then
    return
  fi
  if [ "$dry_run" -eq 1 ]; then
    printf 'WOULD UPGRADE: %s\n' "${file#"$workspace_dir"/}"
    return
  fi
  source_of_truth=$(source_of_truth_for "$file")
  tmp="${file}.documentation-metadata.tmp"
  awk -v source="$source_of_truth" -v review_date="$review_date" '
    /Kerosene documentation metadata/ { in_metadata = 1 }
    in_metadata && /^source_of_truth:/ { source_seen = 1 }
    in_metadata && /^owner:/ {
      print
      if (!source_seen && !inserted) { print "source_of_truth: " source; inserted = 1 }
      next
    }
    in_metadata && /^last_reviewed:/ { print "last_reviewed: " review_date; next }
    in_metadata && /^-->/ { in_metadata = 0 }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  upgraded=$((upgraded + 1))
  printf 'UPGRADED: %s\n' "${file#"$workspace_dir"/}"
}

while IFS= read -r -d '' file; do
  processed=$((processed + 1))
  if has_complete_metadata "$file"; then
    skipped=$((skipped + 1))
    continue
  fi
  if sed -n '1,24p' "$file" | grep -q "$metadata_marker"; then
    upgrade_file "$file"
    skipped=$((skipped + 1))
    continue
  fi
  if [ "$dry_run" -eq 1 ]; then
    printf 'WOULD STAMP: %s\n' "${file#"$workspace_dir"/}"
  else
    stamp_file "$file"
    printf 'STAMPED: %s\n' "${file#"$workspace_dir"/}"
  fi
  stamped=$((stamped + 1))
done < <(
  {
    find "$workspace_dir" \
      \( -path "$workspace_dir/archive" -o -path '*/.worktrees' -o -path '*/.git' -o -path '*/build' \) -prune -o \
      -type f -name '*.md' ! -name 'AGENTS.md' -print0
    printf '%s\0' "$workspace_dir/WORKSPACE.md"
    for name in .github shared vault financial-rails discoveryng-node deploy users-authentication clients krinse-engine contracts server-administration rails node core kfe admin; do
      [ -f "$workspace_dir/$name/README.md" ] && printf '%s\0' "$workspace_dir/$name/README.md"
    done
  } | sort -zu
)

printf 'processed=%s stamped=%s upgraded=%s skipped=%s\n' "$processed" "$stamped" "$upgraded" "$skipped"
