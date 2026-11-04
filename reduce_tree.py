"""Blender batch processing of the high-density original tree for testing."""
import bpy
from pathlib import Path

root = Path(__file__).parent
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root / "tree_small_02/tree_small_02_prepared.gltf"))
for obj in list(bpy.context.scene.objects):
    if obj.type == "MESH":
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        mod = obj.modifiers.new("Render budget", "DECIMATE")
        mod.ratio = 0.08
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.select_set(False)
        print("DECIMATED_FACES", len(obj.data.polygons), flush=True)
bpy.ops.export_scene.gltf(filepath=str(root / "tree_small_02/tree_reduced.glb"), export_format="GLB")
