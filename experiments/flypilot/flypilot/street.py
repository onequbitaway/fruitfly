"""A fictional ruined city. Original geometry with credited CC0 surface maps."""
import math
import os
import numpy as np
import trimesh
from PIL import Image
from .brain import ROOT

STREET_VERSION='battlefield-1'

def build_street(scene,gs):
    generated=ROOT/'runs/generated';generated.mkdir(parents=True,exist_ok=True)
    rng=np.random.default_rng(901);groups={}
    palette={'metal':(.14,.13,.115),'dark':(.08,.075,.065),'glass':(.13,.16,.16),
        'brick':(.27,.19,.13),'dust':(.36,.33,.27),'line':(.44,.41,.32)}
    def add(mesh,mat):groups.setdefault(mat,[]).append(mesh)
    def box(pos,size,mat,rotation=None):
        mesh=trimesh.creation.box(extents=size)
        if rotation is not None:mesh.apply_transform(trimesh.transformations.euler_matrix(*rotation))
        mesh.apply_translation(pos);add(mesh,mat)
    def rod(a,b,r=.015,mat='metal'):
        a,b=np.array(a),np.array(b);delta=b-a
        mesh=trimesh.creation.cylinder(radius=r,height=np.linalg.norm(delta),sections=6)
        mesh.apply_transform(trimesh.geometry.align_vectors([0,0,1],delta));mesh.apply_translation((a+b)/2);add(mesh,mat)
    def field(x0,x1,y0,y1,nx,ny,mat,height):
        vertices=[(x,y,height(x,y)) for x in np.linspace(x0,x1,nx) for y in np.linspace(y0,y1,ny)]
        faces=[]
        for i in range(nx-1):
            for j in range(ny-1):
                a=i*ny+j;faces.extend([(a,a+ny,a+1),(a+1,a+ny,a+ny+1)])
        add(trimesh.Trimesh(vertices=vertices,faces=faces,process=False),mat)
    # A cratered road, with an unobstructed pavement lane for the actual encounter.
    craters=[(3,-6.1,1.7),(18,-7.2,2.1),(31,-3.7,1.5)]
    def ground(x,y):
        z=-.035+.025*math.sin(x*1.7)*math.cos(y*2.1)
        for cx,cy,r in craters:
            d=math.hypot(x-cx,y-cy)/r
            z+=-.48*math.exp(-d*d*2)+.17*math.exp(-((d-1.05)/.23)**2)
        return z
    field(-25,52,-11,-1.7,230,60,'asphalt_02',ground)
    field(-30,62,-30,30,150,130,'concrete_debris',lambda x,y:-.16+max(0,abs(y)-12)*.10+max(0,x-38)*.065+.08*math.sin(x*.8)*math.cos(y))
    box((12,1.35,.06),(80,6.0,.12),'concrete_debris')
    for x in np.arange(-25,51,1.25):
        box((x,-1.70,.14),(1.22,.24,.28),'broken_wall')
        if int(x)%5!=0:box((x,-5.35,.014),(.7,.065,.012),'line')
    # Hollow buildings. Missing wall cells expose floors, broken windows and rebar.
    for b,(cx,width,height,front) in enumerate([(-8,11,8.5,4.65),(7,10,7.8,4.65),(21,11,10.4,4.9),(37,12,8.7,5.5),(-7,15,6.5,-13),(18,15,8.3,-13)]):
        side=1 if front>0 else -1;depth=6.;step=.33;cols=round(width/step)
        for row in range(math.ceil(height/step)):
            z=(row+.5)*step+.13
            for col in range(cols):
                x=cx-width/2+(col+.5)*step
                top=height-1.0+.8*math.sin(x*1.7+b)+.5*math.cos(x*3.3)
                if z>top:continue
                doorway=front>0 and abs(x-cx)<.75 and z<2.65
                window=any(abs(x-(cx+offset))<.68 for offset in [-3,-.0,3]) and any(abs(z-level)<.73 for level in [1.8,4.8,7.8])
                blast=((x-(cx+width*.30))/(2.0 if b==1 else 2.8))**2+((z-(height-1.7))/2.4)**2 < 1+.10*math.sin(x*9+z*5)
                if doorway or window or blast:continue
                box((x,front,z),(step,.40,step),'concrete_wall_005' if b%2 else 'brick_wall_001')
        # Side and rear walls leave rooms dark and give their openings depth.
        for sign in [-1,1]:
            for z in np.arange(.7,height-1.4,1.15):
                length=depth if z<3 else depth-rng.uniform(.3,2.0)
                box((cx+sign*width/2,front+side*length/2,z),(.38,length,1.14),'concrete_wall_005')
        box((cx,front+side*depth,(height-2)/2),(width,.35,height-2),'concrete_wall_005')
        for level in [.12,3.0,5.9]:
            if level>height-1:continue
            length=width if level<1 else width*(.60 if b==1 else .75)
            box((cx-width/2+length/2,front+side*depth/2,level),(length,depth,.18),'concrete_debris')
            for x in np.arange(cx-width/2,cx+width/2,1.3):
                rod((x,front-.24*side,level+.08),(x+.22,front-.8*side,level+.18),.013)
        # Some window frames and a few broken panes survive.
        for x in [cx-3,cx,cx+3]:
            for z in [1.8,4.8]:
                if z>height-2 or (abs(x-cx)<.1 and z<3):continue
                for dx in [-.75,.75]:box((x+dx,front-.25*side,z),(.055,.08,1.6),'metal')
                box((x,front-.25*side,z-.8),(1.55,.30,.09),'broken_wall')
                if rng.random()<.6:
                    verts=[(x-.68,front-.27*side,z-.71),(x-.68,front-.27*side,z+.67),(x+.2,front-.27*side,z+.67),(x-.22,front-.27*side,z+.08)]
                    add(trimesh.Trimesh(vertices=verts,faces=[[0,1,2],[0,2,3]],process=False),'glass')
        if front>0:
            # The character leaves the middle doorway at x=7.
            box((cx-.65,front+.53,1.38),(.08,1.25,2.5),'metal')
            for dx in [-.79,.79]:box((cx+dx,front-.02,1.42),(.16,.52,2.8),'broken_wall')
            box((cx,front-.02,2.79),(1.74,.52,.15),'broken_wall')
            box((cx,front+.9,.06),(1.6,2.1,.12),'dark')
        # Collapsed piles stay outside the flight lane and doorway.
        for _ in range(100):
            x=float(rng.uniform(cx-width*.6,cx+width*.6));y=front-side*float(rng.uniform(.3,1.45))
            if front>0 and (abs(x-cx)<1.1 or y<3.4):continue
            z=.13+float(rng.uniform(.03,.40));size=rng.uniform([.10,.10,.08],[.65,.55,.38])
            mesh=trimesh.creation.box(extents=size);mesh.vertices+=rng.uniform(-.055,.055,mesh.vertices.shape);mesh.apply_transform(trimesh.transformations.euler_matrix(*rng.uniform(-1,1,3)));mesh.apply_translation((x,y,z));add(mesh,'concrete_debris' if rng.random()<.85 else 'brick')
        for _ in range(8):
            x=cx+float(rng.uniform(-width/2,width/2));z=float(rng.uniform(height-2.6,height))
            rod((x,front,z),(x+.20,front-side*.35,z+.8),.014)
    for x,y,z,width,height in [(43,15,0,10,10),(53,5,0,12,12),(47,-13,0,14,8),(-20,15,0,13,10)]:
        box((x,y,height/2),(width,5,height),'concrete_wall_005')
        for xx in np.arange(x-width/2+1,x+width/2,2):
            for zz in np.arange(1.6,height,2.5):box((xx,y-2.54,zz),(.85,.03,1.2),'dark')
    # Road debris has real geometry and receives shadows.
    for _ in range(320):
        x=float(rng.uniform(-14,44));y=float(rng.uniform(-10,-2.1));z=ground(x,y)
        mesh=trimesh.creation.icosphere(subdivisions=0,radius=1)
        size=rng.uniform(.06,.32);mesh.apply_scale([size*1.4,size,size*.45]);mesh.apply_translation((x,y,z+size*.32));add(mesh,'concrete_debris')
    # Bent lamp posts and fallen structural beams.
    for x in [-7,25,42]:
        rod((x,-1.9,.1),(x+.15,-1.9,3.5),.065)
        rod((x+.15,-1.9,3.5),(x+.8,-2.4,3.8),.045)
        box((x+.9,-2.6,3.8),(.50,.65,.10),'dark',(.0,.18,.2))
    for x,y in [(4,-8),(26,-9),(36,-4)]:
        box((x,y,.24),(3.4,.18,.26),'metal',(.12,.08,.5))
    # Scanned concrete road barriers.
    barrier=ROOT/'assets/concrete_road_barrier/concrete_road_barrier.gltf'
    for x,y,yaw in [(-1,-3.1,13),(12,-8.8,-7),(23,-3.0,20)]:
        scene.add_entity(gs.morphs.Mesh(file=str(barrier),pos=(x,y,.02),euler=(0,0,yaw),fixed=True,collision=False,align=False,decimate=False),surface=gs.surfaces.Plastic())
    # The supplied car is deformed and stripped to resemble a burned vehicle.
    original=trimesh.load(ROOT/'assets/ToyCar/ToyCar.glb');car=trimesh.Scene()
    for node in original.graph.nodes_geometry:
        matrix,geometry=original.graph[node]
        if geometry in ['Fabric','Glass']:continue
        mesh=original.geometry[geometry].copy();mesh.apply_transform(matrix)
        vertices=mesh.vertices.copy();bounds=mesh.bounds;yn=(vertices[:,1]-bounds[0,1])/max(1e-9,np.ptp(bounds[:,1]))
        vertices[:,1]-=.08*np.ptp(bounds[:,1])*np.maximum(0,yn-.35)*(1+np.sin(vertices[:,2]*33))
        mesh.vertices=vertices
        mesh.visual=trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(baseColorFactor=[48,43,35,255],metallicFactor=.55,roughnessFactor=.85))
        car.add_geometry(mesh)
    bounds=car.bounds;factor=4.35/max(car.extents[0],car.extents[2]);transform=np.eye(4);transform[:3,3]=[-bounds[:,0].mean(),-bounds[0,1],-bounds[:,2].mean()];car.apply_transform(transform);car.apply_scale(factor)
    car_path=generated/'battle-car.glb';car.export(car_path)
    for pos,yaw in [((2,-5.6,.03),72),((17,-7.3,.03),101),((32,-4.4,.03),58)]:
        scene.add_entity(gs.morphs.Mesh(file=str(car_path),pos=pos,euler=(0,0,yaw),fixed=True,collision=False,align=False,decimate=False),surface=gs.surfaces.Plastic())
    # Group static geometry by material. World-space UVs keep brick and concrete scale consistent.
    for material,meshes in groups.items():
        merged=trimesh.util.concatenate(meshes)
        if material in palette:
            surface=gs.surfaces.Plastic(color=palette[material],roughness=.85)
        else:
            triangles=merged.triangles;normals=merged.face_normals;axes=np.argmax(abs(normals),axis=1)
            vertices=triangles.reshape(-1,3);uv=np.zeros((len(vertices),2))
            for axis,pair in [(0,[1,2]),(1,[0,2]),(2,[0,1])]:
                selected=np.repeat(axes==axis,3);uv[selected]=vertices[selected][:,pair]/(2 if material!='asphalt_02' else 4)
            merged=trimesh.Trimesh(vertices=vertices,faces=np.arange(len(vertices)).reshape(-1,3),process=False)
            merged.visual=trimesh.visual.TextureVisuals(uv=uv)
            folder=ROOT/'assets'/material
            surface=gs.surfaces.Plastic(diffuse_texture=gs.textures.ImageTexture(image_path=str(folder/'diff.jpg'),image_color=(.72,.69,.63)),normal_texture=gs.textures.ImageTexture(image_path=str(folder/'nor_gl.jpg'),encoding='linear'),roughness_texture=gs.textures.ImageTexture(image_path=str(folder/'rough.jpg'),encoding='linear'),double_sided=True)
        path=generated/f'battle-{material}.obj';temp=path.with_name(f'{path.stem}-{os.getpid()}.obj');merged.export(temp);temp.replace(path)
        scene.add_entity(gs.morphs.Mesh(file=str(path),fixed=True,collision=False,align=False,decimate=False),surface=surface)
    # Smoke uses depth-tested procedural volumes in the camera postprocess.
    return [(2,-5.6,.5),(17,-7.3,.5),(28,8,2)]
