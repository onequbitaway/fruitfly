# Sources and licenses

FlyPilot code uses the repository MIT license.
The fixed brain model uses BrainCore from `../full-map` without changes.
See [the full model credits](../full-map/THIRD_PARTY.md).
MaleCNS data retains CC BY 4.0. Google Research, HHMI Janelia, and their
collaborators produced the source wiring. Shiu et al. (2024) supplied the
model equations. These credits do not imply endorsement.

## Simulator

[Genesis World](https://github.com/Genesis-Embodied-AI/genesis-world) 1.4.0
uses Apache 2.0. The complete license is in `vendor/GENESIS-LICENSE`.
The unchanged upstream examples and PID controller are in `vendor`.
`vendor/UPSTREAM.json` records the commit and file hashes.
FlyPilot loads the bundled Crazyflie CF2X asset from the pinned Genesis wheel.
The package provides Apache 2.0 and no separate license file in its drone asset folder.
The URDF shares parameters and geometry with the MIT
[gym-pybullet-drones](https://github.com/learnsyslab/gym-pybullet-drones) assets.
Its license is also preserved in `vendor/GYM-PYBULLET-DRONES-LICENSE`.
The FlyPilot source and evidence archives do not bundle the simulator's mesh files.
The dependency lock pins the Python packages. Setup downloads their license files
with each installed distribution. `provenance/dependency-licenses.json` lists them.

## Portrait and perception

The public sample is a NASA photograph of astronaut Eileen Collins.
It comes from [scikit-image's astronaut sample](https://scikit-image.org/docs/stable/api/skimage.data.html#skimage.data.astronaut).
The source states that it is in the public domain with no known copyright restrictions.
The original NASA image is linked in that page. The complete sample portrait is used.
No endorsement is implied. The image credit supplies the name. Software does not infer identity.

OpenCV uses Apache 2.0. Its ORB features and image matching find the reference
portrait in rendered camera pixels. No downloaded face model is used.
This is reference-image tracking. It is not general face recognition.
Private reference images belong in the ignored `private` folder.
The test camera fixture is a Genesis rendering of this public portrait and the coded room.

NumPy supplies the output-mapping optimization. It uses BSD 3-Clause.
Pillow uses the HPND license. It draws the recorded instrument view.
ImageIO uses BSD 2-Clause. imageio-ffmpeg uses BSD 2-Clause and bundles FFmpeg.
The recording tool invokes that FFmpeg binary. The release does not bundle it.

## Studio materials and models

Poly Haven supplies Potted Plant 01, Modern Wooden Cabinet, and Desk Lamp Arm 01.
The assets use [CC0 1.0](https://polyhaven.com/license).
The original glTF files and 1K material images are included without changes.
`assets/POLYHAVEN.json` preserves source URLs, authors, licenses, and file hashes.
FlyPilot places and scales the models in the coded room.

The oak floor image was generated with OpenAI image generation for this project.
`assets/MATERIALS.json` records its purpose, prompt, and hash.
It is a surface texture. The room, sunlight, camera views, and flight are rendered in Genesis.
The remaining room geometry is original project code.

## Battle map assets

The game character is the Mixamo soldier in the
[three.js animation example](https://threejs.org/examples/webgl_animation_skinning_blending.html).
[Adobe's Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)
describes royalty-free use of its characters and animations in games and films.
This content is not CC0 or part of the project's MIT license.
The source and evidence archives do not bundle the raw character or animation file.
Setup fetches the pinned example from its upstream source. Its URL and checksum are
in `assets/Soldier/SOURCE.json`. The model is kept outside Git.
The runtime scales it to 1.76 m, preserves its textures, plays its Walk and Idle clips,
and adds a small programmed contact lean. No endorsement is implied.

The [Khronos sample collection](https://github.com/KhronosGroup/glTF-Sample-Assets)
supplies ToyCar by Guido Odendahl and Eric Chadwick under CC0.
The runtime removes the display cloth and glass, deforms the shell, changes its material,
and scales it to represent a burned vehicle. The source GLB stays unchanged.
`assets/ToyCar/SOURCE.md` preserves the upstream credit.
`assets/KHRONOS.json` records the source URL and hash.

Poly Haven supplies Asphalt 02, Aerial Grass Rock, Brick Wall 001, Concrete Pavement,
Rubble, Broken Wall, Concrete Debris, Concrete Wall 005, and Concrete Road Barrier.
These surface maps and the scanned barrier use CC0. Original files, authors, and hashes
are in `assets/POLYHAVEN.json`. `vendor/CC0-LICENSE` preserves the complete license.
Terrain, damaged buildings, openings, exposed floors, steel, road craters, debris placement,
and the drone shell are original geometry. The drone uses the pinned Genesis CF2X asset
at a larger virtual scale. Programmed smoke and haze are original visual effects.

## Optional offline renderer

[Blender](https://www.blender.org/) 5.2.1 LTS supplies the Cycles renderer.
Blender uses the GNU GPL. Its license is preserved in `vendor/BLENDER-GPL-LICENSE`.
The app stays outside Git and the release archives. `provenance/blender.json`
records the tested download and checksum. Each Blender download also includes
its dependency licenses. Rendered output retains the source assets' terms.
