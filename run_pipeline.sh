#!/usr/bin/env bash
set -e
# Checks if the paths to the repositories are correct
SAM_FIT_SUGAR_PATH="${SAM_FIT_SUGAR_PATH:-/path/to/SAM_FIT_SUGAR_PATH}"
SAM2_DOCKER_PATH="${SAM2_DOCKER_PATH:-${SAM_FIT_SUGAR_PATH}/SAM2-Docker}"
SUGAR_DOCKER_PATH="${SUGAR_DOCKER_PATH:-${SAM_FIT_SUGAR_PATH}/SuGaR-Docker/SuGaR}"

# --- Silence everything to a log ---
LOGDIR="$SAM_FIT_SUGAR_PATH/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/${DATASET_NAME}_$(date +%Y%m%d_%H%M%S).log"

# Keep the original stdout/stderr
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

# From here on, all output goes to the log
exec >"$LOGFILE" 2>&1

# Checks if a dataset name has been provided
if [ -z "$1" ]; then
  echo "Usage: $0 DATASET_NAME"
  exit 1
fi

DATASET_NAME=$1


# Verifies if the paths are correct
if [ ! -d "$SAM2_DOCKER_PATH" ]; then
  echo "SAM2 Docker path not found: $SAM2_DOCKER_PATH"
  exit 1
fi

if [ ! -d "$SUGAR_DOCKER_PATH" ]; then
  echo "SuGaR Docker path not found: $SUGAR_DOCKER_PATH"
  exit 1
fi

# Checks if the run_sam2.sh file exists before moving it
if [ -f "$SAM_FIT_SUGAR_PATH/run_sam2.sh" ]; then
  echo "[*] Moving run_sam2.sh to $SAM2_DOCKER_PATH"
  mv "$SAM_FIT_SUGAR_PATH/run_sam2.sh" "$SAM2_DOCKER_PATH/"
  chmod +x "$SAM2_DOCKER_PATH/run_sam2.sh"
else
  echo "[*] run_sam2.sh not found in $SAM_FIT_SUGAR_PATH"
fi

# Checks if the Dockerfile exists before moving it
if [ -f "$SAM_FIT_SUGAR_PATH/Dockerfile" ]; then
  echo "[*] Moving Dockerfile to $SAM2_DOCKER_PATH"
  mv "$SAM_FIT_SUGAR_PATH/Dockerfile" "$SAM2_DOCKER_PATH/"
else
  echo "[*] Dockerfile not found in $SAM_FIT_SUGAR_PATH"
fi

# Executes the SAM2 pipeline if everything is ready
cd "$SAM2_DOCKER_PATH"
echo "[*] Running SAM2 pipeline for dataset: $DATASET_NAME..."
./run_sam2.sh "$DATASET_NAME"

# Checks if the SuGaR script exists and executes it
if [ -f "$SUGAR_DOCKER_PATH/run_sugar_pipeline_with_sam.sh" ]; then
  echo "[*] Running SuGaR pipeline for dataset: $DATASET_NAME..."
  cd "$SUGAR_DOCKER_PATH"
  ./run_sugar_pipeline_with_sam.sh "$DATASET_NAME"
else
  echo "[*] run_sugar_pipeline_with_sam.sh not found in $SUGAR_DOCKER_PATH"
  exit 1
fi

echo "[*] Pipeline completed successfully!"
