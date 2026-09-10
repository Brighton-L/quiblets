class_name TrainingDropSlot
extends Panel

# A trainee, helper, or food socket on the Training screen. Quiblet sockets take
# roster cards; the food socket takes one ingredient. Right-click clears a socket.
var game:Node
var role:="trainee"
var slot_index:=0
var occupant:Variant=-1

func setup(new_game:Node,new_role:String,index:int,current:Variant)->void:
	game=new_game;role=new_role;slot_index=index;occupant=current
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	tooltip_text="Right-click to clear" if has_content() else ("Drop one ingredient here" if role=="food" else "Drop a Quiblet here")

func accepts_kind()->String:
	return "ingredient" if role=="food" else "quiblet"

func has_content()->bool:
	if role=="food":return occupant is String and not str(occupant).is_empty()
	return int(occupant)>=0

func _can_drop_data(_at_position:Vector2,data:Variant)->bool:
	return data is Dictionary and data.get("kind","")==accepts_kind() and game.can_assign_training(role,slot_index,data)

func _drop_data(_at_position:Vector2,data:Variant)->void:
	game.assign_training_slot(role,slot_index,data)

func _get_drag_data(_at_position:Vector2)->Variant:
	if not has_content():return null
	var preview:=duplicate();preview.modulate.a=.86;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;set_drag_preview(preview)
	if role=="food":return {"kind":"ingredient","name":str(occupant),"training_source":[role,slot_index]}
	return {"kind":"quiblet","roster_index":int(occupant),"training_source":[role,slot_index]}

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and has_content():game.clear_training_slot(role,slot_index)
