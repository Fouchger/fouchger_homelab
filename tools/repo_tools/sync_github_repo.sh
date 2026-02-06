#!/usr/bin/env bash
# ============================================================
# Script: sync_github_repo.sh
# Purpose:
#   - Clone a GitHub repo from a specified branch (default: main)
#   - DEV folder: clone only if it does not exist
#   - TEST folder: always overwritten (deleted and re-cloned)
#
# Requirements:
#   - git installed
#   - network access to GitHub
# ============================================================

set -euo pipefail

# ---------------------------
# Configuration (variables)
# ---------------------------

# GitHub repo in "owner/repo" format
OWNER="Fouchger"
REPO="fouchger_homelab"
REPO_SLUG="${OWNER}/${REPO}"


# Branch to clone (default is main if empty)
BRANCH="${BRANCH:-20250205}"

# Base folder where dev and test folders will live
BASE_FOLDER_DEV="${HOME}/Fouchger"
BASE_FOLDER_TEST="${HOME}"

# Dev and test folder names (created under BASE_FOLDER)
DEV_FOLDER_NAME="${REPO}_${BRANCH}"
TEST_FOLDER_NAME="${REPO}_${BRANCH}"

# Use SSH clone if true, otherwise HTTPS
USE_SSH="false"

# Optional: shallow clone (faster, less history). Set to "true" or "false"
SHALLOW_CLONE="false"

# ---------------------------
# Derived values
# ---------------------------
DEV_PATH="${BASE_FOLDER_DEV}/${DEV_FOLDER_NAME}"
TEST_PATH="${BASE_FOLDER_TEST}/${TEST_FOLDER_NAME}"

if [[ -z "${BRANCH}" ]]; then
  BRANCH="main"
fi

if [[ "${USE_SSH}" == "true" ]]; then
  REPO_URL="git@github.com:${REPO_SLUG}.git"
else
  REPO_URL="https://github.com/${REPO_SLUG}.git"
fi

# ---------------------------
# Helper functions
# ---------------------------
require_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed or not on PATH. Install git and try again." >&2
    exit 1
  fi
}

ensure_folder() {
  local path="$1"
  mkdir -p "${path}"
}

clone_repo() {
  local url="$1"
  local branch="$2"
  local dest="$3"

  if [[ "${SHALLOW_CLONE}" == "true" ]]; then
    git clone --depth 1 --branch "${branch}" --single-branch "${url}" "${dest}"
  else
    git clone --branch "${branch}" --single-branch "${url}" "${dest}"
  fi
}

# ---------------------------
# Main
# ---------------------------
require_git
ensure_folder "${BASE_FOLDER}"

echo "Repo:   ${REPO_URL}"
echo "Branch: ${BRANCH}"
echo "Dev:    ${DEV_PATH}"
echo "Test:   ${TEST_PATH}"
echo

# DEV: only download if it doesn't exist
if [[ -d "${DEV_PATH}" ]]; then
  echo "Dev folder already exists, skipping download: ${DEV_PATH}"
else
  echo "Cloning to dev (only if not exists)..."
  clone_repo "${REPO_URL}" "${BRANCH}" "${DEV_PATH}"
  echo "Dev clone complete."
fi

# TEST: always overwrite by removing then cloning again
if [[ -d "${TEST_PATH}" ]]; then
  echo "Removing existing test folder to ensure overwrite..."
  rm -rf "${TEST_PATH}"
fi

echo "Cloning to test (always overwrite)..."
clone_repo "${REPO_URL}" "${BRANCH}" "${TEST_PATH}"
echo "Test clone complete."

echo
echo "Done."
