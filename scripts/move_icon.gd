class_name MoveIcon
extends Control

signal selected(move_name:String)
signal move_dropped(source_index:int,target_index:int)
signal move_slot_dropped(source_index:int,target_index:int)

var move_name := ""
var icon_texture:Texture2D
var move_index := -1
var suppress_next_release:=false

func setup(value: String,index: int = -1) -> void:
	move_name = value
	var icon_path:String=GameData.MOVES.get(value,{}).get("icon","")
	icon_texture=load(icon_path) if not icon_path.is_empty() else null
	move_index = index
	tooltip_text = value
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	queue_redraw()

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		if suppress_next_release:suppress_next_release=false
		else:selected.emit(move_name)

func _get_drag_data(_at_position:Vector2)->Variant:
	if move_index<0:return null
	var preview:=MoveIcon.new();preview.setup(move_name);preview.size=size;preview.modulate.a=.86;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;set_drag_preview(preview);suppress_next_release=true
	return {"kind":"quiblet_move","move_index":move_index,"move_name":move_name}

func _can_drop_data(_at_position:Vector2,data:Variant)->bool:
	# Another move swaps places; an empty Move Stone slot from another move joins this move.
	return move_index>=0 and data is Dictionary and data.get("kind","") in ["quiblet_move","move_slot"] and int(data.get("move_index",-1))!=move_index

func _drop_data(_at_position:Vector2,data:Variant)->void:
	if data.get("kind","")=="move_slot":move_slot_dropped.emit(int(data.move_index),move_index)
	else:move_dropped.emit(int(data.move_index),move_index)

func _notification(what:int)->void:
	if what==NOTIFICATION_DRAG_END:call_deferred("_clear_drag_release_guard")

func _clear_drag_release_guard()->void:
	suppress_next_release=false

func _draw() -> void:
	if move_name.is_empty() or not GameData.MOVES.has(move_name):
		return
	if icon_texture!=null:
		var texture_size:=icon_texture.get_size()
		var draw_size:=texture_size*minf(size.x/texture_size.x,size.y/texture_size.y)
		draw_texture_rect(icon_texture,Rect2((size-draw_size)*.5,draw_size),false)
		return
	var move: Dictionary = GameData.MOVES[move_name]
	var color := GameData.COLORS.water
	match str(move.kind):
		"recover": color = GameData.COLORS.leaf
		"burst": color = GameData.COLORS.coral
		"dash": color = GameData.COLORS.gold
	var center := size * .5
	draw_circle(center, minf(size.x, size.y) * .42, Color(color, .19))
	draw_arc(center, minf(size.x, size.y) * .42, 0, TAU, 32, color, 2.5)
	match str(move.kind):
		"recover":
			draw_rect(Rect2(center - Vector2(4, 13), Vector2(8, 26)), color)
			draw_rect(Rect2(center - Vector2(13, 4), Vector2(26, 8)), color)
		"burst":
			for i in 8:
				var direction := Vector2.RIGHT.rotated(float(i) * TAU / 8.0)
				draw_line(center + direction * 7.0, center + direction * 17.0, color, 4.0)
		_:
			var points := PackedVector2Array([center + Vector2(-13, -7), center + Vector2(6, -7), center + Vector2(6, -13), center + Vector2(17, 0), center + Vector2(6, 13), center + Vector2(6, 7), center + Vector2(-13, 7)])
			draw_colored_polygon(points, color)
