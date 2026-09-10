extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func slot_art_path(texture:Texture2D)->String:
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path

func _initialize()->void:call_deferred("run")

func band_counts(unlocks:Array)->Array:
	var counts:=[]
	for band in GameData.POWER_BOARD_UNLOCK_BANDS:counts.append(unlocks.filter(func(level):return int(level)>=int(band[0]) and int(level)<=int(band[1])).size())
	return counts

func run()->void:
	# Board generation: types, guarantees, unique unlock levels per band, and shuffling.
	var type_totals:={"Attack":0,"Health":0,"Flex":0};var order_matches:=0;var boards:={}
	for i in 400:
		var board:=GameData.generate_power_board("seed-%d"%i)
		var types:Array=board.types;var unlocks:Array=board.unlocks
		check(types.size()==16 and unlocks.size()==16,"A board has sixteen positions")
		check(types.all(func(value):return value in ["Attack","Health","Flex"]) and types.has("Attack") and types.has("Health"),"Every board has valid types with at least one Attack and one Health")
		var unique:={}
		for level in unlocks:unique[int(level)]=true
		check(unique.size()==16 and unlocks.count(1)==1 and band_counts(unlocks)==[1,2,3,3,3,2,1,1],"Unlock levels are unique and follow the bands 1, 2–10 ×2, 11–25 ×3, 26–45 ×3, 46–65 ×3, 66–82 ×2, 83–94, 95–100")
		for value in types:type_totals[value]+=1
		var sorted:Array=unlocks.duplicate();sorted.sort()
		if sorted==unlocks:order_matches+=1
		boards[str(types)+str(unlocks)]=true
	check(absf(float(type_totals.Attack)/6400-.45)<.03 and absf(float(type_totals.Health)/6400-.45)<.03 and absf(float(type_totals.Flex)/6400-.10)<.02,"Types roll at about 45% Attack, 45% Health, 10% Flex")
	check(order_matches<3 and boards.size()==400,"Unlock levels are shuffled across positions and boards differ per Quiblet")
	var same:=GameData.generate_power_board("fixed");var again:=GameData.generate_power_board("fixed")
	check(same.types==again.types and same.unlocks==again.unlocks,"A Quiblet's board is fixed by its identity")
	# Unlock rules on a Quiblet.
	var q:=GameData.make_quiblet(0,1)
	check(q.has("power_slot_unlocks") and q.power_slot_unlocks.size()==16,"New Quiblets carry their board")
	var unlocked_at_one:=range(16).filter(func(index):return GameData.power_slot_unlocked(q,index))
	check(unlocked_at_one.size()==1 and GameData.power_slot_unlock_level(q,unlocked_at_one[0])==1,"Exactly one slot is unlocked at level 1")
	var next:=GameData.next_power_unlock(q)
	var sorted_levels:Array=q.power_slot_unlocks.duplicate();sorted_levels.sort()
	check(int(next.level)==int(sorted_levels[1]) and int(next.previous)==1 and is_equal_approx(float(next.progress),0.0),"The next slot is the lowest unlock above the current level with zero progress at the previous unlock")
	q.level=int(sorted_levels[1])-1
	var expected:=float(q.level-1)/float(int(sorted_levels[1])-1)
	check(is_equal_approx(float(GameData.next_power_unlock(q).progress),expected),"Ring progress is (level - previous unlock) / (next unlock - previous unlock)")
	q.level=int(sorted_levels[1])
	next=GameData.next_power_unlock(q)
	check(range(16).filter(func(index):return GameData.power_slot_unlocked(q,index)).size()==2 and int(next.level)==int(sorted_levels[2]) and int(next.previous)==int(sorted_levels[1]) and is_equal_approx(float(next.progress),0.0),"Reaching the unlock level opens that slot and moves the ring to the following one")
	q.level=100
	check(range(16).all(func(index):return GameData.power_slot_unlocked(q,index)) and int(GameData.next_power_unlock(q).index)==-1 and is_equal_approx(float(GameData.next_power_unlock(q).progress),1.0),"At level 100 every slot is unlocked and nothing is pending")
	q.level=int(sorted_levels[3])+2
	for index in 16:
		var slot_type:String=q.power_slot_types[index];var unlocked:=GameData.power_slot_unlocked(q,index)
		check(GameData.power_slot_accepts(q,index,"Health")==(unlocked and slot_type in ["Health","Flex"]) and GameData.power_slot_accepts(q,index,"Attack")==(unlocked and slot_type in ["Attack","Flex"]),"Slots accept only their type (Flex takes both) and only once unlocked")
	# The edit screen shows locks, unlock levels, and one progress ring.
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	var starter:Dictionary=game.roster[0];starter.level=1
	game.selected_roster=0;game.show_quiblet_edit();await process_frame
	var rings:Array=game.content.find_children("UnlockProgressRing","",true,false);var level_tags:Array=game.content.find_children("PowerSlotUnlockLevel","",true,false)
	var pending:=GameData.next_power_unlock(starter)
	check(rings.size()==1 and rings[0].get_parent().find_child("PowerStoneSlot%d"%int(pending.index),true,false)!=null and level_tags.is_empty() and game.content.find_children("LockedSlotRect","",true,false).size()==15,"A level-1 Quiblet shows fifteen locked slots with no level tags and one progress outline on the next unlock")
	var locked_slots:Array=game.content.find_children("PowerStoneSlot*","",true,false).filter(func(slot):return slot.locked)
	check(locked_slots.size()==15 and locked_slots.all(func(slot):return slot.tooltip_text.is_empty() and slot.find_children("*","",true,false).all(func(child):return child.tooltip_text.is_empty())),"Locked slots show no tooltip")
	var locked_slot:Control=game.content.find_child("PowerStoneSlot%d"%int(pending.index),true,false)
	check(locked_slot.modulate==Color.WHITE and game.content.find_children("PowerStoneSlot*","",true,false).all(func(slot):return slot.modulate==Color.WHITE),"Locked slots rely on the Locked art rather than dimming")
	var locked_typed:Array=range(16).filter(func(index):return not GameData.power_slot_unlocked(starter,index))
	check(locked_typed.all(func(index):return slot_art_path(game.content.find_child("PowerStoneSlot%d"%index,true,false).get_node("PowerSlotTypeIcon").texture)=="res://textures/UI/%sSlotLocked.png"%starter.power_slot_types[index]),"Locked Health, Attack, and Flex slots use the Locked textures")
	check(game.content.find_children("PowerSlotTypeIcon","TextureRect",true,false).size()==16 and game.content.find_children("PowerStoneSlot*","",true,false).all(func(slot):return slot.get_parent().find_children("*","Label",true,false).is_empty()),"Every slot, Flex included, shows a type icon and no question mark")
	var locked_rect:Control=locked_slot.get_parent();var locked_cell:Control=locked_rect.get_parent()
	check(locked_rect.name=="LockedSlotRect" and locked_rect.size==Vector2(27,27) and locked_rect.position==Vector2(13.5,13.5) and locked_cell.size==Vector2(54,54) and locked_slot.size==Vector2(27,27),"A locked slot's icon frame is half size, centred in its grid cell")
	check(not (locked_rect is Panel) and locked_cell.get_theme_stylebox("panel") is StyleBoxEmpty,"A locked slot draws no rectangle behind its icon")
	check(UnlockProgressRing.TRACK==Color("#4b4b4b"),"The unfilled progress track uses the slot background colour")
	check(locked_slot.get_node("PowerSlotTypeIcon").size==Vector2(13.75,12.5),"A locked slot's icon is half size")
	var unlocked_slot:Control=game.content.find_child("PowerStoneSlot%d"%range(16).filter(func(index):return GameData.power_slot_unlocked(starter,index))[0],true,false)
	check(unlocked_slot.size==Vector2(54,54) and unlocked_slot.get_parent().size==Vector2(54,54) and (unlocked_slot.get_node_or_null("PowerSlotTypeIcon")==null or unlocked_slot.get_node("PowerSlotTypeIcon").size==Vector2(27.5,25)),"Unlocked slots keep their full size")
	var ring:Control=rings[0]
	check(ring.shape=="square" and ring.get_parent()==locked_cell and ring.size==Vector2(33,33) and ring.position==locked_rect.position-Vector2(3,3) and ring.square_path(1.0).size()==6 and ring.square_path(.5).size()==4,"The unlock progress is a square traced around the small locked rectangle")
	check(locked_slot.locked and not locked_slot._can_drop_data(Vector2.ZERO,{"kind":"power_stone","stone_type":str(starter.power_slot_types[int(pending.index)])}),"Locked slots refuse drops")
	var open_index:int=range(16).filter(func(index):return GameData.power_slot_unlocked(starter,index))[0]
	var open_slot:Control=game.content.find_child("PowerStoneSlot%d"%open_index,true,false);var open_type:String=starter.power_slot_types[open_index]
	check(not open_slot.locked and open_slot._can_drop_data(Vector2.ZERO,{"kind":"power_stone","stone_type":"Health" if open_type!="Attack" else "Attack"}),"The unlocked slot accepts a matching stone")
	var stone:=GameData.make_power_stone("Health" if open_type!="Attack" else "Attack",1);game.power_stone_inventory.append(stone)
	game.equip_stone_from_inventory("power",int(pending.index),-1,game.power_stone_inventory_data(stone,game.power_stone_inventory.size()-1));await process_frame
	check(starter.power_slot_stones[int(pending.index)].is_empty(),"Equipping into a locked slot is refused")
	game.equip_stone_from_inventory("power",open_index,-1,game.power_stone_inventory_data(stone,game.power_stone_inventory.size()-1));await process_frame
	check(starter.power_slot_stones[open_index].power==stone.power and starter.power_slot_types[open_index]==open_type,"Equipping into the unlocked slot works and never changes the slot's type")
	game.remove_equipped_stone("power",open_index,-1);await process_frame
	check(starter.power_slot_stones[open_index].is_empty() and starter.power_slot_types[open_index]==open_type,"Removing a stone keeps the slot's fixed type")
	# Levelling to the next unlock opens it and the ring moves on.
	starter.level=int(pending.level);game.show_quiblet_edit();await process_frame
	rings=game.content.find_children("UnlockProgressRing","",true,false)
	var following:=GameData.next_power_unlock(starter)
	check(game.content.find_children("LockedSlotRect","",true,false).size()==14 and rings.size()==1 and int(following.index)!=int(pending.index) and rings[0].get_parent().find_child("PowerStoneSlot%d"%int(following.index),true,false)!=null,"Reaching an unlock level opens the slot and moves the ring to the following slot")
	# Legacy saves: undecided slots become a fixed board and misplaced stones return to inventory.
	var legacy:=GameData.make_quiblet(1,3);legacy.erase("power_slot_unlocks");legacy.power_slot_types=["Health","Health","Attack","Attack","Health","Attack","Health","Attack","","","","","","","",""]
	legacy.power_slot_stones[15]=GameData.make_power_stone("Health",1)
	var inventory_before:int=game.power_stone_inventory.size()
	game.ensure_quiblet_equipment(legacy)
	check(legacy.power_slot_unlocks.size()==16 and legacy.power_slot_types.all(func(value):return value in ["Attack","Health","Flex"]),"Legacy Quiblets roll a fixed board")
	check(legacy.power_slot_stones.all(func(entry):return entry.is_empty()) and game.power_stone_inventory.size()==inventory_before+1,"Stones in locked or mismatched slots return to inventory on migration")
	# Save round trip keeps the board.
	var encoded:=JSON.stringify(game.save_data());var decoded=JSON.parse_string(encoded)
	var restored=load("res://main.tscn").instantiate();root.add_child(restored);await process_frame
	restored.apply_save_data(decoded)
	check(restored.roster[0].power_slot_unlocks==starter.power_slot_unlocks and restored.roster[0].power_slot_types==starter.power_slot_types,"Boards survive saving and loading")
	print("QUIBLETS_POWER_BOARD_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
