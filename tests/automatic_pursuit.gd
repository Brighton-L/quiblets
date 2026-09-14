extends SceneTree
func _initialize()->void:call_deferred("run")
func actor(e:Expedition3D,enemy:bool,point:Vector2)->QuibletActor3D:
	var a:=QuibletActor3D.new();a.setup(GameData.make_quiblet(0,10),enemy,0);e.add_child(a);a.set_physics_process(false);a.position=Vector3(point.x,0,point.y);a.arena=Rect2(-12,-12,24,24)
	if enemy:e.enemies.append(a);a.set_meta("alerted",false)
	else:e.team.append(a)
	return a
func run()->void:
	var e:=Expedition3D.new();root.add_child(e);e.set_process(false);e.exploring=true
	for x in range(-12,13):
		for y in range(-12,13):
			if x!=0 or y>=7:e.walkable[Vector2i(x,y)]=true
	var leader:=actor(e,false,Vector2(-4,0));var other:=actor(e,false,Vector2(-6,0))
	var across:=actor(e,true,Vector2(2,0));var nearby:=actor(e,true,Vector2(-4,5))
	assert(e.reachable_enemy(leader,e.idle_enemies())==nearby,"Choose the shorter walk, not the closest enemy across water")
	e.update_exploration(e.team)
	assert(leader.has_command and leader.get_meta("auto_route",false))
	other.has_command=false;e.elapsed=1;e.update_exploration(e.team)
	assert(other.has_command,"Idle teammates should not wait for a straggler")
	nearby.set_meta("alerted",true);e.update_team_targets()
	assert(leader.target==nearby and not leader.has_command,"Engagement should cancel automatic travel")
	across.set_meta("alerted",true);e.update_team_targets()
	assert(leader.target==nearby,"Keep pursuing the current target")
	nearby.current_hp=0;e.update_team_targets();e.update_chase_routing(1)
	assert(leader.target==across and leader.get_meta("chase_routed",false),"Automatically pursue the next enemy across the bridge")
	leader.command(Vector3(-8,0,0));e.update_team_targets();e.update_chase_routing(1)
	assert(leader.has_command and leader.desired_point==Vector3(-8,0,0) and not leader.get_meta("chase_routed",false),"Manual destinations retain priority")
	for y in range(7,13):e.walkable.erase(Vector2i(0,y))
	assert(e.find_path(Vector2(-4,0),Vector2(2,0)).is_empty(),"Unreachable destinations must not produce a route through water")
	e.free();print("QUIBLETS_AUTOMATIC_PURSUIT_OK");quit()
