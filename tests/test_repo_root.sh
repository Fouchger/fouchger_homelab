#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: tests/test_repo_root.sh
# Created: 2026-01-24
# Description:
#   Lightweight self-test for resolve_repo_root in lib/common.sh.
#   Designed for CI: fast, no dependencies beyond bash and coreutils.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

fail() { echo "FAIL: $*" >&2; exit 1; }

# Load the library relative to this test file location
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TEST_DIR/.." && pwd)"

# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

# 1) Git-present path: simulate a repo by creating .git directory
root1="$tmp/repo1"
mkdir -p "$root1/.git" "$root1/a/b/c"
(
  cd "$root1/a/b/c"
  # Fake git rev-parse behaviour by stubbing git in PATH, to keep test deterministic.
  stubbin="$tmp/stubbin"
  mkdir -p "$stubbin"
  cat >"$stubbin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--show-toplevel" ]]; then
  # Print the repo root based on presence of .git up the tree (simple stub).
  dir="$PWD"
  while :; do
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      exit 0
    fi
    [[ "$dir" == "/" ]] && exit 1
    dir="${dir%/*}"
    [[ -z "$dir" ]] && dir="/"
  done
fi
exit 1
EOF
  chmod +x "$stubbin/git"
  PATH="$stubbin:$PATH"

  resolve_repo_root || fail "resolve_repo_root failed in git mode"
  [[ "${REPO_ROOT}" == "$root1" ]] || fail "expected REPO_ROOT=$root1, got $REPO_ROOT"
  [[ -f "$root1/.homelab_repo_root" ]] || fail "marker not created in git mode"
  [[ -f "$root1/.gitignore" ]] || fail ".gitignore not created in git mode"
  grep -qxF ".homelab_repo_root" "$root1/.gitignore" || fail "marker not in .gitignore"
)

# 2) No-git path: resolve by marker only
root2="$tmp/repo2"
mkdir -p "$root2/x/y/z"
: >"$root2/.homelab_repo_root"
(
  cd "$root2/x/y/z"
  # Ensure no git is available in PATH for this subshell
  PATH="/nonexistent"

  resolve_repo_root || fail "resolve_repo_root failed in marker mode"
  [[ "${REPO_ROOT}" == "$root2" ]] || fail "expected REPO_ROOT=$root2, got $REPO_ROOT"
)

echo "PASS: resolve_repo_root"
