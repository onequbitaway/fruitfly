"""Run the pinned upstream examples and probe the drone contact limit."""
import argparse
import json
import os
import runpy
import sys
import time
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
sys.path.insert(0,str(ROOT/"vendor"))
parser = argparse.ArgumentParser()
parser.add_argument("kind",choices=["upstream-hover","upstream-route","probe"])
parser.add_argument("--backend", choices=["cpu","metal"],default="cpu")
parser.add_argument("--no-contacts", action="store_true")
args = parser.parse_args()
os.chdir(ROOT)
(ROOT/"runs/out").mkdir(parents=True,exist_ok=True)
start=time.monotonic()
if args.kind != "probe":
    os.chdir(ROOT/"runs")
    sys.argv=[args.kind]
    runpy.run_path(str(ROOT/"vendor"/("fly.py" if args.kind=="upstream-hover" else "fly_route.py")),run_name="__main__")
    print(json.dumps(dict(kind=args.kind,wallSeconds=time.monotonic()-start)))
else:
    from flypilot.world import initialize,array,HOVER_RPM
    gs=initialize(args.backend)
    scene=gs.Scene(sim_options=gs.options.SimOptions(dt=.01),
                   rigid_options=gs.options.RigidOptions(enable_collision=not args.no_contacts),show_viewer=False)
    scene.add_entity(gs.morphs.Plane())
    scene.add_entity(gs.morphs.Box(pos=(0,0,.7),size=(1,1,.1),fixed=True))
    drone=scene.add_entity(gs.morphs.Drone(file="urdf/drones/cf2x.urdf",pos=(0,0,1.2)))
    control=scene.add_entity(gs.morphs.Drone(file="urdf/drones/cf2x.urdf",pos=(2,0,1.2)))
    scene.build()
    built=time.monotonic()
    for _ in range(100):
        drone.set_propellers_rpm([HOVER_RPM]*4)
        control.set_propellers_rpm([HOVER_RPM]*4)
        scene.step()
    hover=array(drone.get_pos())
    before=time.monotonic()
    for _ in range(80):
        drone.set_propellers_rpm([0]*4)
        control.set_propellers_rpm([0]*4)
        scene.step()
    end=array(drone.get_pos())
    result=dict(backend=args.backend,contactsEnabled=not args.no_contacts,buildSeconds=built-start,hoverPosition=hover.tolist(),
                hoverErrorM=float(np.linalg.norm(hover-[0,0,1.2])),
                dropPosition=end.tolist(),freeFallControl=array(control.get_pos()).tolist(),passedThroughSolidSlab=bool(end[2]<.6),
                stepHz=80/(time.monotonic()-before),wallSeconds=time.monotonic()-start)
    suffix="-no-contacts" if args.no_contacts else "-contacts"
    (ROOT/"provenance"/("simulator-"+args.backend+suffix+".json")).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result))
    assert result["hoverErrorM"]<.03
    assert result["freeFallControl"][2]<.6
    if args.no_contacts: assert result["passedThroughSolidSlab"]
    # With contacts enabled, report the observed result. Do not assert the docs' claim.
