extends SceneTree

func _initialize():call_deferred("run")

func run():
	root.size=Vector2i(1280,720)
	var expedition:=Expedition3D.new();expedition.stage_kind="berry_grove";root.add_child(expedition);expedition.set_process(false)
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,10,12);camera.look_at(Vector3.ZERO);expedition.camera=camera
	var markers=load("res://scripts/berry_patch_indicators.gd").new();markers.expedition=expedition;root.add_child(markers)
	await process_frame
	assert(markers.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	assert(markers.marker_for(Vector3.ZERO).is_empty(),"Visible patches must not have an edge marker")
	var ahead:Vector3=camera.position-camera.basis.z*10
	for point in [ahead-camera.basis.x*100,ahead+camera.basis.x*100,ahead+camera.basis.y*100,ahead-camera.basis.y*100,camera.position+camera.basis.z*10+camera.basis.x*100]:
		var marker:Dictionary=markers.marker_for(point)
		assert(not marker.is_empty())
		var p:Vector2=marker.position
		assert(Rect2(11,11,1258,698).has_point(p),"Markers must remain on screen")
		assert(is_equal_approx(p.x,12) or is_equal_approx(p.x,1268) or is_equal_approx(p.y,12) or is_equal_approx(p.y,708),"Markers must sit at the screen edge")
	assert(markers.marker_for(Vector3(-100,0,0)).position.x==12)
	assert(markers.marker_for(Vector3(100,0,0)).position.x==1268)
	for screen_point in [Vector2(1500,-300),Vector2(-300,-300),Vector2(1500,1000),Vector2(-300,1000),Vector2(1100,-300),Vector2(1500,200)]:
		var world_point:=camera.project_position(screen_point,10)
		var expected:Vector2=screen_point.clamp(Vector2(12,12),Vector2(1268,708))
		assert(markers.marker_for(world_point).position.is_equal_approx(expected),"Marker must preserve projected position at edges and corners")
	var before:Vector2=markers.marker_for(Vector3(100,0,0)).position
	camera.position+=Vector3(0,0,20)
	assert(not markers.marker_for(Vector3(100,0,0)).position.is_equal_approx(before),"Marker must follow camera motion")
	for ingredient in ["Bumbleberry","Dewmelon","Frostberry","Sunplum"]:
		var patch:=Node3D.new();patch.position=Vector3(100,0,0);patch.set_meta("ingredient",ingredient);expedition.add_child(patch);expedition.berry_nodes.append(patch)
	await process_frame
	expedition.berry_nodes[0].queue_free();expedition.berry_nodes.remove_at(0);await process_frame
	root.size=Vector2i(960,540);await process_frame
	var resized_bounds:Rect2=root.get_visible_rect()
	var transform:Transform2D=markers.get_global_transform_with_canvas()
	var edge:Vector2=transform*markers.marker_for(Vector3(100,0,0)).position
	assert(is_equal_approx(edge.x,resized_bounds.end.x-12*transform.x.length()),"Marker must follow window resizing")
	expedition.stage_kind="level";await process_frame
	markers.queue_free();expedition.queue_free();camera.queue_free();await process_frame
	print("Berry markers: visible/behind-camera targets, all edges, camera movement, resizing and harvested patches passed")
	quit()
