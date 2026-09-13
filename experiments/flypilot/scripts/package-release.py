"""Package only the public source and the selected, validated local evidence."""
import hashlib
import json
import shutil
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
OUT=ROOT/'runs/release'
OUT.mkdir(parents=True,exist_ok=True)
subprocess.run([str(ROOT/'.venv/bin/python'),str(ROOT/'scripts/check_sources.py')],check=True)
record=ROOT/'runs/battle-full'
cinematic=ROOT/'runs/battle-cinematic'
render=json.loads((cinematic/'render-provenance.json').read_text())
assert render['sourceTraceHash']==hashlib.sha256((record/'trace.jsonl.gz').read_bytes()).hexdigest()
check=json.loads((record/'replay-check.json').read_text())
assert check['physics'] and check['frames']==check['exportedRateFrames']==check['brainFrames']
assert render['frames']==check['frames']
assert check['maxPositionErrorM']<=check['positionToleranceM']
assert json.loads((record/'checkpoint.json').read_text())==json.loads((ROOT/'weights/full-outdoor.json').read_text())
assert json.loads((record/'metrics.json').read_text())['contact']
# A reusable scenery export must contain no character, skin, or animation.
raw=(cinematic/'battle-map.glb').read_bytes()
assert raw[:4]==b'glTF'
length,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
model=json.loads(raw[20:20+length])
assert not model.get('skins') and not model.get('animations')
static={p['name'] for p in json.loads((ROOT/'runs/cinematic-recording/scene.json').read_text())['parts'] if p['role']=='static'}
assert all(node.get('name') in static for node in model['nodes'])

with tempfile.TemporaryDirectory(prefix='flypilot-source-') as temporary:
    source=Path(temporary)/'FlyPilot-0.1.0'
    subprocess.run([str(ROOT/'.venv/bin/python'),str(ROOT/'scripts/stage-source.py'),str(source)],check=True)
    with zipfile.ZipFile(OUT/'FlyPilot-0.1.0-source.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for path in sorted(source.rglob('*')):
            if path.is_file():archive.write(path,Path(source.name)/path.relative_to(source))

with zipfile.ZipFile(OUT/'FlyPilot-0.1.0-evidence.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    selected=[]
    selected.extend((p,'recording/'+str(p.relative_to(record))) for p in record.rglob('*') if p.is_file() and p.suffix!='.mp4')
    for scene in ['outdoor','studio']:
        for mode in ['full','simple']:
            # Studio comparisons predate the explicit scene argument.
            folder=ROOT/'runs'/('evaluation-outdoor-'+mode if scene=='outdoor' else 'evaluation-'+mode)
            assert (folder/'results.json').is_file(),folder
            report=json.loads((folder/'results.json').read_text())
            assert len(report['results'])==18
            selected.extend((p,'evaluation/'+scene+'-'+mode+'/'+str(p.relative_to(folder))) for p in folder.rglob('*') if p.is_file() and p.suffix in ['.json','.gz'])
    for folder in ['training-outdoor-full','training-outdoor-simple','training-full','training-simple']:
        p=ROOT/'runs'/folder/'samples.json'
        assert p.is_file(),p
        selected.append((p,'training/'+folder+'/samples.json'))
    for folder in ['weights','provenance']:
        selected.extend((p,folder+'/'+p.name) for p in (ROOT/folder).iterdir() if p.is_file())
    selected.extend((ROOT/name,name) for name in ['README.md','METHODS.md','RESULTS.md','THIRD_PARTY.md','GAME_MAP.md'])
    selected.extend((cinematic/name,'enhanced-render/'+name) for name in ['render-provenance.json','sound.json','opening.png','contact.png'])
    selected.append((ROOT/'runs/battle-cinematic-frames/render-times.json','enhanced-render/render-times.json'))
    selected.append((ROOT/'runs/cinematic-recording/frames.json','enhanced-render/verified-poses.json'))
    selected.append((REPO/'LICENSE','LICENSE'))
    manifest={}
    for path,name in sorted(selected,key=lambda item:item[1]):
        archive.write(path,'FlyPilot-0.1.0-evidence/'+name)
        manifest[name]=hashlib.sha256(path.read_bytes()).hexdigest()
    archive.writestr('FlyPilot-0.1.0-evidence/SHA256.json',json.dumps(manifest,indent=2)+'\n')
    archive.writestr('FlyPilot-0.1.0-evidence/REPLAY.md',
        '# Replay\n\nSet up the source package first. From experiments/flypilot, run:\n\n'
        '```sh\n./flypilot.sh check /absolute/path/to/FlyPilot-0.1.0-evidence/recording\n```\n\n'
        'The evidence contains public rendered cameras and calculated rates. It does not contain raw brain wiring.\n')
shutil.copy2(cinematic/'flypilot-cinematic.mp4',OUT/'FlyPilot-0.1.0-full-map.mp4')
shutil.copy2(cinematic/'battle-map.mp4',OUT/'FlyPilot-0.1.0-battle-map.mp4')
shutil.copy2(cinematic/'battle-map.glb',OUT/'FlyPilot-0.1.0-battle-map.glb')
files=sorted(p for p in OUT.iterdir() if p.name.startswith('FlyPilot-0.1.0-') and p.suffix in ['.zip','.mp4','.glb'])
(OUT/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in files))
for path in files:print(path.name,path.stat().st_size)
