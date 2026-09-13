# FlyPilot

I gave a fruit-fly brain model a drone.

FlyPilot gives a simulated drone commands from a fruit-fly brain model.
The main scene is a ruined battle map. It has broken buildings, burned cars,
road craters, rubble, exposed steel, and smoke.
A fictional game soldier leaves a doorway and walks along the pavement.
The larger drone approaches the character. Geometric contact ends the encounter.
The view shows the world, drone camera, flight path, and calculated cell activity.
The optional studio scene follows a known portrait at a set distance.
Full map runs 166,700 cells. Simple runs 3,745 cells with separate trained weights.

This is a separate experiment. The stable Fruitfly desktop pet stays at v0.2.0.

## Start

Tested on an Apple M4 Max with 48 GB of memory and macOS 26.5.
Other systems have not been validated for this release.
The Swift package requires macOS 14 or later. This is a build requirement, not a tested support claim.

Install [Apple Command Line Tools](https://developer.apple.com/xcode/resources/).
Install [uv](https://docs.astral.sh/uv/getting-started/installation/).
Full Xcode is not required. Setup uses a local Python environment.
It does not change system Python.

From this folder, run:

```sh
./setup.sh
./flypilot.sh run
```

After setup, you can also open `FlyPilot.command`.
The launcher opens a local browser view. Select **Start**.
Select **Pause** to stop model time. Select **Reset** to repeat the start seed.
Select a brain mode to start a new run. Close the terminal with Control-C to stop the server.

This release is source with a launcher. It is not a standalone Mac app.
The first setup downloads about 700 MB of Python packages, a 75 MB brain pack,
and a 2 MB game character from the pinned upstream example.
The installed environment uses about 2.4 GB. The brain data uses about 206 MB.
Allow at least 5 GB for downloads, caches, builds, and the installed files.
Long recordings need more space.
The first local package install took about nine minutes on the test connection.
Later setup runs use the package cache.

Genesis compiles physics code at first use. The first scene can take a minute or more.
Warm studio starts took about 10 seconds here. The outdoor scene has more geometry.
Physics uses the CPU. BrainCore uses Metal when available.
The single-drone CPU probe was faster than the Metal probe on this Mac.
The [results](RESULTS.md) report the measured loop speed.
The simulation slows on a slower machine. It does not invent brain samples.

## Train and check

```sh
# Train each output mapping from 360 rendered camera samples.
./flypilot.sh train --mode full --samples 360 --seed 2026
./flypilot.sh train --mode simple --samples 360 --seed 2026

# Run six matched controllers on three held-out starts.
./flypilot.sh evaluate --mode full --seconds 20 --seeds 503 607 709
./flypilot.sh evaluate --mode simple --seconds 20 --seeds 503 607 709

# Record a real Full map run and all cell rates.
./flypilot.sh record --mode full --seed 503 --seconds 20 --output runs/demo-full
./flypilot.sh check runs/demo-full

# Run the service, optimization, perception, geometry, and animation tests.
./flypilot.sh test
.venv/bin/python scripts/check_sources.py
```

The training command supports `--epochs`. Its default is 800 gradient updates.
Training changes a small linear output mapping. It keeps the measured wiring fixed.
It keeps the neuron equations fixed. It does not add learning inside BrainCore.
The teacher is a documented camera controller. The trained controller receives calculated rates only.
The lost-target hold gate receives one visibility flag. A contact gate stops motion.
No target coordinates bypass the brain in trained control.

The readout uses left and right LC10a rates and two DNa02 rates in Full map.
LC10a cells also receive the sensory input. This is a small rate readout, not proof
that the full network is required for this task. DNa02 has a smaller fitted contribution.
Simple uses smell-cell rates as a visual proxy. It has no visual or steering channels.
The two modes are trained and evaluated separately.

The checks compare trained weights with their initial random weights, a conventional
camera controller, zeroed rates, swapped left/right rates, and a disabled readout.
All use the same scene sensors, flight controller, starts, and limits.
The camera-controller and disabled-readout tests still calculate the brain for matched telemetry.
See [the methods](METHODS.md) and [the measured results](RESULTS.md).

## Scenes and limits

The outdoor camera renders RGB, a character mask, and depth. The mask gives each
visible character pixel its game object ID. This is a privileged simulator sensor.
It is not a real-world person detector. Lighting affects RGB, but not that ID sensor.
The controller does not use a webcam, identity model, hardware link, or real drone.

The character gait, route, stop, and small contact lean are programmed animation.
After contact, the soldier blends into a standing pose.
The drone approach comes from calculated brain rates and the trained output mapping.
An ellipsoid around the drone checks the actual animated character vertices.
Contact triggers a gentle programmed recoil. It is not a physical injury model.
The scene is a 3D game rendering. Smoke and depth haze are visual effects.
They do not provide a physical smoke sensor. The character and vehicles are game assets.

The drone spans about 0.52 m. Its geometry and dynamics scale from Genesis CF2X.
The larger body is a virtual model. Its coefficients are not calibrated to hardware.
The scene keeps native drone contacts off. A lane guard prevents the drone from
entering buildings or parked cars. A guard event resets the drone and is logged.

The studio keeps the earlier portrait-following task:

```sh
./flypilot.sh run --scene studio
./flypilot.sh record --scene studio --seed 503 --output runs/studio-demo
./flypilot.sh train --scene studio --mode full
./flypilot.sh evaluate --scene studio --mode full
```

## Enhanced render and game map

The live view uses the fast Genesis renderer. For the enhanced recorded view,
install Blender 5.2.1 from [Blender](https://www.blender.org/download/).
It is an optional renderer. The tested Apple Silicon download was about 330 MB.
Its installed app used about 907 MB. Its first Metal render compiled shaders for about two minutes.
Later rendered frames took about two seconds here. The enhanced video is an offline render.

```sh
./flypilot.sh record --mode full --seed 503 --output runs/demo-full
./flypilot.sh render runs/demo-full --output runs/demo-cinematic
```

The render command replays the original inputs and verifies the camera, rates,
positions, and contact. It exports the exact scene geometry and recorded visible poses.
Blender adds lighting, material detail, and smoke. The instrument view keeps the
original sensor camera and brain samples. Model-run time and render time stay separate.
The two videos are `flypilot-cinematic.mp4` and the unobstructed `battle-map.mp4`.

The renderer finds Blender in Applications or on PATH.
Use `--blender /path/to/Blender` for another location.
The scenery-only `battle-map.glb` excludes the Mixamo character.
See [game map notes](GAME_MAP.md) before importing it into an engine.
Local scene caches include the character model. They stay outside Git and release archives.

## Use a local portrait

The public sample is a NASA portrait supplied by scikit-image.
It is a known reference image. The fly model does not detect faces or infer identity.
OpenCV matches the reference against rendered camera pixels.
This release does not claim that it distinguishes people or supports general face recognition.
It does not use a webcam or a real drone.

Put your chosen image in `private/`. Use a clear portrait with visible detail.
Train it before running it:

```sh
./flypilot.sh train --reference private/my-portrait.png --mode full
./flypilot.sh run --reference private/my-portrait.png --mode full
./flypilot.sh record --reference private/my-portrait.png --mode full
```

These commands keep derived weights and recordings local.
Private images and run output are ignored by Git.
The public packaging check accepts only the sample portrait hash.
You must explicitly choose to publish your own image in a later change.

## Physics and permissions

Genesis World 1.4.0 is pinned in `uv.lock`.
The unchanged upstream flight example and route example ran on this Mac.
The route reached all three goals within 10 cm.

The current Genesis docs say drones lack collision checking.
The pinned CPU build stopped a falling drone on a slab in a limited test.
The Metal contact-disabled control fell through it. This does not validate general contacts.
FlyPilot disables native contacts. It uses explicit contact and boundary checks.
Studio furniture and the portrait stand use conservative box guards.
A studio guard event resets the drone. Outdoor character contact ends the run.
Both cameras render the same scene. There is no photographic background substitution.

FlyPilot requests no camera, microphone, screen recording, Accessibility, or login-start permission.
It serves the view on `127.0.0.1`. It does not collect analytics or require an account.
Normal mouse input stays available to other apps.
Setup needs network access. Normal flights use local files after setup.
The launcher and source download are unsigned and not notarized.
macOS may warn about downloaded scripts. Inspect the source and follow Apple's normal
opening controls for a trusted download. Do not disable Gatekeeper.

Raw brain data, environments, caches, and large runs stay outside Git.
The release includes selected public weights and replay evidence.
See [sources and licenses](THIRD_PARTY.md).
