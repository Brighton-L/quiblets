extends SceneTree
# Visual check of the open-field levels. Run non-headless:
#   Godot --path . --script res://tests/level_visual.gd -- --no-save
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	await create_timer(3.0).timeout  # let the startup title reveal finish
	for shot in [[0,1,"/private/tmp/quiblets-level-meadow.png"],[8,1,"/private/tmp/quiblets-level-desert.png"],[12,1,"/private/tmp/quiblets-level-night.png"]]:
		game.area_progress[shot[0]]=8;game.start_area_level(shot[0],shot[1]);await process_frame
		var e:Expedition3D=game.expedition;e.set_process(false)
		for actor in e.team+e.enemies:actor.set_physics_process(false)
		# Pull the camera up high over the middle of the field so the whole layout is visible.
		var center:=Vector3(float(e.field_rect.position.x+e.field_rect.end.x)*.5,0,float(e.field_rect.position.y+e.field_rect.end.y)*.5)
		e.camera.global_position=center+Vector3(0,46,30);e.camera.look_at(center,Vector3.UP)
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shot[2])
		# Close-up over a bridge at gameplay camera distance, so the river channel and water are readable.
		if not e.bridges.is_empty():
			var bridge:Vector2i=e.bridges.keys()[0];var focus:=Vector3(bridge.x,0,bridge.y)
			e.camera.global_position=focus+Vector3(0,9,10);e.camera.look_at(focus,Vector3.UP)
			await create_timer(.3).timeout;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(shot[2].replace(".png","-river.png"))
		e.finish(false);await process_frame;game.show_area_levels(shot[0]);await process_frame
	print("QUIBLETS_LEVEL_VISUAL_OK")
	quit()
