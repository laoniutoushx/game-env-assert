"""Deterministic editable geometry kit. Run inside Blender through the local MCP bridge."""
import bpy,math,random,json,bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path('H:/game-workflow/work/environment_ruins/model_v3')
OUT=ROOT/'assets'; OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
random.seed(73109)
catalog=[]; exported=[]

def material(name,color,rough=.78):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(1,1,1,1);p.inputs['Roughness'].default_value=rough
    attr=m.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Color'
    m.node_tree.links.new(attr.outputs['Color'],p.inputs['Base Color'])
    return m
leafmat=material('Leaf_geometry',(0.18,.31,.065));stonemat=material('Stone_PBR_slot',(.47,.49,.43));barkmat=material('Bark_PBR_slot',(.19,.12,.065));flowermat=material('Petal_geometry',(.8,.78,.65))
class Builder:
    def __init__(self):self.v=[];self.f=[];self.uv=[];self.c=[]
    def vertex(self,p,uv=(0,0),c=(.19,.34,.075,1)):
        self.v.append(tuple(p));self.uv.append(uv);self.c.append(c);return len(self.v)-1
    def leaf(self,a,b,width,bend=.025,color=(.19,.34,.075,1),steps=5,roll=0):
        a=Vector(a);b=Vector(b);axis=(b-a).normalized();side=axis.cross(Vector((0,0,1)))
        if side.length<.01:side=Vector((1,0,0))
        side.normalize();normal=side.cross(axis).normalized()
        side2=side*math.cos(roll)+normal*math.sin(roll);normal=side.cross(axis).normalized()
        ids=[]
        for j in range(steps+1):
            t=j/steps;shape=max(.025,math.sin(math.pi*t)**.72)*(1-.25*t)
            row=[]
            for k in [-1,0,1]:
                p=a.lerp(b,t)+side2*(width*.5*k*shape)+normal*(bend*math.sin(math.pi*t)+abs(k)*width*.13*shape)
                col=tuple(x*(1.08 if k==0 else .94) for x in color[:3])+(1,)
                row.append(self.vertex(p,((k+1)*.5,t),col))
            ids.append(row)
        for j in range(steps):
            for k in range(2):self.f.append((ids[j][k],ids[j+1][k],ids[j+1][k+1],ids[j][k+1]))
    def tube(self,points,radii,color=(.22,.28,.07,1),sides=6):
        ids=[]
        for i,point in enumerate(points):
            tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
            tangent.normalize();u=tangent.cross(Vector((0,0,1)))
            if u.length<.01:u=Vector((1,0,0))
            u.normalize();v=tangent.cross(u).normalized();row=[]
            for s in range(sides):
                angle=math.tau*s/sides
                row.append(self.vertex(Vector(point)+radii[i]*(u*math.cos(angle)+v*math.sin(angle)),(s/sides,i/max(1,len(points)-1)),color))
            ids.append(row)
        for i in range(len(ids)-1):
            for s in range(sides):self.f.append((ids[i][s],ids[i][(s+1)%sides],ids[i+1][(s+1)%sides],ids[i+1][s]))
        self.f.extend([tuple(reversed(ids[0])),tuple(ids[-1])])
    def object(self,name,mat):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(self.v,[],self.f);mesh.update()
        uv=mesh.uv_layers.new(name='UVMap');colors=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
        for i,c in enumerate(self.c):colors.data[i].color=c
        mesh.color_attributes.active_color=colors
        mesh.color_attributes.render_color_index=0
        for poly in mesh.polygons:
            for loop in poly.loop_indices:uv.data[loop].uv=self.uv[mesh.loops[loop].vertex_index]
            poly.use_smooth=True
        ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ob.data.materials.append(mat)
        return ob

def export(ob,name,kind,lod=0):
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    if kind in ['stone','rock','ruin']:
        if kind=='stone':
            uv=ob.data.uv_layers.active
            for poly in ob.data.polygons:
                for li in poly.loop_indices:
                    v=ob.data.vertices[ob.data.loops[li].vertex_index].co
                    uv.data[li].uv=(v.x+.5,v.y+.5) if abs(poly.normal.z)>.6 else ((v.y if abs(poly.normal.x)>.5 else v.x)+.5,v.z/.16)
        ob.data.uv_layers.new(name='LightmapUV')
        ob.data.uv_layers.active_index=len(ob.data.uv_layers)-1
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
        ob.data.uv_layers.active_index=0
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT',export_image_format='NONE',export_animations=False,export_vertex_color='ACTIVE')
    ob.data.calc_loop_triangles();catalog.append({'name':name,'kind':kind,'lod':lod,'triangles':len(ob.data.loop_triangles),'vertices':len(ob.data.vertices),'geometry_only_silhouette':True,'file':name+'.glb'})
    exported.append(ob);print('ASSET',name,len(ob.data.loop_triangles),flush=True)

