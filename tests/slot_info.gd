extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func click(target:Control)->void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=target.size*.5;target._gui_input(event)

func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	# Fitted stones on the Quiblet info menu.
	var q:Dictionary=game.roster[0];q.level=100;game.ensure_quiblet_equipment(q)
	var fitted_stone:=GameData.make_power_stone("Health" if q.power_slot_types[0]!="Attack" else "Attack",2,["Movement Speed"]);q.power_slot_stones[0]=fitted_stone
	q.moves[0].slots=2;q.moves[0].stones=["echo"]
	game.selected_roster=0;game.show_quiblet_edit();await process_frame
	var power_slot:Control=game.content.find_child("PowerStoneSlot0",true,false);var move_slot:Control=game.content.find_child("MoveStoneSlot0_0",true,false);var empty_slot:Control=game.content.find_child("PowerStoneSlot3",true,false)
	check(power_slot!=null and move_slot!=null and empty_slot!=null,"Test needs the fitted and empty slots on screen")
	click(power_slot);await process_frame
	check(game.selected_inventory_item.get("kind","")=="power_stone" and int(game.selected_inventory_item.get("power",0))==int(fitted_stone.power) and game.content.find_child("StoneDetailTitle",true,false)!=null and game.content.find_child("PowerStoneBonusDescription",true,false).text.contains("Movement Speed: +10% movement speed"),"Clicking a fitted Power Stone opens its detail with exact bonus effects")
	check(game.roster[0].power_slot_stones[0].power==fitted_stone.power and game.power_stone_inventory.is_empty(),"Inspecting a fitted stone must not unequip it")
	move_slot=game.content.find_child("MoveStoneSlot0_0",true,false);click(move_slot);await process_frame
	check(game.selected_inventory_item.get("kind","")=="move_stone" and game.selected_inventory_item.get("effect","")=="echo" and game.content.find_child("StoneDetailDescription",true,false)!=null,"Clicking a fitted Move Stone opens its detail")
	check(game.roster[0].moves[0].stones==["echo"],"Inspecting a fitted Move Stone must not detach it")
	var selection_before:Dictionary=game.selected_inventory_item.duplicate(true)
	empty_slot=game.content.find_child("PowerStoneSlot3",true,false);click(empty_slot);await process_frame
	check(game.selected_inventory_item==selection_before,"Clicking an empty slot changes nothing")
	# A drag from a slot must not also count as a click.
	power_slot=game.content.find_child("PowerStoneSlot0",true,false);power_slot.suppress_next_release=true
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;power_slot._gui_input(release)
	check(not power_slot.suppress_next_release,"A release after a drag is swallowed once")
	# Empty Move Stone slots drag between moves; fitted ones do not, and eight is the cap.
	q.moves[0].slots=2;q.moves[0].stones=["echo"];q.moves[1].slots=1;q.moves[1].stones=[];game.show_quiblet_edit();await process_frame
	var empty_move_slot:Control=game.content.find_child("MoveStoneSlot0_1",true,false);var target_slot:Control=game.content.find_child("MoveStoneSlot1_0",true,false)
	var slot_drag=empty_move_slot._get_drag_data(Vector2.ZERO)
	check(slot_drag is Dictionary and slot_drag.get("kind","")=="move_slot" and int(slot_drag.move_index)==0 and game.roster[0].moves[0].slots==2 and game.roster[0].moves[0].stones==["echo"],"Dragging an empty Move Stone slot picks up the slot and changes nothing yet")
	check(target_slot._can_drop_data(Vector2.ZERO,slot_drag) and not empty_move_slot._can_drop_data(Vector2.ZERO,slot_drag) and game.content.find_child("EditableMoveIcon1",true,false)._can_drop_data(Vector2.ZERO,slot_drag),"An empty slot can land on another move's slots or icon, not on its own move")
	target_slot._drop_data(Vector2.ZERO,slot_drag);await process_frame
	check(game.roster[0].moves[0].slots==1 and game.roster[0].moves[0].stones==["echo"] and game.roster[0].moves[1].slots==2,"Dropping moves the slot across and keeps the fitted stone in place")
	game.roster[0].moves[1].slots=8;game.roster[0].moves[0].slots=2;game.show_quiblet_edit();await process_frame
	empty_move_slot=game.content.find_child("MoveStoneSlot0_1",true,false);slot_drag=empty_move_slot._get_drag_data(Vector2.ZERO)
	check(not game.content.find_child("MoveStoneSlot1_0",true,false)._can_drop_data(Vector2.ZERO,slot_drag),"A move with eight slots refuses another")
	game.transfer_move_slot(0,1);check(game.roster[0].moves[1].slots==8 and game.roster[0].moves[0].slots==2,"The cap holds on a direct transfer too")
	var fitted_move_slot:Control=game.content.find_child("MoveStoneSlot0_0",true,false)
	check(not game.move_slot_is_empty(0,0) and game.move_slot_is_empty(0,1),"Only a slot with nothing fitted counts as empty")
	game.transfer_move_slot(1,0);await process_frame
	check(game.roster[0].moves[1].slots==7 and game.roster[0].moves[0].slots==3,"Slots move back the other way")
	game.roster[0].moves[0].slots=1;game.roster[0].moves[0].stones=["echo"];game.transfer_move_slot(0,1)
	check(game.roster[0].moves[0].slots==1,"A move whose only slot is fitted has nothing to give")
	game.roster[0].moves[1].slots=1;game.roster[0].moves[1].stones=[];game.show_quiblet_edit();await process_frame
	# Placed cooking items.
	for ingredient_name in ["Bumbleberry","Emberpepper"]:
		game.ingredients[ingredient_name]=6
		if not game.unlocked_ingredients.has(ingredient_name):game.unlocked_ingredients.append(ingredient_name)
	game.spice_inventory["Hot Flakes"]["good"]=1;game.special_items["Bountiful Berry"]=1
	game.show_cooking();await process_frame
	game.assign_cooking_item("ingredient",0,{"kind":"ingredient","name":"Emberpepper"})
	game.assign_cooking_item("spice",0,{"kind":"spice","name":"Hot Flakes","quality":"good"})
	game.assign_cooking_item("special",0,{"kind":"special","id":"Bountiful Berry"});await process_frame
	var pot_slots:Array=game.content.find_children("*","PotDropSlot",true,false)
	var ingredient_slot:Control=pot_slots.filter(func(slot):return slot.slot_kind=="ingredient" and slot.slot_index==0)[0]
	var spice_slot:Control=pot_slots.filter(func(slot):return slot.slot_kind=="spice" and slot.slot_index==0)[0]
	var special_slot:Control=pot_slots.filter(func(slot):return slot.slot_kind=="special" and slot.slot_index==0)[0]
	click(ingredient_slot);await process_frame
	check(game.selected_cooking_ingredient=="Emberpepper" and game.content.find_child("SelectedIngredientIcon",true,false)!=null and game.pot_slots[0]=="Emberpepper","Clicking a pot ingredient shows its info without removing it")
	pot_slots=game.content.find_children("*","PotDropSlot",true,false);spice_slot=pot_slots.filter(func(slot):return slot.slot_kind=="spice" and slot.slot_index==0)[0]
	click(spice_slot);await process_frame
	var item_name:Label=game.content.find_child("SelectedItemName",true,false)
	check(game.selected_cooking_item.get("kind","")=="spice" and item_name!=null and item_name.text=="Hot Flakes (Good)" and game.content.find_child("SelectedIngredientIcon",true,false)==null and not game.spice_slots[0].is_empty(),"Clicking a placed spice shows its info in the panel")
	pot_slots=game.content.find_children("*","PotDropSlot",true,false);special_slot=pot_slots.filter(func(slot):return slot.slot_kind=="special" and slot.slot_index==0)[0]
	click(special_slot);await process_frame
	item_name=game.content.find_child("SelectedItemName",true,false)
	check(game.selected_cooking_item.get("kind","")=="special" and item_name!=null and item_name.text=="Bountiful Berry" and game.content.find_child("CookingItemInfo",true,false).find_children("*","Label",true,false).any(func(item):return item.text.contains("2–5")) and game.special_slots[0]=="Bountiful Berry","Clicking a placed special item shows its description")
	game.select_cooking_ingredient("Bumbleberry");await process_frame
	check(game.selected_cooking_item.is_empty() and game.selected_cooking_ingredient=="Bumbleberry","Selecting an ingredient card replaces the spice or special item info")
	var empty_pot:Control=game.content.find_children("*","PotDropSlot",true,false).filter(func(slot):return slot.slot_kind=="ingredient" and slot.slot_index==4)[0]
	click(empty_pot);await process_frame
	check(game.selected_cooking_ingredient=="Bumbleberry","Clicking an empty pot slot changes nothing")
	game.clear_all_cooking_slots(true)
	print("QUIBLETS_SLOT_INFO_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
