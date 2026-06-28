class_name KeyLockedDoor
extends Interactable

## An interactable door that requires a specific inventory item to unlock.
## Optionally consumes the key, sets a GameState flag, disables target nodes,
## and can transition to another scene when unlocked.

signal unlocked()

@export var required_item_id: String = ""
@export var unlocked_flag: String = ""
@export var consume_key: bool = true
@export var unlock_message: String = "The door is unlocked."
@export var locked_message: String = "It's locked. You need a key."
@export var target_nodes: Array[NodePath] = []
@export var transition_scene: String = ""
@export var transition_spawn_id: String = "default"


func _ready() -> void:
	super._ready()
	if prompt_text == "Interact":
		prompt_text = "Open door"
	_check_unlocked_state()


func _on_interact(_player: Node3D) -> void:
	if _is_unlocked():
		if not transition_scene.is_empty():
			SceneTransition.change_scene(transition_scene, transition_spawn_id)
		return

	if required_item_id.is_empty():
		push_warning("KeyLockedDoor: required_item_id is empty.")
		return

	if InventoryManager.has(required_item_id):
		_unlock()
	else:
		print(locked_message)


func _is_unlocked() -> bool:
	if unlocked_flag.is_empty():
		return false
	return GameState.has_flag(unlocked_flag)


func _unlock() -> void:
	if not unlocked_flag.is_empty():
		GameState.set_flag(unlocked_flag)

	if consume_key:
		InventoryManager.remove(required_item_id)

	print(unlock_message)
	_set_targets_enabled(false)
	unlocked.emit()

	if not transition_scene.is_empty():
		SceneTransition.change_scene(transition_scene, transition_spawn_id)


func _check_unlocked_state() -> void:
	if _is_unlocked():
		_set_targets_enabled(false)


func _set_targets_enabled(enabled: bool) -> void:
	for path: NodePath in target_nodes:
		var node: Node = get_node_or_null(path)
		if node == null:
			continue
		if node is CollisionShape3D or node is CollisionPolygon3D:
			node.disabled = not enabled
		elif node is MeshInstance3D:
			node.visible = enabled
		elif node.has_method("set_enabled"):
			node.set_enabled(enabled)
		elif node.has_method("set_process"):
			node.set_process(enabled)
			node.set_physics_process(enabled)
		else:
			node.visible = enabled
