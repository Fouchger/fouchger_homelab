#!/usr/bin/env bash
# fouchger_homelab installer
# Notes:
# - Installs into: $HOME/app/fouchger_homelab
# - Use -b to switch branches for testing
# - Logs/config/state/runs are created under the install directory
set -euo pipefail

clear
echo "================================================================="
echo "                                                                 "
echo "            Fouchger Homelab                                     "
echo "                                                                 "
echo "================================================================="
echo "                                                                 "

REPO_URL="https://github.com/Fouchger/fouchger_homelab.git"
APP_NAME="fouchger_homelab"
BRANCH="20260206"
BASE_DIR="${HOME}/app"
INSTALL_DIR="${BASE_DIR}/${APP_NAME}"

usage() {
  cat <<EOF
Usage: $0 [-b branch]
  -b   Git branch or tag to install (default: main)

Examples:
  $0
  $0 -b feature/new-ui
EOF
}

while getopts ":b:h" opt; do
  case "${opt}" in
    b) BRANCH="${OPTARG}" ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; usage; exit 2 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; usage; exit 2 ;;
  esac
done

mkdir -p "${BASE_DIR}"

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  echo "Updating existing install at ${INSTALL_DIR}"
  git -C "${INSTALL_DIR}" fetch --all --tags
  git -C "${INSTALL_DIR}" checkout "${BRANCH}"
  git -C "${INSTALL_DIR}" pull --ff-only
else
  echo "Cloning ${REPO_URL} into ${INSTALL_DIR}"
  git clone --branch "${BRANCH}" --depth 1 "${REPO_URL}" "${INSTALL_DIR}"
fi

mkdir -p "${INSTALL_DIR}/config" "${INSTALL_DIR}/state" "${INSTALL_DIR}/logs" "${INSTALL_DIR}/runs"

if [[ ! -d "${INSTALL_DIR}/.venv" ]]; then
  python3 -m venv "${INSTALL_DIR}/.venv"
fi

# shellcheck disable=SC1091
source "${INSTALL_DIR}/.venv/bin/activate"
python -m pip install --upgrade pip wheel setuptools

# Install the app package (expects pyproject.toml as below)
pip install -e "${INSTALL_DIR}"

cat <<EOF

Installed ${APP_NAME} into:
  ${INSTALL_DIR}

Run:
  ${INSTALL_DIR}/.venv/bin/fouchger-homelab

Optional (web access):
  textual serve -c ${INSTALL_DIR} ${INSTALL_DIR}/.venv/bin/fouchger-homelab

EOF
