extends Panel
var garden
var index:=0
func _can_drop_data(_position:Vector2,data:Variant)->bool:
	return data is Dictionary and data.get("kind","")=="ingredient" and garden.can_place(str(data.get("name","")),index)
func _drop_data(_position:Vector2,data:Variant)->void:
	garden.slots[index]=str(data.name);garden.call_deferred("draw_menu")
func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
		garden.slots[index]="";garden.call_deferred("draw_menu")
