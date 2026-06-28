extends Area3D
## Overrides outdoor low-pass mix while the player is inside. Size with a CollisionShape3D child.

@export var outdoor_mix: bool = false
@export var ambient_override: AudioStream
@export var monitor_player_group: bool = true

var _players_inside: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 1


func _on_body_entered(body: Node3D) -> void:
	if monitor_player_group and not body.is_in_group("player"):
		return
	_players_inside += 1
	if _players_inside == 1:
		_apply_zone()


func _on_body_exited(body: Node3D) -> void:
	if monitor_player_group and not body.is_in_group("player"):
		return
	_players_inside = max(_players_inside - 1, 0)
	if _players_inside == 0:
		_clear_zone()


func _apply_zone() -> void:
	AudioManager.set_outdoor_mix(outdoor_mix)
	if ambient_override:
		AudioManager.play_ambient(ambient_override)


func _clear_zone() -> void:
	var level: LevelRoot = _find_level_root()
	if level and level.level_config:
		AudioManager.set_outdoor_mix(level.level_config.use_outdoor_mix)
		if level.level_config.ambient_loop:
			AudioManager.play_ambient(level.level_config.ambient_loop, false)


func _find_level_root() -> LevelRoot:
	var node: Node = self
	while node:
		if node is LevelRoot:
			return node as LevelRoot
		node = node.get_parent()
	return null
