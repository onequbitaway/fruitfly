from pathlib import Path
import argparse,json,gzip,hashlib,shutil
preview=Path(__file__).resolve().parents[1]
root=preview.parents[1]
parser=argparse.ArgumentParser(description='Copy a checked full-map recording into docs/media.')
parser.add_argument('--output',type=Path,default=preview/'output/brain')
args=parser.parse_args()
out=root/'docs/media'
shutil.copyfile(args.output/'full-map-food.gif',out/'full-map-activity.gif')
shutil.copyfile(args.output/'food-39.png',out/'full-map-activity.png')
shutil.copyfile(args.output/'food-trace.json',out/'full-map-frames.json')
(out/'full-map-cell-activity.f32.gz').write_bytes(gzip.compress((args.output/'food-rates.f32').read_bytes(),mtime=0))
metadata=json.loads((preview/'Data/neurons.json').read_text())
index={k:metadata[k] for k in ['ids','groups','groupNames','sides','channels']}
(out/'full-map-cell-index.json.gz').write_bytes(gzip.compress((json.dumps(index,separators=(',',':'))+'\n').encode(),mtime=0))
data_manifest=json.loads((preview/'Data/manifest.json').read_text())
checks=json.loads((preview/'output/checks.json').read_text())
def digest(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
files=['full-map-activity.gif','full-map-activity.png','full-map-frames.json','full-map-cell-activity.f32.gz','full-map-cell-index.json.gz']
manifest={
 'kind':'Recorded experimental Full map model; not part of v0.2.0',
 'dataset':'MaleCNS v1.0','source':data_manifest['source'],'dataLicense':data_manifest['license'],
 'attribution':'HHMI Janelia FlyEM, University of Cambridge, MRC Laboratory of Molecular Biology, and Google Research',
 'cells':166700,'connections':25582938,'contacts':124177617,'cellsWithPositions':139662,'cellsWithoutPositions':27038,
 'selection':data_manifest['selection'],'sourceSHA256':data_manifest['sourceSHA256'],'modelDataFiles':data_manifest['files'],
 'frames':80,'framesPerSecond':10,'durationSeconds':8,'modelStepMilliseconds':0.2,'seed':7,'foodDropBeforeFrame':10,
 'dimensions':[1260,820],'positionMeaning':metadata['positionMeaning'],
 'cellFileFormat':'gzip of little-endian Float32 rates; frame first, then cell; cell order is full-map-cell-index.json.gz ids',
 'brightness':'Last 100 ms spike rate; fixed 0–100+ Hz scale in 12 levels; gray points show anatomy',
 'movement':'Guided pet rule with a DNa02 turn bias','foodUse':'min(1, mean MN9 Hz / 40) times the chosen consumption rate',
 'input':'Food creates selected odor input; contact adds LB1 taste input. No direct feeding-pathway stimulation in this recording.',
 'validation':checks,
 'recordedModelSourceSHA256':{str(p.relative_to(preview)):digest(p) for p in sorted((preview/'Sources').rglob('*')) if p.is_file() and p.suffix in ['.swift','.cpp','.h']},
 'files':{name:{'bytes':(out/name).stat().st_size,'sha256':digest(out/name)} for name in files}}
(out/'full-map-manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