def fern(kind,lod):
    rng=random.Random(100+kind);m=Builder();count=[11,9,7][lod];pairs=[15,11,8][lod];steps=[5,3,2][lod]
    for f in range(count):
        angle=math.tau*f/count+rng.uniform(-.14,.14);d=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-d.y,d.x,0))
        extent=rng.uniform(.55,.85)*(1 if kind==0 else .75);height=rng.uniform(.45,.70)*(1 if kind==0 else 1.5)
        def point(t):return d*(extent*t)+Vector((0,0,height*math.sin(math.pi*t*.83)))
        pts=[point(t/12) for t in range(13)];m.tube(pts,[.009*(1-t/14) for t in range(13)],sides=5)
        for j in range(pairs):
            t=.13+.82*j/pairs;base=point(t)
            length=.20*math.sin(math.pi*(t+.03))**.7*(1 if kind==0 else .8)
            for sign in [-1,1]:
                tip=base+side*(sign*length)+d*(length*.31)+Vector((0,0,.012+length*.12))
                tint=rng.uniform(.85,1.12);col=(.20*tint,.33*tint,.065*tint,1)
                m.leaf(base,tip,length*(.29 if kind==0 else .39),bend=length*.13,color=col,steps=steps,roll=sign*.18)
        m.leaf(point(.88),point(1.06),.032,steps=steps)
    return m.object('fern_%d_lod%d'%(kind,lod),leafmat)

def flowers(kind,lod):
    rng=random.Random(900+kind);m=Builder()
    for k in range(9 if lod==0 else 6):
        x=rng.uniform(-.28,.28);y=rng.uniform(-.24,.24);h=rng.uniform(.24,.47)*(1 if kind==0 else 1.3)
        base=Vector((x,y,0));head=Vector((x+.025,y,h));m.tube([base,base.lerp(head,.5)+Vector((.025,0,0)),head],[.004,.003,.002],sides=5)
        for sign in [-1,1]:m.leaf(base.lerp(head,.4),base.lerp(head,.62)+Vector((sign*.09,.04,0)),.035,steps=3)
        levels=1 if kind==0 else 4
        for level in range(levels):
            center=head-Vector((0,0,level*.045));rad=.032 if kind==0 else .022
            for j in range(9 if kind==0 else 5):
                a=math.tau*j/(9 if kind==0 else 5)+level*.7
                tip=center+Vector((math.cos(a)*rad,math.sin(a)*rad,.008 if kind==0 else -.014))
                color=(.86,.84,.71,1) if kind==0 else (.30,.12,.43,1)
                m.leaf(center,tip,.016,bend=.009,color=color,steps=3 if lod==0 else 2)
            m.tube([center-Vector((0,0,.002)),center+Vector((0,0,.007))],[.009,.005],color=(.62,.35,.035,1),sides=9)
    return m.object('flowers_%d_lod%d'%(kind,lod),flowermat)

