extends SceneTree

func _initialize():call_deferred("run")

func run():
	var field:=Expedition3D.new();root.add_child(field);field.set_physics_process(false)
	var actors:Array[QuibletActor3D]=[]
	for i in 3:
		var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(10,60),i==0)
		field.add_child(actor);actor.set_physics_process(false);actors.append(actor)
	var enemy:=actors[0];var player:=actors[1];var other:=actors[2]
	player.current_hp=player.max_hp*.4;player.in_combat=true
	var hp:=player.current_hp
	player.process_actor_physics(1.0)
	assert(player.current_hp==hp,"No natural healing during a fight, even without a target")
	player.in_combat=false;player.target=enemy;player.process_actor_physics(.1)
	assert(player.current_hp==hp,"A live combat target also prevents natural healing")
	player.target=null;player.process_actor_physics(1.0)
	assert(is_equal_approx(player.current_hp,hp+player.max_hp*.01),"Exploration restores natural recovery")
	player.in_combat=true;hp=player.current_hp;player.receive_shared_heal(100)
	assert(player.current_hp>hp,"Deliberate healing still works in combat")
	# Move recovery must not silently suppress the independent basic attack.
	enemy.position=Vector3.ZERO;player.position=Vector3(1,0,0);enemy.target=player
	enemy.enemy_cast_recovery=2;enemy.basic_cooldown=0;enemy.try_basic_attack(1)
	assert(enemy.basic_cooldown>0)
	enemy.basic_cooldown=0;enemy.boss_warning_time=1;enemy.try_basic_attack(1)
	assert(enemy.basic_cooldown==0,"Telegraphed attack windups remain safe from basics")
	enemy.boss_warning_time=0
	# A slightly closer teammate doesn't instantly draw off pursuit.
	player.position.x=3;other.position.x=2
	var candidates:Array[QuibletActor3D]=[player,other]
	assert(field.nearest(enemy,candidates)==player)
	# Running clear hands aggro to a closer opponent; taunts still override.
	player.position.x=9;assert(field.nearest(enemy,candidates)==other)
	player.position.x=3;other.add_status("taunt",3,1,other)
	assert(field.nearest(enemy,candidates)==other)
	other.statuses.clear();player.current_hp=0
	assert(field.nearest(enemy,candidates)==other,"Never pursue a fainted Quiblet")
	# Knockout recovery still offers a surviving teammate a comeback.
	player.knocked_out=true;player.revive_time=.01;player.process_actor_physics(.02)
	assert(not player.knocked_out and is_equal_approx(player.current_hp,player.max_hp*.5))
	field.free()
	print("COMBAT_PRESSURE_OK: exploration-only regen, active healing, basic pressure, pursuit, escape, taunt and revival")
	quit()
