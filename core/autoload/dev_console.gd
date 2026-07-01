extends CanvasLayer
## In-game developer console. Toggle with Tilde (~).

signal command_executed(cmd: String, args: Array[String])

const MAX_HISTORY: int = 100
const CONSOLE_SPEED: float = 12.0

@onready var _panel: Panel = $Panel
@onready var _output: RichTextLabel = $Panel/VBox/Output
@onready var _cmd_input: LineEdit = $Panel/VBox/HBox/Input

var _is_open: bool = false
var _history: Array[String] = []
var _history_index: int = -1
var _default_height: float = 0.0
var is_open: bool:
	get:
		return _is_open

var _commands: Dictionary = {}

## True only in debug / editor builds. Some commands are blocked in release.
var _is_debug: bool = false

func _ready() -> void:
	_is_debug = OS.is_debug_build()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_default_height = _panel.size.y
	_panel.visible = false
	_cmd_input.text_submitted.connect(_on_text_submitted)
	_register_default_commands()
	if _is_debug:
		log_msg("DevConsole ready. Type 'help' for commands.")
	else:
		log_msg("DevConsole ready. (Release build — some commands disabled.)")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		get_viewport().set_input_as_handled()
		_toggle()
		return

	if not _is_open:
		return

	if event is InputEventKey and event.is_pressed():
		var key_event: InputEventKey = event as InputEventKey
		match key_event.keycode:
			KEY_UP:
				_get_history(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_get_history(1)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_toggle()
				get_viewport().set_input_as_handled()


func _toggle() -> void:
	_is_open = not _is_open
	_panel.visible = true
	if _is_open:
		_cmd_input.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_cmd_input.release_focus()
		_capture_mouse_next_frame()


func _capture_mouse_next_frame() -> void:
	await get_tree().process_frame
	if _is_open:
		return
	if get_tree().current_scene != null:
		var player: Node = get_tree().get_first_node_in_group("player")
		if player != null and not InventoryManager.is_open and not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif player == null:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func log_msg(text: String, color: String = "#cccccc") -> void:
	_output.append_text("[color=%s]%s[/color]\n" % [color, text])
	var scroll: ScrollBar = _output.get_v_scroll_bar()
	if scroll != null:
		_output.scroll_to_line(_output.get_line_count() - 1)


func log_error(text: String) -> void:
	log_msg(text, "#ff4444")


func log_success(text: String) -> void:
	log_msg(text, "#44ff44")


func log_info(text: String) -> void:
	log_msg(text, "#44aaff")


func register_command(name: String, callback: Callable, help_text: String = "") -> void:
	_commands[name] = {
		"callback": callback,
		"help": help_text,
	}


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_cmd_input.clear()
	log_msg("> " + text, "#ffffff")
	_add_to_history(text)
	var parts: Array[String] = text.split(" ", false)
	if parts.is_empty():
		return
	var cmd: String = parts[0].to_lower()
	var args: Array[String] = []
	for i: int in range(1, parts.size()):
		args.append(parts[i])
	_execute_command(cmd, args)


func _execute_command(cmd: String, args: Array[String]) -> void:
	if not _commands.has(cmd):
		log_error("Unknown command: '%s'. Type 'help' for available commands." % cmd)
		return
	var entry: Dictionary = _commands[cmd]
	var callback: Callable = entry.callback
	var result: Variant = callback.call(args)
	if result is String and not (result as String).is_empty():
		log_msg(result)
	command_executed.emit(cmd, args)


func _add_to_history(text: String) -> void:
	_history.append(text)
	if _history.size() > MAX_HISTORY:
		_history.remove_at(0)
	_history_index = _history.size()


func _get_history(direction: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + direction, 0, _history.size() - 1)
	_cmd_input.text = _history[_history_index]
	_cmd_input.caret_column = _cmd_input.text.length()


func _register_default_commands() -> void:
	register_command("help", _cmd_help, "List all available commands.")
	register_command("clear", _cmd_clear, "Clear the console output.")
	register_command("noclip", _cmd_noclip, "Toggle noclip / free camera mode.")
	register_command("fly", _cmd_noclip, "Alias for noclip.")
	register_command("teleport", _cmd_teleport, "Teleport to x y z coords. Usage: teleport <x> <y> <z>")
	register_command("tp", _cmd_teleport, "Alias for teleport.")
	register_command("pos", _cmd_pos, "Print current player position.")
	register_command("scene", _cmd_scene, "Change scene. Usage: scene <scene_path>")
	register_command("goto", _cmd_goto, "Go to a scene by name. Usage: goto basement|town|main_floor|title")
	register_command("give", _cmd_give, "Give an item. Usage: give <item_id> <title> [text]")
	register_command("flag", _cmd_flag, "Set/clear/check a flag. Usage: flag <id> [true|false|check]")
	register_command("flags", _cmd_flags, "List all current story flags.")
	register_command("inv", _cmd_inv, "List inventory items.")
	register_command("remove", _cmd_remove, "Remove an item. Usage: remove <item_id>")
	register_command("speed", _cmd_speed, "Set player walk speed. Usage: speed <value>")
	register_command("sprint", _cmd_sprint, "Set sprint multiplier. Usage: sprint <value>")
	register_command("spawn", _cmd_spawn, "Spawn a basic shape at player position.")
	register_command("setspawn", _cmd_setspawn, "Set spawn point to current position. Usage: setspawn [default|front|back|basement|all]")
	register_command("editor", _cmd_editor, "Toggle level editor (F8).")
	register_command("save_layout", _cmd_save_layout, "Save editor layout. Usage: save_layout [name]")
	register_command("load_layout", _cmd_load_layout, "Load editor layout. Usage: load_layout [name]")
	register_command("reset", _cmd_reset, "Reset game state and inventory.")
	register_command("quit", _cmd_quit, "Quit the game.")
	register_command("ps1snap", _cmd_ps1snap, "Set PS1 vertex snap amount. Usage: ps1snap <0.005-2.0>  default=0.05")
	register_command("ps1affine", _cmd_ps1affine, "Set PS1 affine warp strength. Usage: ps1affine <0.0-1.0>  default=0.85")
	register_command("crt", _cmd_crt, "Tune CRT overlay. Usage: crt <param> <value>  params: scan vignette aberration grain barrel brightness")


func _cmd_help(_args: Array[String]) -> String:
	var output: String = "[b]Available Commands:[/b]\n"
	var keys: Array = _commands.keys()
	keys.sort()
	for key: String in keys:
		var entry: Dictionary = _commands[key]
		output += "  [color=#44aaff]%s[/color] - %s\n" % [key, entry.help]
	return output


func _cmd_clear(_args: Array[String]) -> String:
	_output.clear()
	return ""


func _cmd_noclip(_args: Array[String]) -> String:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return "No player found in scene."
	DevMode.toggle_noclip()
	return "Noclip toggled."


func _cmd_teleport(args: Array[String]) -> String:
	if args.size() < 3:
		return "Usage: teleport <x> <y> <z>"
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return "No player found."
	var x: float = float(args[0])
	var y: float = float(args[1])
	var z: float = float(args[2])
	player.global_position = Vector3(x, y, z)
	return "Teleported to (%.1f, %.1f, %.1f)" % [x, y, z]


func _cmd_pos(_args: Array[String]) -> String:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return "No player found."
	var pos: Vector3 = player.global_position
	var msg: String = "Player position: (%.3f, %.3f, %.3f)" % [pos.x, pos.y, pos.z]
	print(msg)
	return msg


func _cmd_scene(args: Array[String]) -> String:
	# SECURITY: arbitrary scene loading disabled in release builds.
	if not _is_debug:
		return "Error: 'scene' command disabled in release build."
	if args.is_empty():
		return "Usage: scene <scene_path>"
	var path: String = args[0]
	if not path.begins_with("res://"):
		path = "res://scenes/" + path
	if not path.ends_with(".tscn"):
		path += ".tscn"
	SceneTransition.change_scene(path)
	return "Changing scene to: %s" % path


func _cmd_goto(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: goto basement|town|main_floor|title"
	var name: String = args[0].to_lower()
	var path: String = ""
	match name:
		"basement": path = "res://scenes/basement.tscn"
		"town": path = "res://scenes/town.tscn"
		"main_floor", "house", "mainfloor": path = "res://scenes/main_floor.tscn"
		"title", "menu": path = "res://scenes/ui/title_screen.tscn"
		"overworld", "world", "demo": path = "res://demo/Demo.tscn"
		_:
			return "Unknown scene '%s'. Try: basement, town, main_floor, overworld, title" % name
	SceneTransition.change_scene(path)
	return "Going to %s..." % name


func _cmd_give(args: Array[String]) -> String:
	if args.size() < 2:
		return "Usage: give <item_id> <title> [text]"
	var item_id: String = args[0]
	var title: String = args[1]
	var text: String = args[2] if args.size() > 2 else ""
	InventoryManager.collect(item_id, title, text)
	return "Gave item '%s' (%s)" % [title, item_id]


func _cmd_flag(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: flag <id> [true|false|check]"
	var flag_id: String = args[0]
	if args.size() == 1 or args[1].to_lower() == "true":
		GameState.set_flag(flag_id, true)
		return "Flag '%s' set to true." % flag_id
	elif args[1].to_lower() == "false":
		GameState.clear_flag(flag_id)
		return "Flag '%s' cleared." % flag_id
	elif args[1].to_lower() == "check":
		var has: bool = GameState.has_flag(flag_id)
		return "Flag '%s': %s" % [flag_id, "SET" if has else "NOT SET"]
	else:
		return "Unknown flag action. Use true, false, or check."


func _cmd_flags(_args: Array[String]) -> String:
	if GameState.flags.is_empty():
		return "No flags set."
	var output: String = "[b]Current Flags:[/b]\n"
	for key: String in GameState.flags.keys():
		output += "  %s = %s\n" % [key, str(GameState.flags[key])]
	return output


func _cmd_inv(_args: Array[String]) -> String:
	if InventoryManager.items.is_empty():
		return "Inventory is empty."
	var output: String = "[b]Inventory (%d items):[/b]\n" % InventoryManager.items.size()
	for item: Dictionary in InventoryManager.items:
		output += "  - %s (%s)\n" % [item.get("title", "?"), item.get("id", "?")]
	return output


func _cmd_remove(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: remove <item_id>"
	var item_id: String = args[0]
	if InventoryManager.remove(item_id):
		return "Removed item '%s'." % item_id
	return "Item '%s' not found." % item_id


func _cmd_speed(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: speed <value>"
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return "No player found."
	var new_speed: float = float(args[0])
	player.speed = new_speed
	return "Player speed set to %.1f" % new_speed


func _cmd_sprint(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: sprint <value>"
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return "No player found."
	var new_mult: float = float(args[0])
	player.sprint_multiplier = new_mult
	return "Sprint multiplier set to %.1f" % new_mult


func _cmd_spawn(_args: Array[String]) -> String:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return "No player found."
	var scene: Node = get_tree().current_scene
	if scene == null:
		return "No current scene."
	var cube: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	cube.mesh = box
	cube.global_position = player.global_position + player.global_transform.basis.z * -2.0
	scene.add_child(cube)
	return "Spawned a cube at player position."


func _cmd_setspawn(args: Array[String]) -> String:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return "No player found."
	var scene: Node = get_tree().current_scene
	if scene == null:
		return "No current scene."
	var scene_path: String = scene.scene_file_path
	if scene_path.is_empty():
		return "Current scene has no file path."

	var targets: Array[String] = []
	if args.is_empty():
		targets = ["default"]
	else:
		match args[0].to_lower():
			"all":
				targets = ["default", "from_front_door", "from_back_door", "from_basement", "from_town"]
			"front", "front_door":
				targets = ["from_front_door"]
			"back", "back_door":
				targets = ["from_back_door"]
			"basement":
				targets = ["from_basement"]
			"town":
				targets = ["from_town"]
			"default", _:
				targets = ["default"]

	var overrides: Dictionary = {}
	var path: String = "user://spawn_overrides.json"
	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file != null:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data: Dictionary = json.data as Dictionary
				if data != null:
					overrides = data

	if not overrides.has(scene_path):
		overrides[scene_path] = {}
	var scene_overrides: Dictionary = overrides[scene_path] as Dictionary

	var pos: Dictionary = {
		"x": player.global_position.x,
		"y": player.global_position.y,
		"z": player.global_position.z,
	}
	for target: String in targets:
		scene_overrides[target] = pos

	var out_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if out_file == null:
		return "Failed to save spawn override."
	out_file.store_string(JSON.stringify(overrides, "\t"))
	out_file.close()

	if targets.size() == 1:
		return "%s SAVED to (%.2f, %.2f, %.2f) in %s" % [targets[0], player.global_position.x, player.global_position.y, player.global_position.z, scene_path]
	else:
		return "%d spawns SAVED to (%.2f, %.2f, %.2f) in %s" % [targets.size(), player.global_position.x, player.global_position.y, player.global_position.z, scene_path]


func _cmd_editor(_args: Array[String]) -> String:
	LevelEditor._toggle()
	return "Editor toggled."


func _cmd_save_layout(args: Array[String]) -> String:
	var name: String = args[0] if args.size() > 0 else ""
	LevelEditor.save_layout(name)
	return ""


func _cmd_load_layout(args: Array[String]) -> String:
	var name: String = args[0] if args.size() > 0 else ""
	LevelEditor.load_layout(name)
	return ""


func _cmd_reset(_args: Array[String]) -> String:
	GameState.reset()
	InventoryManager.reset()
	return "Game state and inventory reset."


func _cmd_quit(_args: Array[String]) -> String:
	get_tree().quit()
	return ""


func _cmd_ps1snap(args: Array[String]) -> String:
	if args.is_empty():
		return "Current snap_amount: %.4f  (Usage: ps1snap <value>)" % PS1Renderer.snap_amount
	var val: float = float(args[0])
	PS1Renderer.set_snap(val)
	return "PS1 vertex snap set to %.4f" % PS1Renderer.snap_amount


func _cmd_ps1affine(args: Array[String]) -> String:
	if args.is_empty():
		return "Current affine_strength: %.2f  (Usage: ps1affine <value>)" % PS1Renderer.affine_strength
	var val: float = float(args[0])
	PS1Renderer.set_affine(val)
	return "PS1 affine warp set to %.2f" % PS1Renderer.affine_strength


func _cmd_crt(args: Array[String]) -> String:
	if args.size() < 2:
		return "Usage: crt <param> <value>\n  params: scan vignette aberration grain barrel brightness"
	var crt_node: Node = get_node_or_null("/root/CRTOverlay/Screen")
	if crt_node == null:
		return "CRTOverlay not found."
	var mat: ShaderMaterial = (crt_node as ColorRect).material as ShaderMaterial
	if mat == null:
		return "CRTOverlay has no ShaderMaterial."
	var param: String = args[0].to_lower()
	var val: float = float(args[1])
	var uniform_map: Dictionary = {
		"scan": "scanline_strength",
		"vignette": "vignette_strength",
		"aberration": "aberration_strength",
		"grain": "grain_strength",
		"barrel": "barrel_distortion",
		"brightness": "brightness",
	}
	if not uniform_map.has(param):
		return "Unknown CRT param '%s'. Valid: %s" % [param, ", ".join(uniform_map.keys())]
	mat.set_shader_parameter(uniform_map[param], val)
	return "CRT %s set to %.4f" % [param, val]
