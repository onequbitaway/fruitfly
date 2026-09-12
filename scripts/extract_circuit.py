#!/usr/bin/env python3
"""Build the small, bundled smell circuit from the public MaleCNS files.

This is a maintainer tool. The app does not require Python or raw data.
Install pyarrow and numpy in a virtual environment before use.
"""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from urllib.request import urlretrieve

import numpy as np
import pyarrow.feather as feather
import pyarrow.ipc as ipc
import pyarrow as pa

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://storage.googleapis.com/flyem-male-cns/v1.0/connectome-data/flat-connectome/"
FILES = {
    "annotations.feather": "body-annotations-male-cns-v1.0-minconf-0.5.feather",
    "neurotransmitters.feather": "body-neurotransmitters-male-cns-v1.0.feather",
    "edges.feather": "connectome-weights-male-cns-v1.0-minconf-0.5.feather",
}


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true", help="Download about 1.1 GB of source data.")
    args = parser.parse_args()
    cache = ROOT / ".cache" / "malecns"
    cache.mkdir(parents=True, exist_ok=True)
    for name, remote in FILES.items():
        if not (cache / name).exists():
            if not args.download:
                raise SystemExit(f"Missing {name}. Use --download to fetch the source files.")
            temporary = cache / (name + ".part")
            print(f"Download {name}", flush=True)
            urlretrieve(BASE + remote, temporary)
            temporary.replace(cache / name)

    previous = ROOT / "docs/data-provenance.json"
    if previous.exists():
        recorded = json.loads(previous.read_text())
        for name in FILES:
            if digest(cache / name) != recorded["inputs"][name]["sha256"]:
                raise SystemExit(f"Source checksum changed: {name}. Review the source before updating the record.")

    annotations = feather.read_table(cache / "annotations.feather").to_pylist()
    kinds = {"olfactory": 0, "ALPN": 1, "ALLN": 2}
    nodes = sorted(
        (r for r in annotations if r["class"] in kinds and r["status"] != "Glia"),
        key=lambda r: r["bodyId"],
    )
    ids = np.array([n["bodyId"] for n in nodes], dtype=np.int64)
    transmitters = {
        r["body"]: r["consensus_nt"]
        for r in feather.read_table(cache / "neurotransmitters.feather", columns=["body", "consensus_nt"]).to_pylist()
    }
    circuit = {
        "source": "MaleCNS v1.0",
        "ids": [str(n["bodyId"]) for n in nodes],
        "types": [n["type"] or "untyped" for n in nodes],
        "kinds": [kinds[n["class"]] for n in nodes],
        "sides": [{"L": -1, "R": 1}.get(n["rootSide"] or n["somaSide"], 0) for n in nodes],
        "signs": [-1 if transmitters.get(n["bodyId"]) in ("gaba", "glutamate") else 1 for n in nodes],
        "from": [], "to": [], "counts": [],
    }
    # Process batches to avoid loading the full connection table into memory.
    with pa.memory_map(str(cache / "edges.feather"), "r") as source:
        reader = ipc.open_file(source)
        print(f"Edge columns: {reader.schema.names}", flush=True)
        for column in ["body_pre", "body_post", "weight"]:
            if column not in reader.schema.names:
                raise SystemExit(f"Missing source column: {column}")
        for b in range(reader.num_record_batches):
            batch = reader.get_batch(b)
            pre = batch.column(reader.schema.get_field_index("body_pre")).to_numpy()
            post = batch.column(reader.schema.get_field_index("body_post")).to_numpy()
            counts = batch.column(reader.schema.get_field_index("weight")).to_numpy()
            src = np.searchsorted(ids, pre)
            dst = np.searchsorted(ids, post)
            keep = (src < len(ids)) & (dst < len(ids))
            keep &= ids[np.minimum(src, len(ids) - 1)] == pre
            keep &= ids[np.minimum(dst, len(ids) - 1)] == post
            keep &= counts > 0
            circuit["from"].extend(src[keep].tolist())
            circuit["to"].extend(dst[keep].tolist())
            circuit["counts"].extend(counts[keep].astype(int).tolist())
    # Stable ordering makes regenerated files easy to compare.
    edges = sorted(zip(circuit["from"], circuit["to"], circuit["counts"]))
    circuit["from"], circuit["to"], circuit["counts"] = map(list, zip(*edges))
    output = ROOT / "Sources/FlyCore/Resources/smell-circuit.json"
    output.write_text(json.dumps(circuit, separators=(",", ":")) + "\n")
    provenance = {
        "dataset": "MaleCNS v1.0",
        "source": "https://male-cns.janelia.org/download/",
        "license": "https://creativecommons.org/licenses/by/4.0/",
        "selection": "All non-glial entries with class olfactory, ALPN, or ALLN; all released positive-weight edges with both endpoints retained. No added edges.",
        "classes": dict(Counter(n["class"] for n in nodes)),
        "cells": len(nodes),
        "directed_connections": len(edges),
        "synaptic_contacts": sum(circuit["counts"]),
        "unknown_side_cells": circuit["sides"].count(0),
        "missing_transmitter_cells": sum(not transmitters.get(n["bodyId"]) for n in nodes),
        "transmitters": dict(Counter(transmitters.get(n["bodyId"]) or "unknown" for n in nodes)),
        "model_assumptions": [
            "rootSide takes precedence over somaSide; unknown side receives the mean input.",
            "GABA and glutamate are assigned an inhibitory sign. All other or missing transmitter types are assigned an excitatory sign. Receptors are not modeled.",
            "Runtime weights are divided by each target's retained incoming contact count.",
            "Sensory input, rate dynamics, bilateral output averages, and desktop movement mappings are engineered. This is not learned food-seeking or a whole-brain emulation.",
        ],
        "inputs": {name: {"url": BASE + remote, "sha256": digest(cache / name), "bytes": (cache / name).stat().st_size} for name, remote in FILES.items()},
        "output": {"path": str(output.relative_to(ROOT)), "sha256": digest(output), "bytes": output.stat().st_size},
    }
    (ROOT / "docs/data-provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print(json.dumps({k: provenance[k] for k in ["cells", "directed_connections", "synaptic_contacts", "output"]}, indent=2))


if __name__ == "__main__":
    main()
