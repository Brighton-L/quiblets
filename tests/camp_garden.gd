extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scripts/main.gd").new();root.add_child(game)
 assert(game.save_access_blocked())
 var garden=game.garden
 for points in 17:
  assert(garden.fertilizer_bonus(points,.99)==int(points/3))
  assert(garden.fertilizer_bonus(points,0.0)==int(points/3)+int(points%3>0))
 game.ingredients.Bumbleberry=5;game.ingredients.Sunplum=4
 game.unlocked_ingredients.append("Bumbleberry")
 garden.slots=["Bumbleberry","Sunplum","Sunplum","Sunplum",""]
 assert(garden.commit_plant())
 assert(game.ingredients.Bumbleberry==4 and game.ingredients.Sunplum==1)
 assert(game.garden_plots[0].remaining==2 and game.garden_plots[0]["yield"]>=7 and game.garden_plots[0]["yield"]<=9)
 assert(not garden.commit_plant())
 var saved:Dictionary=game.save_data();game.garden_plots=[{},{},{},{}];game.apply_save_data(saved)
 assert(game.garden_plots[0].remaining==2)
 garden.advance();assert(game.garden_plots[0].remaining==1)
 garden.advance();assert(game.garden_plots[0].remaining==0)
 game.show_camp();garden.open(0);garden.harvest()
 assert(game.garden_plots[0].is_empty() and game.ingredients.Bumbleberry>=11)
 var count:int=game.ingredients.Bumbleberry;garden.harvest();assert(game.ingredients.Bumbleberry==count)
 garden.tween.kill();game.show_camp();garden.open(1)
 garden.slots=["Sunplum","","","",""];assert(garden.commit_plant())
 assert(game.garden_plots[1].required in [5,6])
 garden.tween.kill();game.show_camp();garden.open(2)
 garden.slots=["Sunplum","Sunplum","","",""];assert(not garden.commit_plant())
 garden.slots=["Bumbleberry","Bumbleberry","","",""];garden.draw_menu();garden.confirm_plant()
 saved=game.save_data();saved.erase("garden_plots");game.apply_save_data(saved)
 assert(game.garden_plots==[{},{},{},{}])
 game.queue_free();await process_frame
 print("Garden: fertilizer thresholds, consumption, growth, harvest, duplicate protection, menus, and in-memory persistence passed")
 quit()
