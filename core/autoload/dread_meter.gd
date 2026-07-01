extends Node
## DreadMeter — tracks the player's "cozy dread" level (0.0 = calm, 1.0 = peak).
##
## Dread rises when the player is:
##   • Outdoors (AudioManager outdoor mix active)
##   • Far from any light source or structure
##   • Moving away from spawn
##   • Standing still in darkness for a long time
##
## Dread falls when the player is:
##   • Indoors
##   • Near warm lights / spawn points
##   • Running (they're acting, not waiting)
##
## The value is fed into AudioManager.set_dread() each frame to blend the
## tension music layer. It also drives subtle fog and flashlight feedback
## (optional — hooked via signal so other systems can subscribe).

signal dread_changed(value: float)

const DREAD_RISE_RATE:     float = 0.008   # per second outdoors, far from safety
const DREAD_FALL_RATE:     float = 0.015   # per second indoors / near safety
const DREAD_DISTANCE_SAFE: float = 20.0    # metres from spawn to feel "safe"
const DREAD_DISTANCE_MAX:  float = 120.0   # distance for maximum dread contribution
const STILLNESS_DREAD_RATE: float = 0.003  # extra dread per second when standing still
const SPRINT_DREAD_BONUS:   float = -0.004 # dread falls faster when sprinting

var dread: float = 0.0

var _player: Node3D = null
var _safe_position: Vector3 = Vector3.ZERO   # last known spawn position
var _still_timer: float = 0.0
var _last_player_pos: Vector3 = Vector3.ZERO
var _poll_timer: float = 0.0
const POLL_INTERVAL: float = 0.5            # re-find player every 0.5s


func _ready() -> void:
	# Run even when paused so dread state persists across pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = POLL_INTERVAL
		_player = get_tree().get_first_node_in_group("player") as Node3D

	if _player == null:
		return

	var outdoor: bool = AudioManager.is_outdoor_mix_enabled()
	var player_pos: Vector3 = _player.global_position

	# -- Stillness tracking --
	var moved: float = player_pos.distance_to(_last_player_pos)
	_last_player_pos = player_pos
	if moved < 0.05:
		_still_timer += delta
	else:
		_still_timer = 0.0

	# -- Safe distance from spawn --
	var dist_from_safe: float = player_pos.distance_to(_safe_position)
	var dist_factor: float = clampf(
		(dist_from_safe - DREAD_DISTANCE_SAFE) / (DREAD_DISTANCE_MAX - DREAD_DISTANCE_SAFE),
		0.0, 1.0
	)

	# -- Is player sprinting? (check velocity magnitude from CharacterBody3D) --
	var sprinting: bool = false
	if _player is CharacterBody3D:
		var vel: Vector3 = (_player as CharacterBody3D).velocity
		sprinting = vel.length() > 5.5   # sprint threshold

	# -- Delta accumulation --
	var delta_dread: float = 0.0

	if outdoor:
		# Rise based on distance + stillness.
		delta_dread += DREAD_RISE_RATE * (1.0 + dist_factor * 1.5) * delta
		if _still_timer > 3.0:
			delta_dread += STILLNESS_DREAD_RATE * delta
		if sprinting:
			delta_dread += SPRINT_DREAD_BONUS * delta
	else:
		# Indoors — fall quickly when safe.
		delta_dread -= DREAD_FALL_RATE * delta * (1.0 + (1.0 - dist_factor))

	# Clamp.
	dread = clampf(dread + delta_dread, 0.0, 1.0)

	# Push to AudioManager.
	AudioManager.set_dread(dread)
	dread_changed.emit(dread)


## Call when the player arrives at a spawn point (e.g. from SceneTransition).
## Resets the "safe" reference position.
func register_safe_position(pos: Vector3) -> void:
	_safe_position = pos
	# Arriving somewhere safe immediately halves dread (relief).
	dread = dread * 0.5
