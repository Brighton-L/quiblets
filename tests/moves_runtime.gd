extends SceneTree

var failures:Array[String]=[]
var checks:=0
var events:Array[Dictionary]=[]
var arena:Node3D
var user:QuibletActor3D
var enemy:QuibletActor3D
var started:=0

func _initialize()->void:call_deferred("run")

func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)

func fixture(moves:Array)->void:
	if is_instance_valid(arena):arena.free()
	arena=Node3D.new();root.add_child(arena)
	var data:=GameData.make_quiblet(0,10);data.moves=moves
	user=QuibletActor3D.new();user.setup(data);arena.add_child(user);user.set_physics_process(false);user.max_hp=10000;user.current_hp=10000
	enemy=QuibletActor3D.new();enemy.setup(GameData.make_quiblet(0,10),true);arena.add_child(enemy);enemy.position=Vector3(2,0,0);enemy.set_physics_process(false);enemy.max_hp=10000;enemy.current_hp=10000
	events.clear();started=Time.get_ticks_msec()
	user.move_used.connect(func(_a,name,_t,details):events.append({"name":name,"time":(Time.get_ticks_msec()-started)/1000.0,"echo":details.get("echo",false),"strength":details.strength}))

func run()->void:
	fixture([{"name":"Water Jet","slots":2,"stones":["echo","link:Water Shot"]},{"name":"Water Shot","slots":2,"stones":["heavy","link_from:Water Jet"]}])
	user.move_cooldowns[1]=30;user.use_move(0,enemy)
	await create_timer(1).timeout
	check(events.size()==1,"Echo/Link started before Water Jet finished its stream")
	await create_timer(1.4).timeout
	# The Echo fires .3s after the 1.8s stream ends in physics time; wall-clock sampling can read a little early.
	var stream_seconds:float=float(user.BEHAVIORS.profile("Water Jet").duration)
	check(events.any(func(e):return e.name=="Water Jet" and e.echo and e.time>=stream_seconds-.1),"Echo did not repeat the entire finished stream (events: %s)"%str(events.map(func(e):return "%s%s@%.2f"%[e.name,"(echo)" if e.echo else "",e.time])))
	check(events.any(func(e):return e.name=="Water Shot" and is_equal_approx(e.strength,.65*1.35)),"Link did not apply the destination's Heavy Stone at reduced strength")
	check(user.move_cooldowns[1]==30,"Link changed the destination's existing cooldown")
	fixture([{"name":"Water Shot","slots":2,"stones":["link:Bubble Shot","link_from:Leaf Shot"]},{"name":"Bubble Shot","slots":2,"stones":["link_from:Water Shot","link:Leaf Shot"]},{"name":"Leaf Shot","slots":2,"stones":["link_from:Bubble Shot","link:Water Shot"]}])
	user.use_move(0,enemy);await create_timer(1.8).timeout
	check(events.size()==3 and events[0].name=="Water Shot" and events[1].name=="Bubble Shot" and events[2].name=="Leaf Shot","Link chain revisited a move or failed to reach all three moves")
	# A move plays out in full once started: a stun landing while it is in flight
	# neither drops nor delays the Echo and the Link.
	fixture([{"name":"Rain Drop","slots":2,"stones":["echo","link:Water Shot"]},{"name":"Water Shot","slots":2,"stones":["reach","link_from:Rain Drop"]}])
	user.use_move(0,enemy);await create_timer(.5).timeout
	user.add_status("stun",5.0,0.0)
	await create_timer(1.5).timeout
	check(user.statuses.has("stun") and events.any(func(e):return e.name=="Rain Drop" and e.echo) and events.any(func(e):return e.name=="Water Shot"),"A stun during the cast should not stop the Echo or the Link from playing out")
	user.statuses.erase("stun")
	# A dash keeps going through a stun that lands mid-dash, and a projectile
	# already in flight still lands after its user is knocked out.
	fixture([{"name":"Splash Dash","slots":0,"stones":[]}]);enemy.position=Vector3(2.2,0,0)
	var dash_start:=user.global_position;user.use_move(0,enemy);await create_timer(.08).timeout
	check(user.motion_lock>0,"Test needs the dash under way")
	user.add_status("stun",3.0,0.0);await create_timer(1.2).timeout
	check(user.motion_lock==0 and user.horizontal_distance(user.global_position,dash_start)>2.0 and enemy.current_hp<10000,"A stun landing mid-dash should not cut the dash short (moved %.2f)"%user.horizontal_distance(user.global_position,dash_start))
	user.statuses.erase("stun")
	# An Echo whose target died to the first drop still falls on the same spot, and
	# never flies across the map to a far-off enemy outside the move's reach.
	fixture([{"name":"Rain Drop","slots":2,"stones":["echo","link:Water Shot"]},{"name":"Water Shot","slots":1,"stones":["link_from:Rain Drop"]}])
	enemy.position=Vector3(2,0,0);enemy.max_hp=5;enemy.current_hp=5
	var far_enemy:=QuibletActor3D.new();far_enemy.setup(GameData.make_quiblet(0,10),true);arena.add_child(far_enemy);far_enemy.position=Vector3(40,0,0);far_enemy.set_physics_process(false);far_enemy.max_hp=10000;far_enemy.current_hp=10000
	user.use_move(0,enemy);await create_timer(2.4).timeout
	check(enemy.current_hp<=0 and events.any(func(e):return e.name=="Rain Drop" and e.echo) and events.any(func(e):return e.name=="Water Shot"),"Killing the target with the first drop should not stop the Echo or the Link")
	check(far_enemy.current_hp==10000,"A follow-up with no enemy in reach should land where it was aimed, not on a far-off enemy")
	far_enemy.free()
	fixture([{"name":"Water Shot","slots":0,"stones":[]}]);enemy.position=Vector3(4,0,0);user.use_move(0,enemy);await create_timer(.05).timeout
	user.take_damage(20000,enemy);var hp_before_landing:float=enemy.current_hp
	await create_timer(.9).timeout
	check(user.knocked_out and enemy.current_hp<hp_before_landing,"A projectile already in flight should still land after its user is knocked out")
	# A linked destination uses its own stones: with Reach the link still lands beyond its base range.
	# Rain Drop lands at .85s; the link's Water Shot leaves at ~1.3s and needs ~.4s to fly, so HP sampled at 1.2s isolates the link's hit.
	var far:=Vector3(GameData.MOVES["Water Shot"].range/35.0+.9,0,0)
	fixture([{"name":"Rain Drop","slots":2,"stones":["reach","link:Water Shot"]},{"name":"Water Shot","slots":2,"stones":["reach","link_from:Rain Drop"]}])
	enemy.position=far;enemy.current_hp=10000;user.use_move(0,enemy);await create_timer(1.2).timeout
	var after_rain:float=enemy.current_hp;await create_timer(1.2).timeout
	check(events.any(func(e):return e.name=="Water Shot") and enemy.current_hp<after_rain,"A linked move should use its own Reach Stone when fired through the link")
	fixture([{"name":"Rain Drop","slots":2,"stones":["reach","link:Water Shot"]},{"name":"Water Shot","slots":1,"stones":["link_from:Rain Drop"]}])
	enemy.position=far;enemy.current_hp=10000;user.use_move(0,enemy);await create_timer(1.2).timeout
	after_rain=enemy.current_hp;await create_timer(1.2).timeout
	check(events.any(func(e):return e.name=="Water Shot") and is_equal_approx(enemy.current_hp,after_rain),"Without Reach the same link falls short of the target")
	fixture([{"name":"Water Shot","slots":1,"stones":["echo"]}]);user.use_move(0,enemy);enemy.queue_free()
	await create_timer(.95).timeout
	check(user.delayed_executions_resolved>0,"Freed target broke the delayed Echo")
	fixture([{"name":"Downpour","slots":1,"stones":[]}]);user.use_move(0,enemy)
	await create_timer(.6).timeout
	var hp:=enemy.current_hp;var effect:Node
	for child in arena.get_children():
		if child.has_method("update_shot"):effect=child
	var effect_time:float=effect.elapsed
	paused=true;await create_timer(.3,true).timeout
	check(enemy.current_hp==hp and effect.elapsed==effect_time,"Pause did not freeze active moves")
	paused=false;await create_timer(.6).timeout
	check(enemy.current_hp<hp,"Move did not resume after pause")
	fixture([{"name":"Water Jet","slots":1,"stones":["echo"]}]);user.use_move(0,enemy);await create_timer(.1).timeout
	user.take_damage(20000,enemy);var hp_at_knockout:=enemy.current_hp
	await create_timer(.5).timeout
	check(user.knocked_out and user.motion_lock==0 and enemy.current_hp==hp_at_knockout,"Knockout failed to interrupt the channel")
	check(events.size()==1,"Knockout triggered a canceled move's Echo")
	fixture([{"name":"Pollen Puff","slots":0,"stones":[]}]);user.current_hp=5000
	var expedition:=Expedition3D.new();arena.add_child(expedition);expedition.set_process(false);expedition.manual_move(user,0)
	await create_timer(.1).timeout
	check(user.current_hp>5000,"Expedition manual support input required an enemy target")
	# A brief live battle exercises normal physics, moving targets, deaths, and
	# simultaneous area/status casts (the fast unit tests freeze actor movement).
	arena.free();arena=Node3D.new();root.add_child(arena)
	var live:=Expedition3D.new();arena.add_child(live)
	var team:Array=[]
	for i in 5:
		var q:=GameData.make_quiblet(i,20)
		var names:Array=["Firestorm","Whirlpool","Water Jet","Healing Bloom"] if i%2==0 else ["Flame Dash","Bubble Trap","Ignite","Combust"]
		q.moves=[]
		for name in names:q.moves.append({"name":name,"slots":2,"stones":[]})
		team.append(q)
	live.begin(team,2,false,false)
	for i in live.team.size():live.team[i].position=Vector3(4,0,-1+i*.8)
	for i in live.enemies.size():live.enemies[i].position=Vector3(6,0,-1+i*.8)
	for step in 12:
		for member in live.team:
			if member.current_hp>0:live.manual_move(member,step%4)
		await create_timer(.15).timeout
	var finished_count:=[0];live.expedition_finished.connect(func(_result):finished_count[0]+=1)
	live.finish(false);await create_timer(.1).timeout
	check(finished_count[0]==1,"Live expedition did not finish exactly once")
	check(live.get_children().filter(func(c):return c.has_method("update_shot") and not c.done).is_empty(),"Expedition end left live damaging effects")
	arena.free()
	print("QUIBLETS_MOVES_RUNTIME checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
