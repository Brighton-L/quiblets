extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func tags_match(items:Array[String],need:Dictionary)->bool:
	var counts:={}
	for item in items:
		for tag in GameData.INGREDIENTS[item].tags:counts[tag]=int(counts.get(tag,0))+1
	return need.keys().all(func(tag):return int(counts.get(tag,0))>=int(need[tag]))
func run()->void:
	var keys:=GameData.INGREDIENTS.keys();var reachable:={};var minimums:={}
	# Exhaust all unordered bowls, including repeats; every recipe must be craftable.
	for a in keys.size():
		for b in range(a,keys.size()):
			for c in range(b,keys.size()):
				var short:Array[String]=[keys[a],keys[b],keys[c]]
				check(GameData.choose_spice(short).is_empty(),"Three ingredients cannot make a spice")
				for recipe in GameData.SPICE_RECIPES:check(not tags_match(short,recipe.need),"Tags alone must prevent a three-ingredient recipe: "+recipe.name)
				for d in range(c,keys.size()):
					var bowl:Array[String]=[keys[a],keys[b],keys[c],keys[d]]
					for candidate in GameData.SPICE_RECIPES:
						if tags_match(bowl,candidate.need):minimums[candidate.name]=4
					var recipe:=GameData.choose_spice(bowl)
					if not recipe.is_empty():reachable[recipe.name]=true
					for e in range(d,keys.size()):
						var full:Array[String]=[keys[a],keys[b],keys[c],keys[d],keys[e]]
						for candidate in GameData.SPICE_RECIPES:
							if tags_match(full,candidate.need) and not minimums.has(candidate.name):minimums[candidate.name]=5
						var result:=GameData.choose_spice(full)
						if not result.is_empty():reachable[result.name]=true
	for recipe in GameData.SPICE_RECIPES:check(reachable.has(recipe.name) and int(minimums.get(recipe.name,0)) in [4,5] and not recipe.has("ingredients"),"Recipe must require four or five ingredients and be reachable: "+recipe.name)
	var rolls:={}
	for i in 100:
		var result:=GameData.revitalize_power_stone({"type":"Health","power":10,"bonuses":[]},3)
		check(int(result.power)>=248 and int(result.power)<=253,"Revitalizer bonus must be within 0–5");rolls[result.power]=true
	check(rolls.size()>1,"Separate revitalizations should vary")
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.unlocked_spices.append("Hot Flakes");game.spice_inventory["Hot Flakes"]["great"]=2;game.spice_inventory["Hot Flakes"]["basic"]=1;game.special_items["Bountiful Berry"]=1
	game.show_cooking();await process_frame
	var cards:Array=game.content.find_children("*","Panel",true,false).filter(func(node):return node is CookingItemCard)
	for card in cards:
		var data:Dictionary=card.drag_payload;card.chosen.emit(data);await process_frame
		check(game.selected_cooking_item==data and game.content.find_child("SelectedItemName",true,false)!=null,"Cooking source click shows item details")
		# Rebuild frees the remaining old cards, so inspect subsequent sources directly.
		break
	game.select_cooking_source({"kind":"special","id":"Bountiful Berry"});await process_frame
	check(game.content.find_child("SelectedItemName",true,false).text=="Bountiful Berry","Special ingredients can be inspected")
	game.unlocked_spices.clear();game.show_spice_workshop();await process_frame
	check(game.content.find_child("SpiceRecipeRequires",true,false)==null and game.content.find_child("SpiceNext",true,false)==null,"No spice details or navigation appear before unlocking a spice")
	game.unlocked_spices.append("Hot Flakes");game.show_spice_workshop();await process_frame
	check(game.content.find_child("SpiceNext",true,false).disabled,"A single unlocked spice disables navigation")
	game.unlocked_spices.append("Rare Spice");game.step_spice_recipe(1);await process_frame
	check(game.spice_recipe_index==7 and game.content.find_child("SpiceRecipeName",true,false).text.contains("Rare Spice"),"Navigation skips locked spices, including unlocked spices with no stock")
	game.step_spice_recipe(1);await process_frame
	check(game.spice_recipe_index==0,"Navigation wraps only among unlocked spices")
	game.step_spice_recipe(-1);await process_frame
	check(game.spice_recipe_index==7,"Previous also skips locked spices")
	game.spice_recipe_index=3;game.show_spice_workshop();await process_frame
	check(game.spice_recipe_index==0,"A stale locked selection falls back to an unlocked spice")
	check(game.content.find_child("SpiceRecipeBrowser",true,false)!=null,"Spice browser exists")
	check(game.content.find_child("SpiceRecipeRequires",true,false).text==game.requirement_text(GameData.SPICE_RECIPES[game.spice_recipe_index].need),"Spice browser shows only tag requirements, with no ingredient count")
	var spice_cards:Array=game.content.find_child("OwnedSpices",true,false).find_children("*","Panel",true,false).filter(func(node):return node is CookingItemCard)
	check(spice_cards.size()==2,"Owned spice list separates tiers and omits empty stacks")
	spice_cards[0].chosen.emit(spice_cards[0].drag_payload);await process_frame
	check(game.spice_recipe_index==0,"Clicking owned spice selects its recipe")
	for destination in [game.show_resources,game.show_spice_workshop,game.show_quiblet_edit,game.show_stone_workshop,game.show_cooking,game.show_training,game.show_all_quiblets]:
		destination.call();await process_frame
		var back=game.content.find_child("BackButton",true,false)
		check(back!=null,"Each menu has a back button")
		if back!=null:
			for sibling in back.get_parent().get_children():
				if sibling==back or not sibling is Control or sibling is ColorRect:continue
				if sibling is Panel:check(not back.get_global_rect().intersects(sibling.get_global_rect()),"Back button must not overlap panel on "+game.screen)
	game.screen="expedition";game.expedition=Expedition3D.new();game.add_child(game.expedition)
	game.open_expedition_pause();game.request_give_up_expedition();await process_frame
	check(paused and game.content.find_child("GiveUpConfirmation",true,false)!=null,"Giving up first opens a paused confirmation")
	game.content.find_child("CancelGiveUp",true,false).pressed.emit();await process_frame
	check(not paused and game.screen=="expedition","Cancel returns to the same expedition")
	game.expedition.queue_free();game.expedition=null
	print("QUIBLETS_MENU_UPDATES checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
