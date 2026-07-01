extends Node3D
class_name LevelRoot
## Standard level container. Keep imported art under Terrain / Structures / Props / Vehicles.

const SPAWN_OVERRIDES_PATH: String = "user://spawn_overrides.json"

@export var level_config: LevelConfig

@onready var terrain: Node3D = $Terrain
@onready var structures: Node3D = $Structures
@onready var props: Node3D = $Props
@onready var vehicles: Node3D = $Vehicles
@onready var lighting: Node3D = $Lighting
@onready var audio_zones: Node3D = $AudioZones
@onready var spawn_points: Node3D = $SpawnPoints
@onready var triggers: Node3D = $Triggers


func _ready() -> void:
	_apply_level_config()
	# Spawn placement is handled globally by SpawnManager autoload


func get_spawn_point(spawn_id: String) -> SpawnPoint:
	for child: Node in spawn_points.get_children():
		if child is SpawnPoint and (child as SpawnPoint).spawn_id == spawn_id:
			return child as SpawnPoint
	return null


func _apply_level_config() -> void:
	if level_config == null:
		return
	if level_config.ambient_loop:
		AudioManager.play_ambient(level_config.ambient_loop, false)
	# Wire up the music loop (was defined in LevelConfig but never called).
	AudioManager.play_music(level_config.music_loop, false)
	AudioManager.set_outdoor_mix(level_config.use_outdoor_mix)


func _apply_spawn_overrides() -> void:
	if not FileAccess.file_exists(SPAWN_OVERRIDES_PATH):
		return
	var file: FileAccess = FileAccess.open(SPAWN_OVERRIDES_PATH, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data as Dictionary
	if data == null:
		return

	var scene_path: String = scene_file_path
	if not data.has(scene_path):
		return

	var scene_overrides: Dictionary = data[scene_path] as Dictionary
	if scene_overrides == null:
		return

	for spawn_id: Variant in scene_overrides.keys():
		if not spawn_id is String:
			continue
		var spawn: SpawnPoint = get_spawn_point(spawn_id as String)
		if spawn == null:
			continue
		var pos: Dictionary = scene_overrides[spawn_id] as Dictionary
		if pos == null:
			continue
		var x: float = pos.get("x", spawn.global_position.x) as float
		var y: float = pos.get("y", spawn.global_position.y) as float
		var z: float = pos.get("z", spawn.global_position.z) as float
		spawn.global_position = Vector3(x, y, z)


func _place_player_at_spawn() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var spawn_id: String = GameState.pending_spawn_id
	var spawn: SpawnPoint = get_spawn_point(spawn_id)
	if spawn == null:
		spawn = get_spawn_point("default")

	if spawn:
		player.global_transform = spawn.global_transform
		player.global_rotation.y = spawn.global_rotation.y

	GameState.pending_spawn_id = "default"
