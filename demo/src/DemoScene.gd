@tool
extends Node
## Overworld scene controller. Manages Terrain3D and environment setup.
##
## At runtime, snaps all SpawnPoint nodes to the actual Terrain3D surface so
## placeholder Y values never strand the player underground or floating.
## The Snowfall particles are re-parented to the player so snow always falls
## around the camera regardless of how far the player has moved.

const SPAWN_Y_OFFSET: float = 1.2   # metres above terrain surface (player half-height)
const SNOW_PARENT_PATH: NodePath = ^"../Snowfall"  # relative to DemoScene root

@onready var terrain: Terrain3D = find_child("Terrain3D")


func _ready() -> void:
	# Sky3D addon integration (editor only).
	if Engine.is_editor_hint() and has_node("Environment") and \
		Engine.get_singleton(&"EditorInterface").is_plugin_enabled("sky_3d"):
			$Environment.queue_free()
			var sky3d: Node = load("res://addons/sky_3d/src/Sky3D.gd").new()
			sky3d.name = "Sky3D"
			add_child(sky3d, true)
			move_child(sky3d, 1)
			sky3d.owner = self
			sky3d.current_time = 10
			sky3d.enable_editor_time = false
		return  # Don't run runtime logic in editor.

	# Terrain3D needs one physics frame to initialise its collision before we
	# can call get_height(), so defer spawn snapping.
	await get_tree().physics_frame
	_snap_spawn_points_to_terrain()
	_attach_snow_to_player()


## Reads each SpawnPoint's XZ position, queries Terrain3D for the actual height,
## and raises the Y to sit SPAWN_Y_OFFSET above the surface.
func _snap_spawn_points_to_terrain() -> void:
	if terrain == null:
		push_warning("DemoScene: no Terrain3D found — skipping spawn height snap.")
		return

	var spawn_root: Node = get_node_or_null("SpawnPoints")
	if spawn_root == null:
		return

	for child: Node in spawn_root.get_children():
		if not child is Marker3D:
			continue
		var marker: Marker3D = child as Marker3D
		var pos: Vector3 = marker.global_position
		var terrain_y: float = terrain.get_height(Vector2(pos.x, pos.z))
		if terrain_y > -9999.0:  # Terrain3D returns -INF for out-of-bounds.
			marker.global_position = Vector3(pos.x, terrain_y + SPAWN_Y_OFFSET, pos.z)


## Re-parents the Snowfall GPUParticles3D nodes to the player so snow always
## falls around the camera no matter how far the player has travelled.
func _attach_snow_to_player() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	for snow_name: String in ["Snowfall", "Snowfall2"]:
		var snow: Node3D = get_node_or_null(snow_name) as Node3D
		if snow == null:
			continue
		var old_pos: Vector3 = snow.global_position
		snow.reparent(player, false)
		# Keep snow centred above and around the player, not offset to world origin.
		snow.position = Vector3(0.0, 15.0, 0.0)

		
