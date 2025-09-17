#!/usr/bin/env bash
# Build + Run SAM2 on a dataset folder with multi-point prompts + optional GUI (Gradio or Matplotlib).
# Usage:
#   ./run_sam2.sh <dataset_name>
# Env:
#   WEB_GUI=1             # ανοίγει web GUI (Gradio)
#   WEB_GUI_MODE=first    # first | all
#   GRADIO_PORT=7860      # port για το Gradio (προαιρετικό)
#   GUI=1                 # εναλλακτικά, native matplotlib GUI
#   GUI_MODE=first        # first | all

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dataset_name-or-subfolder>"
  exit 1
fi

DATASET="$1"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${REPO_DIR}/data/${DATASET}"
OUT_DIR="${REPO_DIR}/outputs/${DATASET}"
CACHE_DIR="${HOME}/.cache/sam2"
IMAGE_TAG="sam2:local"

# Port για Gradio (default 7860)
GRADIO_PORT="${GRADIO_PORT:-7860}"

# Preconditions
command -v docker >/dev/null || { echo "Docker not found."; exit 1; }
[[ -f "${REPO_DIR}/Dockerfile" ]] || { echo "Dockerfile not found in ${REPO_DIR}"; exit 1; }
[[ -d "${DATA_DIR}" ]] || { echo "Dataset folder not found: ${DATA_DIR}"; exit 1; }

echo "==> Building Docker image: ${IMAGE_TAG}"
docker build -t "${IMAGE_TAG}" "${REPO_DIR}"

# Prepare host directories
mkdir -p "${OUT_DIR}" "${CACHE_DIR}"
chmod -R u+rwX,g+rwX,o+rwX "${REPO_DIR}/outputs" || true

# Allow X apps (optional for matplotlib GUI)
command -v xhost >/dev/null && xhost +local:docker >/dev/null 2>&1 || true

echo "==> Running SAM2 on dataset: ${DATASET}"
docker run --rm -it \
  --user "$(id -u)":"$(id -g)" \
  --gpus all --ipc=host --shm-size=16g \
  -e DISPLAY="${DISPLAY:-:0}" -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${REPO_DIR}:/workspace" \
  -v "${REPO_DIR}/data:/data" \
  -v "${REPO_DIR}/outputs:/outputs" \
  -v "${CACHE_DIR}:/root/.cache/sam2" \
  -e DATASET="${DATASET}" \
  -e GUI="${GUI:-0}" \
  -e GUI_MODE="${GUI_MODE:-first}" \
  -e WEB_GUI="${WEB_GUI:-0}" \
  -e WEB_GUI_MODE="${WEB_GUI_MODE:-first}" \
  -e GRADIO_SERVER_NAME="0.0.0.0" \
  -e GRADIO_SERVER_PORT="${GRADIO_PORT}" \
  -p "${GRADIO_PORT}:${GRADIO_PORT}" \
  "${IMAGE_TAG}" bash -lc '
set -e

# --- Resolve SAM2 home dynamically ---
if [ -d "/home/user/segment-anything-2" ]; then
  SAM2_HOME="/home/user/segment-anything-2"
else
  SAM2_HOME="$(python3 - <<PY
import os, sam2
print(os.path.dirname(os.path.dirname(sam2.__file__)))
PY
)"
fi
echo ">> SAM2_HOME=$SAM2_HOME"
mkdir -p "$SAM2_HOME/checkpoints"

# Download checkpoints if missing (best effort)
if ! ls "$SAM2_HOME/checkpoints/"*.pt >/dev/null 2>&1; then
  echo ">> No checkpoints found. Trying to download..."
  if [ -f "$SAM2_HOME/checkpoints/download_ckpts.sh" ]; then
    bash "$SAM2_HOME/checkpoints/download_ckpts.sh" || true
  else
    echo ">> WARNING: download_ckpts.sh not found at $SAM2_HOME/checkpoints/"
  fi
fi

echo ">> Available checkpoints:"
ls -lh "$SAM2_HOME/checkpoints" || true

