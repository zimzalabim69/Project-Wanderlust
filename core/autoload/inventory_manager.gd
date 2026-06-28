extends Node

## Tracks collected notes, letters, Polaroids, and small items.

signal item_collected(item_id: String, item_data: Dictionary)
signal item_removed(item_id: String)
signal inventory_opened
signal inventory_closed

var items: Array[Dictionary] = []
var item_ids: Dictionary = {}
var is_open: bool = false

func collect(item_id: String, title: String, text: String, icon: String = "") -> void:
	if item_ids.has(item_id):
		return
	var data: Dictionary = {
		"id": item_id,
		"title": title,
		"text": text,
		"icon": icon,
	}
	items.append(data)
	item_ids[item_id] = true
	item_collected.emit(item_id, data)

func has(item_id: String) -> bool:
	return item_ids.get(item_id, false)

func get_item(item_id: String) -> Dictionary:
	for item in items:
		if item.id == item_id:
			return item
	return {}

func toggle_inventory() -> void:
	if is_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	is_open = true
	inventory_opened.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_inventory() -> void:
	is_open = false
	inventory_closed.emit()
	_capture_mouse_next_frame()


func _capture_mouse_next_frame() -> void:
	await get_tree().process_frame
	if not is_open and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func reset() -> void:
	items.clear()
	item_ids.clear()
	close_inventory()


func remove(item_id: String) -> bool:
	if not item_ids.has(item_id):
		return false
	item_ids.erase(item_id)
	for i: int in range(items.size()):
		if items[i].get("id", "") == item_id:
			items.remove_at(i)
			break
	item_removed.emit(item_id)
	return true


func clear() -> void:
	items.clear()
	item_ids.clear()
	is_open = false
