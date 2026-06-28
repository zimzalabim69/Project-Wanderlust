extends CanvasLayer
## Pause menu overlay. Toggled with Escape (ui_cancel) when not in inventory.

@onready var overlay: ColorRect = $Overlay
@onready var center_container: CenterContainer = $CenterContainer
@onready var main_vbox: VBoxContainer = $CenterContainer/MainVBox
@onready var title_label: Label = $CenterContainer/MainVBox/TitleLabel
@onready var button_vbox: VBoxContainer = $CenterContainer/MainVBox/ButtonVBox
@onready var resume_button: Button = $CenterContainer/MainVBox/ButtonVBox/ResumeButton
@onready var settings_button: Button = $CenterContainer/MainVBox/ButtonVBox/SettingsButton
@onready var save_quit_button: Button = $CenterContainer/MainVBox/ButtonVBox/SaveQuitButton
@onready var quit_desktop_button: Button = $CenterContainer/MainVBox/ButtonVBox/QuitDesktopButton

var _is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	overlay.visible = false
	center_container.visible = false

	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	save_quit_button.pressed.connect(_on_save_quit)
	quit_desktop_button.pressed.connect(_on_quit_desktop)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not _is_paused and not _is_on_title_screen():
			_toggle_pause()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if DevConsole.is_open:
		return
	if LevelEditor.active:
		return

	if InventoryManager.is_open:
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path == "res://scenes/ui/title_screen.tscn":
		return

	get_viewport().set_input_as_handled()
	_toggle_pause()


func _toggle_pause() -> void:
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	overlay.visible = _is_paused
	center_container.visible = _is_paused

	if _is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_capture_mouse_next_frame()


func _capture_mouse_next_frame() -> void:
	await get_tree().process_frame
	if not _is_paused and not _is_on_title_screen() and not InventoryManager.is_open and not DevConsole.is_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _is_on_title_screen() -> bool:
	var current_scene: Node = get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == "res://scenes/ui/title_screen.tscn"


func _on_resume() -> void:
	_toggle_pause()


func _on_settings() -> void:
	print("Settings menu placeholder.")


func _on_save_quit() -> void:
	SaveManager.save_game()
	get_tree().paused = false
	await SceneTransition.change_scene("res://scenes/ui/title_screen.tscn")


func _on_quit_desktop() -> void:
	get_tree().quit()
