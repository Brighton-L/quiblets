extends SceneTree

var failures:=0
var checks:=0
var rewards:Array[Dictionary]=[]

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func tier_share(counts:Dictionary,tiers:Array)->float:
	var total:=0;var matched:=0
	for ingredient_name in counts:
		total+=int(counts[ingredient_name])
		if int(GameData.INGREDIENTS[ingredient_name].tier) in tiers:matched+=int(counts[ingredient_name])
	return float(matched)/maxf(total,1)

func sample(stage_level:int,rolls:int,rng:RandomNumberGenerator,candidates:Array=[])->Dictionary:
	var counts:={}
	for i in rolls:
		var ingredient_name:=GameData.roll_ingredient(stage_level,candidates,rng);counts[ingredient_name]=int(counts.get(ingredient_name,0))+1
	return counts

func run()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=51733
	check(GameData.INGREDIENTS.values().all(func(info):return int(info.tier)>=1 and int(info.tier)<=GameData.INGREDIENT_TIER_LEVELS.size()),"Every ingredient tier needs a drop level")
	for ingredient_name in GameData.INGREDIENTS:
		var previous:=0.0
		for stage_level in 62:
			var weight:=GameData.ingredient_drop_weight(ingredient_name,stage_level)
			check(weight>=GameData.INGREDIENT_TIER_FLOOR and weight<=1.0 and weight>=previous,"Drop weight must rise smoothly with stage level: "+ingredient_name);previous=weight
		check(is_equal_approx(GameData.ingredient_drop_weight(ingredient_name,61),1.0),"Late areas should drop every ingredient at full weight")
	check(is_equal_approx(GameData.ingredient_drop_weight("Bumbleberry",GameData.expedition_area_level(0)),1.0),"Common ingredients must always drop at full weight")
	check(GameData.ingredient_drop_weight("Sunplum",GameData.expedition_area_level(0))<.1 and GameData.ingredient_drop_weight("Frostberry",GameData.expedition_area_level(0))<.1,"Rare ingredients should be heavily down-weighted in the first area")
	var early:=sample(GameData.expedition_area_level(0),40000,rng)
	var late:=sample(GameData.expedition_area_level(15),40000,rng)
	check(tier_share(early,[3,4])<.06,"Tier 3-4 ingredients should be rare in the first area")
	check(tier_share(early,[1])>.7,"Tier 1 ingredients should dominate the first area")
	check(float(early.get("Sunplum",0))/40000<.015,"Sunplum should almost never drop in the first area")
	check(tier_share(late,[3,4])>.3,"Tier 3-4 ingredients should be common in the last area")
	check(late.size()==GameData.INGREDIENTS.size() and early.size()==GameData.INGREDIENTS.size(),"Every ingredient must remain obtainable at every level")
	var mid_share:=tier_share(sample(GameData.expedition_area_level(4),40000,rng),[3,4])
	check(mid_share>tier_share(early,[3,4]) and mid_share<tier_share(late,[3,4]),"Rare drop rates should increase between early and late areas")
	var berries:=["Bumbleberry","Dewmelon","Frostberry","Sunplum"]
	var early_berries:=sample(GameData.expedition_area_level(0),20000,rng,berries)
	var late_berries:=sample(GameData.expedition_area_level(15),20000,rng,berries)
	check(tier_share(early_berries,[3,4])<.08,"Early berry patches should rarely hold Frostberry or Sunplum")
	check(tier_share(late_berries,[3,4])>.4,"Late berry patches should hold rare berries about as often as common ones")
	check(early_berries.keys().all(func(name):return name in berries),"Berry patches must only pick from the berry list")
	# Exercise the real defeat handler and berry placement, not only the helper.
	seed(20931)
	for area_index in [0,15]:
		var expedition:=Expedition3D.new();expedition.stage_area_index=area_index;expedition.stage_kind="optional_berry_grove";root.add_child(expedition);expedition.set_process(false)
		expedition.stage_level=GameData.expedition_area_level(area_index);expedition.build_level()
		var patch_counts:={};var berry_patches:=0
		for patch in expedition.berry_nodes:
			var name:String=patch.get_meta("ingredient");check(GameData.INGREDIENTS.has(name),"Patch holds an unknown ingredient");patch_counts[name]=int(patch_counts.get(name,0))+1
			if name in berries:berry_patches+=1
		check(berry_patches>=expedition.berry_nodes.size()*.3,"A Berry Grove should still lean toward berries")
		for name in GameData.INGREDIENTS:expedition.loot[name]=0
		expedition.reward_acquired.connect(func(reward,_position):rewards.append(reward))
		var defeat_counts:={}
		for i in 4000:
			var enemy:=QuibletActor3D.new();enemy.enemy=true;enemy.data={"stone_drop_chance":0.0}
			expedition.add_child(enemy);enemy.set_physics_process(false);expedition.enemies.append(enemy)
			rewards.clear();expedition._on_actor_defeated(enemy)
			var ingredient_rewards:=rewards.filter(func(reward):return reward.kind=="ingredient")
			check(ingredient_rewards.size()==1,"Each defeat should award exactly one ingredient")
			var name:String=ingredient_rewards[0].name;defeat_counts[name]=int(defeat_counts.get(name,0))+1
		var share:=tier_share(defeat_counts,[3,4])
		if area_index==0:check(share<.08,"Enemy drops in the first area should rarely be rare ingredients")
		else:check(share>.3,"Enemy drops in the last area should include rare ingredients often")
		var loot_total:=0
		for amount in expedition.loot.values():loot_total+=int(amount)
		check(loot_total>=4000,"Defeat drops were not added to expedition loot")
		expedition.queue_free();await process_frame
	print("QUIBLETS_INGREDIENT_DROPS_OK checks=",checks," failures=",failures," early_rare=",snappedf(tier_share(early,[3,4]),.001)," late_rare=",snappedf(tier_share(late,[3,4]),.001))
	quit(0 if failures==0 else 1)
