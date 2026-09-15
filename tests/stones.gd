extends SceneTree

var events: Array[Dictionary] = []

func _initialize() -> void:
	var expected := ["echo","heavy","reach","chain","sharing","split","rush","seeking","lingering","blast","force","drain","link"]
	assert(GameData.MOVE_STONES.size()==13)
	for effect in expected:
		var info:=GameData.stone_info(effect)
		assert(not info.is_empty(),"Missing stone definition: "+effect)
		assert(info.name==effect.capitalize()+" Stone","Move Stone name should use the '[Name] Stone' format: "+effect)
		assert(load(info.texture)!=null,"Missing stone texture: "+effect)
	var arena:=Node3D.new();root.add_child(arena)
	var user_data:=GameData.make_quiblet(0,20)
	user_data.moves=[
		{"name":"Water Shot","slots":6,"stones":["echo","heavy","reach","chain","split","seeking"]},
		{"name":"Water Burst","slots":6,"stones":["rush","lingering","blast","force","drain","link:Water Jet"]},
		{"name":"Water Jet","slots":1,"stones":["link_from:Water Burst"]},
		{"name":"Healing Bloom","slots":1,"stones":["sharing"]}
	]
	var user:=QuibletActor3D.new();user.setup(user_data);user.position=Vector3.ZERO;arena.add_child(user);user.set_physics_process(false);user.move_used.connect(_record_event)
	var primary:=make_actor(arena,1,Vector3(4.6,0,0),true)
	var secondary:=make_actor(arena,2,Vector3(4.9,0,.8),true)
	var ally:=make_actor(arena,3,Vector3(.8,0,0),false)
	await process_frame
	var initial_primary:=primary.current_hp;var initial_secondary:=secondary.current_hp
	user.current_hp=user.max_hp*.45
	user.target=primary
	for attempt in 10:user.try_use_best_move(.1)
	assert(events.is_empty() and user.move_cooldowns.all(func(cooldown):return cooldown==0.0) and user.recover_time==0.0,"Player Quiblets must not automatically activate attacks or healing moves")
	user.use_move(0,primary)
	assert(user.move_cooldowns[0]>GameData.MOVES["Water Shot"].cooldown*1.28,"Echo did not increase cooldown")
	await create_timer(.75).timeout
	assert(primary.current_hp<initial_primary,"Attack stones did not deal damage")
	assert(secondary.current_hp<initial_secondary,"Chain did not hit a nearby target")
	assert(user.move_cooldowns[0]>0,"Heavy/Rush cooldown modifiers were not applied")
	assert(events.any(func(e):return e.get("split",false)),"Split did not create copies")
	assert(events.any(func(e):return e.get("seeking",false)),"Seeking was not passed to projectile behavior")
	assert(events.any(func(e):return e.get("echo",false)),"Echo did not repeat the move")
	assert(events.any(func(e):return e.get("chain",false)),"Chain event was not produced")
	var first_leaf:Dictionary=events.filter(func(e):return e.move_name=="Water Shot" and not e.get("echo",false))[0]
	var echoed_leaf:Dictionary=events.filter(func(e):return e.move_name=="Water Shot" and e.get("echo",false))[0]
	assert(is_equal_approx(float(first_leaf.strength),float(echoed_leaf.strength)),"Echo repeat still has an effectiveness penalty")
	primary.position=Vector3(2.0,0,0);secondary.position=Vector3(2.5,0,.6);primary.current_hp=primary.max_hp;secondary.current_hp=secondary.max_hp
	var before_burst:=primary.current_hp;var before_position:=primary.position;var before_user_hp:=user.current_hp
	user.use_move(1,primary)
	await create_timer(1.45).timeout
	assert(primary.current_hp<before_burst,"Blast/Lingering move did not deal damage")
	assert(primary.position.distance_to(before_position)>.5,"Force did not displace its target")
	assert(user.current_hp>before_user_hp,"Drain did not heal its user")
	assert(events.any(func(e):return e.get("blast",false)),"Blast visual metadata missing")
	assert(not preload("res://scripts/move_behaviors.gd").supports("Water Burst","lingering"),"Instant bursts must not gain a made-up lingering damage pulse")
	assert(user.move_cooldowns[2]==0,"Linked move incorrectly entered cooldown")
	var rushed_event:Dictionary=events.filter(func(e):return e.move_name=="Water Burst")[0]
	assert(is_equal_approx(float(rushed_event.strength),1.0),"Rush still reduces move strength")
	user.recover_time=0;user.current_hp=user.max_hp*.2;ally.current_hp=ally.max_hp*.2;var ally_before:=ally.current_hp
	user.use_move(3,primary)
	await create_timer(.1).timeout
	assert(ally.current_hp>ally_before,"Sharing did not heal a nearby ally")
	# Regression: an enemy may disappear before an Echo/Link timer completes.
	# The delayed activation must resolve with a safe null target, not pass a
	# previously-freed object into the typed move executor.
	var doomed:=make_actor(arena,7,Vector3(1.6,0,0),true);var delayed_before:=user.delayed_executions_resolved
	user.move_cooldowns[0]=0.0;user.use_move(0,doomed);doomed.queue_free();await process_frame;await create_timer(1.2).timeout
	assert(user.delayed_executions_resolved>delayed_before,"A delayed move did not safely resolve after its target was freed")
	var enemy_probe:=make_actor(arena,0,Vector3(1.8,0,0),true);enemy_probe.target=ally;enemy_probe.move_cooldowns.fill(0.0)
	enemy_probe.try_use_best_move(enemy_probe.horizontal_distance(enemy_probe.global_position,ally.global_position))
	assert(enemy_probe.move_cooldowns.any(func(cooldown):return cooldown>0.0),"Enemy Quiblets should retain automatic move use")
	print("QUIBLETS_STONES_OK effects=13 events=",events.size())
	quit(0)

func make_actor(arena:Node3D,species_index:int,pos:Vector3,is_enemy:bool)->QuibletActor3D:
	var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(species_index,15),is_enemy);actor.position=pos;arena.add_child(actor);actor.set_physics_process(false);return actor

func _record_event(_actor:QuibletActor3D,_move_name:String,_target:QuibletActor3D,details:Dictionary)->void:
	var record:=details.duplicate();record.move_name=_move_name;events.append(record)
