# Use the battle map in a game

`battle-map.glb` contains the scenery. It has damaged buildings, open doorways,
exposed floors and steel, rubble, road craters, burned cars, and concrete barriers.
The export uses metres. GLB export converts the native Z-up scene to the standard Y-up axes.
The map uses credited CC0 assets and original project geometry. See THIRD_PARTY.md.

Import the GLB with your game engine's normal glTF importer.
Add collision shapes for your game. The scenery export does not supply a collision system.
Add your character and gameplay rules. The raw Mixamo character is not in this file.
Add engine-specific smoke and lighting. GLB does not carry the Blender volume shaders.
The Python source contains the original scene layout. The Blender script contains
its enhanced lighting and smoke settings.

In the source simulation, the doorway is at x=7 m, y=4.65 m.
The pavement is at z=0.13 m. The programmed character starts at x=7 m, y=4.34 m.
These coordinates use the native Z-up axes. The drone holds about z=1.2 m.
`OutdoorWorld.target_at` defines the game character route.

The live experiment uses a rendered character ID mask and depth as game sensors.
The fly model does not recognize a person. The output map reads calculated neuron rates.
This release does not include an Unreal, Unity, or Godot integration plugin.

The GLB keeps image materials and a dark base color on the vehicles.
Procedural soot, smoke, haze, and the Cycles lighting are specific to the rendered video.
Recreate those effects in your engine. Optimize meshes and add collision shapes before play.
