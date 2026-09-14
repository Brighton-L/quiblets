extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	assert(game.save_access_blocked(),"All script launches must isolate the player's save")
	assert(not game.persistence_enabled)
	# Even an accidental override or force argument must not reach file access.
	game.persistence_enabled=true
	assert(not game.load_game(true),"Forced loads must not read player progress")
	assert(not game.save_game(true),"Forced saves must not write player progress")
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._process(3.0)
	game._exit_tree()
	game.persistence_enabled=false
	print("QUIBLETS_SAVE_ISOLATION_OK");quit()
