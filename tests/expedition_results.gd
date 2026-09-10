extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func click(game)->void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=Vector2(640,650);game._input(event)

func _initialize()->void:call_deferred("run")

func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.roster[0].level=24;game.roster[0].exp=GameData.exp_to_level(24)-10
	var before:Dictionary=game.roster[0].duplicate(true);var old_slots:=0
	for move in before.moves:old_slots+=int(move.slots)
	game.start_area_level(0,0);await process_frame
	game.expedition.loot["Bumbleberry"]=4;game.expedition.loot["Emberpepper"]=2
	game.expedition.move_stones["echo"]=2
	game.expedition.power_stones.append(GameData.make_power_stone("Attack",2))
	game.expedition.power_stones.append(GameData.make_power_stone("Health",1))
	game.expedition.fortune=true
	var cooked_arrival:=GameData.make_quiblet(2,4);var roster_before_stew:int=game.roster.size()
	game.pending_stew={"recipe":"Plain Stew","quality":"Good","score":45,"arrivals":[cooked_arrival],"arrival_names":["Spriggle Lv.4"],"arrival_species":[2],"leftovers":0,"boosted":false,"expeditions_required":2,"expeditions_remaining":2}
	# Supply a deterministic special item while retaining the real expedition result shape.
	var finished:Dictionary={"victory":true,"exp":40,"loot":game.expedition.loot.duplicate(),"move_stones":game.expedition.move_stones.duplicate(),"power_stones":game.expedition.power_stones.duplicate(true),"special":"Growth Fruit","berries":2,"elapsed":5.0,"area_index":0,"node_index":0,"stage_kind":"level"}
	var finished_expedition=game.expedition
	game._on_expedition_finished(finished);await process_frame
	check(game.unlocked_ingredients.has("Bumbleberry") and game.unlocked_ingredients.has("Emberpepper"),"Collecting an ingredient for the first time should unlock it")
	check(int(game.pending_stew.expeditions_remaining)==1 and game.roster.size()==roster_before_stew,"A finished expedition did not advance the active stew exactly once")
	check(game.expedition_music.playing and (game.expedition_music.stream as AudioStreamWAV).get_meta("source_path","").ends_with("Expedition.wav"),"The expedition track should continue into Quiblet updates")
	check(game.screen=="expedition_changes" and not game.result_advance_ready,"Results must begin on a locked Quiblet-animation screen")
	var update_backdrop:ColorRect=game.content.find_child("ResultBackdrop",true,false)
	check(update_backdrop!=null and is_equal_approx(update_backdrop.color.a,.68) and update_backdrop.color.get_luminance()<.05 and is_instance_valid(finished_expedition) and finished_expedition.is_inside_tree(),"Quiblet updates should show the finished expedition through a translucent near-black backdrop")
	check(game.expedition_team_results.size()==game.team_indices.size(),"Not every expedition team member received a change card")
	check(game.content.find_children("QuibletChangeCard*","Panel",true,false).size()==game.team_indices.size(),"Missing Quiblet change cards")
	# The unlock square starts at the pre-expedition state and animates to the final one.
	var start_grid:Control=game.content.find_child("QuibletChangeCard0",true,false).find_child("ResultPowerGrid",true,false)
	var start_ring:Control=start_grid.find_child("UnlockProgressRing",true,false);var start_expected:Dictionary=game.animated_unlock_progress(before,int(before.level),int(before.exp))
	check(start_ring!=null and is_equal_approx(start_ring.progress,float(start_expected.progress)) and start_grid.find_children("LockedSlotRect","",true,false).size()==range(16).filter(func(index):return not GameData.power_slot_unlocked(before,index)).size(),"Result cards begin with the pre-expedition unlock progress and locked slots")
	var probe:=GameData.make_quiblet(0,1);var probe_levels:Array=probe.power_slot_unlocks.duplicate();probe_levels.sort();var second:int=int(probe_levels[1])
	var midway:Dictionary=game.animated_unlock_progress(probe,1,GameData.exp_to_level(1)/2)
	check(is_equal_approx(float(midway.progress),.5/float(second-1)) and int(midway.index)==probe.power_slot_unlocks.find(second),"Animated progress uses the fractional level")
	click(game);check(game.screen=="expedition_changes","Click skipped an unfinished animation")
	await create_timer(2.2).timeout
	check(game.result_advance_ready and game.content.find_child("ResultContinuePrompt",true,false)!=null and game.content.find_child("ResultContinuePrompt",true,false).text=="click to continue","Quiblet updates should end with the requested continuation prompt")
	var first_card:Control=game.content.find_child("QuibletChangeCard0",true,false)
	check(first_card.find_child("ResultLevel",true,false).text=="Lv. 25","Level did not animate to its final value")
	var end_grid:Control=first_card.find_child("ResultPowerGrid",true,false);var end_ring:Control=end_grid.find_child("UnlockProgressRing",true,false);var end_expected:Dictionary=game.animated_unlock_progress(game.roster[0],25,int(game.roster[0].exp))
	check(end_ring!=null and is_equal_approx(end_ring.progress,float(end_expected.progress)) and end_grid.find_children("LockedSlotRect","",true,false).size()==range(16).filter(func(index):return not GameData.power_slot_unlocked(game.roster[0],index)).size(),"The unlock square and locked slots animate to the post-expedition state")
	# Each card mirrors the full Quiblet info menu: info section plus stone equipment menu.
	var menu:Control=first_card.find_child("ResultMenu",false,false)
	check(menu!=null and menu.size.x==game.RESULT_MENU_WIDTH and menu.scale.x<=1.0 and menu.find_child("ResultInfo",false,false)!=null and menu.find_child("ResultEquipment",false,false)!=null,"Result cards should be scaled replicas of the Quiblet info menu")
	var equipment:Control=menu.find_child("ResultEquipment",false,false);var grid:Control=equipment.find_child("ResultPowerGrid",false,false)
	check(grid.position.y<20 and grid.position.x>400 and equipment.size.y<=maxf(game.roster[0].moves.size()*66.0+16.0,268.0) and menu.size.y==equipment.position.y+equipment.size.y,"The condensed menu puts the Power Stone grid beside the moves and trims empty space")
	var cards_all:Array=game.content.find_children("QuibletChangeCard*","Panel",true,false);var layout:Dictionary=game.best_result_card_layout(cards_all.size(),menu.size)
	check(is_equal_approx(first_card.size.x,menu.size.x*float(layout.scale)) and float(layout.scale)>=.5,"Cards use the largest scale that fits the screen for this team size")
	var widest:float=0.0;var tallest:float=0.0
	for card in cards_all:widest=maxf(widest,card.position.x+card.size.x);tallest=maxf(tallest,card.position.y+card.size.y)
	check(widest>1000.0 or tallest>500.0,"The card layout should fill most of the screen")
	var final_quiblet:Dictionary=game.roster[0]
	check(menu.find_children("ResultMoveIcon*","",true,false).size()==final_quiblet.moves.size() and menu.find_children("ResultPowerSlot*","",true,false).size()==16,"Result cards should show every move and all sixteen Power Stone slots")
	var total_slots:=0
	for move in final_quiblet.moves:total_slots+=int(move.slots)
	check(menu.find_children("ResultStoneSlot*","",true,false).size()==total_slots,"Result cards should show each move's Move Stone slots")
	check(menu.find_child("HealthStatBadgeValue",true,false).text==str(GameData.max_hp(final_quiblet)) and menu.find_child("AttackStatBadgeValue",true,false).text==str(GameData.attack(final_quiblet)),"Stat badges should animate to the final values")
	var cards:Array=game.content.find_children("QuibletChangeCard*","Panel",true,false)
	check(cards.all(func(card):return card.position.x>=0 and card.position.x+card.size.x<=1280 and card.position.y>=0 and card.position.y+card.size.y<=612),"Every result card must fit on screen above the continue prompt")
	check(first_card.find_child("ResultChanges",true,false)==null and first_card.size.is_equal_approx(first_card.find_child("ResultMenu",false,false).size*first_card.find_child("ResultMenu",false,false).scale.x),"Result cards carry no change summary beneath the menu")
	var new_slots:=0;for move in game.roster[0].moves:new_slots+=int(move.slots)
	check(new_slots>old_slots or game.roster[0].moves.size()>before.moves.size(),"Milestone fixture did not produce a move or Move Stone-slot change")
	if OS.get_cmdline_user_args().has("--render-gallery"):
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/private/tmp/quiblets-quiblet-changes.png")
	click(game);await process_frame
	check(game.screen=="expedition_haul" and game.result_advance_ready and game.content.find_child("ResultContinuePrompt",true,false).text=="click to continue","Acquired items should show the requested continuation prompt")
	var haul_backdrop:ColorRect=game.content.find_child("ResultBackdrop",true,false)
	check(haul_backdrop!=null and is_equal_approx(haul_backdrop.color.a,.68) and haul_backdrop.color.get_luminance()<.05 and is_instance_valid(finished_expedition) and finished_expedition.is_inside_tree(),"Acquired items should show the finished expedition through a translucent near-black backdrop")
	check(game.expedition_music.playing and (game.expedition_music.stream as AudioStreamWAV).get_meta("source_path","").ends_with("Expedition.wav"),"The expedition track should continue into acquired items")
	var entries:Array=game.expedition_haul_entries()
	check(entries.filter(func(e):return e.kind=="ingredient" and e.name=="Bumbleberry" and e.amount==4).size()==1,"Ingredient haul missing")
	check(entries.filter(func(e):return e.kind=="move_stone" and e.amount==2).size()==1,"Move Stone haul missing")
	check(entries.filter(func(e):return e.kind=="power_stone").size()==2,"Power Stone haul missing")
	check(entries.filter(func(e):return e.kind=="special" and e.name=="Growth Fruit").size()==1,"Special-item haul missing")
	check(game.content.find_children("HaulItem*","Panel",true,false).size()==entries.size(),"Not every acquired item is displayed")
	if OS.get_cmdline_user_args().has("--render-gallery"):
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/private/tmp/quiblets-expedition-haul.png")
	click(game);await process_frame
	check(game.screen=="map" and game.expedition==null,"Second click did not return to area selection")
	# Quit and full-team failure must enter the same first results screen and not unlock levels.
	game.start_area_level(1,0);await process_frame;game.expedition.give_up();await process_frame
	check(game.screen=="expedition_changes" and not game.last_result.victory and game.area_progress[1]==0,"Give Up bypassed results or unlocked progress")
	check(game.pending_stew.is_empty() and game.roster.size()==roster_before_stew+1 and not game.completed_stew_result.is_empty(),"Give Up should count as a finished expedition and complete the stew")
	game.show_area_levels(2);game.start_area_level(2,0);await process_frame
	for actor in game.expedition.team.duplicate():actor.take_damage(actor.max_hp*2)
	await process_frame;await process_frame
	check(game.screen=="expedition_changes" and not game.last_result.victory and game.area_progress[2]==0,"Team failure bypassed results or unlocked progress")
	# Special items are rare on ordinary victories, likelier on Boss levels, common with Fortune, and every item can drop.
	check(is_equal_approx(GameData.special_item_drop_chance("level",false),.03) and is_equal_approx(GameData.special_item_drop_chance("boss",false),.08) and is_equal_approx(GameData.special_item_drop_chance("level",true),.48),"Special item drop chances are wrong")
	check(GameData.SPECIAL_ITEM_DROP_WEIGHTS.keys().all(func(item):return game.special_items.has(item)) and game.special_items.keys().all(func(item):return GameData.SPECIAL_ITEM_DROP_WEIGHTS.has(item) or item=="Treasure Key"),"Every special item except the separately rolled Treasure Key should be in the drop table")
	var key_rng:=RandomNumberGenerator.new();key_rng.seed=77;var key_drops:=0;var boss_keys:=0
	for i in 20000:
		if GameData.roll_treasure_key("level",false,key_rng):key_drops+=1
		if GameData.roll_treasure_key("boss",false,key_rng):boss_keys+=1
	check(key_drops>20000*.10 and key_drops<20000*.14 and boss_keys>20000*.22 and boss_keys<20000*.28,"Treasure Keys should drop about 12%% of regular wins and 25%% of Boss wins (got %d and %d of 20000)"%[key_drops,boss_keys])
	var drop_rng:=RandomNumberGenerator.new();drop_rng.seed=2026
	var dropped:={};var drops:=0;var boss_drops:=0;var fortune_drops:=0;var trials:=20000
	for i in trials:
		var item:=GameData.roll_special_item("level",false,drop_rng)
		if item!="":drops+=1;dropped[item]=int(dropped.get(item,0))+1
		if GameData.roll_special_item("boss",false,drop_rng)!="":boss_drops+=1
		if GameData.roll_special_item("level",true,drop_rng)!="":fortune_drops+=1
	check(drops>trials*.02 and drops<trials*.04,"Ordinary victories should drop a special item about 3%% of the time (got %d of %d)"%[drops,trials])
	check(boss_drops>trials*.065 and boss_drops<trials*.095 and fortune_drops>trials*.44 and fortune_drops<trials*.52,"Boss and Fortune drop rates are off (boss %d, fortune %d of %d)"%[boss_drops,fortune_drops,trials])
	check(dropped.has("Bountiful Berry") and dropped.has("Empty Leftover Jar") and dropped.has("Fortune Charm") and not dropped.has("Treasure Key") and dropped.size()>=GameData.SPECIAL_ITEM_DROP_WEIGHTS.size()-2,"Rare drops should include cooking specials and charms but roll keys separately")
	print("QUIBLETS_EXPEDITION_RESULTS_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
