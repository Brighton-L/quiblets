extends SceneTree

const ICON:=preload("res://scripts/power_stone_icon.gd")
var failures:=0

func check(condition:bool,message:String)->void:
	if not condition:
		failures+=1;push_error(message)

func _initialize()->void:
	var fixture_bonuses:Array=["Fixture bonus A","Fixture bonus B","Fixture bonus C","Fixture bonus D"]
	for kind in ["Health","Attack"]:
		for quality_index in 5:
			for tier in range(1,6):
				var bonuses:Array=fixture_bonuses.slice(0,quality_index)
				var stone:=GameData.make_power_stone(kind,tier,bonuses)
				check(stone.quality==GameData.POWER_STONE_QUALITIES[quality_index] and stone.bonuses.size()==quality_index and stone.bonus_count==quality_index,"Quality must match the number of bonus stats")
				var limits:Vector2i=GameData.POWER_STONE_RANGES[tier-1]
				for roll in 100:
					var rolled:=GameData.make_power_stone(kind,tier,bonuses)
					check(rolled.power>=limits.x and rolled.power<=limits.y and rolled.tier==tier,"A stone must roll within its selected tier")
				var icon:=ICON.new();icon.size=Vector2(64,64);icon.setup(stone)
				check(icon.base_texture.resource_path=="res://textures/PowerStones/%sStoneBase.png"%stone.quality,"Each quality must select its matching base")
				check(icon.level_texture.resource_path=="res://textures/PowerStones/%sStoneLV%d.png"%[kind,tier],"The overlay must match type and selected tier")
				check(icon.base_texture.get_size()==Vector2(512,512) and icon.level_texture.get_size()==Vector2(512,512),"Base and overlay canvases must align")
				check(icon.power_number_rect()==Rect2(19.5,40.5,25,12.5),"The number must be drawn in the base's darker rectangle")
				icon.free()
	var legacy:=GameData.normalize_power_stone({"type":"Attack","power":12,"bonuses":["Existing bonus"],"custom_metadata":"preserve"})
	check(legacy.power==12 and legacy.quality=="Bronze" and legacy.bonuses==["Existing bonus"] and legacy.custom_metadata=="preserve","Migration must preserve existing power, bonuses, and metadata")
	var overlap:=GameData.normalize_power_stone({"type":"Health","power":105,"tier":2})
	check(overlap.tier==2 and GameData.normalize_power_stone(JSON.parse_string(JSON.stringify(overlap))).tier==2,"Saved tiers must not be re-inferred from overlapping power values")
	var sample:=GameData.make_power_stone("Health",3,fixture_bonuses.slice(0,3));sample.power=275
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.roster[0].level=100;game.power_stone_inventory.assign([sample.duplicate(true)]);game.show_quiblet_edit();await process_frame
	var first_slot:int=GameData.first_power_slot_accepting(game.roster[0],"Health");var second_slot:int=range(16).filter(func(index):return index!=first_slot and GameData.power_slot_accepts(game.roster[0],index,"Health"))[0]
	var card=game.content.find_child("StoneInventoryCard0",true,false)
	check(card.item_data.quality=="Gold" and card.item_data.tier==3 and card.find_child("PowerStoneIcon",true,false).stone.power==275,"Inventory cards must preserve and render complete stones")
	var data:Dictionary=card.item_data.duplicate(true);game.select_inventory_stone(data);await process_frame
	check(game.content.find_child("PowerStoneBonusDescription",true,false).text.contains("Fixture bonus C"),"Stone details must show all existing bonuses")
	game.equip_stone_from_inventory("power",first_slot,-1,data);await process_frame
	var fitted=game.content.find_child("PowerStoneSlot%d"%first_slot,true,false)
	check(fitted.find_child("PowerStoneIcon",true,false).stone==GameData.normalize_power_stone(sample),"Equipped slots must render the same layered stone")
	var fitted_icon:Control=fitted.find_child("PowerStoneIcon",true,false)
	check(fitted_icon.position==Vector2.ZERO and fitted_icon.size==fitted.size and fitted.position==Vector2.ZERO and fitted.size==fitted.get_parent().size,"Equipped Power Stones must fill their entire matching slot without a smaller inset")
	var drag_data:Dictionary=game.take_equipment_for_drag("power",first_slot,-1)
	check(drag_data.tier==3 and drag_data.quality=="Gold" and drag_data.bonuses.size()==3 and not fitted.has_node("PowerStoneIcon"),"Detaching a stone must preserve its metadata and immediately remove its fitted icon")
	var preview:Control=fitted.create_equipment_drag_preview(drag_data)
	check(preview.modulate.a==1 and preview.find_child("PowerStoneIcon",true,false).stone.power==275,"The drag preview must use the opaque assembled icon")
	var preview_icon:Control=preview.find_child("PowerStoneIcon",true,false)
	check(preview_icon.position+preview_icon.size*.5==Vector2.ZERO,"Equipped Power Stone drag previews must center the assembled stone on the cursor")
	preview.free()
	game.equip_stone_from_inventory("power",second_slot,-1,drag_data);await process_frame
	check(game.roster[0].power_slot_stones[second_slot].bonuses==sample.bonuses and game.roster[0].power_slot_stones[second_slot].tier==3,"Transferring a stone must not reroll its tier or bonuses")
	game.remove_equipped_stone("power",second_slot,-1);await process_frame
	check(game.power_stone_inventory.size()==1 and game.power_stone_inventory[0].quality=="Gold","Removing a stone must return the original quality to inventory")
	game.start_expedition("Power Stone test");game.expedition.process_mode=Node.PROCESS_MODE_DISABLED
	var reward:=sample.duplicate(true);reward.merge({"kind":"power_stone","amount":1})
	var pickup:Control=game.build_reward_pickup(reward)
	check(pickup.find_child("PowerStoneIcon",true,false).stone.tier==3 and pickup.find_children("*","Label",true,false).is_empty(),"Collection animations must show the layered icon without an external amount")
	game.expedition.power_stones.append(sample.duplicate(true));game.open_expedition_pause()
	check(game.pause_overlay.find_children("PowerStoneIcon","",true,false).size()==1,"The pause haul must use the shared stone icon")
	game.give_up_expedition();await process_frame
	check(game.power_stone_inventory.size()==2 and game.power_stone_inventory[-1].tier==3 and game.power_stone_inventory[-1].bonuses==sample.bonuses,"Banked expedition loot must retain all stone fields")
	game.queue_free();await process_frame
	if OS.get_cmdline_user_args().has("--render-gallery"):
		await render_gallery(fixture_bonuses)
	print("QUIBLETS_POWER_STONES_OK variants=50" if failures==0 else "QUIBLETS_POWER_STONES_FAILED count=%d"%failures)
	quit(0 if failures==0 else 1)

