class_name SpiceMixSlot
extends Control

# One of the spice workshop's five mixing-bowl slots. Ingredients are dragged in
# from the catalogue and dragged back out to remove them, exactly like the
# cooking pot: dropping consumes one from inventory, detaching refunds it, and a
# plain click opens the ingredient's info panel.
var game:Node
var slot_index:=0
var ingredient_name:=""
var drag_started:=false
var suppress_next_release:=false

func setup(new_game:Node,index:int,current_name:String)->void:
	game=new_game;slot_index=index;ingredient_name=current_name
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var box:=StyleBoxFlat.new();box.bg_color=Color.WHITE;box.set_corner_radius_all(14);box.border_color=Color("#e0d8c4");box.set_border_width_all(2)
	var panel:=Panel.new();panel.add_theme_stylebox_override("panel",box);panel.position=Vector2.ZERO;panel.size=size;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
	if ingredient_name.is_empty():
		var plus:=Label.new();plus.text="+";plus.position=Vector2.ZERO;plus.size=size;plus.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;plus.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;plus.add_theme_font_size_override("font_size",42);plus.add_theme_color_override("font_color",GameData.COLORS.muted);plus.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(plus)
	else:
		var info:Dictionary=GameData.INGREDIENTS[ingredient_name]
		var texture:=GameData.ingredient_texture(info)
		if texture!=null:
			var icon:=Sprite2D.new();icon.texture=texture;icon.position=Vector2(size.x*.5,size.y*.42);var fit:=minf((size.x-24.0)/texture.get_width(),(size.y-42.0)/texture.get_height());icon.scale=Vector2.ONE*fit;add_child(icon)
		else:
			var icon:=Label.new();icon.text=str(info.icon);icon.position=Vector2(0,4);icon.size=Vector2(size.x,size.y-30);icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;icon.add_theme_font_size_override("font_size",34);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
		var name_label:=Label.new();name_label.text=ingredient_name;name_label.position=Vector2(4,size.y-26);name_label.size=Vector2(size.x-8,22);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.add_theme_font_size_override("font_size",11);name_label.add_theme_color_override("font_color",GameData.COLORS.ink);name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;name_label.clip_text=true;add_child(name_label)

func has_content()->bool:
	return not ingredient_name.is_empty()

func _can_drop_data(_at_position:Vector2,data:Variant)->bool:
	return data is Dictionary and data.get("kind","")=="ingredient" and game.can_place_spice_ingredient(str(data.get("name","")),slot_index)

func _drop_data(_at_position:Vector2,data:Variant)->void:
	game.place_spice_ingredient(slot_index,str(data.get("name","")))

func _get_drag_data(_at_position:Vector2)->Variant:
	if not has_content():return null
	var payload:Dictionary=game.detach_spice_ingredient_for_drag(slot_index)
	if payload.is_empty():return null
	drag_started=true;suppress_next_release=true
	for child in get_children():child.hide()
	var info:Dictionary=GameData.INGREDIENTS[str(payload.name)]
	var preview:=Control.new();var texture:=GameData.ingredient_texture(info)
	if texture!=null:
		var icon:=Sprite2D.new();icon.texture=texture;icon.position=Vector2.ZERO;var fit:=minf((size.x-8.0)/texture.get_width(),(size.y-8.0)/texture.get_height());icon.scale=Vector2.ONE*fit;preview.add_child(icon)
	else:
		var icon:=Label.new();icon.text=str(info.icon);icon.position=-size*.5;icon.size=size;icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;icon.add_theme_font_size_override("font_size",34);preview.add_child(icon)
	set_drag_preview(preview)
	return payload

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		if suppress_next_release:suppress_next_release=false
		elif has_content():game.select_cooking_ingredient(ingredient_name)

func _notification(what:int)->void:
	if what==NOTIFICATION_DRAG_END and drag_started:
		drag_started=false
		if is_instance_valid(game):game.call_deferred("finish_spice_mix_drag")
