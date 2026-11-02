#!/usr/bin/env bash
set -euo pipefail

component="${1:?usage: check-compatibility.sh <component>}"
case "${component}" in
  core|vault|node|contracts|clients|deploy) ;;
  *)
    echo "::error::Unsupported component: ${component}"
    exit 1
    ;;
esac

manifest_for() {
  local target="$1"
  if [[ "${component}" == "${target}" ]]; then
    printf 'caller/compatibility/kerosene.json'
  else
    printf 'ecosystem/%s/compatibility/kerosene.json' "${target}"
  fi
}

validate_manifest() {
  local manifest="$1"
  local expected_component="$2"

  if [[ ! -f "${manifest}" ]]; then
    echo "::error file=${manifest}::Compatibility manifest is missing"
    return 1
  fi

  jq -e --arg component "${expected_component}" '
    def semver:
      type == "string"
      and test("^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?$");
    .schema_version == 1
    and .component == $component
    and (.contracts | type == "object")
    and (.contracts.provides | type == "array")
    and (.contracts.accepts | type == "array")
    and all(.contracts.provides[]; semver)
    and all(.contracts.accepts[]; semver)
    and ((.contracts.provides | length) == (.contracts.provides | unique | length))
    and ((.contracts.accepts | length) == (.contracts.accepts | unique | length))
    and (
      if $component == "contracts"
      then (.contracts.provides | length) > 0
      else (.contracts.accepts | length) > 0
      end
    )
  ' "${manifest}" >/dev/null || {
    echo "::error file=${manifest}::Invalid compatibility manifest"
    return 1
  }
}

assert_compatible() {
  local provider_manifest="$1"
  local consumer_manifest="$2"
  local consumer="$3"

  if ! jq -n -e \
    --slurpfile provider "${provider_manifest}" \
    --slurpfile consumer_manifest "${consumer_manifest}" '
      [
        $provider[0].contracts.provides[] as $version
        | select($consumer_manifest[0].contracts.accepts | index($version))
      ] | length > 0
    ' >/dev/null; then
    local provided accepted
    provided="$(jq -c '.contracts.provides' "${provider_manifest}")"
    accepted="$(jq -c '.contracts.accepts' "${consumer_manifest}")"
    echo "::error::${consumer} accepts ${accepted}, but Contracts provides ${provided}"
    return 1
  fi
}

contracts_manifest="$(manifest_for contracts)"
validate_manifest "${contracts_manifest}" contracts

for consumer in core vault node clients; do
  consumer_manifest="$(manifest_for "${consumer}")"
  validate_manifest "${consumer_manifest}" "${consumer}"
  assert_compatible "${contracts_manifest}" "${consumer_manifest}" "${consumer}"
done

if [[ "${component}" == "deploy" ]]; then
  deploy_manifest="$(manifest_for deploy)"
  validate_manifest "${deploy_manifest}" deploy
  assert_compatible "${contracts_manifest}" "${deploy_manifest}" deploy
fi

echo "All checked repositories share at least one contract version."
