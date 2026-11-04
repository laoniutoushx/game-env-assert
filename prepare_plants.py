"""Preserve raw sources and restore separate alpha maps in glTF copies."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).parent
for name, image_index, alpha in [
    ("tree_small_02", 4, "leaves_alpha_alpha_source.png"),
    ("shrub_02", 1, "Alpha_alpha_source.png"),
]:
    folder = root / name
    model = json.loads((folder / f"{name}_1k.gltf").read_text(encoding="utf-8"))
    entry = model["images"][image_index]
    image = Image.open(folder / entry["uri"]).convert("RGBA")
    image.putalpha(Image.open(folder / "textures" / alpha).convert("L"))
    output = f"textures/{name}_rgba.png"
    image.save(folder / output)
    entry["uri"] = output
    entry["mimeType"] = "image/png"
    if name == "tree_small_02":
        model["materials"][1]["alphaMode"] = "MASK"
        model["materials"][1]["alphaCutoff"] = 0.5
    (folder / f"{name}_prepared.gltf").write_text(json.dumps(model), encoding="utf-8")
