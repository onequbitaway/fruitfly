"""Fetch the pinned game character from its upstream example. Do not bundle the raw model."""
import hashlib
import json
import urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/Soldier';record=json.loads((folder/'SOURCE.json').read_text())
path=folder/'Soldier.glb'
if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==record['sha256']:
    print('The game character is ready.')
else:
    request=urllib.request.Request(record['source'],headers={'User-Agent':'Fruitfly-FlyPilot/0.1'})
    with urllib.request.urlopen(request,timeout=90) as response:data=response.read()
    if hashlib.sha256(data).hexdigest()!=record['sha256']:raise RuntimeError('The character checksum changed. No file was installed.')
    temporary=path.with_suffix('.download');temporary.write_bytes(data);temporary.replace(path)
    print('The pinned game character is ready.')
