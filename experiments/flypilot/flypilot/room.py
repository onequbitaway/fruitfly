"""Authored studio geometry. All visible furnishings have conservative reset volumes."""
import os
import math
import numpy as np
import trimesh
from .brain import ROOT

SCENE_VERSION = "studio-1"
OVERVIEW_EYE = (-1.62, -2.18, 1.95)
OVERVIEW_LOOK = (2.2, .35, 1.10)
OVERVIEW_FOV = 62
# Axis-aligned safety envelopes include a 10 cm drone margin.
FURNITURE = [
    ("workbench", (4.48, .1, .88), (.61, 2.22, .98)),
    ("window plant", (3.35, 2.10, .92), (.43, .40, 1.02)),
    ("storage cabinet", (-.80, 2.15, .28), (1.03, .36, .38)),
]

def build_room(scene, gs):
    """Combine static meshes by material to keep the renderer small."""
    groups = {}
    colors = {
        "plaster": (.83,.82,.76), "trim": (.90,.89,.83),
        "charcoal": (.055,.065,.066), "metal": (.24,.27,.26),
        "cabinet": (.32,.38,.34), "wood": (.48,.32,.18),
        "ceramic": (.60,.34,.23), "soil": (.07,.055,.035),
        "leaf": (.10,.24,.10), "leaflight": (.20,.33,.12),
        "paper": (.78,.76,.65), "bookred": (.37,.15,.11),
        "screen": (.075,.12,.14), "sky": (.65,.75,.79),
        "building": (.45,.50,.50), "light": (.96,.91,.76),
    }
    def put(mesh, material): groups.setdefault(material, []).append(mesh)
    def box(pos,size,material,euler=None):
        m=trimesh.creation.box(extents=size)
        if euler: m.apply_transform(trimesh.transformations.euler_matrix(*np.radians(euler)))
        m.apply_translation(pos);put(m,material)
    def cylinder(pos,radius,height,material,euler=None):
        m=trimesh.creation.cylinder(radius=radius,height=height,sections=24)
        if euler: m.apply_transform(trimesh.transformations.euler_matrix(*np.radians(euler)))
        m.apply_translation(pos);put(m,material)
    # A complete room, viewed from inside. The broad north window is an actual opening.
    box((1.5,0,-.08),(7,5,.16),"wood")
    box((5.05,0,1.55),(.16,5.16,3.1),"plaster")
    box((-2.05,0,1.55),(.16,5.16,3.1),"plaster")
    box((1.5,-2.55,1.55),(7,.16,3.1),"plaster")
    box((1.5,2.55,.43),(7,.16,.86),"plaster")
    box((1.5,2.55,2.86),(7,.16,.48),"plaster")
    box((-1.6,2.55,1.75),(.8,.16,1.78),"plaster")
    box((4.32,2.55,1.75),(1.36,.16,1.78),"plaster")
    box((1.5,0,3.12),(7,5,.12),"plaster")
    for y in [-2.45,2.45]: box((1.5,y,.065),(7,.035,.13),"trim")
    for x in [-1.95,4.95]: box((x,0,.065),(.035,5,.13),"trim")
    # Deep window sill, mullions, and a partially raised venetian blind.
    box((1.22,2.39,.88),(4.88,.34,.065),"trim")
    for x in [-1.21,.39,1.99,3.65]: box((x,2.48,1.75),(.055,.12,1.8),"trim")
    for z in [.93,1.72,2.61]: box((1.22,2.48,z),(4.88,.12,.055),"trim")
    for i in range(5): box((1.22,2.40,2.52-i*.046),(4.84,.08,.016),"paper",(17,0,0))
    for x in [-.7,3.12]: cylinder((x,2.40,2.37),.003,.42,"charcoal")
    # The outdoor view is 3D geometry, not a photo or a composited background.
    box((1.5,9,-.24),(23,14,.2),"building")
    for x,w,h,y in [(-6,3,5,12),(-2,2.4,3.7,11),(1.8,3.3,5.1,13),(5.5,2.4,4.3,12),(8,2.2,6,14)]:
        box((x,y,h/2),(w,2,h),"building")
        for z in np.arange(.8,h-.2,.85):
            for xx in np.arange(x-w/2+.35,x+w/2-.2,.55): box((xx,y-1.01,z),(.32,.015,.49),"screen")
    # Oak worktop, shallow cabinets, gaps, pulls and a modest electronics station.
    box((4.52,.1,.81),(.73,4.12,.07),"wood")
    for y in [-1.47,-.42,.63,1.67]:
        box((4.62,y,.40),(.51,.99,.77),"cabinet")
        for z in [.22,.58]:
            box((4.347,y,z),(.025,.94,.325),"cabinet")
            box((4.323,y,z+.09),(.025,.26,.016),"metal")
    box((4.37,-.25,1.20),(.07,.95,.55),"charcoal")
    box((4.328,-.25,1.20),(.012,.88,.475),"screen")
    cylinder((4.40,-.25,.95),.027,.22,"metal")
    box((4.40,-.25,.866),(.26,.35,.025),"metal")
    box((4.12,-.22,.862),(.16,.57,.016),"charcoal")
    for y in np.arange(-.46,.04,.043): box((4.09,y,.873),(.025,.03,.005),"metal")
    box((4.22,.50,.87),(.22,.29,.025),"paper")
    cylinder((4.22,.93,.915),.057,.14,"ceramic")
    cylinder((4.22,.93,.988),.046,.004,"soil")
    for z in [1.67,2.21]:
        box((4.75,.25,z),(.39,3.6,.04),"wood")
        for y in [-1.1,1.6]: box((4.92,y,z-.12),(.06,.025,.24),"metal")
    rng=np.random.default_rng(38)
    for i in range(15):
        y=-1.28+i*.052;h=float(rng.uniform(.19,.31))
        box((4.72,y,1.70+h/2),(.19,.035,h),["paper","bookred","cabinet"][i%3])
    for y,z in [(.75,1.78),(-.75,2.32),(.2,2.32)]:
        box((4.76,y,z),(.25,.43,.18),"paper")
        box((4.623,y,z),(.008,.14,.037),"charcoal")
    # CC0 models with authored material maps. Genesis converts glTF to Z up on load.
    for name,pos,scale,euler in [
        ("potted_plant_01",(3.35,2.10,.02),1.,(0,0,0)),
        ("modern_wooden_cabinet",(-.80,2.15,.01),.75,(0,0,0)),
        ("desk_lamp_arm_01",(4.53,-1.2,.91),.70,(0,0,90)),
    ]:
        path=ROOT/"assets"/name/f"{name}_1k.gltf"
        scene.add_entity(gs.morphs.Mesh(file=str(path),pos=pos,scale=scale,euler=euler,
            fixed=True,collision=False,decimate=False,align=False),surface=gs.surfaces.Plastic())
    # Slim ceiling lights and electrical details.
    for x in [-.5,2.3]:
        box((x,.3,3.027),(.045,1.5,.045),"charcoal")
        box((x,.3,3.001),(.04,1.46,.007),"light")
    for y in [-1.05,1.28]:
        box((4.954,y,1.09),(.012,.075,.105),"trim")
        for z in [1.07,1.11]: box((4.944,y,z),(.006,.025,.007),"charcoal")
    asset_dir=ROOT/"runs/generated";asset_dir.mkdir(parents=True,exist_ok=True)
    for material,meshes in groups.items():
        path=asset_dir/f"{SCENE_VERSION}-{material}.obj"
        temporary=path.with_name(f"{path.stem}-{os.getpid()}.obj")
        trimesh.util.concatenate(meshes).export(temporary)
        temporary.replace(path)
        scene.add_entity(gs.morphs.Mesh(file=str(path),fixed=True,collision=False,decimate=False,align=False),
            surface=gs.surfaces.Plastic(color=colors[material],roughness=.75 if material not in ["metal","screen"] else .28,double_sided=True))
    # Explicit UVs preserve the scale and direction of the natural oak boards.
    path=asset_dir/f"{SCENE_VERSION}-floor.obj"
    texture=(ROOT/"assets/oak-floor.png").resolve()
    path.with_suffix(".mtl").write_text(f"newmtl oak\nKd 1 1 1\nmap_Kd {texture}\n")
    path.write_text(f"mtllib {path.stem}.mtl\nusemtl oak\nv -2 -2.5 .005\nv 5 -2.5 .005\nv 5 2.5 .005\nv -2 2.5 .005\nvt 0 0\nvt 2.33 0\nvt 2.33 1.67\nvt 0 1.67\nf 1/1 2/2 3/3\nf 1/1 3/3 4/4\n")
    scene.add_entity(gs.morphs.Mesh(file=str(path),fixed=True,collision=False,decimate=False,align=False),surface=gs.surfaces.Plastic(diffuse_texture=gs.textures.ImageTexture(image_path=str(texture)),roughness=.65))
