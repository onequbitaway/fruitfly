# Fruitfly Duel

Two flies. Three lives. One winner.

[Download Fruitfly Duel for Mac](https://github.com/onequbitaway/fruitfly/releases/tag/duel-0.1.0)

![Two full-map flies fight on a leaf stage.](../../docs/media/fruitfly-duel.gif)

This recorded Full map match plays at three times model time.
[Download the video and calculation trace.](https://github.com/onequbitaway/fruitfly/releases/tag/duel-0.1.0)

This is a separate Mac platform fighter. Pip and Zip fight on leaves above
a pond. They jump, shield, grab, throw, and knock each other off the stage.
Each fly has its own brain model. Choose Simple or Full map.

## Run

Use macOS 14 or later on an Apple Silicon or Intel Mac.
Install Apple's command line tools, then run from the repository root:

```sh
xcode-select --install
make duel
```

The build downloads the checked data pack once. The app contains the data
and works offline. You do not need Node, Python, an account, or screen
access to run the app. It opens in its own window. It does not control
another copy of Smash Bros.

Downloaded apps use an ad-hoc signature. They are not notarized by Apple.
After the first launch attempt, macOS may require **System Settings →
Privacy & Security → Open Anyway**. A local source build avoids the
download warning. Windows and Linux are not supported by this Mac app.

## Watch a match

The flies fight on their own. Each starts with three lives. Higher damage
makes a fly easier to launch. A ring-out costs one life. A fly with no lives
loses. At 90 seconds, the fly with more lives wins. Tied lives start sudden
death: both flies have one life and 999% damage.

- Press **Space** to pause or resume.
- Press **R** to start a new match with a new seed.
- Press **B** to turn blood effects on or off.
- Select **Simple** or **Full map** to restart in that mode.

The red blood is a fictional game effect. It appears only after hits and
throws. Fruit flies do not have red blood. The effect does not change the
brain, combat results, or random seeds.

## How the brains affect play

| Mode | Cells per fly | Direction cue |
| --- | ---: | --- |
| Simple | 3,745 | The opponent's direction becomes a game scent cue. |
| Full map | 166,700 | The opponent's direction drives selected visual cells. |

Full map runs every cell and connection in the released selected MaleCNS
graph. Both flies use that wiring with separate states and seeds. This is
an experimental spiking model. It is not a complete working fly or a
recording of a living brain.

Every 100 ms of model time, the game supplies simulated sensory input:

- Full map uses LC10a visual cells for the opponent and a fixed 20 Hz odor
  background. Simple uses smell cells as a proxy for opponent direction.
- Mean activity in the input channel sets movement strength and the time
  available for attacks. Left and right channel activity, plus DNa02
  output where present, adds a small steering bias.
- A fully silent brain supplies no control input. Gravity and incoming
  hits still act on its body.
- The open-source controller chooses attacks, jumps, shields, and recovery.
  These are programmed rules. The flies have not learned how to fight.

The input and control mappings are game design choices. They are not
validated models of fly aggression or navigation. Broad brain activity
can result from the model's network dynamics. Bright areas do not prove
that a biological brain region performs the move on screen.

The game advances six physics frames for each brain sample. The display
plays those frames. If calculation is slow, the game waits and reports it.
It does not make up spikes. Full map can run below real time, especially
on Intel Macs. Simple uses less memory and runs faster.

The two brain plots use real cell-body positions. They draw a fixed subset
of about 1,200 cells each. Cells without known positions do not appear.
All cells still calculate. The active counts include the full models.

See [model notes](../../docs/full-map-preview.md) and
[data licenses](../full-map/THIRD_PARTY.md).

## Open-source game engine

Combat uses [Super Bash Folds](https://github.com/blancmathis/Super_Bash_Folds),
under the MIT license. The pinned commit is
`1028a3b739ef54efdcbe5a2ef0ad1714fe569c47`.

Eight source files in `Engine/vendor` are copied without changes. They
provide combat, physics, control policy, and move builders. Their hashes,
source, and license are included. Fruitfly supplies its own roster, stage,
brain bridge, and native vector art. No upstream character art or audio is
included. This is an independent platform fighter, with no Nintendo assets.

The app uses Swift, JavaScriptCore, AppKit, Core Graphics, AVFoundation,
and the existing BrainCore solver. No animation generation service is used.

## Build, check, and record

```sh
make duel-test
make duel-test-full
make duel-release
make duel-demo
```

The JavaScript bundle is committed so app builds need no Node installation.
If you change the engine or its bridge, install Node 22 or later and run:

```sh
cd experiments/duel
npm ci
npm run build
npm test
```

Tests check twenty complete matches, damage and lives, repeatable seeds,
changed play when rates change, and zero controls from a silent brain.
Swift checks run the bundled engine through JavaScriptCore. They verify
separate brain states, exact plotted cell rates, and one silenced brain
while the other keeps running.

The demo records a full match with Full map and seed 42. It writes an MP4,
GIF, stills, a manifest, and a trace to `experiments/duel/output/full`.
Playback runs at three times model time, as labeled. The trace includes
every 100 ms sample, its six game frames, inputs, active counts, spike
totals, control values, plotted rates, and hashes of all cell rates.

To check the released trace against the bundled fight engine:

```sh
node experiments/duel/Engine/check-trace.mjs experiments/duel/output/full/trace.ndjson
```

This repeats every combat frame from the recorded brain outputs. It checks
positions, damage, lives, moves, and events. The small tolerance allows
floating-point differences between JavaScriptCore and Node.
