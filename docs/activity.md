# Watch the circuit

Turn on **Show brain activity** from the menu bar controls.
Click **Drop food nearby** in the new window.
You can also use **Place food** or Option-double-click on your desktop.

The window reads the same cell values that help set the fly's speed and turns.
It updates when the model completes a step.
It does not create extra activity for the display.
Pause holds the fly, cell values, and chart. Hide also stops the model.

## What the dots mean

Each dot represents one of the 3,745 included cells.
The source cell ID stays attached to the same dot.
The layout groups cells by class and side. It does not show anatomy.

| Color | Cells | Number |
| --- | --- | --- |
| Blue-green | Smell input cells | 2,639 |
| Purple | Local cells | 420 |
| Orange | Output cells | 686 |

Brightness follows the cell's current model value.
The scale stays fixed from zero to one. It has 16 color levels.
The display uses `floor(value * 15)` to select a level.
A dim dot at zero shows the cell's position. It does not mean the cell is active.
The count below the dots shows cells with values greater than 0.01.
The values beside the class names are the means for each class.

The lines show the 600 strongest retained connections between different cell classes.
Strength means contact count in the source data.
Each line refers to an actual connection in the included map.
Line brightness follows the source cell's value on the same fixed scale.
The lines do not show measured signal travel, spikes, or axon shapes.

## Read the chart

- **Food input:** the mean of the left and right signals sent into the model.
- **Circuit output:** the mean of the left and right output groups used by the fly.

Both lines use a fixed scale from zero to one.
The chart stores samples from completed model steps over the last ten seconds.
The counter shows model time. Pause and hide stop this time.

## What is real

The cell IDs, connection endpoints, and contact counts come from MaleCNS v1.0.
The window shows actual values from the running app model.
It does not show activity measured in a living fly.

We chose the cell response rules, time scale, food signals, and movement mapping.
Food search, eating, rest, and pointer reactions also use programmed rules.
The fly does not learn. The model covers a small selected smell circuit.
Read [the data notes](data.md) for the source, license, and limits.

## Check the GitHub clip

The README’s **Simple** clip shows a recorded run, not a live connection to your app.
The separate [Full map preview](full-map-preview.md) uses a different experimental model.
The recording uses the same model and drawing code as the app.
It runs for 12 seconds at 20 frames per second. Playback uses normal speed.
The fly sprite is enlarged. The clip uses a small test area and a fixed starting seed of 7.

Food drops at 1.50 seconds through the app's normal `dropFood` function.
The next frame shows the first model response at 1.55 seconds.
Only the food event is scheduled. The model determines all cell values after that event.
The normal pet rules determine the fly's movement and eating.
The run starts again when the GIF loops.

Files that support the clip:

- [Still preview](media/brain-activity.png).
- [Frame times, input, output, food, and fly state](media/activity-frames.json).
- [All cell values](media/cell-activity.f32.gz), compressed with gzip.
- [Recording settings and SHA-256 file checksums](media/activity-manifest.json).

The cell file stores 898,800 values: 240 frames × 3,745 cells.
Each value is a 32-bit floating-point number in little-endian byte order.
Values are stored by frame, then by cell.
Cell order matches the `ids` array in `Sources/FlyCore/Resources/smell-circuit.json`.
The file stores full model values before display color levels are applied.

From the source folder on a Mac, run:

```sh
make check-demo
```

This command checks the source files and recording checksums.
It runs the same example again and compares every saved cell value.
It also checks food input, output, fly state, food state, and GIF timing.
Cell values must match within 0.000002 to allow small differences between Mac types.
These checks run on both Apple Silicon and Intel in GitHub builds.
They check the software recording. They do not prove biological accuracy.

To create a new recording after a code change, run:

```sh
make demo
```

This command uses Swift and Apple image tools. It requires no video package or account.
It renders the app's own model in a test area. It does not record your desktop.
