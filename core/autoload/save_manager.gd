extends Node
## Handles saving and loading game state to user://savegame.json.

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1
const MAIN_SCENE: String = "res://scenes/basement.tscn"

const _AUDIO_BUS_MAP: Dictionary = {
	"master": "Master",
	"sfx": "SFX",
	"music": "Music",
	"ambience": "Ambience",
}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_game() -> void:
	GameState.reset()
	InventoryManager.reset()
	await SceneTransition.change_scene(MAIN_SCENE, "default")


func save_game() -> void:
	var current_scene: Node = get_tree().current_scene
	var scene_path: String = ""
	if current_scene != null and current_scene.scene_file_path != null:
		scene_path = current_scene.scene_file_path
	else:
		scene_path = MAIN_SCENE
		push_warning("SaveManager: current_scene was null; defaulting to main scene.")

	var spawn_id: String = GameState.pending_spawn_id
	if spawn_id.is_empty():
		spawn_id = "default"

	var audio_data: Dictionary = {}
	for key: String in _AUDIO_BUS_MAP.keys():
		var bus_name: String = _AUDIO_BUS_MAP[key]
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			audio_data[key] = AudioServer.get_bus_volume_db(bus_index)
		else:
			audio_data[key] = 0.0
			push_warning("SaveManager: audio bus '%s' not found; defaulting to 0.0." % bus_name)

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"current_scene": scene_path,
		"spawn_id": spawn_id,
		"flags": GameState.flags.duplicate(),
		"items": InventoryManager.items.duplicate(),
		"audio": audio_data,
	}

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing. Error: %s" % error_string(FileAccess.get_open_error()))
		return

	var json_string: String = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()


func load_game() -> void:
	if not has_save():
		push_warning("SaveManager: no save file found to load.")
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file for reading. Error: %s" % error_string(FileAccess.get_open_error()))
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(json_string)
	if parse_error != OK:
		push_error("SaveManager: failed to parse save JSON. Error: %s at line %d." % [error_string(parse_error), json.get_error_line()])
		return

	var save_data: Dictionary = json.data as Dictionary
	if save_data == null:
		push_error("SaveManager: save data is not a Dictionary.")
		return

	var version: int = save_data.get("version", 0)
	if version != SAVE_VERSION:
		push_warning("SaveManager: save version mismatch (expected %d, got %d). Attempting to load anyway." % [SAVE_VERSION, version])

	# Reset state before restoring
	GameState.reset()
	InventoryManager.reset()

	# Restore flags
	var flags: Dictionary = save_data.get("flags", {}) as Dictionary
	if flags != null:
		for flag_id: Variant in flags.keys():
			var value: bool = flags.get(flag_id, false)
			if flag_id is String:
				GameState.set_flag(flag_id, value)
			else:
				push_warning("SaveManager: skipping non-string flag key: %s" % str(flag_id))
	else:
		push_warning("SaveManager: flags data missing or invalid.")

	# Restore items
	var items: Array = save_data.get("items", []) as Array
	if items != null:
		for item: Variant in items:
			if item is Dictionary:
				var item_dict: Dictionary = item as Dictionary
				var item_id: String = item_dict.get("id", "") as String
				var title: String = item_dict.get("title", "") as String
				var text: String = item_dict.get("text", "") as String
				var icon: String = item_dict.get("icon", "") as String
				if not item_id.is_empty():
					InventoryManager.collect(item_id, title, text, icon)
				else:
					push_warning("SaveManager: skipping item with empty id.")
			else:
				push_warning("SaveManager: skipping non-dictionary item in save data.")
	else:
		push_warning("SaveManager: items data missing or invalid.")

	# Restore audio
	var audio: Dictionary = save_data.get("audio", {}) as Dictionary
	if audio != null:
		for key: Variant in audio.keys():
			if key is String and _AUDIO_BUS_MAP.has(key):
				var bus_name: String = _AUDIO_BUS_MAP[key]
				var bus_index: int = AudioServer.get_bus_index(bus_name)
				if bus_index >= 0:
					var volume_db: float = audio.get(key, 0.0) as float
					AudioServer.set_bus_volume_db(bus_index, volume_db)
				else:
					push_warning("SaveManager: audio bus '%s' not found during load." % bus_name)
			else:
				push_warning("SaveManager: unknown audio key in save data: %s" % str(key))
	else:
		push_warning("SaveManager: audio data missing or invalid.")

	# Restore scene
	var saved_scene: String = save_data.get("current_scene", MAIN_SCENE) as String
	var saved_spawn_id: String = save_data.get("spawn_id", "default") as String
	if saved_scene.is_empty():
		saved_scene = MAIN_SCENE
		push_warning("SaveManager: saved scene path was empty; defaulting to main scene.")

	await SceneTransition.change_scene(saved_scene, saved_spawn_id)


func delete_save() -> void:
	if not has_save():
		push_warning("SaveManager: no save file to delete.")
		return

	var err: Error = DirAccess.remove_absolute(SAVE_PATH)
	if err != OK:
		push_error("SaveManager: failed to delete save file. Error: %s" % error_string(err))
