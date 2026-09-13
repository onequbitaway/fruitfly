# Calculation and control

## One model tick

1. Render the drone camera at simulation time t.
2. Read the camera observation for the selected scene.
3. Convert the observation to documented input rates.
4. Advance the Swift BrainCore service by 100 ms.
5. Map calculated cell rates to forward speed and yaw rate.
6. Apply the common command filter and hold gates.
7. Run ten physics steps of 10 ms. Set propeller speeds once per step.

Each brain update runs 500 steps of 0.2 ms. All cells run in each selected mode.
The next camera uses the new physical state. Wall time does not create model samples.
Images show time t. The reported brain and flight state show t + 0.1 s.
The path uses saved physical positions. Outdoor drone geometry is shown at its actual scale.
The studio adds a small marker around its much smaller drone.

## Battle map

The 640 × 480 camera has a 65-degree field of view. It renders RGB, depth,
and a character ID mask. The mask is a privileged game sensor. It does not recognize
people from RGB. Horizontal error comes from the mean position of visible mask pixels.
Range is the median positive camera depth at those pixels. A minimum of 12 pixels is required.
There is no real-world detector or hardware control interface.

Full map stimulates metadata-selected LC10a cells. Simple uses odor cells as a visual proxy.
The sensory mapping is programmed:

```text
base_hz = 70 + 12 * clip(camera_depth_m, 0, 10)
left_hz = clip(base_hz - 45 * horizontal_error, 0, 200)
right_hz = clip(base_hz + 45 * horizontal_error, 0, 200)
```

Error is relative to half the image width. Positive means image right.
When the character is lost, both rates are zero. The hold gate commands zero motion.
The trained output receives calculated rates only. It does not receive target coordinates.
The scene uses ground truth for character animation, scoring, and contact checks.
The game renderer also uses it to produce the explicitly privileged mask and depth sensors.

The drone spans about 0.52 m. Genesis CF2X geometry is scaled by five.
Mass scales with length cubed. Inertia scales with length to the fifth power.
Thrust and torque coefficients scale with length to the fourth and fifth powers.
The resulting mass is 3.375 kg. Hover speed is about 6,474 RPM.
This is geometric scaling for a virtual drone. It is not a calibrated hardware model.
The common stabilizer has feedback gains scaled for that body.

Native contacts are disabled. At every 10 ms step, an ellipsoid around the drone
checks the animated character vertices. Its radii are 0.265, 0.275, and 0.11 m.
This is an approximate geometric event, not a continuous rigid-body contact solver.
A contact stops the character route. A 0.40 s transition blends the gait into the Idle clip
and adds a small programmed lean. The drone gets a 0.6 m/s recoil away from the contact point.
The stabilizer then holds it.
The live view pauses two seconds later. The recording includes those two seconds.
Boundary guards keep the drone in the pavement lane and away from cars and buildings.
They log and reset an out-of-lane flight. Vehicles are static scenery.

## Training

Each mode has its own output weights. Full map reads left and right LC10a rates
and left and right DNa02 rates. Simple reads two odor-channel means.
All other cells still run. This small readout does not show that the full network is necessary.
LC10a is also the stimulated sensory channel. It contributes more than DNa02 in these fits.

Seed 2026 selects 360 rendered camera poses. Outdoors, ranges span 0.65–8.5 m,
lateral offsets span ±1.5 m, and yaw spans ±0.35 rad. Exposure spans 0.96–1.15.
The training character follows a different path. Brain state resets every 40 samples.
Lost samples still run the brain. Only visible samples supply supervised labels.
See the checkpoint for the measured sample count and learning curve.

The outdoor teacher is `forward = min(1.9, 0.65 + 0.24 * depth)` and
`yaw = clip(-1.1 * error, -0.65, 0.65)`. The teacher is a programmed game controller.
It supplies imitation labels. Trained flights do not run it to choose commands.

The linear mapping standardizes its features and includes a bias. Initial Gaussian
weights use seed 2026 and a standard deviation of 0.04. Optimization uses 800 full-batch
gradient updates, a 0.04 learning rate, and a 0.001 L2 penalty. Bias has no penalty.
The loss is mean squared error. Outdoor outputs are limited to -0.35–1.9 m/s and ±0.65 rad/s.
The command filter uses 60% of the old command and 40% of the new command.
A lost target or completed contact commands zero motion.

