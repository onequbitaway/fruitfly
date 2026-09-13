"""Genesis physics and two rendered cameras. World poses never enter the readout."""
from __future__ import annotations
import math
import time
import hashlib
import numpy as np
from PIL import Image
from scipy.spatial.transform import Rotation
from .brain import ROOT
from .room import build_room, FURNITURE, OVERVIEW_EYE, OVERVIEW_LOOK, OVERVIEW_FOV

DT = .01
MODEL_DT = .1
ALTITUDE = 1.2
HOVER_RPM = 14468.429183500699
LIMITS = np.array([[-1.8, -2.3, .25], [4.7, 2.3, 2.8]])
_initialized = False

def initialize(backend="cpu"):
    global _initialized
    import genesis as gs
    if not _initialized:
        gs.init(backend=gs.metal if backend == "metal" else gs.cpu, seed=2026,
                logging_level="warning", performance_mode=True)
        _initialized = True
    return gs

def array(tensor): return tensor.detach().cpu().numpy().astype(float)

def collision_reason(position, target, occluded=False):
    pos=np.asarray(position)
    if not np.isfinite(pos).all(): return "invalid physics state"
    if np.any(pos<LIMITS[0]) or np.any(pos>LIMITS[1]): return "room boundary"
    for name,center,half in FURNITURE:
        if np.all(np.abs(pos-np.asarray(center))<np.asarray(half)): return name
    delta=np.abs(pos-np.asarray(target))
    if np.all(delta<np.array([.12,.5,.5])): return "target panel"
    if occluded and np.all(np.abs(pos-(np.asarray(target)+[-.18,0,0]))<np.array([.12,.6,.6])):
        return "occlusion panel"
    if abs(delta[0])<.25 and abs(delta[1])<.43 and pos[2]<.86: return "target stand"
    return None

class FlightController:
    """Cascaded velocity/attitude feedback. Adapted from the credited upstream PID mixer."""
    def __init__(self, drone, size_scale=1):
        self.drone = drone
        self.size_scale=size_scale
        self.hover_rpm=math.sqrt(float(drone.get_mass().item())*9.81/(4*float(drone.KF)))
        self.reset()

    def reset(self):
        self.last_velocity_error = np.zeros(3)
        self.last_body_velocity = np.zeros(3)
        self.last_attitude_error = np.zeros(3)
        self.yaw_target = 0.
        self.first = True

    def update(self, action):
        pos, vel = array(self.drone.get_pos()), array(self.drone.get_vel())
        q = array(self.drone.get_quat())
        roll, pitch, yaw = Rotation.from_quat([q[1],q[2],q[3],q[0]]).as_euler("xyz")
        self.yaw_target += float(action[1])*DT
        self.yaw_target = math.atan2(math.sin(self.yaw_target), math.cos(self.yaw_target))
        cy, sy = math.cos(yaw), math.sin(yaw)
        body_vel = np.array([cy*vel[0]+sy*vel[1], -sy*vel[0]+cy*vel[1], vel[2]])
        velocity_error = np.array([float(action[0]), 0, 2*(ALTITUDE-pos[2])])-body_vel
        attitude_error = np.rad2deg(np.array([-roll, -pitch,
                                    math.atan2(math.sin(self.yaw_target-yaw), math.cos(self.yaw_target-yaw))]))
        if self.first:
            self.last_velocity_error = velocity_error.copy()
            self.last_body_velocity = body_vel.copy()
            self.last_attitude_error = attitude_error.copy()
            self.first = False
        # Derivative on measured velocity avoids kicks at each 100 ms command update.
        v = np.array([40,40,80])*velocity_error - 12*(body_vel-self.last_body_velocity)/DT
        att = np.array([10,10,2])*attitude_error + np.array([3,3,1.7])*(attitude_error-self.last_attitude_error)/DT
        self.last_velocity_error, self.last_attitude_error = velocity_error, attitude_error
        self.last_body_velocity = body_vel
        if self.size_scale != 1:
            ratio=self.hover_rpm/HOVER_RPM
            v*=np.array([ratio*self.size_scale,ratio*self.size_scale,ratio])
            att*=ratio*self.size_scale
        x,y,thrust = v
        roll,pitch,yaw = att
        # CF2X rotor positions in the pinned URDF: (+x,-y), (-x,-y),
        # (-x,+y), (+x,+y). Positive pitch accelerates along body +X.
        roll -= y
        pitch += x
        rpms = self.hover_rpm + np.array([thrust-roll-pitch-yaw,
                                    thrust-roll+pitch+yaw,
                                    thrust+roll+pitch-yaw,
                                    thrust+roll-pitch+yaw])
        reference=self.hover_rpm if self.size_scale!=1 else HOVER_RPM
        return np.clip(rpms, .9*reference, 1.5*reference)

