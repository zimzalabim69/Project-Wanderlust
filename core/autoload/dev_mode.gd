extends Node
## Developer mode systems: noclip, free camera, object inspection.

const NOCLIP_SPEED: float = 8.0
const NOCLIP_FAST_MULT: float = 3.0
const FREE_CAM_SPEED: float = 6.0
const FREE_CAM_FAST_MULT: float = 3.0

var _noclip_enabled: bool = false
var _freecam_enabled: bool = false
var _original_player_collision: int = 0
var _freecam: Camera3D = null
var _freecam_root: Node3D = null
var _freecam_ui: Control = null
var _freecam_speed_label: Label = null
var _freecam_speed: float = FREE_CAM_SPEED


func is_noclip() -> bool:
	return _noclip_enabled


func is_freecam() -> bool:
	return _freecam_enabled


func toggle_noclip() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		DevConsole.log_error("No player found for noclip.")
		return

	_noclip_enabled = not _noclip_enabled
	if _noclip_enabled:
		_original_player_collision = player.collision_layer
		player.collision_layer = 0
		player.collision_mask = 0
		DevConsole.log_success("Noclip ENABLED. Use WASD + Space/Shift to fly.")
	else:
		player.collision_layer = _original_player_collision
		player.collision_mask = 1
		DevConsole.log_success("Noclip DISABLED. Collision restored.")


func toggle_freecam() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		DevConsole.log_error("No player found for freecam.")
		return

	_freecam_enabled = not _freecam_enabled
	if _freecam_enabled:
		_freecam_root = Node3D.new()
		_freecam_root.name = "FreeCamRoot"
		get_tree().current_scene.add_child(_freecam_root)
		_freecam_root.global_transform = player.global_transform

		_freecam = Camera3D.new()
		_freecam.name = "FreeCam"
		_freecam.add_to_group("freecam")
		_freecam_root.add_child(_freecam)

		var cam: Camera3D = player.get_node_or_null("Camera3D")
		if cam != null:
			cam.current = false
		_freecam.current = true
		_show_freecam_ui()
		DevConsole.log_success("Freecam ENABLED. WASD to move, RMB to look. Press F again to return.")
	else:
		if _freecam != null:
			_freecam.queue_free()
			_freecam = null
		if _freecam_root != null:
			_freecam_root.queue_free()
			_freecam_root = null
		var cam: Camera3D = player.get_node_or_null("Camera3D")
		if cam != null:
			cam.current = true
		_hide_freecam_ui()
		DevConsole.log_success("Freecam DISABLED. Player camera restored.")


func _input(event: InputEvent) -> void:
	if DevConsole.is_open:
		return
	if LevelEditor.active:
		return
	if event.is_action_pressed("toggle_freecam"):
		get_viewport().set_input_as_handled()
		toggle_freecam()
	if _freecam_enabled and event.is_action_pressed("teleport_player_here"):
		get_viewport().set_input_as_handled()
		_teleport_player_to_freecam()
		toggle_freecam()
	if _freecam_enabled and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_freecam_speed = clampf(_freecam_speed * 1.15, 0.5, 200.0)
			_update_speed_label()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_freecam_speed = clampf(_freecam_speed / 1.15, 0.5, 200.0)
			_update_speed_label()
			get_viewport().set_input_as_handled()

func _teleport_player_to_freecam() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or _freecam_root == null:
		return
	player.global_position = _freecam_root.global_position
	player.global_rotation.y = _freecam_root.global_rotation.y
	var player_cam: Camera3D = player.get_node_or_null("Camera3D")
	if player_cam != null:
		player_cam.rotation.x = _freecam.rotation.x
	DevConsole.log_success("Player teleported to freecam position.")

func _process(delta: float) -> void:
	if _noclip_enabled:
		_process_noclip(delta)
	elif _freecam_enabled:
		_process_freecam(delta)


func _process_noclip(delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = player.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)

	var up_down: float = 0.0
	if Input.is_action_pressed("ui_page_up") or Input.is_key_pressed(KEY_SPACE):
		up_down += 1.0
	if Input.is_action_pressed("ui_page_down") or Input.is_key_pressed(KEY_CTRL):
		up_down -= 1.0

	var speed: float = NOCLIP_SPEED * (NOCLIP_FAST_MULT if Input.is_action_pressed("sprint") else 1.0)
	player.global_position += direction.normalized() * speed * delta
	player.global_position.y += up_down * speed * delta


func _show_freecam_ui() -> void:
	if _freecam_ui == null:
		var panel: Panel = Panel.new()
		panel.name = "FreecamControls"
		panel.modulate.a = 0.85
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.anchors_preset = Control.PRESET_FULL_RECT
		vbox.offset_left = 12.0
		vbox.offset_top = 8.0
		vbox.offset_right = -12.0
		vbox.offset_bottom = -8.0
		panel.add_child(vbox)

		var title: Label = Label.new()
		title.text = "[ FREECAM MODE ]"
		vbox.add_child(title)

		var controls: Array[String] = [
			"WASD  - Fly",
			"RMB   - Look around",
			"Shift - Speed boost",
			"Space - Fly up",
			"Ctrl  - Fly down",
			"Scroll- Speed +/-",
			"G     - Exit freecam",
			"+     - Teleport player here",
		]
		for line: String in controls:
			var lbl: Label = Label.new()
			lbl.text = line
			vbox.add_child(lbl)

		_freecam_speed_label = Label.new()
		_freecam_speed_label.text = "Speed: %.1f" % _freecam_speed
		vbox.add_child(_freecam_speed_label)

		_freecam_ui = panel
		get_tree().root.add_child(_freecam_ui)
		_freecam_ui.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_freecam_ui.size = Vector2(220, 200)
		_freecam_ui.position = Vector2(get_viewport().size.x - 240, 20)
		_update_speed_label()
	if _freecam_ui != null:
		_freecam_ui.visible = true


func _hide_freecam_ui() -> void:
	if _freecam_ui != null:
		_freecam_ui.visible = false


func _update_speed_label() -> void:
	if _freecam_speed_label != null:
		_freecam_speed_label.text = "Speed: %.1f" % _freecam_speed


func _process_freecam(delta: float) -> void:
	if _freecam_root == null or _freecam == null:
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = _freecam_root.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)

	var up_down: float = 0.0
	if Input.is_action_pressed("ui_page_up") or Input.is_key_pressed(KEY_SPACE):
		up_down += 1.0
	if Input.is_action_pressed("ui_page_down") or Input.is_key_pressed(KEY_CTRL):
		up_down -= 1.0

	var speed: float = _freecam_speed * (FREE_CAM_FAST_MULT if Input.is_action_pressed("sprint") else 1.0)
	_freecam_root.global_position += direction.normalized() * speed * delta
	_freecam_root.global_position.y += up_down * speed * delta

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_delta: Vector2 = Input.get_last_mouse_velocity() * delta * 0.003
		_freecam_root.rotate_y(-mouse_delta.x)
		_freecam.rotate_x(-mouse_delta.y)
		_freecam.rotation.x = clampf(_freecam.rotation.x, -PI / 2.0, PI / 2.0)
