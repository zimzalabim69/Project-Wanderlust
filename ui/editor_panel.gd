extends Control
## Editor UI panel. Shows prefab palette, tool info, and controls.

@onready var _tabs: TabContainer = $Panel/VBox/Tabs
@onready var _prefab_list: ItemList = $Panel/VBox/Tabs/Place/PlaceVBox/PrefabList
@onready var _tool_label: Label = $Panel/VBox/ToolLabel
@onready var _info_label: Label = $Panel/VBox/InfoLabel
@onready var _save_name: LineEdit = $Panel/VBox/Tabs/Save/SaveVBox/SaveName
@onready var _load_name: LineEdit = $Panel/VBox/Tabs/Save/SaveVBox/LoadName
@onready var _save_button: Button = $Panel/VBox/Tabs/Save/SaveVBox/SaveButton
@onready var _load_button: Button = $Panel/VBox/Tabs/Save/SaveVBox/LoadButton

var _prefabs: Array[Dictionary] = []
var _selected_prefab: PackedScene = null

func _ready() -> void:
	visible = false
	_populate_prefabs()
	_prefab_list.item_selected.connect(_on_prefab_selected)
	_save_button.pressed.connect(_on_save)
	_load_button.pressed.connect(_on_load)
	_update_tool_label(1)


func set_tool(tool: int) -> void:
	_update_tool_label(tool)
	match tool:
		1: # PLACE
			_tabs.current_tab = 0
			_info_label.text = "L-Click: Place | Scroll: Rotate"
		2: # TERRAIN
			_tabs.current_tab = 1
			_info_label.text = "L-Click: Raise | R-Click: Lower"
		3: # SPAWN
			_tabs.current_tab = 2
			_info_label.text = "Spawn tool (coming soon)"
		4: # SELECT
			_tabs.current_tab = 3
			_info_label.text = "L-Click: Select | R-Click: Delete | Del: Remove"


func get_selected_prefab() -> PackedScene:
	return _selected_prefab


func _update_tool_label(tool: int) -> void:
	var names: Array[String] = ["None", "Placement", "Terrain Sculpt", "Spawn/Zone", "Select/Delete"]
	_tool_label.text = "Tool: %s (Tab to cycle)" % names[tool]


func _populate_prefabs() -> void:
	_prefabs.clear()
	_prefab_list.clear()

	# Add built-in primitives
	_add_prefab("Primitive: Box", "", "box")
	_add_prefab("Primitive: Sphere", "", "sphere")
	_add_prefab("Primitive: Cylinder", "", "cylinder")

	# Add existing scenes
	_add_prefab("Rock A", "res://demo/assets/models/RockA.glb", "scene")
	_add_prefab("Rock B", "res://demo/assets/models/RockB.glb", "scene")
	_add_prefab("Rock C", "res://demo/assets/models/RockC.glb", "scene")
	_add_prefab("Basement Shell", "res://scenes/structures/basement_shell.tscn", "scene")

	# Select first
	if _prefab_list.item_count > 0:
		_prefab_list.select(0)
		_on_prefab_selected(0)


func _add_prefab(name: String, path: String, type: String) -> void:
	var idx: int = _prefab_list.item_count
	_prefab_list.add_item(name)
	_prefabs.append({
		"name": name,
		"path": path,
		"type": type,
	})


func _on_prefab_selected(index: int) -> void:
	if index < 0 or index >= _prefabs.size():
		return
	var entry: Dictionary = _prefabs[index]
	var type: String = entry.type
	match type:
		"box":
			_selected_prefab = _make_primitive_box()
		"sphere":
			_selected_prefab = _make_primitive_sphere()
		"cylinder":
			_selected_prefab = _make_primitive_cylinder()
		"scene":
			var path: String = entry.path
			if not path.is_empty():
				_selected_prefab = load(path) as PackedScene


func _make_primitive_box() -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "Box"
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	mesh.mesh = box
	root.add_child(mesh)
	var body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	col.shape = shape
	body.add_child(col)
	root.add_child(body)
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	return scene


func _make_primitive_sphere() -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "Sphere"
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	mesh.mesh = sph
	root.add_child(mesh)
	var body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	body.add_child(col)
	root.add_child(body)
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	return scene


func _make_primitive_cylinder() -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "Cylinder"
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 1.0
	mesh.mesh = cyl
	root.add_child(mesh)
	var body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.0
	col.shape = shape
	body.add_child(col)
	root.add_child(body)
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	return scene


func _on_save() -> void:
	var name: String = _save_name.text.strip_edges()
	LevelEditor.save_layout(name)


func _on_load() -> void:
	var name: String = _load_name.text.strip_edges()
	LevelEditor.load_layout(name)
