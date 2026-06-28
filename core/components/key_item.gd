class_name KeyItem
extends Collectible

## A collectible key item. Thin wrapper that defaults prompt text to "Pick up key".

func _ready() -> void:
	super._ready()
	if prompt_text == "Interact":
		prompt_text = "Pick up key"
