extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	assert(game.save_access_blocked())
	game.roster.clear()
	for i in 17:game.roster.append(GameData.make_quiblet(0,10+i))
	game.team_indices.assign([0,1]);game.selected_roster=0
	for item in ["Attack Charm","Health Charm"]:
		game.special_items[item]=2;game.selected_resource_item=item;game.show_resources();await process_frame
		assert(game.content.find_child("UseSpecialItem",true,false)==null)
		game.begin_item_use(item);game.item_use.roster_index=0
		assert(game.item_use_problem()!="")
	for item in ["Memory Fruit","Move Crystal","Growth Fruit","Prodigy Fruit"]:
		game.special_items[item]=2;game.begin_item_use(item);game.show_item_use(item);await process_frame
		assert(game.content.find_child("QuibletGrid",true,false).get_child_count()==15)
		var card=game.content.find_child("QuibletCard16",true,false)
		assert(card!=null);card.chosen.emit(16);await process_frame
		assert(game.item_use.roster_index==16 and game.content.find_child("StoneEquipmentMenu",true,false)!=null)
		assert(game.content.find_child("UseItemButton",true,false)!=null)
		assert(game.content.find_child("AutoSetPowerStones",true,false)==null)
		if item=="Move Crystal":
			game.content.find_child("SlotChoice",true,false).pressed.emit();await process_frame
			var before:int=game.roster[16].moves[0].slots
			game.content.find_child("UseItemButton",true,false).pressed.emit();await process_frame
			assert(game.roster[16].moves[0].slots==before+1 and game.special_items[item]==1)
		game.show_item_quiblet_picker();await process_frame
		assert(game.item_use.roster_index==-1)
	game.special_items["Echo Crystal"]=1;game.move_stone_inventory["blast"]=1
	game.begin_item_use("Echo Crystal");game.show_item_use("Echo Crystal");await process_frame
	assert(game.content.find_child("ItemTargetList",true,false)!=null)
	print("ITEM_USE_NAVIGATION_OK")
	quit()
