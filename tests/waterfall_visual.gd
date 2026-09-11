extends SceneTree
# A low view up a river toward its waterfall. Run non-headless:
#   Godot --path . --script res://tests/waterfall_visual.gd -- --no-save
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	await create_timer(3.0).timeout
	var found:=false
	for node in [1,0,2,4,5]:
		game.area_progress[0]=8;game.start_area_level(0,node);await process_frame
		if not game.expedition.waterfalls.is_empty():found=true;break
		game.expedition.finish(false);await process_frame;game.show_area_levels(0);await process_frame
	var e:Expedition3D=game.expedition;e.set_process(false)
	for actor in e.team+e.enemies:actor.set_physics_process(false)
	print("WATERFALL_VISUAL found=",found," falls=",e.waterfalls.size())
	if found:
		var fall:Dictionary=e.waterfalls[0];var lip:Vector2=fall.lip;var flow:Vector2=fall.flow
		var focus:=Vector3(lip.x,.2,lip.y);var back:=Vector3(flow.x,0,flow.y).normalized()*7.0
		e.camera.global_position=focus+back+Vector3(0,2.2,0);e.camera.look_at(focus,Vector3.UP)
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/quiblets-waterfall.png")
	print("QUIBLETS_WATERFALL_VISUAL_OK");quit()
