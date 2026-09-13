# Measured results

These tests ran on 2026-09-13. The machine was an Apple M4 Max with 48 GB of memory
and macOS 26.5. Genesis 1.4.0 ran CPU physics. BrainCore used Metal.
The main scene is `battlefield-1`. The optional portrait studio is `studio-1`.
The scenes have different tasks and separate trained weights.

## Battle map

Each controller ran for 20 seconds with seeds 503, 607, and 709.
The soldier left a doorway and followed the programmed pavement route.
All controllers used the same starts, game-camera mask/depth sensors, and flight stabilizer.
Contact is an explicit geometric event. It is not a native impact or injury simulation.

| Controller | Full map contacts | Simple contacts | Full mean center error | Full mean range |
| --- | ---: | ---: | ---: | ---: |
| Trained output map | 3 / 3 | 3 / 3 | 0.287 | 2.48 m |
| Initial random weights | 0 / 3 | 0 / 3 | 0.695 | 11.68 m |
| Conventional camera controller | 3 / 3 | 3 / 3 | 0.179 | 2.43 m |
| Zeroed brain features | 0 / 3 | 0 / 3 | 0.225 | 11.63 m |
| Swapped left/right features | 0 / 3 | 0 / 3 | 0.981 | 9.29 m |
| Disabled output | 0 / 3 | 0 / 3 | 0.121 | 10.91 m |

Full map made contact at 8.20, 8.14, and 8.09 seconds.
Simple made contact at 8.26, 8.10, and 8.14 seconds.
The conventional controller made contact at 8.81, 8.21, and 8.20 seconds.
Trained runs had no boundary resets. Two Simple zero-feature runs reset once each.
Untrained and shuffled runs often lost the character and did not recover.
Every loss interval is saved in the result files.

A small center error does not mean a successful approach. Disabled control kept the
soldier near the image center while staying far away. Post-contact recoil and hold
also affect the full-run center and range metrics. Contact is the primary task measure.
The conventional controller had better mean centering than the trained Full map.

The readout depends on calculated rates: changing or disabling them removed contact
in these matched tests. This does not show that all 166,700 cells are necessary.
The Full map readout includes the stimulated LC10a channel and two DNa02 cells.
The mask is a privileged game sensor. These tests do not measure person recognition
from ordinary photographs or real-world autonomous flight.

Reports: [Full map](provenance/battle-full-results.json) and
[Simple](provenance/battle-simple-results.json).

## Training

Each mode ran 360 camera samples with seed 2026. All samples calculated the selected
brain model. Each mode had 351 visible samples for fitting. The readout used 800
full-batch gradient updates. The brain wiring and neuron equations stayed fixed.

| Mode | Initial mean squared loss | Final loss | Training wall time |
| --- | ---: | ---: | ---: |
| Full map | 1.492039 | 0.010583 | 51.25 s |
| Simple | 1.429558 | 0.011255 | 38.48 s |

The two training jobs ran concurrently. Wall time includes scene setup and sampling.
Weights preserve their initial values, final values, feature scaling, seed, settings,
and learning curve. The teacher is documented in METHODS.md.
The gait, route, contact lean, stop, and flight stabilization are programmed.

## Recorded run and replay

The Full map preview uses seed 503. It records 10.2 seconds of model time.
Contact occurs at 8.20 seconds. The last two seconds show the response and hold.
The recording contains 102 brain updates and all 17,003,400 per-cell rate values.
Its same-Mac replay matched all rate hashes, RGB hashes, game-sensor hashes, inputs,
actions, positions, and contact events. Maximum action and position errors were zero.
The allowed position tolerance was 0.00002 m. Cross-platform bitwise rendering is not promised.

The original instrument recording took 39.20 seconds after scene setup, including
encoding and evidence writing. Its calculation timer was 27.81 seconds.
The video plays at one second per second of model time. It is not a real-time speed claim.
The average Full map evaluation speed was 0.67 times real time. Simple averaged 0.90.
Evaluation jobs ran concurrently with other local checks. These are workload measurements,
not isolated hardware benchmarks.

The enhanced video renders the saved geometry and verified poses with Blender 5.2.1.
It adds ray-traced lighting, material detail, and volume smoke. It preserves the
original sensor camera and calculated brain samples in the instrument view.
Its camera starts wide and moves closer. The 102 world frames took 230.50 seconds to render,
after scene setup. Rendering ran alongside local validation work. Encoding time is separate.
The scenery-only GLB excludes the Mixamo character. The local render cache includes
that character and stays outside Git and the release archives.
Motor and contact sounds are synthesized game effects. They are not measured acoustics.

## Optional portrait studio

Studio training matched 331 of 360 camera samples per mode. It used the known NASA
portrait with OpenCV image matching. Evaluation used different motion, starts,
exposures, and an occlusion from 7.0 to 8.2 seconds. Seeds were 503, 607, and 709.
Success required a detection, center error below 0.15, and range error below 0.35 m
around a 1.8 m setpoint.

| Controller | Full tracking success | Simple tracking success |
| --- | ---: | ---: |
| Trained | 58.3% | 53.7% |
| Initial random weights | 0.0% | 2.2% |
| Conventional | 62.5% | 62.5% |
| Zeroed features | 0.0% | 0.0% |
| Swapped features | 0.0% | 0.0% |
| Disabled | 1.2% | 1.2% |

Trained Full map had a mean range error of 0.329 m and no boundary resets.
Its success after the first five seconds was 70.4%. The conventional controller
reached 74.7% over that period. The known portrait matched on the first clear frame
after the planned occlusion. This is reference-image tracking, not general face recognition.

Reports: [Full map studio](provenance/studio-full-results.json) and
[Simple studio](provenance/studio-simple-results.json).

## Simulator checks

The unchanged upstream hover and route examples ran locally. The route reached all
three goals within 10 cm. The CPU probe processed about 3,935 physics steps per second.
That is a physics-only measure. Rendering and the brain reduce the full loop speed.

A pinned CPU contact probe stopped a falling drone on a slab. The corresponding
contact-disabled test passed through it. This limited result does not establish general
native drone collision support. FlyPilot disables native contacts and logs its own
geometric contact and boundary events.

The service checks cover full cell counts, exact plotted rates, seeded reset,
independent state, restart, shutdown, missing process, and timeout behavior.
Other checks cover optimization, portrait pixels, room guards, animated geometry,
and the game sensor adapter. See the [release validation record](provenance/validation.json) for the completed checks.
