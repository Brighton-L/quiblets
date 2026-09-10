class_name TeamDropSlot
extends Panel

signal quiblet_dropped(slot_index: int, roster_index: int)
signal remove_requested(slot_index: int)

var slot_index := 0
var roster_index := -1
var controller:Node
var team_drag_started:=false

func setup(index: int, occupant_roster_index := -1, owner_controller:Node=null) -> void:
	slot_index = index
	roster_index = occupant_roster_index
	controller=owner_controller
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _get_drag_data(_at_position:Vector2)->Variant:
	if roster_index<0:return null
	if controller!=null:
		var data:Dictionary=controller.take_team_member_for_drag(slot_index,roster_index)
		if data.is_empty():return null
		var preview:=duplicate();preview.modulate.a=.86;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;set_drag_preview(preview);team_drag_started=true
		return data
	var preview:=duplicate();preview.modulate.a=.86;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;set_drag_preview(preview)
	return {"kind":"quiblet","roster_index":roster_index}

func _notification(what:int)->void:
	if what==NOTIFICATION_DRAG_END and team_drag_started:
		team_drag_started=false
		if controller!=null:controller.finish_team_drag()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind", "") == "quiblet"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	quiblet_dropped.emit(slot_index, int(data.roster_index))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		remove_requested.emit(slot_index)
