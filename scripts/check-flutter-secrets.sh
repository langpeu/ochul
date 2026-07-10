#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

allowed_keys=(
  "SUPABASE_URL"
  "SUPABASE_ANON_KEY"
  "SUPABASE_PUBLISHABLE_KEY"
  "AUTH_REDIRECT_URL"
  "APP_ENV"
)

is_allowed_key() {
  local key="$1"
  for allowed in "${allowed_keys[@]}"; do
    if [[ "${key}" == "${allowed}" ]]; then
      return 0
    fi
  done
  return 1
}

check_file() {
  local file="$1"
  local failed=0
  local line key

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "${line}" || "${line}" == \#* ]] && continue

    if [[ "${line}" != *=* ]]; then
      echo "${file}: invalid line without '=': ${line}" >&2
      failed=1
      continue
    fi

    key="${line%%=*}"
    key="${key%"${key##*[![:space:]]}"}"
    if ! is_allowed_key "${key}"; then
      echo "${file}: '${key}' is not allowed in Flutter dart-define secrets." >&2
      failed=1
    fi
  done < "${file}"

  return "${failed}"
}

files=(
  "apps/tablet_app/Secrets.dev.example.config"
  "apps/tablet_app/Secrets.prod.example.config"
)

[[ -f "apps/tablet_app/Secrets.dev.config" ]] && files+=("apps/tablet_app/Secrets.dev.config")
[[ -f "apps/tablet_app/Secrets.prod.config" ]] && files+=("apps/tablet_app/Secrets.prod.config")

failed=0
for file in "${files[@]}"; do
  check_file "${file}" || failed=1
done

if [[ "${failed}" -ne 0 ]]; then
  echo "Flutter Secrets files may only contain client-safe dart-define keys." >&2
  exit 1
fi

echo "Flutter Secrets files contain only client-safe keys."
