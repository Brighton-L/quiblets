extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var terrain=load("res://scripts/camp_terrain.gd").new();root.add_child(terrain);terrain.build()
	var roaming=load("res://scripts/camp_roaming.gd").new();root.add_child(roaming)
	var roster:Array=[]
	for i in GameData.SPECIES.size():roster.append({"species":i})
	roaming.setup(roster,terrain);roaming.set_process(false);roaming.rng.seed=73
	var starts:Array=[];var distances:Array=[];var failures:=0
	for resident in roaming.residents:starts.append(resident.body.position);distances.append(0.0)
	if roaming.residents.size()!=roster.size():failures+=1;push_error("Every owned Quiblet must appear in camp")
	for frame in 1200:
		roaming._process(.05)
		for i in roaming.residents.size():
			var position:Vector3=roaming.residents[i].body.position
			distances[i]=maxf(distances[i],position.distance_to(starts[i]))
			if not roaming.floats(int(roaming.residents[i].species)) and terrain.terrain_height_at(Vector2(position.x,position.z))<-.1:failures+=1;push_error("Resident entered the stream")
	if not distances.all(func(distance):return distance>1.0):failures+=1;push_error("Every resident should wander")
	roaming.free();terrain.free();print("QUIBLETS_CAMP_ROAMING failures=",failures);quit(failures)
