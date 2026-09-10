extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func set_pot(game:Node,contents:Dictionary)->Dictionary:
	game.pot=contents.duplicate()
	return GameData.choose_recipe(game.pot)

func _initialize()->void:call_deferred("run")

func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.leftover_boost=false;game.empty_leftover_jar_used=false
	var recipe:=set_pot(game,{"Bumbleberry":1,"Emberpepper":1,"Dewmelon":1,"Knobroot":1,"Curlcap":1})
	check(recipe.name=="Plain Stew" and game.calculate_stew_score(recipe)==25 and game.calculate_quality()=="Decent","Common varied Plain Stew should be Decent with a score of 25")
	recipe=set_pot(game,{"Stonebean":5})
	check(game.calculate_stew_score(recipe)==52 and game.calculate_quality()=="Good","Tier-2 recipe match should be Good")
	recipe=set_pot(game,{"Brinepod":5})
	check(game.calculate_stew_score(recipe)==72 and game.calculate_quality()=="Great","Tier-3 recipe match should be Great")
	recipe=set_pot(game,{"Sunplum":2,"Frostberry":2,"Sparkfruit":1})
	check(recipe.name=="Fancy Feast" and game.calculate_stew_score(recipe)==84 and game.calculate_quality()=="Amazing","Precise high-tier recipe should be Amazing")
	recipe=set_pot(game,{"Bumbleberry":1,"Emberpepper":1,"Dewmelon":1,"Knobroot":1,"Curlcap":1});game.empty_leftover_jar_used=true
	check(game.calculate_stew_score(recipe)==37 and game.calculate_quality()=="Good","An Empty Leftover Jar should add recipe precision without adding ingredient quality")
	game.empty_leftover_jar_used=false
	check(game.quality_rarity_multiplier("Decent")==1.0 and game.quality_rarity_multiplier("Good")==1.25 and game.quality_rarity_multiplier("Great")==1.75 and game.quality_rarity_multiplier("Amazing")==2.5,"Quality rarity multipliers are wrong")
	check(game.quality_stone_chance("Decent")==.08 and game.quality_stone_chance("Good")==.15 and game.quality_stone_chance("Great")==.25 and game.quality_stone_chance("Amazing")==.35,"Quality Power Stone chances are wrong")
	check(game.quality_expeditions_required("Decent")==1 and game.quality_expeditions_required("Good")==2 and game.quality_expeditions_required("Great")==3 and game.quality_expeditions_required("Amazing")==5,"Cooking expedition requirements are wrong")
	check(not game.is_rare_arrival(0) and game.is_rare_arrival(1) and game.is_rare_arrival(5) and game.is_rare_arrival(7),"Actual rare-arrival classification is wrong")
	var move_rng:=RandomNumberGenerator.new();move_rng.seed=84721
	var bloomie_rolls:={}
	var rolled_move_counts:={}
	for i in 60:
		var rolled_bloomie:=GameData.make_quiblet(5,5,"",true,move_rng)
		var rolled_names:Array=rolled_bloomie.moves.map(func(move):return str(move.name))
		bloomie_rolls["|".join(rolled_names)]=true
		rolled_move_counts[rolled_names.size()]=true
		check(rolled_names.size() in [1,2,3] and rolled_names.all(func(move_name):return GameData.learnset(5).has(move_name)) and rolled_names.duplicate().all(func(move_name):return rolled_names.count(move_name)==1),"An acquired Bloomie rolled an invalid move count, move, or duplicate")
	check(bloomie_rolls.size()>1,"Acquired Quiblets should not all receive the same starting move set")
	check(rolled_move_counts.has(1) and rolled_move_counts.has(2) and rolled_move_counts.has(3),"Acquired Quiblets should be able to roll one, two, or three initial moves")
	var roster_before:int=game.roster.size()
	for ingredient_name in ["Bumbleberry","Emberpepper","Dewmelon","Knobroot","Curlcap"]:game.ingredients[ingredient_name]=3;game.unlocked_ingredients.append(ingredient_name)
	game.show_cooking()
	for i in 5:game.assign_pot_slot(i,["Bumbleberry","Emberpepper","Dewmelon","Knobroot","Curlcap"][i])
	game.request_start_cooking();await process_frame
	check(game.pending_stew.is_empty() and game.content.find_child("StartCookingConfirmation",true,false)!=null,"Start Cooking should require confirmation before consuming the pot")
	var predicted_recipe:String=GameData.choose_recipe(game.pot).name
	check(not game.content.find_child("StartCookingConfirmation",true,false).find_children("*","Label",true,false).any(func(item):return str(item.text).contains(predicted_recipe)),"The confirmation dialog must not name the stew")
	game.content.find_child("CancelStartCooking",true,false).pressed.emit();await process_frame
	check(game.pending_stew.is_empty() and game.pot_total()==5,"Canceling Start Cooking should preserve every filled pot slot")
	game.request_start_cooking();game.content.find_child("ConfirmStartCooking",true,false).pressed.emit();await process_frame
	check(game.screen=="camp" and game.pending_stew.quality=="Decent" and int(game.pending_stew.expeditions_remaining)==1 and game.roster.size()==roster_before,"Starting a stew returns straight to camp without awarding its Quiblet")
	var dropping_lid:Node3D=game.world_root.get_node("CookingPotLid");var resting_y:float=dropping_lid.get_meta("resting_y")
	var rim_top:float=game.world_mesh_bounds(game.world_root.get_node("CookingPot")).end.y;var lid_bottom_start:float=rim_top+(dropping_lid.position.y-resting_y)
	check(lid_bottom_start>game.COOKING_INDICATOR_HEIGHT and lid_bottom_start<game.COOKING_INDICATOR_HEIGHT+1.5,"Right after starting a stew the lid begins a little above the expedition counter")
	await create_timer(.2).timeout
	check(dropping_lid.position.y>resting_y+(game.COOKING_INDICATOR_HEIGHT+1.0-rim_top) or dropping_lid.rotation.y>0.0,"The lid hops slightly higher, then spins on the way down")
	await create_timer(.5).timeout
	check(is_equal_approx(dropping_lid.position.y,resting_y) and is_zero_approx(dropping_lid.rotation.y),"The lid settles squarely on the pot with its spin finished")
	await create_timer(.22).timeout
	check(game.started_cooking_music.playing and (game.started_cooking_music.stream as AudioStreamWAV).loop_mode==AudioStreamWAV.LOOP_DISABLED,"A valid stew should trigger the non-looping Started Cooking theme")
	game.show_camp();await process_frame
	check(game.world_root.get_node_or_null("CookingPotLid")!=null,"A cooking pot should have its lid on")
	var cooking_progress:=game.world_root.get_node_or_null("CookingProgressIndicator") as Label3D
	check(cooking_progress!=null and cooking_progress.text=="0/1","A cooking pot should show completed expeditions over required expeditions")
	check(cooking_progress!=null and is_equal_approx(cooking_progress.pixel_size,.00125) and cooking_progress.fixed_size,"The cooking counter should render at a quarter of the default label size")
	var pot_bounds:AABB=game.world_mesh_bounds(game.world_root.get_node("CookingPot"));var lid_bounds:AABB=game.world_mesh_bounds(game.world_root.get_node("CookingPotLid"))
	check(lid_bounds.position.y>=pot_bounds.end.y-.02 and lid_bounds.position.y<=pot_bounds.end.y+.02,"The lid should rest on the pot's rim rather than float inside or above it")
	check(lid_bounds.size.x>=pot_bounds.size.x and lid_bounds.end.y<cooking_progress.position.y,"The lid should cover the pot's opening and sit below the counter")
	check(game.world_root.get_node_or_null("CookingPotHitbox")==null,"A cooking pot should not be clickable before it is ready")
	game.open_cooking_pot()
	check(game.screen=="camp","Trying to open a cooking pot should do nothing before it is ready")
	check(game.advance_pending_stew() and game.pending_stew.is_empty() and game.roster.size()==roster_before+1 and not game.completed_stew_result.is_empty(),"A Decent stew should finish after one expedition advance")
	game.show_camp();await process_frame
	check(game.world_root.get_node_or_null("CookingPotLid")!=null and game.world_root.get_node_or_null("CookingReadyIndicator")!=null,"A finished pot should keep its lid and show the pink ready indicator")
	check(game.world_root.get_node_or_null("CookingProgressIndicator")==null and game.world_root.get_node_or_null("CookingPotHitbox")!=null,"A finished pot should replace its progress counter and become clickable")
	var ready_indicator:Node3D=game.world_root.get_node("CookingReadyIndicator")
	check(ready_indicator.get_children().all(func(part):return part is Label3D and is_equal_approx(part.pixel_size,.00125) and part.fixed_size),"The ready exclamation should render at a quarter of the default label size")
	game.completed_stew_result.clear()
	for ingredient_name in ["Sunplum","Frostberry","Sparkfruit"]:game.ingredients[ingredient_name]=15;if not game.unlocked_ingredients.has(ingredient_name):game.unlocked_ingredients.append(ingredient_name)
	game.show_cooking()
	var amazing_mix:=["Sunplum","Sunplum","Frostberry","Frostberry","Sparkfruit"]
	for i in 5:game.assign_pot_slot(i,amazing_mix[i])
	var amazing_roster_before:int=game.roster.size();game.cook();await process_frame
	check(game.pending_stew.quality=="Amazing" and int(game.pending_stew.expeditions_remaining)==5,"An Amazing stew should require five expeditions")
	for i in 4:check(not game.advance_pending_stew() and game.roster.size()==amazing_roster_before,"An Amazing stew finished before five expedition advances")
	check(game.advance_pending_stew() and game.roster.size()==amazing_roster_before+1,"An Amazing stew did not finish on its fifth expedition advance")
	# Predicted result on the pot lid: --- under five ingredients, ??? until discovered, then the name.
	game.pending_stew={};game.completed_stew_result={};game.known_recipes.clear();game.clear_all_cooking_slots(true);game.show_cooking();await process_frame
	check(game.content.find_child("PredictedResult",true,false).text=="Predicted Result: ---","An unfilled pot predicts ---")
	game.ingredients["Stonebean"]=15
	if not game.unlocked_ingredients.has("Stonebean"):game.unlocked_ingredients.append("Stonebean")
	for i in 5:game.assign_cooking_item("ingredient",i,{"kind":"ingredient","name":"Stonebean"})
	await process_frame
	var predicted_name:String=GameData.choose_recipe(game.pot).name
	check(predicted_name!="Plain Stew" and game.content.find_child("PredictedResult",true,false).text=="Predicted Result: ???","An undiscovered stew predicts ???")
	game.known_recipes.append(predicted_name);game.show_cooking();await process_frame
	check(game.content.find_child("PredictedResult",true,false).text=="Predicted Result: "+predicted_name,"A discovered stew predicts its name")
	var predicted_label:Label=game.content.find_child("PredictedResult",true,false);var pot_art:Control=game.content.find_child("CookingPotTexture",true,false)
	check(predicted_label.position.y<pot_art.position.y+pot_art.size.y*.3 and predicted_label.position.y>pot_art.position.y,"The prediction sits in the lid band at the top of the pot art")
	game.clear_all_cooking_slots(true)
	# Recipe browser: one stew at a time, numbered, with "???" until discovered.
	game.pending_stew={};game.completed_stew_result={};game.known_recipes.clear();game.cooking_recipe_index=0;game.show_cooking();await process_frame
	var browser:Control=game.content.find_child("RecipeBrowser",true,false)
	check(browser!=null and browser.find_child("RecipeNumber",true,false).text=="#1" and browser.find_child("RecipeName",true,false).text=="Plain Stew" and browser.find_child("RecipeRequires",true,false).text=="any five ingredients" and browser.find_child("RecipeAttracts",true,false).text=="Attracts any Quiblet","The browser opens on stew #1 with its name, requirements, and what it attracts")
	check(browser.find_child("RecipeNumber",true,false).position.x<20 and browser.find_child("RecipeNumber",true,false).position.y<20 and browser.find_child("RecipeAttracts",true,false).position.x>browser.find_child("RecipeRequires",true,false).position.x,"The stew number sits top-left and what it attracts sits right of the requirements")
	check(browser.find_child("RecipePrevious",true,false).text=="▲" and browser.find_child("RecipeNext",true,false).text=="▼","Up and down arrows step through recipes")
	browser.find_child("RecipeNext",true,false).pressed.emit();await process_frame;browser=game.content.find_child("RecipeBrowser",true,false)
	check(game.cooking_recipe_index==1 and browser.find_child("RecipeNumber",true,false).text=="#2" and browser.find_child("RecipeName",true,false).text=="???" and browser.find_child("RecipeRequires",true,false).text=="???" and browser.find_child("RecipeAttracts",true,false).text=="???","An undiscovered stew shows ??? for its name, requirements, and attraction")
	game.known_recipes.append("Rock Bottom Broth");game.show_cooking();await process_frame;browser=game.content.find_child("RecipeBrowser",true,false)
	check(browser.find_child("RecipeName",true,false).text=="Rock Bottom Broth" and browser.find_child("RecipeRequires",true,false).text==game.requirement_text(GameData.RECIPES[1].need) and browser.find_child("RecipeAttracts",true,false).text=="Attracts sturdy Green-type Quiblets","A discovered stew reveals its details")
	browser.find_child("RecipePrevious",true,false).pressed.emit();await process_frame
	game.step_cooking_recipe(-1);await process_frame
	check(game.cooking_recipe_index==GameData.RECIPES.size()-1 and game.content.find_child("RecipeNumber",true,false).text=="#%d"%GameData.RECIPES.size(),"Stepping up from the first stew wraps to the last")
	check(game.content.find_children("*","Panel",true,false).filter(func(node):return node.get_parent()==game.content.find_child("RecipeBrowser",true,false)).is_empty(),"Only one recipe is shown at a time")
	var species_names:Array=[]
	for entry in GameData.SPECIES:species_names.append(str(entry.name))
	for stew in GameData.RECIPES:
		var hint:String=game.recipe_attracts_text(stew)
		check(hint.begins_with("Attracts ") and not species_names.any(func(name):return hint.contains(name)),"Every recipe's attraction hint is generic and names no species: "+stew.name)
	# Spices season arrivals with small permanent stat bonuses scaled by quality.
	var hot_great:Dictionary=GameData.spice_stat_bonuses("Hot Flakes","great");var hot_basic:Dictionary=GameData.spice_stat_bonuses("Hot Flakes","basic");var hot_special:Dictionary=GameData.spice_stat_bonuses("Hot Flakes","special")
	check(is_equal_approx(float(hot_great.get("attack",0.0)),.04) and is_equal_approx(float(hot_basic.get("attack",0.0)),.014) and is_equal_approx(float(hot_special.get("attack",0.0)),.06),"Hot Flakes stat bonus should scale with spice quality")
	check(GameData.spice_stat_bonuses("Swift Spice","great").has("speed") and GameData.spice_stat_bonuses("Brain Salt","great").has("cooldown"),"Swift Spice and Brain Salt should season speed and cooldowns")
	for spice_name in GameData.SPICES:check(not GameData.spice_stat_bonuses(spice_name,"great").is_empty() and GameData.spice_stat_text(spice_name,"great")!="","Every spice should carry a stat bonus: "+spice_name)
	check(GameData.spice_stat_text("Hot Flakes","special")=="+6.0% Attack" and GameData.spice_stat_text("Brain Salt","great")=="−3.0% move cooldowns","Spice stat text is wrong")
	game.spice_slots[0]={"name":"Iron Flakes","quality":"special"};game.spice_slots[1]={"name":"Gentle Herb","quality":"basic"}
	var seasoning:Dictionary=game.spice_arrival_bonuses()
	check(is_equal_approx(float(seasoning.get("max_hp",0.0)),.06+.007) and is_equal_approx(float(seasoning.get("healing",0.0)),.0175),"Two placed spices should stack their arrival bonuses")
	var plain:Dictionary=GameData.make_quiblet(3,8);var seasoned:Dictionary=GameData.make_quiblet(3,8);seasoned.spice_bonuses=seasoning
	check(GameData.max_hp(seasoned)==int(GameData.max_hp(plain)*1.067) and GameData.attack(seasoned)==GameData.attack(plain),"Seasoning should raise max HP through the bonus totals without touching Attack")
	check(is_equal_approx(float(GameData.quiblet_bonus_totals(seasoned).get("healing",0.0)),.0175),"Seasoning should reach the battle bonus totals")
	var plain_mix:=["Bumbleberry","Emberpepper","Dewmelon","Knobroot","Curlcap"]
	for ingredient_name in plain_mix:game.ingredients[ingredient_name]=int(game.ingredients.get(ingredient_name,0))+3
	game.pending_stew.clear();game.clear_all_cooking_slots(true);game.spice_slots[0]={"name":"Iron Flakes","quality":"special"};game.spice_slots[1]={"name":"Gentle Herb","quality":"basic"};game.show_cooking()
	for i in 5:game.assign_pot_slot(i,plain_mix[i])
	game.cook();await process_frame
	check(game.pending_stew.size()>0 and game.pending_stew.arrivals.size()==1 and game.pending_stew.arrivals[0].has("spice_bonuses") and is_equal_approx(float(game.pending_stew.arrivals[0].spice_bonuses.get("max_hp",0.0)),.067),"Cooking with spices should season the arrival")
	check(game.spice_slots.all(func(slot):return slot.is_empty()),"Spices should be consumed by cooking")
	for ingredient_name in plain_mix:game.ingredients[ingredient_name]=int(game.ingredients.get(ingredient_name,0))+3
	game.pending_stew.clear();game.clear_all_cooking_slots(true);game.show_cooking()
	for i in 5:game.assign_pot_slot(i,plain_mix[i])
	game.cook();await process_frame
	check(game.pending_stew.size()>0 and not game.pending_stew.arrivals[0].has("spice_bonuses"),"Unspiced stews should not season the arrival")
	game.pending_stew.clear()
	# Filled leftover jars are visible under Resources and can be recycled there.
	game.leftovers["Plain Stew"]=2;game.show_resources();await process_frame
	var jar_rows:Array=game.content.find_children("LeftoverRow","",true,false);var recycle_buttons:Array=game.content.find_children("RecycleLeftovers","",true,false)
	check(jar_rows.size()==1 and recycle_buttons.size()==1 and jar_rows[0].find_children("*","Label",true,false).any(func(entry):return entry.text=="× 2"),"Resources should list stored leftovers with their count and a recycle button")
	var ingredient_total_before:int=0
	for name in game.ingredients:ingredient_total_before+=int(game.ingredients[name])
	recycle_buttons[0].pressed.emit();await process_frame
	var ingredient_total_after:int=0
	for name in game.ingredients:ingredient_total_after+=int(game.ingredients[name])
	var recovered:int=ingredient_total_after-ingredient_total_before
	check(game.leftovers["Plain Stew"]==1 and recovered>=2 and recovered<=4 and game.screen=="inventory" and game.content.find_children("LeftoverRow","",true,false).size()==1,"Recycling from Resources should spend one jar, return two to four ingredients, and stay on Resources")
	game.leftovers["Plain Stew"]=0;game.show_resources();await process_frame
	check(game.content.find_children("LeftoverRow","",true,false).is_empty(),"Empty leftover stock should not list a jar")
	print("QUIBLETS_COOKING_QUALITY_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
