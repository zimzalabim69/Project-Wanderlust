extends CharacterBody2D

func _physics_process(delta: float) -> void:
    velocity = Vector2.ZERO
    move_and_slide()
