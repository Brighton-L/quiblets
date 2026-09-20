extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 game.pending_stew={"expeditions_remaining":2,"recipe":"Plain Stew","quality":"Decent","score":25,"arrivals":[],"arrival_names":[],"arrival_species":[],"leftovers":0,"boosted":false}
 game.garden_plots[0]={"ingredient":"Bumbleberry","required":2,"remaining":2,"yield":4}
 var result={"victory":false,"loot":{},"special":"","exp":0}
 game._on_expedition_finished(result);assert(game.pending_stew.expeditions_remaining==2 and game.garden_plots[0].remaining==2)
 game._on_expedition_finished(result);assert(game.pending_stew.expeditions_remaining==2 and game.completed_stew_result.is_empty())
 result.victory=true;game._on_expedition_finished(result);assert(game.pending_stew.expeditions_remaining==1 and game.garden_plots[0].remaining==1)
 result.victory=false;game._on_expedition_finished(result);assert(game.pending_stew.expeditions_remaining==1 and game.garden_plots[0].remaining==1)
 result.victory=true;game._on_expedition_finished(result);assert(game.pending_stew.is_empty() and game.completed_stew_result.recipe=="Plain Stew" and game.garden_plots[0].remaining==0)
 game.queue_free();await process_frame
 print("Only victories advance and complete stews; non-victories preserve progress")
 quit()
