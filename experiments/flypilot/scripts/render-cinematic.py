"""Run with Blender --background --python this_file -- SCENE_FOLDER OUTPUT.png."""
import json
import math
import sys
import time
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:]
root=Path(args[0]).resolve();output=Path(args[1]).resolve()
manifest=json.loads((root/'scene.json').read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=16
scene.render.use_persistent_data=True
scene.cycles.seed=2026
scene.cycles.use_denoising=True
scene.cycles.max_bounces=5
scene.cycles.diffuse_bounces=3
scene.cycles.transparent_max_bounces=4
try:
    settings=bpy.context.preferences.addons['cycles'].preferences
    settings.compute_device_type='METAL';settings.get_devices()
    for device in settings.devices:device.use=device.type=='METAL'
    scene.cycles.device='GPU'
except Exception as error:print('CPU renderer:',error,flush=True)
scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(output)
scene.view_settings.view_transform='AgX'
scene.view_settings.exposure=-.45
try:scene.view_settings.look='AgX - Medium High Contrast'
except TypeError:pass
scene.render.film_transparent=False
materials={}

def image_node(nodes,record,noncolor=False):
    node=nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(root/record['file']),check_existing=True)
    if noncolor:node.image.colorspace_settings.name='Non-Color'
    node.extension='REPEAT';return node

def material(data):
    key=json.dumps(data,sort_keys=True)
    if key in materials:return materials[key]
    mat=bpy.data.materials.new('Surface');mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;shader=nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value=.85
    for kind,socket in [('diffuse','Base Color'),('roughness','Roughness'),('metallic','Metallic')]:
        record=data.get(kind)
        if not record:continue
        if 'file' in record:
            tex=image_node(nodes,record,kind!='diffuse')
            if kind=='diffuse':
                mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
                factor=record.get('factor',[1,1,1]);mix.inputs[2].default_value=tuple(factor[:3])+ (1,) if len(factor)>1 else (factor[0],)*3+(1,)
                links.new(tex.outputs['Color'],mix.inputs[1]);links.new(mix.outputs[0],shader.inputs[socket])
            else:links.new(tex.outputs['Color'],shader.inputs[socket])
        else:
            value=record.get('color',[.5]);shader.inputs[socket].default_value=tuple(value[:3])+(1,) if kind=='diffuse' else value[0]
    if record:=data.get('normal'):
        if 'file' in record:
            tex=image_node(nodes,record,True);normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.8
            links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],shader.inputs['Normal'])
    # Add soot and rust detail to the burned vehicle surface.
    base=data.get('diffuse') or {}
    if 'color' in base and len(base['color'])>=3 and np.allclose(base['color'][:3],[48/255,43/255,35/255],atol=1e-6):
        shader.inputs['Base Color'].default_value=(.025,.022,.018,1)
        noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=32;noise.inputs['Detail'].default_value=4
        ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=(.012,.013,.012,1)
        ramp.color_ramp.elements[1].position=.83;ramp.color_ramp.elements[1].color=(.14,.064,.028,1)
        ash=ramp.color_ramp.elements.new(.56);ash.color=(.038,.033,.025,1)
        links.new(noise.outputs['Fac'],ramp.inputs['Fac']);links.new(ramp.outputs['Color'],shader.inputs['Base Color'])
        shader.inputs['Roughness'].default_value=.94;shader.inputs['Metallic'].default_value=.18
        bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.35;bump.inputs['Distance'].default_value=.012
        links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],shader.inputs['Normal'])
    materials[key]=mat;return mat

for part in manifest['parts']:
    data=np.load(root/(part['name']+'.npz'));vertices=data['vertices'];faces=data['faces']
    mesh=bpy.data.meshes.new(part['name']);mesh.from_pydata(vertices.tolist(),[],faces.tolist());mesh.update()
    obj=bpy.data.objects.new(part['name'],mesh);scene.collection.objects.link(obj)
    if 'uv' in data:
        uv=mesh.uv_layers.new(name='UVMap');coords=data['uv']
        values=coords[np.array([loop.vertex_index for loop in mesh.loops])].copy()
        # Genesis and Blender use the same UV origin for the exported visual mesh.
        uv.data.foreach_set('uv',values.ravel())
    obj.data.materials.append(material(part['material']))
    if part['role']!='static':
        for polygon in mesh.polygons:polygon.use_smooth=True

