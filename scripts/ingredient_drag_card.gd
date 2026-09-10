class_name IngredientDragCard
extends Panel

var game: Node
var ingredient_name := ""
var unlocked := false
var draggable := false
var drag_started := false

func setup(new_game:Node,new_name:String,is_unlocked:bool,required:=3)->void:
	game=new_game;ingredient_name=new_name;unlocked=is_unlocked
	custom_minimum_size=Vector2(67,82);size=Vector2(67,82);clip_contents=true
	var count:=int(game.ingredients.get(ingredient_name,0)) if unlocked else 0
	draggable=unlocked and count>=required
	var info:Dictionary=GameData.INGREDIENTS[ingredient_name]
	var box:=StyleBoxFlat.new();box.bg_color=Color("#ffffff");box.set_corner_radius_all(12);box.border_color=Color("#d6d6d6");box.set_border_width_all(2);add_theme_stylebox_override("panel",box)
	var texture:=GameData.ingredient_texture(info) if unlocked else null
	if texture!=null:
		var icon:=Sprite2D.new();icon.texture=texture;icon.position=Vector2(33.5,32.5);var fit:=minf(51.0/texture.get_width(),55.0/texture.get_height());icon.scale=Vector2.ONE*fit;icon.modulate=Color.WHITE if draggable else Color("#666666");add_child(icon)
	else:
		var icon:=Label.new();icon.text=info.icon if unlocked else "?";icon.position=Vector2(0,8);icon.size=Vector2(67,52);icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;icon.add_theme_font_size_override("font_size",34);icon.add_theme_color_override("font_color",info.color if draggable else Color("#555555"));icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
	var amount:=Label.new();amount.name="IngredientAmount";amount.text=str(count);amount.position=Vector2(0,56);amount.size=Vector2(67,18);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;amount.add_theme_font_size_override("font_size",13);amount.add_theme_color_override("font_color",GameData.COLORS.ink if draggable else Color("#555555"));amount.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(amount)
	mouse_default_cursor_shape=Control.CURSOR_DRAG if draggable else Control.CURSOR_FORBIDDEN

func _get_drag_data(_at_position:Vector2)->Variant:
	if not draggable:return null
	drag_started=true
	var preview:=Control.new()
	var preview_size:=Vector2(74,74)
	var info:Dictionary=GameData.INGREDIENTS[ingredient_name];var texture:=GameData.ingredient_texture(info)
	if texture!=null:
		var icon:=Sprite2D.new();icon.texture=texture;icon.position=Vector2.ZERO;var fit:=minf(preview_size.x/texture.get_width(),preview_size.y/texture.get_height());icon.scale=Vector2.ONE*fit;preview.add_child(icon)
	else:
		var text:=Label.new();text.text=info.icon;text.position=-preview_size*.5;text.size=preview_size;text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;text.add_theme_font_size_override("font_size",32);preview.add_child(text)
	set_drag_preview(preview)
	return {"kind":"ingredient","name":ingredient_name}

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and unlocked:
		if not drag_started:game.select_cooking_ingredient(ingredient_name)
		drag_started=false

func _notification(what:int)->void:
	if what==NOTIFICATION_DRAG_END:drag_started=false
