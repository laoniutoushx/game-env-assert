"""Run with Blender --background --python optimize_glb.py -- INPUT OUTPUT TRIANGLES."""
import sys
from pathlib import Path
import bpy

args = sys.argv[sys.argv.index('--') + 1:]
source, destination, target = Path(args[0]), Path(args[1]), int(args[2])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
objects=[obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
triangles = sum(sum(max(0,len(p.vertices)-2) for p in obj.data.polygons) for obj in objects)
ratio = min(1.0, target / max(triangles,1))
for obj in objects:
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('runtime_decimate','DECIMATE')
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)
destination.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB')
print('MESHY_OPTIMIZED', source, 'original_triangles',triangles, 'target',target,'ratio',ratio, flush=True)
