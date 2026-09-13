"""Reproducible camera samples and measured-activity readout optimization."""
from __future__ import annotations
import hashlib
import json
import time
import numpy as np
from .brain import Brain, ROOT, sensory
from .perception import PortraitMatcher, teacher
from .policy import fit
from .world import World, ALTITUDE
from .room import SCENE_VERSION

def train(mode="full", samples=360, seed=2026, epochs=800, reference=None, scene="outdoor"):
    if samples < 40: raise ValueError("Use at least 40 training samples.")
    start=time.monotonic()
    output=ROOT/"runs"/("training-"+scene+"-"+mode)
    output.mkdir(parents=True,exist_ok=True)
    if scene=="outdoor":
        from .outdoor import OutdoorWorld,outdoor_sensory,outdoor_teacher
        world=OutdoorWorld();matcher=None;adapter=outdoor_sensory
    else:
        world=World(reference=reference);matcher=PortraitMatcher(reference=reference);adapter=sensory
    rng=np.random.default_rng(seed)
    features,labels,rows=[],[],[]
    try:
        with Brain(mode,seed) as brain:
            world.reset(seed,"train")
            for i in range(samples):
                if i%40==0: brain.reset(seed+i)
                # New camera pose and exposure. No ground-truth pose supplies a label.
                world.time=i*.1
                world.update_target()
                distance=float(rng.uniform(.65,8.5) if scene=="outdoor" else rng.uniform(1.1,3.7))
                lateral=float(rng.uniform(-1.5,1.5) if scene=="outdoor" else rng.uniform(-1.15,1.15))
                yaw=float(rng.uniform(-.35,.35))
                world.set_drone(world.target-np.array([distance,lateral,0]),yaw)
                world.exposure=float(rng.uniform(.96,1.15))
                rgb=world.camera_frame()
                observation=matcher.measure(rgb) if matcher else world.observation()
                inputs=adapter(observation,mode)
                sample=brain.step(inputs)
                # Fit the teacher before the common actuator limits. This avoids
                # bias near the set distance from fitting clipped commands.
                label=outdoor_teacher(observation) if scene=="outdoor" else (np.array([.65*(observation["distance"]-1.8),-1.1*observation["x"]]) if observation["found"] else np.zeros(2))
                # Lost samples exercise the model but the explicit hold gate handles loss.
                if observation["found"]:
                    features.append(sample["features"])
                    labels.append(label.tolist())
                rows.append(dict(index=i,seed=seed+(i//40)*40,observation=observation,input=inputs,
                    features=sample["features"],teacher=label.tolist(),rateHash=sample["rateHash"],
                    cameraHash=hashlib.sha256(rgb.tobytes()).hexdigest(),modelTime=sample["time"],cameraPose=world.state(),exposure=world.exposure))
                if i%40==0: print(f"Training camera samples: {i}/{samples}. Matches: {len(features)}.",flush=True)
            if len(features)<samples*.55:
                raise RuntimeError(f"Only {len(features)}/{samples} targets found. Fix perception before training.")
            checkpoint=fit(features,labels,brain.metadata["featureNames"],mode,seed,epochs)
            checkpoint.update(cameraSamples=samples,matchedSamples=len(features),wallSeconds=time.monotonic()-start,
                              portraitHash=hashlib.sha256((matcher.path if matcher else world.reference).read_bytes()).hexdigest(),
                              processor=brain.metadata["processor"],genesisVersion="1.4.0",sceneVersion=world.scene_version if scene=="outdoor" else SCENE_VERSION,scene=scene)
            if scene=="outdoor":
                checkpoint.update(outputMin=[-.35,-.65],outputMax=[1.9,.65],
                    teacher="Fictional scene camera: forward=min(1.9,0.65+0.24*depth_m); yaw=clip(-1.1*x,-0.65,0.65). Stop on game contact.",
                    perception="Rendered character ID mask and depth. Privileged game sensor. No real-world person detector.")
            # Custom photos and all derived weights stay local.
            destination=(ROOT/"private" if reference else ROOT/"weights")
            destination.mkdir(exist_ok=True)
            (destination/(mode+("-outdoor" if scene=="outdoor" else "")+".json")).write_text(json.dumps(checkpoint,indent=2)+"\n")
            (output/"samples.json").write_text(json.dumps(rows)+"\n")
            print(json.dumps({k:checkpoint[k] for k in ["mode","matchedSamples","wallSeconds","curve"]}),flush=True)
            return checkpoint
    finally: world.close()