def stone(index):
    rng=random.Random(300+index);parts=[]
    outline=[(-.48,-.42),(-.39,-.50),(.36,-.49),(.49,-.37),(.47,.34),(.37,.49),(-.34,.48),(-.50,.33)]
    outline=[(x+rng.uniform(-.025,.025),y+rng.uniform(-.025,.025)) for x,y in outline]
    polygons=[outline]
    if index in [3,4]:
        def clip(poly,sign):
            result=[]
            for i,a in enumerate(poly):
                b=poly[(i+1)%len(poly)];va=(a[0]+a[1]*.3)*sign-.012;vb=(b[0]+b[1]*.3)*sign-.012
                if va>=0:result.append(a)
                if (va>=0)!=(vb>=0):
                    t=va/(va-vb);result.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t))
            return result
        polygons=[clip(outline,1),clip(outline,-1)]
    m=Builder()
    for poly in polygons:
        bottom=[];top=[]
        for x,y in poly:
            bottom.append(m.vertex((x*.96,y*.96,0),(x+.5,y+.5),(.65,.65,.65,1)))
            top.append(m.vertex((x,y,.16+rng.uniform(-.007,.007)),(x+.5,y+.5),(.98,.98,.98,1)))
        m.f.extend([tuple(reversed(bottom)),tuple(top)])
        for j in range(len(poly)):m.f.append((bottom[j],bottom[(j+1)%len(poly)],top[(j+1)%len(poly)],top[j]))
    ob=m.object('slab_%d'%index,stonemat)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    bevel=ob.modifiers.new('Worn edge radius','BEVEL');bevel.width=.018;bevel.segments=3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for p in ob.data.polygons:p.use_smooth=False
    if index in [5,6]:
        # Recessed angular glyph strokes cut into the stone; not floating text.
        for row in range(2):
            for col in range(5):
                x=-.31+col*.145;y=-.17+row*.30
                for angle,offset in [(0,0),(.65,.025)]:
                    bpy.ops.mesh.primitive_cube_add(size=1,location=(x+offset,y,.159))
                    cutter=bpy.context.object;cutter.scale=(.010,.13,.025);cutter.rotation_euler.z=angle if (col+row+index)%2 else -angle
                    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
                    mod=ob.modifiers.new('Incised rune','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
                    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
                    bpy.data.objects.remove(cutter,do_unlink=True)
    if index==7:
        for v in ob.data.vertices:
            x,y,z=v.co;angle=x*.55;radius=1.8+y;v.co=(math.sin(angle)*radius,math.cos(angle)*radius-1.8,z)
    # Boolean-created vertices otherwise inherit black default attribute values.
    colors=ob.data.color_attributes.get('Color')
    if colors and colors.domain=='POINT':
        for v in ob.data.vertices:
            shade=.98 if v.co.z>.11 else .65
            colors.data[v.index].color=(shade,shade,shade,1)
    return ob

def rock(index,lod):
    rng=random.Random(400+index)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3 if lod==0 else 2,radius=1)
    ob=bpy.context.object;ob.name='rock_%d_lod%d'%(index,lod)
    for v in ob.data.vertices:
        p=v.co;noise=1+.12*math.sin(p.x*7+index)*math.cos(p.y*5)+.10*math.sin(p.z*9+p.x*3)
        p.x*=noise*.74;p.y*=noise*.55;p.z=max(-.46,p.z*noise*.52);p.z+=.46
    colors=ob.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    ob.data.color_attributes.active_color=colors;ob.data.color_attributes.render_color_index=0
    for v in ob.data.vertices:
        moss=max(0,min(1,(v.co.z-.48)*1.7+.2*math.sin(v.co.x*7)))
        colors.data[v.index].color=(.68*(1-moss)+.29*moss,.69*(1-moss)+.40*moss,.64*(1-moss)+.11*moss,1)
    ob.data.materials.append(stonemat)
    for poly in ob.data.polygons:poly.use_smooth=True
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.03);bpy.ops.object.mode_set(mode='OBJECT')
    return ob

def column():
    m=Builder();rings=[];sides=48
    for j in range(9):
        z=j*.12;ring=[]
        for k in range(sides):
            a=math.tau*k/sides;r=.22-.018*(.5+.5*math.cos(a*12))
            zz=z+(0.08*math.sin(a*3)+.035*math.cos(a*7) if j==8 else 0)
            ring.append(m.vertex((r*math.cos(a),r*math.sin(a),zz),(k/sides,z),(.84,.85,.81,1)))
        rings.append(ring)
    for j in range(8):
        for k in range(sides):m.f.append((rings[j][k],rings[j][(k+1)%sides],rings[j+1][(k+1)%sides],rings[j+1][k]))
    m.f.extend([tuple(reversed(rings[0])),tuple(rings[-1])]);return m.object('fallen_column',stonemat)

