#!/usr/bin/env bash
set -Eeuo pipefail

DATASET_NAME=${1:?Usage: $0 DATASET_NAME}
REFINEMENT_TIME=${REFINEMENT_TIME:-short}

# --- Silence everything to a log ---
LOGDIR="$HOME/SuGaR_Docker/SuGaR/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/${DATASET_NAME}_$(date +%Y%m%d_%H%M%S).log"

# Κράτα τα αρχικά stdout/stderr
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

# Από εδώ και κάτω, ό,τι γράφεις πάει στο log
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
# echo "[*] STEP 1: Preparing directories..."
# # Δημιουργία του φακέλου αν δεν υπάρχει
# mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}
# mkdir -p ~/SuGaR_Docker/SuGaR/outputs/${DATASET_NAME}

# # Ρύθμιση δικαιωμάτων στον φάκελο
# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}
# chmod -R 775 ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}
# sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/SuGaR/outputs/${DATASET_NAME}
# chmod -R 775 ~/SuGaR_Docker/SuGaR/outputs/${DATASET_NAME}


# mkdir -p ~/SuGaR_Docker/SuGaR/cache
# mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"  # Saving directly in the data folder
# mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/images
# mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images_sugar
# mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images_sugar_black
# mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/masks
# mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/distorted
# mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input
# # mkdir -p ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images

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



# echo "ok"
# # Αντιγραφή των αρχικών εικόνων του SAM2 στο φάκελο `input` του SuGaR για το COLMAP
# cp ~/sam2_docker_github/SAM2-Docker/outputs/${DATASET_NAME}/images/* ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/images
# # cp ~/sam2_docker_github/SAM2-Docker/outputs/${DATASET_NAME}/images/* ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images

# # Αντιγραφή των αρχικών εικόνων του SAM2 στο φάκελο `input` του SuGaR για το COLMAP
# # cp ~/sam2_docker_github/SAM2-Docker/outputs/${DATASET_NAME}/images_masked/* ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images
# for img in ~/sam2_docker_github/SAM2-Docker/outputs/${DATASET_NAME}/images_masked/*.png; do
#   # Βρες το όνομα της μάσκας χωρίς την κατάληξη
#   img_name=$(basename "$img" .png)
  
#   # Αντιγραφή της μάσκας στον φάκελο με κατάληξη .jpg.png
#   cp "$img" ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images_sugar/"$img_name".jpg
# done
# for img in ~/sam2_docker_github/SAM2-Docker/outputs/${DATASET_NAME}/images_masked_black/*.png; do
#   # Βρες το όνομα της μάσκας χωρίς την κατάληξη
#   img_name=$(basename "$img" .png)
  
#   # Αντιγραφή της μάσκας στον φάκελο με κατάληξη .jpg.png
#   cp "$img" ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/images_sugar_black/"$img_name".jpg
# done


# # Αντιγραφή των αρχικών εικόνων του SAM2 στο φάκελο `input` του SuGaR για το COLMAP
# cp ~/sam2_docker_github/SAM2-Docker/outputs/${DATASET_NAME}/images/* ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input
# # Αντιγραφή των μασκών του SAM2 με την κατάληξη .png
# for mask in ~/sam2_docker_github/SAM2-Docker/outputs/${DATASET_NAME}/maskes/*.png; do
#   # Βρες το όνομα της μάσκας χωρίς την κατάληξη
#   mask_name=$(basename "$mask" .png)
  
#   # Αντιγραφή της μάσκας στον φάκελο με κατάληξη .jpg.png
#   cp "$mask" ~/SuGaR_Docker/SuGaR/data/${DATASET_NAME}"_output"/input_colmap/masks/"$mask_name".jpg.png
# done





# echo "[*] STEP 1: Directories prepared"
# # -------------------------------
# # 2. Build Docker image (if needed)
# # -------------------------------
# echo "[*] STEP 2: Building Docker image sugar-final (if not already built)..."
# cd ~/SuGaR_Docker/SuGaR
# sudo docker build -t sugar-final -f Dockerfile_final .




# # -------------------------------
# # 2. Run COLMAP with SAM2 masks
# # -------------------------------
# echo "[*] STEP 2: Running COLMAP with SAM2 masks..."
# sudo docker run --gpus all -it --rm \
#   -v "$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output/input_colmap:/app/data" \
#   -v "$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output/distorted:/app/output" \
#   -v "$HOME/SuGaR_Docker/SuGaR/cache:/app/.cache" \
#   -e XDG_CACHE_HOME=/app/.cache \
#   -e HOME=/app \
#   sugar-final bash -lc "
#     set -e

#     # Δημιουργία βάσης δεδομένων COLMAP
#     /usr/local/bin/colmap database_creator --database_path /app/output/database.db

#     # Εξαγωγή χαρακτηριστικών από εικόνες με μάσκες SAM2
#     /usr/local/bin/colmap feature_extractor \
#       --database_path /app/output/database.db \
#       --image_path /app/data/images \
#       --ImageReader.mask_path /app/data/masks

