class_name ExpeditionMoveButton
extends Control

signal move_requested(actor:QuibletActor3D,index:int)

var actor:QuibletActor3D
var move_index:=0
var last_cooldown:=0.0
var ready_pulse:=0.0
var icon_texture:Texture2D

func setup(new_actor:QuibletActor3D,index:int)->void:
	actor=new_actor;move_index=index
	custom_minimum_size=Vector2(42,42);mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if is_instance_valid(actor) and move_index<actor.data.moves.size():
		var entry:Dictionary=actor.data.moves[move_index];var move:Dictionary=GameData.MOVES[entry.name]
		var icon_path:String=move.get("icon","")
		icon_texture=load(icon_path) if not icon_path.is_empty() else null
		tooltip_text="%s\n%s"%[entry.name,move.desc]
		last_cooldown=actor.move_cooldowns[move_index]
	set_process(true);queue_redraw()

func _process(delta:float)->void:
	if not is_instance_valid(actor) or move_index>=actor.move_cooldowns.size():return
	var current:=actor.move_cooldowns[move_index]
	if last_cooldown>.02 and current<=.02:ready_pulse=.38
	last_cooldown=current
	if ready_pulse>0.0:ready_pulse=maxf(0.0,ready_pulse-delta)
	queue_redraw()

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(actor) and actor.current_hp>0 and move_index<actor.move_cooldowns.size() and actor.move_cooldowns[move_index]<=0.0:
			move_requested.emit(actor,move_index)
		accept_event()

func _draw()->void:
	if not is_instance_valid(actor) or move_index>=actor.data.moves.size():return
	var entry:Dictionary=actor.data.moves[move_index];var move:Dictionary=GameData.MOVES[entry.name]
	var center:=size*.5;var radius:=minf(size.x,size.y)*.38
	var alive:=actor.current_hp>0
	var icon_rect:=Rect2(Vector2.ZERO,size)
	if icon_texture!=null:
		var texture_size:=icon_texture.get_size()
		var draw_size:=texture_size*minf(size.x/texture_size.x,size.y/texture_size.y)
		icon_rect=Rect2((size-draw_size)*.5,draw_size)
		draw_texture_rect(icon_texture,icon_rect,false)
	else:
		draw_circle(center,radius+4.0,Color("#f8fbff") if alive else Color("#777b80"))
		draw_circle(center,radius,move.color.darkened(.08) if alive else Color("#66696d"))
		_draw_move_glyph(center,radius,move)
	var cooldown:=actor.move_cooldowns[move_index] if move_index<actor.move_cooldowns.size() else 0.0
	var total:=actor.move_cooldown_totals[move_index] if move_index<actor.move_cooldown_totals.size() else 0.0
	var tint_ratio:=display_tint_ratio(cooldown,total)
	if tint_ratio>0.0:
		var ratio:=tint_ratio
		var points:=PackedVector2Array([center]);var start:=-PI*.5;var segments:=32
		for i in segments+1:
			var angle:=start+TAU*ratio*float(i)/float(segments)
			var direction:=Vector2(cos(angle),sin(angle))
			var distance:=radius+1.0
			if icon_texture!=null:
				distance=minf(icon_rect.size.x*.5/maxf(absf(direction.x),.0001),icon_rect.size.y*.5/maxf(absf(direction.y),.0001))
			points.append(center+direction*distance)
		draw_colored_polygon(points,Color(0.05,0.07,0.11,.72))
	if ready_pulse>0.0:
		var progress:=1.0-ready_pulse/.38
		var pulse_radius:=radius+4.0+progress*13.0
		if icon_texture!=null:draw_rect(icon_rect.grow(progress*13.0),Color(1,1,1,(1.0-progress)*.9),false,3.0)
		else:draw_arc(center,pulse_radius,0,TAU,40,Color(1,1,1,(1.0-progress)*.9),3.0)

func display_tint_ratio(cooldown:float=-1.0,total:float=-1.0)->float:
	if not is_instance_valid(actor) or actor.current_hp<=0.0:return 1.0
	if cooldown<0.0:cooldown=actor.move_cooldowns[move_index]
	if total<0.0:total=actor.move_cooldown_totals[move_index]
	return clampf(cooldown/total,0.0,1.0) if cooldown>0.0 and total>0.0 else 0.0

func _draw_move_glyph(center:Vector2,radius:float,move:Dictionary)->void:
	var white:=Color(1,1,1,.94)
	match str(move.kind):
		"projectile":
			var arrow:=PackedVector2Array([center+Vector2(-radius*.55,radius*.18),center+Vector2(radius*.1,radius*.18),center+Vector2(radius*.1,radius*.48),center+Vector2(radius*.65,0),center+Vector2(radius*.1,-radius*.48),center+Vector2(radius*.1,-radius*.18),center+Vector2(-radius*.55,-radius*.18)])
			draw_colored_polygon(arrow,white)
		"recover":
			draw_rect(Rect2(center-Vector2(radius*.18,radius*.62),Vector2(radius*.36,radius*1.24)),white)
			draw_rect(Rect2(center-Vector2(radius*.62,radius*.18),Vector2(radius*1.24,radius*.36)),white)
		_:
			draw_circle(center,radius*.27,white)
			for i in 8:
				var direction:=Vector2.from_angle(float(i)*TAU/8.0)
				draw_line(center+direction*radius*.42,center+direction*radius*.72,white,3.0)
	# Small pips make moves with the same behavior visually distinct without putting names on the button.
	var pip_count:=absi(str(entry_name(move)).hash())%3+1
	for i in pip_count:draw_circle(center+Vector2((i-(pip_count-1)*.5)*6.0,radius*.72),1.6,white)

func entry_name(move:Dictionary)->String:
	if is_instance_valid(actor) and move_index<actor.data.moves.size():return str(actor.data.moves[move_index].name)
	return str(move.get("kind","move"))
