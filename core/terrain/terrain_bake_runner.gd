extends Node3D
## Bakes snowy town terrain when run via: godot --path . --display-driver headless --audio-driver Dummy res://scenes/tools/terrain_bake_runner.tscn

const DATA_DIR: String = "res://assets/terrain/town/data"
const HEIGHT_MAP_RES: int = 1024
const BASE_HEIGHT: float = 0.0
const HEIGHT_SCALE: float = 16.0


func _ready() -> void:
	if not ClassDB.class_exists("Terrain3D"):
		push_error("Terrain3D not loaded.")
		_deferred_quit(1)
		return

	var terrain: Terrain3D = $Terrain3D
	_clear_data_dir()
	terrain.data_directory = DATA_DIR

	_add_region_with_editor(terrain)
	await get_tree().process_frame

	var images: Array[Image] = []
	images.resize(Terrain3DRegion.TYPE_MAX)
	images[Terrain3DRegion.TYPE_HEIGHT] = _build_height_image()
	images[Terrain3DRegion.TYPE_CONTROL] = _build_control_image(HEIGHT_MAP_RES, HEIGHT_MAP_RES)
	terrain.data.import_images(images, Vector3.ZERO, BASE_HEIGHT, 1.0)
	terrain.data.update_height_range()

	await get_tree().process_frame
	terrain.data.save_directory(DATA_DIR)

	var regions: Array = terrain.data.get_regions_active()
	print("Town terrain bake OK -> ", DATA_DIR)
	print("  active regions: ", regions.size())
	print("  height range: ", terrain.data.get_height_range())
	_deferred_quit(0)


func _deferred_quit(code: int) -> void:
	await get_tree().process_frame
	get_tree().quit(code)


func _add_region_with_editor(terrain: Terrain3D) -> void:
	var editor: Terrain3DEditor = Terrain3DEditor.new()
	editor.set_terrain(terrain)
	editor.set_tool(Terrain3DEditor.REGION)
	editor.set_operation(Terrain3DEditor.ADD)
	editor.start_operation(Vector3.ZERO)
	editor.operate(Vector3.ZERO, 0.0)
	editor.stop_operation()
	editor.free()


func _clear_data_dir() -> void:
	var absolute: String = ProjectSettings.globalize_path(DATA_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	var dir: DirAccess = DirAccess.open(absolute)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".res"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _build_height_image() -> Image:
	var img: Image = Image.create_empty(HEIGHT_MAP_RES, HEIGHT_MAP_RES, false, Image.FORMAT_RF)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0028
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.45

	var center: Vector2 = Vector2(HEIGHT_MAP_RES * 0.5, HEIGHT_MAP_RES * 0.5)
	var falloff_radius: float = HEIGHT_MAP_RES * 0.48

	for y: int in HEIGHT_MAP_RES:
		for x: int in HEIGHT_MAP_RES:
			var n: float = noise.get_noise_2d(float(x), float(y))
			var h: float = (BASE_HEIGHT + n * HEIGHT_SCALE) * clampf(
				1.0 - pow(Vector2(x, y).distance_to(center) / falloff_radius, 2.0), 0.0, 1.0
			)
			img.set_pixel(x, y, Color(inverse_lerp(-HEIGHT_SCALE, HEIGHT_SCALE, h), 0.0, 0.0, 1.0))

	return img


func _build_control_image(width: int, height: int) -> Image:
	var img: Image = Image.create_empty(width, height, false, Image.FORMAT_RF)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	return img
