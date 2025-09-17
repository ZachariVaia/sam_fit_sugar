#!/usr/bin/env bash
set -e

# Ελέγχει αν έχει δοθεί όνομα dataset
if [ -z "$1" ]; then
  echo "Usage: $0 DATASET_NAME"
  exit 1
fi

DATASET_NAME=$1

# Κλήση του run_sam2.sh από το σωστό path
echo "[*] Running SAM2 pipeline for dataset: $DATASET_NAME..."

cd /home/ilias/sam2_docker_github/SAM2-Docker
GUI=1 ./run_sam2.sh "$DATASET_NAME"


# Αλλάζουμε φάκελο και τρέχουμε το SuGaR pipeline
echo "[*] Running SuGaR pipeline for dataset: $DATASET_NAME..."
cd /home/ilias/SuGaR_Docker/SuGaR
./run_sugar_pipeline_with_sam.sh "$DATASET_NAME"

echo "[*] Pipeline completed successfully!"
