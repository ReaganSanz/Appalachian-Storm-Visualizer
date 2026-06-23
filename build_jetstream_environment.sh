#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# Pretty printing helpers (same style)
# ----------------------------------------

function generate_separator {
  local max_len=0
  for arg in "$@"; do
    ((${#arg} > max_len)) && max_len=${#arg}
  done

  local spaces
  printf -v spaces "%${max_len}s" ""
  echo "${spaces// /=}"
}

function print_separated_message {
  local sep
  sep=$(generate_separator "$@")

  echo "$sep"
  for line in "$@"; do
    echo "$line"
  done
  echo "$sep"
}

function die {
  echo "ERROR: $*" >&2
  exit 1
}

function step {
  # Usage: step "1/7" "Message"
  print_separated_message "[${1}] ${2}"
}

# ----------------------------------------
# Static settings (change only if needed)
# ----------------------------------------

ENV_NAME="nsdf-scivis"
KERNEL_NAME="nsdf-scivis"
KERNEL_DISPLAY='Python (NSDF-SciVis)'

# ----------------------------------------
# Derived paths
# ----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ----------------------------------------
# 0) Ensure conda is available
# ----------------------------------------
step "0/4" "Checking conda availability"

if command -v module >/dev/null 2>&1; then
  # Jetstream module environment
  module purge >/dev/null 2>&1 || true
  module load miniforge >/dev/null 2>&1 || true
fi
command -v conda >/dev/null 2>&1 || die "conda not found. Did you 'module load miniforge'?"

# Make conda activate work in scripts
# shellcheck disable=SC1090
source "$(conda info --base)/etc/profile.d/conda.sh"

# ----------------------------------------
# 1) Create env from environment.yml (replace if exists)
# ----------------------------------------
step "1/4" "Create env from environment.yml (name: ${ENV_NAME})"

if conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  echo "Removing existing env: ${ENV_NAME}"
  conda env remove -n "$ENV_NAME" -y >/dev/null
fi

conda env create -f environment.yml >/dev/null

# ----------------------------------------
# 2) Activate environment
# ----------------------------------------
step "2/4" "Activate env: ${ENV_NAME}"

conda activate "$ENV_NAME"
hash -r

# ----------------------------------------
# 3) Verify activation (hard fail if wrong)
# ----------------------------------------
step "3/4" "Verify activation"

python - <<PY
import os, sys
env = os.environ.get("CONDA_DEFAULT_ENV")
prefix = os.environ.get("CONDA_PREFIX")
print("CONDA_DEFAULT_ENV:", env)
print("CONDA_PREFIX:", prefix)
print("sys.executable:", sys.executable)
if env != "$ENV_NAME":
    raise SystemExit(f"ERROR: expected CONDA_DEFAULT_ENV=$ENV_NAME but got {env}")
PY

# ----------------------------------------
# 7) Install ipykernel + register kernel
# ----------------------------------------

step "4/4" "Install Jupyter kernel + extras"

# keep these visible enough to diagnose, but not too noisy
ENV_BIN_DIR="$CONDA_PREFIX/bin"

python -m ipykernel install --user \
  --name "$KERNEL_NAME" \
  --display-name "$KERNEL_DISPLAY" \

print_separated_message \
  "DONE" \
  "" \
  "Environment:" \
  "  conda activate ${ENV_NAME}" \
  "" \
  "Kernel:" \
  "  jupyter kernelspec list" \
  "  (look for '${KERNEL_DISPLAY}')"
