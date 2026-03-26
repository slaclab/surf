#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
RUCKUS_DIR="${ROOT_DIR}/ruckus"
HOME_RUCKUS_DIR="${HOME}/ruckus"

echo "[surf-regress] root: ${ROOT_DIR}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[surf-regress] error: python3 is required" >&2
  exit 1
fi

if ! command -v make >/dev/null 2>&1; then
  echo "[surf-regress] error: make is required" >&2
  exit 1
fi

if ! command -v ghdl >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[surf-regress] error: ghdl is not installed.

Install it first, then rerun this script.

Examples:
  macOS (Homebrew): brew install ghdl
  Ubuntu/Debian:    sudo apt-get install -y ghdl
EOF
  exit 1
fi

if [ ! -d "${VENV_DIR}" ]; then
  echo "[surf-regress] creating virtualenv at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "[surf-regress] upgrading pip"
python -m pip install --upgrade pip

echo "[surf-regress] installing repo python requirements"
python -m pip install -r "${ROOT_DIR}/pip_requirements.txt"

if [ ! -e "${RUCKUS_DIR}" ] && [ -d "${HOME_RUCKUS_DIR}" ]; then
  echo "[surf-regress] linking existing ruckus checkout from ${HOME_RUCKUS_DIR}"
  ln -s "${HOME_RUCKUS_DIR}" "${RUCKUS_DIR}"
fi

if [ -L "${RUCKUS_DIR}" ] && [ ! -d "${RUCKUS_DIR}" ]; then
  echo "[surf-regress] removing broken ruckus symlink at ${RUCKUS_DIR}"
  rm "${RUCKUS_DIR}"
fi

if [ ! -d "${RUCKUS_DIR}" ]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "[surf-regress] error: git is required to clone ruckus" >&2
    exit 1
  fi

  echo "[surf-regress] cloning ruckus into ${RUCKUS_DIR}"
  git clone https://github.com/slaclab/ruckus.git "${RUCKUS_DIR}"
fi

if [ -f "${RUCKUS_DIR}/scripts/pip_requirements.txt" ]; then
  echo "[surf-regress] installing ruckus python requirements"
  python -m pip install -r "${RUCKUS_DIR}/scripts/pip_requirements.txt"
fi

cat <<EOF
[surf-regress] setup complete

Activate the environment with:
  source "${VENV_DIR}/bin/activate"

Then prepare HDL sources with:
  make MODULES="${ROOT_DIR}" import

Then run regressions with:
  python -m pytest -v tests/
EOF
