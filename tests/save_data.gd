extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func run()->void:
	var packed:PackedScene=load("res://main.tscn")
	var source=packed.instantiate();root.add_child(source);await process_frame
	source.roster.append(GameData.make_quiblet(1,6));source.roster.append(GameData.make_quiblet(2,6))
	source.ingredients["Sunplum"]=17
	source.unlocked_ingredients.append("Sunplum")
	source.special_items["Treasure Key"]=3
	source.leftovers["Plain Stew"]=2
	source.known_recipes.append("Plain Stew")
	source.move_stone_inventory["echo"]=4
	source.power_stone_inventory.append({"type":"Attack","power":222,"quality":"Silver","bonuses":["Critical Hit Rate","Movement Speed"]})
	source.roster[0].nickname="Ripple"
	source.roster[0].level=12
	source.roster[0].exp=31
	source.roster[0].moves[0].stones=["reach"]
	source.team_indices.assign([2,0])
	source.area_progress[0]=6
	source.selected_area_index=2
	source.selected_level_index=3
	source.pending_stew={"recipe":"Plain Stew","quality":"Good","expeditions_required":2,"expeditions_remaining":1,"arrivals":[],"arrival_names":[],"arrival_species":[],"leftovers":0,"score":42,"boosted":false}
	var encoded:=JSON.stringify(source.save_data())
	var decoded=JSON.parse_string(encoded)
	check(decoded is Dictionary,"Save data must be valid JSON")
	var restored=packed.instantiate();root.add_child(restored);await process_frame
	restored.apply_save_data(decoded)
	check(restored.ingredients["Sunplum"]==17 and restored.unlocked_ingredients.has("Sunplum"),"Ingredient inventory and discoveries did not restore")
	check(restored.special_items["Treasure Key"]==3 and restored.leftovers["Plain Stew"]==2 and restored.known_recipes.has("Plain Stew"),"Resources, leftovers, or recipes did not restore")
	check(restored.move_stone_inventory["echo"]==4 and restored.power_stone_inventory[-1].power==222,"Stone inventories did not restore")
	check(restored.roster[0].nickname=="Ripple" and restored.roster[0].level==12 and restored.roster[0].exp==31 and restored.roster[0].moves[0].stones==["reach"],"Quiblet progression or equipment did not restore")
	check(restored.team_indices==[2,0] and restored.area_progress[0]==6 and restored.selected_area_index==2 and restored.selected_level_index==3,"Team or expedition progress did not restore")
	check(restored.pending_stew.quality=="Good" and restored.pending_stew.expeditions_remaining==1,"Cooking progress did not restore")
	var granted_save:Dictionary=(decoded as Dictionary).duplicate(true);granted_save.version=2;granted_save.ingredients={}
	for ingredient_name in GameData.INGREDIENTS:granted_save.ingredients[ingredient_name]=4
	granted_save.ingredients["Sunplum"]=9;granted_save.unlocked_ingredients=GameData.INGREDIENTS.keys()
	restored.apply_save_data(granted_save)
	check(restored.ingredients["Sunplum"]==5 and restored.unlocked_ingredients==["Sunplum"] and GameData.INGREDIENTS.keys().filter(func(ingredient_name):return ingredient_name!="Sunplum").all(func(ingredient_name):return int(restored.ingredients[ingredient_name])==0),"Version 3 should remove the temporary four-ingredient grant without removing later earnings")
	print("QUIBLETS_SAVE_DATA_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
