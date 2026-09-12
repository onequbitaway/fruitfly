# Fruitfly Royale

Ten flies. One survivor.

[Download Fruitfly Royale for Mac](https://github.com/onequbitaway/fruitfly/releases/tag/royale-0.1.0)

This is a separate Mac game. Ten flies start around a dish. They fight over
food as the ring closes. The last fly wins. Hits leave red blood particles.
Four crumbs draw the flies into separate fights. Hits push flies apart.

![Ten full-map flies fight in a shrinking ring.](../../docs/media/fruitfly-royale.gif)

This recorded Full map round plays at three times model time.
[Download the video and calculation trace.](https://github.com/onequbitaway/fruitfly/releases/tag/royale-0.1.0)

Each fly runs its own brain state. The wiring comes from MaleCNS.
Movement, combat, health, food healing, blood, and ring damage are game
rules. They are not measured or learned fly behavior. The red blood is a
fictional effect. Fruit flies do not have red blood.

## Run

Use a Mac with macOS 14 or later. Install Apple's command line tools:

```sh
xcode-select --install
```

From the top of this repository:

```sh
make royale
```

The build downloads the checked data pack once. It builds
`dist/Fruitfly Royale.app`. The app contains its data and works offline.
It opens in its own window. It needs no account or screen access.

The app uses an ad-hoc code signature. It is not notarized by Apple. A
downloaded build may require **System Settings → Privacy & Security →
Open Anyway** after the first launch attempt. A source build avoids the
download warning. Intel and Apple Silicon builds use the same source.

## Play

- Double-click inside the ring to drop food. Food restores some health.
- Click a fly or its roster row to see its brain activity.
- Press **Space** to pause or resume.
- Press **R** for a new round.
- Press **B** to turn blood effects on or off.
- Select **Simple** or **Full map** to start a round in that mode.

| Mode | Cells in each fly | Total across 10 flies |
| --- | ---: | ---: |
| Simple | 3,745 | 37,450 |
| Full map | 166,700 | 1,667,000 |

Simple uses the small spiking circuit. Full map runs all released selected
cells and connections in each of ten separate models. It uses more memory
and can run slower than real time. The display shows the calculation pace.
The game waits for each brain step. It does not invent spikes to fill gaps.
Both modes start from rest with a different seed for each fly.

The small brain plot uses real cell-body positions. It draws a fixed subset
for clarity and skips cells with missing positions. Every cell still runs.
The active count includes all cells. A knocked-out fly stops computing;
its brain plot holds its last sample.

See [model details](../../docs/full-map-preview.md) and
[data credits](../full-map/THIRD_PARTY.md) for source limits and licenses.

## Check and record

```sh
make royale-test
make royale-test-full
make royale-release
make royale-demo
```

The checks cover thirty complete rounds, one winner, bounded health and
food, repeatable seeds, brain effects on movement, ten separate brain states,
and blocking one fly's brain while the other nine keep running.

The demo uses Full map and seed 42. It writes an MP4, GIF, stills, and a
JSON trace to `experiments/royale/output/full`. The replay runs at three
times model time, as shown in the image. Each frame records the actual
per-fly active count, spike total, input, model time, and a hash of all rates.
Blood uses hit events. Its switch does not affect the game or brain seeds.

Source: Swift, AppKit, Core Graphics, AVFoundation, and the existing brain
solver. No image or video generation service is used.
