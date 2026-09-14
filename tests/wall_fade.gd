extends SceneTree

# Ground between the camera and a fighter fades to 20% and fades back once clear.
var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func run()->void:
	var e:=Expedition3D.new();e.stage_area_index=0;e.stage_node_index=1;e.stage_kind="level";e.stage_level=2;root.add_child(e);e.set_process(false);e.build_level()
	# This test isolates the fighter line-of-sight fade; a level's own waterfalls add
	# their own fade points, which are exercised separately.
	e.waterfalls.clear()
	var camera:=Camera3D.new();root.add_child(camera);e.camera=camera
	var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(0,10),false,0,2);e.place_actor(actor);actor.set_physics_process(false);e.team.append(actor)
	# The meadow's own hills are gentle, so raise an artificial ridge in the heightfield on the
	# camera side of one open cell and stand the Quiblet just behind it.
	var hidden:Vector2i=e.zones[0].center
	var ridge_z:=float(hidden.y)+2.0
	for c in e.height_cols:
		for r in e.height_rows:
			var point:Vector2=e.height_origin+Vector2(c,r)/float(e.TERRAIN_SUBDIV)
			if absf(point.y-ridge_z)<.7 and absf(point.x-float(hidden.x))<3.0:e.height_field[r*e.height_cols+c]=5.0
	actor.position=Vector3(hidden.x,0,hidden.y);camera.global_position=actor.position+Vector3(0,13,15)
	check(e.occluded_by_terrain(actor),"A ridge between the Quiblet and the camera counts as hiding it")
	for i in 30:e.update_wall_fades(1.0/60.0)
	var weight:float=float(e.fade_weights.get(actor.get_instance_id(),0.0))
	check(is_equal_approx(weight,1.0) and e.fading_wall_count()==1 and int(e.terrain_material.get_shader_parameter("fade_count"))==1 and int(e.terrain_fade_material.get_shader_parameter("fade_count"))==1 and is_equal_approx(float(e.terrain_fade_material.get_shader_parameter("fade_alpha")),e.WALL_FADE_ALPHA),"A hidden Quiblet fades the ground on its line of sight to 20%% (weight %.2f)"%weight)
	check(e.terrain_material.next_pass==e.terrain_fade_material and not e.terrain_material.shader.code.contains("ALPHA=") and e.terrain_fade_material.shader.code.contains("ALPHA="),"The opaque pass cuts the hole and only the next pass is transparent, so water in the troughs stays visible")
	# Step into the open: the fade eases off over a few frames, then stops.
	actor.position=Vector3(hidden.x,0,hidden.y-6);camera.global_position=actor.position+Vector3(0,13,15)
	check(not e.occluded_by_terrain(actor),"Away from the ridge the Quiblet is in the open")
	e.update_wall_fades(1.0/60.0)
	var easing:float=float(e.fade_weights.get(actor.get_instance_id(),0.0))
	check(easing>0.0 and easing<1.0,"The fade eases back smoothly rather than snapping (weight %.2f)"%easing)
	for i in 30:e.update_wall_fades(1.0/60.0)
	check(e.fading_wall_count()==0 and int(e.terrain_material.get_shader_parameter("fade_count"))==0,"Once nothing is hidden no ground fades")
	e.free()
	print("QUIBLETS_WALL_FADE_OK checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
