class_name ExpeditionPortraitCooldown
extends Control

var actor:QuibletActor3D

func setup(new_actor:QuibletActor3D)->void:
	actor=new_actor;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(true);queue_redraw()

func _process(_delta:float)->void:
	queue_redraw()

func display_tint_ratio()->float:
	if not is_instance_valid(actor) or not actor.knocked_out:return 0.0
	return clampf(actor.revive_time/GameData.KNOCKOUT_REVIVE_SECONDS,0.0,1.0)

func _draw()->void:
	var ratio:=display_tint_ratio()
	if ratio<=0.0:return
	var center:=size*.5;var radius:=minf(size.x,size.y)*.48
	var points:=PackedVector2Array([center]);var start:=-PI*.5;var segments:=32
	for i in segments+1:
		var angle:=start+TAU*ratio*float(i)/float(segments)
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	draw_colored_polygon(points,Color(.05,.07,.11,.74))
