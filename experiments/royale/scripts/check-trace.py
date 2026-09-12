#!/usr/bin/env python3
"""Check a recorded round without third-party Python packages."""
import json
import math
from pathlib import Path
import sys

folder = Path(sys.argv[1] if len(sys.argv) > 1 else "experiments/royale/output/full")
manifest = json.loads((folder / "manifest.json").read_text())
frames = json.loads((folder / "trace.json").read_text())
assert len(frames) == manifest["frames"]
assert manifest["flyCount"] == 10 and manifest["mode"] in ("Simple", "Full map")
assert manifest["bloodToggleChangedPixels"] > 0
assert manifest["renderDidNotChangeBrainRates"]
last = None
for frame in frames:
    assert len(frame["flies"]) == len(frame["activity"]) == 10
    assert 0 <= frame["ringRadius"] <= 290
    alive = sum("diedAt" not in fly for fly in frame["flies"])
    assert 1 <= alive <= 10
    for fly, activity in zip(frame["flies"], frame["activity"]):
        assert fly["id"] == activity["id"]
        assert 0 <= fly["health"] <= 100
        assert all(math.isfinite(fly["position"][axis]) for axis in ("x", "y"))
        assert math.hypot(fly["position"]["x"], fly["position"]["y"]) <= 291.001
        assert 0 <= activity["activeCells"] <= manifest["cellsPerFly"]
        assert 0 <= activity["modelTime"] <= frame["modelTime"] + 0.001
        assert math.isfinite(activity["meanHz"]) and activity["meanHz"] >= 0
        if last:
            old = last["activity"][fly["id"]]
            assert activity["totalSpikes"] >= old["totalSpikes"]
            if "diedAt" in last["flies"][fly["id"]]:
                assert activity == old, "A knocked-out brain kept running."
    if last:
        assert 0 < frame["modelTime"] - last["modelTime"] <= 0.301
        assert frame["ringRadius"] <= last["ringRadius"]
        assert alive <= sum("diedAt" not in fly for fly in last["flies"])
    last = frame
survivors = [fly["id"] for fly in frames[-1]["flies"] if "diedAt" not in fly]
assert survivors == [manifest["winner"]]
assert len({a["rateHash"] for a in frames[0]["activity"]}) > 1
assert abs(frames[-1]["modelTime"] - manifest["lastModelTime"]) < 0.001
print(f"Passed: {len(frames)} frames, ten separate brains, frozen knockout states, one winner, and blood toggle.")
