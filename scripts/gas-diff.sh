#!/usr/bin/env bash
set -euo pipefail

# gas-diff.sh — quick CLI diff for Google Apps Script projects
# Modes:
#   1) IDs:   gas-diff.sh --ids <SCRIPT_ID_A> <SCRIPT_ID_B>
#   2) DIRs:  gas-diff.sh --dirs <DIR_A> <DIR_B>
# Options:
#   --names-only | --list   Print only file names with A/M/D status
#
# Requirements for --ids: npx + clasp (logged in)

usage() {
  cat <<EOF
Usage:
  $0 --ids <SCRIPT_ID_A> <SCRIPT_ID_B> [--names-only]
  $0 --dirs <DIR_A> <DIR_B>            [--names-only]

Notes:
  - For --ids, the current HEAD of each GAS project is pulled to temp dirs via clasp.
  - Excludes: .git, node_modules, dist, build, .DS_Store, package-lock.json, yarn.lock
  - Status meanings (A/M/D) are from A -> B perspective:
      A  file exists only in B (added)
      D  file exists only in A (deleted)
      M  file exists in both but differs
EOF
}

# ------------------ args ------------------
MODE=""
SID_A=""; SID_B=""
DIR_A=""; DIR_B=""
NAMES_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ids)  MODE="ids";  SID_A="${2:-}"; SID_B="${3:-}"; shift 3 ;;
    --dirs) MODE="dirs"; DIR_A="${2:-}"; DIR_B="${3:-}"; shift 3 ;;
    --names-only|--list) NAMES_ONLY=true; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

if [[ "$MODE" == "ids" && ( -z "${SID_A:-}" || -z "${SID_B:-}" ) ]]; then usage; exit 1; fi
if [[ "$MODE" == "dirs" && ( -z "${DIR_A:-}" || -z "${DIR_B:-}" ) ]]; then usage; exit 1; fi
if [[ -z "$MODE" ]]; then usage; exit 1; fi

command -v diff >/dev/null 2>&1 || { echo "diff not found"; exit 1; }

# ------------------ helpers ------------------
HAS() { command -v "$1" >/dev/null 2>&1; }

TMP_ROOT=""
cleanup() { [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]] && rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

make_pull_dir() {
  local sid="$1"
  local d
  d="$(mktemp -d -t gasdiff-XXXXXXXX)" || { echo "mktemp failed"; exit 1; }
  cat >"$d/.clasp.json" <<JSON
{"scriptId":"$sid","rootDir":"."}
JSON
  pushd "$d" >/dev/null
  npx -y clasp pull --force >/dev/null
  popd >/dev/null
  echo "$d"
}

# Excludes for both modes
EXCLUDES=(-x '.git' -x 'node_modules' -x 'dist' -x 'build' -x '.DS_Store' -x 'package-lock.json' -x 'yarn.lock')

abspath() { realpath -s "$1"; }

ensure_dirs() {
  local A="$1" B="$2"
  [[ -d "$A" ]] || { echo "⛔ Not a directory: $A"; exit 1; }
  [[ -d "$B" ]] || { echo "⛔ Not a directory: $B"; exit 1; }
  [[ "$A" != "$B" ]] || { echo "⛔ Both paths resolve to the same directory."; exit 1; }
}

names_only_diff() {
  # Print A/M/D and relative paths using diff -qr output
  local A="$1" B="$2"
  diff -qr "${EXCLUDES[@]}" "$A" "$B" | \
  awk -v Aroot="$A" -v Broot="$B" '
    BEGIN {
      # ensure trailing slashes
      if (Aroot !~ /\/$/) Aroot=Aroot"/";
      if (Broot !~ /\/$/) Broot=Broot"/";
    }
    /^Only in / {
      # "Only in <DIR>: <file>"
      match($0, /^Only in (.*): (.*)$/, m);
      parent=m[1]; fname=m[2];
      if (substr(parent,1,length(Aroot))==Aroot) {
        rel=substr(parent, length(Aroot)+1); if (rel=="") rel=".";
        print "D\t" rel "/" fname;
      } else if (substr(parent,1,length(Broot))==Broot) {
        rel=substr(parent, length(Broot)+1); if (rel=="") rel=".";
        print "A\t" rel "/" fname;
      }
      next;
    }
    /^Files / && / differ$/ {
      # "Files <A>/<p> and <B>/<p> differ"
      match($0, /^Files (.*) and (.*) differ$/, m);
      fA=m[1]; fB=m[2];
      if (substr(fA,1,length(Aroot))==Aroot) {
        rel=substr(fA, length(Aroot)+1);
      } else if (substr(fB,1,length(Broot))==Broot) {
        rel=substr(fB, length(Broot)+1);
      } else {
        rel=fA;
      }
      print "M\t" rel;
      next;
    }
  ' | sort -k1,1 -k2,2
}

full_diff() {
  local A="$1" B="$2"
  diff -ruN "${EXCLUDES[@]}" "$A" "$B" | colordiff | less -R || true
}

run_dirs() {
  local A="$(abspath "$1")"
  local B="$(abspath "$2")"
  echo "A: $A"
  echo "B: $B"
  ensure_dirs "$A" "$B"

  if $NAMES_ONLY; then
    names_only_diff "$A" "$B"
  else
    full_diff "$A" "$B"
  fi
}

# ------------------ main ------------------
if [[ "$MODE" == "ids" ]]; then
  HAS npx || { echo "npx not found"; exit 1; }
  npx -y clasp --version >/dev/null 2>&1 || { echo "clasp not available via npx"; exit 1; }

  TMP_ROOT="$(mktemp -d -t gasdiffroot-XXXXXXXX)"
  PULL_A="$(make_pull_dir "$SID_A")"
  PULL_B="$(make_pull_dir "$SID_B")"

  echo "Pulled:"
  echo "  A (scriptId=$SID_A) → $PULL_A"
  echo "  B (scriptId=$SID_B) → $PULL_B"
  echo ""

  run_dirs "$PULL_A" "$PULL_B"
else
  run_dirs "$DIR_A" "$DIR_B"
fi
