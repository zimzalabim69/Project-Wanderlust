extends Node

class_name EnvironmentCheck

@export var player_health: int = 100

func _ready() -> void:
	tree_entered.connect(func(): print("LSP is alive - Environment check passed!"))
