extends SceneTree
## Builds snowy ground mesh + collision. No Terrain3D required.
## Run: godot --path . --display-driver headless --script res://core/terrain/generate_town_ground_mesh.gd

const MESH_PATH: String = "res://assets/terrain/town/town_ground_mesh.tres"
const SHAPE_PATH: String = "res://assets/terrain/town/town_ground_shape.tres"
const GRID: int = 128
const SIZE: float = 200.0
const HEIGHT_SCALE: float = 14.0


func _init() -> void:
	print("Generating town ground mesh...")
	var mesh: ArrayMesh = _build_mesh()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape() as ConcavePolygonShape3D
	var err_mesh: Error = ResourceSaver.save(mesh, MESH_PATH)
	var err_shape: Error = ResourceSaver.save(shape, SHAPE_PATH)
	if err_mesh != OK or err_shape != OK:
		push_error("Failed to save mesh/shape.")
		quit(1)
		return
	print("Saved ", MESH_PATH, " and ", SHAPE_PATH)
	quit(0)


func _build_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.018
	noise.fractal_octaves = 4

	var half: float = SIZE * 0.5
	var step: float = SIZE / float(GRID - 1)

	for z: int in GRID - 1:
		for x: int in GRID - 1:
			var corners: Array[Vector3] = [
				_height_vertex(x, z, step, half, noise),
				_height_vertex(x + 1, z, step, half, noise),
				_height_vertex(x + 1, z + 1, step, half, noise),
				_height_vertex(x, z + 1, step, half, noise),
			]
			var normal: Vector3 = (corners[1] - corners[0]).cross(corners[3] - corners[0]).normalized()
			for i: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(normal)
				st.set_color(Color(0.72, 0.76, 0.82))
				st.add_vertex(corners[i])

	st.generate_normals()
	return st.commit()


func _height_vertex(gx: int, gz: int, step: float, half: float, noise: FastNoiseLite) -> Vector3:
	var wx: float = gx * step - half
	var wz: float = gz * step - half
	var n: float = noise.get_noise_2d(wx, wz)
	var dist: float = Vector2(wx, wz).length() / half
	var edge: float = clampf(1.0 - dist * dist, 0.0, 1.0)
	var y: float = n * HEIGHT_SCALE * edge
	return Vector3(wx, y, wz)
