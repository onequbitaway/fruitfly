"""Check source and asset provenance without importing the simulator."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT/"assets/SOURCE.json").read_text())
assert hashlib.sha256((ROOT/"assets/portrait.png").read_bytes()).hexdigest()==source["sha256"]
upstream=json.loads((ROOT/"vendor/UPSTREAM.json").read_text())
for name,digest in upstream["files"].items():
    assert hashlib.sha256((ROOT/"vendor"/name).read_bytes()).hexdigest()==digest,name
for mode in ["full","simple"]:
    weights=json.loads((ROOT/"weights"/(mode+".json")).read_text())
    assert weights["portraitHash"]==source["sha256"]
    assert weights["mode"]==mode
    assert weights["curve"][-1]["mse"]<weights["curve"][0]["mse"]
material=json.loads((ROOT/"assets/MATERIALS.json").read_text())
assert hashlib.sha256((ROOT/"assets"/material["file"]).read_bytes()).hexdigest()==material["sha256"]
for asset in json.loads((ROOT/"assets/POLYHAVEN.json").read_text()):
    for name,record in asset["files"].items():
        assert hashlib.sha256((ROOT/"assets"/asset["id"]/name).read_bytes()).hexdigest()==record["sha256"]
character=json.loads((ROOT/"assets/Soldier/SOURCE.json").read_text())
assert hashlib.sha256((ROOT/"assets/Soldier/Soldier.glb").read_bytes()).hexdigest()==character["sha256"]
for asset in json.loads((ROOT/"assets/KHRONOS.json").read_text()):
    assert hashlib.sha256((ROOT/"assets"/asset["name"]/(asset["name"]+".glb")).read_bytes()).hexdigest()==asset["sha256"]
    assert (ROOT/"assets"/asset["name"]/"SOURCE.md").is_file()
for mode in ["full","simple"]:
    weights=json.loads((ROOT/"weights"/(mode+"-outdoor.json")).read_text())
    assert weights["portraitHash"]==character["sha256"]
    assert weights["mode"]==mode and weights["sceneVersion"]=="battlefield-1"
    assert weights["curve"][-1]["mse"]<weights["curve"][0]["mse"]
assert (ROOT/"uv.lock").is_file()
print("Public assets, upstream hashes, both scenes, trained weights, and lock are valid.")
