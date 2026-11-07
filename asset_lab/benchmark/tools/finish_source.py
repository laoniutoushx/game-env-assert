"""Offline texture baking and explicit whole-leaf LOD preparation in Blender."""
import bpy, bmesh, json, math
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1]
ROOT=OUT.parents[1]
bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/broadleaf_editable.blend'))
source_scene=bpy.context.scene
source_objects=[o for o in source_scene.objects if o.get('role')=='benchmark_asset']
leaves=[o for o in source_objects if o.name.startswith('LeafClump')]

# Build a UV-space, light-independent leaf material. All nodes are retained.
bake_scene=bpy.data.scenes.new('Leaf_Texture_Bake_Source')
bpy.context.window.scene=bake_scene
mesh=bpy.data.meshes.new('Leaf_Texture_Canvas')
mesh.from_pydata([(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0)],[],[(0,1,2,3)])
uv=mesh.uv_layers.new(name='UVMap')
for i,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=co
plane=bpy.data.objects.new('Editable_UV_Bake_Canvas',mesh);bake_scene.collection.objects.link(plane)
plane.select_set(True);bpy.context.view_layer.objects.active=plane
material=bpy.data.materials.new('Editable_Leaf_Venation_and_Color');material.use_nodes=True
plane.data.materials.append(material)
nt=material.node_tree;nt.nodes.clear()
out=nt.nodes.new('ShaderNodeOutputMaterial');emit=nt.nodes.new('ShaderNodeEmission')
nt.links.new(emit.outputs[0],out.inputs['Surface'])
coord=nt.nodes.new('ShaderNodeTexCoord');sep=nt.nodes.new('ShaderNodeSeparateXYZ')
nt.links.new(coord.outputs['UV'],sep.inputs[0])
def mathnode(op,a,b=None):
    n=nt.nodes.new('ShaderNodeMath');n.operation=op
    for i,v in enumerate([a,b]):
        if v is None:continue
        if isinstance(v,(int,float)):n.inputs[i].default_value=v
        else:nt.links.new(v,n.inputs[i])
    return n.outputs[0]
x=mathnode('ABSOLUTE',mathnode('SUBTRACT',sep.outputs['X'],.5))
phase=mathnode('SUBTRACT',mathnode('MULTIPLY',sep.outputs['Y'],32),mathnode('MULTIPLY',x,23))
veins=mathnode('LESS_THAN',mathnode('ABSOLUTE',mathnode('SINE',phase)),.085)
midrib=mathnode('LESS_THAN',x,.012)
veins=mathnode('MAXIMUM',veins,midrib)
noise=nt.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=26
noise.inputs['Detail'].default_value=2;nt.links.new(coord.outputs['UV'],noise.inputs['Vector'])
factor=mathnode('ADD',mathnode('MULTIPLY',noise.outputs['Fac'],.5),mathnode('MULTIPLY',sep.outputs['Y'],.35))
factor=mathnode('ADD',factor,mathnode('MULTIPLY',veins,.16))
ramp=nt.nodes.new('ShaderNodeValToRGB');nt.links.new(factor,ramp.inputs[0])
nt.links.new(ramp.outputs['Color'],emit.inputs['Color'])
target=nt.nodes.new('ShaderNodeTexImage');target.label='Active bake target'
nt.nodes.active=target
bake_scene.render.engine='CYCLES';bake_scene.cycles.samples=1
bake_scene.render.bake.margin=16
textures={}
for style,colors in [('natural',((.055,.135,.018,1),(.19,.32,.045,1))),('painted',((.11,.25,.035,1),(.30,.46,.075,1)))]:
    for e,c in zip(ramp.color_ramp.elements,colors):e.color=c
    im=bpy.data.images.new('leaf_'+style,1024,1024,alpha=False)
    target.image=im
    bpy.ops.object.bake(type='EMIT')
    im.filepath_raw=str(OUT/f'textures/leaf_{style}_base.png');im.file_format='PNG';im.save()
    textures[style]=im
# Tangent normal from editable procedural veins, not painted illumination.
bs=nt.nodes.new('ShaderNodeBsdfPrincipled');bump=nt.nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value=.25;bump.inputs['Distance'].default_value=.012
nt.links.new(veins,bump.inputs['Height']);nt.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
nt.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
normal=bpy.data.images.new('leaf_normal_gl',1024,1024,alpha=False)
normal.colorspace_settings.name='Non-Color';target.image=normal
bpy.ops.object.bake(type='NORMAL')
normal.filepath_raw=str(OUT/'textures/leaf_normal_gl.png');normal.file_format='PNG';normal.save()
# Bake source can be inspected as a node graph. It has no direct lighting.
bake_scene['instructions']='Edit palette ramp / vein math, select target image, Cycles Bake Emit or Normal.'

bpy.context.window.scene=source_scene
for part in ('trunk',):
    for kind in ('base','normal','orm'):
        img=bpy.data.images.load(str(ROOT/f'atmosphere/textures/tree_{part}_{kind}.jpg'),check_existing=False)
        if kind!='base':img.colorspace_settings.name='Non-Color'
        _=img.pixels[0]
        img.scale(2048,2048)
        img.filepath_raw=str(OUT/f'textures/bark_{kind}.png');img.file_format='PNG'
        img.save()

