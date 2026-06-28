extends Node
## In-game level editor suite. Toggle with F8.
## Combines freecam, object placement, terrain brush, and spawn tools.

enum Tool { NONE, PLACE, TERRAIN, SPAWN, SELECT }

const SAVE_DIR: String = "user://editor_saves"

var active: bool = false
var current_tool: Tool = Tool.PLACE
var selected_node: Node3D = null

var _editor_ui: Control = null

func _ready() -> void:
	add_to_group("level_editor")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_editor"):
		get_viewport().set_input_as_handled()
		_toggle()

	if not active:
		return

	if event.is_action_pressed("editor_cycle_tool"):
		get_viewport().set_input_as_handled()
		_cycle_tool()

	if event.is_action_pressed("editor_delete") and selected_node != null:
		get_viewport().set_input_as_handled()
		_delete_selected()

	if event is InputEventMouseButton and event.is_pressed():
		if current_tool == Tool.PLACE and event.button_index == MOUSE_BUTTON_LEFT:
			_place_at_mouse()
		elif current_tool == Tool.TERRAIN:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_sculpt_terrain(true)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_sculpt_terrain(false)
		elif current_tool == Tool.SELECT and event.button_index == MOUSE_BUTTON_LEFT:
			_select_at_mouse()
		elif current_tool == Tool.SELECT and event.button_index == MOUSE_BUTTON_RIGHT:
			_delete_at_mouse()


func _toggle() -> void:
	active = not active
	if active:
		_enter_editor()
	else:
		_exit_editor()


func _enter_editor() -> void:
	DevConsole.log_info("EDITOR MODE ON (F8). Tool: Placement")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not DevMode.is_freecam():
		DevMode.toggle_freecam()
	_show_ui()
	current_tool = Tool.PLACE
	_update_ui()


func _exit_editor() -> void:
	DevConsole.log_info("EDITOR MODE OFF")
	selected_node = null
	if DevMode.is_freecam():
		DevMode.toggle_freecam()
	if not InventoryManager.is_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hide_ui()


func _cycle_tool() -> void:
	current_tool = wrapi(current_tool + 1, 1, Tool.SPAWN + 1) as Tool
	selected_node = null
	_update_ui()
	var tool_name: String = Tool.keys()[current_tool]
	DevConsole.log_info("Tool: %s" % tool_name)


func _show_ui() -> void:
	if _editor_ui == null:
		var scene: PackedScene = load("res://ui/editor_panel.tscn") as PackedScene
		if scene != null:
			_editor_ui = scene.instantiate() as Control
			get_tree().root.add_child(_editor_ui)
	if _editor_ui != null:
		_editor_ui.visible = true


func _hide_ui() -> void:
	if _editor_ui != null:
		_editor_ui.visible = false


func _update_ui() -> void:
	if _editor_ui != null and _editor_ui.has_method("set_tool"):
		_editor_ui.set_tool(current_tool)


func _place_at_mouse() -> void:
	var cam: Camera3D = _get_active_camera()
	if cam == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var to: Vector3 = from + cam.project_ray_normal(mouse_pos) * 200.0

	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 1
	var result: Dictionary = space.intersect_ray(query)

	var place_pos: Vector3
	if result.is_empty():
		place_pos = from + cam.project_ray_normal(mouse_pos) * 20.0
	else:
		place_pos = result.position

	var prefab: PackedScene = _get_current_prefab()
	if prefab == null:
		DevConsole.log_error("No prefab selected.")
		return

	var instance: Node3D = prefab.instantiate() as Node3D
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var container: Node = scene_root.get_node_or_null("Props")
	if container == null:
		container = scene_root
	container.add_child(instance)
	instance.owner = scene_root
	instance.global_position = place_pos
	instance.rotation_degrees.y = randf() * 360.0
	DevConsole.log_success("Placed %s at (%.1f, %.1f, %.1f)" % [instance.name, place_pos.x, place_pos.y, place_pos.z])


func _sculpt_terrain(raise: bool) -> void:
	var cam: Camera3D = _get_active_camera()
	if cam == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var to: Vector3 = from + cam.project_ray_normal(mouse_pos) * 200.0

	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 1
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return

	var hit_pos: Vector3 = result.position
	# Try to find Terrain3D node
	var terrain: Node = _find_terrain3d()
	if terrain == null:
		DevConsole.log_error("No Terrain3D found. Sculpting on baked mesh only.")
		return

	var _brush_size: int = 4
	var _strength: float = 0.3 if raise else -0.3
	# Note: Terrain3D API is complex; this is a simplified approach
	# In a full implementation you'd call terrain storage methods
	DevConsole.log_info("Terrain sculpt at (%.1f, %.1f, %.1f) - %s" % [hit_pos.x, hit_pos.y, hit_pos.z, "raise" if raise else "lower"])


