"""Extract deterministic stone surface samples from the local PBR set."""
from pathlib import Path
from PIL import Image, ImageEnhance

root = Path(__file__).parent / "textures"
# Approximate interiors of larger slabs; UVs are clamped per individual stone.
regions = [(20, 15, 220, 220), (835, 15, 1015, 220),
           (1570, 15, 1770, 210), (25, 535, 225, 760),
           (270, 560, 445, 750), (850, 535, 1050, 745),
           (1110, 545, 1300, 750), (1780, 535, 1980, 745)]
for channel in ("Color", "NormalGL", "Roughness"):
    source = Image.open(root / f"Tiles130_2K-JPG_{channel}.jpg")
    for i, rect in enumerate(regions):
        sample = source.crop(rect).resize((512, 512), Image.Resampling.LANCZOS)
        if channel == "Color":
            sample = ImageEnhance.Color(sample).enhance(0.65)
            sample = ImageEnhance.Brightness(sample).enhance(1.36)
        sample.save(root / f"slab_{i}_{channel}.jpg", quality=92)

ground = Image.open(root / "Ground003_2K-JPG_Color.jpg").convert("RGB")
ground = ImageEnhance.Color(ground).enhance(0.48)
ground = ImageEnhance.Brightness(ground).enhance(0.72)
ground.save(root / "ground_muted.jpg", quality=94)
