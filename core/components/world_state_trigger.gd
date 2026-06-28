class_name WorldStateTrigger
extends Node

## Monitors GameState flags and toggles target nodes based on conditions.

@export var required_flag: String = ""
@export var invert: bool = false
@export var target_nodes: Array[NodePath] = []
@export var enable_on_match: bool = true

func _ready() -> void:
	GameState.flag_changed.connect(_on_flag_changed)
	_check_state()

func _on_flag_changed(flag_id: String, _value: bool) -> void:
	if flag_id == required_flag:
		_check_state()

func _check_state() -> void:
	if required_flag.is_empty():
		return
	var has: bool = GameState.has_flag(required_flag)
	var should_enable: bool = has if not invert else not has
	for path in target_nodes:
		var node: Node = get_node_or_null(path)
		if node == null:
			continue
		if node.has_method("set_enabled"):
			node.set_enabled(should_enable if enable_on_match else not should_enable)
		elif node is CollisionShape3D or node is CollisionPolygon3D:
			node.disabled = not (should_enable if enable_on_match else not should_enable)
		elif node.has_method("set_process"):
			node.set_process(should_enable if enable_on_match else not should_enable)
			node.set_physics_process(should_enable if enable_on_match else not should_enable)
		else:
			node.visible = should_enable if enable_on_match else not should_enable
