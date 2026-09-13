"""Closed-loop runs, matched baselines, evidence, and exact-input replay."""
from __future__ import annotations
import base64
import gzip
import hashlib
import json
import time
from pathlib import Path
import numpy as np
from PIL import Image
from .brain import Brain, ROOT, sensory
from .perception import PortraitMatcher, teacher
from .policy import Readout, load
from .recording import Instruments
from .world import World
from .room import SCENE_VERSION

CONTROLLERS=("trained","untrained","conventional","zero","shuffled","disabled")

class Experiment:
    def __init__(self, mode="full", controller="trained", seed=101, reference=None, checkpoint=None,scene="outdoor"):
        if controller not in CONTROLLERS: raise ValueError("Unknown controller.")
        self.mode,self.controller,self.seed=mode,controller,seed
        self.scene_name=scene
        if scene=="outdoor":
            from .outdoor import OutdoorWorld,outdoor_sensory,outdoor_teacher
            self.world=OutdoorWorld();self.adapt=outdoor_sensory;self.teacher=outdoor_teacher
        else:
            self.world=World(reference=reference);self.adapt=sensory;self.teacher=teacher
        self.brain=None
        try:
            self.brain=Brain(mode,seed)
            self.matcher=PortraitMatcher(reference=reference) if scene=="studio" else None
            self.readout=Readout(checkpoint) if checkpoint else load(mode,scene)
            if self.readout.checkpoint["mode"] != mode: raise ValueError("The weights use a different brain mode.")
            if self.readout.checkpoint.get("sceneVersion") != (self.world.scene_version if scene=="outdoor" else SCENE_VERSION):
                raise ValueError("The weights use an older room. Train the output map again.")
            portrait_hash=hashlib.sha256((self.matcher.path if self.matcher else self.world.reference).read_bytes()).hexdigest()
            if portrait_hash != self.readout.checkpoint["portraitHash"]:
                raise ValueError("Train this portrait first. The saved weights use a different image.")
            self.instruments=Instruments(self.brain.metadata)
            self.reset(seed)
        except BaseException:
            self.close()
            raise

    def reset(self, seed=None):
        if seed is not None: self.seed=seed
        self.world.reset(self.seed)
        self.brain.reset(self.seed)
        self.rng=np.random.default_rng(self.seed)
        self.frames=[]
        self.started=time.monotonic()
        self.wall_total=0.
        self.smoothed=np.zeros(2)
        self.lost=False
        self.hold_pos=None

    def step(self, full_rates=False, overview=False):
        start=time.monotonic()
        camera=self.world.camera_frame()
        observation=self.matcher.measure(camera) if self.matcher else self.world.observation()
        inputs=self.adapt(observation,self.mode)
        sample=self.brain.step(inputs,full_rates)
        features=np.array(sample["features"])
        if self.controller=="conventional": desired=self.teacher(observation)
        elif self.controller=="disabled": desired=np.zeros(2)
        else:
            if self.controller=="zero": features[:]=0
            if self.controller=="shuffled":
                # Swap hemispheres; fixed permutation preserves rate scale.
                features[[0,1]]=features[[1,0]]
                features[[2,3]]=features[[3,2]]
            if self.controller=="untrained":
                checkpoint=dict(self.readout.checkpoint,weights=self.readout.checkpoint["initialWeights"])
                desired=Readout(checkpoint).predict(features)
            else: desired=self.readout.predict(features)
        # A common slew filter belongs to the programmed flight controller.
        # The only camera bypass in trained modes is the binary lost-target hold gate.
        if not observation["found"]:
            self.smoothed[:]=0
            status="Hold · target lost"
        else:
            self.smoothed=.6*self.smoothed+.4*desired
            status="Follow · "+self.controller
        if getattr(self.world,"contact",None):self.smoothed[:]=0
        action=self.smoothed.copy()
        rgb_world=self.world.overview_frame() if overview else None
        before=self.world.state()
        motors=self.world.advance(action)
        state=self.world.state()
        distance=float(np.linalg.norm(np.array(before["target"])-before["position"])-(1.8 if self.scene_name=="studio" else 0))
        center=float(abs(observation["x"]) if observation["found"] else 1.)
        self.wall_total+=time.monotonic()-start
        frame=dict(index=len(self.frames),seed=self.seed,mode=self.mode,controller=self.controller,scene=self.scene_name,sceneVersion=self.readout.checkpoint["sceneVersion"],
            observation=observation,input=inputs,brain=sample,action=action.tolist(),motors=motors,
            before=before,state=state,distanceError=abs(distance),centerError=center,
            tracking=bool(observation["found"] and center<.15 and (abs(distance)<.35 if self.scene_name=="studio" else True)),
            status=("Contact · run complete" if state.get("contact") else status),wallSeconds=self.wall_total,cameraHash=hashlib.sha256(camera.tobytes()).hexdigest())
        if self.scene_name=="outdoor":
            frame["sensorHash"]=hashlib.sha256(self.world.sensor_mask.tobytes()+self.world.sensor_depth.tobytes()).hexdigest()
        self.frames.append(frame)
        return frame,camera,rgb_world

    def metrics(self):
        frames=self.frames
        steady=[f for f in frames if f["before"]["time"]>=5]
        recovery=[]
        loss_episodes=[]
        loss_onset=None
        loss_planned=False
        lost_start=None
        for f in frames:
            t=f["before"]["time"]
            if not f["observation"]["found"] and loss_onset is None:
                loss_onset=t;loss_planned=f["before"]["occluded"]
            if f["observation"]["found"] and loss_onset is not None:
                loss_episodes.append(dict(start=loss_onset,duration=round(t-loss_onset,3),recovered=True,plannedOcclusion=loss_planned))
                loss_onset=None
            if f["before"]["occluded"]: lost_start=f["before"]["time"]+.1
            elif lost_start is not None and f["observation"]["found"]:
                recovery.append(round(f["before"]["time"]-lost_start,3));lost_start=None
        if loss_onset is not None:
            loss_episodes.append(dict(start=loss_onset,duration=round(self.world.time-loss_onset,3),recovered=False,plannedOcclusion=loss_planned))
        def mean(key, group=frames): return float(np.mean([f[key] for f in group])) if group else None
        return dict(mode=self.mode,controller=self.controller,seed=self.seed,frames=len(frames),
            modelSeconds=self.world.time,wallSeconds=self.wall_total,
            simulationSpeed=self.world.time/max(.001,self.wall_total),
            meanCenterError=mean("centerError"),meanDistanceErrorM=mean("distanceError"),
            trackingSuccess=mean("tracking"),steadyTrackingSuccess=mean("tracking",steady),
            steadyDistanceErrorM=mean("distanceError",steady),
            detectedFraction=float(np.mean([f["observation"]["found"] for f in frames])),
            lostTargetRecoverySeconds=recovery,unrecovered=loss_onset is not None or lost_start is not None,
            lossEpisodes=loss_episodes,
            boundaryEvents=sum(e["type"]!="character contact" for e in self.world.events),events=self.world.events,
            scene=self.scene_name,contact=bool(getattr(self.world,"contact",None)),
            contactTime=getattr(self.world,"contact",None)["time"] if getattr(self.world,"contact",None) else None)

    def close(self):
        if self.brain: self.brain.close()
        self.world.close()

