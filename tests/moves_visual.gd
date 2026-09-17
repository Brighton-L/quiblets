extends SceneTree

# Reproducible six-scene render of actual casts, not a separate mock-up.
func _initialize()->void:call_deferred("run")

func run()->void:
	var actors:Array[QuibletActor3D]=[]
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#233844");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7;environment.environment=env;world.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-65,-25,0);world.add_child(light)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,30,24);camera.look_at(Vector3.ZERO);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=30
	var names:=["Water Jet","Whirlpool","Healing Bloom","Flame Dash","Guard","Downpour"]
	for i in names.size():
		var group:=Node3D.new();world.add_child(group)
		var center:=Vector3((i%3-1)*9,0,(i/3)*8-4)
		var floor_mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(8,.2,7);floor_mesh.mesh=box;floor_mesh.position=center-Vector3.UP*.2
		var material:=StandardMaterial3D.new();material.albedo_color=Color("#65906c");floor_mesh.material_override=material;group.add_child(floor_mesh)
		var source:=QuibletActor3D.new();var q:=GameData.make_quiblet(i%8,10);q.moves=[{"name":names[i],"slots":2,"stones":[]}];source.setup(q,false,0,i%5);group.add_child(source);source.position=center+Vector3(-2,0,0);source.arena=Rect2(-100,-100,200,200);source.set_physics_process(false)
		var target:=QuibletActor3D.new();target.setup(GameData.make_quiblet(6,10),true);group.add_child(target);target.position=center+Vector3(1,0,0);target.set_physics_process(false);target.max_hp=10000;target.current_hp=10000;target.arena=source.arena
		var label:=Label3D.new();label.text=names[i];label.font_size=64;label.pixel_size=.015;label.position=center+Vector3(0,.2,3.1);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;group.add_child(label)
		actors.append(source);actors.append(target);source.use_move(0,target)
	for frame in 54:
		await physics_frame
		for actor in actors:actor.update_statuses(1.0/60)
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image().save_png("/private/tmp/quiblets-moves-visual.png")
	print("QUIBLETS_MOVE_RENDER result=",result)
	quit()
