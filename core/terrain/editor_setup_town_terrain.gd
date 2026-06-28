@tool
extends EditorScript
## Run from Script Editor: File → Run (or Ctrl+Shift+X).
## Creates a flat Terrain3D region at the town spawn so sculpting works immediately.

const TOWN_SCENE: String = "res://scenes/town.tscn"
const REGION_WORLD_POS: Vector3 = Vector3(0.0, 0.0, 0.0)


func _run() -> void:
	var terrain: Terrain3D = _find_town_terrain()
	if terrain == null:
		push_error("Town Terrain3D not found. Open scenes/town.tscn first.")
		return

	if terrain.data_directory.is_empty():
		terrain.data_directory = "res://assets/terrain/town/data"

	if terrain.data.has_regionp(REGION_WORLD_POS):
		print("Terrain setup: region already exists at origin — nothing to do.")
		return

	var editor: Terrain3DEditor = Terrain3DEditor.new()
	editor.set_terrain(terrain)
	editor.set_tool(Terrain3DEditor.REGION)
	editor.set_operation(Terrain3DEditor.ADD)
	editor.start_operation(REGION_WORLD_POS)
	editor.operate(REGION_WORLD_POS, 0.0)
	editor.stop_operation()
	editor.free()

	terrain.data.save_directory(terrain.data_directory)
	print("Terrain setup: added 256m region at world origin. Saved to ", terrain.data_directory)
	print("Reopen town.tscn, select Terrain3D, use Raise/Lower (2nd tool group) to sculpt.")


func _find_town_terrain() -> Terrain3D:
	var root: Node = get_scene()
	if root == null:
		return null
	var terrain_node: Node = root.get_node_or_null("Terrain/Terrain3D")
	if terrain_node is Terrain3D:
		return terrain_node as Terrain3D
	return null
