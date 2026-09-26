extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 check(game.save_access_blocked(),"Tests must not access saves")
 if is_instance_valid(game.startup_overlay):await create_timer(4).timeout
 game.play_base_camp_music();game.base_camp_music.play(1.0)
 for method in ["show_resources","show_stone_workshop","show_spice_workshop","show_cooking","show_recipes","show_all_quiblets","show_quiblet_edit","show_training"]:
  game.call(method);await process_frame
  check(game.base_camp_music.playing,"Camp music continues in "+method)
  check(game.base_camp_music.get_playback_position()>=.9,"Menu must not restart the track: "+method)
 game.show_item_use("Move Crystal");await process_frame
 check(game.base_camp_music.playing,"Item use keeps camp music")
 game.show_stone_workshop();game.show_crystallization_picker();await process_frame
 check(game.base_camp_music.playing,"Crystallization picker keeps camp music")
 game.show_move_slot_manager();game.move_slot_selection=[[0,0],[1,0]];game.show_move_slot_manager(false);game.confirm_move_slot_extraction();await process_frame
 check(game.base_camp_music.playing,"Crystallization and confirmation keep camp music")
 game.stop_primary_music();game.show_resources();await process_frame
 check(game.base_camp_music.playing,"Direct menu entry restores camp music from silence")
 game.stop_primary_music();game.play_expedition_music("level");game.show_quiblet_edit()
 await create_timer(1.3).timeout
 check(game.base_camp_music.playing and not game.expedition_music.playing,"Direct entry from expedition music crossfades to camp music")
 game.play_started_cooking_music();await create_timer(.25).timeout
 game.show_stone_workshop();await process_frame
 check(game.started_cooking_music.playing and game.base_camp_music.volume_db< -60,"Workshop preserves the cooking cue")
 game.started_cooking_music.stop();game._on_started_cooking_music_finished();await create_timer(1.3).timeout
 check(game.base_camp_music.playing and is_equal_approx(game.base_camp_music.volume_db,0),"Cooking cue restores camp music in workshop")
 game.queue_free();await process_frame
 print("BASE_CAMP_MENU_MUSIC failures=",failures)
 quit(1 if failures else 0)