func render_gallery(bonuses:Array)->void:
	root.size=Vector2i(1140,650)
	var gallery:=Control.new();root.add_child(gallery)
	var background:=ColorRect.new();background.color=Color("#333a44");background.size=Vector2(1140,650);gallery.add_child(background)
	for column in 10:
		var header:=Label.new();header.text=("Health" if column<5 else "Attack")+" LV%d"%(column%5+1);header.position=Vector2(120+column*100,28);header.add_theme_font_size_override("font_size",13);gallery.add_child(header)
	for quality_index in 5:
		var label:=Label.new();label.text=GameData.POWER_STONE_QUALITIES[quality_index];label.position=Vector2(16,96+quality_index*110);gallery.add_child(label)
		for column in 10:
			var tier:=column%5+1;var limits:Vector2i=GameData.POWER_STONE_RANGES[tier-1]
			var stone:=GameData.make_power_stone("Health" if column<5 else "Attack",tier,bonuses.slice(0,quality_index));stone.power=(limits.x+limits.y)/2
			var icon:=ICON.new();icon.position=Vector2(112+column*100,62+quality_index*110);icon.size=Vector2(96,96);icon.setup(stone);gallery.add_child(icon)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture:=root.get_texture().get_image()
	check(capture!=null and capture.save_png("/private/tmp/quiblets-power-stone-gallery.png")==OK,"The gallery should render successfully")