This is optimization of the output mapping. It is not reinforcement learning or
synaptic plasticity. The brain equations and measured source graph stay fixed.
The character route, gait, contact lean, and flight stabilization are programmed.

## Evaluation

The matched evaluation uses seeds 503, 607, and 709. Each controller gets 20 s.
The outdoor character leaves an open doorway, turns, and walks down the pavement.
Starts and yaw vary. Exposure spans 0.82–1.02. RGB lighting, smoke, and haze effects do not affect the privileged ID mask.
The map has broken buildings and a clear pavement lane through the debris.
There is no planned outdoor occlusion. The studio separately tests occlusion and recovery.
This small suite does not establish general visual recognition or autonomous flight.

All six controllers share sensors, physics, stabilization, starts, and output limits.
Untrained control uses the saved initial weights with the same feature scaling.
Zero control replaces the readout features with zero. Shuffled control swaps hemispheres.
Disabled control commands zero forward speed and turn. Conventional control reads camera
measurements directly. All six still calculate brain telemetry for a matched comparison.

Outdoor success means the geometric contact event occurred within 20 s. Center error is
absolute normalized horizontal error. Lost frames count as 1. Outdoor range is physical
center-to-center distance. It is not an error around the studio's 1.8 m following setpoint.
Outdoor `trackingSuccess` means visible and center error below 0.15. It is only a centering
metric. It includes the post-contact hold and does not replace the contact metric.
The `steady` metrics start at 5 s. All loss episodes and boundary events are saved.
The selected video and all evaluation outcomes are reported in RESULTS.md.

## Optional studio

The studio uses the unchanged public NASA portrait on a movable 0.8 m square panel.
OpenCV ORB matches it in the 480 × 360 RGB camera. A planar pose estimate supplies range.
It does not infer identity or perform general face recognition.
The input base rate is `100 + 40 * clip((range - 1.8) / 2, -1, 1)`.
The same ±45 Hz horizontal offset supplies left and right rates.
The teacher is `forward = 0.65 * (range - 1.8)` and `yaw = -1.1 * error`, before limits.
Studio output limits are -0.35–0.65 m/s and ±0.65 rad/s.

Studio training uses 360 poses, range 1.1–3.7 m, lateral offsets ±1.15 m, yaw ±0.35 rad,
and a 0.7 s occlusion. The published studio runs matched 331 samples per mode.
Evaluation uses different paths, starts, exposure 0.72–0.94, and an occlusion from 7.0–8.2 s.
Studio success requires detection, center error below 0.15, and range error below 0.35 m.
The public studio weights and earlier studio results remain available separately.

## Evidence and replay

Each run saves inputs, observations, actions, ten motor commands per model tick,
physical state, events, feature rates, plot rates, and a SHA-256 hash of all cell rates.
Rate hashes cover little-endian Float32 data in metadata order. Recordings also save all
rates in gzip, camera PNGs, and outdoor mask/depth arrays. Checkpoints include initial weights,
trained weights, feature scaling, seeds, settings, asset hashes, and the learning curve.

MP4 output is 1920 × 1080 at ten frames per second. One second of video equals one second
of simulation. It records actual calculations. It does not claim real-time performance.
Wall time includes encoding and evidence writing. The calculation-only timer is separate.

`check` verifies saved rate, RGB, and game-sensor hashes. It reruns sensors, BrainCore,
the mapping, and physics. The same-Mac action and position tolerance is 0.00002.
Brain rate hashes must match exactly. Cross-platform bitwise rendering is not promised.
`check --brain-only` verifies the solver from saved inputs without rebuilding the scene.

The service uses versioned JSON lines on stdin and stdout. Metadata sends cell positions
once, with their original indices. Logs go to stderr. The client sets a bounded response wait.
A missing service or timeout stops the flight. Restart resets the entire run.
The local HTTP view requires a same-origin header for mutations. It has no upload endpoint.