python3 - <<PY
import os, glob, json, csv, numpy as np
from PIL import Image, ImageDraw
import torch, sam2
from pathlib import Path
import shutil
from PIL import Image

from sam2.build_sam import build_sam2
from sam2.sam2_image_predictor import SAM2ImagePredictor

dataset = os.environ["DATASET"]
use_gui = os.environ.get("GUI","0") == "1"
gui_mode = os.environ.get("GUI_MODE","first")  # "first" | "all"

use_web = os.environ.get("WEB_GUI","0") == "1"
web_mode = os.environ.get("WEB_GUI_MODE","first")  # "first" | "all"
gr_host = os.environ.get("GRADIO_SERVER_NAME","0.0.0.0")
gr_port = int(os.environ.get("GRADIO_SERVER_PORT","7860"))

in_dir  = f"/data/{dataset}"
out_dir = f"/outputs/{dataset}"
os.makedirs(out_dir, exist_ok=True)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(">> Device:", device)

# Prefer cloned repo if present, else installed package
pkg_root = os.path.dirname(os.path.dirname(sam2.__file__))
repo_default = "/home/user/segment-anything-2"
root_path = repo_default if os.path.isdir(os.path.join(repo_default, "checkpoints")) else pkg_root
ckpt_dir = os.path.join(root_path, "checkpoints")

# Pick checkpoint (prefer 2.1 large)
preferred = [
    os.path.join(ckpt_dir, "sam2.1_hiera_large.pt"),
    os.path.join(ckpt_dir, "sam2_hiera_large.pt"),
]
ckpt = next((p for p in preferred if os.path.isfile(p)), None)
if ckpt is None:
    pts = sorted(glob.glob(os.path.join(ckpt_dir, "*.pt")))
    ckpt = pts[0] if pts else None
if ckpt is None:
    raise FileNotFoundError(f"No SAM2 checkpoint found in {ckpt_dir}")

# Hydra config NAME
config_name = "configs/sam2.1/sam2.1_hiera_l.yaml" if "sam2.1_" in os.path.basename(ckpt) else "configs/sam2/sam2_hiera_l.yaml"
print(">> Using config name:", config_name)
print(">> Using checkpoint :", ckpt)

model = build_sam2(config_name, ckpt, device=device)
predictor = SAM2ImagePredictor(model)

# ---------- Helpers: points IO ----------
def _coerce_points(raw):
    if raw is None: return None, None
    if isinstance(raw, dict):
        if "points" in raw:
            seq = raw["points"]
        else:
            seq = []
            for xy in raw.get("pos", []): seq.append([xy[0], xy[1], 1])
            for xy in raw.get("neg", []): seq.append([xy[0], xy[1], 0])
    else:
        seq = raw
    coords, labels = [], []
    for it in seq:
        if len(it) == 2:
            x,y = float(it[0]), float(it[1]); lab = 1
        else:
            x,y,lab = float(it[0]), float(it[1]), int(it[2]); lab = 1 if lab>0 else 0
        coords.append([x,y]); labels.append(lab)
    if not coords: return None, None
    return np.asarray(coords, np.float32), np.asarray(labels, np.int32)

def _try_read_json(path):
    try:
        with open(path,"r",encoding="utf-8") as f: return json.load(f)
    except Exception:
        return None

def _try_read_csv(path):
    try:
        rows=[]
        with open(path,newline="",encoding="utf-8") as f:
            sample=f.read(1024); f.seek(0)
            import csv
            try:
                dialect = csv.Sniffer().sniff(sample)
                reader  = csv.reader(f, dialect)
            except Exception:
                reader  = csv.reader(f)
            for r in reader:
                if len(r)>=2:
                    x=float(r[0]); y=float(r[1])
                    lab=int(r[2]) if len(r)>=3 and r[2] != "" else 1
                    rows.append([x,y,lab])
        return rows if rows else None
    except Exception:
        return None

def _try_read_npy(path):
    try:
        arr=np.load(path, allow_pickle=True)
        return arr.tolist()
    except Exception:
        return None

