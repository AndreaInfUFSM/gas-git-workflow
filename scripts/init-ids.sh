#!/usr/bin/env bash
set -euo pipefail

read -rp "Enter DEV scriptId: " DEV
read -rp "Enter PROD scriptId: " PROD

# Basic sanity: non-empty and looks like Apps Script ID (AKfy… style is common but not guaranteed).
[[ -n "$DEV" && -n "$PROD" ]] || { echo "⛔ IDs cannot be empty"; exit 1; }

# Replace placeholders
sed -i.bak "s|__DEV_SCRIPT_ID__|$DEV|g" .clasp.dev.json
sed -i.bak "s|__PROD_SCRIPT_ID__|$PROD|g" .clasp.prod.json
rm -f .clasp.dev.json.bak .clasp.prod.json.bak

echo "✅ IDs saved to .clasp.dev.json and .clasp.prod.json"

# Optional quick check (no effect on your repo state)
if command -v npx >/dev/null 2>&1; then
  echo "ℹ️ Verifying DEV access (clasp pull to temp)…"
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  cp .clasp.dev.json "$tmp/.clasp.json"
  ( cd "$tmp" && npx -y @google/clasp@latest pull --force >/dev/null ) \
    && echo "   ✓ DEV reachable" || echo "   ⚠️ Could not pull DEV (check login/permissions)"
fi

