extends Node3D
class_name Interactable
## Attach to a prop root. Add a CollisionShape3D (or child mesh with collision) for ray hits.

signal interacted(player: Node3D)

@export var prompt_text: String = "Interact"
@export var enabled: bool = true
@export var one_shot: bool = false

var _used: bool = false


func _ready() -> void:
	add_to_group("interactable")


func can_interact() -> bool:
	return enabled and (not one_shot or not _used)


func interact(player: Node3D) -> void:
	if not can_interact():
		return
	_used = true
	interacted.emit(player)
	_on_interact(player)


func _on_interact(_player: Node3D) -> void:
	pass
