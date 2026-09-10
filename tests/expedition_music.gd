extends SceneTree

func _initialize()->void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var track:AudioStreamWAV=game.expedition_music.stream
	if not check(track!=null and track.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Expedition music must have a looping stream"):return
	if not check(track.loop_begin==0 and track.loop_end==roundi(track.get_length()*track.mix_rate) and track.loop_end>0,"The loop must span the entire track in sample frames"):return
	AudioServer.add_bus()
	var bus_index:=AudioServer.bus_count-1
	AudioServer.set_bus_name(bus_index,"ExpeditionMusicTest")
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=1.0
	AudioServer.add_bus_effect(bus_index,capture)
	game.expedition_music.bus="ExpeditionMusicTest"
	game.start_expedition("Music playback test")
	game.expedition.process_mode=Node.PROCESS_MODE_DISABLED
	await create_timer(1.35).timeout
	if not check(game.expedition_music.playing and has_audio(capture),"Starting an expedition must produce non-silent audio"):return
	capture.clear_buffer()
	game.expedition_music.play(track.get_length()-.15)
	await create_timer(.5).timeout
	if not check(game.expedition_music.playing and game.expedition_music.get_playback_position()<1.5 and has_audio(capture),"Music must remain audible and wrap back to the beginning at the loop boundary"):return
	capture.clear_buffer()
	await create_timer(.2).timeout
	if not check(has_audio(capture),"The next loop must continue producing non-silent audio"):return
	game.show_map()
	if not check(game.expedition_music.playing and (game.expedition_music.stream as AudioStreamWAV).get_meta("source_path","").ends_with("Expedition.wav"),"Island selection must continue with the Expedition theme"):return
	game.show_camp()
	if not check(game.expedition_music.playing and game.base_camp_music.playing,"Returning to Base Camp must begin an overlapping crossfade"):return
	await create_timer(1.3).timeout
	if not check(not game.expedition_music.playing and game.base_camp_music.playing and is_equal_approx(game.base_camp_music.volume_db,0.0),"The Base Camp crossfade did not finish correctly"):return
	game.queue_free()
	await process_frame
	AudioServer.remove_bus(bus_index)
	print("QUIBLETS_EXPEDITION_MUSIC_OK")
	quit()

func has_audio(capture:AudioEffectCapture)->bool:
	var samples:=capture.get_buffer(capture.get_frames_available())
	for sample in samples:
		if maxf(absf(sample.x),absf(sample.y))>.001:return true
	return false

func check(condition:bool,message:String)->bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
