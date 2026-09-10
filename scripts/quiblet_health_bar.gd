class_name QuibletHealthBar
extends Control

var actor:QuibletActor3D
var world_camera:Camera3D

func setup(new_actor:QuibletActor3D,new_camera:Camera3D)->void:
	actor=new_actor;world_camera=new_camera
	size=Vector2(58,9);mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=20
	set_process(true);update_bar()

func _process(_delta:float)->void:
	update_bar()

func update_bar()->void:
	if not is_instance_valid(actor) or not is_instance_valid(world_camera):visible=false;return
	var damaged:=actor.current_hp>0.0 and actor.current_hp<actor.max_hp-.1
	if not damaged or world_camera.is_position_behind(actor.global_position):visible=false;return
	visible=true
	var screen_position:=world_camera.unproject_position(actor.global_position+Vector3(0,2.05,0))
	position=screen_position-size*.5
	queue_redraw()

func _draw()->void:
	if not is_instance_valid(actor):return
	var ratio:=clampf(actor.current_hp/maxf(actor.max_hp,1.0),0.0,1.0)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.08,0.1,0.13,.9),true)
	draw_rect(Rect2(Vector2(2,2),Vector2((size.x-4.0)*ratio,size.y-4.0)),GameData.COLORS.coral if actor.enemy else GameData.COLORS.leaf,true)
	draw_rect(Rect2(Vector2.ZERO,size),Color(1,1,1,.9),false,1.5)