def _sidecar_paths(img_path):
    base = os.path.splitext(os.path.basename(img_path))[0]
    same_dir = os.path.dirname(img_path)
    return [os.path.join(same_dir, base + s) for s in (".points.json",".points.csv",".points.npy")]

def load_points_for_image(img_path, dataset_root):
    """
    Προτεραιότητες:
      1) <same_dir>/<base>.points.json|csv|npy
      2) /data/<dataset>/points/<rel>.json|csv|npy
      3) /data/<dataset>/points.json (map rel->list/dict)
    """
    base = os.path.splitext(os.path.basename(img_path))[0]
    same_dir = os.path.dirname(img_path)
    # Cross-platform relative path σε POSIX μορφή (χωρίς backslashes)
    rel = Path(os.path.relpath(img_path, dataset_root)).as_posix()

    # 1) sidecar δίπλα στην εικόνα
    for suf, reader in ((".points.json", _try_read_json),
                        (".points.csv",  _try_read_csv),
                        (".points.npy",  _try_read_npy)):
        p = os.path.join(same_dir, base + suf)
        raw = reader(p)
        if raw is not None:
            return _coerce_points(raw)

    # 2) /points/<rel>.*
    points_dir = os.path.join(dataset_root, "points")
    if os.path.isdir(points_dir):
        rel_base = os.path.splitext(rel)[0]
        for ext, reader in ((".json", _try_read_json),
                            (".csv",  _try_read_csv),
                            (".npy",  _try_read_npy)):
            p = os.path.join(points_dir, rel_base + ext)
            if os.path.isfile(p):
                raw = reader(p)
                if raw is not None:
                    return _coerce_points(raw)

    # 3) global points.json
    gm = _try_read_json(os.path.join(dataset_root, "points.json"))
    if isinstance(gm, dict):
        raw = gm.get(rel) or gm.get(os.path.basename(img_path))
        if raw is not None:
            return _coerce_points(raw)

    return None, None

def save_points_sidecar(img_path, coords, labels):
    data = {"points":[[float(x), float(y), int(l)] for (x,y),l in zip(coords,labels)]}
    out = _sidecar_paths(img_path)[0]  # .points.json
    with open(out,"w",encoding="utf-8") as f:
        json.dump(data,f,ensure_ascii=False,indent=2)
    print("   >> Saved points:", out)

