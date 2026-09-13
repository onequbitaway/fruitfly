"""Stage the small source distribution. Include only Git-visible source files."""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
destination=Path(sys.argv[1]).resolve()
if destination.exists(): raise SystemExit("Choose a new destination folder.")
files=subprocess.check_output(["git","ls-files","--cached","--others","--exclude-standard","-z"],cwd=ROOT).decode().split("\0")
selected=[]
for name in files:
    if not name: continue
    if any(part in {"private","runs",".venv",".build","Data","__pycache__"} for part in Path(name).parts): continue
    if name in ["LICENSE","AGENTS.md","docs/full-map-preview.md"] or name.startswith("experiments/flypilot/") or name.startswith("experiments/full-map/"):
        p=ROOT/name
        if p.is_file(): selected.append(name)
for name in selected:
    to=destination/name
    to.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/name,to)
(destination/"README.md").write_text("# FlyPilot\n\nOpen experiments/flypilot/README.md for setup.\n\nRun these commands:\n\n```sh\ncd experiments/flypilot\n./setup.sh\n./flypilot.sh run\n```\n")
print(f"Staged {len(selected)} source files in {destination}.")
