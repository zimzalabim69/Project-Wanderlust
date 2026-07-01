extends CanvasLayer

## Simple inventory UI panel to read collected notes and items.

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var text_label: RichTextLabel = $Panel/VBox/HSplit/TextVBox/Text
@onready var item_list: ItemList = $Panel/VBox/HSplit/ItemList
@onready var close_button: Button = $Panel/VBox/CloseButton

var _reading_mode: bool = false

func _ready() -> void:
	panel.visible = false
	InventoryManager.inventory_opened.connect(_open)
	InventoryManager.inventory_closed.connect(_close)
	InventoryManager.readable_opened.connect(_open_readable)
	InventoryManager.readable_closed.connect(_close)
	close_button.pressed.connect(_on_close)
	item_list.item_selected.connect(_on_item_selected)

func _input(event: InputEvent) -> void:
	if InventoryManager.is_reading:
		if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel") \
				or event.is_action_pressed("interact"):
			InventoryManager.close_readable()
			get_viewport().set_input_as_handled()
			return
	elif InventoryManager.is_open:
		if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
			InventoryManager.close_inventory()
			get_viewport().set_input_as_handled()
			return
	else:
		if event.is_action_pressed("toggle_inventory"):
			InventoryManager.open_inventory()
			get_viewport().set_input_as_handled()
			return

func _open() -> void:
	panel.visible = true
	_refresh_list()
	if item_list.item_count > 0:
		item_list.select(0)
		_on_item_selected(0)

func _refresh_list() -> void:
	item_list.clear()
	for item in InventoryManager.items:
		item_list.add_item(item.title)

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= InventoryManager.items.size():
		return
	var item: Dictionary = InventoryManager.items[index]
	title_label.text = item.title
	text_label.text = item.text

## Opens the panel showing a single non-collected readable text.
## The item list is hidden; only title + body are shown.
func _open_readable(readable_title: String, body: String) -> void:
	_reading_mode = true
	panel.visible = true
	item_list.visible = false
	title_label.text = readable_title
	text_label.text = body


func _close() -> void:
	panel.visible = false
	if _reading_mode:
		_reading_mode = false
		item_list.visible = true


func _on_close() -> void:
	if _reading_mode:
		InventoryManager.close_readable()
	else:
		InventoryManager.close_inventory()