def save_evidence(folder, experiment, frames, metrics):
    folder.mkdir(parents=True,exist_ok=True)
    (folder/"metadata.json").write_text(json.dumps(experiment.brain.metadata)+"\n")
    (folder/"checkpoint.json").write_text(json.dumps(experiment.readout.checkpoint,indent=2)+"\n")
    with gzip.open(folder/"trace.jsonl.gz","wt") as out:
        for frame in frames: out.write(json.dumps(frame,separators=(",",":"))+"\n")
    (folder/"metrics.json").write_text(json.dumps(metrics,indent=2)+"\n")

def run_episode(experiment,seconds=20,output=None,record=False):
    if seconds<=0 or seconds>600: raise ValueError("Use a duration from 0 to 600 seconds.")
    started=time.monotonic()
    writer=None
    rates=None
    folder=Path(output) if output else None
    if record:
        import imageio.v2 as imageio
        folder.mkdir(parents=True,exist_ok=True)
        (folder/"camera").mkdir(exist_ok=True)
        writer=imageio.get_writer(str(folder/"flypilot-full-map.mp4"),fps=10,codec="libx264",
            macro_block_size=8,quality=8,ffmpeg_log_level="error")
        rates=gzip.open(folder/"rates.f32.gz","wb")
    try:
        for i in range(round(seconds*10)):
            frame,camera,overview=experiment.step(full_rates=record,overview=record)
            if record:
                rates.write(base64.b64decode(frame["brain"].pop("ratesF32LE")))
                Image.fromarray(camera).save(folder/"camera"/f"{i:05}.png")
                frame["wallSeconds"]=time.monotonic()-started
                composed=experiment.instruments.compose(overview,camera,frame,experiment.world.path)
                writer.append_data(composed)
                if i==0: Image.fromarray(composed).save(folder/"opening.png")
                if i==min(50,round(seconds*10)-1): Image.fromarray(composed).save(folder/"preview.png")
                if experiment.scene_name=="outdoor":
                    np.savez_compressed(folder/"camera"/f"{i:05}.npz",mask=experiment.world.sensor_mask,depth=experiment.world.sensor_depth)
                    if frame["state"].get("contact"):
                        if frame["before"].get("contact") and not (folder/"contact.png").exists():
                            Image.fromarray(composed).save(folder/"contact.png")
                        if experiment.world.time>=experiment.world.contact["time"]+2:break
            if i%50==0: print(f'{experiment.controller} seed {experiment.seed}: {i/10:.1f}/{seconds:.1f} s',flush=True)
    finally:
        if writer: writer.close()
        if rates: rates.close()
    metrics=experiment.metrics()
    metrics["calculationSeconds"]=metrics["wallSeconds"]
    metrics["wallSeconds"]=time.monotonic()-started
    metrics["simulationSpeed"]=metrics["modelSeconds"]/metrics["wallSeconds"]
    if folder: save_evidence(folder,experiment,experiment.frames,metrics)
    print(json.dumps(metrics),flush=True)
    return metrics

def evaluate(mode="full",seconds=20,seeds=(503,607,709),controllers=CONTROLLERS,output=None,scene="outdoor"):
    output=Path(output) if output else ROOT/"runs"/("evaluation-"+scene+"-"+mode)
    output.mkdir(parents=True,exist_ok=True)
    results=[]
    experiment=Experiment(mode,scene=scene)
    try:
        for controller in controllers:
            experiment.controller=controller
            for seed in seeds:
                experiment.reset(seed)
                result=run_episode(experiment,seconds,output/f"{controller}-{seed}")
                results.append(result)
    finally: experiment.close()
    report=dict(mode=mode,scene=scene,seeds=list(seeds),seconds=seconds,results=results,summary={})
    for controller in controllers:
        selected=[r for r in results if r["controller"]==controller]
        report["summary"][controller]={k:float(np.mean([r[k] for r in selected])) for k in
            ["meanCenterError","meanDistanceErrorM","trackingSuccess","steadyTrackingSuccess",
             "boundaryEvents","simulationSpeed","detectedFraction","contact"]}
    (output/"results.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report["summary"],indent=2),flush=True)
    return report
