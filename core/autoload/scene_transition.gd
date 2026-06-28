extends CanvasLayer
## Full-screen fade wrapper around scene changes.

const DEFAULT_FADE_SECONDS: float = 0.6

@onready var _overlay: ColorRect = $Overlay

var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func change_scene(
	target_scene: String,
	spawn_id: String = "default",
	fade_seconds: float = DEFAULT_FADE_SECONDS
) -> void:
	if _busy:
		return
	if target_scene.is_empty():
		push_warning("SceneTransition: target_scene is empty.")
		return

	_busy = true
	GameState.pending_spawn_id = spawn_id
	await _fade_to_black(fade_seconds)
	var err: Error = get_tree().change_scene_to_file(target_scene)
	if err != OK:
		push_error("SceneTransition: failed to load scene '%s', error: %s" % [target_scene, error_string(err)])
		await _fade_from_black(fade_seconds)
		_busy = false
		return
	await get_tree().process_frame
	await _fade_from_black(fade_seconds)
	_busy = false


func _fade_to_black(duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, duration)
	await tween.finished


func _fade_from_black(duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	await tween.finished