def tree(lod):
    rng=random.Random(1312);m=Builder();trunk=[Vector((.06*math.sin(j*.7),.05*math.sin(j*.5),j*.4)) for j in range(11)]
    m.tube(trunk,[.20*(1-j/13)**1.3 for j in range(11)],color=(.25,.18,.10,1),sides=10 if lod==0 else 6)
    for i in range(12 if lod==0 else 9):
        a=i*2.399;start=trunk[3+i%6];reach=1.1+(.3 if i%3 else 0)
        end=start+Vector((math.cos(a)*reach,math.sin(a)*reach,.65+rng.random()*.6))
        mid=start.lerp(end,.5)+Vector((0,0,.2));m.tube([start,mid,end],[.055,.026,.008],color=(.26,.18,.10,1),sides=7 if lod==0 else 5)
        for j in range(7 if lod<2 else 4):
            t=.35+j*.09;base=mid.lerp(end,min(t*1.2,1))
            aa=a+j*1.9;tip=base+Vector((math.cos(aa)*.50,math.sin(aa)*.50,.28))
            m.tube([base,base.lerp(tip,.5),tip],[.013,.007,.002],color=(.25,.2,.1,1),sides=4)
            for k in range(16 if lod==0 else (11 if lod==1 else 7)):
                p=base.lerp(tip,rng.random())+Vector((rng.uniform(-.27,.27),rng.uniform(-.27,.27),rng.uniform(-.18,.22)))
                theta=rng.random()*math.tau;length=rng.uniform(.10,.19);q=p+Vector((math.cos(theta)*length,math.sin(theta)*length,rng.uniform(-.04,.07)))
                g=rng.uniform(.8,1.25);m.leaf(p,q,length*.55,.025,color=(.13*g,.26*g,.045*g,1),steps=3 if lod==0 else 2,roll=rng.uniform(-.5,.5))
    # Buttress roots visibly enter the ground.
    for i in range(6):
        a=i*math.tau/6;m.tube([Vector((0,0,.3)),Vector((math.cos(a)*.32,math.sin(a)*.32,.06)),Vector((math.cos(a)*.58,math.sin(a)*.58,-.025))],[.11,.065,.01],color=(.25,.18,.1,1),sides=6)
    return m.object('hero_tree_lod%d'%lod,leafmat)

import numpy as np
tex=ROOT/'textures';tex.mkdir(exist_ok=True)
yy,xx=np.mgrid[0:512,0:512].astype(np.float32)/511
rib=np.exp(-((xx-.5)/.018)**2)
veins=np.exp(-(np.sin((yy-np.abs(xx-.5)*.5)*math.pi*18)/.17)**2)*(.4+.6*yy)
height=.6*rib+.13*veins
gy,gx=np.gradient(height)
normal=np.stack((-gx*5,-gy*5,np.ones_like(xx)),axis=2);normal/=np.linalg.norm(normal,axis=2,keepdims=True)
for name,rgb in [('leaf_detail',np.repeat((.86+.08*rib-.045*veins)[:,:,None],3,axis=2)),('leaf_normal',normal*.5+.5)]:
    im=bpy.data.images.new(name,width=512,height=512,alpha=True)
    im.pixels.foreach_set(np.concatenate((rgb,np.ones((512,512,1))),axis=2).astype(np.float32).ravel())
    im.filepath_raw=str(tex/(name+'.png'));im.file_format='PNG';im.save()
for kind in range(2):
    for lod in range(3):
        ob=fern(kind,lod);export(ob,ob.name,'fern',lod)
    for lod in range(2):
        ob=flowers(kind,lod);export(ob,ob.name,'flowers',lod)
for i in range(8):
    ob=stone(i);export(ob,ob.name,'stone')
for i in range(2):
    for lod in range(2):
        ob=rock(i,lod);export(ob,ob.name,'rock',lod)
ob=column();export(ob,ob.name,'ruin')
for lod in range(3):
    ob=tree(lod);export(ob,ob.name,'tree',lod)
for i,ob in enumerate(exported):ob.location=(i%7*2.5,i//7*3.0,0)
source=ROOT/'source';source.mkdir(exist_ok=True);(source/'.gdignore').touch()
bpy.ops.wm.save_as_mainfile(filepath=str(source/'ruins_model_kit.blend'))
(OUT/'geometry_catalog.json').write_text(json.dumps({'generator':'build_assets.py','seed':73109,'blender':bpy.app.version_string,'assets':catalog,'paid_generation':False},indent=2),encoding='utf-8')
print('MODEL_KIT_COMPLETE',len(catalog),sum(x['triangles'] for x in catalog),flush=True)
