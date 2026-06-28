extends Node
## Global spawn placement. Works in ANY scene (not just LevelRoot scenes).

const OVERRIDES_PATH: String = "user://spawn_overrides.json"

var _last_scene_path: String = ""

func _ready() -> void:
	# Wait for initial scene to load then place player
	await get_tree().process_frame
	_place_player()

func _process(_delta: float) -> void:
	# Poll for scene changes since SceneTree has no current_scene_changed signal
	var scene: Node = get_tree().current_scene
	if scene != null:
		var path: String = scene.scene_file_path
		if path != _last_scene_path and not path.is_empty():
			_last_scene_path = path
			_place_player()

func _place_player() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var scene_path: String = scene.scene_file_path
	if scene_path.is_empty():
		return

	var spawn_id: String = GameState.pending_spawn_id
	var spawn: Node3D = _find_spawn(scene, spawn_id)

	# Check for JSON override
	if FileAccess.file_exists(OVERRIDES_PATH):
		var file: FileAccess = FileAccess.open(OVERRIDES_PATH, FileAccess.READ)
		if file != null:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data: Dictionary = json.data as Dictionary
				if data != null and data.has(scene_path):
					var scene_overrides: Dictionary = data[scene_path] as Dictionary
					if scene_overrides != null and scene_overrides.has(spawn_id):
						var pos: Dictionary = scene_overrides[spawn_id] as Dictionary
						if pos != null:
							var new_pos: Vector3 = Vector3(
								pos.get("x", player.global_position.x) as float,
								pos.get("y", player.global_position.y) as float,
								pos.get("z", player.global_position.z) as float
							)
							player.global_position = new_pos
							GameState.pending_spawn_id = "default"
							return

	# Fallback: use scene's SpawnPoints if no override
	if spawn != null:
		player.global_position = spawn.global_position
		player.global_rotation.y = spawn.global_rotation.y

	GameState.pending_spawn_id = "default"

func _find_spawn(scene: Node, spawn_id: String) -> Node3D:
	var spawn_points: Node = scene.get_node_or_null("SpawnPoints")
	if spawn_points == null:
		return null
	for child: Node in spawn_points.get_children():
		if child is SpawnPoint and (child as SpawnPoint).spawn_id == spawn_id:
			return child as Node3D
	# Fallback to default
	for child: Node in spawn_points.get_children():
		if child is SpawnPoint and (child as SpawnPoint).spawn_id == "default":
			return child as Node3D
	return null
