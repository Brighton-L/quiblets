extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 var visitor:=GameData.make_quiblet(2,5);game.roster.append(visitor)
 game.completed_stew_result={"recipe":GameData.RECIPES[1].name,"new_recipe":true,"arrival_uids":[visitor.uid],"arrival_species":[2]}
 game.show_camp();await process_frame
 var residents=game.world_root.get_node("CampResidents")
 game.open_cooking_pot();await process_frame
 var sequence=game.arrival_sequence
 assert(sequence.revealing_stew and not sequence.can_continue)
 assert(sequence.visitors.is_empty())
 sequence.advance();assert(sequence.revealing_stew)
 await create_timer(2.1).timeout
 assert(sequence.can_continue and game.content.find_child("StewRecipeCard",true,false)!=null)
 assert(game.content.find_child("RecipeNext",true,false)==null and game.content.find_child("RecipePrevious",true,false)==null)
 assert(game.content.find_child("NewRecipeNotice",true,false)!=null)
 assert(not game.world_root.get_node("CookingPotLid").visible)
 assert(residents==game.world_root.get_node("CampResidents") and residents.is_processing())
 var color=sequence.stew_visual.get_node("Broth").material_override.albedo_color
 assert(color==GameData.RECIPES[1].color)
 sequence.advance();await create_timer(.95).timeout
 assert(game.completed_stew_result.stew_revealed and not sequence.revealing_stew and sequence.visitors.size()==1)
 print("Stew reveal: lid, card, new-recipe notice, click gate, resident continuity and arrival handoff passed")
 game.queue_free();await process_frame;quit()
