extends SceneTree
# A collision/terrain obstruction must not prevent an in-range attack.
class BlockedActor extends QuibletActor3D:
	func move_toward_point(_point:Vector3,_delta:float,_steer:=true)->void:pass
func _initialize():call_deferred("run")
func run():
	for mode in ["direct","routed","retreat"]:
		var routed:bool=mode=="routed"
		var arena:=Node3D.new();root.add_child(arena)
		var q:=GameData.make_quiblet(10,65);q.moves=[{"name":"Rock Toss","slots":0,"stones":[]},{"name":"Quake","slots":0,"stones":[]}]
		var boss:=BlockedActor.new();boss.setup(q,true);arena.add_child(boss);boss.set_physics_process(false);boss.set_meta("level_boss",true);boss.move_cooldowns.fill(0)
		var player:=QuibletActor3D.new();player.setup(GameData.make_quiblet(0,60));arena.add_child(player);player.set_physics_process(false);player.position=Vector3(4,0,0);boss.target=player
		boss.retreating=mode=="retreat"
		if boss.retreating:boss.enemy_retreat_time=boss.ENEMY_RETREAT_DURATION
		boss.has_command=routed;boss.desired_point=player.position;boss.set_meta("chase_routed",routed)
		var casts:=[0];boss.move_used.connect(func(_a,_b,_c,_d):casts[0]+=1)
		var warned:=false;var initial_hp:=player.current_hp
		for tick in 300:
			boss.process_actor_physics(1.0/60)
			warned=warned or boss.boss_warning_time>0
			for node in arena.get_children():
				if node is QuibletActor3D or node.is_queued_for_deletion():continue
				if node.get_script() in [boss.MOVE_CAST,boss.BASIC_ATTACK]:node._physics_process(1.0/60);node.set_physics_process(false)
		assert(casts[0]>=2,"A chasing boss must fire reachable moves even if it cannot settle")
		assert(warned and player.current_hp<initial_hp,"Chasing attacks must actually hit and advance the boss pattern")
		# No remote attack/telegraph after the target moves out of every reach.
		boss.clear_boss_warning();boss.enemy_cast_recovery=0;boss.boss_attacks=2;boss.move_cooldowns.fill(0);player.position.x=40
		var before:int=casts[0];boss.process_actor_physics(1.0/60)
		assert(casts[0]==before and boss.boss_warning_time==0)
		# Player movement orders still take precedence over automatic basics.
		player.target=boss;player.position.x=1.5;player.has_command=true;player.basic_cooldown=0
		player.try_basic_attack(1.5);assert(player.basic_cooldown==0)
		arena.free();await process_frame
	print("ATTACK_WHILE_CHASING_OK: blocked/routed/retreating bosses cast, damage, warn, respect range and player orders")
	quit()
