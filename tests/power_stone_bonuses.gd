extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func stones_with(bonus_name:String,count:int,stone_type:="Health")->Array:
	var stones:Array=[]
	for i in count:stones.append(GameData.make_power_stone(stone_type,1,[bonus_name]))
	return stones

func fitted(q:Dictionary,stones:Array)->void:
	for i in 16:q.power_slot_stones[i]=stones[i] if i<stones.size() else {}

func actor_for(q:Dictionary,enemy:bool,parent:Node)->QuibletActor3D:
	var actor:=QuibletActor3D.new();actor.setup(q,enemy);parent.add_child(actor);actor.set_physics_process(false);return actor

func run()->void:
	# Every bonus has a stat, a fixed amount, and text that states the exact number.
	for bonus_name in GameData.POWER_STONE_BONUSES:
		var info:Dictionary=GameData.POWER_STONE_BONUSES[bonus_name]
		check(not str(info.stat).is_empty() and float(info.amount)>0.0 and str(info.text).contains("%") and str(info.text).contains(str(roundi(float(info.amount)*100))),"Bonus %s must state its exact percentage"%bonus_name)
		check(GameData.bonus_description(bonus_name)=="%s: %s"%[bonus_name,info.text],"Bonus descriptions must name the stat and the exact change")
	check(GameData.bonus_description("Fixture bonus A")=="Fixture bonus A (no effect)","Unknown bonus names must not claim an effect")
	check(GameData.stone_bonus_totals(stones_with("Movement Speed",3)).get("speed",0.0)>.299 and GameData.stone_bonus_totals(stones_with("Movement Speed",3)).get("speed",0.0)<.301,"Bonuses stack additively across stones")
	# Health and Attack bonuses change the derived stats by exactly their percentage.
	var base:=GameData.make_quiblet(0,10);var base_hp:=GameData.max_hp(base);var base_attack:=GameData.attack(base)
	var boosted:=base.duplicate(true);fitted(boosted,[GameData.make_power_stone("Health",1,["Health","Attack"])])
	var health_stone:Dictionary=boosted.power_slot_stones[0]
	check(GameData.max_hp(boosted)==int((base_hp+health_stone.power)*1.05) and GameData.attack(boosted)==int(base_attack*1.05),"Health and Attack bonuses apply +5% after stone power")
	# Live effects on actors.
	var arena:=Node3D.new();root.add_child(arena)
	var plain:=actor_for(GameData.make_quiblet(0,10),false,arena)
	var speedy_data:=GameData.make_quiblet(0,10);fitted(speedy_data,stones_with("Movement Speed",2));var speedy:=actor_for(speedy_data,false,arena)
	check(is_equal_approx(speedy.speed,plain.speed*1.2),"Two Movement Speed bonuses give exactly +20% speed")
	var quick_data:=GameData.make_quiblet(0,10);fitted(quick_data,stones_with("Move Cooldown",1));var quick:=actor_for(quick_data,false,arena)
	var victim:=actor_for(GameData.make_quiblet(0,10),true,arena);victim.position=Vector3(2,0,0);victim.max_hp=10000;victim.current_hp=10000
	quick.use_move(0,victim);plain.use_move(0,victim)
	check(is_equal_approx(quick.move_cooldowns[0],plain.move_cooldowns[0]*.94),"One Move Cooldown bonus shortens cooldowns by exactly 6%")
	var tough_data:=GameData.make_quiblet(0,10);fitted(tough_data,stones_with("Damage Resistance",2));var tough:=actor_for(tough_data,false,arena);tough.max_hp=1000;tough.current_hp=1000
	tough.take_damage(100.0,null,false)
	check(is_equal_approx(tough.current_hp,910.0),"Two Damage Resistance bonuses cut damage by exactly 10%")
	var healed_data:=GameData.make_quiblet(0,10);fitted(healed_data,stones_with("Healing Received",1));var healed:=actor_for(healed_data,false,arena);healed.max_hp=1000;healed.current_hp=500
	healed.receive_shared_heal(100.0)
	check(is_equal_approx(healed.current_hp,610.0),"One Healing Received bonus adds exactly 10% to heals")
	var sturdy_data:=GameData.make_quiblet(0,10);fitted(sturdy_data,stones_with("Knockback Resistance",1));var sturdy:=actor_for(sturdy_data,false,arena);sturdy.position=Vector3.ZERO
	sturdy.displace(Vector3(2,0,0))
	check(is_equal_approx(sturdy.position.x,1.5),"One Knockback Resistance bonus shortens displacement by exactly 25%")
	var crit_data:=GameData.make_quiblet(0,10);fitted(crit_data,stones_with("Critical Hit Rate",13));var critter:=actor_for(crit_data,false,arena)
	check(is_equal_approx(critter.bonus_value("crit"),GameData.bonus_cap("crit")),"Thirteen crit bonuses stop at the crit cap")
	critter.bonus_totals["crit"]=1.0
	victim.current_hp=10000;victim.take_damage(100.0,critter,true)
	check(is_equal_approx(victim.current_hp,10000.0-100.0*GameData.CRITICAL_HIT_MULTIPLIER),"A critical hit deals exactly 1.5× damage")
	var dodgy_data:=GameData.make_quiblet(0,10);fitted(dodgy_data,stones_with("Evasion",16));var dodgy:=actor_for(dodgy_data,false,arena)
	check(is_equal_approx(dodgy.bonus_value("evasion"),GameData.bonus_cap("evasion")),"Sixteen Evasion bonuses stop at the evasion cap")
	dodgy.bonus_totals["evasion"]=1.0
	var dodged:=0
	for i in 50:
		if not dodgy.accepts_hit_from(victim):dodged+=1
	check(dodged==50,"Stacked Evasion bonuses reach a guaranteed dodge")
	# Drops: bonuses appear at the documented rates and Fortune doubles them.
	var rng:=RandomNumberGenerator.new();rng.seed=4471;var with_bonus:=0;var fortune_bonus:=0;var sizes:={}
	for i in 20000:
		var bonuses:=GameData.roll_power_stone_bonuses(false,rng);if not bonuses.is_empty():with_bonus+=1
		sizes[bonuses.size()]=int(sizes.get(bonuses.size(),0))+1
		if not GameData.roll_power_stone_bonuses(true,rng).is_empty():fortune_bonus+=1
		check(bonuses.size()<=4 and bonuses.all(func(name):return GameData.POWER_STONE_BONUSES.has(name)) and bonuses.size()==bonuses.size(),"Rolled bonuses must come from the catalog")
	check(absf(float(with_bonus)/20000-.18)<.012 and absf(float(fortune_bonus)/20000-.36)<.015 and int(sizes.get(2,0))>0 and int(sizes.get(3,0))>0,"Bonus drop rates should match the documented chances")
	# UI: the detail panel and icon tooltips state the exact effects.
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	var sample:=GameData.make_power_stone("Attack",3,["Critical Hit Rate","Movement Speed"]);game.power_stone_inventory.append(sample)
	game.selected_roster=0;game.show_quiblet_edit();await process_frame
	game.select_inventory_stone(game.power_stone_inventory_data(sample,game.power_stone_inventory.size()-1));await process_frame
	var description:RichTextLabel=game.content.find_child("PowerStoneBonusDescription",true,false)
	check(description!=null and description.text.contains("Critical Hit Rate: +8% chance for a critical hit (1.5× damage)") and description.text.contains("Movement Speed: +10% movement speed"),"The stone detail panel must state each bonus's exact effect")
	var icon:=PowerStoneIcon.new();icon.setup(sample)
	check(icon.tooltip_text.contains("+%d Attack"%sample.power) and icon.tooltip_text.contains("+8%") and icon.tooltip_text.contains("+10% movement speed"),"Stone icons must carry the exact effects in their tooltip")
	icon.free()
	print("QUIBLETS_POWER_STONE_BONUSES_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
