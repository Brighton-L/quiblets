extends SceneTree
# Isolated flat arena: real encounter generation, physics, casts, AI, healing,
# target selection and revivals. No save access, terrain rendering or loot.
class MeterActor extends QuibletActor3D:
	var received:=0.0
	var healed:=0.0
	func take_damage(amount:float,attacker:QuibletActor3D=null,reflectable:=true)->float:
		var actual:=super.take_damage(amount,attacker,reflectable)
		received+=actual
		return actual
	func receive_shared_heal(amount:float)->void:
		var before:=current_hp
		super.receive_shared_heal(amount)
		healed+=current_hp-before

class Arena extends Expedition3D:
	var audit_time:=0.0
	var flee:=false
	var rescue:=false
	var casts:=0
	var boss_casts:=0
	var warnings:=0
	var last_warning:=false
	var min_alive:=3
	var revivals:=0
	var outcome:="timeout"
	var escaped_distance:=0.0
	func pick_spawn_point(_for_boss:=false)->int:return 0
	func patch_zone(_point:Vector2)->int:return 0
	func encounter_positions(center:Vector2,count:int)->Array[Vector2]:
		var result:Array[Vector2]=[]
		for i in count:result.append(center+Vector2((i%3)*2,(i/3)*2))
		return result
	func play_spawn_drop(_actor:QuibletActor3D,_delay:=0.0,_landing_squash:=true)->void:pass
	func boss_intro(_boss:QuibletActor3D)->void:pass
	func line_walkable(_a:Vector2,_b:Vector2,_floating:=false)->bool:return true
	func place_actor(actor:QuibletActor3D)->void:
		actor.arena=arena_rect;add_child(actor)
		actor.set_meta("alerted",true)
		actor.move_used.connect(func(a,_b,_c,_d):
			if a.enemy:
				casts+=1
				if a.get_meta("level_boss",false):boss_casts+=1)
	func _physics_process(delta:float)->void:
		if outcome!="timeout":return
		audit_time+=delta
		var live_team:Array[QuibletActor3D]=[]
		var foes:Array[QuibletActor3D]=[]
		for actor in team:
			if actor.current_hp>0:live_team.append(actor)
		for actor in enemies:
			if actor.current_hp>0:foes.append(actor)
		min_alive=mini(min_alive,live_team.size())
		if live_team.is_empty():outcome="defeat";return
		if foes.is_empty():outcome="victory";return
		for actor in enemies:
			if actor.current_hp>0:actor.target=nearest(actor,live_team)
			if actor.get_meta("level_boss",false):
				var warning:=actor.boss_warning_time>0
				if warning and not last_warning:warnings+=1
				last_warning=warning
		for actor in live_team:
			actor.in_combat=true
			if not is_instance_valid(actor.target) or actor.target.current_hp<=0:actor.target=nearest(actor,foes)
			if flee and actor==team[2] and audit_time<10.5:
				# Keep running around the arena, using ordinary movement commands.
				var goal:=Vector3(-18,0,-14) if audit_time<5 else Vector3(-18,0,14)
				actor.command(goal)
				escaped_distance=maxf(escaped_distance,actor.position.distance_to(Vector3(-3,0,2)))
			elif not rescue:
				for index in actor.data.moves.size():
					if actor.move_cooldowns[index]<=0:actor.request_move(index,actor.target)
		# Same boss defeat rule as live expeditions, without loot generation.
		for actor in enemies:
			if actor.get_meta("level_boss",false) and actor.current_hp<=0:
				for other in enemies:other.current_hp=0
		if rescue and revivals>=2:outcome="recovered"

func _initialize():call_deferred("run")

func equipped(species_index:int,names:Array,build:String)->Dictionary:
	var q:=GameData.make_quiblet(species_index,80 if build=="strong" else 60)
	q.moves=[]
	for name in names:
		assert(GameData.learnset(species_index).has(name))
		q.moves.append({"name":name,"slots":3,"stones":["drain","drain","drain"] if build=="drain" else (["heavy","heavy","rush"] if build=="strong" else [])})
	for i in 8:
		q.power_slot_stones[i]=GameData.normalize_power_stone({"type":"Health" if i<4 else "Attack","power":450 if build=="strong" else 300,"bonuses":["Healing Received","Damage Resistance"] if build=="support_bonus" else [],"tier":3})
	return q

func run():
	for scenario in ["ordinary","field_boss","boss","escape","escape_stand"]:
		if "--boss-only" in OS.get_cmdline_user_args() and scenario=="ordinary":continue
		for build in (["damage","support","support_bonus","drain","strong"] if not scenario.begins_with("escape") else ["damage"]):
			for trial in [23,41,79]:
				seed(trial)
				var field:=Arena.new();root.add_child(field);field.set_process(false)
				field.process_physics_priority=-100
				field.arena_rect=Rect2(-24,-20,48,40)
				field.stage_kind="boss" if scenario=="boss" else "level"
				field.stage_node_index=6 if scenario=="boss" else 5
				field.stage_area_index=13;field.stage_level=GameData.expedition_node_level(13,6 if scenario=="boss" else 5);field.enemy_bonus=GameData.stage_enemy_stone_bonus(field.stage_level)
				field.spawn_points.assign([Vector2(4,0)]);field.spawn_rng.seed=trial
				field.team_data=[equipped(10,["Rock Toss","Quake","Mud Shot"],build),equipped(7,["Fireball","Flame Burst","Firestorm"],build),equipped(27,["Tentacle Zap","Static Pulse","Discharge"],build)]
				if build.begins_with("support"):field.team_data[1]=equipped(5,["Healing Bloom","Pollen Puff","Spore Cloud"],build)
				field.team_average_level=GameData.average_team_level(field.team_data)
				for i in 3:
					var player:=MeterActor.new();player.setup(field.team_data[i]);field.place_actor(player);field.team.append(player);player.position=Vector3(-3,0,-2+i*2);player.in_combat=true
					player.revived.connect(func(_a):field.revivals+=1)
				if scenario=="ordinary":field.spawn_enemy_set()
				else:field.spawn_boss_wave()
				# spawn functions label actors unalerted after placement.
				for actor in field.enemies:actor.set_meta("alerted",true)
				if scenario.begins_with("escape"):
					field.rescue=true;field.flee=scenario=="escape"
					field.team[0].take_damage(field.team[0].max_hp*10)
					field.team[1].take_damage(field.team[1].max_hp*10)
					field.team[2].current_hp=field.team[2].max_hp*.35
				while field.audit_time<90 and field.outcome=="timeout":await physics_frame
				var row:={"scenario":scenario,"build":build,"seed":trial,"outcome":field.outcome,"seconds":snappedf(field.audit_time,.1),"min_alive":field.min_alive,"revivals":field.revivals,"enemy_casts":field.casts,"boss_casts":field.boss_casts,"warnings":field.warnings,"escape_distance":snappedf(field.escaped_distance,.1),"hp":[],"damage":[],"healing":[],"knockouts":[],"enemies":[]}
				for actor in field.team:
					row.hp.append(snappedf(actor.current_hp/actor.max_hp,.01));row.damage.append(roundi(actor.received));row.healing.append(roundi(actor.healed));row.knockouts.append(actor.knockouts)
				for actor in field.enemies:row.enemies.append({"species":GameData.species(actor.data.species).name,"moves":actor.data.moves.map(func(m):return m.name)})
				print("AUDIT ",JSON.stringify(row))
				field.free();await process_frame
	quit()
