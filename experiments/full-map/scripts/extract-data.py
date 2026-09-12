#!/usr/bin/env python3
"""Full-map extraction: retain every classified MaleCNS neuron and all released edges between them."""
import argparse,hashlib,json,struct,time
from pathlib import Path
from collections import Counter
import numpy as np
import pyarrow as pa, pyarrow.feather as feather, pyarrow.ipc as ipc
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-dir',type=Path,default=REPO/'.cache/malecns')
parser.add_argument('--output',type=Path,default=ROOT/'Data')
args=parser.parse_args()
CACHE=args.source_dir
OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
source_info=json.loads((REPO/'docs/data-provenance.json').read_text())['inputs']
for name,info in source_info.items():
 with (CACHE/name).open('rb') as f:
  actual=hashlib.file_digest(f,'sha256').hexdigest()
 if actual != info['sha256']:raise ValueError(f'Source hash mismatch: {name}')
start=time.time()
rows=feather.read_table(CACHE/'annotations.feather').to_pylist()
nodes=sorted((r for r in rows if r['superclass'] and r['status']!='Glia'),key=lambda r:r['bodyId'])
ids=np.array([r['bodyId'] for r in nodes],dtype=np.int64)
assert len(ids)==166700 and len(set(ids))==len(ids)
nts={r['body']:r['consensus_nt'] for r in feather.read_table(CACHE/'neurotransmitters.feather',columns=['body','consensus_nt']).to_pylist()}
signs=np.array([-1 if nts.get(r['bodyId']) in ('gaba','glutamate') else 1 for r in nodes],dtype='<f4')
groups=['Smell','Taste','Vision','Central complex','Mushroom body','Descending','Motor','Other brain','Nerve cord']
def group(r):
 c,s=r['class'],r['superclass']
 if c in ['olfactory','ALPN','ALLN','ALIN','ALON']: return 0
 if c=='gustatory':return 1
 if c=='CX':return 3
 if c in ['Kenyon_Cell','MBON']:return 4
 if s.startswith('ol_') or s.startswith('visual_'):return 2
 if s.startswith('descending_neuron'):return 5
 if s in ['cb_motor','vnc_motor']:return 6
 if s.startswith('vnc_') or s in ['ascending_neuron','sensory_ascending','sensory_ascending_tbc','ENS']:return 8
 return 7
catalog=sorted(set(r['type'] or 'untyped' for r in nodes));type_lookup={v:i for i,v in enumerate(catalog)}
channels={
 'odor':[i for i,r in enumerate(nodes) if r['type'] in ['ORN_DM1','ORN_VA2','ORN_DM4']],
 'taste':[i for i,r in enumerate(nodes) if r['class']=='gustatory' and (r['type'] or '').startswith('LB1')],
 'feeding':[i for i,r in enumerate(nodes) if r['type'] in ['GNG056','GNG540','GNG550']],
 'visual':[i for i,r in enumerate(nodes) if r['type']=='LC10a'],
 'steering':[i for i,r in enumerate(nodes) if r['type']=='DNa02'],
 'mn9':[i for i,r in enumerate(nodes) if r['type']=='MN9'],
}
metadata={'dataset':'MaleCNS v1.0','ids':ids.tolist(),'types':[type_lookup[r['type'] or 'untyped'] for r in nodes],'typeNames':catalog,
 'groups':[group(r) for r in nodes],'groupNames':groups,
 'sides':[{'L':-1,'R':1}.get(r['rootSide'] or r['somaSide'],0) for r in nodes],
 'positions':[r['somaLocation'] for r in nodes],
 'channels':channels,
 'selection':'Every non-glial annotation with a nonempty published superclass. No sampling. All positive released edges between these cells.',
 'positionMeaning':'Published somaLocation (cell body) in MaleCNS 8 nm voxel coordinates. Missing locations remain missing.'}
(OUT/'neurons.json').write_text(json.dumps(metadata,separators=(',',':'))+'\n')
print('Neurons',len(ids),'channels',{k:len(v) for k,v in channels.items()},flush=True)
sources=[];targets=[];counts=[]
with pa.memory_map(str(CACHE/'edges.feather'),'r') as source:
 reader=ipc.open_file(source)
 for b in range(reader.num_record_batches):
  batch=reader.get_batch(b)
  pre=batch.column(0).to_numpy();post=batch.column(1).to_numpy();weight=batch.column(2).to_numpy()
  a=np.searchsorted(ids,pre);z=np.searchsorted(ids,post)
  keep=(a<len(ids))&(z<len(ids))&(weight>0)
  keep&=ids[np.minimum(a,len(ids)-1)]==pre
  keep&=ids[np.minimum(z,len(ids)-1)]==post
  if keep.any():
   sources.append(a[keep].astype('<u4'));targets.append(z[keep].astype('<u4'));counts.append(weight[keep].astype('<u4'))
  if b%400==0: print('Read batches',b,'/',reader.num_record_batches,'seconds',round(time.time()-start),flush=True)
