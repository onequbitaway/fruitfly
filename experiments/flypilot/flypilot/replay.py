"""Recompute brain samples and physics. Compare exported rates with plotted rates."""
import gzip
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from .brain import Brain, sensory
from .experiment import Experiment

def check(folder, physics=True, tolerance=2e-5):
    folder=Path(folder)
    metadata=json.loads((folder/"metadata.json").read_text())
    with gzip.open(folder/"trace.jsonl.gz","rt") as f: frames=[json.loads(line) for line in f]
    if not frames: raise ValueError("The trace has no frames.")
    rate_checks=0
    rate_path=folder/"rates.f32.gz"
    if rate_path.exists():
        with gzip.open(rate_path,"rb") as stream:
            for frame in frames:
                raw=stream.read(metadata["cells"]*4)
                assert len(raw)==metadata["cells"]*4
                assert hashlib.sha256(raw).hexdigest()==frame["brain"]["rateHash"]
                rates=np.frombuffer(raw,dtype="<f4")
                assert np.count_nonzero(rates)==frame["brain"]["activeCells"]
                for point,hz in zip(metadata["plot"],frame["brain"]["plotRates"]): assert rates[point["index"]]==hz
                camera=folder/"camera"/f'{frame["index"]:05}.png'
                if camera.exists():
                    pixels=np.asarray(Image.open(camera).convert("RGB"))
                    assert hashlib.sha256(pixels.tobytes()).hexdigest()==frame["cameraHash"]
                if saved_hash:=frame.get("sensorHash"):
                    sensor=np.load(folder/"camera"/f'{frame["index"]:05}.npz')
                    assert hashlib.sha256(sensor["mask"].tobytes()+sensor["depth"].tobytes()).hexdigest()==saved_hash
                rate_checks+=1
            assert not stream.read(1),"Extra rate data."
    first=frames[0]
    max_position_error=0.
    max_action_error=0.
    brain_checks=0
    if physics:
        experiment=Experiment(first["mode"],first["controller"],first["seed"],checkpoint=folder/"checkpoint.json",scene=first.get("scene","studio"))
        try:
            for saved in frames:
                actual,_,_=experiment.step()
                assert actual["cameraHash"]==saved["cameraHash"],f'Rendered RGB changed at frame {saved["index"]}.'
                if "sensorHash" in saved:assert actual["sensorHash"]==saved["sensorHash"]
                assert actual["input"]==saved["input"],f'Camera adapter changed at frame {saved["index"]}.'
                assert actual["brain"]["rateHash"]==saved["brain"]["rateHash"],f'Rates changed at frame {saved["index"]}.'
                assert actual["brain"]["time"]==saved["brain"]["time"]
                action_error=float(np.max(np.abs(np.array(actual["action"])-saved["action"])))
                position_error=float(np.max(np.abs(np.array(actual["state"]["position"])-saved["state"]["position"])))
                max_position_error=max(max_position_error,position_error)
                max_action_error=max(max_action_error,action_error)
                assert position_error<=tolerance and action_error<=tolerance
                assert actual["state"]["events"]==saved["state"]["events"]
                brain_checks+=1
                if brain_checks%50==0: print(f"Replayed {brain_checks}/{len(frames)} frames.",flush=True)
        finally: experiment.close()
    else:
        with Brain(first["mode"],first["seed"]) as brain:
            for frame in frames:
                actual=brain.step(frame["input"])
                assert actual["rateHash"]==frame["brain"]["rateHash"]
                assert actual["features"]==frame["brain"]["features"]
                brain_checks+=1
    result=dict(frames=len(frames),exportedRateFrames=rate_checks,brainFrames=brain_checks,
        physics=physics,positionToleranceM=tolerance,maxPositionErrorM=max_position_error,maxActionError=max_action_error)
    (folder/"replay-check.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result),flush=True)
    return result
