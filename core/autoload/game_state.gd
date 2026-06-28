extends Node
## Tracks cross-scene state: spawn targets, story flags, and level metadata.

signal flag_changed(flag_id: String, value: bool)

var pending_spawn_id: String = "default"
var flags: Dictionary = {}


func set_flag(flag_id: String, value: bool = true) -> void:
	flags[flag_id] = value
	flag_changed.emit(flag_id, value)


func has_flag(flag_id: String) -> bool:
	return flags.get(flag_id, false)


func clear_flag(flag_id: String) -> void:
	flags.erase(flag_id)
	flag_changed.emit(flag_id, false)


func reset() -> void:
	flags.clear()
	pending_spawn_id = "default"
