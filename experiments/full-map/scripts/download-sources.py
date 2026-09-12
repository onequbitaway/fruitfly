#!/usr/bin/env python3
"""Download and check the original MaleCNS files for data extraction."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
repo = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-dir', type=Path, default=repo/'.cache/malecns')
args = parser.parse_args()
args.source_dir.mkdir(parents=True, exist_ok=True)
inputs = json.loads((repo/'docs/data-provenance.json').read_text())['inputs']
def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()
for name, info in inputs.items():
    path = args.source_dir/name
    if path.exists() and digest(path) == info['sha256']:
        print('Already checked:', name)
        continue
    part = path.with_suffix('.part')
    try:
        print('Downloading:', name, flush=True)
        with urllib.request.urlopen(info['url'], timeout=120) as source, part.open('wb') as dest:
            while block := source.read(1024*1024):
                dest.write(block)
        if digest(part) != info['sha256']:
            raise ValueError(f'Source hash mismatch: {name}')
        part.replace(path)
    finally:
        part.unlink(missing_ok=True)
print('Source files match the published extraction inputs.')
