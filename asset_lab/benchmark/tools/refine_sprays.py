"""Offline, editable leaf-spray study and crown replacement; no runtime generation.

Run with --sample first. The full mode loads the existing source trunk/branches,
replaces only the canopy, and samples actual BVH visibility for vertex AO.
"""
import bpy, math, random, json, sys
from pathlib import Path
from mathutils import Vector, Euler
from mathutils.bvhtree import BVHTree

OUT=Path(__file__).resolve().parents[1]
SAMPLE='--sample' in sys.argv
rng=random.Random(263)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/broadleaf_editable.blend'))
scene=bpy.context.scene
leaf_material=bpy.data.materials.get('Leaf_PBR_Painted')
bark_material=next(m for m in bpy.data.materials if 'trunk' in m.name and m.use_nodes)
if SAMPLE:
    scene=bpy.data.scenes.new('Branch_Two_Leaf_Sprays')
    bpy.context.window.scene=scene
    canopy=scene.collection
else:
    canopy=bpy.data.collections['02_Canopy_30_Editable_Clumps']
    for ob in list(canopy.objects):bpy.data.objects.remove(ob,do_unlink=True)
    for ob in list(scene.objects):
        if ob.name.startswith('TwigBranches'):bpy.data.objects.remove(ob,do_unlink=True)

stem_vertices=[];stem_faces=[];stem_uv=[]
leaf_records=[]
# Twelve boundary segments preserve a rounded, narrow ovate leaf at a smaller scale.
outline=[(0,-.17)]
for j in range(1,6):
    t=j/6;outline.append((.077*math.sin(math.pi*t)**.8,-.17+.36*t))
outline.append((0,.19))
for j in range(5,0,-1):
    t=j/6;outline.append((-.077*math.sin(math.pi*t)**.8,-.17+.36*t))
prototype=[Vector((0,.005,.022))]+[Vector((x,y,-.009*(y/.19)**2)) for x,y in outline]
uvs=[(.5,.5)]+[(x/.16+.5,(y+.18)/.38) for x,y in outline]
faces=[(0,1+i,1+(i+1)%12) for i in range(12)]
leaf_base=prototype[1]

def tube(points,radii):
    start=len(stem_vertices)
    for ring,(p,r) in enumerate(zip(points,radii)):
        tangent=(points[min(ring+1,len(points)-1)]-points[max(0,ring-1)]).normalized()
        side=tangent.cross(Vector((0,0,1))).normalized()
        up=tangent.cross(side).normalized()
        for j in range(3):
            a=j*math.tau/3
            stem_vertices.append(tuple(p+(side*math.cos(a)+up*math.sin(a))*r))
    for ring in range(len(points)-1):
        for j in range(3):
            a=start+ring*3+j;b=start+ring*3+(j+1)%3;c=a+3;d=b+3
            stem_faces.extend([(a,b,d),(a,d,c)])
    stem_faces.extend([(start+2,start+1,start),(start+6,start+7,start+8)])

