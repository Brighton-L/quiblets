extends SceneTree
# Visual check of the Stone Workshop. Run non-headless:
#   Godot --path . --script res://tests/workshop_visual.gd -- --no-save
func _initialize()->void:call_deferred("run")
func stone(type:String,power:int,bonuses:Array)->Dictionary:
	return GameData.normalize_power_stone({"type":type,"power":power,"bonuses":bonuses})
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	await create_timer(3.0).timeout
	game.power_stone_inventory.clear()
	for value in [stone("Attack",410,["Critical Hit Rate","Movement Speed","Health"]),stone("Attack",392,["Critical Hit Rate","Attack","Evasion","Move Cooldown"]),stone("Attack",365,["Healing Received"]),stone("Attack",118,["Damage Resistance"]),stone("Health",300,["Health"]),stone("Health",90,[]),stone("Health",520,["Evasion","Health"]),stone("Attack",640,[])]:game.power_stone_inventory.append(value)
	game.area_progress[3]=4
	game.show_resources();await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-workshop-resources.png")
	game.begin_stone_workshop("combine");game.show_stone_workshop()
	for index in [0,1,2,3]:game.workshop_pick_stone(index)
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-workshop-combine.png")
	game.apply_stone_workshop();game.set_stone_workshop_mode("reforge");game.workshop_pick_stone(4);game.stone_workshop.bonus_index=1;game.workshop_pick_stone(0)
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-workshop-reforge.png")
	game.set_stone_workshop_mode("revitalize");game.workshop_pick_stone(2)
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/quiblets-workshop-revitalize.png")
	print("QUIBLETS_WORKSHOP_VISUAL_OK")
	quit()
