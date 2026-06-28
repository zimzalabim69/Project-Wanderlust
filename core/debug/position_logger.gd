extends Node
## Press P to print player position to Output panel.

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player:
			print("=== PLAYER POSITION ===")
			print("X: ", player.global_position.x)
			print("Y: ", player.global_position.y)
			print("Z: ", player.global_position.z)
			print("Copy these numbers and send them to me!")
