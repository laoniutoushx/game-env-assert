import bpy,sys,json
from pathlib import Path
source,output=sys.argv[sys.argv.index('--')+1:]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=source)
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
try:
    p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='CUDA';p.get_devices()
    for d in p.devices:d.use=d.type=='CUDA'
    if any(d.type=='CUDA' for d in p.devices):scene.cycles.device='GPU'
except Exception:pass
scene.render.bake.use_selected_to_active=False;scene.render.bake.margin=8
image=bpy.data.images.new('validated_low_ao',width=2048,height=2048,alpha=False)
image.colorspace_settings.name='Non-Color'
for o in objects:
    for m in o.data.materials:
        node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
        m.node_tree.nodes.active=node
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.bake(type='AO')
image.filepath_raw=output;image.file_format='PNG';image.save()
print('AO_REBAKED_LOW_ONLY',output)
