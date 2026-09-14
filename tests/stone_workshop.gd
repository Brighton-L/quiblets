extends SceneTree

# Stone Workshop: Combiner, Revitalizer, Converter, and Reforger on inventory
# Power Stones, plus the stacked-bonus and Obsidian material rules behind them.
var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func stone(type:String,power:int,bonuses:Array)->Dictionary:
	return GameData.normalize_power_stone({"type":type,"power":power,"bonuses":bonuses})

func run()->void:
	# Materials follow distinct bonus stats; Obsidian is the fifth material and has art.
	check(GameData.POWER_STONE_QUALITIES==["Regular","Bronze","Silver","Gold","Diamond","Obsidian"],"Obsidian must be the material above Diamond")
	check(ResourceLoader.exists("res://textures/PowerStones/ObsidianStoneBase.png"),"Obsidian stones need their base texture")
	for count in 7:
		var bonuses:Array=GameData.POWER_STONE_BONUSES.keys().slice(0,count)
		check(GameData.power_stone_material(bonuses)==GameData.POWER_STONE_QUALITIES[mini(count,5)],"%d distinct stats should be %s"%[count,GameData.POWER_STONE_QUALITIES[mini(count,5)]])
	# Stacked bonuses: merged lines multiply the fixed effect and read as one stat.
	var merged:Array=GameData.merge_power_stone_bonuses([["Critical Hit Rate","Movement Speed"],["Critical Hit Rate"],[{"name":"Critical Hit Rate","stacks":2}]])
	check(merged.size()==2 and merged[0] is Dictionary and int(merged[0].stacks)==GameData.MAX_BONUS_STACKS and merged[1]=="Movement Speed","Matching bonuses should merge into one stacked line in first-seen order, capped at three rolls")
	check(GameData.bonus_description(merged[0])=="Critical Hit Rate: +24% chance for a critical hit (1.5× damage)","A stacked bonus must state only its added-together percentage")
	check(GameData.bonus_description("Movement Speed")=="Movement Speed: +10% movement speed","Single bonuses keep their exact text")
	var totals:=GameData.stone_bonus_totals([stone("Attack",100,merged)])
	check(is_equal_approx(float(totals.get("crit",0.0)),.24) and is_equal_approx(float(totals.get("speed",0.0)),.10),"Stacked bonuses apply their multiplied effect")
	var stacked:=stone("Health",50,["Health","Health","Evasion"])
	check(stacked.bonuses.size()==2 and stacked.quality=="Silver" and int(stacked.bonus_count)==2,"Normalizing merges duplicate stats and rates the material on distinct stats")
	# Combiner rules.
	var a:=stone("Attack",410,["Critical Hit Rate","Movement Speed","Health"]);var b:=stone("Attack",392,["Critical Hit Rate","Attack","Evasion","Move Cooldown"]);var c:=stone("Attack",365,["Healing Received"]);var d:=stone("Attack",118,["Damage Resistance"])
	check(GameData.combine_problem([a])!="","One stone cannot be combined")
	check(GameData.combine_problem([a,b,c,d,a])!="","Five stones cannot be combined")
	check(GameData.combine_problem([a,stone("Health",300,["Health"])])!="","Mixed stat types cannot be combined")
	check(GameData.combine_problem([a,stone("Attack",300,[])])!="","A stone without a bonus cannot be combined")
	var combined:=GameData.combine_power_stones([a,b,c,d])
	check(int(combined.power)==118 and combined.type=="Attack" and int(combined.tier)==int(d.tier),"The combined stone keeps the lowest input power")
	check(combined.bonuses.size()==8 and combined.quality=="Obsidian","Eight distinct stats from four inputs make an Obsidian stone")
	check(GameData.bonus_stacks(combined.bonuses[0])==2 and GameData.bonus_name(combined.bonuses[0])=="Critical Hit Rate","Overlapping stats add together on the combined stone")
	var two:=GameData.combine_power_stones([a,b])
	check(two.bonuses.size()==6 and two.quality=="Obsidian" and int(two.power)==392,"A 3-bonus and a 4-bonus stone with one overlap give six stats and Obsidian")
	check(GameData.combine_power_stones([c,d]).quality=="Silver" and GameData.combine_power_stones([a,c]).quality=="Diamond","Two and four distinct stats give Silver and Diamond")
	check(GameData.combine_power_stones([c,stone("Attack",200,["Healing Received"])]).quality=="Bronze","Two copies of one stat stay Bronze with a stacked line")
	check(GameData.combine_problem([combined,two])!="" and GameData.combine_problem([combined,c])=="","Only one Obsidian stone may enter a combination")
	var rebuilt:=GameData.combine_power_stones([combined,c])
	check(rebuilt.quality=="Obsidian" and int(rebuilt.power)==118 and GameData.bonus_stacks(rebuilt.bonuses[6])==2,"An Obsidian stone can be combined again under the same rules")
	# Stack and total caps: a stat keeps at most three rolls per stone, lost rolls are counted, and equipped totals are capped.
	var heavy_crit:=stone("Attack",200,[{"name":"Critical Hit Rate","stacks":3},"Evasion"]);var more_crit:=stone("Attack",180,[{"name":"Critical Hit Rate","stacks":2},"Movement Speed"])
	var capped:=GameData.combine_power_stones([heavy_crit,more_crit])
	check(GameData.bonus_stacks(capped.bonuses[0])==GameData.MAX_BONUS_STACKS and capped.bonuses.size()==3 and capped.quality=="Gold","Combining past the stack cap keeps three rolls of the stat")
	var counts:Dictionary=GameData.bonus_roll_counts([heavy_crit.bonuses,more_crit.bonuses])
	check(int(counts.raw)==7 and int(counts.kept)==5 and int(counts.lost)==2,"Lost rolls are counted for the preview")
	var overstacked:=GameData.normalize_power_stone({"type":"Health","power":248,"bonuses":[{"name":"Movement Speed","stacks":16},{"name":"Critical Hit Rate","stacks":17}]})
	check(overstacked.bonuses.all(func(bonus):return GameData.bonus_stacks(bonus)<=GameData.MAX_BONUS_STACKS),"An over-stacked stone is clamped when loaded")
	var many:Array=[]
	for i in 8:many.append(stone("Health",100,[{"name":"Critical Hit Rate","stacks":3},{"name":"Evasion","stacks":3},{"name":"Damage Resistance","stacks":3}]))
	var capped_totals:=GameData.stone_bonus_totals(many)
	check(is_equal_approx(float(capped_totals.crit),.5) and is_equal_approx(float(capped_totals.evasion),.3) and is_equal_approx(float(capped_totals.resist),.4),"Equipped totals stop at each stat's cap")
	# Revitalizer formula: max(current, round(drop average × 0.9)).
	check(GameData.power_stone_drop_average(5)==590 and GameData.revitalized_power(stone("Health",100,[]),5)==531 and GameData.revitalized_power(stone("Health",600,[]),5)==600,"Revitalized power is the larger of the current power and 90% of the drop average")
	var revived:=GameData.revitalize_power_stone(stone("Health",100,["Health"]),3)
	check(int(revived.power)>=248 and int(revived.power)<=253 and int(revived.tier)==3 and revived.bonuses==["Health"] and revived.type=="Health","Revitalizing keeps the stone and lifts its power and tier")
	# Converter keeps everything but the type.
	var converted:=GameData.convert_power_stone(a)
	check(converted.type=="Health" and int(converted.power)==410 and converted.bonuses==a.bonuses and converted.quality==a.quality,"Converting swaps the stat type only")
	# Reforger replaces the chosen line with a stat the stone lacks.
	check(GameData.reforge_problem({},{},0)!="" and GameData.reforge_problem(a,{},-1)!="" and GameData.reforge_problem(a,stone("Attack",1,[]),0)!="" and GameData.reforge_problem(a,d,0)=="","Reforging needs a target, a chosen bonus, and a consumed stone with a bonus")
	var full:=stone("Attack",10,GameData.POWER_STONE_BONUSES.keys())
	check(GameData.reforge_problem(full,d,0)!="","A stone with every stat cannot be reforged")
	var rng:=RandomNumberGenerator.new();rng.seed=7
	for trial in 20:
		var reforged:=GameData.reforge_power_stone(a,1,rng)
		check(reforged.bonuses.size()==3 and reforged.bonuses[0]=="Critical Hit Rate" and reforged.bonuses[2]=="Health" and not reforged.bonuses[1] in ["Critical Hit Rate","Movement Speed","Health"] and reforged.quality=="Gold","Reforging rerolls only the chosen line to a new stat")
	# The workshop screen.
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.show_resources();await process_frame
	var open_button=game.content.find_child("OpenStoneWorkshop",true,false)
	check(open_button!=null,"Resources should open the Stone Workshop")
	game.power_stone_inventory.clear()
	for value in [a,b,c,d,stone("Health",300,["Health"]),stone("Health",90,[])]:game.power_stone_inventory.append(value)
	game.begin_stone_workshop("combine");game.show_stone_workshop();await process_frame
	check(game.screen=="stone_workshop" and game.content.find_children("WorkshopStone?","",true,false).size()==6 and game.content.find_child("WorkshopApply",true,false).disabled,"The workshop lists every inventory stone and starts with nothing to apply")
	for key in game.STONE_WORKSHOP_MODES:check(game.content.find_child("WorkshopMode_%s"%key,true,false)!=null,"Missing workshop tab "+str(key))
	game.workshop_pick_stone(0);game.workshop_pick_stone(1);game.workshop_pick_stone(4);await process_frame
	check(game.workshop_problem()!="" and game.content.find_child("WorkshopApply",true,false).disabled,"Mixed types must leave the Combiner disabled")
	game.workshop_pick_stone(4);game.workshop_pick_stone(2);game.workshop_pick_stone(3);await process_frame
	check(game.workshop_problem()!="" and game.content.find_child("WorkshopApply",true,false).disabled,"Valid inputs still require an inserted charm")
	game.special_items["Combiner Charm"]=2;game.show_stone_workshop();await process_frame
	game.content.find_child("CombinerCharmSlot",true,false).pressed.emit();await process_frame
	check(game.special_items["Combiner Charm"]==2,"Inserting reserves the charm without spending it")
	check(game.workshop_problem()=="" and not game.content.find_child("WorkshopApply",true,false).disabled and game.content.find_child("WorkshopResult",true,false)!=null,"Four valid inputs enable the Combiner and preview the result")
	game.workshop_pick_stone(5)
	check(game.stone_workshop.selected.size()==4,"A fifth input is refused")
	game.apply_stone_workshop();await process_frame
	check(game.special_items["Combiner Charm"]==1 and not game.stone_workshop.charm_inserted,"A combination consumes exactly one charm and empties its slot")
	check(game.power_stone_inventory.size()==3 and game.power_stone_inventory[2].quality=="Obsidian" and int(game.power_stone_inventory[2].power)==118 and game.stone_workshop.selected.is_empty(),"Combining consumes the inputs and adds the Obsidian result")
	# Revitalizer uses the highest reached node's loot tier.
	game.area_progress.fill(0);game.area_progress[0]=7
	var reached:int=game.highest_reached_stage_level()
	check(reached==maxi(int(game.area_level_data(0,6).level),int(game.area_level_data(1,0).level)),"Clearing an island's boss reaches its whole route and the next island's first level")
	game.area_progress[0]=3;var reachable:int=0
	for level_index in 4:reachable=maxi(reachable,int(game.area_level_data(0,level_index).level))
	check(game.highest_reached_stage_level()==reachable and reachable<int(game.area_level_data(0,6).level),"Only reached nodes count toward the loot tier")
	game.area_progress[0]=0;check(game.highest_reached_stage_level()==int(game.area_level_data(0,0).level),"A fresh game has reached only the first level");game.area_progress[0]=7
	game.set_stone_workshop_mode("revitalize");game.workshop_pick_stone(1);await process_frame
	var expected:int=maxi(90,roundi(GameData.power_stone_drop_average(game.workshop_loot_tier())*.9))
	check(game.workshop_problem()=="" if expected>90 else game.workshop_problem()!="","Revitalizer availability follows the formula")
	if expected>90:
		game.apply_stone_workshop();await process_frame
		check(int(game.power_stone_inventory[1].power)>=expected and int(game.power_stone_inventory[1].power)<=expected+5 and game.power_stone_inventory[1].bonuses.is_empty() and game.stone_workshop.selected.is_empty(),"Revitalizing sets the formula power")
		game.workshop_pick_stone(1);check(game.workshop_problem()!="","A revitalized stone cannot be revitalized again at the same tier")
	# Converter.
	game.set_stone_workshop_mode("convert");game.workshop_pick_stone(0);await process_frame
	check(game.content.find_child("WorkshopResult",true,false)!=null,"The Converter previews its result")
	game.apply_stone_workshop();await process_frame
	check(game.power_stone_inventory[0].type=="Attack" and int(game.power_stone_inventory[0].power)==300 and game.power_stone_inventory[0].bonuses==["Health"],"Converting flips the type in place")
	# Reforger: target, bonus, then the consumed stone.
	game.set_stone_workshop_mode("reforge");game.workshop_pick_stone(2);await process_frame
	check(game.content.find_children("ReforgeBonusChoice*","",true,false).size()==8 and game.workshop_problem()!="","The Reforger lists the target's bonuses and waits for a choice")
	game.stone_workshop.bonus_index=7;game.workshop_pick_stone(0);await process_frame
	check(game.workshop_problem()=="" and game.content.find_child("WorkshopSacrifice",true,false)!=null,"A chosen bonus and a bonus-bearing sacrifice enable the Reforger")
	var before:Array=game.power_stone_inventory[2].bonuses.duplicate(true)
	game.apply_stone_workshop();await process_frame
	var after:Array=game.power_stone_inventory[1].bonuses
	check(game.power_stone_inventory.size()==2 and after.size()==8 and after[7]=="Knockback Resistance" and after.slice(0,7)==before.slice(0,7) and game.power_stone_inventory[1].quality=="Obsidian","Reforging replaces only the chosen bonus and consumes the sacrifice")
	# Fitted stones appear in every list, marked with their owner, and cannot be picked, dragged, or recycled.
	var owner_q:Dictionary=game.roster[0];game.ensure_quiblet_equipment(owner_q);var owner_slot:int=GameData.first_power_slot_accepting(owner_q,"Attack")
	owner_q.power_slot_stones[owner_slot]=stone("Attack",777,["Attack"])
	var entries:Array=game.all_power_stone_entries();var fitted_entries:Array=entries.filter(func(entry):return entry.get("fitted",false))
	var attack_powers:Array=entries.filter(func(entry):return entry.stone_type=="Attack").map(func(entry):return int(entry.power))
	check(entries.size()==game.power_stone_inventory.size()+1 and fitted_entries.size()==1 and int(fitted_entries[0].power)==777 and fitted_entries[0].owner==GameData.display_name(owner_q) and not fitted_entries[0].has("inventory_index") and attack_powers[0]==777 and range(attack_powers.size()-1).all(func(i):return attack_powers[i]>=attack_powers[i+1]),"Every owned stone is listed in one type-and-power order, fitted ones in their natural place with their owner and no inventory index")
	game.begin_stone_workshop("combine");game.show_stone_workshop();await process_frame
	var fitted_card=game.content.find_child("WorkshopFitted0_%d"%owner_slot,true,false)
	check(fitted_card!=null and fitted_card.find_child("FittedOwnerBadge",true,false)!=null and fitted_card.find_child("FittedStoneIcon",true,false).modulate.r<1.0 and fitted_card._get_drag_data(Vector2.ZERO)==null,"A fitted stone's card is darkened, badged with its owner, and not draggable")
	fitted_card.chosen.emit(fitted_card.item_data);await process_frame
	check(game.stone_workshop.selected.is_empty(),"Clicking a fitted stone in the workshop selects nothing")
	game.selected_roster=0;game.select_inventory_stone(game.fitted_power_stone_data(owner_q.power_slot_stones[owner_slot],0,owner_slot));await process_frame
	check(game.content.find_child("FittedStoneNote",true,false)!=null and game.content.find_child("RecyclePowerStone",true,false)==null and game.content.find_children("FittedOwnerBadge","",true,false).size()==1,"The Quiblet menu lists the fitted stone with its badge and offers no recycling for it")
	owner_q.power_slot_stones[owner_slot]={}
	# The removed charms are gone from drops and the item list.
	check(not GameData.SPECIAL_ITEM_DROP_WEIGHTS.has("Reforger Charm") and not game.special_items.has("Conversion Charm"),"The stone charms no longer exist")
	print("QUIBLETS_STONE_WORKSHOP_OK checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