def spray(index,anchor,yaw,tilt,size=1):
    pose=Euler((tilt,rng.uniform(-.18,.18),yaw),'XYZ').to_matrix()
    # All leaves attach by their petiole to a real tapering twig.
    def world(p):return anchor+pose@(p*size)
    tube([world(Vector((0,0,0))),world(Vector((0,.40,.04))),world(Vector((0,.82,.10)))],[.012*size,.007*size,.0025*size])
    vertices=[];polygons=[];normals=[];colors=[];all_uv=[]
    tint=rng.uniform(.35,.65)
    for leaf in range(17):
        terminal=leaf==16
        station=.065+(leaf//2)*.09 if not terminal else .82
        side=-1 if leaf%2 else 1
        attach=Vector((0,station,.10*(station/.82)**1.3))
        angle=(side*rng.uniform(.90,1.35)) if not terminal else rng.uniform(-.18,.18)
        leaf_rot=Euler((rng.uniform(-.48,.45),rng.uniform(-.48,.48),angle),'XYZ').to_matrix()
        scale=rng.uniform(.88,1.22)*(1.08 if terminal else 1)
        offset=len(vertices)
        normal=(pose@leaf_rot@Vector((0,0,1))).normalized()
        world_attach=world(attach)
        for vi,p in enumerate(prototype):
            co=world(attach+leaf_rot@((p-leaf_base)*scale))
            vertices.append(tuple(co))
            local_dome=(co-(anchor+pose@Vector((0,.38,-.30)))).normalized()
            normals.append(tuple((normal*.72+local_dome*.28).normalized()))
            colors.append((1,tint,max(0,min(1,(co.z-.6)/3.5))*uvs[vi][1],1))
        for face in faces:
            polygons.append(tuple(offset+i for i in face));all_uv.extend(uvs[i] for i in face)
        leaf_records.append((index,leaf,Vector(vertices[offset]),normal))
    mesh=bpy.data.meshes.new('SprayMesh_%02d'%index)
    mesh.from_pydata(vertices,[],polygons);mesh.update()
    for f in mesh.polygons:f.use_smooth=True
    mesh.normals_split_custom_set_from_vertices(normals)
    uv=mesh.uv_layers.new(name='UVMap')
    for i,value in enumerate(all_uv):uv.data[i].uv=value
    attr=mesh.color_attributes.new(name='AssetData',type='FLOAT_COLOR',domain='POINT')
    for i,value in enumerate(colors):attr.data[i].color=value
    mesh.color_attributes.active_color_name='AssetData'
    ob=bpy.data.objects.new('LeafClump_%02d'%index,mesh);canopy.objects.link(ob)
    ob.data.materials.append(leaf_material)
    ob['role']='benchmark_asset';ob['leaf_count']=17;ob['normal_blend']=.28
    ob['construction']='17 individual leaves anchored to a real twig; no shell-shingle distribution'
    return ob

sprays=[]
if SAMPLE:
    sprays.append(spray(0,Vector((-.12,0,.1)),-.65,.18,1))
    sprays.append(spray(1,Vector((.12,.30,.18)),.70,.28,.95))
    tube([Vector((0,-.35,.02)),Vector((0,.05,.1)),Vector((.12,.30,.18))],[.025,.015,.007])
else:
    # Uneven branch endpoints, not three horizontal tiers or ten closed domes.
    forms=[(-1.08,-.42,2.08,.92),(1.12,-.35,2.12,.95),(-.72,-.42,2.66,1.0),(.76,-.38,2.70,.92),(-.28,.10,3.18,.90),(.02,.68,2.68,.95)]
    for main,(x,y,z,size) in enumerate(forms):
        outward=math.atan2(-x,y)
        for sub in range(5):
            yaw=outward+[-.95,-.48,.02,.43,.88][sub]+rng.uniform(-.12,.12)
            tilt=[.08,.27,.58,.36,.12][sub]+rng.uniform(-.08,.08)
            anchor=Vector((x,y,z))+Vector((rng.uniform(-.035,.035),rng.uniform(-.035,.035),rng.uniform(-.035,.035)))
            sprays.append(spray(main*5+sub,anchor,yaw,tilt,size*rng.uniform(.94,1.06)))

mesh=bpy.data.meshes.new('TwigBranches');mesh.from_pydata(stem_vertices,[],stem_faces);mesh.update()
twig=bpy.data.objects.new('TwigBranches_LOD0',mesh);scene.collection.objects.link(twig)
twig['role']='benchmark_asset';twig.data.materials.append(bark_material)
for f in mesh.polygons:f.use_smooth=True
bpy.context.view_layer.objects.active=twig;twig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')

objects=[o for o in scene.objects if o.get('role')=='benchmark_asset']
verts=[];polys=[];owners=[]
for ob in objects:
    start=len(verts);verts.extend(tuple(ob.matrix_world@v.co) for v in ob.data.vertices)
    for f in ob.data.polygons:
        polys.append(tuple(start+i for i in f.vertices))
        owners.append((ob.name,f.index//12 if ob in sprays else -1))
bvh=BVHTree.FromPolygons(verts,polys,all_triangles=False,epsilon=.0001)
ao_values=[]
for group,leaf,point,normal in leaf_records:
    tangent=normal.cross(Vector((1,0,0)) if abs(normal.x)<.8 else Vector((0,1,0))).normalized()
    bitangent=normal.cross(tangent).normalized()
    visible=0
    for ray in range(24):
        z=(ray+.5)/24;r=math.sqrt(1-z*z);a=ray*2.399963
        direction=(tangent*(r*math.cos(a))+bitangent*(r*math.sin(a))+normal*z).normalized()
        origin=point+normal*.008;remaining=1.0;blocked=False
        for crossing in range(6):
            hit,_,face,distance=bvh.ray_cast(origin,direction,remaining)
            if hit is None:break
            if owners[face]!=(sprays[group].name,leaf):blocked=True;break
            remaining-=distance+.004;origin=hit+direction*.004
            if remaining<=0:break
        if not blocked:visible+=1
    ao=visible/24;ao_values.append(ao)
    data=sprays[group].data.color_attributes['AssetData'].data
    for i in range(13):
        entry=data[leaf*13+i];color=list(entry.color);color[0]=ao;entry.color=color

scene['construction']='Offline editable branch-spray refinement. Not represented as manual UI modeling.'
scene['vertex_contract']='R BVH hemisphere visibility (24 rays/leaf, 1m radius), G neutral color variation, B tip wind weight'
scene['leaf_count']=len(leaf_records)
report={'leaves':len(leaf_records),'clumps':len(sprays),'leaf_triangles':12,'triangles':sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects),'ao_method':'24 actual BVH visibility rays per leaf; no height-based AO','ao_min':min(ao_values),'ao_mean':sum(ao_values)/len(ao_values),'ao_max':max(ao_values),'process':'offline editable Blender assembly'}
if SAMPLE:
    for other in list(bpy.data.scenes):
        if other!=scene:bpy.data.scenes.remove(other)
    bpy.data.orphans_purge(do_recursive=True)
    path=OUT/'source/leaf_spray_study.blend'
else:
    # Update the editable leaf modules instead of leaving obsolete half-meter templates.
    mods=bpy.data.collections.get('91_Leaf_Modules_NO_EXPORT')
    if mods:
        for ob in list(mods.objects):bpy.data.objects.remove(ob,do_unlink=True)
        for i in range(4):
            me=bpy.data.meshes.new('Leaf_Module_%02d'%i);me.from_pydata(prototype,[],faces);me.update()
            ob=bpy.data.objects.new(me.name,me);mods.objects.link(ob);ob.hide_viewport=True;ob.hide_render=True
            uv=me.uv_layers.new(name='UVMap')
            for f in me.polygons:
                for li in f.loop_indices:uv.data[li].uv=uvs[me.loops[li].vertex_index]
    path=OUT/'source/broadleaf_editable.blend'
scene['lod0_triangles']=report['triangles']
bpy.ops.wm.save_as_mainfile(filepath=str(path))
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:
    ob.select_set(True)
    ob.data.materials.clear()
    m=bpy.data.materials.get('Study_Leaf' if ob in sprays else 'Study_Bark')
    if m is None:m=bpy.data.materials.new('Study_Leaf' if ob in sprays else 'Study_Bark')
    ob.data.materials.append(m)
    for f in ob.data.polygons:f.material_index=0
target=OUT/'models/leaf_spray_study.glb' if SAMPLE else OUT/'models/broadleaf_lod0.glb'
bpy.ops.export_scene.gltf(filepath=str(target),use_selection=True,use_active_scene=True,export_format='GLB',export_normals=True,export_tangents=True,export_vertex_color='ACTIVE',export_all_vertex_colors=False)
(OUT/'reports'/('spray_study.json' if SAMPLE else 'geometry.json')).write_text(json.dumps(report,indent=2))
print('SPRAY_REFINEMENT',report)
