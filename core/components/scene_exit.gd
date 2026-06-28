extends Area3D
## Doorways and level transitions. Uses fade + spawn id from GameState.

@export_file("*.tscn") var target_scene: String = "res://scenes/town.tscn"
@export var target_spawn_id: String = "default"
@export var fade_seconds: float = 0.6
@export var require_player_group: bool = true

var _triggered: bool = false
const TRIGGER_TIMEOUT: float = 2.0


func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 1


func _on_body_entered(body: Node3D) -> void:
	print("SceneExit: body entered: ", body.name, " group=player: ", body.is_in_group("player"))
	if _triggered:
		print("SceneExit: already triggered, ignoring.")
		return
	if require_player_group and not body.is_in_group("player"):
		print("SceneExit: body not in player group, ignoring.")
		return
	print("SceneExit: transitioning to ", target_scene)
	_triggered = true
	SceneTransition.change_scene(target_scene, target_spawn_id, fade_seconds)
	await get_tree().create_timer(TRIGGER_TIMEOUT).timeout
	_triggered = false
