#!/usr/bin/env python3
"""Check saved full-map rates against every numeric frame readout."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--data', type=Path, default=root/'Data')
parser.add_argument('--output', type=Path, default=root/'output/brain')
args = parser.parse_args()
manifest = json.loads((args.data/'manifest.json').read_text())
for name, info in manifest['files'].items():
    with (args.data/name).open('rb') as file:
        assert hashlib.file_digest(file, 'sha256').hexdigest() == info['sha256'], name
trace = json.loads((args.output/'food-trace.json').read_text())
rates = np.fromfile(args.output/'food-rates.f32', dtype='<f4').reshape(trace['frameCount'], trace['cellCount'])
meta = json.loads((args.data/'neurons.json').read_text())
groups = np.array(meta['groups'])
assert np.isfinite(rates).all() and (rates >= 0).all()
for n, frame in enumerate(trace['frames']):
    assert int(np.sum(rates[n] > 0)) == frame['activeCells']
    for group in range(9):
        values = rates[n][groups == group]
        assert int(np.sum(values > 0)) == frame['groupActive'][group]
        assert abs(float(values.mean(dtype=np.float64)) - frame['groupMeanHz'][group]) < 1e-10
    assert float(rates[n][meta['channels']['mn9']].mean()) == frame['MN9Hz']
assert np.all(rates[:10] == 0)
print(f'Verified {rates.size:,} saved rates, frame totals, class means, MN9, and data hashes.')
