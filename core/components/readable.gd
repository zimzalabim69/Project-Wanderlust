class_name Readable
extends Interactable
## A readable object: shows text on-screen when interacted with, but stays
## in the world (not collected). Good for newspapers, writing on walls, signs,
## notices pinned to things — objects too big or too mundane to pocket.
##
## Text is displayed via InventoryPanel in "read" mode.
## Press E / Tab / Esc to dismiss.

@export var title: String = ""
@export_multiline var body_text: String = ""
@export var world_flag: String = ""


func _on_interact(_player: Node3D) -> void:
	if title.is_empty() and body_text.is_empty():
		return

	# Set world flag first (e.g. track "read the newspaper").
	if not world_flag.is_empty():
		GameState.set_flag(world_flag)

	# Show via InventoryPanel readable mode.
	InventoryManager.show_readable(title, body_text)
