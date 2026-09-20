extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 var terrain=game.world_root.get_node("CampLandscape")
 assert(not terrain.camp_berry_patches.is_empty())
 var id:String=terrain.camp_berry_patches.keys()[0]
 var patch:Node3D=terrain.camp_berry_patches[id]
 var ingredient:String=patch.get_meta("ingredient");var before:int=game.ingredients[ingredient]
 game.harvest_camp_berry(id)
 assert(game.ingredients[ingredient]==before+1 and not patch.visible and patch.get_node("HarvestHitbox").collision_layer==0)
 game.harvest_camp_berry(id);assert(game.ingredients[ingredient]==before+1)
 var deadline:float=game.camp_berry_regrowth[id]
 game.show_team();game.show_camp();assert(not patch.visible)
 var saved:Dictionary=game.save_data();game.apply_save_data(saved);game.show_camp()
 assert(game.camp_berry_regrowth[id]==deadline and not patch.visible)
 terrain.refresh_wild_berries(deadline-.01);assert(not patch.visible)
 terrain.refresh_wild_berries(deadline);assert(patch.visible and patch.get_node("HarvestHitbox").collision_layer==2)
 assert(terrain.harvest_wild_berry(id,deadline)==ingredient and not patch.visible)
 for other_id in terrain.camp_berry_patches:
  if other_id!=id:assert(terrain.camp_berry_patches[other_id].visible)
 saved.erase("camp_berry_regrowth");game.apply_save_data(saved);game.show_camp();assert(patch.visible)
 game.queue_free();await process_frame
 print("Wild camp berries: harvest once, regrow on time, independent patches, menu persistence and in-memory save/load passed")
 quit()
