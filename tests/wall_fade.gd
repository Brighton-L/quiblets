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
	var camera:=Camera3D.new();root.add_child(camera);e.camera=camera
	var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(0,10),false,0,2);e.place_actor(actor);actor.set_physics_process(false);e.team.append(actor)
	# A spot on the open ground where the hills on the camera side rise through the line of sight.
	var hidden:Vector2i=Vector2i(-9999,-9999)
	for cell in e.walkable:
		actor.position=Vector3(cell.x,0,cell.y);camera.global_position=actor.position+Vector3(0,13,15)
		if e.occluded_by_terrain(actor):hidden=cell;break
	check(hidden.x>-9000,"Test needs open ground hidden behind a hill from the camera")
	for i in 30:e.update_wall_fades(1.0/60.0)
	var weight:float=float(e.fade_weights.get(actor.get_instance_id(),0.0))
	check(is_equal_approx(weight,1.0) and e.fading_wall_count()==1 and int(e.terrain_material.get_shader_parameter("fade_count"))==1 and int(e.terrain_fade_material.get_shader_parameter("fade_count"))==1 and is_equal_approx(float(e.terrain_fade_material.get_shader_parameter("fade_alpha")),e.WALL_FADE_ALPHA),"A hidden Quiblet fades the ground on its line of sight to 20%% (weight %.2f)"%weight)
	check(e.terrain_material.next_pass==e.terrain_fade_material and not e.terrain_material.shader.code.contains("ALPHA=") and e.terrain_fade_material.shader.code.contains("ALPHA="),"The opaque pass cuts the hole and only the next pass is transparent, so water in the troughs stays visible")
	# Step into the open: the fade eases off over a few frames, then stops.
	var open_cell:Vector2i=hidden
	for cell in e.walkable:
		actor.position=Vector3(cell.x,0,cell.y);camera.global_position=actor.position+Vector3(0,13,15)
		if not e.occluded_by_terrain(actor):open_cell=cell;break
	actor.position=Vector3(open_cell.x,0,open_cell.y);camera.global_position=actor.position+Vector3(0,13,15)
	e.update_wall_fades(1.0/60.0)
	var easing:float=float(e.fade_weights.get(actor.get_instance_id(),0.0))
	check(easing>0.0 and easing<1.0,"The fade eases back smoothly rather than snapping (weight %.2f)"%easing)
	for i in 30:e.update_wall_fades(1.0/60.0)
	check(e.fading_wall_count()==0 and int(e.terrain_material.get_shader_parameter("fade_count"))==0,"Once nothing is hidden no ground fades")
	e.free()
	print("QUIBLETS_WALL_FADE_OK checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
