extends Node
## Ambient playback, music playback, and outdoor/indoor mix
## (snow-dampened low-pass on Ambience bus).

const AMBIENCE_BUS_NAME: String = "Ambience"
const MUSIC_BUS_NAME: String = "Music"
const LOWPASS_CUTOFF_INDOOR: float = 20500.0
const LOWPASS_CUTOFF_OUTDOOR: float = 800.0

# Crossfade duration in seconds for music transitions.
const MUSIC_FADE_TIME: float = 1.5

# Layered tension music: calm layer plays always; tension layer fades in as
# dread rises. Both use the Music bus. When a LevelConfig provides a
# music_loop it replaces the calm layer (tension layer is cleared).
const TENSION_BLEND_SPEED: float = 0.8   # dB/sec approach rate

var _ambient_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer       # calm / base layer
var _tension_player: AudioStreamPlayer     # tension overlay layer
var _lowpass: AudioEffectLowPassFilter
var _outdoor_mix_enabled: bool = false

# Current dread level [0..1] — set by DreadMeter autoload each frame.
var _dread: float = 0.0
# Target volume_db for tension layer at full dread.
const TENSION_MAX_DB: float = 0.0
const TENSION_MIN_DB: float = -80.0


func _ready() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	add_child(_ambient_player)
	_ambient_player.bus = AMBIENCE_BUS_NAME

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_music_player.bus = MUSIC_BUS_NAME

	_tension_player = AudioStreamPlayer.new()
	_tension_player.name = "TensionPlayer"
	add_child(_tension_player)
	_tension_player.bus = MUSIC_BUS_NAME
	_tension_player.volume_db = TENSION_MIN_DB

	_setup_lowpass()


func _process(delta: float) -> void:
	# Smoothly blend tension layer volume toward target.
	if _tension_player.stream != null and _tension_player.playing:
		var target_db: float = lerpf(TENSION_MIN_DB, TENSION_MAX_DB, _dread)
		_tension_player.volume_db = move_toward(
			_tension_player.volume_db, target_db, TENSION_BLEND_SPEED * delta * 60.0
		)


## Set the tension layer stream (looping stinger / drone).
## Starts playing immediately at volume corresponding to current dread.
func set_tension_stream(stream: AudioStream) -> void:
	if stream == null:
		_tension_player.stop()
		return
	if _tension_player.stream == stream:
		return
	_tension_player.stream = stream
	_tension_player.volume_db = lerpf(TENSION_MIN_DB, TENSION_MAX_DB, _dread)
	_tension_player.play()


## Called every frame by DreadMeter. dread in [0..1].
func set_dread(dread: float) -> void:
	_dread = clampf(dread, 0.0, 1.0)


## Music playback with crossfade. Calling with null stops music gracefully.
func play_music(stream: AudioStream, restart: bool = false) -> void:
	if stream == null:
		_fade_out_music()
		return
	if _music_player.stream == stream and _music_player.playing and not restart:
		return
	# Crossfade: tween current player to silence, swap track, tween back in.
	_crossfade_music(stream)


func stop_music() -> void:
	_fade_out_music()


func _crossfade_music(new_stream: AudioStream) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(false)
	# Fade out if already playing.
	if _music_player.playing:
		tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_TIME * 0.5)
	# Swap stream and fade in.
	tween.tween_callback(func() -> void:
		_music_player.stop()
		_music_player.stream = new_stream
		_music_player.volume_db = -80.0
		_music_player.play()
	)
	tween.tween_property(_music_player, "volume_db", 0.0, MUSIC_FADE_TIME * 0.5)


func _fade_out_music() -> void:
	if not _music_player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_TIME)
	tween.tween_callback(_music_player.stop)


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
