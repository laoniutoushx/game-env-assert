"""Blender: direct-source decimation and selected-to-active normal/AO transfer."""
import bpy, sys, json, time, math
from pathlib import Path
from mathutils import Vector

arguments = sys.argv[sys.argv.index('--')+1:]
source, output, triangles = arguments[:3]
reunwrap = '--reunwrap' in arguments
source, output, triangles = Path(source), Path(output), int(triangles)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
highs=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(highs)==1, 'Expected single Meshy master mesh'
high=highs[0]
low=high.copy(); low.data=high.data.copy(); bpy.context.collection.objects.link(low)
low.name='repaired_runtime'
for slot in low.material_slots:
    slot.material=slot.material.copy()
original=sum(len(p.vertices)-2 for p in high.data.polygons)
bpy.context.view_layer.objects.active=low
modifier=low.modifiers.new('direct_master_decimation','DECIMATE')
modifier.ratio=min(1.0,triangles/original)
modifier.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=modifier.name)
if reunwrap:
    bpy.ops.object.select_all(action='DESELECT'); low.select_set(True)
    bpy.context.view_layer.objects.active=low
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=16
device='CPU'
try:
    pref=bpy.context.preferences.addons['cycles'].preferences
    pref.compute_device_type='CUDA'; pref.get_devices()
    for d in pref.devices: d.use=d.type=='CUDA'
    if any(d.type=='CUDA' for d in pref.devices): scene.cycles.device='GPU';device='CUDA'
except Exception: pass
diag=Vector(high.dimensions).length
scene.render.bake.use_selected_to_active=True
scene.render.bake.cage_extrusion=diag*0.005
scene.render.bake.max_ray_distance=diag*0.03
scene.render.bake.margin=8
results={}
started=time.time()
for bake_type in (['DIFFUSE','ROUGHNESS','NORMAL','AO'] if reunwrap else ['NORMAL','AO']):
    resolution=4096 if reunwrap and bake_type=='DIFFUSE' else 2048
    image=bpy.data.images.new(output.stem+'_'+bake_type.lower(),width=resolution,height=resolution,alpha=False)
    image.colorspace_settings.name='sRGB' if bake_type=='DIFFUSE' else 'Non-Color'
    image.generated_color=(0.5,0.5,1.0,1.0) if bake_type=='NORMAL' else (1,1,1,1)
    for mat in low.data.materials:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
        for n in mat.node_tree.nodes: n.select=False
        node.select=True;mat.node_tree.nodes.active=node
    bpy.ops.object.select_all(action='DESELECT')
    high.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
    scene.render.bake.use_selected_to_active=bake_type!='AO'
    high.hide_render=bake_type=='AO'
    if bake_type=='AO': high.select_set(False)
    scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False
    scene.render.bake.use_pass_color=True
    bpy.ops.object.bake(type=bake_type)
    target=output.with_name(output.stem+'_'+bake_type.lower()+'.png')
    image.filepath_raw=str(target);image.file_format='PNG';image.save()
    results[bake_type]=str(target)
    if bake_type in ['DIFFUSE','ROUGHNESS']:
        for mat in low.data.materials:
            tree=mat.node_tree;shader=next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED')
            tex=next(n for n in tree.nodes if n.type=='TEX_IMAGE' and n.image==image)
            tree.links.new(tex.outputs['Color'],shader.inputs['Base Color' if bake_type=='DIFFUSE' else 'Roughness'])
    if bake_type=='NORMAL':
        for mat in low.data.materials:
            tree=mat.node_tree; shader=next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED')
            tex=next(n for n in tree.nodes if n.type=='TEX_IMAGE' and n.image==image)
            normal=tree.nodes.new('ShaderNodeNormalMap');normal.space='TANGENT'
            tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
            tree.links.new(normal.outputs['Normal'],shader.inputs['Normal'])
bpy.ops.object.select_all(action='DESELECT');low.select_set(True);bpy.context.view_layer.objects.active=low
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_tangents=True)
results.update(original_triangles=original,triangles=sum(len(p.vertices)-2 for p in low.data.polygons),source=str(source),seconds=time.time()-started,device=device,cage=diag*0.005,max_ray=diag*0.03,reunwrap=reunwrap,ao_source='low-only; avoid high/low overlap self-occlusion')
output.with_suffix('.bake.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print('BAKE_COMPLETE',json.dumps(results),flush=True)
