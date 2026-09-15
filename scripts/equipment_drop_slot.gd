class_name EquipmentDropSlot
extends TextureRect

signal equipment_dropped(slot_kind: String, primary_index: int, secondary_index: int, data: Dictionary)
signal remove_requested(slot_kind: String, primary_index: int, secondary_index: int)

var slot_kind := "power"
var primary_index := 0
var secondary_index := -1
var accepted_power_type := ""
var move_entry: Dictionary = {}
var controller: Node
var equipment_drag_started:=false
var locked:=false
var suppress_next_release:=false

func setup(kind: String, first_index: int, second_index: int, accepted_type: String, entry: Dictionary, owner_controller: Node) -> void:
	slot_kind = kind
	primary_index = first_index
	secondary_index = second_index
	accepted_power_type = accepted_type
	move_entry = entry
	controller = owner_controller
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or locked:
		return false
	# An empty Move Stone slot dragged from another move lands on any of this move's slots.
	if data.get("kind", "") == "move_slot":
		return slot_kind == "move" and int(data.get("move_index", -1)) != primary_index and controller != null and controller.can_receive_move_slot(primary_index)
	if slot_kind == "charm":
		return data.get("kind","")=="charm" and controller!=null and controller.charm_slot_accepts(primary_index,str(data.get("charm_type","")))
	if slot_kind == "power":
		return data.get("kind", "") == "power_stone" and (accepted_power_type.is_empty() or data.get("stone_type", "") == accepted_power_type)
	if data.get("kind", "") != "move_stone":
		return false
	return controller != null and controller.stone_compatible(str(data.effect), move_entry)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.get("kind", "") == "move_slot":
		if controller != null:controller.transfer_move_slot(int(data.move_index), primary_index)
		return
	equipment_dropped.emit(slot_kind, primary_index, secondary_index, data)

func _get_drag_data(_at_position:Vector2)->Variant:
	if controller==null or locked:return null
	# An empty Move Stone slot is itself draggable: dropping it on another move
	# moves the slot capacity across. Fitted slots drag their stone instead.
	if slot_kind=="move" and controller.move_slot_is_empty(primary_index,secondary_index):
		if get_viewport()!=null and get_viewport().gui_is_dragging():set_drag_preview(create_move_slot_drag_preview())
		equipment_drag_started=true;suppress_next_release=true
		return {"kind":"move_slot","move_index":primary_index,"slot_index":secondary_index}
	var data:Dictionary=controller.take_equipment_for_drag(slot_kind,primary_index,secondary_index)
	if data.is_empty():return null
	var preview:=create_equipment_drag_preview(data)
	set_drag_preview(preview);equipment_drag_started=true;suppress_next_release=true
	return data

func create_move_slot_drag_preview()->Control:
	var slot_preview:=Control.new();slot_preview.size=size;slot_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var art:=TextureRect.new();art.texture=texture;art.expand_mode=expand_mode;art.stretch_mode=stretch_mode;art.size=size;art.position=-size*.5;art.modulate.a=.85;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot_preview.add_child(art)
	return slot_preview

func create_equipment_drag_preview(data:Dictionary)->Control:
	if slot_kind=="charm":
		var charm_preview:=Control.new();charm_preview.size=size;charm_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		controller.add_charm_icon(charm_preview,str(data.charm_type),-size*.5,size)
		return charm_preview
	if slot_kind=="move":
		var preview:=Control.new();preview.size=size;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		controller.add_fitted_move_stone(preview,str(data.effect))
		preview.get_child(0).position=-size*.5
		return preview
	var preview:=Control.new();preview.size=size;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	controller.add_power_stone_icon(preview,data,-size*.5,size)
	return preview

func _notification(what:int)->void:
	if what==NOTIFICATION_DRAG_END and equipment_drag_started:
		equipment_drag_started=false
		if controller!=null:controller.finish_equipment_drag()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		remove_requested.emit(slot_kind, primary_index, secondary_index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		# A click without a drag opens the fitted stone's info panel.
		if suppress_next_release:suppress_next_release=false
		elif controller!=null and controller.has_method("inspect_equipment"):controller.inspect_equipment(slot_kind,primary_index,secondary_index)
