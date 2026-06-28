extends Node
## Ambient playback and outdoor/indoor mix (snow-dampened low-pass on Ambience bus).

const AMBIENCE_BUS_NAME: String = "Ambience"
const LOWPASS_CUTOFF_INDOOR: float = 20500.0
const LOWPASS_CUTOFF_OUTDOOR: float = 800.0

var _ambient_player: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _outdoor_mix_enabled: bool = false


func _ready() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	add_child(_ambient_player)
	_ambient_player.bus = AMBIENCE_BUS_NAME
	_setup_lowpass()


func play_ambient(stream: AudioStream, restart: bool = true) -> void:
	if stream == null:
		_ambient_player.stop()
		return
	if _ambient_player.stream == stream and _ambient_player.playing and not restart:
		return
	_ambient_player.stream = stream
	_ambient_player.play()


func stop_ambient() -> void:
	_ambient_player.stop()


func set_outdoor_mix(enabled: bool) -> void:
	_outdoor_mix_enabled = enabled
	if _lowpass == null:
		return
	_lowpass.cutoff_hz = LOWPASS_CUTOFF_OUTDOOR if enabled else LOWPASS_CUTOFF_INDOOR


func is_outdoor_mix_enabled() -> bool:
	return _outdoor_mix_enabled


func _setup_lowpass() -> void:
	var bus_index: int = AudioServer.get_bus_index(AMBIENCE_BUS_NAME)
	if bus_index < 0:
		push_warning("AudioManager: '%s' bus missing. Assign default_bus_layout.tres in Project Settings." % AMBIENCE_BUS_NAME)
		return

	for effect_index: int in AudioServer.get_bus_effect_count(bus_index):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectLowPassFilter:
			_lowpass = effect as AudioEffectLowPassFilter
			break

	if _lowpass == null:
		_lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(bus_index, _lowpass)

	set_outdoor_mix(false)
