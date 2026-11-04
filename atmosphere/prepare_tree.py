"""Blender: preserve UV/material domains while making three 3D tree LODs."""
import bpy,json,sys
from pathlib import Path
p=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(p/'source/tree/tree_prepared.gltf'))
masters=[o for o in bpy.context.scene.objects if o.type=='MESH']
for obj in masters:
    # Branch maps all use glTF UV1 with a shared scale. Bake that into UV0;
    # custom Godot shaders then need no hidden importer UV transform.
    if len(obj.data.uv_layers)>1:
        uv0=obj.data.uv_layers[0];uv1=obj.data.uv_layers[1]
        for poly in obj.data.polygons:
            if 'branch' in obj.data.materials[poly.material_index].name.lower():
                for loop in poly.loop_indices:
                    uv0.data[loop].uv=(uv1.data[loop].uv.x*3.0,uv1.data[loop].uv.y*0.5999999046325684)
        while len(obj.data.uv_layers)>1:obj.data.uv_layers.remove(obj.data.uv_layers[-1])
        obj.data.uv_layers[0].active_render=True
    for mat in obj.data.materials:
        if 'branch' in mat.name.lower():
            for node in mat.node_tree.nodes:
                if node.type=='TEX_IMAGE':
                    for link in list(node.inputs['Vector'].links):mat.node_tree.links.remove(link)
original=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in masters)
report={'source_triangles':original,'lods':{},'textures':'4K, alpha restored from verified separate source','whole_plant_billboards':False}
out=p/'assets';out.mkdir(exist_ok=True)
for label,target in [('high',260000),('mid',80000),('low',28000)]:
    copies=[]
    for source in masters:
        obj=source.copy();obj.data=source.data.copy();bpy.context.collection.objects.link(obj)
        obj.name='Tree_'+label+'_'+source.name
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('material_boundary_preserving_lod','DECIMATE')
        mod.ratio=min(1,target/original)
        mod.use_collapse_triangulate=True
        mod.delimit={'MATERIAL','UV','SEAM'}
        bpy.ops.object.modifier_apply(modifier=mod.name)
        copies.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in copies:obj.select_set(True)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.export_scene.gltf(filepath=str(out/f'tree_{label}.glb'),export_format='GLB',use_selection=True,export_tangents=True)
    report['lods'][label]=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in copies)
    for obj in copies:bpy.data.objects.remove(obj,do_unlink=True)
(out/'tree_lod_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('TREE_LODS_COMPLETE',report,flush=True)
