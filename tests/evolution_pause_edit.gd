extends SceneTree

func _initialize()->void:call_deferred("run")

func run()->void:
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.roster.clear();game.roster.append(GameData.make_quiblet(2,17));game.selected_roster=0
 game.show_quiblet_edit();await process_frame
 var toggle=game.content.find_child("EvolutionToggle",true,false)
 var recycle=game.content.find_child("OpenPowerStoneRecycler",true,false)
 assert(toggle.text=="PAUSE\nEVOLUTION")
 assert(not toggle.get_global_rect().intersects(recycle.get_global_rect()))
 toggle.pressed.emit();await process_frame
 assert(game.screen=="edit_quiblet" and game.roster[0].evolution_paused)
 assert(game.content.find_child("EvolutionToggle",true,false).text=="EVOLUTION\nPAUSED")
 game.grant_training_exp(game.roster[0],GameData.exp_to_level(17))
 assert(game.roster[0].level==18 and game.roster[0].species==2)
 var saved=game.save_data();game.apply_save_data(saved)
 assert(game.roster[0].evolution_paused and game.roster[0].species==2)
 game.show_quiblet_edit();await process_frame
 game.content.find_child("EvolutionToggle",true,false).pressed.emit();await process_frame
 assert(not game.roster[0].evolution_paused and game.screen=="edit_quiblet")
 game.grant_training_exp(game.roster[0],GameData.exp_to_level(18))
 assert(game.roster[0].species==3)
 print("Evolution toggle, layout, paused level-up, in-memory persistence and resumed evolution passed")
 game.queue_free();await process_frame;quit()
