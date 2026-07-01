extends Node
## PS1Renderer — applies the ps1.gdshader to every MeshInstance3D in the scene
## at startup and whenever a new scene is loaded.
##
## The shader reproduces two signature PlayStation 1 rendering artifacts:
##   • Vertex snapping  — geometry snaps to a coarse grid, making polygons
##                         "wobble" as the camera moves.
##   • Affine texture mapping — UVs are interpolated without perspective
##                               correction, causing textures to swim/warp.
##
## Existing material properties (albedo color, roughness, textures) are
## preserved — the shader reads them via shader uniforms that are copied from
## the source StandardMaterial3D / ORMMaterial3D before replacement.
##
## Exclusions:
##   • MeshInstance3D nodes in the "ps1_exclude" group are skipped.
##   • The sky / WorldEnvironment is not touched.
##   • Terrain3D nodes handle their own shaders; they are skipped.

const SHADER_PATH: String = "res://assets/shaders/ps1.gdshader"
const SNAP_DEFAULT: float  = 0.05
const AFFINE_DEFAULT: float = 0.85

var _shader: Shader = null

# Global overrides — tweak via DevConsole or from code.
var snap_amount:     float = SNAP_DEFAULT
var affine_strength: float = AFFINE_DEFAULT

# Track materials we've already converted so we don't double-process on
# scene_changed signals that fire multiple times.
var _converted: Dictionary = {}


func _ready() -> void:
	_shader = load(SHADER_PATH) as Shader
	if _shader == null:
		push_error("PS1Renderer: cannot load shader at " + SHADER_PATH)
		return
	# Apply immediately to whatever is loaded at startup.
	call_deferred("_apply_to_tree")
	# Re-apply when the active scene changes.
	get_tree().node_added.connect(_on_node_added)


## Public API ----------------------------------------------------------------

## Force a full re-application across the current scene tree.
func refresh() -> void:
	_converted.clear()
	_apply_to_tree()


## Adjust snap resolution at runtime (e.g. from DevConsole).
## snap — world-space grid size; smaller = more wobble.
func set_snap(snap: float) -> void:
	snap_amount = clampf(snap, 0.005, 2.0)
	_update_all_uniforms()


## Adjust affine warp strength at runtime.
## strength — 0.0 (perspective-correct) to 1.0 (full PS1 affine).
func set_affine(strength: float) -> void:
	affine_strength = clampf(strength, 0.0, 1.0)
	_update_all_uniforms()


## Internal ------------------------------------------------------------------

func _apply_to_tree() -> void:
	if get_tree() == null:
		return
	_recurse(get_tree().root)


func _on_node_added(node: Node) -> void:
	# Called for every newly added node — only act on MeshInstance3D.
	if node is MeshInstance3D:
		call_deferred("_apply_to_mesh", node as MeshInstance3D)


func _recurse(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		_apply_to_mesh(node as MeshInstance3D)
	for child: Node in node.get_children():
		_recurse(child)


func _apply_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_instance):
		return

	# Skip excluded nodes.
	if mesh_instance.is_in_group("ps1_exclude"):
		return

	# Skip Terrain3D — it manages its own shaders internally.
	if mesh_instance.get_class() == "Terrain3D":
		return
	var parent: Node = mesh_instance.get_parent()
	if parent != null and parent.get_class() == "Terrain3D":
		return

	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return

	var surface_count: int = mesh.get_surface_count()
	for i: int in range(surface_count):
		var existing: Material = mesh_instance.get_surface_override_material(i)
		if existing == null:
			existing = mesh.surface_get_material(i)

		# Already a PS1 shader material — just refresh uniforms.
		if existing is ShaderMaterial:
			var sm: ShaderMaterial = existing as ShaderMaterial
			if sm.shader == _shader:
				_set_ps1_uniforms(sm, null)
				continue

		# Build a new ShaderMaterial and copy properties from the old one.
		var ps1_mat: ShaderMaterial = ShaderMaterial.new()
		ps1_mat.shader = _shader
		_set_ps1_uniforms(ps1_mat, existing)
		mesh_instance.set_surface_override_material(i, ps1_mat)


func _set_ps1_uniforms(mat: ShaderMaterial, source: Material) -> void:
	# Always apply global knobs.
	mat.set_shader_parameter("snap_amount",     snap_amount)
	mat.set_shader_parameter("affine_strength", affine_strength)

	if source == null:
		return

	# Copy relevant properties from StandardMaterial3D / ORMMaterial3D.
	if source is BaseMaterial3D:
		var bm: BaseMaterial3D = source as BaseMaterial3D
		mat.set_shader_parameter("albedo_color",   bm.albedo_color)
		mat.set_shader_parameter("roughness",      bm.roughness)
		mat.set_shader_parameter("metallic",       bm.metallic)

		if bm.albedo_texture != null:
			mat.set_shader_parameter("albedo_texture", bm.albedo_texture)

		if bm is StandardMaterial3D:
			var sm3: StandardMaterial3D = bm as StandardMaterial3D
			if sm3.emission_enabled:
				mat.set_shader_parameter("emission_color",  sm3.emission)
				mat.set_shader_parameter("emission_energy", sm3.emission_energy_multiplier)
			if sm3.ao_enabled and sm3.ao_texture != null:
				mat.set_shader_parameter("ao_texture", sm3.ao_texture)

	elif source is ShaderMaterial:
		# If it's already a ShaderMaterial (not ours), try to copy common params.
		var other: ShaderMaterial = source as ShaderMaterial
		var color: Variant = other.get_shader_parameter("albedo_color")
		if color != null:
			mat.set_shader_parameter("albedo_color", color)
		var tex: Variant = other.get_shader_parameter("albedo_texture")
		if tex != null:
			mat.set_shader_parameter("albedo_texture", tex)


func _update_all_uniforms() -> void:
	if get_tree() == null:
		return
	_update_uniforms_recursive(get_tree().root)


func _update_uniforms_recursive(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null:
			return
		for i: int in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				var sm: ShaderMaterial = mat as ShaderMaterial
				if sm.shader == _shader:
					sm.set_shader_parameter("snap_amount",     snap_amount)
					sm.set_shader_parameter("affine_strength", affine_strength)
	for child: Node in node.get_children():
		_update_uniforms_recursive(child)
