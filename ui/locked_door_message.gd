extends CanvasLayer

## Brief popup that displays a message at the bottom of the screen and auto-hides.

@onready var _panel: PanelContainer = $PanelContainer
@onready var _label: Label = $PanelContainer/Label
@onready var _timer: Timer = $Timer

func _ready() -> void:
	_panel.visible = false
	_timer.one_shot = true
	_timer.timeout.connect(_hide)

func show_message(text: String, duration: float = 2.0) -> void:
	_label.text = text
	_panel.visible = true
	_timer.stop()
	_timer.wait_time = duration
	_timer.start()

func _hide() -> void:
	_panel.visible = false
