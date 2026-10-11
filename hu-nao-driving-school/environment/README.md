# School Corner environment

A self-contained visual-only Godot 4 environment. No gameplay, physics, input, multiplayer or imported third-party scene models.

## Instantiate

```gdscript
var school = preload("res://environment/environment_scene.tscn").instantiate()
add_child(school)
```

Or create `preload("res://environment/SchoolCorner.gd").new()`. Geometry is built once in `_ready()`. The public `build()` method is available for a detached instance that needs to be inspected before entering the scene tree; do not call it again on an already built instance.

The parent owns WorldEnvironment, lights and cameras. All file dependencies are inside `environment/`: three small PNG signage assets and three original shaders. No font or addon installation is needed.

## Composition and scale

- One unit is one metre; ground top is y=0
- Hero car bay is x=-2.35 to 2.35, z=-2.95 to 3.55
- Main sign faces +Z, around (-3.05,3.03,-6.05)
- Rear wall is at z=-6.33; entry portal is x=2.93 to 8.45
- Visible school architecture runs about x=-10.4 to 9.1, z=-11 to 1.1
- Trees extend to roughly y=6.8 and x=12
- An intentionally oversized flat asphalt surface prevents a diorama edge appearing near the camera
- Suggested hero camera: (8.5,5.1,11), aim at (0,1,-0.5), 43–50-degree FOV; tighten framing after placing the actual car
- Suggested overview: (10.7,8.3,17.3), aim at (-0.3,1.5,-3.0)

## Art contents

Warm textured plaster, bevelled stone plinths and coping, inset wall panels, layered ceramic sign roof, framed Chinese enamel signage, an open slatted entry portal, framed lanterns and service box, planter beds, smooth branched trees with individually modelled fine leaf blades, rounded shrubs, stones, slatted bench, detailed cones, capped bollards, drainage grille, cream training markings and Chinese road stencil.

The palette is restrained warm cream, jade/olive, natural wood and muted orange. Foliage uses shared original leaf meshes and subtle vertex tone variation. Leaves, road aggregate and plaster grain remain gentle enough for a toon-oriented lighting treatment.

## Validation and interchange

Tested by constructing all 703 visual nodes under Godot 4.6.3 headless without script/runtime errors. Actual Godot viewport rendering was unavailable in this execution environment; no Godot screenshot is claimed.

`SchoolCorner.glb` is an export of the exact generated scene geometry, embedded signage and PBR-compatible materials for DCC previews. Custom Godot shader materials become equivalent flat-color PBR approximations in that export; procedural grain is not represented. `export_environment.gd` reproduces it:

```sh
godot --headless --path . --script environment/export_environment.gd
```

The correct 4.6 export API is `GLTFDocument.write_to_filesystem`. The GLB is optional: the live Godot scene builds from `SchoolCorner.gd`, not from the GLB.
