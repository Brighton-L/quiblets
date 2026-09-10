extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func stone_reward(stone_type:String,tier:int,bonuses:Array=[])->Dictionary:
	var reward:=GameData.make_power_stone(stone_type,tier,bonuses);reward.merge({"kind":"power_stone","name":stone_type+" Power Stone","amount":1});return reward

func sparkles_of(pickup:Control)->RewardSparkles:
	return pickup.find_child("RewardSparkles",true,false) as RewardSparkles

func run()->void:
	var stone_texture:String=GameData.stone_info("echo").texture
	check(GameData.reward_sparkle_level({"kind":"ingredient","name":"Bumbleberry"})==0 and GameData.reward_sparkle_level({"kind":"ingredient","name":"Stonebean"})==0,"Common ingredients should not sparkle")
	check(GameData.reward_sparkle_level({"kind":"ingredient","name":"Frostberry"})==1 and GameData.reward_sparkle_level({"kind":"ingredient","name":"Sunplum"})==2,"Tier-3 ingredients should be good and tier-4 great")
	check(GameData.reward_sparkle_level({"kind":"move_stone","name":"Echo Stone","effect":"echo","texture":stone_texture})==1,"Every Move Stone drop should sparkle")
	check(GameData.reward_sparkle_level(stone_reward("Health",1))==0 and GameData.reward_sparkle_level(stone_reward("Attack",2))==0,"Low-tier Regular Power Stones should not sparkle")
	check(GameData.reward_sparkle_level(stone_reward("Health",3))==1 and GameData.reward_sparkle_level(stone_reward("Attack",1,["Critical Hit Rate"]))==1,"Tier-3 or Bronze Power Stones should be good")
	check(GameData.reward_sparkle_level(stone_reward("Health",4))==2 and GameData.reward_sparkle_level(stone_reward("Attack",1,["Critical Hit Rate","Movement Speed"]))==2,"Tier-4 or Silver Power Stones should be great")
	check(GameData.reward_sparkle_level({"kind":"unknown"})==0,"Unknown rewards should not sparkle")
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_expedition("Sparkle test");game.expedition.process_mode=Node.PROCESS_MODE_DISABLED;await process_frame
	var plain:Control=game.build_reward_pickup({"kind":"ingredient","name":"Bumbleberry","amount":1})
	check(sparkles_of(plain)==null,"A plain pickup should not carry sparkles")
	var good:Control=game.build_reward_pickup({"kind":"move_stone","name":"Echo Stone","effect":"echo","amount":1,"texture":stone_texture})
	var good_sparkles:=sparkles_of(good)
	check(good_sparkles!=null and good_sparkles.level==1 and good_sparkles.stars.size()>0 and good_sparkles.halo==null,"A good pickup should carry level-1 sparkles without a halo")
	var great:Control=game.build_reward_pickup(stone_reward("Attack",4))
	var great_sparkles:=sparkles_of(great)
	check(great_sparkles!=null and great_sparkles.level==2 and great_sparkles.stars.size()>good_sparkles.stars.size() and great_sparkles.halo!=null and great_sparkles.halo.z_index<0,"A great pickup should carry more sparkles plus a halo drawn behind the icon")
	check(great_sparkles.get_index()>great.find_child("PowerStoneIcon",true,false).get_index(),"Sparkles should draw over the reward icon")
	check(great_sparkles.size==great.size and great_sparkles.halo.size==great.size,"Sparkles should cover the pickup so the stars ring the icon")
	for pickup in [plain,good,great]:
		check(pickup.find_children("*","Label",true,false).is_empty() and not pickup is Panel,"Sparkles must not add labels or a background to pickups")
		check(pickup.find_children("*","",true,false).all(func(node):return node.mouse_filter==Control.MOUSE_FILTER_IGNORE),"Sparkles must not intercept clicks")
	# The stars ride along with the real collection animation and vanish with it.
	game.reward_pickup_delay=0.0
	game.show_expedition_reward({"kind":"ingredient","name":"Sunplum","amount":1},game.expedition.team[0].global_position)
	var flying:Control=game.content.find_children("RewardPickup*","",true,false)[-1]
	var flying_sparkles:=sparkles_of(flying)
	check(flying_sparkles!=null and flying_sparkles.level==2,"A collected Sunplum should sparkle at the great level")
	await create_timer(.4).timeout
	check(is_instance_valid(flying_sparkles) and flying_sparkles.elapsed>.2 and flying.visible and flying_sparkles.get_parent()==flying,"Sparkles should keep animating while the pickup hovers")
	await create_timer(1.4).timeout
	check(not is_instance_valid(flying) and not is_instance_valid(flying_sparkles),"Sparkles should disappear together with their pickup")
	print("QUIBLETS_REWARD_SPARKLES_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
