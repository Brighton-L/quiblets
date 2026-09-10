extends SceneTree
# The team tucked behind a hill from the gameplay camera. Run non-headless:
#   Godot --path . --script res://tests/wall_fade_visual.gd -- --no-save
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	await create_timer(3.0).timeout
	game.area_progress[0]=8;game.start_area_level(0,1);await process_frame
	var e:Expedition3D=game.expedition;e.set_process(false)
	for actor in e.team+e.enemies:actor.set_physics_process(false)
	var probe:QuibletActor3D=e.team[0];var stand:Vector2i=Vector2i.ZERO
	for cell in e.walkable:
		probe.position=Vector3(cell.x,0,cell.y);e.camera.global_position=probe.position+Vector3(0,13,15)
		if e.occluded_by_terrain(probe) and e.cell_open(cell+Vector2i(-1,0)):stand=cell;break
	for i in e.team.size():e.team[i].position=Vector3(stand.x-i*.9,0,stand.y)
	e.camera_focus=Vector3(stand.x,0,stand.y);e.camera.global_position=e.camera_focus+Vector3(0,13,15);e.camera.look_at(e.camera_focus+Vector3(0,.45,0),Vector3.UP)
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-wall-fade-before.png")
	for i in 40:e.update_wall_fades(1.0/60.0)
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-wall-fade-after.png")
	print("QUIBLETS_WALL_FADE_VISUAL_OK");quit()
