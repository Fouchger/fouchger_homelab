#!/usr/bin/env bash
# =============================================================================
# File: install.sh
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose:
#   Self-healing installer that:
#     1) Installs minimum OS prerequisites (Debian/Ubuntu apt-based)
#     2) Clones the GitHub repo (branch-aware)
#     3) Creates a Python venv and installs runtime dependencies
#     4) Launches the menu app
#
# Developer notes:
# - Designed for Ubuntu 22.04/24.04 and Debian 12.
# - Avoids hardcoding by using environment variables with safe defaults.
# - Uses sudo only when needed and available.
# - Supports repeatable runs (updates existing clone).
# =============================================================================

set -euo pipefail

# -----------------------------
# User-configurable variables
# -----------------------------
: "${FHL_REPO_URL:="https://github.com/Fouchger/fouchger_homelab.git"}"
: "${FHL_REPO_BRANCH:="dev"}"

: "${FHL_INSTALL_BASE_DIR:="$HOME/apps"}"
: "${FHL_INSTALL_DIR_NAME:="fouchger-homelab"}"

: "${FHL_PYTHON_BIN:="python3"}"
: "${FHL_VENV_DIR:=".venv"}"

# The menu app lives inside the repo under tools/fhl_menu
: "${FHL_APP_RELATIVE_DIR:="tools/fhl_menu"}"
: "${FHL_ENTRY_MODULE:="fhl_menu"}"

# Requirements file location.
#
# Folder structure options supported:
# - Preferred: requirements.txt at repo root
# - Legacy:    requirements.txt inside tools/fhl_menu
#
# You can override this if you want a non-standard layout.
: "${FHL_REQUIREMENTS_RELATIVE_PATH:="requirements.txt"}"

# Identity (display vs slug)
: "${FHL_APP_DISPLAY_NAME:="Fouchger HomeLab"}"
: "${FHL_APP_SLUG:="fouchger-homelab"}"

# Optional pip flags (private index, proxies, etc.)
: "${FHL_PIP_EXTRA_ARGS:=""}"

# -----------------------------
# Helpers
# -----------------------------
die() { echo "ERROR: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

need_sudo() {
  # True if not root
  [[ "${EUID:-$(id -u)}" -ne 0 ]]
}

sudo_cmd() {
  if need_sudo; then
    have_cmd sudo || die "sudo not found. Install sudo or run this script as root."
    echo "sudo"
  else
    echo ""
  fi
}

print_header() {
  echo "============================================================"
  echo "${FHL_APP_DISPLAY_NAME} installer"
  echo "Repo:   ${FHL_REPO_URL}"
  echo "Branch: ${FHL_REPO_BRANCH}"
  echo "Install base: ${FHL_INSTALL_BASE_DIR}"
  echo "Install dir:  ${FHL_INSTALL_BASE_DIR}/${FHL_INSTALL_DIR_NAME}"
  echo "App dir:      ${FHL_APP_RELATIVE_DIR}"
  echo "Python: ${FHL_PYTHON_BIN}"
  echo "============================================================"
}

detect_os_family() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID_LIKE:-$ID}"
    return 0
  fi
  echo "unknown"
}

apt_install_minimum() {
  local sudo_prefix
  sudo_prefix="$(sudo_cmd)"

  have_cmd apt-get || die "apt-get not found. This installer currently supports Debian/Ubuntu apt-based systems."

  echo "Installing minimum prerequisites via apt-get..."
  ${sudo_prefix} apt-get update -y
  ${sudo_prefix} apt-get install -y \
    git \
    ca-certificates \
    "${FHL_PYTHON_BIN}" \
    python3-venv \
    python3-pip
}

clone_or_update_repo() {
  local target_dir="$1"

  if [[ -d "${target_dir}/.git" ]]; then
    echo "Repo already exists. Updating..."
    git -C "${target_dir}" fetch --all --prune
    git -C "${target_dir}" checkout "${FHL_REPO_BRANCH}"
    git -C "${target_dir}" pull --ff-only
  else
    echo "Cloning repo..."
    git clone --branch "${FHL_REPO_BRANCH}" "${FHL_REPO_URL}" "${target_dir}"
  fi
}

create_or_use_venv() {
  local app_dir="$1"
  local venv_path="${app_dir}/${FHL_VENV_DIR}"

  if [[ ! -d "${venv_path}" ]]; then
    echo "Creating venv at ${venv_path}..."
    "${FHL_PYTHON_BIN}" -m venv "${venv_path}"
  fi

  # shellcheck disable=SC1091
  source "${venv_path}/bin/activate"
}

install_python_deps() {
  local repo_dir="$1"
  local app_dir="$2"
  local req_file

  # 1) Respect explicit override (relative to repo root)
  req_file="${repo_dir}/${FHL_REQUIREMENTS_RELATIVE_PATH}"

  # 2) Backwards-compatible fallback (requirements in app dir)
  if [[ ! -f "${req_file}" && -f "${app_dir}/requirements.txt" ]]; then
    req_file="${app_dir}/requirements.txt"
  fi

  [[ -f "${req_file}" ]] || die "requirements.txt not found. Looked for: ${repo_dir}/${FHL_REQUIREMENTS_RELATIVE_PATH} and ${app_dir}/requirements.txt"

  echo "Upgrading pip..."
  python -m pip install --upgrade pip wheel ${FHL_PIP_EXTRA_ARGS}

  echo "Installing runtime dependencies..."
  python -m pip install -r "${req_file}" ${FHL_PIP_EXTRA_ARGS}
}

launch_app() {
  local app_dir="$1"
  echo "Launching ${FHL_APP_DISPLAY_NAME}..."
  cd "${app_dir}"

  # Pass identity down to the app without hardcoding in code.
  export FHL_APP_DISPLAY_NAME
  export FHL_APP_SLUG

  exec python -m "${FHL_ENTRY_MODULE}"
}

# -----------------------------
# Main
# -----------------------------
print_header

os_family="$(detect_os_family)"
case "${os_family}" in
  *debian*|*ubuntu*|debian|ubuntu)
    apt_install_minimum
    ;;
  *)
    die "Unsupported OS family '${os_family}'. Currently supports Ubuntu/Debian (apt-based)."
    ;;
esac

have_cmd git || die "git still missing after install attempt."
have_cmd "${FHL_PYTHON_BIN}" || die "${FHL_PYTHON_BIN} still missing after install attempt."

mkdir -p "${FHL_INSTALL_BASE_DIR}"
TARGET_DIR="${FHL_INSTALL_BASE_DIR}/${FHL_INSTALL_DIR_NAME}"

clone_or_update_repo "${TARGET_DIR}"

APP_DIR="${TARGET_DIR}/${FHL_APP_RELATIVE_DIR}"
[[ -d "${APP_DIR}" ]] || die "App directory not found in repo at: ${APP_DIR}. Ensure you committed tools/fhl_menu."

create_or_use_venv "${APP_DIR}"
install_python_deps "${TARGET_DIR}" "${APP_DIR}"
launch_app "${APP_DIR}"
