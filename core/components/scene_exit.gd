extends Area3D
## Doorways and level transitions. Uses fade + spawn id from GameState.
##
## Double-fire prevention: monitoring is disabled the instant the trigger fires.
## The SceneTransition autoload also has its own _busy guard as a second layer.

@export_file("*.tscn") var target_scene: String = "res://scenes/town.tscn"
@export var target_spawn_id: String = "default"
@export var fade_seconds: float = 0.6
@export var require_player_group: bool = true


func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 1


func _on_body_entered(body: Node3D) -> void:
	if not monitoring:
		return
	if require_player_group and not body.is_in_group("player"):
		return
	# Disable immediately — any further overlaps this frame are ignored.
	monitoring = false
	SceneTransition.change_scene(target_scene, target_spawn_id, fade_seconds)
