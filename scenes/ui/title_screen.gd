extends CanvasLayer
## Title screen for Project Wanderlust.

@onready var background: ColorRect = $Background
@onready var center_container: CenterContainer = $CenterContainer
@onready var main_vbox: VBoxContainer = $CenterContainer/MainVBox
@onready var title_label: Label = $CenterContainer/MainVBox/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/MainVBox/SubtitleLabel
@onready var button_vbox: VBoxContainer = $CenterContainer/MainVBox/ButtonVBox
@onready var new_game_button: Button = $CenterContainer/MainVBox/ButtonVBox/NewGameButton
@onready var continue_button: Button = $CenterContainer/MainVBox/ButtonVBox/ContinueButton
@onready var quit_button: Button = $CenterContainer/MainVBox/ButtonVBox/QuitButton
@onready var controls_label: Label = $ControlsLabel
@onready var snow_particles: GPUParticles2D = $SnowParticles


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	new_game_button.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)
	quit_button.pressed.connect(_on_quit)

	continue_button.visible = SaveManager.has_save()

	_start_pulse_animation()


func _on_new_game() -> void:
	SaveManager.new_game()


func _on_continue() -> void:
	SaveManager.load_game()


func _on_quit() -> void:
	get_tree().quit()


func _start_pulse_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(subtitle_label, "modulate:a", 0.4, 2.0)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 2.0)
