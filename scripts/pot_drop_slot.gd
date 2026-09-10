class_name PotDropSlot
extends Control

var game:Node
var slot_index:=0
var slot_kind:="ingredient"
var content_data:Variant=""
var drag_started:=false
var suppress_next_release:=false

func setup(new_game:Node,index:int,new_kind:String,current_data:Variant)->void:
	game=new_game;slot_index=index;slot_kind=new_kind;content_data=current_data
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if not has_content():
		if slot_kind!="ingredient":tooltip_text=("Spice" if slot_kind=="spice" else "Special ingredient")+" slot"
	else:
		var display:Dictionary=game.cooking_slot_display(slot_kind,content_data)
		var texture:=GameData.ingredient_texture(display) if slot_kind=="ingredient" else null
		var texture_path:=str(display.get("texture",""))
		if texture==null and not texture_path.is_empty() and ResourceLoader.exists(texture_path):texture=load(texture_path)
		if texture!=null:
			var icon:=Sprite2D.new();icon.texture=texture;icon.position=size*.5;var fit:=minf((size.x-12.0)/texture.get_width(),(size.y-12.0)/texture.get_height());icon.scale=Vector2.ONE*fit;add_child(icon)
		else:
			var icon:=Label.new();icon.text=display.icon;icon.position=Vector2.ZERO;icon.size=size;icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;icon.add_theme_font_size_override("font_size",34);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
		if slot_kind!="ingredient":tooltip_text=display.tooltip+" — right-click to remove"

func _can_drop_data(_at_position:Vector2,data:Variant)->bool:
	return data is Dictionary and data.get("kind","")==slot_kind and game.can_drop_cooking_item(slot_kind,data,slot_index)

func _drop_data(_at_position:Vector2,data:Variant)->void:
	game.assign_cooking_item(slot_kind,slot_index,data)

func _get_drag_data(_at_position:Vector2)->Variant:
	if not has_content():return null
	var display:Dictionary=game.cooking_slot_display(slot_kind,content_data)
	var payload:Dictionary=game.detach_cooking_item_for_drag(slot_kind,slot_index)
	if payload.is_empty():return null
	drag_started=true;suppress_next_release=true
	for child in get_children():child.hide()
	var preview:=Control.new()
	var preview_size:=size
	var texture:=GameData.ingredient_texture(display) if slot_kind=="ingredient" else null
	var texture_path:=str(display.get("texture",""))
	if texture==null and not texture_path.is_empty() and ResourceLoader.exists(texture_path):texture=load(texture_path)
	if texture!=null:
		var icon:=Sprite2D.new();icon.texture=texture;icon.position=Vector2.ZERO;var fit:=minf((preview_size.x-8.0)/texture.get_width(),(preview_size.y-8.0)/texture.get_height());icon.scale=Vector2.ONE*fit;preview.add_child(icon)
	else:
		var icon:=Label.new();icon.text=str(display.get("icon","?"));icon.position=-preview_size*.5;icon.size=preview_size;icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;icon.add_theme_font_size_override("font_size",34);preview.add_child(icon)
	set_drag_preview(preview)
	return payload

func _gui_input(event:InputEvent)->void:
	if slot_kind!="ingredient" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and has_content():game.clear_cooking_item(slot_kind,slot_index,true)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		# A click without a drag opens the placed item's info.
		if suppress_next_release:suppress_next_release=false
		elif has_content() and game.has_method("inspect_cooking_item"):game.inspect_cooking_item(slot_kind,slot_index)

func has_content()->bool:
	return not (content_data==null or (content_data is String and content_data.is_empty()) or (content_data is Dictionary and content_data.is_empty()))

func _notification(what:int)->void:
	if what==NOTIFICATION_DRAG_END and drag_started:
		drag_started=false
		if is_instance_valid(game):game.call_deferred("finish_cooking_slot_drag")
