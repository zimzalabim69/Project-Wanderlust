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
	# Guarded with has_singleton() so this never crashes at runtime.
	if Engine.is_editor_hint():
		if has_node("Environment") and Engine.has_singleton(&"EditorInterface"):
			var ei: Object = Engine.get_singleton(&"EditorInterface")
			if ei.has_method("is_plugin_enabled") and ei.call("is_plugin_enabled", "sky_3d"):
				$Environment.queue_free()
				var sky3d: Node = load("res://addons/sky_3d/src/Sky3D.gd").new()
				sky3d.name = "Sky3D"
				add_child(sky3d, true)
				move_child(sky3d, 1)
				sky3d.owner = self
				sky3d.current_time = 10
				sky3d.enable_editor_time = false
		return  # Don't run runtime logic in editor.

	# Capture the intended spawn id before SpawnManager consumes it.
	var pending_spawn_id: String = GameState.pending_spawn_id

	# Force Full/Game collision mode (3) so the entire terrain has collision
	# from startup. Dynamic mode only generates collision around the camera and
	# can miss the player's spawn area, causing fall-through.
	if terrain != null:
		terrain.collision_mode = 3  # Terrain3DCollision.FULL_GAME

	# Terrain3D needs a couple of physics frames to initialise its data and
	# build collision. Wait before placing the player.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_snap_spawn_points_to_terrain()
	_attach_snow_to_player()
	_tag_terrain_surface()
	_place_player_at_spawn(pending_spawn_id)
	_add_safety_floor()


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
		var terrain_data: Object = terrain.get("data")
		var terrain_y: float = -9999.0
		if terrain_data != null and terrain_data.has_method("get_height"):
			terrain_y = terrain_data.call("get_height", Vector3(pos.x, 0.0, pos.z))
		if terrain_y > -9999.0:  # Terrain3D returns -INF for out-of-bounds.
			marker.global_position = Vector3(pos.x, terrain_y + SPAWN_Y_OFFSET, pos.z)


## Adds the surface_snow group to the Terrain3D collision body so the player
## footstep system can identify the surface type (snow = outdoor terrain).
func _tag_terrain_surface() -> void:
	if terrain == null:
		return
	# Terrain3D exposes its StaticBody3D via get_collision_static().
	# Fall back to searching children if the method isn't present.
	if terrain.has_method("get_collision_static"):
		var body: Node = terrain.call("get_collision_static")
		if body != null:
			body.add_to_group("surface_snow")
			return
	# Fallback: tag any StaticBody3D child of the Terrain3D node.
	for child: Node in terrain.get_children():
		if child is StaticBody3D:
			child.add_to_group("surface_snow")


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


## After snapping spawn points, move the player to the snapped spawn so the
## player never starts at the placeholder Y (the SpawnManager runs before the
## terrain snap and would place the player at the unsnapped height otherwise).
func _place_player_at_spawn(spawn_id: String) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var spawn_points: Node = get_node_or_null("SpawnPoints")
	if spawn_points == null:
		return

	var target: Node3D = null
	for child: Node in spawn_points.get_children():
		if child is SpawnPoint and (child as SpawnPoint).spawn_id == spawn_id:
			target = child as Node3D
			break

	# Fallback to default if the requested id is missing.
	if target == null:
		for child: Node in spawn_points.get_children():
			if child is SpawnPoint and (child as SpawnPoint).spawn_id == "default":
				target = child as Node3D
				break

	if target != null:
		player.global_position = target.global_position
		player.global_rotation.y = target.global_rotation.y


## Adds a large invisible floor under the spawn area as a safety net. If
## Terrain3D's collision hasn't fully initialised when the player spawns,
## this prevents them from falling through the world.
func _add_safety_floor() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "SafetyFloor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 1
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	# 2000x2000 area centered on spawn, 0.5 thick at y=-0.25 (top at y=0)
	shape.size = Vector3(2000.0, 0.5, 2000.0)
	col.shape = shape
	floor_body.add_child(col)
	floor_body.global_position = Vector3(960.0, -0.25, -1988.0)
	add_child(floor_body)
