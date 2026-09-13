"""Render an original fly character at a twin-stick camera-drone remote."""
import json
import math
import sys
import time
from pathlib import Path
import bpy
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:]
root=Path(args[0]).resolve();output=Path(args[1]).resolve();output.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from game_effects import solid
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.cycles.use_denoising=True;scene.cycles.max_bounces=6;scene.cycles.seed=2026
scene.render.use_persistent_data=True
try:
    settings=bpy.context.preferences.addons['cycles'].preferences
    settings.compute_device_type='METAL';settings.get_devices()
    for device in settings.devices:device.use=device.type=='METAL'
    scene.cycles.device='GPU'
except Exception:pass
scene.render.resolution_x=960;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
scene.world.color=(.16,.19,.22)
grey=solid('Remote pale grey',(.52,.57,.57),.34,.15)
trim=solid('Remote seam',(.075,.09,.095),.45)
rubber=solid('Gimbal rubber',(.02,.025,.027),.7)
metal=solid('Joystick shafts',(.38,.42,.43),.2,.8)
amber=solid('Fly amber abdomen',(.22,.075,.012),.45)
stripe=solid('Fly dark bands',(.055,.024,.009),.6)
body=solid('Fly thorax',(.045,.033,.025),.48)
eye_mat=solid('Ruby compound eyes',(.33,.012,.004),.25)
nodes=eye_mat.node_tree.nodes;links=eye_mat.node_tree.links
texture=nodes.new('ShaderNodeTexVoronoi');texture.inputs['Scale'].default_value=75
bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.32;bump.inputs['Distance'].default_value=.015
links.new(texture.outputs['Distance'],bump.inputs['Height']);links.new(bump.outputs['Normal'],nodes.get('Principled BSDF').inputs['Normal'])
red=solid('Record button',(.5,.025,.012),.45)

def uv(name,location,scale,mat,segments=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=16,location=location)
    obj=bpy.context.object;obj.name=name;obj.scale=scale;obj.data.materials.append(mat)
    for polygon in obj.data.polygons:polygon.use_smooth=True
    return obj

