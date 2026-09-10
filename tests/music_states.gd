extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func check_loop(player:AudioStreamPlayer,path:String,message:String)->void:
	var track:=player.stream as AudioStreamWAV
	check(player.playing and track!=null and track.loop_mode==AudioStreamWAV.LOOP_FORWARD and track.loop_begin==0 and track.loop_end==roundi(track.get_length()*track.mix_rate) and track.get_meta("source_path","")==path,message)

func _initialize()->void:call_deferred("run")

func run()->void:
	var paths:=["BaseCamp.wav","BerryGrove.wav","BossTheme.wav","GotQuiblet.wav","GotQuibletSpecial.wav","StartCooking.wav","StartupTheme.wav"]
	for file in paths:check(load("res://audio/Music/"+file)!=null,"Missing music: "+file)
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp did not start its looping music")
	var startup:=game.startup_music.stream as AudioStreamWAV
	check(startup!=null and startup.loop_mode==AudioStreamWAV.LOOP_DISABLED and startup.get_meta("source_path","").ends_with("StartupTheme.wav"),"Startup theme must be a one-shot")
	game.show_startup_reveal();await process_frame
	check(game.startup_music.playing and not game.base_camp_music.playing and is_instance_valid(game.startup_overlay) and game.startup_overlay.find_children("*","Label",true,false)[0].text=="QUIBLETS","Startup theme did not play alone during title reveal")
	await create_timer(2.6).timeout
	check(game.base_camp_music.playing and game.base_camp_music.volume_db<0.0,"Base Camp music did not begin fading in from silence after the title")
	await create_timer(1.3).timeout
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music did not resume after the startup title")
	check(is_equal_approx(game.base_camp_music.volume_db,0.0),"Base Camp title fade did not reach full volume")
	game.base_camp_music.play(1.0);game.show_resources();await process_frame
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music stopped in Resources")
	check(game.base_camp_music.get_playback_position()>=.9,"Opening a Base Camp menu restarted the music instead of continuing it")
	game.show_cooking();await process_frame
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music stopped in Cooking")
	game.show_spice_workshop();await process_frame
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music stopped in the Spice Workshop")
	game.show_recipes();await process_frame
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music stopped in Recipes")
	game.show_all_quiblets();await process_frame
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music stopped in the Quiblet menu")
	game.show_quiblet_edit();await process_frame
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music stopped in Quiblet editing")
	game.show_training();await process_frame
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music stopped in Training")
	game.play_started_cooking_music();await create_timer(.1).timeout
	check(not game.started_cooking_music.playing and game.base_camp_music.playing and game.base_camp_music.volume_db<0.0,"Base Camp music should fade away before the Started Cooking cue begins")
	await create_timer(.12).timeout
	var cooking_started:=game.started_cooking_music.stream as AudioStreamWAV
	check(game.started_cooking_music.playing and cooking_started.loop_mode==AudioStreamWAV.LOOP_DISABLED and cooking_started.get_meta("source_path","").ends_with("StartCooking.wav"),"Started Cooking theme is wrong or looping")
	check(game.base_camp_music.playing and game.base_camp_music.volume_db<=-70.0,"Base Camp music should remain silent while the Started Cooking cue plays")
	await create_timer(1.55).timeout
	check(not game.started_cooking_music.playing and game.base_camp_music.playing and game.base_camp_music.volume_db<0.0,"Base Camp music should begin fading back after the cooking cue")
	await create_timer(1.25).timeout
	check_loop(game.base_camp_music,"res://audio/Music/BaseCamp.wav","Base Camp music did not return after the Started Cooking cue")
	check(is_equal_approx(game.base_camp_music.volume_db,0.0),"Base Camp music did not finish its slow return fade")
	game.show_map();await process_frame
	check(game.base_camp_music.playing and game.base_camp_music.volume_db<0.0 and game.expedition_music.playing and game.expedition_music.volume_db<0.0,"Base Camp to island selection did not begin an overlapping crossfade")
	await create_timer(.55).timeout
	check(db_to_linear(game.base_camp_music.volume_db)>.25 and db_to_linear(game.expedition_music.volume_db)>.25,"Both tracks should remain audibly present through the middle of the crossfade")
	await create_timer(.75).timeout
	check(not game.base_camp_music.playing and is_equal_approx(game.expedition_music.volume_db,0.0),"Base Camp to island-selection crossfade did not finish correctly")
	check_loop(game.expedition_music,"res://audio/Music/Expedition.wav","Island selection did not play the Expedition theme")
	game.expedition_music.play(1.0);game.show_area_levels(0);await process_frame
	check_loop(game.expedition_music,"res://audio/Music/Expedition.wav","Island level selection did not keep the Expedition theme")
	check(game.expedition_music.get_playback_position()>=.9,"Moving from island selection to level selection restarted the Expedition theme")
	game.show_camp();await process_frame
	check(game.expedition_music.playing and game.expedition_music.volume_db<0.0 and game.base_camp_music.playing and game.base_camp_music.volume_db<0.0,"Island selection to Base Camp did not begin an overlapping crossfade")
	await create_timer(.55).timeout
	check(db_to_linear(game.base_camp_music.volume_db)>.25 and db_to_linear(game.expedition_music.volume_db)>.25,"Both tracks should remain audibly present through the reverse crossfade")
	await create_timer(.75).timeout
	check(not game.expedition_music.playing and is_equal_approx(game.base_camp_music.volume_db,0.0),"Island-selection to Base Camp crossfade did not finish correctly")
	game.show_map();await create_timer(1.3).timeout
	game.start_area_level(0,0);await process_frame
	check(not game.base_camp_music.playing,"Base Camp music must stop when an expedition starts")
	check_loop(game.expedition_music,"res://audio/Music/Expedition.wav","Regular level did not use looping expedition music")
	# Pausing the expedition must not pause whatever music is playing.
	game.open_expedition_pause();await process_frame
	check(game.get_tree().paused and game.expedition_music.playing and game.expedition_music.can_process() and not game.expedition_music.stream_paused,"The current track should keep playing under the pause menu")
	check([game.base_camp_music,game.quiblet_arrival_music,game.started_cooking_music,game.startup_music].all(func(player):return player.process_mode==Node.PROCESS_MODE_ALWAYS),"Every music player should ignore the tree pause")
	game.close_expedition_pause();await process_frame
	check(not game.get_tree().paused and game.expedition_music.playing,"Music continues after the pause menu closes")
	game.expedition.wave=game.expedition.max_waves-1;game.expedition.spawn_wave();await process_frame
	check_loop(game.expedition_music,"res://audio/Music/Expedition.wav","The Boss theme must wait for the boss's grunt, not start at its spawn")
	await create_timer(2.4).timeout
	check_loop(game.expedition_music,"res://audio/Music/BossTheme.wav","The Boss theme should start once the boss has grunted")
	var level_boss:QuibletActor3D=game.expedition.enemies[-1]
	check(level_boss.get_meta("level_boss",false),"Final regular-level wave has no level boss")
	var escorts_before:int=game.expedition.enemies.size()-1;var loot_before:int=0
	for name in game.expedition.loot:loot_before+=int(game.expedition.loot[name])
	game.expedition._on_actor_defeated(level_boss);await process_frame
	check_loop(game.expedition_music,"res://audio/Music/BossTheme.wav","The Boss theme should keep playing after a regular level boss falls")
	var loot_after:int=0
	for name in game.expedition.loot:loot_after+=int(game.expedition.loot[name])
	check(game.expedition.enemies.is_empty() and game.expedition.intermission>0.0 and loot_after-loot_before>=escorts_before+1,"A fallen boss should rout its escorts and each should drop its loot")
	game.expedition.finish(false);await process_frame;game.show_area_levels(0);game.area_progress[0]=8
	game.start_area_level(0,3);await process_frame
	check_loop(game.expedition_music,"res://audio/Music/BerryGrove.wav","Berry Grove did not use its looping theme")
	game.expedition.finish(false);await process_frame;game.show_area_levels(0)
	game.start_area_level(0,7);await process_frame
	check_loop(game.expedition_music,"res://audio/Music/BerryGrove.wav","Optional Berry Grove did not use the Berry Grove theme")
	game.expedition.finish(false);await process_frame;game.show_area_levels(0)
	game.start_area_level(0,6);await process_frame
	check_loop(game.expedition_music,"res://audio/Music/Expedition.wav","A Boss level should open on the Expedition theme until its boss grunts")
	check(game.expedition.max_waves>=8 and game.expedition.enemies.size()>=2 and not game.expedition.enemies.any(func(enemy):return enemy.get_meta("level_boss",false)),"Boss level should open with its first enemy set")
	game.expedition.wave=game.expedition.max_waves-1;game.expedition.spawn_wave();await create_timer(2.4).timeout
	check_loop(game.expedition_music,"res://audio/Music/BossTheme.wav","A Boss level's boss should bring in the Boss theme after its grunt")
	game.expedition.finish(false);await process_frame
	check(game.screen=="expedition_changes","Boss expedition did not open Quiblet updates")
	check_loop(game.expedition_music,"res://audio/Music/BossTheme.wav","Boss theme did not continue into Quiblet updates")
	game.show_expedition_haul();await process_frame
	check_loop(game.expedition_music,"res://audio/Music/BossTheme.wav","Boss theme did not continue into acquired items")
	game.play_quiblet_arrival_music(false);await process_frame
	var normal:=game.quiblet_arrival_music.stream as AudioStreamWAV
	check(game.quiblet_arrival_music.playing and normal.loop_mode==AudioStreamWAV.LOOP_DISABLED and normal.get_meta("source_path","").ends_with("GotQuiblet.wav"),"Normal Quiblet arrival theme is wrong or looping")
	game.play_quiblet_arrival_music(true);await process_frame
	var special:=game.quiblet_arrival_music.stream as AudioStreamWAV
	check(game.quiblet_arrival_music.playing and special.loop_mode==AudioStreamWAV.LOOP_DISABLED and special.get_meta("source_path","").ends_with("GotQuibletSpecial.wav"),"Special Quiblet arrival theme is wrong or looping")
	print("QUIBLETS_MUSIC_STATES_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
