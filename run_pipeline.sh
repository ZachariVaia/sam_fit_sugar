#!/usr/bin/env bash
set -euo pipefail

# --- args / dataset name (accept env or $1) ---
DATASET_NAME="${DATASET_NAME:-${1:-}}"
: "${DATASET_NAME:?Usage: $0 DATASET_NAME  (or export DATASET_NAME first)}"

# --- resolve repo paths early ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAM_FIT_SUGAR_PATH="${SAM_FIT_SUGAR_PATH:-$SCRIPT_DIR}"
SAM2_DOCKER_PATH="${SAM2_DOCKER_PATH:-${SAM_FIT_SUGAR_PATH}/SAM2-Docker}"
SUGAR_DOCKER_PATH="${SUGAR_DOCKER_PATH:-${SAM_FIT_SUGAR_PATH}/SuGaR}"

# --- logging (after we know DATASET_NAME) ---
LOGDIR="$SAM_FIT_SUGAR_PATH/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/${DATASET_NAME}_$(date +%Y%m%d_%H%M%S).log"

# Keep original stdout/stderr
exec 3>&1 4>&2
restore_fds() { exec 1>&3 2>&4; }

on_error() {
  restore_fds
  echo "STATUS: ERROR" >&2
  echo "LOG: $LOGFILE" >&2
  exit 1
}
trap on_error ERR
trap restore_fds EXIT

# From here on, tee output to log (and keep it on console too)
exec >"$LOGFILE" 2>&1


# echo "[*] Root: $SAM_FIT_SUGAR_PATH"
# echo "[*] SAM2: $SAM2_DOCKER_PATH"
# echo "[*] SuGaR: $SUGAR_DOCKER_PATH"
# echo "[*] Dataset: $DATASET_NAME"

# --- sanity checks for paths ---
if [ ! -d "$SAM2_DOCKER_PATH" ]; then
  echo "SAM2 Docker path not found: $SAM2_DOCKER_PATH"
  exit 1
fi

if [ ! -d "$SUGAR_DOCKER_PATH" ]; then
  echo "SuGaR Docker path not found: $SUGAR_DOCKER_PATH"
  exit 1
fi

# --- optionally stage helper files (copy, not move) ---
if [ -f "$SAM_FIT_SUGAR_PATH/run_sam2.sh" ]; then
  echo "[*] Copying run_sam2.sh to $SAM2_DOCKER_PATH"
  cp -f "$SAM_FIT_SUGAR_PATH/run_sam2.sh" "$SAM2_DOCKER_PATH/"
  chmod +x "$SAM2_DOCKER_PATH/run_sam2.sh"
else
  echo "[*] run_sam2.sh not found in $SAM_FIT_SUGAR_PATH (skipping copy)"
fi

if [ -f "$SAM_FIT_SUGAR_PATH/Dockerfile" ]; then
  echo "[*] Copying Dockerfile to $SAM2_DOCKER_PATH"
  cp -f "$SAM_FIT_SUGAR_PATH/Dockerfile" "$SAM2_DOCKER_PATH/"
else
  echo "[*] Dockerfile not found in $SAM_FIT_SUGAR_PATH (skipping copy)"
fi

# --- run SAM2 (pass DATASET_NAME as env) ---
cd "$SAM2_DOCKER_PATH"
echo "[*] Running SAM2 pipeline for dataset: $DATASET_NAME..."
GUI=1 DATASET_NAME="$DATASET_NAME" ./run_sam2.sh


# --- optionally stage helper files (copy, not move) ---
if [ -f "$SAM_FIT_SUGAR_PATH/run_sugar_pipeline_with_sam.sh" ]; then
  echo "[*] Copying run_sugar_pipeline_with_sam.sh to $SUGAR_DOCKER_PATH"
  cp -f "$SAM_FIT_SUGAR_PATH/run_sugar_pipeline_with_sam.sh" "$SUGAR_DOCKER_PATH/"
  chmod +x "$SUGAR_DOCKER_PATH/run_sugar_pipeline_with_sam.sh"
else
  echo "[*] run_sugar_pipeline_with_sam.sh not found in $SAM_FIT_SUGAR_PATH (skipping copy)"
fi
if [ -f "$SAM_FIT_SUGAR_PATH/Dockerfile_final" ]; then
  echo "[*] Copying Dockerfile to $SUGAR_DOCKER_PATH"
  cp -f "$SAM_FIT_SUGAR_PATH/Dockerfile_final" "$SUGAR_DOCKER_PATH/"
  cp -f "$SAM_FIT_SUGAR_PATH/train.py" "$SUGAR_DOCKER_PATH/gaussian_splatting/train.py"


else
  echo "[*] Dockerfile not found in $SAM_FIT_SUGAR_PATH (skipping copy)"
  echo "[*] train.py not found in $SAM_FIT_SUGAR_PATH (skipping copy)"
fi

# --- run SUGAR (pass DATASET_NAME as env) ---

echo "[*] Running Sugar pipeline for dataset: $DATASET_NAME..."
echo "[*] Running Sugar pipeline for dataset: $DATASET_NAME..."
(
  cd "$SUGAR_DOCKER_PATH"
  DATASET_NAME="$DATASET_NAME" \
  SUGAR_DOCKER_PATH="$SUGAR_DOCKER_PATH" \
  SAM_FIT_SUGAR_PATH="$SAM_FIT_SUGAR_PATH" \
  bash ./run_sugar_pipeline_with_sam.sh "$DATASET_NAME"
)


echo "[*] Pipeline completed successfully!"
echo "LOG: $LOGFILE" >&3
