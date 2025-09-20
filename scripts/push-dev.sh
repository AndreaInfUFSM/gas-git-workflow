#!/usr/bin/env bash
set -euo pipefail

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
# Only auto-push GAS on these branches; adjust as you like:
if ! echo "$BRANCH" | grep -Eq '^(dev|main)$'; then
  exit 0
fi

# If .clasp.dev.json drives DEV, point .clasp.json to it
if [ -f .clasp.dev.json ]; then
  cp .clasp.dev.json .clasp.json
  # Validate placeholder not present
  if grep -q "__DEV_SCRIPT_ID__" .clasp.json; then
    echo "⛔ DEV scriptId not set. Run scripts/init-ids.sh first." >&2
    exit 1
  fi
fi

# If clasp isn't available/configured, don't block git push
if ! command -v npx >/dev/null 2>&1; then
  echo "⚠️  npx not found; skipping clasp push."
  exit 0
fi

# Optional: warn about unstaged changes in trigger paths
TRIGGERS_REGEX='^(src/|appsscript\.json$)'
UNSTAGED="$(git diff --name-only | grep -E "$TRIGGERS_REGEX" || true)"
if [ -n "$UNSTAGED" ]; then
  echo "⚠️  Unstaged changes in GAS files:"
  echo "$UNSTAGED" | sed 's/^/   - /'
  echo "    (These will NOT be in this clasp push.)"
fi

echo "↗️  Always pushing DEV GAS from branch $BRANCH..."


# Push; block git push if it fails (so DEV doesn’t silently desync)
npx clasp push --force || { echo "⛔ clasp push failed. Aborting git push."; exit 1; }
echo "✅ clasp push successful."
