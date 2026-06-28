class_name Collectible
extends Interactable

## Attach to a 3D object to make it a pickup. Adds itself to InventoryManager on interaction.

@export var item_id: String = ""
@export var title: String = ""
@export var text: String = ""
@export var icon: String = ""
@export var world_flag: String = ""
@export var destroy_on_pickup: bool = true

func _on_interact(_player: Node3D) -> void:
	if item_id.is_empty() or title.is_empty():
		return
	InventoryManager.collect(item_id, title, text, icon)
	if not world_flag.is_empty():
		GameState.set_flag(world_flag)
	if destroy_on_pickup:
		queue_free()
