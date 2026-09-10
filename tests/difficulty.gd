extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func actor_for(level:int,enemy:bool,parent:Node,area:int=0)->QuibletActor3D:
	var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(0,level),enemy,0,-1,GameData.enemy_scaling(area) if enemy else {});parent.add_child(actor);actor.set_physics_process(false);return actor

func run()->void:
	# Enemy scaling rises monotonically across islands and hits its anchors.
	var first:=GameData.enemy_scaling(0);var mid:=GameData.enemy_scaling(6);var last:=GameData.enemy_scaling(15)
	check(is_equal_approx(float(first.hp),.68) and is_equal_approx(float(first.damage),.58) and is_equal_approx(float(mid.hp),1.0) and is_equal_approx(float(mid.damage),.95) and is_equal_approx(float(last.hp),1.55) and is_equal_approx(float(last.damage),1.4),"Enemy scaling anchors: 68%/58% on the first island, parity by the sixth, 155%/140% on the last")
	for area in range(1,16):
		var previous:=GameData.enemy_scaling(area-1);var current:=GameData.enemy_scaling(area)
		check(float(current.hp)>=float(previous.hp) and float(current.damage)>=float(previous.damage),"Enemy scaling never drops between islands")
	# Later islands close part of the team's level lead and borrow part of its stone strength.
	check(is_equal_approx(GameData.enemy_level_catch_up(0),0.0) and is_equal_approx(GameData.enemy_level_catch_up(2),0.0) and is_equal_approx(GameData.enemy_level_catch_up(6),.45) and is_equal_approx(GameData.enemy_level_catch_up(15),.9),"Enemy level catch-up anchors are wrong")
	check(is_equal_approx(GameData.enemy_stone_share(0),0.0) and is_equal_approx(GameData.enemy_stone_share(6),.55) and is_equal_approx(GameData.enemy_stone_share(15),1.1),"Enemy stone share anchors are wrong")
	for area in range(1,16):check(GameData.enemy_level_catch_up(area)>=GameData.enemy_level_catch_up(area-1) and GameData.enemy_stone_share(area)>=GameData.enemy_stone_share(area-1),"Catch-up and stone share never drop between islands")
	check(GameData.enemy_level_for_stage(29,52,0)==29 and GameData.enemy_level_for_stage(29,52,6)==29+roundi(23*.45) and GameData.enemy_level_for_stage(29,20,15)==29,"Enemies only catch up toward a team that is ahead, and never on the first islands")
	var carry:=GameData.make_quiblet(0,52);carry.power_slot_stones[0]=GameData.make_power_stone("Attack",3,[]);carry.power_slot_stones[0].power=300;carry.power_slot_stones[1]=GameData.make_power_stone("Health",3,[]);carry.power_slot_stones[1].power=200
	var plain:=GameData.make_quiblet(5,50)
	var power:=GameData.team_stone_power([carry,plain])
	check(int(GameData.fitted_stone_power(carry).attack)==300 and int(power.attack)==int((150.0+300.0)*.5) and int(power.hp)==int((100.0+200.0)*.5),"Team stone power averages the mean and the strongest member")
	var bonus:=GameData.enemy_stone_bonus(power,6)
	check(int(bonus.attack)==int(225*.55) and int(bonus.hp)==int(150*.55) and int(GameData.enemy_stone_bonus(power,0).attack)==0,"Enemy stone bonus follows the island share")
	var scaled_game=load("res://main.tscn").instantiate();root.add_child(scaled_game);await process_frame
	scaled_game.roster[0].level=52;scaled_game.roster[0].power_slot_stones[0]=GameData.make_power_stone("Attack",3,[]);scaled_game.roster[0].power_slot_stones[0].power=300
	scaled_game.team_indices.clear();scaled_game.team_indices.append(0);scaled_game.area_progress[7]=8;scaled_game.start_area_level(7,0);await process_frame
	var expected_level:int=GameData.enemy_level_for_stage(GameData.expedition_area_level(7),52,7)
	check(scaled_game.expedition.enemies.all(func(enemy):return absi(int(enemy.data.level)-expected_level)<=1 and int(enemy.data.atk_bonus)==int(300*GameData.enemy_stone_share(7))),"Whiteout enemies should catch up toward a level-52 team and carry its stone share")
	scaled_game.expedition.finish(false);await process_frame;scaled_game.show_area_levels(0);scaled_game.start_area_level(0,0);await process_frame
	check(scaled_game.expedition.enemies.all(func(enemy):return absi(int(enemy.data.level)-GameData.expedition_area_level(0))<=1 and int(enemy.data.atk_bonus)==0),"First-island enemies stay at the island level with no stone share")
	scaled_game.expedition.finish(false);await process_frame;scaled_game.queue_free();await process_frame
	# Level gap factor.
	check(is_equal_approx(GameData.level_gap_factor(10,10),1.0) and is_equal_approx(GameData.level_gap_factor(20,10),1.35) and is_equal_approx(GameData.level_gap_factor(10,20),.65) and is_equal_approx(GameData.level_gap_factor(61,15),2.5) and is_equal_approx(GameData.level_gap_factor(15,61),.35),"Level gap scales 3.5% per level and clamps between 0.35× and 2.5×")
	var arena:=Node3D.new();root.add_child(arena)
	var low:=actor_for(15,false,arena);var high_enemy:=actor_for(61,true,arena,15);var peer_enemy:=actor_for(15,true,arena,0)
	low.max_hp=10000;low.current_hp=10000;high_enemy.max_hp=10000;high_enemy.current_hp=10000;peer_enemy.max_hp=10000;peer_enemy.current_hp=10000
	low.take_damage(100.0,high_enemy,false);check(is_equal_approx(low.current_hp,10000.0-250.0),"A level-61 enemy hits a level-15 Quiblet for 2.5× damage")
	high_enemy.take_damage(100.0,low,false);check(is_equal_approx(high_enemy.current_hp,10000.0-35.0),"A level-15 Quiblet hits a level-61 enemy for 0.35× damage")
	low.current_hp=10000;low.take_damage(100.0,peer_enemy,false);check(is_equal_approx(low.current_hp,9900.0),"Equal levels take unscaled damage")
	low.current_hp=10000;low.take_damage(100.0,null,false);check(is_equal_approx(low.current_hp,9900.0),"Damage without an attacker is unscaled")
	# Enemy stats follow the island scaling.
	var q:=GameData.make_quiblet(0,20)
	var early_enemy:=QuibletActor3D.new();early_enemy.setup(q,true,0,-1,GameData.enemy_scaling(0));arena.add_child(early_enemy)
	var late_enemy:=QuibletActor3D.new();late_enemy.setup(q,true,0,-1,GameData.enemy_scaling(15));arena.add_child(late_enemy)
	check(is_equal_approx(early_enemy.max_hp,GameData.max_hp(q)*.68) and is_equal_approx(early_enemy.damage_multiplier,.58) and is_equal_approx(late_enemy.max_hp,GameData.max_hp(q)*1.55) and is_equal_approx(late_enemy.damage_multiplier,1.4),"Enemy HP and damage multipliers come from the island scaling")
	# Knockouts: every revive takes the same ten seconds, with no limit.
	check(is_equal_approx(GameData.knockout_revive_seconds(1),10.0) and is_equal_approx(GameData.knockout_revive_seconds(3),10.0),"Every knockout revives after ten seconds")
	var fighter:=actor_for(10,false,arena);fighter.max_hp=100;fighter.current_hp=100
	for knockout in 3:
		fighter.take_damage(500.0,null,false);check(fighter.knocked_out and is_equal_approx(fighter.revive_time,10.0),"Knockout %d: ten seconds"%(knockout+1))
		var cooldown:=ExpeditionPortraitCooldown.new();cooldown.setup(fighter);check(is_equal_approx(cooldown.display_tint_ratio(),1.0),"The portrait starts fully shaded");cooldown.free()
		fighter._physics_process(10.1);check(not fighter.knocked_out and is_equal_approx(fighter.current_hp,50.0),"Knockout %d revives at half health"%(knockout+1))
	fighter.take_damage(500.0,null,false)
	# Natural recovery: team members regain 1% of max HP per second below full; enemies and knocked-out Quiblets do not.
	var healer:=actor_for(10,false,arena);healer.max_hp=1000;healer.current_hp=500;healer.target=null
	healer._physics_process(1.0);check(is_equal_approx(healer.current_hp,510.0),"A team Quiblet below full recovers 1% of max HP per second")
	healer.current_hp=995.0;healer._physics_process(1.0);check(is_equal_approx(healer.current_hp,1000.0),"Natural recovery never exceeds max HP")
	var enemy_regen:=actor_for(10,true,arena);enemy_regen.max_hp=1000;enemy_regen.current_hp=500;enemy_regen.target=null
	enemy_regen._physics_process(1.0);check(is_equal_approx(enemy_regen.current_hp,500.0),"Enemies do not recover naturally")
	fighter._physics_process(1.0);check(fighter.knocked_out and fighter.current_hp<=0.0,"A knocked-out Quiblet does not recover naturally")
	# Extra enemies on later islands, none early.
	check(GameData.extra_enemies_for_area(0)==0 and GameData.extra_enemies_for_area(5)==0 and GameData.extra_enemies_for_area(6)==1 and GameData.extra_enemies_for_area(12)==2 and GameData.extra_enemies_for_area(15)==2,"Islands 7 and 13 onward add one and two enemies per wave")
	# The matchup formula produces a real curve for a level-15 five-Quiblet team.
	var team:Array=[15,15,15,15,15]
	var early:=GameData.expected_matchup(team,GameData.expedition_area_level(0),0);var fourth:=GameData.expected_matchup(team,GameData.expedition_area_level(3),3);var sixth:=GameData.expected_matchup(team,GameData.expedition_area_level(5),5);var final:=GameData.expected_matchup(team,GameData.expedition_area_level(15),15)
	check(early>3.0 and fourth>1.0 and sixth<1.0 and final<.1,"A level-15 team should coast on island 1, hold on island 4, struggle on island 6, and stand no chance on island 16")
	var ahead:=GameData.expected_matchup([75,75,75],GameData.expedition_area_level(15),15)
	check(GameData.expected_matchup([61,61,61],GameData.expedition_area_level(15),15)<1.0 and ahead>.4 and ahead<1.0,"The last island stays demanding even for a team above its level, because enemies close most of the lead")
	var previous_ratio:=INF
	for area in 16:
		var ratio:=GameData.expected_matchup(team,GameData.expedition_area_level(area),area)
		check(ratio<=previous_ratio,"The matchup only gets harder from island to island for a fixed team");previous_ratio=ratio
	# Live expedition: late-island waves are larger and use the scaling; the route card reads HARD.
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	for species_index in [1,2,6,5]:game.roster.append(GameData.make_quiblet(species_index,15))
	game.team_indices.assign([0,1,2,3,4])
	for index in game.team_indices:game.roster[index].level=15
	game.area_progress[15]=8;game.start_area_level(15,0);await process_frame
	var late:Expedition3D=game.expedition
	check(late.enemies.size()>=3 and late.enemies.all(func(enemy):return is_equal_approx(enemy.damage_multiplier,1.4)),"Island 16 sets carry two extra enemies at full late scaling")
	late.finish(false);await process_frame
	game.area_progress[15]=0;game.show_area_levels(15);await process_frame
	var card:Control=game.content.find_child("LevelNode0",true,false)
	check(card.find_children("*","Label",true,false).any(func(item):return item.text=="HARD"),"The route card rates island 16 as HARD for a level-15 team")
	game.show_area_levels(0);await process_frame
	card=game.content.find_child("LevelNode0",true,false)
	check(card.find_children("*","Label",true,false).any(func(item):return item.text=="COMFORTABLE" or item.text=="✓ CLEARED"),"The route card rates island 1 as comfortable for a level-15 team")
	print("QUIBLETS_DIFFICULTY_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
