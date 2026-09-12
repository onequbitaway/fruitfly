# Fruitfly full-map preview

Run the full mapped network and inspect its activity.
Choose **Simple** or **Full map** in the same window.
The source includes the CPU solver, Metal solver, controls, model checks, and animation code.

[Download the Mac preview](https://github.com/onequbitaway/fruitfly/releases/tag/full-map-preview-0.1.0)

The preview runs in its own window. The released [desktop pet](../../README.md) floats above your apps.
The desktop animation is a rendered scene made with this full-map model.

## Download and run

1. Open the download page.
2. Download `Fruitfly-Full-Map-Preview-0.1.0-macos-universal.zip`.
3. Open the ZIP file.
4. Move **Fruitfly Preview** to Applications.
5. Open it.
6. Choose **Simple** or **Full map**.

The download contains both data sets. No account, Python, or separate service is needed.
It supports macOS 14 or later on Apple Silicon and Intel Macs.
It uses Metal when available and the same CPU model otherwise.
Full-mode speed depends on the Mac. The model clock slows when it cannot keep up.
The preview has an ad hoc signature. It is not notarized.
See [the install notes](../../README.md#install) if macOS blocks it.

## Build from a fresh clone

Install Apple's command line tools, then run these commands:

```sh
xcode-select --install
git clone https://github.com/onequbitaway/fruitfly.git
cd fruitfly
make preview
```

`make preview` downloads the data pack, checks its SHA-256 hash, builds the app, and opens it.
The large data files stay outside Git. The app bundle includes them after the build.
The first build needs network access for the data. Later runs work offline.

| Mode | Cells | Connections | Behavior |
| --- | ---: | ---: | --- |
| Simple | 3,745 | 435,997 | Smell subset. Food use follows a pet rule. |
| Full map | 166,700 | 25,582,938 | Full selected graph. Food use reads MN9 output. |

Both preview modes use spiking rules. The released desktop app uses a different rate model.
The two preview modes share the same parameters and selected smell input.

## Controls

Double-click in the fly area to place food. You can also select **Drop food**.
Use **Pause** to hold the model and **Reset** to start again.
Click a cell class to isolate its colored points.
The input buttons apply two seconds of direct stimulation. Reset between independent tests.
**Block MN9 feeding cells** prevents those model cells from firing.
In Full map, this prevents food use. It does not stop other cells from firing.

Movement toward food follows a pet rule. The DNa02 output adds a small turn bias.
This is an experimental model of the map. It is not a complete working fly.
Read [the model notes](../../docs/full-map-preview.md) for sources, equations, input cells, and limits.

## Check the source

From the repository root:

```sh
make preview-test
make preview-ui-check
```

The first command checks the full data and both solvers.
The second builds the app and checks mode changes, pause, food placement, reset, and the feeding block.
The checks run on GitHub for Apple Silicon and Intel Macs.

For a small analytical check without downloading the data:

```sh
swift run -c release --package-path experiments/full-map BrainChecks --kernel-only
```

The full check compares CPU and graphics spike counts for a short, seeded run.
It also checks an independent inhibitory response and blocking effects.
These checks validate software behavior, not biological accuracy.

## Make the animations

From the repository root:

```sh
make preview-demo
make desktop-demo
```

The first command writes the brain GIF, four independent input stills, a Simple still, and every cell rate.
The second writes the desktop GIF, a desktop MP4, a desktop-to-brain MP4, and every desktop-trial rate.
Files go to `experiments/full-map/output`. The source uses AppKit, ImageIO, and AVFoundation.
It needs no video editor or external animation service. It does not record your screen.
The desktop clip draws clean windows and a pointer around the model-driven trial.

To check the saved values, install the optional Python tools:

```sh
python3 -m venv .venv
.venv/bin/pip install -r experiments/full-map/scripts/requirements.txt
.venv/bin/python experiments/full-map/scripts/check-recording.py
.venv/bin/python experiments/full-map/scripts/check-desktop-values.py
swift experiments/full-map/scripts/check-video.swift experiments/full-map/output/desktop
```

Python 3.11 or later is needed for these maintainer tools. The app itself does not need Python.
The checks use the data folder and output folders shown above. Use `--help` to select other folders.
The `export-github-media.py` script copies a checked brain recording into `docs/media` when updating it.

## Rebuild the data pack

The prepared [data pack](https://github.com/onequbitaway/fruitfly/releases/download/full-map-preview-0.1.0/MaleCNS-v1.0-fruitfly-data.tar.gz)
is the easiest way to run the model. To reproduce its extraction, install the optional Python tools above, then run:

```sh
.venv/bin/python experiments/full-map/scripts/download-sources.py
.venv/bin/python experiments/full-map/scripts/extract-data.py
```

This downloads about 1.1 GB of original data into `.cache/malecns` and verifies the source hashes.
Extraction writes `experiments/full-map/Data`. Close the preview before replacing data it has open.
No weight threshold or random sampling removes edges between the selected cells.
See the data manifest for the exact selection and source hashes.

## Files

| Path | Purpose |
| --- | --- |
| `Sources/BrainKernel` | CPU solver in C++ |
| `Sources/BrainCore` | Model, inputs, trials, and Metal solver |
| `Sources/BrainPreview` | Window, drawing, recordings, and live UI checks |
| `Sources/BrainChecks` | Analytical and full-network checks |
| `scripts` | Setup, packaging, extraction, export, and value checks |
| `provenance` | Results from the original checked preview |
| `data-files.sha256` | Expected unpacked data hashes |
| `data-pack.sha256` | Expected download hash |

The code uses MIT. The data retains CC BY 4.0. See [the credits](THIRD_PARTY.md).
