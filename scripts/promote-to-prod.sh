#!/usr/bin/env bash
set -euo pipefail

# --- Safety: branch & cleanliness
git fetch --all --prune
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "main" || "$BRANCH" == "master" ]] || { echo "⛔ Promote only from main/master (current: $BRANCH)"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "⛔ Working tree not clean."; exit 1; }

# --- Require HEAD to be an annotated tag
HEAD_TAG=$(git describe --tags --exact-match 2>/dev/null || true)
[[ -n "$HEAD_TAG" ]] || { echo "⛔ HEAD is not exactly at a tag. Tag this commit (e.g., v1.4.0) and try again."; exit 1; }

# Verify it’s annotated (not lightweight)
git for-each-ref "refs/tags/$HEAD_TAG" --format="%(taggername)" | grep . >/dev/null || {
  echo "⛔ Tag '$HEAD_TAG' is lightweight. Use annotated tags (git tag -a ...)."; exit 1;
}

echo "🏷️ Promoting tag: $HEAD_TAG"

# --- Point clasp to PROD
cp .clasp.prod.json .clasp.json
if grep -q "__PROD_SCRIPT_ID__" .clasp.json; then
  echo "⛔ PROD scriptId not set. Run scripts/init-ids.sh first." >&2
  exit 1
fi

# --- Push code
npx clasp push --force
echo "✅ Code pushed to PROD scriptId."

# --- Create a GAS version with the tag as note
NOTE="Release $HEAD_TAG"
npx clasp version "$NOTE" >/dev/null
echo "📦 Created GAS version: $NOTE"
echo "🎯 Promotion complete."