class World:
    def __init__(self, backend="cpu", reference=None, render=True):
        start = time.monotonic()
        gs = initialize(backend)
        self.gs, self.render_enabled = gs, render
        self.scene = gs.Scene(sim_options=gs.options.SimOptions(dt=DT),
            rigid_options=gs.options.RigidOptions(enable_collision=False),
            vis_options=gs.options.VisOptions(ambient_light=(.64,.66,.68), show_world_frame=False,
                background_color=(.70,.79,.84),shadow=True,lights=[
                    {"type":"directional","dir":(-.45,-1,-.7),"color":(1,.94,.83),"intensity":2.6},
                    {"type":"directional","dir":(1,.15,-.6),"color":(.80,.89,1),"intensity":.7}]),
            show_viewer=False)
        def box(pos,size,color):
            return self.scene.add_entity(gs.morphs.Box(pos=pos,size=size,fixed=True,collision=False),
                                         surface=gs.surfaces.Plastic(color=color,roughness=.6))
        build_room(self.scene,gs)
        self.drone = self.scene.add_entity(gs.morphs.Drone(file="urdf/drones/cf2x.urdf",pos=(0,0,ALTITUDE)))
        self.reference = reference or ROOT / "assets/portrait.png"
        if render:
            # A simple OBJ preserves authored vertex/UV order across loaders.
            asset_dir=ROOT/"runs/generated"
            asset_dir.mkdir(parents=True,exist_ok=True)
            stem="panel-"+hashlib.sha256(self.reference.read_bytes()).hexdigest()[:16]
            panel_path=asset_dir/(stem+".obj")
            if not panel_path.exists():
                Image.open(self.reference).convert("RGB").save(asset_dir/(stem+".png"))
                (asset_dir/(stem+".mtl")).write_text("newmtl portrait\nKd 1 1 1\nmap_Kd "+stem+".png\n")
                panel_path.write_text("mtllib "+stem+".mtl\nusemtl portrait\n"
                    "v 0 0.4 -0.4\nv 0 -0.4 -0.4\nv 0 -0.4 0.4\nv 0 0.4 0.4\n"
                    "vt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\nf 1/1 2/2 3/3\nf 1/1 3/3 4/4\n")
            self.panel = self.scene.add_entity(gs.morphs.Mesh(file=str(panel_path),pos=(2.8,0,ALTITUDE),
                fixed=True,collision=False,decimate=False,align=False),surface=gs.surfaces.Rough(double_sided=True))
            self.target_parts = [
                (box((2.84,0,1.2),(.065,.85,.85),(.045,.05,.05)),np.array([.04,0,0])),
                (box((2.85,0,.43),(.045,.055,.74),(.17,.19,.19)),np.array([.05,0,-.77])),
                (box((2.85,0,.045),(.40,.65,.055),(.09,.11,.11)),np.array([.05,0,-1.155])),
            ]
            self.occluder = box((2.65,0,-3),(.03,1.0,1.0),(.53,.54,.49))
            self.camera = self.scene.add_camera(pos=(0,0,ALTITUDE),lookat=(2.8,0,ALTITUDE),
                up=(0,0,1),res=(480,360),fov=60,GUI=False)
            self.overview = self.scene.add_camera(pos=OVERVIEW_EYE,lookat=OVERVIEW_LOOK,
                up=(0,0,1),res=(960,600),fov=OVERVIEW_FOV,GUI=False)
        self.scene.build()
        self.controller = FlightController(self.drone)
        self.setup_seconds = time.monotonic()-start
        self.reset(101)

    def reset(self, seed, split="eval"):
        self.seed, self.split = seed, split
        self.rng = np.random.default_rng(seed)
        self.time, self.events, self.path = 0., [], []
        y = float(self.rng.uniform(-.55,.55))
        yaw = float(self.rng.uniform(-.18,.18))
        self.start = np.array([float(self.rng.uniform(-.3,.2)), y, ALTITUDE])
        self.set_drone(self.start,yaw)
        self.controller.reset()
        self.controller.yaw_target = yaw
        self.target = self.target_at(0)
        self.exposure = float(self.rng.uniform(.72,.94) if split=="eval" else self.rng.uniform(.96,1.15))
        self.update_target()

    def set_drone(self, pos, yaw=0.):
        self.drone.set_pos(np.array(pos,dtype=float),zero_velocity=True)
        self.drone.set_quat(np.array([math.cos(yaw/2),0,0,math.sin(yaw/2)]),zero_velocity=True)

    def target_at(self,t):
        phase = (self.seed % 11)*.15
        if self.split == "train":
            return np.array([2.9+.3*math.sin(.3*t+phase), .65*math.sin(.38*t+phase),ALTITUDE])
        return np.array([2.7+.45*math.sin(.24*t+phase), .72*math.sin(.31*t+phase)+.16*math.sin(.8*t),ALTITUDE])

    def update_target(self):
        self.target = self.target_at(self.time)
        self.occluded = (7 <= self.time < 8.2) if self.split == "eval" else (4 <= self.time < 4.7)
        if self.render_enabled:
            self.panel.set_pos(self.target)
            for entity,offset in self.target_parts: entity.set_pos(self.target+offset)
            self.occluder.set_pos(self.target+np.array([-.18,0,0]) if self.occluded else (2.6,0,-3))

    def camera_frame(self):
        pos = array(self.drone.get_pos())
        q = array(self.drone.get_quat())
        rotation = Rotation.from_quat([q[1],q[2],q[3],q[0]])
        # Rigid forward camera. Mount is just in front of the rotor body.
        forward, up = rotation.apply([1,0,0]), rotation.apply([0,0,1])
        eye = pos+forward*.08
        self.camera.set_pose(pos=eye,lookat=eye+forward,up=up)
        frame = self.camera.render(force_render=True)[0]
        return np.clip(frame.astype(float)*self.exposure,0,255).astype(np.uint8)

    def overview_frame(self): return self.overview.render()[0]

    def advance(self, action):
        rpms_trace = []
        for _ in range(10):
            rpm = self.controller.update(action)
            self.drone.set_propellers_rpm(rpm)
            self.scene.step()
            self.time = round(self.time+DT, 10)
            pos = array(self.drone.get_pos())
            reason = collision_reason(pos,self.target,self.occluded)
            if reason:
                self.events.append(dict(time=self.time, type=reason, position=pos.tolist() if np.isfinite(pos).all() else None))
                self.set_drone(self.start)
                self.controller.reset()
            rpms_trace.append(rpm.tolist())
            self.update_target()
        self.path.append(array(self.drone.get_pos()).tolist())
        return rpms_trace

    def state(self):
        return dict(time=self.time,position=array(self.drone.get_pos()).tolist(),
                    quaternion=array(self.drone.get_quat()).tolist(),velocity=array(self.drone.get_vel()).tolist(),
                    target=self.target.tolist(),occluded=self.occluded,events=list(self.events))

    def close(self): self.scene.destroy()
