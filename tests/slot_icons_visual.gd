extends SceneTree
# Visual check of the Power Stone board icons. Run non-headless:
#   Godot --path . --script res://tests/slot_icons_visual.gd -- --no-save
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	await create_timer(3.0).timeout
	var q:Dictionary=game.roster[game.selected_roster];q.level=30
	if not q.power_slot_types.has("Flex"):q.power_slot_types[0]="Flex";q.power_slot_types[15]="Flex";q.power_slot_unlocks[15]=90
	game.show_quiblet_edit();await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-slot-icons.png")
	print("QUIBLETS_SLOT_ICONS_VISUAL_OK")
	quit()
