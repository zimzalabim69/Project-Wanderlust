extends CharacterBody3D

var speed: float = 2.0
var sprint_multiplier: float = 3.5
const MOUSE_SENSITIVITY: float = 0.003
const INTERACT_DISTANCE: float = 2.5
const FOOTSTEP_INTERVAL: float = 0.55
const FOOTSTEP_SPEED_FACTOR: float = 1.2

@export var footstep_sounds: Array[AudioStream] = []

@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var interact_prompt: Label = $UI/InteractPrompt
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@onready var ground_ray: RayCast3D = $GroundRay

var _mouse_captured: bool = true
var _current_interactable: Interactable = null
var _footstep_timer: float = 0.0
var _was_on_floor: bool = false
var _sprinting: bool = false
var _auto_running: bool = false


func _ready() -> void:
	add_to_group("player")
	_capture_mouse()
	interact_ray.target_position = Vector3(0.0, 0.0, -INTERACT_DISTANCE)
	if interact_prompt != null:
		interact_prompt.visible = false
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_mouse()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if not get_tree().paused and not _is_on_title_screen():
			_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if DevConsole.is_open:
		return
	if LevelEditor.active:
		return

	if InventoryManager.is_open:
		if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
			InventoryManager.close_inventory()
			get_viewport().set_input_as_handled()
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_capture_mouse()
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if DevMode.is_freecam():
		return

	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mouse_motion.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-mouse_motion.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

	if event.is_action_pressed("toggle_flashlight"):
		flashlight.visible = not flashlight.visible

	if event.is_action_pressed("sprint"):
		_sprinting = not _sprinting

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_toggle_auto_run()

	if event.is_action_pressed("interact"):
		_try_interact()

	if event.is_action_pressed("toggle_inventory"):
		InventoryManager.open_inventory()
		get_viewport().set_input_as_handled()
		_release_mouse()


func _physics_process(delta: float) -> void:
	if DevMode.is_noclip():
		_update_interact_prompt()
		return

	if not is_on_floor():
		velocity.y -= 9.8 * delta

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _auto_running:
		if Input.is_action_pressed("move_back"):
			_auto_running = false
			_sprinting = false
		else:
			input_dir.y = -1.0
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not DevConsole.is_open and not LevelEditor.active:
		input_dir.y = -1.0
	input_dir = input_dir.normalized()
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var current_speed: float = speed * (sprint_multiplier if _sprinting else 1.0)

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()
	_update_interact_prompt()

	if is_on_floor():
		var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		if horizontal_velocity.length() > 0.1:
			_footstep_timer -= delta * (velocity.length() / speed) * FOOTSTEP_SPEED_FACTOR
			if _footstep_timer <= 0.0:
				_play_footstep()
				_footstep_timer = FOOTSTEP_INTERVAL
		else:
			_footstep_timer = FOOTSTEP_INTERVAL
	else:
		_footstep_timer = FOOTSTEP_INTERVAL * 0.5

	_was_on_floor = is_on_floor()


func _update_interact_prompt() -> void:
	if interact_prompt == null or InventoryManager.is_open:
		return
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		_current_interactable = null
		interact_prompt.visible = false
		return
	var collider: Object = interact_ray.get_collider()
	if collider == null or not (collider is Node):
		_current_interactable = null
		interact_prompt.visible = false
		return
	var found: Interactable = _find_interactable(collider as Node)
	if found != null and found.can_interact():
		_current_interactable = found
		interact_prompt.text = "[E] " + found.prompt_text
		interact_prompt.visible = true
	else:
		_current_interactable = null
		interact_prompt.visible = false


func _try_interact() -> void:
	if InventoryManager.is_open or _current_interactable == null:
		return
	_current_interactable.interact(self)


func _find_interactable(start: Node) -> Interactable:
	var current: Node = start
	while current:
		if current is Interactable:
			return current as Interactable
		current = current.get_parent()
	return null


func _toggle_mouse_capture() -> void:
	if _mouse_captured:
		_release_mouse()
	else:
		_capture_mouse()


func _toggle_auto_run() -> void:
	if _auto_running:
		_auto_running = false
		_sprinting = false
		print("Auto-run OFF")
	else:
		var moving_forward: bool = Input.is_action_pressed("move_forward") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not DevConsole.is_open and not LevelEditor.active)
		if moving_forward:
			_auto_running = true
			_sprinting = true
			print("Auto-run ON")


func _capture_mouse() -> void:
	_mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _is_on_title_screen() -> bool:
	var current_scene: Node = get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == "res://scenes/ui/title_screen.tscn"


func _release_mouse() -> void:
	_mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _play_footstep() -> void:
	var surface_type: String = "unknown"
	if ground_ray.is_colliding():
		var collider: Object = ground_ray.get_collider()
		if collider is Node:
			var collider_node: Node = collider as Node
			if collider_node.is_in_group("surface_wood"):
				surface_type = "wood"
			elif collider_node.is_in_group("surface_snow"):
				surface_type = "snow"
			elif collider_node.is_in_group("surface_concrete"):
				surface_type = "concrete"
			elif collider_node.is_in_group("surface_metal"):
				surface_type = "metal"

	print("Footstep on %s" % surface_type)

	if not footstep_sounds.is_empty():
		var random_index: int = randi() % footstep_sounds.size()
		var sound: AudioStream = footstep_sounds[random_index]
		footstep_player.stream = sound
		footstep_player.play()
