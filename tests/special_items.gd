extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func back_buttons_bottom_right(game)->bool:
	var buttons:Array=game.content.find_children("BackButton","",true,false)
	return buttons.size()==1 and buttons[0].position==game.BACK_BUTTON_POSITION

func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	for item in game.special_items:game.special_items[item]=3
	# Every special item is either usable from the USE screen or used in place.
	for item in game.special_items:check(game.item_use_screen_supported(item) or game.SPECIAL_ITEM_USAGE.has(item),"Special item has no way to be used: "+str(item))
	game.show_resources();await process_frame
	check(game.content.find_children("ResourceItemCard_*","",true,false).size()==game.special_items.size(),"Resources lists every special item as a compact card")
	# Selecting a screen-usable owned item shows an enabled USE button in the info panel.
	for item in game.QUIBLET_ITEMS:
		game.select_resource_item(item);await process_frame
		var use_button=game.content.find_child("UseSpecialItem",true,false)
		check(use_button!=null and not use_button.disabled,"Selecting owned %s offers an enabled USE button"%item)
	# Fixture Quiblet: three moves, one remembered move, a fitted stone.
	var q:Dictionary=game.roster[0];q.level=10;q.exp=0;q.prodigy=false;q.health_charms=0;q.attack_charms=0;q.flex_health=0;q.flex_attack=0
	q.moves=[{"name":"Water Jet","slots":2,"stones":["echo"]},{"name":"Water Shot","slots":1,"stones":[]},{"name":"Water Burst","slots":1,"stones":[]}];q.memory=["Water Jet","Water Shot","Water Burst","Whirlpool"]
	while game.roster.size()<3:game.roster.append(GameData.make_quiblet(game.roster.size(),5))
	game.team_indices.clear();for index in [0,1,2]:game.team_indices.append(index)
	game.roster[1].level=20;game.roster[2].level=30
	game.show_item_use("Memory Fruit");await process_frame
	check(game.screen=="item_use" and back_buttons_bottom_right(game) and game.content.find_child("UseItemButton",true,false).disabled,"The USE screen should open with the item unusable until a target is chosen")
	game.item_use.roster_index=0;game.item_use.memory_move="Whirlpool";game.show_item_use("Memory Fruit");await process_frame
	check(not game.content.find_child("UseItemButton",true,false).disabled and game.remembered_moves(q)==["Whirlpool"],"Memory Fruit should list only forgotten moves")
	game.apply_item_use();await process_frame
	check(q.moves.size()==4 and q.moves[-1].name=="Whirlpool" and game.special_items["Memory Fruit"]==2,"Memory Fruit should restore a forgotten move into a free slot")
	q.moves[-1].name="Water Burst";q.moves[2].name="Splash Dash";q.moves[2].stones=["heavy"];game.move_stone_inventory["heavy"]=0
	game.begin_item_use("Memory Fruit");game.item_use.roster_index=0;game.item_use.memory_move="Whirlpool";game.item_use.move_index=2;game.apply_item_use();await process_frame
	check(q.moves[2].name=="Whirlpool" and q.moves[2].stones.is_empty() and int(game.move_stone_inventory.get("heavy",0))==1,"Memory Fruit on a full moveset should replace the chosen slot and refund its stones")
	game.begin_item_use("Move Crystal");game.item_use.roster_index=0;game.item_use.move_index=1;game.apply_item_use();await process_frame
	check(int(q.moves[1].slots)==2 and game.special_items["Move Crystal"]==2,"Move Crystal should add one Move Stone slot")
	q.moves[1].slots=8;game.begin_item_use("Move Crystal");game.item_use.roster_index=0;game.item_use.move_index=1
	check(game.item_use_problem()!="","Move Crystal must refuse a move that already has eight slots")
	var echo_before:int=int(game.move_stone_inventory.get("echo",0))
	game.begin_item_use("Echo Crystal");game.item_use.roster_index=0;game.item_use.stone_value="echo";game.item_use.move_index=0;game.apply_item_use();await process_frame
	check(int(game.move_stone_inventory.get("echo",0))==echo_before+1 and q.moves[0].stones.has("echo"),"Echo Crystal should copy a fitted stone and leave the original fitted")
	game.begin_item_use("Growth Fruit");game.item_use.roster_index=0;game.apply_item_use();await process_frame
	check(int(q.level)==25 and int(q.level)==game.growth_target_level(q) and int(q.exp)==0,"Growth Fruit should raise the Quiblet to its teammates' average level")
	check(game.item_use_problem()!="","Growth Fruit must refuse a Quiblet already at its teammates' average")
	game.begin_item_use("Prodigy Fruit");game.item_use.roster_index=0;game.apply_item_use();await process_frame
	check(q.prodigy==true and game.item_use_problem()!="","Prodigy Fruit should flag the next milestone and refuse a second blessing")
	game.begin_item_use("Health Charm");game.item_use.roster_index=0;game.apply_item_use();await process_frame
	game.begin_item_use("Attack Charm");game.item_use.roster_index=0;game.apply_item_use();await process_frame
	check(int(q.health_charms)==1 and int(q.attack_charms)==1 and game.special_items["Health Charm"]==2,"Charms should add growth through the USE screen")
	# Power Stone work (combine, revitalize, convert, reforge) lives in the Stone Workshop: res://tests/stone_workshop.gd.
	check(not game.special_items.has("Revitalizer Charm") and not game.special_items.has("Conversion Charm") and not game.special_items.has("Reforger Charm"),"The stone charms are no longer items")
	# Using the last copy of an item returns to Resources.
	game.special_items["Prodigy Fruit"]=1;game.roster[1].prodigy=false;game.begin_item_use("Prodigy Fruit");game.item_use.roster_index=1;game.apply_item_use();await process_frame
	check(game.screen=="inventory" and game.special_items["Prodigy Fruit"]==0,"Spending the last copy should return to Resources")
	# Treasure caches: placed in levels, opened only with a key, rewarding stone, ingredients, and maybe a special.
	# Boss levels always hide a cache, groves never, and only some regular levels do (fixed per node).
	var cached_levels:int=0;var regular_levels:int=0;var cache_area:=-1;var cache_node_index:=-1;var bare_area:=-1;var bare_node_index:=-1
	for area_index in GameData.EXPEDITION_AREAS.size():
		for kind in [["level",0],["level",1],["level",2],["level",4],["level",5],["boss",6],["berry_grove",3]]:
			var e:=Expedition3D.new();e.stage_area_index=area_index;e.stage_node_index=kind[1];e.stage_kind=kind[0];e.stage_level=5;root.add_child(e);e.set_process(false);e.build_level()
			if kind[0]=="berry_grove":check(e.cache_node==null,"Groves should not hold treasure caches")
			elif kind[0]=="boss":check(is_instance_valid(e.cache_node),"Boss levels should always hold a cache")
			else:
				regular_levels+=1
				if is_instance_valid(e.cache_node):
					cached_levels+=1
					check(e.walkable.has(e.cell_of(Vector2(e.cache_node.position.x,e.cache_node.position.z))) and e.cell_exposed(e.cell_of(Vector2(e.cache_node.position.x,e.cache_node.position.z))),"Caches sit on exposed walkable ground")
					if cache_area<0 and area_index==0:cache_area=area_index;cache_node_index=kind[1]
				elif bare_area<0 and area_index==0:bare_area=area_index;bare_node_index=kind[1]
			e.free()
	check(cached_levels>regular_levels*.3 and cached_levels<regular_levels*.6,"Only some regular levels should hide a cache (got %d of %d)"%[cached_levels,regular_levels])
	check(cache_area>=0 and bare_area>=0,"The first island needs both a cached and a bare regular level for the live checks")
	game.special_items["Treasure Key"]=1;game.area_progress[0]=8;game.start_area_level(cache_area,cache_node_index);await process_frame
	var expedition:Expedition3D=game.expedition;expedition.set_process(false)
	for actor in expedition.team+expedition.enemies:actor.set_physics_process(false)
	var rewards:Array=[];expedition.reward_acquired.connect(func(reward,_position):rewards.append(reward))
	check(expedition.treasure_keys==1 and is_instance_valid(expedition.cache_node),"The expedition should know the player's Treasure Keys and hold a cache")
	var stones_before:int=expedition.power_stones.size();var messages:Array=[];expedition.event_message.connect(func(message):messages.append(message))
	expedition.team[0].position=expedition.cache_node.position;expedition._process(.02)
	check(expedition.cache_node==null and expedition.treasure_keys==0 and game.special_items["Treasure Key"]==0,"Walking onto the cache with a key should open it and spend the key")
	check(expedition.power_stones.size()==stones_before+1 and rewards.filter(func(reward):return reward.kind=="power_stone").size()==1 and rewards.filter(func(reward):return reward.kind=="ingredient").size()==2,"An opened cache should give a Power Stone and two ingredient bundles")
	check(rewards.filter(func(reward):return reward.kind=="special").size()==expedition.extra_specials.size(),"Any special item from a cache is announced as a reward")
	expedition.finish(false);await process_frame
	game.show_area_levels(0);game.special_items["Treasure Key"]=0;game.start_area_level(cache_area,cache_node_index);await process_frame
	expedition=game.expedition;expedition.set_process(false)
	for actor in expedition.team+expedition.enemies:actor.set_physics_process(false)
	messages.clear();expedition.event_message.connect(func(message):messages.append(message))
	expedition.team[0].position=expedition.cache_node.position;expedition._process(.02);expedition._process(.02)
	check(is_instance_valid(expedition.cache_node) and messages.filter(func(message):return message.contains("Treasure Key")).size()==1,"Without a key the cache stays locked and warns exactly once")
	expedition.finish(false);await process_frame;game.show_area_levels(0);game.start_area_level(bare_area,bare_node_index);await process_frame
	expedition=game.expedition;check(expedition.cache_node==null,"A bare level should start without a cache")
	# Extra specials from caches are banked and shown with the haul.
	var finished:Dictionary={"victory":true,"exp":10,"loot":expedition.loot.duplicate(),"move_stones":{},"power_stones":[],"special":"","extra_specials":["Treasure Key","Bountiful Berry"],"berries":0,"elapsed":3.0,"area_index":0,"node_index":1,"stage_kind":"level"}
	var berries_before:int=game.special_items["Bountiful Berry"]
	game._on_expedition_finished(finished);await process_frame
	check(game.special_items["Treasure Key"]==1 and game.special_items["Bountiful Berry"]==berries_before+1 and game.expedition_haul_entries().filter(func(entry):return entry.kind=="special").size()==2,"Cache specials should be banked and listed in the haul")
	# Unfitted Power Stones recycle into ingredients from the stone detail panel; fitted ones cannot.
	game.show_camp();await process_frame
	game.power_stone_inventory.clear();game.power_stone_inventory.append(GameData.make_power_stone("Health",2,["Movement Speed"]))
	game.selected_roster=0;game.select_inventory_stone(game.power_stone_inventory_data(game.power_stone_inventory[0],0));await process_frame
	var recycle_button:Button=game.content.find_child("RecyclePowerStone",true,false)
	check(game.screen=="edit_quiblet" and recycle_button!=null and recycle_button.text.contains("4 INGREDIENTS"),"An inventory stone should offer recycling worth tier + bonuses + 1 ingredients")
	var totals_before:int=0
	for name in game.ingredients:totals_before+=int(game.ingredients[name])
	recycle_button.pressed.emit();await process_frame
	var confirmation=game.content.find_child("RecycleStoneConfirmation",true,false)
	check(confirmation!=null and game.power_stone_inventory.size()==1 and confirmation.find_child("ConfirmRecycleStone",true,false)!=null,"Recycling should ask for confirmation before destroying the stone")
	confirmation.find_child("CancelRecycleStone",true,false).pressed.emit();await process_frame
	check(game.content.find_child("RecycleStoneConfirmation",true,false)==null and game.power_stone_inventory.size()==1,"Cancelling keeps the stone")
	recycle_button.pressed.emit();await process_frame
	game.content.find_child("ConfirmRecycleStone",true,false).pressed.emit();await process_frame
	var totals_after:int=0
	for name in game.ingredients:totals_after+=int(game.ingredients[name])
	check(game.power_stone_inventory.is_empty() and totals_after-totals_before==4 and game.selected_inventory_item.is_empty() and game.screen=="edit_quiblet","Recycling should remove the stone and grant its ingredients")
	var fitted:Dictionary=GameData.normalize_power_stone(GameData.make_power_stone("Attack",1,[]));fitted.kind="power_stone";fitted.display_name="Fitted stone"
	game.select_inventory_stone(fitted);await process_frame
	check(game.content.find_child("RecyclePowerStone",true,false)==null,"A fitted stone must not offer recycling")
	print("QUIBLETS_SPECIAL_ITEMS_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