# A broad overcast sky and a low warm sun give surfaces depth without painted shadows.
world=bpy.data.worlds.new('Overcast battlefield');scene.world=world;world.use_nodes=True
nodes=world.node_tree.nodes;links=world.node_tree.links
sky=nodes.new('ShaderNodeTexSky');sky.sky_type='MULTIPLE_SCATTERING';sky.sun_elevation=math.radians(24);sky.sun_rotation=math.radians(130);sky.air_density=1.5;sky.aerosol_density=4
background=nodes.get('Background');background.inputs['Strength'].default_value=.18
links.new(sky.outputs['Color'],background.inputs['Color'])
bpy.ops.object.light_add(type='SUN',location=(-10,-12,20));sun=bpy.context.object;sun.data.energy=1.7;sun.data.angle=math.radians(5);sun.data.color=(1,.87,.72)
sun.rotation_euler=Vector((.5,.7,-1)).to_track_quat('-Z','Y').to_euler()
# Real volume shaders replace the fast viewport's approximate smoke effect.
for oi,origin in enumerate(manifest['smoke']):
    for i in range(5):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=Vector(origin)+Vector((i*.33,0,i*.85)))
        obj=bpy.context.object;obj.name=f'Smoke-{oi}-{i}';obj.scale=(.46+i*.19,.46+i*.19,.8+i*.1)
        mat=bpy.data.materials.new(obj.name);mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
        out=nodes.new('ShaderNodeOutputMaterial');volume=nodes.new('ShaderNodeVolumePrincipled');volume.inputs['Color'].default_value=(.18,.19,.18,1)
        noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=3;noise.inputs['Detail'].default_value=3
        mathnode=nodes.new('ShaderNodeMath');mathnode.operation='MULTIPLY';mathnode.inputs[1].default_value=3.0
        coords=nodes.new('ShaderNodeTexCoord');radial=nodes.new('ShaderNodeVectorMath');radial.operation='DISTANCE';radial.inputs[1].default_value=(.5,.5,.5);links.new(coords.outputs['Generated'],radial.inputs[0]);falloff=nodes.new('ShaderNodeMapRange');falloff.inputs['From Min'].default_value=0;falloff.inputs['From Max'].default_value=.5;falloff.inputs['To Min'].default_value=1;falloff.inputs['To Max'].default_value=0;falloff.clamp=True;links.new(radial.outputs['Value'],falloff.inputs['Value']);density=nodes.new('ShaderNodeMath');density.operation='MULTIPLY';links.new(falloff.outputs['Result'],density.inputs[0]);links.new(noise.outputs['Fac'],density.inputs[1]);links.new(density.outputs[0],mathnode.inputs[0]);links.new(mathnode.outputs[0],volume.inputs['Density']);links.new(volume.outputs['Volume'],out.inputs['Volume']);obj.data.materials.append(mat)
# A low-density volume establishes depth through the street.
bpy.ops.mesh.primitive_cube_add(size=1,location=(12,0,8));fog=bpy.context.object;fog.scale=(90,65,30)
mat=bpy.data.materials.new('Air');mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
out=nodes.new('ShaderNodeOutputMaterial');volume=nodes.new('ShaderNodeVolumePrincipled');volume.inputs['Density'].default_value=.0035;volume.inputs['Color'].default_value=(.58,.62,.65,1);volume.inputs['Anisotropy'].default_value=.25;links.new(volume.outputs['Volume'],out.inputs['Volume']);fog.data.materials.append(mat)
bpy.ops.object.camera_add(location=manifest['overviewEye']);camera=bpy.context.object
camera.rotation_euler=(Vector(manifest['overviewLook'])-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.sensor_fit='VERTICAL';camera.data.sensor_height=24;camera.data.lens=24/(2*math.tan(math.radians(manifest['overviewFov'])/2));camera.data.clip_end=250;scene.camera=camera
# The reusable map export contains scenery only. It excludes the Mixamo character.
bpy.ops.object.select_all(action='DESELECT')
for part in manifest['parts']:
    if part['role']=='static':bpy.data.objects[part['name']].select_set(True)
# glTF cannot carry the procedural soot shader. Export its dark base color.
procedural_links=[]
for mat in materials.values():
    shader=mat.node_tree.nodes.get('Principled BSDF')
    for link in list(shader.inputs['Base Color'].links):
        if link.from_node.type=='VALTORGB':
            procedural_links.append((mat,link.from_socket,link.to_socket))
            mat.node_tree.links.remove(link)
bpy.ops.export_scene.gltf(filepath=str(root/'battle-map.glb'),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
for mat,source,destination in procedural_links:mat.node_tree.links.new(source,destination)
if '--map-only' in args:
    print('Exported scenery only:',root/'battle-map.glb',flush=True)
    sys.exit(0)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'battlefield.blend'))
started=time.monotonic()
if output.suffix.lower()=='.png':
    bpy.ops.render.render(write_still=True)
    print('Rendered actual exported Genesis scene:',output,'seconds',time.monotonic()-started,flush=True)
else:
    output.mkdir(parents=True,exist_ok=True)
    frames=json.loads((root/'frames.json').read_text());records=[]
    dynamic=[part for part in manifest['parts'] if part['role']!='static']
    for frame in frames:
        arrays=np.load(root/'poses'/f"{frame['index']:05}.npz")
        for part in dynamic:
            vertices=arrays[str(part['entity'])][part['vertexStart']:part['vertexStart']+part['vertexCount']]
            mesh=bpy.data.objects[part['name']].data;mesh.vertices.foreach_set('co',vertices.ravel());mesh.update()
        progress=min(1,frame['time']/5);blend=progress*progress*(3-2*progress)
        eye=np.array(frame['overviewEye'])+(1-blend)*np.array([1.35,-4.,1.35])
        look=np.array(frame['overviewLook'])+(1-blend)*np.array([0,-2.35,.15])
        fov=55-11*blend
        camera.location=eye;camera.rotation_euler=(Vector(look)-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.lens=24/(2*math.tan(math.radians(fov)/2))
        scene.render.filepath=str(output/f"{frame['index']:05}.png")
        bpy.context.view_layer.update();bpy.ops.render.render(write_still=True)
        records.append(dict(index=frame['index'],modelTime=frame['time'],renderWallSeconds=time.monotonic()-started,eye=eye.tolist(),look=look.tolist(),fov=fov))
        print('Rendered verified frame',frame['index'],'elapsed',round(time.monotonic()-started,2),flush=True)
        (output/'render-times.json').write_text(json.dumps(records,indent=2)+'\n')
