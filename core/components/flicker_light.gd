class_name FlickerLight
extends Node

## Randomly varies the light_energy of a target OmniLight3D for atmosphere.

@export var target_light_path: NodePath = ^""
@export var base_energy: float = 1.35
@export var flicker_amount: float = 0.15
@export var flicker_speed: float = 8.0

var _timer: float = 0.0
var _target: OmniLight3D = null


func _ready() -> void:
	_target = get_node_or_null(target_light_path) as OmniLight3D
	if _target == null:
		push_warning("FlickerLight: no target light found at path ", target_light_path)


func _process(delta: float) -> void:
	if _target == null:
		return
	_timer += delta * flicker_speed
	var noise: float = sin(_timer) + sin(_timer * 2.3) + sin(_timer * 5.7)
	var variation: float = (noise / 3.0) * flicker_amount
	_target.light_energy = base_energy + variation
