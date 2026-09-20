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
var revealing_stew:=false
var stew_visual:Node3D
var stew_card:Control
var new_recipe_notice:Label
var visitors:Array[Dictionary]=[]
var arrival_route:Array[Vector2]=[]
var arrival_route_length:=0.0
var arrival_spacing:=2.4

func setup(owner_game,visitors:Array[Dictionary])->void:
	game=owner_game;arrivals=visitors;index=int(game.completed_stew_result.get("revealed_count",0))
	saved_camera=game.camera_3d.transform;saved_fov=game.camera_3d.fov
	for indicator_name in ["CookingReadyIndicator","CookingProgressIndicator"]:
		var indicator=game.world_root.get_node_or_null(indicator_name)
		if indicator:indicator.visible=false
	game.camp_pan_dragging=false;game.stop_primary_music()
	if not game.completed_stew_result.get("stew_revealed",false) and index==0:reveal_stew()
	else:bring_in_group()

func reveal_stew()->void:
	can_continue=false;revealing_stew=true
	var recipe:Dictionary=GameData.RECIPES[0]
	for entry in GameData.RECIPES:
		if entry.name==game.completed_stew_result.get("recipe",""):recipe=entry;break
	var pot:Node3D=game.world_root.get_node("CookingPot")
	var bounds:AABB=game.world_mesh_bounds(pot)
	stew_visual=preload("res://scripts/stew_reveal_visual.gd").new();stew_visual.name="FinishedStew";game.world_root.add_child(stew_visual);stew_visual.setup(recipe,bounds)
	var lid:Node3D=game.world_root.get_node_or_null("CookingPotLid")
	if lid!=null:
		var lift:=create_tween();lift.set_parallel(true)
		lift.tween_property(lid,"position:y",lid.position.y+5.0,.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		lift.tween_property(lid,"rotation:z",.25,.85)
		await lift.finished
		lid.hide()
	var focus:=Vector3(bounds.get_center().x,bounds.end.y-.25,bounds.get_center().z)
	await camera_to(focus+Vector3(0,3.6,3.4),focus,1.0).finished
	stew_card=game.panel(Rect2(327,516,626,148),Color("#f4f7fb"),16);stew_card.name="StewRecipeCard";game.content.add_child(stew_card)
	game.build_recipe_card(stew_card,recipe,true,GameData.RECIPES.find(recipe),false)
	# The reveal is advanced by clicking anywhere, including on the card itself.
	stew_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for control in stew_card.find_children("*","Control",true,false):control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if bool(game.completed_stew_result.get("new_recipe",false)):
		new_recipe_notice=game.label(game.content,"NEW RECIPE UNLOCKED!",Vector2(327,475),24,GameData.COLORS.gold,true,HORIZONTAL_ALIGNMENT_CENTER,626)
		new_recipe_notice.name="NewRecipeNotice";new_recipe_notice.add_theme_color_override("font_outline_color",Color("#20382d"));new_recipe_notice.add_theme_constant_override("outline_size",6)
	hint=game.label(game.content,"Click to meet your Quiblets",Vector2(327,675),17,Color.WHITE,true,HORIZONTAL_ALIGNMENT_CENTER,626)
	hint.add_theme_color_override("font_outline_color",Color("#20382d"));hint.add_theme_constant_override("outline_size",6)
	can_continue=true

func finish_stew_reveal()->void:
	can_continue=false
	stew_card.queue_free();hint.queue_free()
	if is_instance_valid(new_recipe_notice):new_recipe_notice.queue_free()
	var zoom_out:=create_tween();zoom_out.tween_property(game.camera_3d,"transform",saved_camera,.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await zoom_out.finished
	game.completed_stew_result.stew_revealed=true;game.save_game()
	revealing_stew=false
	bring_in_group()

func pose_camera(position:Vector3,focus:Vector3)->void:
	game.camera_3d.position=position;game.camera_3d.look_at(focus,Vector3.UP)

func camera_to(position:Vector3,focus:Vector3,duration:float)->Tween:
	var start:Transform3D=game.camera_3d.transform
	pose_camera(position,focus);var finish:Transform3D=game.camera_3d.transform;game.camera_3d.transform=start
	var tween:=create_tween();tween.tween_property(game.camera_3d,"transform",finish,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func prepare_arrival_route()->void:
	var terrain=game.world_root.get_node("CampLandscape")
	var radius:=.6
	for visitor in visitors:
		var body_model:QuibletModel3D=visitor.model
		var bounds:AABB=body_model.transform*body_model.combined_aabb(body_model)
		radius=maxf(radius,Vector2(bounds.size.x,bounds.size.z).length()*.5)
	# Leave enough space even where the procession rounds a corner. The same
	# distance separates the final spots beside the pot and the entrance walkers.
	arrival_spacing=maxf(2.4,(radius*2.0+.3)*1.5)
	arrival_route=[terrain.entrance_point(-24.0-arrival_spacing*visitors.size()),terrain.entrance_point(-24.0),terrain.entrance_point(-18.0),terrain.entrance_point(-11.0),Vector2(1.5,-4),Vector2(2.7,1.6),Vector2(2.7+arrival_spacing*maxi(0,visitors.size()-1),1.6)]
	arrival_route_length=0.0
	for i in range(1,arrival_route.size()):arrival_route_length+=arrival_route[i-1].distance_to(arrival_route[i])

func arrival_route_point(distance:float)->Vector2:
	for i in range(1,arrival_route.size()):
		var length:=arrival_route[i-1].distance_to(arrival_route[i])
		if distance<=length:return arrival_route[i-1].lerp(arrival_route[i],clampf(distance/maxf(length,.001),0,1))
		distance-=length
	return arrival_route.back()

func walk_in(progress:float)->void:
	if is_queued_for_deletion():return
	var terrain=game.world_root.get_node("CampLandscape")
	var travel:=arrival_route_length-arrival_spacing*maxi(0,visitors.size()-1)
	for visitor_index in visitors.size():
		var visitor:Dictionary=visitors[visitor_index]
		var body:Node3D=visitor.actor;var body_model:QuibletModel3D=visitor.model
		if not is_instance_valid(body):continue
		var distance:=travel*progress+visitor_index*arrival_spacing
		var point:=arrival_route_point(distance)
		var height:float=terrain.flight_height_at(point) if float(GameData.species(body_model.species_index).get("model_hover",0.0))>0 else terrain.terrain_height_at(point)
		body.position=Vector3(point.x,height,point.y)
		var direction:=arrival_route_point(minf(distance+.05,arrival_route_length))-arrival_route_point(maxf(0,distance-.05))
		body.rotation.y=atan2(direction.x,direction.y)
		body_model.animate_walking(progress*PI*28.0,.075)

func bring_in_group()->void:
	can_continue=false
	if index>=arrivals.size():finish_sequence();return
	var silhouette:=StandardMaterial3D.new();silhouette.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;silhouette.albedo_color=Color.BLACK
	for arrival_index in range(index,arrivals.size()):
		var q:Dictionary=arrivals[arrival_index]
		var body:=Node3D.new();body.name="ArrivingQuiblet%d"%arrival_index;game.world_root.add_child(body)
		var body_model:=QuibletModel3D.new();body_model.setup(int(q.species),false,preload("res://scripts/camp_roaming.gd").MODEL_SCALE);body.add_child(body_model)
		var meshes:Array[MeshInstance3D]=[];game.collect_mesh_instances(body_model,meshes)
		var materials:Array=[]
		for mesh in meshes:materials.append({"mesh":mesh,"material":mesh.material_override});mesh.material_override=silhouette
		visitors.append({"index":arrival_index,"actor":body,"model":body_model,"materials":materials})
	prepare_arrival_route()
	var lift:=entrance_camera_lift()
	walk_in(0);pose_camera(Vector3(4,9.5+lift,-7),Vector3(6,lift,-20))
	var walk:=create_tween();walk.tween_method(walk_in,0.0,1.0,4.6)
	camera_to(Vector3(0,9.5+lift,13.5),Vector3(0,lift,0),4.6)
	await walk.finished
	for visitor in visitors:
		for entry in visitor.materials:entry.mesh.material_override=entry.material
		visitor.model.position.y=0;visitor.actor.rotation.y=0
	show_next()

func entrance_camera_lift()->float:
	var low:=INF;var high:=-INF
	for visitor in visitors:
		var body_model:QuibletModel3D=visitor.model
		var bounds:AABB=body_model.transform*body_model.combined_aabb(body_model)
		low=minf(low,bounds.get_center().y);high=maxf(high,bounds.get_center().y)
	return maxf(0.0,(low+high)*.5-1.0) if not visitors.is_empty() else 0.0

func reveal_framing(body_model:QuibletModel3D)->Dictionary:
	# Floating meshes sit above their actor's ground anchor. Frame the visible
	# body, with breathing room for its idle motion and the cards on the left.
	var bounds:AABB=body_model.global_transform*body_model.combined_aabb(body_model)
	var distance:=maxf(6.9,bounds.size.length()*2.1)
	var focus:=bounds.get_center()+Vector3(-distance*.25,0,0)
	return {"focus":focus,"position":focus+Vector3(0,2.6,6.4).normalized()*distance}

func show_next()->void:
	can_continue=false
	if index>=arrivals.size():finish_sequence();return
	var q:Dictionary=arrivals[index]
	for visitor in visitors:
		if visitor.index==index:actor=visitor.actor;model=visitor.model;break
	var framing:=reveal_framing(model)
	await camera_to(framing.position,framing.focus,.9).finished
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
	if revealing_stew:finish_stew_reveal();return
	can_continue=false;hint.queue_free();game.quiblet_arrival_music.stop()
	var out:=create_tween();out.set_parallel(true)
	out.tween_property(cards,"position:x",-620.0,.4)
	if index==arrivals.size()-1:
		out.tween_property(game.camera_3d,"transform",saved_camera,.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:out.tween_interval(.8)
	await out.finished
	cards.queue_free()
	game.world_root.get_node("CampResidents").adopt_resident(arrivals[index],actor,model)
	actor=null;model=null;index+=1
	game.completed_stew_result.revealed_count=index;game.save_game()
	show_next()

func finish_sequence()->void:
	game.camera_3d.fov=saved_fov;game.completed_stew_result.clear();game.arrival_sequence=null
	game.show_camp();game.save_game();queue_free()