for ob in leaves:
    mat=bpy.data.materials.new('Leaf_PBR_Painted') if 'Leaf_PBR_Painted' not in bpy.data.materials else bpy.data.materials['Leaf_PBR_Painted']
    mat.use_nodes=True;nt2=mat.node_tree;bs2=nt2.nodes.get('Principled BSDF')
    if not any(n.type=='TEX_IMAGE' for n in nt2.nodes):
        tx=nt2.nodes.new('ShaderNodeTexImage');tx.image=textures['painted'];nt2.links.new(tx.outputs['Color'],bs2.inputs['Base Color'])
        bs2.inputs['Roughness'].default_value=.8
    ob.data.materials.clear();ob.data.materials.append(mat)
    ob.data.color_attributes.active_color_name='AssetData'

source_scene['texture_method']='Blender procedural UV bake, editable nodes. Not hand-painted or AI-generated.'
source_scene['leaf_count']=360
for im in bpy.data.images:
    if im.filepath and Path(bpy.path.abspath(im.filepath)).is_file():
        try:
            im.source='FILE';im.reload();_=im.pixels[0];im.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/broadleaf_editable.blend'))

def export_lod(level):
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    names={src:src.name for src in source_objects}
    for src,name in names.items():src.name='SOURCE_ONLY_'+name
    for src in source_objects:
        ob=src.copy();ob.data=src.data.copy();source_scene.collection.objects.link(ob)
        ob.name=names[src]
        if src in leaves and level==2:
            bounds=[Vector(p) for p in src.bound_box]
            low=Vector(tuple(min(p[j] for p in bounds) for j in range(3)))
            high=Vector(tuple(max(p[j] for p in bounds) for j in range(3)))
            center=(low+high)*.5;radius=(high-low)*.49
            mesh=bpy.data.meshes.new(src.name+'_VolumeLOD')
            bm=bmesh.new();bmesh.ops.create_icosphere(bm,subdivisions=1,radius=1)
            bm.to_mesh(mesh);bm.free()
            uv=mesh.uv_layers.new(name='UVMap')
            for poly in mesh.polygons:
                poly.use_smooth=True
                for li in poly.loop_indices:
                    v=mesh.vertices[mesh.loops[li].vertex_index].co
                    uv.data[li].uv=(.5+math.atan2(v.y,v.x)/math.tau,.5+math.asin(v.z)/math.pi)
            for v in mesh.vertices:v.co=center+Vector(tuple(v.co[j]*radius[j] for j in range(3)))
            attr=mesh.color_attributes.new(name='AssetData',type='FLOAT_COLOR',domain='POINT')
            for col in attr.data:col.color=(.9,.5,.5,1)
            mesh.color_attributes.active_color_name='AssetData'
            ob.data=mesh
        elif src in leaves and level==1:
            low=Vector(tuple(min(v.co[j] for v in ob.data.vertices) for j in range(3)))
            high=Vector(tuple(max(v.co[j] for v in ob.data.vertices) for j in range(3)))
            for index in range(12):
                if index%2:continue
                verts=list(ob.data.vertices)[index*17:(index+1)*17]
                center=sum((v.co for v in verts),Vector())/len(verts)
                for v in verts:
                    co=center+(v.co-center)*1.28
                    v.co=Vector(tuple(max(low[j],min(high[j],co[j])) for j in range(3)))
            bm=bmesh.new();bm.from_mesh(ob.data);bm.faces.ensure_lookup_table()
            divisor=2
            bmesh.ops.delete(bm,geom=[f for i,f in enumerate(list(bm.faces)) if (i//16)%divisor!=0],context='FACES')
            bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
            bm.to_mesh(ob.data);bm.free()
        elif src not in leaves and level>0:
            mod=ob.modifiers.new('LOD_Trunk_Decimation','DECIMATE');mod.ratio=.65 if level==1 else .30
            bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name)
        ob.data.materials.clear()
        m=bpy.data.materials.get('Export_Leaf') if src in leaves else bpy.data.materials.get('Export_Bark')
        if m is None:m=bpy.data.materials.new('Export_Leaf' if src in leaves else 'Export_Bark')
        ob.data.materials.append(m)
        for poly in ob.data.polygons:poly.material_index=0
        copies.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in copies:ob.select_set(True)
    triangles=sum(sum(len(f.vertices)-2 for f in ob.data.polygons) for ob in copies)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'models/broadleaf_lod{level}.glb'),use_selection=True,use_active_scene=True,export_format='GLB',export_normals=True,export_tangents=True,export_vertex_color='ACTIVE',export_all_vertex_colors=False)
    for ob in copies:bpy.data.objects.remove(ob,do_unlink=True)
    for src,name in names.items():src.name=name
    return triangles
report={f'lod{i}':export_lod(i) for i in range(3)}
(OUT/'reports/lods.json').write_text(json.dumps(report,indent=2))
print('EXPLICIT_LODS',report)