#     # Αντιστοίχιση χαρακτηριστικών
#     /usr/local/bin/colmap sequential_matcher \
#       --database_path /app/output/database.db
  

#     # 3D ανασύνθεση
#     mkdir -p /app/output/sparse

#     /usr/local/bin/colmap mapper \
#       --database_path /app/output/database.db \
#       --image_path /app/data/images \
#       --output_path /app/output/sparse

   



#   "

# echo "======================================"
# echo " DONE! COLMAP steps completed."


# # -------------------------------
# # # 3. Run conversion script
# # # -------------------------------
# echo "[*] STEP 4: Running convert.py for dataset=${DATASET_NAME}..."
# sudo docker run --gpus all -it --rm \
#   -v "$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output:/app/data" \
#   -v "$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output:/app/output" \
#   -v "$HOME/SuGaR_Docker/SuGaR/cache:/app/.cache" \
#   -e XDG_CACHE_HOME=/app/.cache \
#   -e TORCH_EXTENSIONS_DIR=/app/.cache/torch_extensions \
#   -e HOME=/app \
#   sugar-final bash -lc "

#     set -e

#     # Define the path to colmap
#     COLMAP_PATH='/usr/local/bin/colmap'

#     # Verify if COLMAP exists
#     if [ ! -f \$COLMAP_PATH ]; then
#       echo 'Colmap executable not found at \$COLMAP_PATH'
#       exit 1
#     fi
    
#     # Remove the existing images folder if it exists
    

    
#     # Run the conversion script with the correct colmap path
#     python /app/gaussian_splatting/convert.py -s /app/data --skip_matching
#   "

# echo "======================================"
# echo " DONE! Dataset conversion completed."


# # # Ορισμός διαδρομών για τους φακέλους
# SOURCE_FOLDER="$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output/images_sugar_black"
# DEST_FOLDER="$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output/images"
# TEMP_FOLDER="$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output/images_temp"

# # Δημιουργία του προσωρινού φακέλου images_temp αν δεν υπάρχει
# if [ ! -d "$TEMP_FOLDER" ]; then
#     mkdir -p "$TEMP_FOLDER"
# fi

# # Μεταφορά όλων των εικόνων από images_sugar στο images_temp με τα ίδια ονόματα
# echo "Μεταφορά εικόνων από $SOURCE_FOLDER στον προσωρινό φάκελο $TEMP_FOLDER"
# for image in "$SOURCE_FOLDER"/*; do
#     if [ -f "$image" ]; then
#         image_name=$(basename "$image")
#         if [ -f "$DEST_FOLDER/$image_name" ]; then
#             mv "$image" "$TEMP_FOLDER/"
#             echo "Μεταφέρθηκε η εικόνα: $image_name"
#         fi
#     fi
# done

# # Διαγραφή του αρχικού φακέλου images
# echo "Διαγραφή του φακέλου images..."
# sudo rm -rf "$DEST_FOLDER"

# # Μετονομασία του images_temp σε images
# echo "Μετονομασία του προσωρινού φακέλου σε images..."
# sudo mv "$TEMP_FOLDER" "$DEST_FOLDER"

# echo "Η διαδικασία ολοκληρώθηκε. Ο φάκελος images έχει ανανεωθεί με τις νέες εικόνες."


# # -------------------------------
# # 4. Run SuGaR pipeline with SAM2 masks
# # -------------------------------
# echo "[*] STEP 3: Running SuGaR on dataset=$DATASET_NAME..."

# sudo docker run -it --rm --gpus all \
#   -v "$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output:/app/data" \
#   -v "$HOME/SuGaR_Docker/SuGaR/outputs/${DATASET_NAME}:/app/output" \
#   -v "$HOME/SuGaR_Docker/SuGaR/cache:/app/.cache" \
#   -e XDG_CACHE_HOME=/app/.cache \
#   -e TORCH_EXTENSIONS_DIR=/app/.cache/torch_extensions \
#   -e HOME=/app \
#   sugar-final \
#   /app/run_with_xvfb.sh python train_full_pipeline.py \
#     -s /app/data \
#     -r dn_consistency \
#     --refinement_time $REFINEMENT_TIME \
#     --export_obj False

# echo "======================================"
# echo " DONE! SuGaR training completed."

# -------------------------------
# 5. Extract textured mesh
# -------------------------------

echo "[*] STEP 4: Extracting textured mesh..."
sudo docker run -it --rm --gpus all \
  -v "$HOME/SuGaR_Docker/SuGaR/data/${DATASET_NAME}_output:/app/data" \
  -v "$HOME/SuGaR_Docker/SuGaR/outputs/$DATASET_NAME:/app/output" \
  -v "$HOME/SuGaR_Docker/SuGaR/cache:/app/.cache" \
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
