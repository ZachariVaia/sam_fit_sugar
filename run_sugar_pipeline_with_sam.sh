#!/usr/bin/env bash
set -Eeuo pipefail

DATASET_NAME=${1:?Usage: $0 DATASET_NAME}
REFINEMENT_TIME=${REFINEMENT_TIME:-short}

# --- Silence everything to a log ---
LOGDIR="$SUGAR_DOCKER_PATH/logs"
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

# -------------------------------
# 0. Parse args
# -------------------------------
if [ -z "$DATASET_NAME" ]; then
  echo "Usage: $0 DATASET_NAME"
  exit 1
fi

echo "======================================"
echo " Running SuGaR pipeline with SAM2 outputs"
echo " Dataset: $DATASET_NAME"
echo " Refinement time: $REFINEMENT_TIME"
echo "======================================"
# -------------------------------
# 1. Prepare directories
# -------------------------------
echo "[*] STEP 1: Preparing directories..."
# Create the folder if it doesn't exist
mkdir -p "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}"
mkdir -p "$SUGAR_DOCKER_PATH/outputs/${DATASET_NAME}"

# Set folder permissions
sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}"
chmod -R 775 "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}"
sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/outputs/${DATASET_NAME}"
chmod -R 775 "$SUGAR_DOCKER_PATH/outputs/${DATASET_NAME}"

mkdir -p "$SUGAR_DOCKER_PATH/cache"
mkdir -p "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap/images"
mkdir -p "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar"
mkdir -p "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar_black"
mkdir -p "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap/masks"
mkdir -p "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/distorted"
mkdir -p "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input"

# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}
# chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}

# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"
# chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"

# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/images
# chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/images


# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images_sugar
# chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images_sugar

# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images_sugar_black
# chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images_sugar_black

# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/masks
# chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/masks

# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input
# chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input
# # Set permissions for the directories
# sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}"
# chmod -R 775 "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}"

# sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output"
# chmod -R 775 "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output"

# sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap/images"
# sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar"
# sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar_black"
# sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap/masks"

# chmod -R 775 "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap/images"
# chmod -R 775 "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar"
# chmod -R 775 "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar_black"
# chmod -R 775 "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap/masks"

# sudo chown -R $(id -u):$(id -g) "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images"
# chmod -R 775 "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images"

# sudo chown -R $(id -u):$(id -g) "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images_masked"
# chmod -R 775 "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images_masked"

# sudo chown -R $(id -u):$(id -g) "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images_masked_black"
# chmod -R 775 "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images_masked_black"

# sudo chown -R $(id -u):$(id -g) "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/maskes"
# chmod -R 775 "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/maskes"

# sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/outputs/vazo/vanilla_gs"
# sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH/outputs/vazo/coarse"
# chmod -R 775 "$SUGAR_DOCKER_PATH/outputs/vazo/vanilla_gs"
# chmod -R 775 "$SUGAR_DOCKER_PATH/outputs/vazo/coarse"

sudo chown -R $(id -u):$(id -g) "$SAM2_DOCKER_PATH"
sudo chown -R $(id -u):$(id -g) "$SUGAR_DOCKER_PATH"
chmod -R 775 "$SUGAR_DOCKER_PATH"
chmod -R 775 "$SUGAR_DOCKER_PATH"


# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/images
# sudo chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/images

echo "ok"

# Copy SAM2 images to SuGaR input directory for COLMAP
for img in "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images/"*; do
  cp "$img" "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap/images/"
  cp "$img" "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input"
done

# Copy SAM2 masked images to SuGaR directories
for img in "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images_masked/"*; do
  img_name=$(basename "$img" .png)
  cp "$img" "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar/$img_name.jpg"
done


for img in "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/images_masked_black/"*; do
  img_name=$(basename "$img" .png)
  cp "$img" "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar_black/$img_name.jpg"
done

# Copy SAM2 masks to SuGaR input directory
for mask in "$SAM2_DOCKER_PATH/outputs/${DATASET_NAME}/maskes/"*; do
  mask_name=$(basename "$mask" .png)
  cp "$mask" "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap/masks/$mask_name.jpg.png"
done

echo "[*] STEP 1: Directories prepared"
# -------------------------------
# 2. Build Docker image (if needed)
# -------------------------------
echo "[*] STEP 2: Building Docker image sugar-final (if not already built)..."
cd "$SUGAR_DOCKER_PATH"
sudo docker build -t sugar-final -f Dockerfile_final .

# -------------------------------
# 3. Run COLMAP with SAM2 masks
# -------------------------------
echo "[*] STEP 2: Running COLMAP with SAM2 masks..."
sudo docker run --gpus all -it --rm \
  -v "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/input_colmap:/app/data" \
  -v "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/distorted:/app/output" \
  -v "$SUGAR_DOCKER_PATH/cache:/app/.cache" \
  -e XDG_CACHE_HOME=/app/.cache \
  -e HOME=/app \
  sugar-final bash -lc "
    set -e

    # Create COLMAP database
    /usr/local/bin/colmap database_creator --database_path /app/output/database.db

    # Extract features from images with SAM2 masks
    /usr/local/bin/colmap feature_extractor \
      --database_path /app/output/database.db \
      --image_path /app/data/images \
      --ImageReader.mask_path /app/data/masks

    # Match features
    /usr/local/bin/colmap sequential_matcher \
      --database_path /app/output/database.db

    # 3D reconstruction
    mkdir -p /app/output/sparse
    /usr/local/bin/colmap mapper \
      --database_path /app/output/database.db \
      --image_path /app/data/images \
      --output_path /app/output/sparse
  "

