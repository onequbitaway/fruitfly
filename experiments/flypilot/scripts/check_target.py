"""Milestone check: rendered color target -> Full map -> speed and turn."""
import hashlib
import json
import sys
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from flypilot.brain import Brain,sensory
from flypilot.world import World

folder=ROOT/"runs/simple-target"
folder.mkdir(parents=True,exist_ok=True)
portrait=folder/"green.png"
Image.new("RGB",(64,64),(0,230,40)).save(portrait)
world=World(reference=portrait)
rows=[]
try:
    with Brain("full",17) as brain:
        for enabled in [False,True]:
            world.reset(17,"train");brain.reset(17)
            centers=[];distances=[];actions=[];hashes=[]
            for i in range(120):
                rgb=world.camera_frame()
                mask=((rgb[:,:,1]>rgb[:,:,0]*1.4)&(rgb[:,:,1]>rgb[:,:,2]*1.4)&(rgb[:,:,1]>90)).astype(np.uint8)
                y,x=np.nonzero(mask)
                found=len(x)>100
                observation=dict(found=found,x=float((x.mean()-240)/240) if found else 0,
                    distance=float((360/(2*np.tan(np.pi/6)))*.8/(x.max()-x.min()+1)) if found else 0)
                sample=brain.step(sensory(observation,"full"))
                left,right=sample["features"][:2]
                # An explicitly programmed smoke-test readout, before optimization.
                action=np.array([np.clip(.65*((left+right)/2-100)/20,-.35,.65),np.clip(-1.1*(right-left)/90,-.65,.65)])
                if not enabled or not found: action[:]=0
                world.advance(action)
                centers.append(abs(observation["x"]) if found else 1.)
                distances.append(abs(np.linalg.norm(np.array(world.state()["position"])-world.target)-1.8))
                actions.append(action.tolist());hashes.append(sample["rateHash"])
            rows.append(dict(brainLinkEnabled=enabled,frames=120,meanCenterError=float(np.mean(centers)),
                meanDistanceErrorM=float(np.mean(distances)),boundaryEvents=len(world.events),
                actions=actions,rateHashes=hashes,finalState=world.state()))
finally: world.close()
(ROOT/"provenance/simple-target.json").write_text(json.dumps(rows,indent=2)+"\n")
print(json.dumps([{k:v for k,v in r.items() if k not in ['actions','rateHashes']} for r in rows]),flush=True)
assert rows[1]["meanDistanceErrorM"]<rows[0]["meanDistanceErrorM"]
assert rows[1]["boundaryEvents"]==0
