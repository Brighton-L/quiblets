extends SceneTree
# Visual check: every resource's patch shape in one scene. Run non-headless:
#   Godot --path . --script res://tests/patch_shapes_visual.gd -- --no-save
func _initialize()->void:call_deferred("run")
func run()->void:
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("#8fbd7f");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=1.2;env.environment=e;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-30,0);light.light_energy=1.3;stage.add_child(light)
	var ground:=MeshInstance3D.new();var plane:=BoxMesh.new();plane.size=Vector3(12,.1,10);ground.mesh=plane;ground.position=Vector3(0,-.05,0);var mat:=StandardMaterial3D.new();mat.albedo_color=Color("#9cc78c");ground.material_override=mat;stage.add_child(ground)
	var builder:=Expedition3D.new()
	var names:Array=GameData.INGREDIENTS.keys();var index:=0
	for ingredient_name in names:
		var patch:=Node3D.new();patch.position=Vector3(-3.9+(index%4)*2.6,0,-3.3+(index/4)*2.2);stage.add_child(patch);builder.build_berry_patch_shape(patch,ingredient_name)
		var tag:=Label3D.new();tag.text=ingredient_name;tag.font_size=44;tag.pixel_size=.006;tag.position=patch.position+Vector3(0,1.15,0);tag.modulate=Color("#243447");tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;stage.add_child(tag)
		index+=1
	# look_at needs the camera inside the tree, so add it first.
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,10.5,9.5);camera.look_at(Vector3(0,.2,-.2),Vector3.UP);camera.fov=44;camera.current=true
	for frame in 30:await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-patch-shapes.png")
	builder.free()
	print("QUIBLETS_PATCH_SHAPES_VISUAL_OK")
	quit()
