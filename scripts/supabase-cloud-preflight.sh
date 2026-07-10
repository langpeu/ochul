#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
FUNCTION_NAME="${SUPABASE_FUNCTION_NAME:-edge-api}"

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI is not installed." >&2
  exit 1
fi

if ! command -v deno >/dev/null 2>&1; then
  echo "deno is not installed." >&2
  exit 1
fi

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "SUPABASE_ACCESS_TOKEN is required for Cloud preflight." >&2
  echo "Run 'supabase login' locally or export SUPABASE_ACCESS_TOKEN." >&2
  exit 1
fi

if [[ -z "${PROJECT_REF}" ]]; then
  echo "SUPABASE_PROJECT_REF is required." >&2
  exit 1
fi

if [[ ! -f "supabase/config.toml" ]]; then
  echo "supabase/config.toml is missing. Run 'supabase init' locally first." >&2
  exit 1
fi

echo "Checking Supabase project access..."
supabase projects list >/dev/null

echo "Linking Supabase project ${PROJECT_REF}..."
supabase link --project-ref "${PROJECT_REF}"

echo "Checking pending database migrations..."
supabase db push --dry-run

echo "Checking Edge Function TypeScript..."
deno fmt --check "supabase/functions/${FUNCTION_NAME}/index.ts"
deno check "supabase/functions/${FUNCTION_NAME}/index.ts"

if [[ "${DEPLOY_EDGE_FUNCTION:-0}" == "1" ]]; then
  echo "Deploying Edge Function ${FUNCTION_NAME}..."
  supabase functions deploy "${FUNCTION_NAME}" --project-ref "${PROJECT_REF}" --use-api
else
  echo "Skipping Edge Function deploy. Set DEPLOY_EDGE_FUNCTION=1 to deploy."
fi
