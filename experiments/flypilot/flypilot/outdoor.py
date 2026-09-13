"""A fictional street encounter. Control receives rendered game-camera sensors only."""
import hashlib
import math
import time
import xml.etree.ElementTree as ET
import numpy as np
import trimesh
from PIL import Image
from scipy.spatial.transform import Rotation
from .brain import ROOT
from .world import initialize,array,FlightController,DT,ALTITUDE
from .street import build_street,STREET_VERSION
from .character import WalkingCharacter

DRONE_SCALE=5

def scaled_drone_asset(gs):
    source=__import__('pathlib').Path(gs.__file__).parent/'assets/urdf/drones/cf2x.urdf'
    tree=ET.parse(source);root=tree.getroot();properties=root.find('properties')
    # Geometric similarity only. This is a game model, not calibrated flight hardware.
    properties.set('kf',str(float(properties.get('kf'))*DRONE_SCALE**4))
    properties.set('km',str(float(properties.get('km'))*DRONE_SCALE**5))
    for mesh in root.findall('.//mesh'):
        mesh.set('filename',str((source.parent/mesh.get('filename')).resolve()))
    destination=ROOT/'runs/generated/street-drone.urdf';destination.parent.mkdir(parents=True,exist_ok=True)
    tree.write(destination,encoding='utf-8',xml_declaration=True)
    return destination

def contact_vertex(position,quaternion,vertices):
    """Return the first closest body vertex inside the visible-drone envelope, or None."""
    q=np.asarray(quaternion);rot=Rotation.from_quat([q[1],q[2],q[3],q[0]])
    delta=rot.inv().apply(np.asarray(vertices)-np.asarray(position))
    distances=np.linalg.norm(delta/np.array([.265,.275,.11]),axis=1)
    closest=int(np.argmin(distances))
    return closest if distances[closest]<=1 else None

