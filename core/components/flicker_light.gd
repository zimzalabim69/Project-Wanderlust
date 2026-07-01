class_name FlickerLight
extends Node
## Atmospheric light flicker — simulates failing fluorescents, loose wiring,
## and ageing tungsten bulbs. Supports OmniLight3D and SpotLight3D.
##
## Flicker modes:
##   SMOOTH  — gentle sinusoidal sway (warm incandescent feel)
##   HARSH   — rapid random spikes (fluorescent / failing tube)
##   DROPOUT — SMOOTH base with occasional full-off events (loose wiring)

enum FlickerMode { SMOOTH, HARSH, DROPOUT }

@export var target_light_path: NodePath = ^""
@export var base_energy: float = 1.35
@export var flicker_amount: float = 0.15
@export var flicker_speed: float = 8.0
@export var mode: FlickerMode = FlickerMode.SMOOTH

# DROPOUT / HARSH parameters.
@export var dropout_chance: float = 0.004   # probability per frame of a dropout event
@export var dropout_duration_min: float = 0.04
@export var dropout_duration_max: float = 0.28
@export var harsh_noise_scale: float = 18.0  # HARSH mode frequency multiplier

var _timer: float = 0.0
var _target_light: Light3D = null
var _dropout_timer: float = 0.0   # > 0 while in a dropout event
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var node: Node = get_node_or_null(target_light_path)
	if node is Light3D:
		_target_light = node as Light3D
	else:
		# Auto-detect: look for a Light3D sibling/child if no path set.
		var parent: Node = get_parent()
		if parent is Light3D:
			_target_light = parent as Light3D
		else:
			for child: Node in parent.get_children():
				if child is Light3D:
					_target_light = child as Light3D
					break
	if _target_light == null:
		push_warning("FlickerLight: no Light3D found. Set target_light_path.")


func _process(delta: float) -> void:
	if _target_light == null:
		return

	_timer += delta

	# Handle dropout.
	if _dropout_timer > 0.0:
		_dropout_timer -= delta
		_target_light.light_energy = 0.0
		return

	# Roll for a new dropout (DROPOUT mode only).
	if mode == FlickerMode.DROPOUT and _rng.randf() < dropout_chance:
		_dropout_timer = _rng.randf_range(dropout_duration_min, dropout_duration_max)
		return

	# Compute base flicker.
	var energy: float = base_energy

	match mode:
		FlickerMode.SMOOTH:
			var noise: float = sin(_timer * flicker_speed) \
				+ sin(_timer * flicker_speed * 2.3) \
				+ sin(_timer * flicker_speed * 5.7)
			energy += (noise / 3.0) * flicker_amount

		FlickerMode.HARSH:
			# High-frequency pseudo-random using multiple primes.
			var t: float = _timer * harsh_noise_scale
			var noise: float = sin(t * 1.1) * sin(t * 3.7) * sin(t * 7.3)
			energy += noise * flicker_amount
			# Additional spike: occasionally lurch to near-off.
			if _rng.randf() < 0.02:
				energy *= _rng.randf_range(0.1, 0.5)

		FlickerMode.DROPOUT:
			var noise: float = sin(_timer * flicker_speed) \
				+ sin(_timer * flicker_speed * 2.3)
			energy += (noise / 2.0) * flicker_amount

	_target_light.light_energy = maxf(0.0, energy)
