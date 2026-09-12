from pathlib import Path
import argparse,json,numpy as np
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description='Check every saved desktop-model value and food-use step.')
parser.add_argument('--data',type=Path,default=root/'Data')
parser.add_argument('--output',type=Path,default=root/'output/desktop')
args=parser.parse_args()
meta=json.loads((args.data/'neurons.json').read_text())
trace=json.loads((args.output/'desktop-trace.json').read_text())
rates=np.fromfile(args.output/'desktop-rates.f32',dtype='<f4').reshape(120,166700)
groups=np.array(meta['groups']);sides=np.array(meta['sides'])
assert np.isfinite(rates).all() and np.all(rates>=0)
assert np.all(rates[:12]==0)
previous=None
for n,frame in enumerate(trace['frames']):
    row=rates[n];trial=frame['trial']
    assert abs(frame['modelSeconds']-(n+1)/10)<1e-9
    assert np.count_nonzero(row)==frame['activeCells']
    assert row[meta['channels']['mn9']].mean()==frame['MN9Hz']
    for g in range(9):
        values=row[groups==g]
        assert np.count_nonzero(values)==frame['groupActive'][g]
        assert abs(values.mean(dtype=np.float64)-frame['groupMeanHz'][g])<1e-10
    if previous is not None and previous['foodAmount']>0:
        at_food=np.hypot(previous['x']-previous['foodX'],previous['y']-previous['foodY'])<14
        expected=max(0,previous['foodAmount']-0.05*min(1,frame['MN9Hz']/40)) if at_food else previous['foodAmount']
        assert abs(trial['foodAmount']-expected)<1e-9,(n,trial['foodAmount'],expected)
    if n==12:assert trial['foodAmount']==0.1
    previous=trial
assert trace['frames'][-1]['trial']['meals']==1
print('Verified all 20,004,000 rates, class readouts, model time, and each food-use step against MN9.')
print('Food gone at',next(f['modelSeconds'] for f in trace['frames'] if f['trial']['meals']==1),'model seconds.')