a=np.concatenate(sources);z=np.concatenate(targets);w=np.concatenate(counts)
del sources,targets,counts
if np.any(a[1:]<a[:-1]):
 print('Sort',len(a),'connections',flush=True)
 order=np.argsort(a,kind='stable');a=a[order];z=z[order];w=w[order];del order
assert len(a)<2**32 and np.max(w)<2**32
synapses=int(w.sum(dtype=np.uint64))
offsets=np.zeros(len(ids)+1,dtype='<u4');offsets[1:]=np.cumsum(np.bincount(a,minlength=len(ids)),dtype=np.uint64).astype('<u4')
with (OUT/'network.bin').open('wb') as f:
 f.write(struct.pack('<8sIIQ',b'FFBRN001',len(ids),len(a),synapses))
 for v in [offsets,z,w,signs]:f.write(v.tobytes())
# A matched small network retains the original smell-circuit cells.
original=json.loads((REPO/'Sources/FlyCore/Resources/smell-circuit.json').read_text())
small_ids=np.array([int(v) for v in original['ids']],dtype=np.int64)
indices=np.searchsorted(ids,small_ids)
assert np.all(ids[indices]==small_ids)
small={k:([metadata[k][int(i)] for i in indices] if k in ['ids','types','groups','sides','positions'] else v) for k,v in metadata.items() if k!='channels'}
inverse={int(full):i for i,full in enumerate(indices)}
small['channels']={k:[inverse[i] for i in v if i in inverse] for k,v in channels.items()}
small['selection']='Original 3,745-cell smell subset, with selective inputs and the same spiking rules as Full map.'
(OUT/'simple-neurons.json').write_text(json.dumps(small,separators=(',',':'))+'\n')
sa=np.array(original['from'],dtype='<u4');sz=np.array(original['to'],dtype='<u4');sw=np.array(original['counts'],dtype='<u4')
so=np.zeros(len(small_ids)+1,dtype='<u4');so[1:]=np.cumsum(np.bincount(sa,minlength=len(small_ids)),dtype=np.uint64)
with (OUT/'simple-network.bin').open('wb') as f:
 f.write(struct.pack('<8sIIQ',b'FFBRN001',len(small_ids),len(sa),int(sw.sum(dtype=np.uint64))))
 for v in [so,sz,sw,signs[indices]]:f.write(v.tobytes())
def digest(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
(OUT/'NOTICE.txt').write_text('MaleCNS v1.0. HHMI Janelia FlyEM, University of Cambridge, MRC Laboratory of Molecular Biology, and Google Research.\nSource: https://male-cns.janelia.org/download/\nData license: CC BY 4.0 https://creativecommons.org/licenses/by/4.0/\nChanges: classified-neuron selection, binary format, display groups, and chosen input/output sets.\n')
manifest={'attribution':'HHMI Janelia FlyEM, University of Cambridge, MRC Laboratory of Molecular Biology, and Google Research','dataset':'MaleCNS v1.0','cells':len(ids),'connections':len(a),'contacts':synapses,'selection':metadata['selection'],
 'groupCounts':dict(Counter(groups[group(r)] for r in nodes)),'statusCounts':dict(Counter(r['status'] or 'unlabeled' for r in nodes)),
 'cellsWithoutSomaLocation':sum(r['somaLocation'] is None for r in nodes),'inputCells':{k:len(v) for k,v in channels.items()},
 'source':'https://male-cns.janelia.org/download/','license':'CC BY 4.0','files':{p.name:{'bytes':p.stat().st_size,'sha256':digest(p)} for p in OUT.iterdir() if p.is_file() and p.name != 'manifest.json'},
 'sourceURLs':{k:v['url'] for k,v in source_info.items()},'sourceSHA256':{p.name:digest(p) for p in CACHE.iterdir() if p.suffix=='.feather'}}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2));print('Finished in',round(time.time()-start),'seconds')
