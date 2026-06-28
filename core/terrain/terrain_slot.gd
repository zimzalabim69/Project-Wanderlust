extends Node3D
## Parent for imported terrain meshes (Blender GLB/FBX or Terrain3D node).
## Add collision: include it in the export, or add a MeshInstance3D sibling with StaticBody3D.

@export var notes: String = "Instance terrain under this node. Replace Floor/SnowGround blockouts when ready."
