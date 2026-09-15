class_name StoneInventoryCard
extends Panel

const POWER_STONE_ICON_SCRIPT:=preload("res://scripts/power_stone_icon.gd")

signal chosen(data: Dictionary)

var item_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	item_data = data
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		chosen.emit(item_data)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_data.is_empty() or item_data.get("fitted",false):
		return null
	set_drag_preview(create_stone_drag_preview())
	return item_data

func create_stone_drag_preview()->Control:
	if item_data.get("kind","")=="power_stone":
		var power_preview:=Control.new();power_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var power_icon:=POWER_STONE_ICON_SCRIPT.new();power_icon.size=Vector2(64,64);power_icon.position=-power_icon.size*.5;power_icon.setup(item_data);power_preview.add_child(power_icon)
		return power_preview
	var preview:=Control.new()
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var icon:=TextureRect.new()
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture=load(str(item_data.texture)) if item_data.get("kind","")=="charm" else load(GameData.stone_info(str(item_data.effect)).texture)
	icon.size=Vector2(56,56)
	icon.position=-icon.size*.5
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	preview.add_child(icon)
	return preview