class OutdoorWorld:
    scene_version=STREET_VERSION
    def __init__(self,backend='cpu',reference=None,render=True):
        start=time.monotonic();gs=initialize(backend);self.gs=gs;self.render_enabled=render
        self.scene=gs.Scene(sim_options=gs.options.SimOptions(dt=DT),rigid_options=gs.options.RigidOptions(enable_collision=False),
            vis_options=gs.options.VisOptions(ambient_light=(.16,.18,.20),background_color=(.53,.55,.54),shadow=True,
                segmentation_level='entity',lights=[{'type':'directional','dir':(-.5,.65,-.65),'color':(1,.91,.77),'intensity':3.0}]),show_viewer=False)
        self.smoke=build_street(self.scene,gs)
        self.character=WalkingCharacter();self.reference=self.character.path
        self.person=self.scene.add_entity(gs.morphs.Mesh(file=str(self.character.asset),fixed=True,collision=False,
            align=False,decimate=False,enable_custom_vverts=True),surface=gs.surfaces.Plastic(roughness=.85,double_sided=True))
        self.drone=self.scene.add_entity(gs.morphs.Drone(file=str(scaled_drone_asset(gs)),scale=DRONE_SCALE,pos=(0,1,ALTITUDE)))
        # A plain camera shell covers the oversized laboratory circuit board.
        shell=trimesh.creation.icosphere(subdivisions=2,radius=1);shell.apply_scale([.145,.090,.052])
        shell.apply_translation((0,0,.044));path=ROOT/'runs/generated/street-drone-shell.obj';shell.export(path)
        self.shell=self.scene.add_entity(gs.morphs.Mesh(file=str(path),fixed=True,collision=False,align=False,decimate=False),surface=gs.surfaces.Plastic(color=(.84,.86,.84),roughness=.32))
        self.lens=self.scene.add_entity(gs.morphs.Cylinder(radius=.025,height=.035,euler=(0,90,0),fixed=True,collision=False),surface=gs.surfaces.Plastic(color=(.025,.035,.045),roughness=.15))
        self.camera=self.scene.add_camera(pos=(.35,1,ALTITUDE),lookat=(8,1,ALTITUDE),res=(640,480),fov=65,GUI=False)
        self.overview=self.scene.add_camera(pos=(-3,-7,3),lookat=(4,1,1),res=(1280,800),fov=55,GUI=False)
        self.scene.build();self.character.bind(self.person)
        self.person_sensor_id=next(key for key,value in self.scene.visualizer.segmentation_idx_dict.items() if value==self.person.idx)
        self.controller=FlightController(self.drone,size_scale=DRONE_SCALE)
        self.setup_seconds=time.monotonic()-start
        self.reset(101)

    def reset(self,seed,split='eval'):
        self.seed,self.split=seed,split;self.rng=np.random.default_rng(seed)
        self.time=0.;self.events=[];self.path=[];self.contact=None;self.occluded=False
        self.walk_speed=.58 if split=='eval' else .42
        self.start=np.array([float(self.rng.uniform(-.3,.2)),float(self.rng.uniform(.35,1.65)),ALTITUDE])
        yaw=float(self.rng.uniform(-.12,.12));self.set_drone(self.start,yaw);self.controller.reset();self.controller.yaw_target=yaw
        self.exposure=float(self.rng.uniform(.82,1.02) if split=='eval' else self.rng.uniform(1.0,1.15))
        self.update_target();self.update_visuals()

    def set_drone(self,pos,yaw=0):
        self.drone.set_pos(np.array(pos,dtype=float),zero_velocity=True)
        self.drone.set_quat(np.array([math.cos(yaw/2),0,0,math.sin(yaw/2)]),zero_velocity=True)

    def target_at(self,t):
        phase=(self.seed%11)*.15
        if self.split=='train':return np.array([6+.42*t,1+.24*math.sin(.4*t+phase),ALTITUDE])
        # Walk from the open doorway, round the corner, then follow the pavement.
        speed=.58;turn_start=3.2;turn_time=1.6;radius=speed*turn_time/(math.pi/2)
        if t<turn_start:return np.array([7,4.34-speed*t,ALTITUDE])
        angle=min(math.pi/2,(t-turn_start)/turn_time*math.pi/2)
        x=7+radius*(1-math.cos(angle));y=4.34-speed*turn_start-radius*math.sin(angle)
        if t>turn_start+turn_time:
            dt=t-turn_start-turn_time;x+=speed*dt;y+=.10*math.sin(.55*dt+phase)-.10*math.sin(phase)
        return np.array([x,y,ALTITUDE])

    def update_target(self):
        t=self.contact['time'] if self.contact else self.time
        self.target=self.target_at(t)
        # The provided gait is retimed to a walk. Animation is explicitly programmed.
        reaction=min(1,max(0,(self.time-self.contact['time'])/.40)) if self.contact else 0
        heading=0. if self.split=='train' else -math.pi/2+min(math.pi/2,max(0,(t-3.2)/1.6)*math.pi/2)
        self.character_vertices=self.character.update(t*.65,np.array([self.target[0],self.target[1],.13]),heading=heading,reaction=reaction)

    def update_visuals(self):
        pos=array(self.drone.get_pos());q=array(self.drone.get_quat());rotation=Rotation.from_quat([q[1],q[2],q[3],q[0]])
        self.shell.set_pos(pos);self.shell.set_quat(q)
        self.lens.set_pos(pos+rotation.apply([.15,0,-.005]));lq=(rotation*Rotation.from_euler('y',90,degrees=True)).as_quat();self.lens.set_quat(np.r_[lq[3],lq[:3]])

    def camera_frame(self):
        self.update_visuals()
        pos=array(self.drone.get_pos());q=array(self.drone.get_quat());rotation=Rotation.from_quat([q[1],q[2],q[3],q[0]])
        forward,up=rotation.apply([1,0,0]),rotation.apply([0,0,1]);eye=pos+forward*.31
        self.camera.set_pose(pos=eye,lookat=eye+forward,up=up)
        rgb,depth,seg,_=self.camera.render(depth=True,segmentation=True,force_render=True)
        self.sensor_depth=depth;self.sensor_mask=seg==self.person_sensor_id
        return self.atmosphere(rgb,depth,eye,eye+forward,65,self.exposure)

    def observation(self):
        # This ID mask is a game-engine sensor, not a real-world person detector.
        yy,xx=np.nonzero(self.sensor_mask)
        empty=dict(found=False,x=0.,distance=0.,confidence=0.,box=None,sensor='rendered character mask + depth')
        if len(xx)<12:return empty
        depth=self.sensor_depth[self.sensor_mask];depth=depth[np.isfinite(depth)&(depth>0)]
        if not len(depth):return empty
        x0,x1,y0,y1=map(int,[xx.min(),xx.max(),yy.min(),yy.max()])
        return dict(found=True,x=float((xx.mean()-320)/320),distance=float(np.median(depth)),confidence=1.,
            box=[[x0,y0],[x1,y0],[x1,y1],[x0,y1]],pixels=len(xx),sensor='rendered character mask + depth')

    def overview_frame(self):
        self.update_visuals();pos=array(self.drone.get_pos());middle=(pos+self.target)/2
        separation=np.linalg.norm(pos[:2]-self.target[:2])
        back=4.2+min(4.0,separation*.65)
        self.overview_eye=np.array([middle[0]-4.2,middle[1]-back,2.65])
        self.overview_look=np.array([middle[0]+.8,middle[1],1.05])
        self.overview.set_pose(pos=self.overview_eye,lookat=self.overview_look,up=(0,0,1))
        rgb,depth,_,_=self.overview.render(depth=True,force_render=True)
        return self.atmosphere(rgb,depth,self.overview_eye,self.overview_look,55)

    def atmosphere(self,rgb,depth,eye,look,fov,exposure=1.):
        # All effects use the real camera pose and depth. Smoke is programmed scenery.
        h,w=depth.shape;small_w,small_h=w//2,h//2
        d=np.asarray(Image.fromarray(depth).resize((small_w,small_h)),dtype=np.float32)
        forward=np.asarray(look)-eye;forward/=np.linalg.norm(forward)
        right=np.cross(forward,[0,0,1]);right/=np.linalg.norm(right);up=np.cross(right,forward)
        yy,xx=np.mgrid[0:small_h,0:small_w];focal=small_h/(2*np.tan(np.deg2rad(fov/2)))
        rays=forward+right*((xx-small_w/2)/focal)[:,:,None]-up*((yy-small_h/2)/focal)[:,:,None]
        lengths=np.linalg.norm(rays,axis=2);rays/=lengths[:,:,None]
        limit=np.where(np.isfinite(d)&(d>0),d*lengths,1000)
        alpha=np.zeros_like(d)
        for origin in self.smoke:
            for i in range(6):
                radius=.40+i*.21;center=np.array(origin)+[i*.32+.12*math.sin(self.time*.4+i),0,i*.82]
                offset=center-eye;t=rays@offset
                perpendicular=np.maximum(0,np.dot(offset,offset)-t*t)
                visibility=np.clip((limit-(t-radius*2))/(radius*4),0,1)*(t>0)
                noise=.77+.14*np.sin(xx*.23+yy*.12+i*2+self.time*.4)*np.sin(yy*.20-xx*.13+i)
                alpha+=np.exp(-perpendicular/(2*radius**2))*.50*visibility*noise
        alpha=1-np.exp(-alpha)
        alpha=np.asarray(Image.fromarray(alpha).resize((w,h),Image.Resampling.BILINEAR))[:,:,None]
        distance=np.where(np.isfinite(depth)&(depth>0),depth,1000)
        fog=(1-np.exp(-np.maximum(0,distance-4)*.015))[:,:,None]
        color=np.asarray(rgb,dtype=float)/255*exposure
        grey=color@np.array([.2126,.7152,.0722]);color=.91*color+.09*grey[:,:,None]
        color=color*(1-fog)+np.array([.52,.54,.53])*fog
        # A restrained cloud gradient fills only empty sky pixels.
        sky=.50+.09*np.clip(-rays[:,:,2],-.7,.7)+.027*np.sin(rays[:,:,0]*8+rays[:,:,2]*7)*np.cos(rays[:,:,1]*9)
        sky=np.asarray(Image.fromarray(sky.astype(np.float32)).resize((w,h)))
        empty=~np.isfinite(depth)|(depth<=0)|(depth>200)
        color[empty]=sky[empty,None]*np.array([1.,1.025,1.02])
        color=color*(1-alpha)+np.array([.15,.16,.155])*alpha
        return np.clip(color*255,0,255).astype(np.uint8)

    def advance(self,action):
        motors=[]
        for _ in range(10):
            command=np.zeros(2) if self.contact else action
            rpm=self.controller.update(command);self.drone.set_propellers_rpm(rpm);self.scene.step();motors.append(rpm.tolist())
            self.time=round(self.time+DT,10);self.update_target();pos=array(self.drone.get_pos())
            if not self.contact:
                # Conservative ellipsoid around the visible drone. Check it against animated body vertices.
                closest=contact_vertex(pos,array(self.drone.get_quat()),self.character_vertices)
                if closest is not None:
                    self.contact=dict(time=self.time,type='character contact',position=pos.tolist(),
                        characterPoint=self.character_vertices[closest].tolist(),velocity=array(self.drone.get_vel()).tolist())
                    self.events.append(self.contact)
                    # A mild programmed collision response. It is not a biological injury model.
                    normal=pos-self.character_vertices[closest];normal[2]=0;normal/=max(1e-5,np.linalg.norm(normal))
                    self.drone.set_dofs_velocity(normal*.6,dofs_idx_local=[0,1,2]);self.controller.reset()
                elif not np.isfinite(pos).all() or pos[0]<-3 or pos[0]>35 or pos[1]<-1.2 or pos[1]>3.7 or pos[2]<.35 or pos[2]>3.3:
                    self.events.append(dict(time=self.time,type='street boundary',position=pos.tolist()))
                    self.set_drone(self.start);self.controller.reset()
            self.update_visuals()
        self.path.append(array(self.drone.get_pos()).tolist());return motors

    def state(self):
        result=dict(time=self.time,position=array(self.drone.get_pos()).tolist(),quaternion=array(self.drone.get_quat()).tolist(),velocity=array(self.drone.get_vel()).tolist(),
            target=self.target.tolist(),occluded=False,events=list(self.events),contact=self.contact,sceneVersion=STREET_VERSION,
            animationTime=(self.contact['time'] if self.contact else self.time)*.65)
        if hasattr(self,'overview_eye'):result.update(overviewEye=self.overview_eye.tolist(),overviewLook=self.overview_look.tolist(),overviewFov=55)
        return result

    def close(self):self.scene.destroy()

def outdoor_sensory(observation,mode):
    if not observation['found']:left=right=0.
    else:
        base=70+12*np.clip(observation['distance'],0,10)
        left=float(np.clip(base-45*observation['x'],0,200));right=float(np.clip(base+45*observation['x'],0,200))
    return dict(visualLeft=left if mode=='full' else 0,visualRight=right if mode=='full' else 0,
        odorLeft=left if mode=='simple' else 0,odorRight=right if mode=='simple' else 0,taste=0,feeding=0)

def outdoor_teacher(observation):
    if not observation['found']:return np.zeros(2)
    return np.array([min(1.9,.65+.24*observation['distance']),np.clip(-1.1*observation['x'],-.65,.65)])