echo "======================================"
echo " DONE! COLMAP steps completed."


# -------------------------------
# # 3. Run conversion script
# # -------------------------------
echo "[*] STEP 4: Running convert.py for dataset=${DATASET_NAME}..."
sudo docker run --gpus all -it --rm \
  -v "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output:/app/data" \
  -v "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output:/app/output" \
  -v "$SUGAR_DOCKER_PATH/cache:/app/.cache" \
  -e XDG_CACHE_HOME=/app/.cache \
  -e TORCH_EXTENSIONS_DIR=/app/.cache/torch_extensions \
  -e HOME=/app \
  sugar-final bash -lc "

    set -e

    # Define the path to colmap
    COLMAP_PATH='/usr/local/bin/colmap'

    # Verify if COLMAP exists
    if [ ! -f \$COLMAP_PATH ]; then
      echo 'Colmap executable not found at \$COLMAP_PATH'
      exit 1
    fi
    
    # Remove the existing images folder if it exists
    

    
    # Run the conversion script with the correct colmap path
    python /app/gaussian_splatting/convert.py -s /app/data --skip_matching
  "

echo "======================================"
echo " DONE! Dataset conversion completed."


# Define folder paths
SOURCE_FOLDER="$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_sugar_black"
DEST_FOLDER="$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images"
TEMP_FOLDER="$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output/images_temp"

# Create the temporary images_temp folder if it doesn't exist
if [ ! -d "$TEMP_FOLDER" ]; then
    mkdir -p "$TEMP_FOLDER"
fi

# Move all images from images_sugar to images_temp with the same names
echo "Moving images from $SOURCE_FOLDER to temporary folder $TEMP_FOLDER"
for image in "$SOURCE_FOLDER"/*; do
    if [ -f "$image" ]; then
        image_name=$(basename "$image")
        if [ -f "$DEST_FOLDER/$image_name" ]; then
            mv "$image" "$TEMP_FOLDER/"
            echo "Moved image: $image_name"
        fi
    fi
done

# Delete the original images folder
echo "Deleting the images folder..."
sudo rm -rf "$DEST_FOLDER"

# Rename images_temp to images
echo "Renaming temporary folder to images..."
sudo mv "$TEMP_FOLDER" "$DEST_FOLDER"

echo "Process completed. The images folder has been updated with the new images."


# -------------------------------
# 5. Run SuGaR pipeline with SAM2 masks
# -------------------------------
echo "[*] STEP 3: Running SuGaR on dataset=$DATASET_NAME..."

sudo docker run -it --rm --gpus all \
  -v "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output:/app/data" \
  -v "$SUGAR_DOCKER_PATH/outputs/${DATASET_NAME}:/app/output" \
  -v "$SUGAR_DOCKER_PATH/cache:/app/.cache" \
  -e XDG_CACHE_HOME=/app/.cache \
  -e TORCH_EXTENSIONS_DIR=/app/.cache/torch_extensions \
  -e HOME=/app \
  sugar-final \
  /app/run_with_xvfb.sh python train_full_pipeline.py \
    -s /app/data \
    -r dn_consistency \
    --refinement_time $REFINEMENT_TIME \
    --export_obj False

echo "======================================"
echo " DONE! SuGaR training completed."

# -------------------------------
# 6. Extract textured mesh
# -------------------------------
echo "[*] STEP 4: Extracting textured mesh..."
sudo docker run -it --rm --gpus all \
  -v "$SUGAR_DOCKER_PATH/data/${DATASET_NAME}_output:/app/data" \
  -v "$SUGAR_DOCKER_PATH/outputs/$DATASET_NAME:/app/output" \
  -v "$SUGAR_DOCKER_PATH/cache:/app/.cache" \
  -e XDG_CACHE_HOME=/app/.cache \
  -e TORCH_EXTENSIONS_DIR=/app/.cache/torch_extensions \
  -e HOME=/app \
  sugar-final bash -lc "\
    set -e
    REF=\$(find /app/output/refined/ -type f -name '2000.pt' | head -n1)

    if [ -z \"\$REF\" ]; then
      echo '[!] No refined checkpoint found, skipping mesh extraction.'
      exit 0
    fi

    echo 'Using refined checkpoint: '\$REF
    cp -r /app/sugar_utils /tmp/sugar_utils
    ln -sfn /app/output /tmp/output
    cd /tmp
    PYTHONPATH=/tmp:/app:/app/gaussian_splatting:\$PYTHONPATH \
      python -m extract_refined_mesh_with_texture \
        -s /app/data \
        -c /app/output/vanilla_gs/data \
        -m \"\$REF\" \
        -o /app/output/refined_mesh/data \
        --square_size 8
"

restore_fds
echo "STATUS: MESH DONE"
