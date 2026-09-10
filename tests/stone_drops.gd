extends SceneTree

var failures:=0
var rewards:Array[Dictionary]=[]

func check(condition:bool,message:String)->void:
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func run()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=934183
	var control:=RandomNumberGenerator.new();control.seed=934183
	check(GameData.roll_enemy_stone_kind({"stone_drop_chance":0.0},rng)=="","Zero-chance enemy dropped a stone")
	control.randf()
	check(rng.state==control.state,"A failed stone drop must not consume a stone-type roll")
	var counts:={"":0,"power_stone":0,"move_stone":0}
	for i in 100000:counts[GameData.roll_enemy_stone_kind({},rng)]+=1
	var dropped:int=counts.power_stone+counts.move_stone
	check(absf(float(dropped)/100000-0.468)<.006,"Default overall stone chance changed")
	check(absf(float(counts.move_stone)/dropped-.04)<.003,"Successful drops must split 96% Power / 4% Move")
	var guaranteed:={"":0,"power_stone":0,"move_stone":0}
	for i in 100000:guaranteed[GameData.roll_enemy_stone_kind({"stone_drop_chance":1.0},rng)]+=1
	check(guaranteed[""]==0,"Guaranteed-drop enemy failed to drop a stone")
	check(absf(float(guaranteed.power_stone)/100000-.96)<.003,"Enemy-specific chances changed the conditional type split")
	# Exercise the real defeat handler, including inventory entries and the
	# reward signal used by the collection animation, not only the roll helper.
	seed(84052)
	var expedition:=Expedition3D.new();root.add_child(expedition);expedition.set_process(false)
	for name in GameData.INGREDIENTS:expedition.loot[name]=0
	expedition.reward_acquired.connect(func(reward,_position):rewards.append(reward))
	var actual_counts:={"power_stone":0,"move_stone":0}
	for i in 528:
		var enemy:=QuibletActor3D.new();enemy.enemy=true;enemy.data={"stone_drop_chance":1.0 if i<512 else 0.0}
		expedition.add_child(enemy);enemy.set_physics_process(false);expedition.enemies.append(enemy)
		rewards.clear();expedition._on_actor_defeated(enemy)
		var stones:=rewards.filter(func(reward):return reward.kind in ["power_stone","move_stone"])
		check(stones.size()==(1 if i<512 else 0),"Defeated enemy awarded the wrong number of stones")
		check(rewards.filter(func(reward):return reward.kind=="ingredient").size()==1,"Stone change interfered with ingredient loot")
		for reward in stones:
			actual_counts[reward.kind]+=1
			check(int(reward.amount)==1,"Stone collection animation has the wrong amount")
			if reward.kind=="power_stone":check(reward.has("power") and reward.has("tier"),"Power Stone drop lost its rolled stats")
			else:check(reward.has("texture") and reward.has("effect"),"Move Stone drop lost its icon/effect")
	check(actual_counts.move_stone>0 and actual_counts.power_stone>0,"Defeat-handler test must cover both stone types")
	check(expedition.power_stones.size()==actual_counts.power_stone,"Power Stone drops were not added to the expedition inventory")
	var move_total:=0
	for amount in expedition.move_stones.values():move_total+=int(amount)
	check(move_total==actual_counts.move_stone,"Move Stone drops were not added to the expedition inventory")
	expedition.queue_free();await process_frame
	print("QUIBLETS_STONE_DROPS_OK rolls=200000 defeats=528 default_counts=",counts," guaranteed_counts=",guaranteed," failures=",failures)
	quit(0 if failures==0 else 1)
