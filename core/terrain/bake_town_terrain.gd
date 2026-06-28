extends SceneTree
## Headless bake for town snow terrain. Requires Terrain3D GDExtension loaded.
## Run: godot --path . --display-driver headless --script res://core/terrain/bake_town_terrain.gd

const TOWN_SCENE: String = "res://scenes/town.tscn"
const DATA_DIR: String = "res://assets/terrain/town/data"
const HEIGHT_MAP_RES: int = 1024
const BASE_HEIGHT: float = 0.0
const HEIGHT_SCALE: float = 18.0
const TYPE_HEIGHT: int = 0
const TYPE_CONTROL: int = 1


func _init() -> void:
	if not ClassDB.class_exists("Terrain3D"):
		push_error("Terrain3D extension not loaded. Run from project root with Godot 4.4+.")
		quit(1)
		return

	print("Town terrain bake: starting...")
	_clear_data_dir()

	var scene_packed: PackedScene = load(TOWN_SCENE) as PackedScene
	if scene_packed == null:
		push_error("Failed to load town scene.")
		quit(1)
		return

	var town: Node = scene_packed.instantiate()
	root.add_child(town)

	var terrain: Object = town.get_node_or_null("Terrain/Terrain3D")
	if terrain == null:
		push_error("Terrain3D node missing.")
		quit(1)
		return

	terrain.set("data_directory", DATA_DIR)

	var height_img: Image = _build_height_image()
	var control_img: Image = _build_control_image(height_img.get_width(), height_img.get_height())

	var images: Array = []
	images.resize(3)
	images[TYPE_HEIGHT] = height_img
	images[TYPE_CONTROL] = control_img

	var data: Object = terrain.get("data")
	data.call("import_images", images, Vector3.ZERO, BASE_HEIGHT, 1.0)
	data.call("update_height_range")
	var err: int = int(data.call("save_directory", DATA_DIR))
	if err != OK:
		push_error("save_directory failed: %s" % error_string(err))
		quit(1)
		return

	print("Town terrain bake: saved to ", DATA_DIR)
	print("Town terrain bake: height range ", data.call("get_height_range"))
	quit(0)


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
			var h: float = BASE_HEIGHT + n * HEIGHT_SCALE
			var dist: float = Vector2(x, y).distance_to(center) / falloff_radius
			var edge: float = clampf(1.0 - dist * dist, 0.0, 1.0)
			h *= edge
			var normalized: float = inverse_lerp(-HEIGHT_SCALE, HEIGHT_SCALE, h)
			img.set_pixel(x, y, Color(normalized, 0.0, 0.0, 1.0))

	return img


func _build_control_image(width: int, height: int) -> Image:
	var img: Image = Image.create_empty(width, height, false, Image.FORMAT_RF)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	return img
