"""Restore the separate Poly Haven alpha map in a Godot-ready glTF copy."""
import hashlib
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).parent / "fern_02"
alpha_path = root / "textures/fern_02_alpha_2k.png"
assert hashlib.md5(alpha_path.read_bytes()).hexdigest() == "ff18f7e8e869c58eac8f9c7d7c519f4a"
image = Image.open(root / "textures/fern_02_diff_2k.jpg").convert("RGBA")
image.putalpha(Image.open(alpha_path).convert("L"))
image.save(root / "textures/fern_02_rgba.png")
source = json.loads((root / "fern_02_2k.gltf").read_text(encoding="utf-8"))
source["images"][1]["uri"] = "textures/fern_02_rgba.png"
source["images"][1]["mimeType"] = "image/png"
(root / "fern_02_prepared.gltf").write_text(json.dumps(source), encoding="utf-8")
