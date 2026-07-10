#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not installed." >&2
  exit 1
fi

if ! command -v deno >/dev/null 2>&1; then
  echo "deno is not installed." >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep is not installed." >&2
  exit 1
fi

echo "Checking Flutter formatting..."
(cd apps/tablet_app && dart format --set-exit-if-changed lib test)

echo "Running Flutter analyzer..."
(cd apps/tablet_app && flutter analyze)

echo "Running Flutter tests..."
(cd apps/tablet_app && flutter test)

echo "Checking Edge Function formatting..."
deno fmt --check supabase/functions/edge-api/index.ts

echo "Checking Edge Function types..."
deno check supabase/functions/edge-api/index.ts

echo "Checking local secret ignore rules..."
git check-ignore -v apps/tablet_app/Secrets.dev.config >/dev/null
git check-ignore -v apps/tablet_app/Secrets.prod.config >/dev/null
git check-ignore -v supabase/functions/.env >/dev/null
git check-ignore -v supabase/config.toml >/dev/null

echo "Checking Flutter Secrets allowlist..."
scripts/check-flutter-secrets.sh

echo "Checking Flutter direct DB access guard..."
if rg -n "\.from\(|\.rpc\(|Postgrest|select\(|insert\(|update\(" \
  apps/tablet_app/lib apps/tablet_app/test; then
  echo "Flutter code must call Edge Functions, not Supabase tables/RPC directly." >&2
  exit 1
fi

echo "Scanning for committed secret-like values..."
if rg -n --hidden \
  --glob '!.git/**' \
  --glob '!.github/workflows/ci.yml' \
  --glob '!docs/ci/github-actions-ci.yml' \
  --glob '!scripts/validate.sh' \
  --glob '!apps/tablet_app/Secrets.dev.config' \
  --glob '!apps/tablet_app/Secrets.prod.config' \
  "(eyJ[A-Za-z0-9_-]{20,}|s[k]-[A-Za-z0-9]|BEGIN [A-Z ]+PRIVATE KEY|PRIVATE KEY-----)" .; then
  echo "Secret-like value found in tracked files." >&2
  exit 1
fi

echo "Checking access metadata storage guard..."
matches="$(
  rg -n --glob '!docs/ci/github-actions-ci.yml' \
    --glob '!scripts/validate.sh' \
    "\bip\b|device|user_agent|user agent|기기 식별자" \
    supabase/migrations supabase/functions docs apps/tablet_app/lib || true
)"
if [[ -n "${matches}" ]]; then
  echo "${matches}"
fi
if echo "${matches}" | rg -v \
  "저장하지 않는다|저장 코드 없음|같은 불필요한 접속 정보는 저장하지 않는다|감사 로그에는 IP" >/dev/null; then
  echo "Unexpected IP/device/user-agent storage reference found." >&2
  exit 1
fi

echo "Checking whitespace errors..."
git diff --check

echo "Validation complete."
