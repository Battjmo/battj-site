#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    key="${line%%=*}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ -z "$key" ]] && continue
    value="${line#*=}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    if [[ -z "${!key:-}" ]]; then
      export "$key=$value"
    fi
  done < "$ROOT_DIR/.env"
fi

PROJECT_NAME="${PAGES_PROJECT_NAME:-battj-site}"
BUN_VERSION="${BUN_VERSION:-$(sed -n 's/.*bun@//p' "$ROOT_DIR/package.json" | head -n1)}"
NODE_VERSION="${NODE_VERSION:-$(tr -d '[:space:]' < "$ROOT_DIR/.node-version")}"
BUILD_COMMAND="${PAGES_BUILD_COMMAND:-bun run build}"
DESTINATION_DIR="${PAGES_DESTINATION_DIR:-dist}"

: "${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID in the environment or .env}"
: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN in the environment or .env}"

if [[ -z "$BUN_VERSION" ]]; then
  echo "Could not determine Bun version from package.json packageManager field." >&2
  exit 1
fi

if [[ -z "$NODE_VERSION" ]]; then
  echo "Could not determine Node version from .node-version." >&2
  exit 1
fi

payload="$(cat <<EOF
{
  "build_config": {
    "build_command": "$BUILD_COMMAND",
    "destination_dir": "$DESTINATION_DIR"
  },
  "deployment_configs": {
    "production": {
      "env_vars": {
        "SKIP_DEPENDENCY_INSTALL": {
          "type": "plain_text",
          "value": "true"
        },
        "BUN_VERSION": {
          "type": "plain_text",
          "value": "$BUN_VERSION"
        },
        "NODE_VERSION": {
          "type": "plain_text",
          "value": "$NODE_VERSION"
        }
      }
    },
    "preview": {
      "env_vars": {
        "SKIP_DEPENDENCY_INSTALL": {
          "type": "plain_text",
          "value": "true"
        },
        "BUN_VERSION": {
          "type": "plain_text",
          "value": "$BUN_VERSION"
        },
        "NODE_VERSION": {
          "type": "plain_text",
          "value": "$NODE_VERSION"
        }
      }
    }
  }
}
EOF
)"

response="$(
  curl -fsS \
    -X PATCH \
    "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${PROJECT_NAME}" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$payload"
)"

if command -v jq >/dev/null 2>&1; then
  if ! jq -e '.success == true' <<<"$response" >/dev/null; then
    echo "Cloudflare API request failed:" >&2
    jq . <<<"$response" >&2
    exit 1
  fi

  echo "Configured Cloudflare Pages project: $PROJECT_NAME"
  jq -r '
    "Build command: \(.result.build_config.build_command)",
    "Output dir: \(.result.build_config.destination_dir)"
  ' <<<"$response"
else
  echo "$response"
  echo "Configured Cloudflare Pages project: $PROJECT_NAME"
fi