def box(name,location,scale,mat,bevel=.1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    modifier=obj.modifiers.new('Soft edges','BEVEL');modifier.width=bevel;modifier.segments=5
    obj.modifiers.new('Face normals','WEIGHTED_NORMAL')
    return obj

def cylinder(name,a,b,radius,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=radius,depth=1)
    obj=bpy.context.object;obj.name=name;obj.data.materials.append(mat)
    set_rod(obj,a,b);return obj

def set_rod(obj,a,b):
    a,b=Vector(a),Vector(b);obj.location=(a+b)/2;obj.scale.z=(b-a).length
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()

box('Controller body',(0,0,0),(3.5,2.65,.36),grey,.2)
box('Controller lower seam',(0,.01,-.08),(3.48,2.6,.18),trim,.18)
for side in [-1,1]:
    uv('Rubber grip',(side*1.47,.15,-.09),(.32,.87,.2),rubber)
    cylinder('Antenna hinge',(side*1.29,1.22,0),(side*1.29,1.38,.16),.085,trim)
    box('Folding antenna',(side*1.29,1.63,.28),(.18,.65,.11),grey,.065).rotation_euler.x=.28

box('Display bezel',(0,-.56,.193),(2.7,1.19,.065),rubber,.11)
screen_material=bpy.data.materials.new('Recorded drone camera display');screen_material.use_nodes=True
nodes=screen_material.node_tree.nodes;links=screen_material.node_tree.links;shader=nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value=.28;shader.inputs['Emission Strength'].default_value=.6
screen_texture=nodes.new('ShaderNodeTexImage')
links.new(screen_texture.outputs['Color'],shader.inputs['Base Color']);links.new(screen_texture.outputs['Color'],shader.inputs['Emission Color'])
bpy.ops.mesh.primitive_plane_add(size=2,location=(0,-.56,.232));screen=bpy.context.object
screen.name='Live image on controller';screen.scale=(1.28,.52,1);screen.data.materials.append(screen_material)

gimbals=[]
for side in [-1,1]:
    x=side*.98;y=.59
    cylinder('Gimbal housing',(x,y,.18),(x,y,.255),.3,trim)
    cylinder('Gimbal inner ring',(x,y,.255),(x,y,.265),.22,rubber)
    base=Vector((x,y,.27));tip=base+Vector((0,0,.24))
    stem=cylinder('Stick shaft',base,tip,.045,metal)
    knob=uv('Stick thumb pad',tip,(.125,.125,.064),rubber)
    gimbals.append((base,stem,knob))
for x,y,mat in [(-1.45,-.62,red),(1.45,-.62,trim),(-.45,.78,grey),(.45,.78,grey)]:
    cylinder('Remote button',(x,y,.19),(x,y,.225),.075,mat)
box('Status light',(0,.4,.203),(.15,.03,.025),solid('Link light',(.03,.4,.12),.25),.01)
bpy.ops.object.text_add(location=(-.39,-1.20,.2));label=bpy.context.object
label.data.body='FLYPILOT';label.data.size=.11;label.data.extrude=.001;label.data.materials.append(trim)

# Six legs, two wings, a banded abdomen, and red compound eyes.
uv('Thorax',(0,1.00,.91),(.34,.43,.34),body)
for i in range(5):
    uv('Abdomen segment '+str(i),(0,1.32+i*.17,.87-i*.035),(.31-i*.041,.16,.27-i*.033),amber if i%2==0 else stripe)
head_parts=[]
head_parts.append(uv('Head',(0,.57,1.05),(.34,.25,.3),body))
for side in [-1,1]:
    head_parts.append(uv('Compound eye',(side*.245,.435,1.11),(.235,.2,.285),eye_mat))
    cylinder('Antenna',(side*.12,.38,1.27),(side*.21,.25,1.39),.016,stripe)
    uv('Antenna tip',(side*.21,.25,1.39),(.035,.027,.024),stripe)
    # Middle and rear legs brace on the remote housing.
    for start,knee,end in [((side*.26,1.03,.82),(side*.64,1.24,.5),(side*.85,1.1,.22)),((side*.23,1.3,.78),(side*.48,1.53,.44),(side*.62,1.22,.22))]:
        cylinder('Leg upper',start,knee,.039,body);cylinder('Leg lower',knee,end,.026,stripe)
        uv('Foot',end,(.07,.035,.025),body)
forelegs=[]
for side,(base,stem,knob) in zip([-1,1],gimbals):
    shoulder=Vector((side*.25,.91,.91));elbow=Vector((side*.62,.81,.81));tip=knob.location.copy()
    upper=cylinder('Foreleg upper',shoulder,elbow,.04,body)
    lower=cylinder('Foreleg lower',elbow,tip,.028,stripe)
    toe=uv('Foreleg on stick',tip,(.07,.055,.04),body)
    forelegs.append((shoulder,elbow,upper,lower,toe))

wing_mat=solid('Translucent wings',(.7,.78,.78),.18)
ws=wing_mat.node_tree.nodes.get('Principled BSDF');ws.inputs['Transmission Weight'].default_value=.68;ws.inputs['IOR'].default_value=1.33
wing_vein=solid('Wing veins',(.17,.2,.17),.55)
wings=[]
for side in [-1,1]:
    root_obj=bpy.data.objects.new('Wing hinge',None);scene.collection.objects.link(root_obj)
    root_obj.location=(side*.13,1.15,1.16)
    vertices=[(side*.58,.36,0)]
    for i in range(40):
        theta=2*math.pi*i/40
        vertices.append((side*(.58+.69*math.cos(theta)),.36+.28*math.sin(theta),.01*math.sin(theta)))
    faces=[(0,i+1,(i+1)%40+1) for i in range(40)]
    mesh=bpy.data.meshes.new('Wing membrane');mesh.from_pydata(vertices,[],faces);mesh.update()
    wing=bpy.data.objects.new('Wing',mesh);scene.collection.objects.link(wing);wing.parent=root_obj;wing.data.materials.append(wing_mat)
    modifier=wing.modifiers.new('Membrane thickness','SOLIDIFY');modifier.thickness=.006
    for j in [-1,0,1]:
        vein=cylinder('Wing vein',(0,0,0),(side*1.13,.36+j*.16,0),.007,wing_vein);vein.parent=root_obj
    wings.append((side,root_obj))
# Fine bristles add scale to the macro character.
for i in range(26):
    angle=2*math.pi*i/26
    a=Vector((.29*math.cos(angle),1+.33*math.sin(angle),1.12))
    b=a+Vector((.045*math.cos(angle),.045*math.sin(angle),.09))
    cylinder('Thorax bristle',a,b,.004,stripe)

floor=solid('Pilot backdrop',(.028,.048,.058),.7)
box('Studio floor',(0,0,-.52),(200,200,.2),floor,0)
for location,power,size,color in [((1,-3,6),600,5,(.78,.89,1)),((-4,2,4),800,4,(1,.7,.42)),((2,4,3),550,3,(.5,.73,1))]:
    bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.data.color=color
    light.rotation_euler=(Vector((0,.5,.5))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3.15,-4.45,4.1));camera=bpy.context.object
camera.rotation_euler=(Vector((0,.4,.5))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=45;scene.camera=camera
frames=json.loads((root/'frames.json').read_text());timings=[];started=time.monotonic()
if '--preview' in args:frames=[frames[min(50,len(frames)-1)]]
for frame in frames:
    t=frame['time'];forward,turn=frame['action']
    tips=[]
    for index,(base,stem,knob) in enumerate(gimbals):
        offset=Vector((max(-1,min(1,turn/.65))*.17,0,.23)) if index==0 else Vector((0,-max(-1,min(1,forward/1.9))*.17,.23))
        tip=base+offset;set_rod(stem,base,tip);knob.location=tip;tips.append(tip)
    for tip,(shoulder,elbow,upper,lower,toe) in zip(tips,forelegs):
        joint=elbow+Vector((0,0,.012*math.sin(t*5)))
        set_rod(upper,shoulder,joint);set_rod(lower,joint,tip);toe.location=tip
    startled=bool(frame.get('contact'))
    for side,wing in wings:
        wing.rotation_euler.y=side*(.12+(.34 if startled else .12)*math.sin(t*2*math.pi*3.7))
        wing.rotation_euler.z=side*.1
    source=root/'cameras'/f"{frame['index']:05}.png"
    screen_texture.image=bpy.data.images.load(str(source),check_existing=True)
    scene.render.filepath=str(output/f"{frame['index']:05}.png")
    bpy.context.view_layer.update();bpy.ops.render.render(write_still=True)
    timings.append(dict(index=frame['index'],modelTime=t,renderWallSeconds=time.monotonic()-started,action=frame['action']))
    print('Rendered fly pilot',frame['index'],flush=True)
    (output/'render-times.json').write_text(json.dumps(timings,indent=2)+'\n')
