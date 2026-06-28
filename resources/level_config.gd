class_name LevelConfig
extends Resource
## Per-level audio and mix settings. Assign on each LevelRoot in the Inspector.

@export var level_id: String = ""
@export var display_name: String = ""
@export var ambient_loop: AudioStream
@export var music_loop: AudioStream
@export var use_outdoor_mix: bool = false
