extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	assert(game.save_access_blocked())
	game.power_stone_inventory.clear()
	for i in 36:game.power_stone_inventory.append(GameData.normalize_power_stone({"type":"Health","power":i+1,"tier":1,"bonuses":[]}))
	game.power_stone_inventory.append(GameData.normalize_power_stone({"type":"Attack","power":90,"tier":1,"bonuses":[]}))
	game.show_stone_workshop();await process_frame
	assert(game.content.find_child("WorkshopGrid",true,false).get_child_count()==30)
	assert(game.content.find_child("StoneWorkshop",true,false).find_children("*","ScrollContainer",true,false).is_empty())
	game.set_workshop_inventory_page(1);await process_frame
	assert(game.content.find_child("WorkshopGrid",true,false).get_child_count()==6)
	game.set_workshop_inventory_tab("Attack");await process_frame
	assert(game.workshop_inventory_page==0 and game.content.find_child("WorkshopGrid",true,false).get_child_count()==1)
	var q:=GameData.make_quiblet(7,50)
	q.moves=[{"name":"Flare","slots":4,"stones":[]},{"name":"Fireball","slots":2,"stones":[]}]
	game.roster=[q];game.selected_roster=0;game.MOVE_SLOTS.ensure(q)
	q.moves[0].slot_data[1].home_move_id=q.moves[1].move_id
	q.moves[0].slot_data[2].origin=game.MOVE_SLOTS.CRYSTAL
	q.moves[0].slot_data[3].origin=game.MOVE_SLOTS.CRYSTAL;q.moves[0].slot_data[3].home_move_id=q.moves[1].move_id
	game.show_move_slot_manager();await process_frame
	assert(game.content.find_child("ResultPortrait",true,false)!=null)
	assert(game.content.find_children("TransferSlotTo*","",true,false).is_empty())
	for i in 4:
		var slot=game.content.find_child("ResultStoneSlot0_%d"%i,true,false)
		assert(slot!=null and not slot.has_node("SlotOriginOutline"))
	game.content.find_child("ManageMoveSlot0_0",true,false).pressed.emit();await process_frame
	assert(game.move_slot_selection==[[0,0]])
	print("WORKSHOP_LAYOUT_OK")
	quit()