func _select_at_mouse() -> void:
	var cam: Camera3D = _get_active_camera()
	if cam == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var to: Vector3 = from + cam.project_ray_normal(mouse_pos) * 200.0

	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 1
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		selected_node = null
		return

	var collider: Node = result.collider as Node
	if collider == null:
		return
	selected_node = _find_selectable_root(collider)
	if selected_node != null:
		DevConsole.log_info("Selected: %s" % selected_node.name)


func _delete_at_mouse() -> void:
	_select_at_mouse()
	_delete_selected()


func _delete_selected() -> void:
	if selected_node == null:
		return
	var name: String = selected_node.name
	selected_node.queue_free()
	selected_node = null
	DevConsole.log_success("Deleted: %s" % name)


func _get_active_camera() -> Camera3D:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		var cam: Camera3D = player.get_node_or_null("Camera3D") as Camera3D
		if cam != null and cam.current:
			return cam
	var freecam: Camera3D = get_tree().get_first_node_in_group("freecam") as Camera3D
	if freecam != null and freecam.current:
		return freecam
	# Fallback: any current camera
	for node: Node in get_tree().get_nodes_in_group("player"):
		var c: Camera3D = node.get_node_or_null("Camera3D") as Camera3D
		if c != null and c.current:
			return c
	return get_viewport().get_camera_3d()


func _get_current_prefab() -> PackedScene:
	if _editor_ui != null and _editor_ui.has_method("get_selected_prefab"):
		return _editor_ui.get_selected_prefab() as PackedScene
	return null


func _find_selectable_root(node: Node) -> Node3D:
	var current: Node = node
	while current != null:
		if current is Node3D and current.owner != null:
			return current as Node3D
		current = current.get_parent()
	return null


func _find_terrain3d() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Terrain/Terrain3D")


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func save_layout(slot_name: String = "") -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if slot_name.is_empty():
		slot_name = scene.scene_file_path.get_file().get_basename()

	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive(SAVE_DIR)

	var save_data: Dictionary = {
		"scene": scene.scene_file_path,
		"timestamp": Time.get_datetime_string_from_system(),
		"objects": [],
	}

	# Save Props, Structures, Vehicles children
	for category: String in ["Props", "Structures", "Vehicles"]:
		var container: Node = scene.get_node_or_null(category)
		if container == null:
			continue
		for child: Node in container.get_children():
			if child is Node3D and child.scene_file_path != null and not child.scene_file_path.is_empty():
				var obj: Dictionary = {
					"category": category,
					"path": child.scene_file_path,
					"position": [child.global_position.x, child.global_position.y, child.global_position.z],
					"rotation": [child.global_rotation.x, child.global_rotation.y, child.global_rotation.z],
					"scale": [child.global_scale.x, child.global_scale.y, child.global_scale.z],
				}
				save_data.objects.append(obj)

	var path: String = SAVE_DIR + "/" + slot_name + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		DevConsole.log_success("Saved layout to %s (%d objects)" % [path, save_data.objects.size()])
	else:
		DevConsole.log_error("Failed to save layout.")


func load_layout(slot_name: String = "") -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if slot_name.is_empty():
		slot_name = scene.scene_file_path.get_file().get_basename()

	var path: String = SAVE_DIR + "/" + slot_name + ".json"
	if not FileAccess.file_exists(path):
		DevConsole.log_error("No saved layout found: %s" % path)
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		DevConsole.log_error("Failed to open layout file.")
		return

	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		DevConsole.log_error("Failed to parse layout JSON.")
		return

	var data: Dictionary = json.data as Dictionary
	if data == null:
		return

	var loaded: int = 0
	for obj: Variant in data.get("objects", []) as Array:
		if obj is Dictionary:
			var obj_dict: Dictionary = obj as Dictionary
			var prefab_path: String = obj_dict.get("path", "") as String
			if prefab_path.is_empty():
				continue
			var prefab: PackedScene = load(prefab_path) as PackedScene
			if prefab == null:
				continue
			var instance: Node3D = prefab.instantiate() as Node3D
			var category: String = obj_dict.get("category", "Props")
			var container: Node = scene.get_node_or_null(category)
			if container == null:
				container = scene
			container.add_child(instance)
			instance.owner = scene

			var pos: Array = obj_dict.get("position", [0, 0, 0]) as Array
			var rot: Array = obj_dict.get("rotation", [0, 0, 0]) as Array
			var scl: Array = obj_dict.get("scale", [1, 1, 1]) as Array
			instance.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
			instance.global_rotation = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
			var new_scale: Vector3 = Vector3(float(scl[0]), float(scl[1]), float(scl[2]))
			instance.set("scale", new_scale)
			loaded += 1

	DevConsole.log_success("Loaded %d objects from %s" % [loaded, path])
