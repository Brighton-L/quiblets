extends SceneTree

func _initialize()->void:call_deferred("run")

func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.75).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-startup-reveal.png")
	await create_timer(1.8).timeout
	assert(not is_instance_valid(game.startup_overlay) and not game.startup_music.playing,"Startup reveal or theme did not finish together")
	print("QUIBLETS_STARTUP_VISUAL_OK")
	quit()
