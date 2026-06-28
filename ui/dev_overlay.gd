extends CanvasLayer
## Debug overlay HUD. Shows FPS, position, scene, flags, inventory.

@onready var _panel: Panel = $Panel
@onready var _fps_label: Label = $Panel/VBox/FPSLabel
@onready var _pos_label: Label = $Panel/VBox/PosLabel
@onready var _scene_label: Label = $Panel/VBox/SceneLabel
@onready var _flags_label: Label = $Panel/VBox/FlagsLabel
@onready var _inv_label: Label = $Panel/VBox/InvLabel
@onready var _noclip_label: Label = $Panel/VBox/NoclipLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 94
	_panel.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_overlay"):
		get_viewport().set_input_as_handled()
		_toggle()


func _toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		DevConsole.log_info("Debug overlay ON (F3). Press F3 again to hide.")


func _process(_delta: float) -> void:
	if not _panel.visible:
		return

	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		var pos: Vector3 = player.global_position
		_pos_label.text = "POS: %.2f, %.2f, %.2f" % [pos.x, pos.y, pos.z]
	else:
		_pos_label.text = "POS: N/A"

	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path != null:
		_scene_label.text = "SCENE: %s" % current_scene.scene_file_path.get_file()
	else:
		_scene_label.text = "SCENE: N/A"

	var noclip: String = "ON" if DevMode.is_noclip() else "OFF"
	var freecam: String = "ON" if DevMode.is_freecam() else "OFF"
	var editor: String = "ON" if LevelEditor.active else "OFF"
	_noclip_label.text = "NOCLIP: %s | FREECAM: %s | EDITOR: %s" % [noclip, freecam, editor]

	var flags_text: String = ""
	if GameState.flags.is_empty():
		flags_text = "none"
	else:
		for key: String in GameState.flags.keys():
			flags_text += "%s=%s " % [key, str(GameState.flags[key])]
	_flags_label.text = "FLAGS: %s" % flags_text

	var inv_text: String = ""
	if InventoryManager.items.is_empty():
		inv_text = "empty"
	else:
		for item: Dictionary in InventoryManager.items:
			inv_text += "%s, " % item.get("id", "?")
	_inv_label.text = "INV: %s" % inv_text
