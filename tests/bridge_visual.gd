extends SceneTree
# Low-angle look along a river at a land bridge. Run non-headless:
#   Godot --path . --script res://tests/bridge_visual.gd -- --no-save
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	await create_timer(3.0).timeout
	game.area_progress[0]=8;game.start_area_level(0,1);await process_frame
	var e:Expedition3D=game.expedition;e.set_process(false)
	for actor in e.team+e.enemies:actor.set_physics_process(false)
	# Prefer a bridge inside a clearing: the case where the channel used to be plain full-block ground.
	var clearing:Array=e.bridges.keys().filter(func(cell):return e.zones.any(func(zone):return Vector2(zone.center).distance_to(Vector2(cell))<2.6))
	var bridge:Vector2i=clearing[clearing.size()/2] if not clearing.is_empty() else e.bridges.keys()[0];var flow:Vector2=e.river_flow.get(bridge,Vector2(0,1))
	print("BRIDGE_VISUAL clearing_bridges=",clearing.size()," at=",bridge)
	var focus:=Vector3(bridge.x,-.6,bridge.y);var back:=Vector3(flow.x,0,flow.y).normalized()*4.5
	e.camera.global_position=focus-back+Vector3(0,1.6,0);e.camera.look_at(focus,Vector3.UP)
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-bridge-under.png")
	var arch:Dictionary=e.bridge_arches[0];var center:Vector2=arch.center;var axis:Vector2=arch.axis;var side:=Vector2(-axis.y,axis.x)
	var top_focus:=Vector3(center.x,e.deck_height_at(center),center.y)
	e.camera.global_position=top_focus+Vector3(axis.x*7+side.x*9,10,axis.y*7+side.y*9);e.camera.look_at(top_focus,Vector3.UP)
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-bridge-top.png")
	print("QUIBLETS_BRIDGE_VISUAL_OK");quit()