# ---------- Web GUI (Gradio) ----------
def launch_web_gui(image_paths, dataset_root, host="0.0.0.0", port=7860):
    import gradio as gr
    from PIL import Image, ImageDraw
    import numpy as np, json, os

    buffers = {p: [] for p in image_paths}  # {path: [(x,y,label), ...]}
    idx = {"i": 0}
    label_mode = {"v": 1}  # 1=positive, 0=negative

    def draw_overlay(p):
        im = Image.open(p).convert("RGB")
        ov = im.copy()
        dr = ImageDraw.Draw(ov)
        pts = buffers[p]
        r = max(3, min(im.size)//200)
        for x,y,l in pts:
            bb = (x-r, y-r, x+r, y+r)
            if l==1:
                dr.ellipse(bb, outline=(0,255,0), width=2)
                dr.line((x-r,y, x+r,y), fill=(0,255,0), width=2)
                dr.line((x,y-r, x,y+r), fill=(0,255,0), width=2)
            else:
                dr.ellipse(bb, outline=(255,0,0), width=2)
                dr.line((x-r,y-r, x+r,y+r), fill=(255,0,0), width=2)
                dr.line((x-r,y+r, x+r,y-r), fill=(255,0,0), width=2)
        return ov

    def current_path():
        return image_paths[idx["i"]]

    def load_image():
        p = current_path()
        rel = os.path.relpath(p, dataset_root)
        cur = int(idx.get("i", 0))
        total = len(image_paths)
        status_text = f"{cur+1}/{total} • {rel}"
        return draw_overlay(p), status_text


    def on_select(evt: gr.SelectData):
        x, y = float(evt.index[0]), float(evt.index[1])
        buffers[current_path()].append((x,y,label_mode["v"]))
        return draw_overlay(current_path())

    def set_label(mode):
        label_mode["v"] = 1 if mode=="positive" else 0
        return gr.update()

    def undo():
        pts = buffers[current_path()]
        if pts: pts.pop()
        return draw_overlay(current_path())

    def reset_pts():
        buffers[current_path()].clear()
        return draw_overlay(current_path())

    def nav(delta):
        idx["i"] = (idx["i"] + delta) % len(image_paths)
        return load_image()

    def save_cur():
        p = current_path()
        sidecar = os.path.splitext(p)[0] + ".points.json"
        data = {"points":[[float(x),float(y),int(l)] for x,y,l in buffers[p]]}
        os.makedirs(os.path.dirname(sidecar), exist_ok=True)
        with open(sidecar, "w", encoding="utf-8") as f: json.dump(data, f, ensure_ascii=False, indent=2)
        return f"Saved: {os.path.relpath(sidecar, dataset_root)}"

    def finish_all():
        for p, pts in buffers.items():
            sidecar = os.path.splitext(p)[0] + ".points.json"
            data = {"points":[[float(x),float(y),int(l)] for x,y,l in pts]}
            with open(sidecar, "w", encoding="utf-8") as f: json.dump(data, f, ensure_ascii=False, indent=2)
        import gradio
        gradio.close_all()
        return "Saved all. You can close this tab."

    with gr.Blocks() as demo:
        gr.Markdown("### SAM2 Point Picker — click to add points\n**Label:** positive=green, negative=red")
        img = gr.Image(type="pil", interactive=True, label="Image")
        img.select(on_select, outputs=img)
        status = gr.Markdown()
        with gr.Row():
            label = gr.Radio(choices=["positive","negative"], value="positive", label="Point label")
            label.change(set_label, inputs=label, outputs=[])
        with gr.Row():
            btn_undo = gr.Button("Undo")
            btn_reset = gr.Button("Reset")
            btn_prev  = gr.Button("◀ Prev")
            btn_next  = gr.Button("Next ▶")
        with gr.Row():
            btn_save  = gr.Button("💾 Save current")
            btn_finish= gr.Button("✅ Finish & Run")

        btn_undo.click(undo, outputs=img)
        btn_reset.click(reset_pts, outputs=img)
        btn_prev.click(lambda: nav(-1), outputs=[img, status])
        btn_next.click(lambda: nav(+1), outputs=[img, status])
        btn_save.click(save_cur, outputs=gr.Textbox(label="Save log", interactive=False))
        btn_finish.click(finish_all, outputs=gr.Textbox(label="Status", interactive=False))

        # initial load
        img.value, status.value = load_image()

    print(f">> Web GUI ready: http://localhost:{port}")
    demo.queue()
    demo.launch(server_name=host, server_port=port, share=False, inbrowser=False)

# ---------- Optional Matplotlib GUI ----------
def annotate_points_gui(pil_image, existing=None):
    """
    Left-click: positive (green)
    Right-click: negative (red)
    Keys: u=undo, r=reset, s=save, enter=finish, q=quit(no save)
    Returns (coords Nx2 float32, labels N int32) or (None,None) if canceled.
    """
    try:
        import matplotlib
        if "agg" in matplotlib.get_backend().lower():
            for bk in ["TkAgg","Qt5Agg","GTK3Agg"]:
                try:
                    matplotlib.use(bk, force=True); break
                except Exception:
                    pass
        import matplotlib.pyplot as plt
    except Exception as e:
        print("   >> GUI not available (matplotlib backend issue):", e)
        return None, None

    import numpy as np
    img = np.asarray(pil_image)
    fig, ax = plt.subplots(figsize=(10,8))
    ax.imshow(img); ax.set_title("Click points: left=POS (green), right=NEG (red)\nKeys: u=undo, r=reset, s=save, Enter=finish, q=quit")
    ax.axis("on")

    coords = []
    labels = []
    if existing is not None and existing[0] is not None and len(existing[0])>0:
        coords.extend(existing[0].tolist())
        labels.extend(existing[1].tolist())

    pos_plots=[]; neg_plots=[]
    def redraw():
        nonlocal pos_plots, neg_plots
        for h in pos_plots+neg_plots:
            try: h.remove()
            except Exception: pass
        pos_plots=[]; neg_plots=[]
        if coords:
            c = np.array(coords); l = np.array(labels)
            pos = c[np.where(np.array(l)==1)]
            neg = c[np.where(np.array(l)==0)]
            if len(pos):
                h=ax.scatter(pos[:,0], pos[:,1], marker="+", s=120, linewidths=2, c="g"); pos_plots.append(h)
            if len(neg):
                h=ax.scatter(neg[:,0], neg[:,1], marker="x", s=120, linewidths=2, c="r"); neg_plots.append(h)
        fig.canvas.draw_idle()

    def onclick(ev):
        if ev.inaxes != ax or ev.xdata is None or ev.ydata is None: return
        x,y = float(ev.xdata), float(ev.ydata)
        if ev.button==1:   coords.append([x,y]); labels.append(1)
        elif ev.button==3: coords.append([x,y]); labels.append(0)
        redraw()

    state = {"save":False, "done":False, "quit":False}
    def onkey(ev):
        key = ev.key
        if key=="u":
            if coords: coords.pop(); labels.pop(); redraw()
        elif key=="r":
            coords.clear(); labels.clear(); redraw()
        elif key=="s":
            state["save"]=True; state["done"]=True; plt.close(fig)
        elif key=="enter":
            state["done"]=True; plt.close(fig)
        elif key=="q":
            state["quit"]=True; plt.close(fig)

    fig.canvas.mpl_connect("button_press_event", onclick)
    fig.canvas.mpl_connect("key_press_event", onkey)
    redraw(); plt.show()

    if state["quit"]:
        return None, None
    if not coords:
        return np.zeros((0,2),np.float32), np.zeros((0,),np.int32)
    return np.asarray(coords,np.float32), np.asarray(labels,np.int32)

# ---------- Gather images ----------
exts = ("*.jpg","*.jpeg","*.png","*.bmp","*.tif","*.tiff")
imgs = []
for e in exts: imgs += glob.glob(os.path.join(in_dir, "**", e), recursive=True)
imgs = sorted(imgs)
if not imgs: raise SystemExit(f"No images found in {in_dir}")

# ---------- WEB GUI (if enabled) ----------
if use_web:
    targets = imgs if web_mode=="all" else imgs[:1]
    print(">> Web GUI mode:", web_mode, "| images:", len(targets))
    launch_web_gui(targets, in_dir, host=gr_host, port=gr_port)
    print(">> Web GUI finished, continuing to predictor...\n")

# ---------- Matplotlib GUI (if enabled and web not used) ----------
elif use_gui:
    print(">> Matplotlib GUI mode enabled (", gui_mode, ")")
    targets = imgs if gui_mode=="all" else imgs[:1]
    for p in targets:
        try:
            im = Image.open(p).convert("RGB")
            exist = load_points_for_image(p, in_dir)
            new_pts, new_labs = annotate_points_gui(im, existing=exist)
            if new_pts is None and new_labs is None:
                print("   >> Skipped (no save):", os.path.relpath(p, in_dir))
                continue
            save_points_sidecar(p, new_pts, new_labs)
        except Exception as e:
            print("   >> GUI failed on", p, ":", e)
    print(">> GUI stage finished.\n")

print(f">> Found {len(imgs)} images. Running predictor...")
for i, path in enumerate(imgs, 1):
    try:
        im = Image.open(path).convert("RGB")
        arr = np.array(im); H, W = arr.shape[:2]

        # Load user points (multi-point). If none, fallback to center.
        all_pts, all_labs = load_points_for_image(path, in_dir)
        used_center_fallback = False
        if all_pts is None or all_labs is None or len(all_pts) == 0:
            all_pts = np.asarray([[W//2, H//2]], np.float32)
            all_labs = np.asarray([1], np.int32)
            used_center_fallback = True

        predictor.set_image(arr)

        # Two-stage prediction (seed -> refine)
        if len(all_pts) == 1:
            masks, scores, logits = predictor.predict(
                point_coords=all_pts,
                point_labels=all_labs,
                multimask_output=True
            )
            best = int(np.argmax(scores))
            mask = (masks[best] > 0).astype(np.uint8) * 255
        else:
            pos_idx = np.where(all_labs == 1)[0]
            seed_idx = int(pos_idx[0]) if len(pos_idx)>0 else 0
            seed_pt  = all_pts[[seed_idx]]
            seed_lab = all_labs[[seed_idx]]

            masks1, scores1, logits1 = predictor.predict(
                point_coords=seed_pt,
                point_labels=seed_lab,
                multimask_output=True
            )
            best1 = int(np.argmax(scores1))
            seed_logits = logits1[best1]

            masks2, scores2, _ = predictor.predict(
                point_coords=all_pts,
                point_labels=all_labs,
                mask_input=seed_logits[None, :, :],
                multimask_output=False
            )
            mask = (masks2[0] > 0).astype(np.uint8) * 255

        # Save results
        rel     = os.path.relpath(path, in_dir)
        rel_dir = os.path.dirname(rel)
        base    = os.path.splitext(os.path.basename(path))[0]
        out_sub = os.path.join(out_dir, rel_dir)
        os.makedirs(out_sub, exist_ok=True)

        Image.fromarray(mask).save(os.path.join(out_sub, f"{base}_mask.png"))

        overlay = im.convert("RGBA")
        mask_rgba = Image.fromarray(np.stack([
            np.zeros_like(mask),
            (mask>0).astype(np.uint8)*255,
            np.zeros_like(mask),
            (mask>0).astype(np.uint8)*128
        ], axis=-1))
        overlay = Image.alpha_composite(overlay, mask_rgba)

        draw = ImageDraw.Draw(overlay)
        r = max(3, min(H, W)//200)
        for (x, y), lab in zip(all_pts, all_labs):
            x = float(x); y = float(y)
            bb = (x-r, y-r, x+r, y+r)
            if lab == 1:
                draw.ellipse(bb, outline=(0,255,0,255), width=2)
                draw.line((x-r, y, x+r, y), fill=(0,255,0,255), width=2)
                draw.line((x, y-r, x, y+r), fill=(0,255,0,255), width=2)
            else:
                draw.ellipse(bb, outline=(255,0,0,255), width=2)
                draw.line((x-r, y-r, x+r, y+r), fill=(255,0,0,255), width=2)
                draw.line((x-r, y+r, x+r, y-r), fill=(255,0,0,255), width=2)

        overlay.save(os.path.join(out_sub, f"{base}_overlay.png"))

        meta = {
            "image": rel,
            "used_center_fallback": bool(used_center_fallback),
            "num_points": int(len(all_pts)),
            "points": [[float(x), float(y), int(l)] for (x,y), l in zip(all_pts, all_labs)],
            "config_name": config_name,
            "checkpoint": os.path.basename(ckpt),
        }
        with open(os.path.join(out_sub, f"{base}_meta.json"), "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)

        tag = "fallback" if used_center_fallback else "multi-pts" if len(all_pts)>1 else "single-pt"
        print(f"[{i}/{len(imgs)}] OK ({tag}): {rel}")
    except Exception as e:
        print(f"[{i}/{len(imgs)}] ERROR on {path}: {e}")

print("\\n>> Done. Outputs in", out_dir)
PY
'

echo "==> Finished. Check outputs in: ${OUT_DIR}"
# === Post-process (FLAT): maskes/, images/, images_masked/ ===


echo ">> Post-process (flat): creating 'maskes', 'images', 'images_masked' ..."
echo "Ξεκινάει η επεξεργασία..."



echo ">> Post-process: creating maskes, images, images_masked ..."

python3 - <<EOF
import os
import glob
import shutil
from pathlib import Path
from PIL import Image

out_dir = "${OUT_DIR}"
in_dir_images = "${DATA_DIR}"

masks_root  = os.path.join(out_dir, "maskes")
images_root = os.path.join(out_dir, "images")
masked_root = os.path.join(out_dir, "images_masked")
masked_black_root = os.path.join(out_dir, "images_masked_black")


os.makedirs(masks_root, exist_ok=True)
os.makedirs(images_root, exist_ok=True)
os.makedirs(masked_root, exist_ok=True)
os.makedirs(masked_black_root, exist_ok=True)

def unique_path(dest_dir, filename):
    base, ext = os.path.splitext(filename)
    candidate = filename
    i = 1
    while os.path.exists(os.path.join(dest_dir, candidate)):
        candidate = f"{base}_{i}{ext}"
        i += 1
    return os.path.join(dest_dir, candidate)

mask_paths = glob.glob(os.path.join(out_dir, "**", "*_mask.png"), recursive=True)

for mpath in mask_paths:
    base = os.path.basename(mpath)
    stem = base[:-9]  # remove _mask.png
    dest_mask = unique_path(masks_root, f"{stem}.png")
    shutil.copy2(mpath, dest_mask)

img_paths = []
for ext in ("*.png", "*.jpg", "*.jpeg"):
    img_paths.extend(glob.glob(os.path.join(in_dir_images, "**", ext), recursive=True))

for ipath in img_paths:
    base = os.path.basename(ipath)
    dest_img = unique_path(images_root, base)
    shutil.copy2(ipath, dest_img)

for mpath in mask_paths:
    base = os.path.basename(mpath)
    stem = base[:-9]

    candidates = [p for p in img_paths if os.path.splitext(os.path.basename(p))[0] == stem]
    if not candidates:
        print(f"Warning: no original image found for mask {base}")
        continue

    ipath = candidates[0]
    im = Image.open(ipath).convert("RGBA")
    mimg = Image.open(mpath).convert("L")

    if mimg.size != im.size:
        mimg = mimg.resize(im.size, Image.NEAREST)

    r, g, b, _ = im.split()
    im_rgba = Image.merge("RGBA", (r, g, b, mimg))

    dest_rgba = unique_path(masked_root, f"{stem}.png")
    im_rgba.save(dest_rgba)



for mpath in mask_paths:
    base = os.path.basename(mpath)
    stem = base[:-9]  # Αφαιρούμε το _mask.png από το όνομα της μάσκας

    candidates = [p for p in img_paths if os.path.splitext(os.path.basename(p))[0] == stem]
    if not candidates:
        print(f"Warning: no original image found for mask {base}")
        continue

    ipath = candidates[0]
    im = Image.open(ipath).convert("RGBA")  # Ανοίγουμε την εικόνα με RGBA
    mimg = Image.open(mpath).convert("L")   # Η μάσκα είναι grayscale

    if mimg.size != im.size:
        mimg = mimg.resize(im.size, Image.NEAREST)  # Κάνουμε resize τη μάσκα στην εικόνα αν είναι αναγκαίο

    # Δημιουργία νέας εικόνας με μαύρο φόντο
    im_black = im.copy()  
    black_pixels = mimg.point(lambda p: 0 if p == 0 else 255)  # Μαύρο όπου η μάσκα είναι 0

    # Εφαρμογή της μάσκας στην εικόνα με μαύρο φόντο
    r, g, b, a = im.split()
    new_r = Image.composite(r, Image.new("L", r.size, 0), black_pixels)
    new_g = Image.composite(g, Image.new("L", g.size, 0), black_pixels)
    new_b = Image.composite(b, Image.new("L", b.size, 0), black_pixels)

    # Δημιουργούμε τη νέα εικόνα με τα αντίστοιχα pixels
    im_black = Image.merge("RGBA", (new_r, new_g, new_b, a))  

    # Αποθήκευση της εικόνας με μαύρο φόντο
    dest_black = unique_path(masked_black_root, f"{stem}.png")
    im_black.save(dest_black)

print(f">> images_masked_black/: {len(mask_paths)} files (flat)")
print(f">> maskes/: {len(mask_paths)} files (flat)")
print(f">> images/: {len(img_paths)} files (flat)")
print(f">> images_masked/: {len(mask_paths)} files (flat)")

EOF
