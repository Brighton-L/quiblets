extends Node

var game
var arrivals:Array[Dictionary]=[]
var index:=0
var can_continue:=false
var actor:Node3D
var model:QuibletModel3D
var cards:Control
var hint:Label
var saved_camera:Transform3D
var saved_fov:=48.0
var materials:Array=[]

func setup(owner_game,visitors:Array[Dictionary])->void:
	game=owner_game;arrivals=visitors;index=int(game.completed_stew_result.get("revealed_count",0))
	saved_camera=game.camera_3d.transform;saved_fov=game.camera_3d.fov
	for indicator_name in ["CookingReadyIndicator","CookingProgressIndicator"]:
		var indicator=game.world_root.get_node_or_null(indicator_name)
		if indicator:indicator.visible=false
	game.camp_pan_dragging=false;game.stop_primary_music()
	show_next()

func pose_camera(position:Vector3,focus:Vector3)->void:
	game.camera_3d.position=position;game.camera_3d.look_at(focus,Vector3.UP)

func camera_to(position:Vector3,focus:Vector3,duration:float)->Tween:
	var start:Transform3D=game.camera_3d.transform
	pose_camera(position,focus);var finish:Transform3D=game.camera_3d.transform;game.camera_3d.transform=start
	var tween:=create_tween();tween.tween_property(game.camera_3d,"transform",finish,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func walk_in(progress:float)->void:
	if is_queued_for_deletion() or not is_instance_valid(actor):return
	var terrain=game.world_root.get_node("CampLandscape")
	var points:=[terrain.entrance_point(-24.0),terrain.entrance_point(-18.0),terrain.entrance_point(-11.0),Vector2(1.5,-4),Vector2(2.7,1.6)]
	var segment:=mini(3,int(progress*4.0));var t:=clampf(progress*4.0-segment,0.0,1.0)
	var point:Vector2=points[segment].lerp(points[segment+1],t)
	var height:float=terrain.flight_height_at(point) if float(GameData.species(model.species_index).get("model_hover",0.0))>0 else terrain.terrain_height_at(point)
	actor.position=Vector3(point.x,height,point.y)
	var direction:Vector2=points[segment+1]-points[segment];actor.rotation.y=atan2(direction.x,direction.y)
	model.animate_walking(progress*PI*28.0,.075)

func show_next()->void:
	can_continue=false
	if index>=arrivals.size():finish_sequence();return
	var q:Dictionary=arrivals[index]
	actor=Node3D.new();actor.name="ArrivingQuiblet";game.world_root.add_child(actor)
	model=QuibletModel3D.new();model.setup(int(q.species),false,.65);actor.add_child(model)
	var meshes:Array[MeshInstance3D]=[];game.collect_mesh_instances(model,meshes);materials.clear()
	var silhouette:=StandardMaterial3D.new();silhouette.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;silhouette.albedo_color=Color.BLACK
	for mesh in meshes:materials.append({"mesh":mesh,"material":mesh.material_override});mesh.material_override=silhouette
	walk_in(0);pose_camera(Vector3(4,9.5,-7),Vector3(6,0,-20))
	var walk:=create_tween();walk.tween_method(walk_in,0.0,1.0,4.6)
	camera_to(Vector3(0,9.5,13.5),Vector3(0,0,0),4.6)
	await walk.finished
	for entry in materials:entry.mesh.material_override=entry.material
	model.position.y=0;actor.rotation.y=0
	await camera_to(Vector3(1.0,3.6,8.0),Vector3(1.0,1.0,1.6),.9).finished
	cards=Control.new();cards.name="ArrivalCards";cards.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.content.add_child(cards)
	game.build_quiblet_menu_replica(cards,q);cards.scale=Vector2.ONE*.78;cards.position=Vector2(-620,172)
	var slide:=create_tween();slide.tween_property(cards,"position:x",26.0,.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slide.finished
	game.play_quiblet_arrival_music(game.is_rare_arrival(int(q.species)))
	hint=game.label(game.content,"Click to continue" if arrivals.size()==1 else "Click to continue  •  %d / %d"%[index+1,arrivals.size()],Vector2(820,644),18,Color.WHITE,true,HORIZONTAL_ALIGNMENT_CENTER,360)
	hint.add_theme_color_override("font_outline_color",Color("#20382d"));hint.add_theme_constant_override("outline_size",6)
	can_continue=true

func advance()->void:
	if not can_continue:return
	can_continue=false;hint.queue_free();game.quiblet_arrival_music.stop()
	var out:=create_tween();out.set_parallel(true)
	out.tween_property(cards,"position:x",-620.0,.4)
	out.tween_property(game.camera_3d,"transform",saved_camera,.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await out.finished
	cards.queue_free()
	game.world_root.get_node("CampResidents").adopt_resident(arrivals[index],actor,model)
	actor=null;model=null;index+=1
	game.completed_stew_result.revealed_count=index;game.save_game()
	show_next()

func finish_sequence()->void:
	game.camera_3d.fov=saved_fov;game.completed_stew_result.clear();game.arrival_sequence=null
	game.show_camp();game.save_game();queue_free()
