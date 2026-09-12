# Brain data

Source: [MaleCNS v1.0](https://male-cns.janelia.org/download/).

The data comes from HHMI Janelia, the University of Cambridge, the MRC Laboratory of Molecular Biology, and Google Research.
The data uses the [Creative Commons Attribution 4.0 license](https://creativecommons.org/licenses/by/4.0/).

The app includes the file `Sources/FlyCore/Resources/smell-circuit.json`.
The full source files are not included.

The included file contains 3,745 cells and 435,997 directed connections.
These connections represent 3,213,028 contacts between cells in the source data.
The file is about 4.8 MB before ZIP compression.

## Selection

The selected cells have one of these published classes:

- `olfactory`: cells that receive smell input.
- `ALPN`: cells that pass signals from the antennal lobe to other brain regions.
- `ALLN`: cells that connect within the antennal lobe.

The antennal lobe is a brain region that processes smell.
Entries marked as glia are excluded. Glia are support cells.
The file retains all positive connections between selected cells, including connections from a cell to itself.
It does not add connections. The source uses a synapse confidence threshold of 0.5.

Read [data-provenance.json](data-provenance.json) for exact counts, source URLs, file sizes, and SHA-256 checksums.

## Model

The app assigns a value between zero and one to each cell.
This value represents modeled activity. It is not a measured firing rate.
Values below 0.000001 are set to zero. An idle circuit stops its calculation until it receives new input.

1. Food position determines the strength of the left and right smell inputs.
2. The inputs enter the selected smell cells.
3. Activity passes through the published connections.
4. Average activity in the left and right output groups changes speed and turn direction.

The app divides connection weights by the total retained input weight for each target cell.
This step keeps large input counts from overwhelming the model.
Cells with predicted GABA or glutamate use a negative sign.
Other cells, including cells with missing transmitter data, use a positive sign.
These signs are model assumptions. Actual effects also depend on receptors, which this model does not include.

The cell response curve, time scale, input signals, and movement mapping are chosen for this app.
Unknown cell sides receive the mean of the two inputs.
The app uses `rootSide` when available, then `somaSide`.

## Limits

A wiring map records connections between cells.
It does not provide a complete working brain or a record of learned behavior.

The app includes only a selected smell circuit. Connections to all other cells are excluded.
Food search, landing, eating, rest, and pointer reactions use programmed rules.
The fly does not learn. Tests check software behavior; they do not prove biological accuracy.
The brain view shows values from all 3,745 included cells. Dot positions do not show anatomy.
Read [the activity guide](activity.md) for display scales and recording checks.

## Rebuild the included data

These steps are for contributors. App users do not need them.
The source download is about 1.1 GB.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install pyarrow numpy
.venv/bin/python scripts/extract_circuit.py --download
make test
```

The script stores source files in `.cache/malecns`.
Git ignores this directory. The output file contains only the selected cells and connections.

## Attribution

MaleCNS v1.0, HHMI Janelia FlyEM, University of Cambridge, MRC Laboratory of Molecular Biology, and Google Research.
Data license: CC BY 4.0.
Changes: cell selection, compact file format, and removal of connections outside the selected circuit.
Runtime weight scaling and modeled dynamics are further changes made by Fruitfly.
