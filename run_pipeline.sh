#!/usr/bin/env bash
set -e

# Checks if a dataset name has been provided
if [ -z "$1" ]; then
  echo "Usage: $0 DATASET_NAME"
  exit 1
fi

DATASET_NAME=$1

# Checks if the paths to the repositories are set via environment variables
SAM_FIT_SUGAR_PATH="${SAM_FIT_SUGAR_PATH:-/path/to/SAM_FIT_SUGAR_PATH}"
SAM2_DOCKER_PATH="${SAM2_DOCKER_PATH:-${SAM_FIT_SUGAR_PATH}/SAM2-Docker}"  # Uses the environment variable or default
SUGAR_DOCKER_PATH="${SUGAR_DOCKER_PATH:-${SAM_FIT_SUGAR_PATH}/SuGaR-Docker/SuGaR}"


# Verifies if the paths are correct
if [ ! -d "$SAM2_DOCKER_PATH" ]; then
  echo "SAM2 Docker path not found: $SAM2_DOCKER_PATH"
  exit 1
fi

if [ ! -d "$SUGAR_DOCKER_PATH" ]; then
  echo "SuGaR Docker path not found: $SUGAR_DOCKER_PATH"
  exit 1
fi

# Calls the run_sam2.sh script from the correct path
echo "[*] Running SAM2 pipeline for dataset: $DATASET_NAME..."
# chmod +x run_sam2.sh
# mv "$SAM_FIT_SUGAR_PATH/run_sam2.sh" "$SAM2_DOCKER_PATH/"
# mv "$SAM_FIT_SUGAR_PATH/Dockerfile" "$SAM2_DOCKER_PATH/"
cd "$SAM2_DOCKER_PATH"

GUI=1 ./run_sam2.sh "$DATASET_NAME"

cd "$SAM_FIT_SUGAR_PATH"
# Change directory and run the SuGaR pipeline
echo "[*] Running SuGaR pipeline for dataset: $DATASET_NAME..."
# chmod +x run_sugar_pipeline_with_sam.sh
# mv "$SAM_FIT_SUGAR_PATH/run_sugar_pipeline_with_sam.sh" "$SUGAR_DOCKER_PATH/"
# mv "$SAM_FIT_SUGAR_PATH/Dockerfile_final" "$SUGAR_DOCKER_PATH/"
cd "$SUGAR_DOCKER_PATH"
./run_sugar_pipeline_with_sam.sh "$DATASET_NAME"

echo "[*] Pipeline completed successfully!"
