#!/usr/bin/env bash
set -euo pipefail

# ---- Config ---------------------------------------------------------------
INITIAL_VERSION="v0.1.0"                 # starting version if no prior tag
PATCH_TYPES_EXTRAS="refactor docs chore test build ci style"
RELEASE_BRANCH="main"

# ---- Args -----------------------------------------------------------------
DRY_RUN=false
if [[ "${1-}" == "-n" || "${1-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

# ---- Helpers --------------------------------------------------------------
normalize_semver() {
  local v="$1"
  if [[ "$v" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    [[ "$v" == v* ]] || v="v${v}"
    echo "$v"
  else
    echo "Invalid semver: $v" >&2
    return 1
  fi
}

bump_semver() {
  # bump_semver v1.2.3 major|minor|patch
  local ver="$1"; local part="$2"
  ver=$(normalize_semver "$ver")
  local base="${ver#v}"
  IFS='.' read -r MAJ MIN PAT <<< "$base"
  case "$part" in
    major) ((MAJ+=1)); MIN=0; PAT=0 ;;
    minor) ((MIN+=1)); PAT=0 ;;
    patch) ((PAT+=1)) ;;
    *) echo "Unknown bump: $part" >&2; return 1 ;;
  esac
  echo "v${MAJ}.${MIN}.${PAT}"
}

latest_tag_or_empty() {
  git describe --tags --abbrev=0 2>/dev/null || true
}

commits_since() {
  local last="$1"
  if [[ -z "$last" ]]; then
    git log --pretty='%H%x09%s' --no-merges
  else
    git log "${last}..HEAD" --pretty='%H%x09%s' --no-merges
  fi
}

commit_messages_since() {
  local last="$1"
  if [[ -z "$last" ]]; then
    git log --format='%s%n%b' --no-merges
  else
    git log "${last}..HEAD" --format='%s%n%b' --no-merges
  fi
}

decide_bump_from_commits() {
  # Reads commit messages on stdin, prints: major|minor|patch|none
  local content
  content="$(cat)"

  # major: breaking change
  if echo "$content" | grep -Ei '^.*!:' >/dev/null 2>&1 \
     || echo "$content" | grep -Eqi '(^|\n)BREAKING CHANGE:' ; then
    echo major; return
  fi

  # minor: feat
  if echo "$content" | grep -Eqi '(^|\n)feat(\([^)]+\))?:' ; then
    echo minor; return
  fi

  # patch: fix or perf
  if echo "$content" | grep -Eqi '(^|\n)fix(\([^)]+\))?:' \
     || echo "$content" | grep -Eqi '(^|\n)perf(\([^)]+\))?:' ; then
    echo patch; return
  fi

  # extras as patch
  for t in $PATCH_TYPES_EXTRAS; do
    if echo "$content" | grep -Eqi "(^|\n)${t}(\([^)]+\))?:" ; then
      echo patch; return
    fi
  done

  echo none
}

# ---- Main -----------------------------------------------------------------
git fetch --all --prune
git switch "$RELEASE_BRANCH" >/dev/null 2>&1 || git checkout "$RELEASE_BRANCH"
git pull --ff-only
git diff --quiet && git diff --cached --quiet || { echo "⛔ Working tree not clean."; exit 1; }

LAST_TAG="$(latest_tag_or_empty)"

COMMITS_LIST="$(commits_since "$LAST_TAG")"            # short list with SHAs
COMMITS_MSGS="$(commit_messages_since "$LAST_TAG")"    # full messages

if [[ -z "$LAST_TAG" ]]; then
  echo "ℹ️  No previous tag found. Will start at $INITIAL_VERSION."
fi

BUMP="$(printf "%s" "$COMMITS_MSGS" | decide_bump_from_commits)"

if [[ "$BUMP" == "none" ]]; then
  if [[ -z "$COMMITS_LIST" ]]; then
    echo "⛔ No commits to release since last tag. Aborting."
    exit 1
  fi
  BUMP="patch"
fi

CURRENT="${LAST_TAG:-v0.0.0}"
NEXT="$(bump_semver "$CURRENT" "$BUMP")"

# Summary
COMMITS_COUNT=$(printf "%s\n" "$COMMITS_LIST" | grep -c . || true)
echo "Last tag: ${LAST_TAG:-<none>}"
echo "Commits since: $COMMITS_COUNT"
echo "Bump: $BUMP"
echo "Next version: $NEXT"

# Show commits (compact)
if [[ -n "$COMMITS_LIST" ]]; then
  echo ""
  echo "Commits to include:"
  printf "%s\n" "$COMMITS_LIST"
  echo ""
fi

if $DRY_RUN; then
  echo "🔎 DRY-RUN: would tag '$NEXT', push, then run scripts/promote-to-prod.sh"
  exit 0
fi

# Create annotated tag on HEAD (must be the intended release commit)
git tag -a "$NEXT" -m "Release $NEXT"
# git push origin "$RELEASE_BRANCH"
git push origin "$NEXT"

# Hand off to your promote script (requires HEAD at the tag)
scripts/promote-to-prod.sh

