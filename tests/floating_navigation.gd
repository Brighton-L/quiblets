extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var e:=Expedition3D.new();root.add_child(e);e.set_process(false);e.field_rect=Rect2i(-8,-8,17,17)
	for x in range(-8,9):
		for y in range(-8,9):
			var cell:=Vector2i(x,y)
			if abs(x)<=1 and y<5:e.rivers[cell]=true
			else:e.walkable[cell]=true
	e.build_obstacles()
	assert(not e.line_walkable(Vector2(-4,0),Vector2(4,0)))
	assert(e.line_walkable(Vector2(-4,0),Vector2(4,0),true))
	assert(e.find_path(Vector2(-4,0),Vector2(4,0),true).size()==1)
	assert(e.find_path(Vector2(-4,0),Vector2(4,0)).size()>1)
	assert(not e.flight_obstacles.any(func(rect):return rect.has_point(Vector2.ZERO)))
	var camp=load("res://scripts/camp_terrain.gd").new();root.add_child(camp);camp.build()
	var point:Vector2=camp.bridge_arches[0].center
	assert(camp.terrain_height_at(point)>camp.flight_height_at(point)+.3)
	var roaming=load("res://scripts/camp_roaming.gd").new();root.add_child(roaming);roaming.setup([GameData.make_quiblet(16,5)],camp)
	assert(roaming.floats(16) and not roaming.floats(0))
	assert(roaming.clear_ground(Vector2(camp.stream_x(0),0),true))
	assert(not roaming.clear_ground(Vector2(camp.stream_x(0),0),false))
	roaming.free();camp.free();e.free();print("FLOATING_NAVIGATION_OK");quit()
