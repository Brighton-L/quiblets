extends Node3D

const SAVE_PATH := "user://quiblets_save.json"
const HEALTH_BAR_SCRIPT:=preload("res://scripts/quiblet_health_bar.gd")
const PORTRAIT_COOLDOWN_SCRIPT:=preload("res://scripts/expedition_portrait_cooldown.gd")
const TEAM_RING_SCRIPT:=preload("res://scripts/team_ring_3d.gd")
const TEAM_DROP_SLOT_SCRIPT:=preload("res://scripts/team_drop_slot.gd")
const ROSTER_CARD_SCRIPT:=preload("res://scripts/quiblet_roster_card.gd")
const STONE_CARD_SCRIPT:=preload("res://scripts/stone_inventory_card.gd")
const EQUIPMENT_SLOT_SCRIPT:=preload("res://scripts/equipment_drop_slot.gd")
const MOVE_ICON_SCRIPT:=preload("res://scripts/move_icon.gd")
const POWER_STONE_ICON_SCRIPT:=preload("res://scripts/power_stone_icon.gd")
const TRAINING_SLOT_SCRIPT:=preload("res://scripts/training_drop_slot.gd")
const SPICE_MIX_SLOT_SCRIPT:=preload("res://scripts/spice_mix_slot.gd")
const SPICE_MIX_MAX:=5
const UNLOCK_RING_SCRIPT:=preload("res://scripts/unlock_progress_ring.gd")
const REWARD_SPARKLES_SCRIPT:=preload("res://scripts/reward_sparkles.gd")

var roster: Array = []
var team_indices: Array[int] = [0]
var ingredients := {"Bumbleberry":0,"Emberpepper":0,"Dewmelon":0,"Knobroot":0,"Curlcap":0,"Stonebean":0,"Honeybulb":0,"Bitterleaf":0,"Puffshroom":0,"Crystalcorn":0,"Brinepod":0,"Sparkfruit":0,"Oldroot":0,"Glowcap":0,"Frostberry":0,"Sunplum":0}
var special_items := {"Health Charm":0,"Attack Charm":0,"Memory Fruit":0,"Move Crystal":0,"Echo Crystal":0,"Growth Fruit":0,"Bountiful Berry":0,"Empty Leftover Jar":0,"Fortune Charm":0,"Challenger's Charm":0,"Treasure Key":0,"Prodigy Fruit":0}
var leftovers := {}
var known_recipes: Array[String] = []
var pot := {}
var pot_slots: Array[String] = ["","","","",""]
var spice_slots: Array[Dictionary] = [{},{}]
var special_slots: Array[String] = ["",""]
var spice_mix: Array[String] = []
var spice_inventory := {
	"Hot Flakes":{"basic":0,"good":0,"great":0,"special":0},
	"Iron Flakes":{"basic":0,"good":0,"great":0,"special":0},
	"Swift Spice":{"basic":0,"good":0,"great":0,"special":0},
	"Punch Pepper":{"basic":0,"good":0,"great":0,"special":0},
	"Brain Salt":{"basic":0,"good":0,"great":0,"special":0},
	"Sharp Salt":{"basic":0,"good":0,"great":0,"special":0},
	"Gentle Herb":{"basic":0,"good":0,"great":0,"special":0},
	"Rare Spice":{"basic":0,"good":0,"great":0,"special":0}
}
# Spices are hidden in the workshop until crafted at least once.
var unlocked_spices: Array[String] = []
var selected_cooking_ingredient := ""
var selected_cooking_item:Dictionary={}
var unlocked_ingredients: Array[String] = []
var leftover_boost := false
var empty_leftover_jar_used:=false
var use_bountiful := false
var screen := "camp"
var ui: CanvasLayer
var content: Control
var expedition
var expedition_music: AudioStreamPlayer
var base_camp_music:AudioStreamPlayer
var quiblet_arrival_music:AudioStreamPlayer
var started_cooking_music:AudioStreamPlayer
var startup_music:AudioStreamPlayer
var startup_overlay:CanvasLayer
var base_camp_music_fade:Tween
var expedition_music_fade:Tween
var started_cooking_sequence:=0
var current_expedition_music_path:=""
var reward_pickup_delay:=0.0
var expedition_health_bars:={}
var expedition_paused:=false
var pause_overlay:Control
var move_stone_inventory:={}
var power_stone_inventory:Array[Dictionary]=[]
var selected_roster := 0
var selected_team_slot := 0
var last_result := {}
var pending_stew:Dictionary={}
var completed_stew_result:Dictionary={}
var fortune_active := false
var challenger_active := false
var pot_preview: Label
var difficulty_level := 8
const AREAS_PER_PAGE:=3
const SPECIAL_ITEM_DESCRIPTIONS:={"Health Charm":"Permanent scaling HP growth.","Attack Charm":"Permanent scaling Attack growth.","Memory Fruit":"Restore an individually remembered move.","Move Crystal":"Add one Move Stone slot (max 8).","Echo Crystal":"Copy a fitted Move Stone.","Growth Fruit":"Catch up toward the current team level.","Bountiful Berry":"Attract 2–5 lower-level arrivals.","Empty Leftover Jar":"Collects leftovers from the next finished stew.","Fortune Charm":"Harder run; improved rare loot chance.","Challenger's Charm":"Harder run; much more ordinary progress.","Treasure Key":"Opens marked expedition caches.","Prodigy Fruit":"Next milestone grants both outcomes."}
const MUSIC_FADE_SECONDS:=1.2
const MUSIC_SILENCE_DB:=-80.0
const COOKING_MUSIC_FADE_OUT_SECONDS:=.18
const COOKING_MUSIC_FADE_IN_SECONDS:=1.2
const COOKING_POT_REFERENCE_SIZE:=512.0
const COOKING_POT_DISPLAY_SIZE:=512.0
# Height of the cooking counter and ready badge above the pot; the lid drop starts just above it.
const COOKING_INDICATOR_HEIGHT:=3.55
var map_page:=0
var selected_area_index:=0
var selected_level_index:=0
var area_progress:Array[int]=[]
var expedition_team_before:Array[Dictionary]=[]
var expedition_team_results:Array[Dictionary]=[]
var result_advance_ready:=false
var world_root: Node3D
var camera_3d: Camera3D
var camp_pan_x:=0.0
var camp_pan_dragging:=false
var move_slot_texture_cache := {}
var selected_inventory_item:Dictionary={}
var all_quiblets_scroll:=0
var quiblet_inventory_page:=0
var cooking_recipe_index:=0
var lid_drop_pending:=false
var stone_inventory_page:=0
var selection_pulse_roster:=-1
var team_preview_camera:Camera3D
var team_preview_models:Array[Dictionary]=[]
var team_preview_angle:=0.0
var pending_team_drag:Dictionary={}
var persistence_enabled:=false
var autosave_elapsed:=0.0
const AUTOSAVE_INTERVAL:=2.0
# Every navigation back button sits in the bottom-right corner of the screen.
const BACK_BUTTON_POSITION:=Vector2(1182,646)
var training_mode:="move"
var training_trainee:=-1
var training_helpers:Array[int]=[-1,-1,-1,-1]
var training_foods:Array[String]=["",""]
var training_move:=-1
var training_rng:RandomNumberGenerator
var last_training_result:Dictionary={}

const TEAM_SLOT_NAMES := ["Red","Green","Blue","Cyan","Yellow"]
const TEAM_SLOT_COLORS := [Color("#e96257"),Color("#67a65a"),Color("#5279d8"),Color("#55c7cf"),Color("#e7b83f")]

const MOVE_SLOT_MARKERS := {
	16774242:"chain", # 255, 244, 98
	9233682:"force", # 140, 229, 18
	4849605:"seeking", # 73, 255, 197
	8900318:"reach", # 135, 206, 222
	4416489:"rush", # 67, 99, 233
	16740884:"heavy", # 255, 114, 20
	8867125:"blast", # 135, 77, 53
	11534394:"drain", # 176, 0, 58
	16063272:"split", # 245, 27, 40
	16749480:"sharing", # 255, 147, 168
	8604340:"echo", # 131, 74, 180
	4861840:"lingering" # 74, 47, 144
}

func _ready() -> void:
	seed(40281)
	# Visual checks and tooling can pass --no-save so the real save file is never touched.
	persistence_enabled=DisplayServer.get_name()!="headless" and not OS.get_cmdline_user_args().has("--no-save")
	area_progress.resize(GameData.EXPEDITION_AREAS.size());area_progress.fill(0)
	if not load_game():create_starter_roster()
	create_3d_stage()
	expedition_music=AudioStreamPlayer.new();expedition_music.name="ExpeditionMusic";add_child(expedition_music)
	expedition_music.stream=looping_music("res://audio/Music/Expedition.wav");current_expedition_music_path="res://audio/Music/Expedition.wav"
	base_camp_music=AudioStreamPlayer.new();base_camp_music.name="BaseCampMusic";base_camp_music.stream=looping_music("res://audio/Music/BaseCamp.wav");add_child(base_camp_music)
	quiblet_arrival_music=AudioStreamPlayer.new();quiblet_arrival_music.name="QuibletArrivalMusic";add_child(quiblet_arrival_music)
	started_cooking_music=AudioStreamPlayer.new();started_cooking_music.name="StartedCookingMusic";started_cooking_music.stream=one_shot_music("res://audio/Music/StartCooking.wav");started_cooking_music.finished.connect(_on_started_cooking_music_finished);add_child(started_cooking_music)
	startup_music=AudioStreamPlayer.new();startup_music.name="StartupMusic";startup_music.stream=one_shot_music("res://audio/Music/StartupTheme.wav");add_child(startup_music)
	# Music keeps playing through the expedition pause menu: the tree pause must not reach the players.
	for player in [expedition_music,base_camp_music,quiblet_arrival_music,started_cooking_music,startup_music]:player.process_mode=Node.PROCESS_MODE_ALWAYS
	ui = CanvasLayer.new()
	add_child(ui)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(content)
	show_camp()
	if DisplayServer.get_name()!="headless":show_startup_reveal()
	if OS.get_cmdline_user_args().has("--open-map"):call_deferred("show_map")
	elif OS.get_cmdline_user_args().has("--open-team"):call_deferred("show_team")
	elif OS.get_cmdline_user_args().has("--open-cooking"):call_deferred("show_cooking")
	elif OS.get_cmdline_user_args().has("--open-spices"):call_deferred("show_spice_workshop")
	elif OS.get_cmdline_user_args().has("--open-recipes"):call_deferred("show_recipes")

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_WM_CLOSE_REQUEST:save_game()

func _exit_tree()->void:
	save_game()

func save_data()->Dictionary:
	return {
		"version":3,
		"roster":roster.duplicate(true),
		"team_indices":team_indices.duplicate(),
		"ingredients":ingredients.duplicate(true),
		"unlocked_ingredients":unlocked_ingredients.duplicate(),
		"special_items":special_items.duplicate(true),
		"leftovers":leftovers.duplicate(true),
		"known_recipes":known_recipes.duplicate(),
		"pot_slots":pot_slots.duplicate(),
		"spice_slots":spice_slots.duplicate(true),
		"special_slots":special_slots.duplicate(),
		"spice_mix":spice_mix.duplicate(),
		"spice_inventory":spice_inventory.duplicate(true),
		"unlocked_spices":unlocked_spices.duplicate(),
		"move_stone_inventory":move_stone_inventory.duplicate(true),
		"power_stone_inventory":power_stone_inventory.duplicate(true),
		"pending_stew":pending_stew.duplicate(true),
		"completed_stew_result":completed_stew_result.duplicate(true),
		"area_progress":area_progress.duplicate(),
		"selected_roster":selected_roster,
		"selected_team_slot":selected_team_slot,
		"selected_area_index":selected_area_index,
		"selected_level_index":selected_level_index,
		"map_page":map_page,
		"camp_pan_x":camp_pan_x
	}

func save_game(force:=false)->bool:
	if not persistence_enabled and not force:return false
	var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file==null:
		push_warning("Could not open the Quiblets save file (error %d)."%FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(save_data()))
	file.flush()
	return true

func load_game(force:=false)->bool:
	if not persistence_enabled and not force:return false
	if not FileAccess.file_exists(SAVE_PATH):return false
	var file:=FileAccess.open(SAVE_PATH,FileAccess.READ)
	if file==null:return false
	var json:=JSON.new()
	if json.parse(file.get_as_text())!=OK:
		push_warning("The Quiblets save file could not be read; starting fresh.")
		return false
	if not json.data is Dictionary:return false
	var needs_migration:=int(json.data.get("version",0))<3
	apply_save_data(json.data)
	if needs_migration:save_game()
	return not roster.is_empty()

func apply_save_data(data:Dictionary)->void:
	var loaded_roster=data.get("roster",[])
	if loaded_roster is Array:
		roster.clear()
		for saved_value in loaded_roster:
			if not saved_value is Dictionary:continue
			var saved:Dictionary=saved_value
			var species_index:=clampi(int(saved.get("species",0)),0,GameData.SPECIES.size()-1)
			var q:=GameData.make_quiblet(species_index,maxi(1,int(saved.get("level",1))),str(saved.get("nickname","")))
			for key in saved:q[key]=saved[key]
			q.species=species_index;q.level=maxi(1,int(q.level));q.exp=maxi(0,int(q.exp))
			ensure_quiblet_equipment(q)
			roster.append(q)
	var saved_ingredients=data.get("ingredients",{})
	merge_saved_counts(ingredients,saved_ingredients)
	if saved_ingredients is Dictionary:
		if saved_ingredients.has("Cracklecorn") and not saved_ingredients.has("Crystalcorn"):ingredients["Crystalcorn"]=maxi(0,int(saved_ingredients.Cracklecorn))
		if saved_ingredients.has("Ironroot") and not saved_ingredients.has("Oldroot"):ingredients["Oldroot"]=maxi(0,int(saved_ingredients.Ironroot))
	merge_saved_counts(special_items,data.get("special_items",{}))
	leftovers.clear()
	if data.get("leftovers",{}) is Dictionary:
		for key in data.leftovers:leftovers[str(key)]=maxi(0,int(data.leftovers[key]))
	unlocked_ingredients.clear()
	for value in data.get("unlocked_ingredients",[]):
		var ingredient_name:=migrate_ingredient_name(str(value))
		if GameData.INGREDIENTS.has(ingredient_name) and not unlocked_ingredients.has(ingredient_name):unlocked_ingredients.append(ingredient_name)
	# Version 2 temporarily granted four of every ingredient. Version 3 removes
	# that grant once while preserving anything earned beyond those four copies.
	if int(data.get("version",0))==2:
		for ingredient_name in GameData.INGREDIENTS:
			ingredients[ingredient_name]=maxi(0,int(ingredients[ingredient_name])-4)
			if int(ingredients[ingredient_name])==0:unlocked_ingredients.erase(ingredient_name)
	known_recipes.clear()
	for value in data.get("known_recipes",[]):
		var recipe_name:=str(value)
		if GameData.RECIPES.any(func(recipe):return str(recipe.name)==recipe_name) and not known_recipes.has(recipe_name):known_recipes.append(recipe_name)
	load_string_slots(pot_slots,data.get("pot_slots",[]),5)
	for index in pot_slots.size():pot_slots[index]=migrate_ingredient_name(pot_slots[index])
	load_string_slots(special_slots,data.get("special_slots",[]),2)
	spice_slots.clear()
	for value in data.get("spice_slots",[]):
		if spice_slots.size()>=2:break
		spice_slots.append(value.duplicate(true) if value is Dictionary else {})
	while spice_slots.size()<2:spice_slots.append({})
	spice_mix.clear()
	for value in data.get("spice_mix",[]):
		var ingredient_name:=migrate_ingredient_name(str(value))
		if spice_mix.size()<SPICE_MIX_MAX and GameData.INGREDIENTS.has(ingredient_name):spice_mix.append(ingredient_name)
	var saved_spices=data.get("spice_inventory",{})
	if saved_spices is Dictionary:
		for spice_name in spice_inventory:
			var saved_qualities=saved_spices.get(spice_name,{})
			if saved_qualities is Dictionary:
				for quality in spice_inventory[spice_name]:spice_inventory[spice_name][quality]=maxi(0,int(saved_qualities.get(quality,0)))
	unlocked_spices.clear()
	for value in data.get("unlocked_spices",[]):
		var spice_name:=str(value)
		if GameData.SPICES.has(spice_name) and not unlocked_spices.has(spice_name):unlocked_spices.append(spice_name)
	# Older saves recorded no unlock list: any spice already sitting in the
	# inventory has clearly been made before, so treat it as discovered.
	for spice_name in spice_inventory:
		if not unlocked_spices.has(spice_name) and spice_inventory[spice_name].values().any(func(count):return int(count)>0):unlocked_spices.append(spice_name)
	move_stone_inventory.clear()
	for stone in GameData.MOVE_STONES:move_stone_inventory[str(stone.effect)]=0
	var saved_move_stones=data.get("move_stone_inventory",{})
	if saved_move_stones is Dictionary:
		for effect in move_stone_inventory:move_stone_inventory[effect]=maxi(0,int(saved_move_stones.get(effect,0)))
	power_stone_inventory.clear()
	for stone in data.get("power_stone_inventory",[]):
		if stone is Dictionary:power_stone_inventory.append(GameData.normalize_power_stone(stone))
	pending_stew=data.get("pending_stew",{}).duplicate(true) if data.get("pending_stew",{}) is Dictionary else {}
	completed_stew_result=data.get("completed_stew_result",{}).duplicate(true) if data.get("completed_stew_result",{}) is Dictionary else {}
	area_progress.clear()
	for value in data.get("area_progress",[]):
		if area_progress.size()>=GameData.EXPEDITION_AREAS.size():break
		area_progress.append(clampi(int(value),0,8))
	while area_progress.size()<GameData.EXPEDITION_AREAS.size():area_progress.append(0)
	team_indices.clear()
	for value in data.get("team_indices",[]):
		var index:=int(value)
		if index>=0 and index<roster.size() and not team_indices.has(index) and team_indices.size()<5:team_indices.append(index)
	if team_indices.is_empty() and not roster.is_empty():team_indices.append(0)
	selected_roster=clampi(int(data.get("selected_roster",0)),0,maxi(0,roster.size()-1))
	selected_team_slot=clampi(int(data.get("selected_team_slot",0)),0,4)
	selected_area_index=clampi(int(data.get("selected_area_index",0)),0,GameData.EXPEDITION_AREAS.size()-1)
	selected_level_index=clampi(int(data.get("selected_level_index",0)),0,7)
	map_page=clampi(int(data.get("map_page",selected_area_index/AREAS_PER_PAGE)),0,map_page_count()-1)
	camp_pan_x=clampf(float(data.get("camp_pan_x",0.0)),-9.0,9.0)
	rebuild_pot_from_slots()

func merge_saved_counts(target:Dictionary,saved_value:Variant)->void:
	if not saved_value is Dictionary:return
	for key in target:target[key]=maxi(0,int(saved_value.get(key,0)))

func migrate_ingredient_name(value:String)->String:
	if value=="Cracklecorn":return "Crystalcorn"
	if value=="Ironroot":return "Oldroot"
	return value

func load_string_slots(target:Array[String],saved_value:Variant,count:int)->void:
	target.clear()
	if saved_value is Array:
		for value in saved_value:
			if target.size()>=count:break
			target.append(str(value))
	while target.size()<count:target.append("")

func create_starter_roster() -> void:
	# A fresh game begins with a single level-6 Plip and empty stone inventories.
	roster.append(GameData.make_quiblet(0,6))
	team_indices.assign([0])
	for stone in GameData.MOVE_STONES:move_stone_inventory[str(stone.effect)]=0
	power_stone_inventory.clear()

func looping_music(path:String)->AudioStreamWAV:
	var track:=load(path) as AudioStreamWAV
	if track==null:return null
	track=track.duplicate();track.loop_begin=0;track.loop_end=roundi(track.get_length()*track.mix_rate);track.loop_mode=AudioStreamWAV.LOOP_FORWARD
	track.set_meta("source_path",path)
	return track

func one_shot_music(path:String)->AudioStreamWAV:
	var track:=load(path) as AudioStreamWAV
	if track==null:return null
	track=track.duplicate();track.loop_mode=AudioStreamWAV.LOOP_DISABLED;track.loop_begin=0;track.loop_end=0
	track.set_meta("source_path",path)
	return track

func play_expedition_music(stage_kind:String)->void:
	var path:="res://audio/Music/Expedition.wav"
	# Boss levels open on the regular Expedition theme; the Boss theme only
	# starts once the boss has grunted (Expedition3D.boss_fight_started).
	if stage_kind.contains("berry_grove"):path="res://audio/Music/BerryGrove.wav"
	if expedition_music.stream==null or current_expedition_music_path!=path:
		expedition_music.stream=looping_music(path);current_expedition_music_path=path
	expedition_music.volume_db=0.0
	if not expedition_music.playing:expedition_music.play()

func play_boss_music()->void:
	if screen!="expedition":return
	expedition_music.stream=looping_music("res://audio/Music/BossTheme.wav");current_expedition_music_path="res://audio/Music/BossTheme.wav";expedition_music.play()

func restore_stage_music()->void:
	if screen=="expedition" and is_instance_valid(expedition):play_expedition_music(expedition.stage_kind)

func play_quiblet_arrival_music(special:bool)->void:
	var path:="res://audio/Music/GotQuibletSpecial.wav" if special else "res://audio/Music/GotQuiblet.wav"
	quiblet_arrival_music.stop();quiblet_arrival_music.stream=one_shot_music(path);quiblet_arrival_music.set_meta("music_path",path);quiblet_arrival_music.play()

func play_started_cooking_music()->void:
	started_cooking_sequence+=1
	var sequence:=started_cooking_sequence
	started_cooking_music.stop()
	if not base_camp_music.playing:
		base_camp_music.volume_db=0.0
		base_camp_music.play()
	fade_music(base_camp_music,MUSIC_SILENCE_DB,COOKING_MUSIC_FADE_OUT_SECONDS)
	await get_tree().create_timer(COOKING_MUSIC_FADE_OUT_SECONDS).timeout
	if sequence!=started_cooking_sequence:return
	started_cooking_music.play()

func _on_started_cooking_music_finished()->void:
	if not is_base_camp_screen(screen):return
	if not base_camp_music.playing:
		base_camp_music.volume_db=MUSIC_SILENCE_DB
		base_camp_music.play()
	fade_music(base_camp_music,0.0,COOKING_MUSIC_FADE_IN_SECONDS)

func play_base_camp_music()->void:
	if base_camp_music.stream==null:base_camp_music.stream=looping_music("res://audio/Music/BaseCamp.wav")
	base_camp_music.volume_db=0.0
	if not base_camp_music.playing:base_camp_music.play()

func cancel_music_fade(player:AudioStreamPlayer)->void:
	if player==base_camp_music:
		if base_camp_music_fade!=null and base_camp_music_fade.is_valid():base_camp_music_fade.kill()
		base_camp_music_fade=null
	else:
		if expedition_music_fade!=null and expedition_music_fade.is_valid():expedition_music_fade.kill()
		expedition_music_fade=null

func fade_music(player:AudioStreamPlayer,target_db:float,duration:float,stop_after:=false)->void:
	cancel_music_fade(player)
	# Tween audible amplitude, not decibels. A linear dB tween makes the outgoing
	# track become inaudible almost immediately and keeps the incoming track
	# inaudible until the end, which sounds like a delay instead of a crossfade.
	var start_amplitude:=db_to_linear(player.volume_db)
	var target_amplitude:=0.0 if target_db<=MUSIC_SILENCE_DB else db_to_linear(target_db)
	var fade:=create_tween();fade.tween_method(set_music_amplitude.bind(player),start_amplitude,target_amplitude,duration)
	if stop_after:fade.tween_callback(func():player.stop();player.volume_db=0.0)
	if player==base_camp_music:base_camp_music_fade=fade
	else:expedition_music_fade=fade

func set_music_amplitude(amplitude:float,player:AudioStreamPlayer)->void:
	player.volume_db=MUSIC_SILENCE_DB if amplitude<=0.0001 else linear_to_db(amplitude)

func expedition_music_path(stage_kind:String)->String:
	if stage_kind.contains("berry_grove"):return "res://audio/Music/BerryGrove.wav"
	return "res://audio/Music/Expedition.wav"

func transition_to_expedition_music(stage_kind:String)->void:
	var path:=expedition_music_path(stage_kind)
	if base_camp_music.playing:
		if expedition_music.stream==null or current_expedition_music_path!=path:
			expedition_music.stream=looping_music(path);current_expedition_music_path=path
		cancel_music_fade(expedition_music);expedition_music.volume_db=MUSIC_SILENCE_DB
		if not expedition_music.playing:expedition_music.play()
		fade_music(base_camp_music,MUSIC_SILENCE_DB,MUSIC_FADE_SECONDS,true)
		fade_music(expedition_music,0.0,MUSIC_FADE_SECONDS)
	else:play_expedition_music(stage_kind)

func transition_to_base_camp_music(from_silence:=false)->void:
	if expedition_music.playing:
		cancel_music_fade(base_camp_music)
		if not base_camp_music.playing:base_camp_music.volume_db=MUSIC_SILENCE_DB;base_camp_music.play()
		fade_music(expedition_music,MUSIC_SILENCE_DB,MUSIC_FADE_SECONDS,true)
		fade_music(base_camp_music,0.0,MUSIC_FADE_SECONDS)
	elif from_silence:
		cancel_music_fade(base_camp_music);base_camp_music.stop();base_camp_music.volume_db=MUSIC_SILENCE_DB;base_camp_music.play();fade_music(base_camp_music,0.0,MUSIC_FADE_SECONDS)
	else:play_base_camp_music()

func stop_primary_music()->void:
	cancel_music_fade(base_camp_music);cancel_music_fade(expedition_music)
	base_camp_music.stop();base_camp_music.volume_db=0.0
	expedition_music.stop();expedition_music.volume_db=0.0

func is_base_camp_screen(screen_name:String)->bool:
	return screen_name in ["camp","inventory","spice_workshop","cooking","cook_result","recipes","all_quiblets","edit_quiblet","team","training","item_use"]

func is_expedition_music_screen(screen_name:String)->bool:
	return screen_name in ["map","area_levels","expedition","expedition_changes","expedition_haul"]

func show_startup_reveal()->void:
	cancel_music_fade(base_camp_music);base_camp_music.stop();base_camp_music.volume_db=0.0
	startup_overlay=CanvasLayer.new();startup_overlay.name="StartupReveal";startup_overlay.layer=100;add_child(startup_overlay)
	var shade:=ColorRect.new();shade.color=Color("#172e37");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;startup_overlay.add_child(shade)
	var title:=Label.new();title.text="QUIBLETS";title.position=Vector2(240,260);title.size=Vector2(800,150);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",72);title.add_theme_color_override("font_color",Color.WHITE);title.pivot_offset=title.size*.5;title.scale=Vector2.ONE*.65;title.modulate.a=0;shade.add_child(title)
	startup_music.play()
	var tween:=title.create_tween();tween.set_parallel(true);tween.tween_property(title,"modulate:a",1.0,.45);tween.tween_property(title,"scale",Vector2.ONE,.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false);tween.tween_interval(1.35);tween.tween_property(shade,"modulate:a",0.0,.5);tween.tween_callback(func():startup_music.stop();if is_instance_valid(startup_overlay):startup_overlay.queue_free();if is_base_camp_screen(screen):transition_to_base_camp_music(true))

func clear_content() -> void:
	if get_tree().paused:get_tree().paused=false
	reward_pickup_delay=0.0
	expedition_paused=false;pause_overlay=null
	expedition_health_bars.clear()
	for child in content.get_children():content.remove_child(child);child.queue_free()
	var showing_expedition_results:=screen in ["expedition_changes","expedition_haul"]
	if is_instance_valid(expedition) and not showing_expedition_results:expedition.queue_free();expedition=null
	if not is_expedition_music_screen(screen) and not is_base_camp_screen(screen):stop_primary_music()
	if screen!="expedition" and not showing_expedition_results:build_camp_world()

func show_camp() -> void:
	screen = "camp"
	clear_content()
	transition_to_base_camp_music()
	var resources_button:=add_button(content,"🎒  RESOURCES",Vector2(26,26),Vector2(220,62),func():show_resources(),"leaf")
	resources_button.add_theme_font_size_override("font_size",17)
	# The active team sits in one compact row along the bottom center of camp.
	var panel_width:float=team_indices.size()*109.0+130.0
	var team_panel := panel(Rect2((1280.0-panel_width)/2.0,584,panel_width,124),Color("#f4fbf6e8"),18);team_panel.name="CampTeamPanel";content.add_child(team_panel)
	label(team_panel,"%d / 5"%team_indices.size(),Vector2(panel_width-54,4),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,42)
	var edit_team_button:=add_button(team_panel,"EDIT TEAM",Vector2(12,24),Vector2(105,91),func():show_team(),"leaf")
	edit_team_button.add_theme_font_size_override("font_size",13)
	for i in team_indices.size():
		var x := 125+i*109
		var y := 24
		var slot := panel(Rect2(x,y,102,91),Color.WHITE,11)
		team_panel.add_child(slot)
		var q: Dictionary = roster[team_indices[i]]
		label(slot,"Lv. %d"%q.level,Vector2(4,3),9,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,94)
		var p := QuibletPortrait.new(); p.position=Vector2(26,18); p.size=Vector2(50,50); p.setup(int(q.species)); slot.add_child(p)
		label(slot,GameData.display_name(q),Vector2(4,70),11,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,94)
	var expedition_button:=add_button(content,"EXPEDITIONS  ›",Vector2(995,620),Vector2(255,72),func():show_map(),"gold")
	expedition_button.add_theme_font_size_override("font_size",20)

func open_cooking_pot()->void:
	# A sealed pot cannot be opened until its expedition timer has finished.
	if not pending_stew.is_empty():return
	if not completed_stew_result.is_empty():show_cook_result()
	else:show_cooking()

func show_team() -> void:
	show_all_quiblets()

func show_all_quiblets() -> void:
	screen="all_quiblets";clear_content();add_menu_backdrop()
	var team_section:=panel(Rect2(28,68,560,624),Color("#f5faf7f2"),18);content.add_child(team_section);team_section.name="TeamSection"
	label(team_section,team_composition_text(),Vector2(18,10),17,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,524)
	build_team_preview(team_section)
	for slot_index in 5:
		build_team_drop_slot(team_section,slot_index,Vector2(12+slot_index*107,498))
	build_quiblet_side_panels(true)
	add_back_button(content,BACK_BUTTON_POSITION,show_camp)
	selection_pulse_roster=-1

func add_menu_backdrop(color:Color=Color("#e9f3ec"))->ColorRect:
	# Full-screen menus hide the camp diorama behind a flat backdrop.
	var backdrop:=ColorRect.new();backdrop.name="MenuBackdrop";backdrop.color=color;backdrop.position=Vector2.ZERO;backdrop.size=Vector2(1280,720);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(backdrop);return backdrop

func build_quiblet_side_panels(with_training_button:bool)->void:
	var info_section:=panel(Rect2(699,68,460,189),Color("#fffdf7"),18);content.add_child(info_section);info_section.name="QuibletInfo"
	build_quiblet_info(info_section,roster[selected_roster],true)
	if with_training_button:
		var train_backdrop:=panel(Rect2(1170,68,82,82),GameData.COLORS.gold,10);train_backdrop.name="OpenTrainingBackdrop";train_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(train_backdrop)
		var train:=add_texture_button(content,"res://textures/UI/TrainingIcon.png",Vector2(1170,68),Vector2(82,82),show_training,"OpenTrainingButton",.625);train.tooltip_text="Move and EXP training"
	var list_panel:=panel(Rect2(606,275,646,417),Color("#f6f8f6f2"),18);content.add_child(list_panel);list_panel.name="OwnedQuiblets"
	var grid:=GridContainer.new();grid.name="QuibletGrid";grid.position=Vector2(43,14);grid.size=Vector2(560,336);grid.columns=5;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);list_panel.add_child(grid)
	var quiblet_page_count:=maxi(1,ceili(roster.size()/15.0));quiblet_inventory_page=clampi(quiblet_inventory_page,0,quiblet_page_count-1)
	var quiblet_start:=quiblet_inventory_page*15;var quiblet_end:=mini(roster.size(),quiblet_start+15)
	var order:=sorted_roster_indices()
	for position in range(quiblet_start,quiblet_end):build_roster_card(grid,int(order[position]))
	add_page_navigation(list_panel,quiblet_inventory_page,quiblet_page_count,Vector2(145,366),356,set_quiblet_page)

func refresh_quiblet_screen()->void:
	if screen=="training":show_training()
	else:show_all_quiblets()

func build_team_preview(parent:Control)->void:
	var frame:=panel(Rect2(18,42,524,430),Color("#dcefe4"),14);parent.add_child(frame);frame.clip_contents=true
	var container:=SubViewportContainer.new();container.name="TeamPreview3D";container.position=Vector2.ZERO;container.size=frame.size;container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(container)
	var viewport:=SubViewport.new();viewport.size=Vector2i(524,430);viewport.transparent_bg=false;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#dcefe4");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=1.35;environment.environment=env;viewport.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-52,-35,0);light.light_energy=1.4;viewport.add_child(light)
	var stage:=Node3D.new();stage.name="FormationStage";viewport.add_child(stage)
	var ground_mesh:=CylinderMesh.new();ground_mesh.top_radius=5.9;ground_mesh.bottom_radius=5.9;ground_mesh.height=.22;ground_mesh.radial_segments=48
	var ground:=MeshInstance3D.new();ground.mesh=ground_mesh;ground.position.y=-.13;ground.material_override=world_material(Color("#94c785"));stage.add_child(ground)
	team_preview_models.clear()
	var positions:=[Vector3(0,0,-1.15),Vector3(-1.8,0,.05),Vector3(1.8,0,.05),Vector3(-.9,0,1.5),Vector3(.9,0,1.5)]
	for slot_index in team_indices.size():
		var model:=QuibletModel3D.new();model.setup(int(roster[team_indices[slot_index]].species),false,.62);model.position=positions[slot_index];model.rotation.y=0.0;stage.add_child(model)
		var ring:=TEAM_RING_SCRIPT.new();ring.setup(slot_index,1.45);ring.position=positions[slot_index];stage.add_child(ring)
		team_preview_models.append({"model":model,"ring":ring})
	team_preview_camera=Camera3D.new();team_preview_camera.fov=43;viewport.add_child(team_preview_camera);update_team_preview_camera()

func update_team_preview_camera()->void:
	if not is_instance_valid(team_preview_camera):return
	team_preview_camera.position=Vector3(sin(team_preview_angle)*7.1,5.0,cos(team_preview_angle)*7.1);team_preview_camera.look_at(Vector3(0,.55,.3),Vector3.UP)

func build_team_drop_slot(parent:Control,slot_index:int,pos:Vector2)->void:
	var slot:=TEAM_DROP_SLOT_SCRIPT.new();slot.name="TeamSlot%d"%slot_index;slot.position=pos;slot.size=Vector2(96,108);slot.setup(slot_index,team_indices[slot_index] if slot_index<team_indices.size() else -1,self)
	var style:=StyleBoxFlat.new();style.bg_color=Color(TEAM_SLOT_COLORS[slot_index],.35);style.border_color=TEAM_SLOT_COLORS[slot_index];style.set_border_width_all(3);style.set_corner_radius_all(13);slot.add_theme_stylebox_override("panel",style);parent.add_child(slot)
	label(slot,str(slot_index+1),Vector2(5,4),10,TEAM_SLOT_COLORS[slot_index].darkened(.3),true)
	if slot_index<team_indices.size():
		var q:Dictionary=roster[team_indices[slot_index]];var portrait:=QuibletPortrait.new();portrait.position=Vector2(17,9);portrait.size=Vector2(62,66);portrait.setup(int(q.species),.9);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(portrait)
		label(slot,GameData.display_name(q),Vector2(4,80),10,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,88)
	else:label(slot,"DROP HERE",Vector2(4,45),9,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_CENTER,88)
	slot.quiblet_dropped.connect(assign_team_slot);slot.remove_requested.connect(remove_team_slot)

# The owned list runs from the highest level down; Quiblets on the same level
# keep their order of arrival.
func sorted_roster_indices()->Array:
	var order:Array=range(roster.size())
	order.sort_custom(func(a,b):
		if int(roster[a].level)!=int(roster[b].level):return int(roster[a].level)>int(roster[b].level)
		return a<b)
	return order

func build_roster_card(parent:Control,roster_index:int)->void:
	var card:=ROSTER_CARD_SCRIPT.new();card.name="QuibletCard%d"%roster_index;card.custom_minimum_size=Vector2(104,104);card.size=Vector2(104,104)
	# Team members wear their slot colour; every other Quiblet gets a plain white tile with a gray border.
	var team_slot:=team_indices.find(roster_index);var on_team:=team_slot>=0
	var style:=StyleBoxFlat.new();style.bg_color=Color(TEAM_SLOT_COLORS[team_slot],.72) if on_team else Color.WHITE;style.border_color=TEAM_SLOT_COLORS[team_slot].darkened(.15) if on_team else Color("#b9bec4");style.set_border_width_all(2);style.set_corner_radius_all(14);card.add_theme_stylebox_override("panel",style);parent.add_child(card)
	var q:Dictionary=roster[roster_index];var portrait:=QuibletPortrait.new();portrait.position=Vector2(8,3);portrait.size=Vector2(88,78);portrait.setup(int(q.species),1.0);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(portrait)
	label(card,"Lv. %d"%int(q.level),Vector2(4,81),11,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,96)
	card.setup(roster_index,roster_index==selection_pulse_roster);card.chosen.connect(select_roster_quiblet)

func select_roster_quiblet(index:int)->void:
	selected_roster=index;selection_pulse_roster=index;refresh_quiblet_screen()

func set_quiblet_page(page:int)->void:
	quiblet_inventory_page=page;refresh_quiblet_screen()

func build_quiblet_info(parent:Control,q:Dictionary,with_button:bool)->void:
	ensure_quiblet_equipment(q)
	if with_button and parent.size.y<250:
		build_short_quiblet_info(parent,q)
		return
	if with_button and parent.size.x<320:
		build_narrow_quiblet_info(parent,q)
		return
	var portrait_size:=Vector2(145,160) if with_button else Vector2(100,110)
	var portrait:=QuibletPortrait.new();portrait.position=Vector2(14,18);portrait.size=portrait_size;portrait.setup(int(q.species),1.08);parent.add_child(portrait)
	var left:=175.0 if with_button else 126.0
	label(parent,GameData.display_name(q),Vector2(left,24),25 if with_button else 20,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,250)
	var level_y:=67.0 if with_button else 55.0;label(parent,"Lv. %d"%int(q.level),Vector2(left,level_y),13,GameData.COLORS.muted,true)
	var xp:=ProgressBar.new();xp.name="QuibletXPBar";xp.position=Vector2(left,level_y+21);xp.size=Vector2(100 if with_button else 115,18);xp.scale=Vector2(1,.5);xp.max_value=GameData.exp_to_level(int(q.level));xp.value=int(q.exp);xp.show_percentage=false;parent.add_child(xp)
	style_quiblet_xp_bar(xp)
	var separator_y:=108.0 if with_button else 90.0;var separator:=HSeparator.new();separator.position=Vector2(left,separator_y);separator.size=Vector2(250 if with_button else 355,2);parent.add_child(separator)
	if with_button:
		add_quiblet_stat_badge(parent,Vector2(left,120),Vector2(150,34),"res://textures/UI/HealthIcon.png",GameData.max_hp(q),Color("#4b9fda"),"HealthStatBadge")
		add_quiblet_stat_badge(parent,Vector2(left,158),Vector2(150,34),"res://textures/UI/AttackIcon.png",GameData.attack(q),Color("#df5b55"),"AttackStatBadge")
	else:
		add_quiblet_stat_badge(parent,Vector2(500,28),Vector2(150,34),"res://textures/UI/HealthIcon.png",GameData.max_hp(q),Color("#4b9fda"),"HealthStatBadge")
		add_quiblet_stat_badge(parent,Vector2(500,68),Vector2(150,34),"res://textures/UI/AttackIcon.png",GameData.attack(q),Color("#df5b55"),"AttackStatBadge")
	var stat_y:=124.0 if with_button else 92.0
	label(parent,"%s • %s range"%[GameData.species(int(q.species)).element,"long" if is_long_range(q) else "short"],Vector2(18,200) if with_button else Vector2(left+245,stat_y+7),13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,424 if with_button else 205)
	if with_button:add_button(parent,"POWER STONES",Vector2(175,264),Vector2(252,54),show_quiblet_edit,"leaf")

func build_short_quiblet_info(parent:Control,q:Dictionary)->void:
	var portrait:=QuibletPortrait.new();portrait.position=Vector2(12,10);portrait.size=Vector2(132,154);portrait.setup(int(q.species),1.03);parent.add_child(portrait)
	label(parent,GameData.display_name(q),Vector2(154,14),22,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,286)
	label(parent,"Lv. %d"%int(q.level),Vector2(154,52),12,GameData.COLORS.muted,true)
	var xp:=ProgressBar.new();xp.name="QuibletXPBar";xp.position=Vector2(154,72);xp.size=Vector2(116.5,18);xp.scale=Vector2(1,.5);xp.max_value=GameData.exp_to_level(int(q.level));xp.value=int(q.exp);xp.show_percentage=false;parent.add_child(xp)
	style_quiblet_xp_bar(xp)
	var separator:=HSeparator.new();separator.position=Vector2(154,90);separator.size=Vector2(286,2);parent.add_child(separator)
	add_quiblet_stat_badge(parent,Vector2(154,99),Vector2(150,32),"res://textures/UI/HealthIcon.png",GameData.max_hp(q),Color("#4b9fda"),"HealthStatBadge")
	add_quiblet_stat_badge(parent,Vector2(154,137),Vector2(150,32),"res://textures/UI/AttackIcon.png",GameData.attack(q),Color("#df5b55"),"AttackStatBadge")
	add_button(parent,"POWER STONES",Vector2(319,105),Vector2(121,48),show_quiblet_edit,"leaf")

func build_narrow_quiblet_info(parent:Control,q:Dictionary)->void:
	var portrait:=QuibletPortrait.new();portrait.position=Vector2(60,16);portrait.size=Vector2(130,138);portrait.setup(int(q.species),1.08);parent.add_child(portrait)
	label(parent,GameData.display_name(q),Vector2(12,157),23,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,226)
	label(parent,"%s • %s range"%[GameData.species(int(q.species)).element,"long" if is_long_range(q) else "short"],Vector2(12,194),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,226)
	label(parent,"Lv. %d"%int(q.level),Vector2(18,236),13,GameData.COLORS.muted,true)
	var xp:=ProgressBar.new();xp.name="QuibletXPBar";xp.position=Vector2(18,258);xp.size=Vector2(107,21);xp.scale=Vector2(1,.5);xp.max_value=GameData.exp_to_level(int(q.level));xp.value=int(q.exp);xp.show_percentage=false;parent.add_child(xp)
	style_quiblet_xp_bar(xp)
	var separator:=HSeparator.new();separator.position=Vector2(18,311);separator.size=Vector2(214,2);parent.add_child(separator)
	add_quiblet_stat_badge(parent,Vector2(50,333),Vector2(150,34),"res://textures/UI/HealthIcon.png",GameData.max_hp(q),Color("#4b9fda"),"HealthStatBadge")
	add_quiblet_stat_badge(parent,Vector2(50,373),Vector2(150,34),"res://textures/UI/AttackIcon.png",GameData.attack(q),Color("#df5b55"),"AttackStatBadge")
	add_button(parent,"POWER STONES",Vector2(20,548),Vector2(210,54),show_quiblet_edit,"leaf")

func style_quiblet_xp_bar(bar:ProgressBar)->void:
	var fill:=StyleBoxFlat.new();fill.bg_color=Color("#4b9fda");fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill",fill)

func add_quiblet_stat_badge(parent:Control,pos:Vector2,badge_size:Vector2,icon_path:String,value:int,color:Color,node_name:String)->Panel:
	var badge:=Panel.new();badge.name=node_name;badge.position=pos;badge.size=badge_size
	var style:=StyleBoxFlat.new();style.bg_color=color;style.border_color=color.darkened(.15);style.set_border_width_all(1);style.set_corner_radius_all(7);badge.add_theme_stylebox_override("panel",style);parent.add_child(badge)
	var icon:=TextureRect.new();icon.name=node_name+"Icon";icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.custom_minimum_size=Vector2.ZERO;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=load(icon_path);icon.position=Vector2(6,4);icon.size=Vector2(26,badge_size.y-8);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.add_child(icon)
	label(badge,str(value),Vector2(38,5),14,Color.WHITE,true,HORIZONTAL_ALIGNMENT_CENTER,badge_size.x-44).name=node_name+"Value"
	return badge

func assign_team_slot(slot_index:int,roster_index:int)->void:
	if slot_index<0 or slot_index>=5 or roster_index<0 or roster_index>=roster.size():return
	if not pending_team_drag.is_empty() and int(pending_team_drag.get("roster_index",-1))==roster_index:
		pending_team_drag.clear()
	var old_slot:=team_indices.find(roster_index)
	if old_slot==slot_index:return
	if old_slot>=0:
		if slot_index<team_indices.size():
			var replaced:=team_indices[slot_index];team_indices[slot_index]=roster_index;team_indices[old_slot]=replaced
		else:
			team_indices.remove_at(old_slot);team_indices.append(roster_index)
	elif slot_index<team_indices.size():team_indices[slot_index]=roster_index
	else:
		while team_indices.size()<slot_index and team_indices.size()<5:
			# Team slots remain compact; dropping into a later empty socket fills the next one.
			break
		team_indices.append(roster_index)
	selected_roster=roster_index;selection_pulse_roster=roster_index;show_all_quiblets()

func take_team_member_for_drag(slot_index:int,roster_index:int)->Dictionary:
	if slot_index<0 or slot_index>=team_indices.size() or team_indices[slot_index]!=roster_index:return {}
	if team_indices.size()<=1:
		toast("A team needs at least one Quiblet.",GameData.COLORS.coral)
		return {}
	pending_team_drag={"slot_index":slot_index,"roster_index":roster_index}
	return {"kind":"quiblet","roster_index":roster_index}

func finish_team_drag()->void:
	if not pending_team_drag.is_empty():
		var roster_index:=int(pending_team_drag.get("roster_index",-1))
		if team_indices.size()>1:team_indices.erase(roster_index)
		pending_team_drag.clear()
	if screen=="all_quiblets":show_all_quiblets()

func remove_team_slot(slot_index:int)->void:
	if slot_index<0 or slot_index>=team_indices.size():return
	if team_indices.size()<=1:toast("A team needs at least one Quiblet.",GameData.COLORS.coral);return
	team_indices.remove_at(slot_index);show_all_quiblets()

func is_long_range(q:Dictionary)->bool:
	return float(GameData.species(int(q.species)).range)>125.0

func team_composition_text()->String:
	var long_count:=0
	for index in team_indices:
		if is_long_range(roster[index]):long_count+=1
	var short_count:=team_indices.size()-long_count
	var parts:Array[String]=[]
	if long_count>0:parts.append("%d long range"%long_count)
	if short_count>0:parts.append("%d short range"%short_count)
	return " and ".join(parts)+" team"

func ensure_quiblet_equipment(q:Dictionary)->void:
	if not q.has("power_slot_stones"):q.power_slot_stones=[]
	while q.power_slot_stones.size()<16:q.power_slot_stones.append({})
	for index in q.power_slot_stones.size():
		if not q.power_slot_stones[index].is_empty():q.power_slot_stones[index]=GameData.normalize_power_stone(q.power_slot_stones[index])
	# Quiblets saved before the fixed board roll one now from their uid, and any
	# stone sitting in a slot that is locked or mismatched returns to inventory.
	var types:Array=q.get("power_slot_types",[]);var unlocks:Array=q.get("power_slot_unlocks",[])
	var legacy:=types.size()!=16 or unlocks.size()!=16 or types.any(func(value):return not str(value) in ["Attack","Health","Flex"])
	if legacy:
		var board:=GameData.generate_power_board(str(q.get("uid","")))
		q.power_slot_types=board.types;q.power_slot_unlocks=board.unlocks
	else:
		var clean:Array[int]=[]
		for value in unlocks:clean.append(int(value))
		q.power_slot_unlocks=clean
	for index in 16:
		var stone:Dictionary=q.power_slot_stones[index]
		if stone.is_empty():continue
		if not GameData.power_slot_accepts(q,index,str(stone.type)):power_stone_inventory.append(stone);q.power_slot_stones[index]={}

func show_quiblet_edit()->void:
	screen="edit_quiblet";clear_content();add_menu_backdrop();add_back_button(content,BACK_BUTTON_POSITION,show_all_quiblets)
	var q:Dictionary=roster[selected_roster];ensure_quiblet_equipment(q)
	var left:=Control.new();left.position=Vector2(28,68);left.size=Vector2(820,624);content.add_child(left)
	var compact_info:=panel(Rect2(0,0,820,146),Color("#fffdf7"),18);left.add_child(compact_info);build_quiblet_info(compact_info,q,false)
	var equipment_menu:=panel(Rect2(0,160,820,464),Color("#5f5f5f"),16);left.add_child(equipment_menu);equipment_menu.name="StoneEquipmentMenu"
	var move_position:=Vector2(20,4)
	for move_index in q.moves.size():
		var entry:Dictionary=q.moves[move_index]
		var cluster_width:=54.0 if int(entry.slots)==0 else 66.0+(int(entry.slots)-1)*60.0+59.0625
		if move_position.x>20 and move_position.x+cluster_width>equipment_menu.size.x-20:
			move_position=Vector2(20,move_position.y+66)
		build_edit_move_cluster(equipment_menu,entry,move_index,move_position)
		move_position.x+=cluster_width+20
	var power_section_y:=ceili(move_position.y+70) if not q.moves.is_empty() else 8
	var equipment_separator:=HSeparator.new();equipment_separator.position=Vector2(18,power_section_y);equipment_separator.size=Vector2(784,2);equipment_menu.add_child(equipment_separator)
	var power_grid:=Control.new();power_grid.name="PowerStoneGrid";power_grid.size=Vector2(252,252);power_grid.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Fit four equally spaced rows below up to four moves without overflowing.
	var grid_scale:=minf(1.0,(equipment_menu.size.y-power_section_y-24.0)/252.0)
	power_grid.scale=Vector2.ONE*grid_scale;power_grid.position=Vector2(20,power_section_y+12);equipment_menu.add_child(power_grid)
	for slot_index in 16:build_power_slot(power_grid,q,slot_index,Vector2((slot_index%4)*66,(slot_index/4)*66))
	var right:=panel(Rect2(868,68,384,624),Color("#f6f8f6"),18);content.add_child(right);right.name="StoneInventory"
	build_stone_detail(right)
	var separator:=HSeparator.new();separator.position=Vector2(16,164);separator.size=Vector2(352,2);right.add_child(separator)
	build_equipment_inventory(right)

func build_edit_move_cluster(parent:Control,entry:Dictionary,move_index:int,pos:Vector2)->void:
	var icon:=MOVE_ICON_SCRIPT.new();icon.name="EditableMoveIcon%d"%move_index;icon.position=pos;icon.size=Vector2(54,54);icon.setup(str(entry.name),move_index);icon.selected.connect(func(_move_name):show_move_info(entry));icon.move_dropped.connect(swap_quiblet_moves);icon.move_slot_dropped.connect(transfer_move_slot);parent.add_child(icon)
	for stone_slot in int(entry.slots):
		var slot:=EQUIPMENT_SLOT_SCRIPT.new();slot.name="MoveStoneSlot%d_%d"%[move_index,stone_slot];slot.position=pos+Vector2(66+stone_slot*60,0);slot.size=Vector2(59.0625,59.0625);slot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;slot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;slot.texture=move_stone_slot_texture(entry);slot.setup("move",move_index,stone_slot,"",entry,self);parent.add_child(slot)
		if stone_slot<entry.stones.size():add_fitted_move_stone(slot,str(entry.stones[stone_slot]))
		slot.equipment_dropped.connect(equip_stone_from_inventory);slot.remove_requested.connect(remove_equipped_stone)

func show_move_info(entry:Dictionary)->void:
	if entry.is_empty() or not GameData.MOVES.has(entry.name):return
	var shade:=ColorRect.new();shade.name="MoveInfoOverlay";shade.color=Color(0.04,.06,.08,.72);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;shade.z_index=100;content.add_child(shade)
	var menu:=panel(Rect2(350,158,580,404),Color("#fffdf7"),20);menu.name="MoveInfoMenu";shade.add_child(menu)
	add_back_button(menu,menu.size-Vector2(48,48),shade.queue_free,34)
	var large_icon:=MOVE_ICON_SCRIPT.new();large_icon.name="MoveInfoLargeIcon";large_icon.position=Vector2(28,28);large_icon.size=Vector2(128,128);large_icon.setup(str(entry.name));large_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;menu.add_child(large_icon)
	var move:Dictionary=GameData.MOVES[entry.name]
	label(menu,str(entry.name),Vector2(177,31),24,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,330)
	var description:=RichTextLabel.new();description.name="MoveInfoDescription";description.text=str(move.desc);description.position=Vector2(177,75);description.size=Vector2(340,72);description.custom_minimum_size=Vector2.ZERO;description.fit_content=false;description.scroll_active=false;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.mouse_filter=Control.MOUSE_FILTER_IGNORE;description.add_theme_font_size_override("normal_font_size",13);description.add_theme_color_override("default_color",GameData.COLORS.ink);menu.add_child(description)
	label(menu,"Base damage: %d"%int(move.power),Vector2(177,154),13,GameData.COLORS.coral,true,HORIZONTAL_ALIGNMENT_LEFT,160)
	label(menu,"Base cooldown: %.1fs"%float(move.cooldown),Vector2(345,154),13,GameData.COLORS.water,true,HORIZONTAL_ALIGNMENT_LEFT,190)
	var separator:=HSeparator.new();separator.position=Vector2(24,205);separator.size=Vector2(532,2);menu.add_child(separator)
	var supported_index:=0
	for stone in GameData.MOVE_STONES:
		if not stone_compatible(str(stone.effect),entry):continue
		var supported_icon:=TextureRect.new();supported_icon.name="SupportedMoveStoneIcon%d"%supported_index;supported_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;supported_icon.custom_minimum_size=Vector2.ZERO;supported_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;supported_icon.texture=load(stone.texture);supported_icon.position=Vector2(28+(supported_index%8)*66,228+(supported_index/8)*66);supported_icon.size=Vector2(46,46);supported_icon.tooltip_text=str(stone.name);menu.add_child(supported_icon);supported_index+=1

func add_fitted_move_stone(slot:Control,value:String)->void:
	var info:=GameData.stone_info(value)
	if info.is_empty():return
	var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.custom_minimum_size=Vector2.ZERO;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=move_stone_display_texture(value);icon.position=Vector2.ZERO;icon.size=slot.size;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(icon)

func move_stone_display_texture(value:String)->Texture2D:
	if value.begins_with("link_from:"):return load("res://textures/MoveStones/LinkStoneOcupied.png")
	var info:=GameData.stone_info(value)
	return load(info.texture) if not info.is_empty() else null

# Every slot type has an unlocked icon and a grey locked one; Flex shows the
# split Attack/Health mark instead of a question mark.
func power_slot_texture_path(slot_type:String,unlocked:bool)->String:
	if slot_type=="Health":return "res://textures/UI/HealthStoneSlot.png" if unlocked else "res://textures/UI/HealthSlotLocked.png"
	if slot_type=="Attack":return "res://textures/UI/AttackStoneSlot.png" if unlocked else "res://textures/UI/AttackSlotLocked.png"
	if slot_type=="Flex":return "res://textures/UI/FlexSlot.png" if unlocked else "res://textures/UI/FlexSlotLocked.png"
	return ""

var slot_type_texture_cache:={}

# Slot type art cropped to its visible pixels, so the padded Flex mark draws as
# large as the Health and Attack marks that fill their whole canvas.
func slot_type_texture(path:String)->Texture2D:
	if slot_type_texture_cache.has(path):return slot_type_texture_cache[path]
	var texture:Texture2D=load(path);var image:=texture.get_image()
	if image!=null:
		var visible_rect:=image.get_used_rect()
		if visible_rect.size.x>0 and visible_rect.size.y>0 and visible_rect.size!=image.get_size():
			var cropped:=AtlasTexture.new();cropped.atlas=texture;cropped.region=Rect2(visible_rect);texture=cropped
	slot_type_texture_cache[path]=texture;return texture

func slot_backing_style()->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("#4b4b4b");style.set_corner_radius_all(2);style.corner_detail=1;return style

func build_power_cell(parent:Control,q:Dictionary,slot_index:int,pos:Vector2,interactive:bool)->Control:
	# One 54×54 grid cell. An unlocked cell is the slot itself; a locked cell shows
	# only the locked icon at half size, with no rectangle behind it, and (on
	# the next slot to unlock) a square progress outline traced around that icon.
	var slot_type:String=str(q.power_slot_types[slot_index]);var unlocked:=GameData.power_slot_unlocked(q,slot_index)
	var cell:=Panel.new();cell.position=pos;cell.size=Vector2(54,54)
	if unlocked:cell.add_theme_stylebox_override("panel",slot_backing_style())
	else:cell.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	if not interactive:cell.name="ResultPowerSlot%d"%slot_index;cell.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(cell)
	var rect:Control=cell
	if not unlocked:
		# No rectangle behind a locked slot: only the half-size icon, anchored in an invisible 27×27 frame.
		var small:=Control.new();small.name="LockedSlotRect";small.position=Vector2(13.5,13.5);small.size=Vector2(27,27);small.mouse_filter=Control.MOUSE_FILTER_IGNORE;cell.add_child(small);rect=small
	var slot:Control
	if interactive:
		var drop_slot:=EQUIPMENT_SLOT_SCRIPT.new();drop_slot.name="PowerStoneSlot%d"%slot_index;drop_slot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;drop_slot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;drop_slot.locked=not unlocked;drop_slot.setup("power",slot_index,-1,"" if slot_type=="Flex" else slot_type,{},self)
		drop_slot.equipment_dropped.connect(equip_stone_from_inventory);drop_slot.remove_requested.connect(remove_equipped_stone);slot=drop_slot
	else:slot=Control.new();slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	slot.position=Vector2.ZERO;slot.size=rect.size;rect.add_child(slot)
	var texture_path:=power_slot_texture_path(slot_type,unlocked)
	if not texture_path.is_empty():
		var type_icon:=TextureRect.new();type_icon.name="PowerSlotTypeIcon";type_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;type_icon.custom_minimum_size=Vector2.ZERO;type_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;type_icon.texture=slot_type_texture(texture_path);type_icon.size=Vector2(27.5,25) if unlocked else Vector2(13.75,12.5);type_icon.position=(slot.size-type_icon.size)*.5;type_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(type_icon)
	if unlocked and q.power_slot_stones[slot_index] is Dictionary and not q.power_slot_stones[slot_index].is_empty():add_power_stone_icon(slot,q.power_slot_stones[slot_index],Vector2.ZERO,slot.size)
	if not unlocked:
		# Locked slots stay silent: no level tag and no tooltip, only the square progress outline on the next unlock.
		slot.tooltip_text=""
		var next:=GameData.next_power_unlock(q)
		if int(next.index)==slot_index:
			var ring:=UNLOCK_RING_SCRIPT.new();ring.name="UnlockProgressRing";ring.shape="square";ring.size=rect.size+Vector2(6,6);ring.position=rect.position-Vector2(3,3);ring.progress=float(next.progress);cell.add_child(ring)
	return cell

func build_power_slot(parent:Control,q:Dictionary,slot_index:int,pos:Vector2)->void:
	build_power_cell(parent,q,slot_index,pos,true)

func add_power_stone_icon(parent:Node,stone:Dictionary,pos:Vector2,icon_size:Vector2)->Control:
	var icon:=POWER_STONE_ICON_SCRIPT.new();icon.name="PowerStoneIcon";icon.position=pos;icon.size=icon_size;icon.setup(stone);parent.add_child(icon)
	return icon

func power_stone_inventory_data(stone:Dictionary,inventory_index:int)->Dictionary:
	var data:=GameData.normalize_power_stone(stone)
	data.merge({"kind":"power_stone","inventory_index":inventory_index,"stone_type":str(data.type),"display_name":"%s %s Power Stone"%[data.quality,data.type]},true)
	return data

func build_stone_detail(parent:Control)->void:
	if selected_inventory_item.is_empty():
		label(parent,"SELECT A STONE",Vector2(18,22),18,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,348)
		label(parent,"Click a stone below to see what it does.",Vector2(22,61),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,340);return
	var data:=selected_inventory_item;var title:=str(data.get("display_name","Stone"));var title_label:=label(parent,title,Vector2(18,18),18,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,348);title_label.name="StoneDetailTitle"
	if data.kind=="power_stone":
		var stone:=GameData.normalize_power_stone(data)
		add_power_stone_icon(parent,stone,Vector2(18,54),Vector2(76,76))
		label(parent,"T%d • +%d %s"%[stone.tier,stone.power,stone.type],Vector2(106,54),14,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,258)
		var description:=RichTextLabel.new();description.name="PowerStoneBonusDescription";description.position=Vector2(106,80);description.size=Vector2(258,74);description.fit_content=false;description.scroll_active=true;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.add_theme_font_size_override("normal_font_size",11);description.add_theme_color_override("default_color",GameData.COLORS.muted)
		var bonus_lines:Array[String]=[]
		for bonus in stone.bonuses:bonus_lines.append(GameData.bonus_description(bonus))
		description.text="\n".join(bonus_lines) if not bonus_lines.is_empty() else "No bonus stats."
		parent.add_child(description)
		if data.get("fitted",false):
			var fitted_note:=label(parent,"Fitted on %s. Take it off the Quiblet to recycle or rework it."%str(data.get("owner","")),Vector2(18,153),11,GameData.COLORS.berry,true,HORIZONTAL_ALIGNMENT_CENTER,348);fitted_note.name="FittedStoneNote"
		# Only unfitted inventory stones can be recycled; a fitted stone is inspected in place.
		if int(data.get("inventory_index",-1))>=0:
			var recycle:=add_button(parent,"RECYCLE FOR %d INGREDIENTS"%power_stone_recycle_count(stone),Vector2(18,158),Vector2(348,34),func(index=int(data.inventory_index)):request_recycle_power_stone(index),"leaf");recycle.name="RecyclePowerStone"
	else:
		var info:Dictionary=GameData.stone_info(str(data.effect));var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.custom_minimum_size=Vector2.ZERO;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=load(info.texture);icon.position=Vector2(20,54);icon.size=Vector2(50,50);parent.add_child(icon)
		var description:=RichTextLabel.new();description.name="StoneDetailDescription";description.text=str(info.desc);description.position=Vector2(82,53);description.size=Vector2(270,96);description.custom_minimum_size=Vector2.ZERO;description.fit_content=false;description.scroll_active=false;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.add_theme_font_size_override("normal_font_size",11);description.add_theme_color_override("default_color",GameData.COLORS.ink);parent.add_child(description)

# Every owned Power Stone, unfitted and fitted alike, in one order: Health before
# Attack, then stronger first. Fitted entries carry their owner and never an
# inventory index, so lists draw them darker with the owner's portrait and
# nothing can recycle, drag, or rework them until they are taken off.
func all_power_stone_entries()->Array:
	var entries:Array=[]
	for inventory_index in power_stone_inventory.size():
		power_stone_inventory[inventory_index]=GameData.normalize_power_stone(power_stone_inventory[inventory_index])
		entries.append(power_stone_inventory_data(power_stone_inventory[inventory_index],inventory_index))
	for roster_index in roster.size():
		var q:Dictionary=roster[roster_index]
		for slot_index in q.get("power_slot_stones",[]).size():
			var stone=q.power_slot_stones[slot_index]
			if not stone is Dictionary or stone.is_empty():continue
			entries.append(fitted_power_stone_data(stone,roster_index,slot_index))
	entries.sort_custom(func(a,b):
		if a.stone_type!=b.stone_type:return a.stone_type=="Health"
		return int(a.power)>int(b.power))
	return entries

func fitted_power_stone_data(stone:Dictionary,roster_index:int,slot_index:int)->Dictionary:
	var data:=power_stone_inventory_data(stone,-1);data.erase("inventory_index")
	data.merge({"fitted":true,"roster_index":roster_index,"slot_index":slot_index,"owner":GameData.display_name(roster[roster_index]),"species":int(roster[roster_index].species)},true)
	return data

const STONE_GRID_COLUMNS:=4
const STONE_GRID_GAP:=10
const STONE_GRID_WIDTH:=352
const STONE_CARD_HEIGHT:=74

# Inventory cards keep their height and stretch to fill the panel's width.
func stone_card_size()->Vector2:
	return Vector2(floorf((STONE_GRID_WIDTH-(STONE_GRID_COLUMNS-1)*STONE_GRID_GAP)/float(STONE_GRID_COLUMNS)),STONE_CARD_HEIGHT)

func build_equipment_inventory(parent:Control)->void:
	var entries:Array=all_power_stone_entries()
	for stone in GameData.MOVE_STONES:
		var count:=int(move_stone_inventory.get(stone.effect,0))
		for copy_index in count:entries.append({"kind":"move_stone","effect":str(stone.effect),"count":1,"copy_index":copy_index,"display_name":str(stone.name)})
	var page_count:=maxi(1,ceili(entries.size()/16.0));stone_inventory_page=clampi(stone_inventory_page,0,page_count-1)
	var grid:=GridContainer.new();grid.name="StoneIconGrid";grid.position=Vector2(16,182);grid.size=Vector2(STONE_GRID_WIDTH,326);grid.columns=STONE_GRID_COLUMNS;grid.add_theme_constant_override("h_separation",STONE_GRID_GAP);grid.add_theme_constant_override("v_separation",STONE_GRID_GAP);parent.add_child(grid)
	var page_start:=stone_inventory_page*16;var page_end:=mini(entries.size(),page_start+16)
	for entry_index in range(page_start,page_end):add_stone_inventory_card(grid,entries[entry_index])
	if entries.is_empty():label(grid,"No stones owned",Vector2(0,20),13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,STONE_GRID_WIDTH)
	add_page_navigation(parent,stone_inventory_page,page_count,Vector2(14,557),356,set_stone_page)

func add_stone_inventory_card(parent:Control,data:Dictionary)->void:
	var card_size:=stone_card_size();var fitted:bool=data.get("fitted",false)
	var card:=STONE_CARD_SCRIPT.new();card.name="StoneInventoryCard%d"%parent.get_child_count();card.custom_minimum_size=card_size;card.size=card_size;var style:=StyleBoxFlat.new();style.bg_color=Color("#d7dbdd") if fitted else Color.WHITE;style.border_color=Color("#b9c1bc") if fitted else Color("#d4ddd5");style.set_border_width_all(1);style.set_corner_radius_all(11);card.add_theme_stylebox_override("panel",style);parent.add_child(card);card.setup(data);card.chosen.connect(select_inventory_stone)
	if data.kind=="power_stone":
		var icon:=add_power_stone_icon(card,data,Vector2((card_size.x-64)*.5,5),Vector2(64,64))
		if fitted:decorate_fitted_stone_card(card,icon,data)
	else:
		var info:Dictionary=GameData.stone_info(str(data.effect));var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.custom_minimum_size=Vector2.ZERO;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=load(info.texture);icon.position=Vector2((card_size.x-56)*.5,9);icon.size=Vector2(56,56);icon.clip_contents=true;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(icon)

# A fitted stone's card: the stone art darkened and the owner's portrait in the top-right corner.
func decorate_fitted_stone_card(card:Control,icon:Control,data:Dictionary)->void:
	icon.modulate=Color(.5,.5,.55);icon.name="FittedStoneIcon"
	var badge:=Panel.new();badge.name="FittedOwnerBadge";var style:=StyleBoxFlat.new();style.bg_color=Color("#fffdf7");style.border_color=Color("#b9c1bc");style.set_border_width_all(1);style.set_corner_radius_all(12);badge.add_theme_stylebox_override("panel",style);badge.size=Vector2(24,24);badge.position=Vector2(card.size.x-26,2);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.tooltip_text="Fitted on %s"%str(data.get("owner",""));card.add_child(badge)
	var portrait:=QuibletPortrait.new();portrait.position=Vector2(1,1);portrait.size=Vector2(22,22);portrait.setup(int(data.get("species",0)),1.4);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.add_child(portrait)

func set_stone_page(page:int)->void:
	stone_inventory_page=page;show_quiblet_edit()

func add_page_navigation(parent:Control,current_page:int,page_count:int,pos:Vector2,navigation_width:float,callback:Callable)->void:
	var navigation:=Control.new();navigation.name="PageNavigation";navigation.position=pos;navigation.size=Vector2(navigation_width,38);parent.add_child(navigation)
	var back:=add_button(navigation,"‹",Vector2(0,0),Vector2(44,36),func():callback.call(current_page-1),"plain");back.name="PreviousPage";back.disabled=current_page<=0
	var next:=add_button(navigation,"›",Vector2(navigation_width-44,0),Vector2(44,36),func():callback.call(current_page+1),"plain");next.name="NextPage";next.disabled=current_page>=page_count-1
	var dots:=""
	for page_index in page_count:dots+=("●" if page_index==current_page else "○")+("  " if page_index<page_count-1 else "")
	var dots_label:=label(navigation,dots,Vector2(48,8),14,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,int(navigation_width-96));dots_label.name="PageDots"

func select_inventory_stone(data:Dictionary)->void:
	selected_inventory_item=data.duplicate(true);show_quiblet_edit()

# Recycling a Power Stone: one ingredient per tier plus one per bonus stat plus
# one, rolled at the level the stone's tier corresponds to, so a strong or
# well-rolled stone pays back more and rarer ingredients.
func power_stone_recycle_count(stone:Dictionary)->int:
	return int(stone.tier)+int(stone.get("bonus_count",stone.get("bonuses",[]).size()))+1

# Recycling destroys the stone, so it asks first: the dialog names the stone, its
# bonuses, and the ingredient count it pays back.
func request_recycle_power_stone(inventory_index:int)->void:
	if inventory_index<0 or inventory_index>=power_stone_inventory.size():toast("That stone is no longer in the inventory.",GameData.COLORS.coral);return
	if content.find_child("RecycleStoneConfirmation",true,false)!=null:return
	var stone:=GameData.normalize_power_stone(power_stone_inventory[inventory_index])
	var shade:=ColorRect.new();shade.name="RecycleStoneConfirmation";shade.color=Color(0,0,0,.72);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;shade.z_index=100;content.add_child(shade)
	var menu:=panel(Rect2(370,200,540,300),Color("#fffdf7"),20);shade.add_child(menu)
	label(menu,"RECYCLE THIS STONE?",Vector2(30,28),25,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,480)
	add_power_stone_icon(menu,stone,Vector2(42,78),Vector2(64,64))
	label(menu,"%s %s Power Stone • T%d • +%d %s"%[stone.quality,stone.type,int(stone.tier),int(stone.power),"max HP" if stone.type=="Health" else "Attack"],Vector2(118,80),14,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,380)
	var lines:Array[String]=[]
	for bonus in stone.bonuses:lines.append(GameData.bonus_description(bonus))
	label(menu,"; ".join(lines) if not lines.is_empty() else "No bonus stats.",Vector2(118,102),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,380)
	label(menu,"The stone is destroyed and pays back %d ingredients rolled at its tier's level."%power_stone_recycle_count(stone),Vector2(42,160),13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,456)
	var cancel:=add_button(menu,"KEEP IT",Vector2(45,211),Vector2(205,54),shade.queue_free,"plain");cancel.name="CancelRecycleStone"
	var confirm:=add_button(menu,"RECYCLE",Vector2(270,211),Vector2(225,54),func():shade.queue_free();recycle_power_stone(inventory_index),"coral");confirm.name="ConfirmRecycleStone"

func recycle_power_stone(inventory_index:int)->void:
	if inventory_index<0 or inventory_index>=power_stone_inventory.size():toast("That stone is no longer in the inventory.",GameData.COLORS.coral);return
	var stone:=GameData.normalize_power_stone(power_stone_inventory[inventory_index])
	var selected:=selected_inventory_item
	if int(selected.get("inventory_index",-1))!=inventory_index or int(selected.get("power",-1))!=int(stone.power) or str(selected.get("type",""))!=str(stone.type):toast("Select the stone again before recycling it.",GameData.COLORS.coral);return
	power_stone_inventory.remove_at(inventory_index)
	var power_range:Vector2i=GameData.POWER_STONE_RANGES[int(stone.tier)-1];var level:=maxi(1,int((power_range.x+power_range.y)/2)/6)
	var found:Array[String]=[]
	for i in power_stone_recycle_count(stone):
		var ingredient:=GameData.roll_ingredient(level);grant_ingredient(ingredient,1);found.append(ingredient)
	selected_inventory_item={};show_quiblet_edit()
	toast("Recycled the %s %s stone into: %s"%[stone.quality,stone.type,", ".join(found)],GameData.COLORS.leaf)

func equip_stone_from_inventory(kind:String,primary_index:int,secondary_index:int,data:Dictionary)->void:
	var q:Dictionary=roster[selected_roster];ensure_quiblet_equipment(q)
	if kind=="power":
		var inventory_index:=int(data.inventory_index)
		if inventory_index<0 or inventory_index>=power_stone_inventory.size():return
		var stone:=GameData.normalize_power_stone(power_stone_inventory[inventory_index]);var old:Dictionary=q.power_slot_stones[primary_index]
		if not GameData.power_slot_accepts(q,primary_index,str(stone.type)):return
		if not old.is_empty():power_stone_inventory.append(old)
		q.power_slot_stones[primary_index]=stone;power_stone_inventory.remove_at(inventory_index)
		selected_inventory_item.clear();show_quiblet_edit();return
	var effect:=str(data.effect);var entry:Dictionary=q.moves[primary_index]
	if int(move_stone_inventory.get(effect,0))<=0 or not stone_compatible(effect,entry):return
	if effect=="link":
		var placeholder:=Control.new();content.add_child(placeholder);show_link_target_picker(primary_index,placeholder);return
	while entry.stones.size()<=secondary_index:entry.stones.append("")
	var old_effect:=str(entry.stones[secondary_index])
	if not old_effect.is_empty():move_stone_inventory[GameData.stone_effect(old_effect)]=int(move_stone_inventory.get(GameData.stone_effect(old_effect),0))+1
	entry.stones[secondary_index]=effect;move_stone_inventory[effect]-=1;selected_inventory_item.clear();show_quiblet_edit()

const MAX_MOVE_STONE_SLOTS:=8

# Empty Move Stone slots can be dragged between a Quiblet's moves. A move can
# hold at most eight slots, and only a slot with nothing fitted moves.
func move_slot_is_empty(move_index:int,slot_index:int)->bool:
	if selected_roster<0 or selected_roster>=roster.size():return false
	var moves:Array=roster[selected_roster].moves
	if move_index<0 or move_index>=moves.size() or slot_index<0 or slot_index>=int(moves[move_index].slots):return false
	var stones:Array=moves[move_index].stones
	return slot_index>=stones.size() or str(stones[slot_index]).is_empty()

func can_receive_move_slot(move_index:int)->bool:
	if selected_roster<0 or selected_roster>=roster.size():return false
	var moves:Array=roster[selected_roster].moves
	return move_index>=0 and move_index<moves.size() and int(moves[move_index].slots)<MAX_MOVE_STONE_SLOTS

func transfer_move_slot(source_index:int,target_index:int)->void:
	if selected_roster<0 or selected_roster>=roster.size() or source_index==target_index:return
	var moves:Array=roster[selected_roster].moves
	if source_index<0 or source_index>=moves.size() or target_index<0 or target_index>=moves.size():return
	var source:Dictionary=moves[source_index];var target:Dictionary=moves[target_index]
	var empty_slots:Array=range(int(source.slots)).filter(func(slot_index):return move_slot_is_empty(source_index,slot_index))
	if empty_slots.is_empty():toast("%s has no empty Move Stone slot to give."%source.name,GameData.COLORS.coral);return
	if not can_receive_move_slot(target_index):toast("%s already has %d Move Stone slots."%[target.name,MAX_MOVE_STONE_SLOTS],GameData.COLORS.coral);return
	# Drop the last empty slot so fitted stones keep their positions.
	var removed:int=int(empty_slots.back())
	if removed<source.stones.size():source.stones.remove_at(removed)
	source.slots=int(source.slots)-1;target.slots=int(target.slots)+1
	toast("Moved a Move Stone slot from %s to %s."%[source.name,target.name],GameData.COLORS.leaf)
	if screen=="edit_quiblet":show_quiblet_edit()

func take_equipment_for_drag(kind:String,primary_index:int,secondary_index:int)->Dictionary:
	if selected_roster<0 or selected_roster>=roster.size():return {}
	var q:Dictionary=roster[selected_roster];ensure_quiblet_equipment(q)
	if kind=="power":
		if primary_index<0 or primary_index>=q.power_slot_stones.size():return {}
		var stone:Dictionary=q.power_slot_stones[primary_index]
		if stone.is_empty():return {}
		var returned_stone:=GameData.normalize_power_stone(stone)
		q.power_slot_stones[primary_index]={}
		power_stone_inventory.append(returned_stone)
		var source_slot:=content.find_child("PowerStoneSlot%d"%primary_index,true,false)
		if source_slot!=null:
			var fitted_icon:=source_slot.get_node_or_null("PowerStoneIcon")
			if fitted_icon!=null:source_slot.remove_child(fitted_icon);fitted_icon.queue_free()
		return power_stone_inventory_data(returned_stone,power_stone_inventory.size()-1)
	var effect:=detach_fitted_stone(primary_index,secondary_index)
	if effect.is_empty():return {}
	move_stone_inventory[effect]=int(move_stone_inventory.get(effect,0))+1
	refresh_fitted_move_stone_icons()
	return {"kind":"move_stone","effect":effect,"count":1,"display_name":str(GameData.stone_info(effect).name)}

func refresh_fitted_move_stone_icons()->void:
	# Refresh in place: rebuilding the screen here would destroy the active drag
	# source. Also refresh the paired end of a Link Stone and any shifted stones.
	if screen!="edit_quiblet" or not is_instance_valid(content):return
	var moves:Array=roster[selected_roster].moves
	for slot in content.find_children("MoveStoneSlot*","",true,false):
		for child in slot.get_children():slot.remove_child(child);child.queue_free()
		var entry:Dictionary=moves[slot.primary_index]
		if slot.secondary_index<entry.stones.size():add_fitted_move_stone(slot,str(entry.stones[slot.secondary_index]))

func finish_equipment_drag()->void:
	# A Link Stone drop opens a destination picker; keep that picker alive until the
	# player chooses its paired move or cancels it.
	if is_instance_valid(content) and content.find_child("LinkPicker",true,false)!=null:return
	if screen=="edit_quiblet":show_quiblet_edit()

func remove_equipped_stone(kind:String,primary_index:int,secondary_index:int)->void:
	var q:Dictionary=roster[selected_roster]
	if kind=="power":
		var stone:Dictionary=q.power_slot_stones[primary_index]
		if stone.is_empty():return
		power_stone_inventory.append(stone);q.power_slot_stones[primary_index]={}
		show_quiblet_edit();return
	var effect:=detach_fitted_stone(primary_index,secondary_index)
	if effect.is_empty():return
	move_stone_inventory[effect]=int(move_stone_inventory.get(effect,0))+1
	show_quiblet_edit();toast("Move Stone removed.",GameData.COLORS.muted)

func show_legacy_team() -> void:
	screen="team"; clear_content(); make_topbar("TEAM & MOVES","Build a team of one to five. Larger teams spread out naturally and share limited space.",true)
	var roster_panel := panel(Rect2(28,110,330,574),Color("#f8fbf8"),18); content.add_child(roster_panel)
	label(roster_panel,"YOUR QUIBLETS",Vector2(18,16),17,GameData.COLORS.ink,true)
	var list := ScrollContainer.new(); list.position=Vector2(12,52); list.size=Vector2(306,508); roster_panel.add_child(list)
	var vb:=VBoxContainer.new(); vb.custom_minimum_size=Vector2(286,0); vb.add_theme_constant_override("separation",8); list.add_child(vb)
	for i in roster.size():
		var q:Dictionary=roster[i]
		var row:=Button.new(); row.custom_minimum_size=Vector2(286,70); row.text="     %s\n     Lv. %d  •  %s"%[GameData.display_name(q),q.level,GameData.species(int(q.species)).element]; row.alignment=HORIZONTAL_ALIGNMENT_LEFT; style_button(row,"selected" if i==selected_roster else "plain"); row.pressed.connect(func(index=i): selected_roster=index; show_team()); vb.add_child(row)
		var p:=QuibletPortrait.new(); p.position=Vector2(5,4); p.size=Vector2(60,60); p.setup(int(q.species)); row.add_child(p)
	var q:Dictionary=roster[selected_roster]
	var detail:=panel(Rect2(376,110,876,574),Color("#fffdf7"),18); content.add_child(detail)
	var portrait:=QuibletPortrait.new(); portrait.position=Vector2(24,22); portrait.size=Vector2(150,150); portrait.setup(int(q.species),1.05); detail.add_child(portrait)
	label(detail,GameData.display_name(q),Vector2(183,29),30,GameData.COLORS.ink,true)
	label(detail,"%s Quiblet  •  Level %d"%[GameData.species(int(q.species)).element,q.level],Vector2(184,67),16,GameData.COLORS.muted)
	label(detail,"♥ %d     ⚔ %d     Next milestone: Lv. %d"%[GameData.max_hp(q),GameData.attack(q),(int(q.level)/25+1)*25],Vector2(184,101),16,GameData.COLORS.ink)
	var in_team:=team_indices.has(selected_roster)
	add_button(detail,"REMOVE FROM TEAM" if in_team else "ADD TO TEAM",Vector2(183,131),Vector2(190,42),func(): toggle_team_member(selected_roster),"coral" if in_team else "leaf")
	label(detail,"MOVES  •  reorder freely; click ＋ to fit • right-click a stone to remove",Vector2(22,194),15,GameData.COLORS.leaf_dark,true)
	for i in 4:
		var y:=226+i*78
		var move_card:=panel(Rect2(20,y,835,66),Color("#f2f6f1") if i<q.moves.size() else Color("#eeeeeb"),12); detail.add_child(move_card)
		if i<q.moves.size():
			var entry:Dictionary=q.moves[i]; var move:Dictionary=GameData.MOVES[entry.name]
			move_card.tooltip_text=str(move.desc)
			label(move_card,"%d"%(i+1),Vector2(12,18),17,GameData.COLORS.muted,true)
			label(move_card,entry.name,Vector2(46,10),17,GameData.COLORS.ink,true)
			label(move_card,"%s  •  %.1fs  •  range %d"%[move.kind.capitalize(),move.cooldown,int(move.range)],Vector2(46,34),12,GameData.COLORS.muted)
			for s in 6:
				var available:=s<int(entry.slots)
				draw_slot(move_card,Vector2(405+s*42,14),available,entry.stones[s] if s<entry.stones.size() else "",i,s,entry)
			add_button(move_card,"↑",Vector2(674,12),Vector2(42,42),func(idx=i): reorder_move(idx,-1),"plain")
			add_button(move_card,"↓",Vector2(722,12),Vector2(42,42),func(idx=i): reorder_move(idx,1),"plain")
			add_button(move_card,"＋",Vector2(770,12),Vector2(42,42),func(idx=i): show_stone_picker(idx),"plain")
		else: label(move_card,"EMPTY MOVE SLOT",Vector2(20,21),14,GameData.COLORS.muted,true)

func toggle_team_member(index: int) -> void:
	if team_indices.has(index):
		if team_indices.size()<=1: toast("A team needs at least one Quiblet.",GameData.COLORS.coral); return
		team_indices.erase(index)
	else:
		if team_indices.size()>=5: toast("The team is full (5/5).",GameData.COLORS.coral); return
		team_indices.append(index)
	show_team()

func reorder_move(index:int,direction:int)->void:
	var to:=index+direction
	swap_quiblet_moves(index,to)

func swap_quiblet_moves(source_index:int,target_index:int)->void:
	var moves:Array=roster[selected_roster].moves
	if source_index<0 or source_index>=moves.size() or target_index<0 or target_index>=moves.size() or source_index==target_index:return
	var source_entry=moves[source_index];moves[source_index]=moves[target_index];moves[target_index]=source_entry
	if screen=="edit_quiblet":show_quiblet_edit()
	else:show_team()
	toast("Moves swapped — their slots and stones moved with them.",GameData.COLORS.leaf)

func show_stone_picker(move_index:int)->void:
	var entry:Dictionary=roster[selected_roster].moves[move_index]
	if entry.stones.size()>=int(entry.slots): toast("Unlock another Move Stone slot first.",GameData.COLORS.coral); return
	var shade:=ColorRect.new();shade.name="StonePicker";shade.color=Color(0.07,.1,.12,.62);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;content.add_child(shade)
	var picker:=panel(Rect2(95,78,1090,590),Color("#fffdf7"),22);shade.add_child(picker)
	label(picker,"CHOOSE A MOVE STONE",Vector2(24,18),23,GameData.COLORS.ink,true)
	label(picker,"%s • slot %d of %d"%[entry.name,entry.stones.size()+1,entry.slots],Vector2(24,50),13,GameData.COLORS.muted)
	add_button(picker,"CLOSE",Vector2(946,18),Vector2(120,42),func():shade.queue_free(),"plain")
	for i in GameData.MOVE_STONES.size():
		var stone:Dictionary=GameData.MOVE_STONES[i];var x:=22+(i%4)*263;var y:=88+(i/4)*118
		var compatible:=stone_compatible(stone.effect,entry)
		var card:=panel(Rect2(x,y,246,102),Color.WHITE if compatible else Color("#e8e8e5"),12);picker.add_child(card)
		var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2.ZERO;icon.texture=load(stone.texture);icon.position=Vector2(10,11);icon.size=Vector2(58,58);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(icon)
		label(card,stone.name,Vector2(76,10),15,GameData.COLORS.ink if compatible else GameData.COLORS.muted,true)
		label(card,stone.desc,Vector2(76,34),10,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,154)
		var choose:=Button.new();choose.flat=true;choose.position=Vector2.ZERO;choose.size=card.size;choose.disabled=not compatible;choose.tooltip_text=stone.desc;choose.pressed.connect(_on_stone_chosen.bind(move_index,str(stone.effect),shade));card.add_child(choose)

func _on_stone_chosen(move_index:int,effect:String,shade:Control)->void:
	if effect=="link":show_link_target_picker(move_index,shade)
	else:fit_stone(move_index,effect)

func stone_compatible(effect:String,entry:Dictionary)->bool:
	if effect=="link":return roster[selected_roster].moves.size()>1 and not entry.stones.any(func(value):return str(value).begins_with("link:"))
	return preload("res://scripts/move_behaviors.gd").supports(entry.name,effect)

func show_link_target_picker(source_index:int,old_picker:Control)->void:
	old_picker.queue_free()
	var shade:=ColorRect.new();shade.name="LinkPicker";shade.color=Color(0.07,.1,.12,.62);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;content.add_child(shade)
	var picker:=panel(Rect2(320,180,640,350),Color("#fffdf7"),20);shade.add_child(picker)
	var moves:Array=roster[selected_roster].moves
	label(picker,"LINK %s TO…"%moves[source_index].name,Vector2(22,18),21,GameData.COLORS.ink,true)
	label(picker,"The destination also needs one open Move Stone slot.",Vector2(22,51),13,GameData.COLORS.muted)
	var y:=90
	for i in moves.size():
		if i==source_index:continue
		var target:Dictionary=moves[i];var open:bool=target.stones.size()<int(target.slots) and can_link_moves(source_index,i)
		var reason:="  •  would create a loop" if not can_link_moves(source_index,i) else "  •  no open slot"
		var button:=add_button(picker,"%s%s"%[target.name,reason if not open else ""],Vector2(24,y),Vector2(592,48),func(target_index=i):fit_link(source_index,target_index),"plain")
		button.disabled=not open;y+=58
	add_button(picker,"CANCEL",Vector2(450,292),Vector2(166,40),func():cancel_link_picker(shade),"plain")

func cancel_link_picker(shade:Control)->void:
	if is_instance_valid(shade):shade.queue_free()
	if screen=="edit_quiblet":show_quiblet_edit()

func fit_stone(move_index:int,effect:String)->void:
	var entry:Dictionary=roster[selected_roster].moves[move_index]
	if entry.stones.size()>=int(entry.slots):return
	entry.stones.append(effect);show_team();toast("%s fitted to %s."%[GameData.stone_info(effect).name,entry.name],GameData.COLORS.gold)

func fit_link(source_index:int,target_index:int)->void:
	if not can_link_moves(source_index,target_index):return
	var moves:Array=roster[selected_roster].moves;var source:Dictionary=moves[source_index];var target:Dictionary=moves[target_index]
	if source.stones.size()>=int(source.slots) or target.stones.size()>=int(target.slots):return
	source.stones.append("link:"+str(target.name));target.stones.append("link_from:"+str(source.name))
	if int(move_stone_inventory.get("link",0))>0:move_stone_inventory["link"]-=1
	if screen=="edit_quiblet":show_quiblet_edit()
	else:show_team()
	toast("Linked %s → %s."%[source.name,target.name],Color.WHITE)

func can_link_moves(source_index:int,target_index:int)->bool:
	var moves:Array=roster[selected_roster].moves
	if source_index==target_index or source_index<0 or target_index<0 or source_index>=moves.size() or target_index>=moves.size():return false
	if moves[source_index].stones.any(func(value):return str(value).begins_with("link:")):return false
	var seen:Array=[source_index];var current:=target_index
	while current>=0:
		if seen.has(current):return false
		seen.append(current);var next_name:=""
		for value in moves[current].stones:
			if str(value).begins_with("link:"):next_name=str(value).trim_prefix("link:");break
		current=-1
		for i in moves.size():
			if moves[i].name==next_name:current=i;break
	return true

func remove_fitted_stone(move_index:int,stone_index:int)->void:
	var effect:=detach_fitted_stone(move_index,stone_index)
	if effect.is_empty():return
	if screen=="edit_quiblet":show_quiblet_edit()
	else:show_team()
	toast("Move Stone removed.",GameData.COLORS.muted)

func detach_fitted_stone(move_index:int,stone_index:int)->String:
	var moves:Array=roster[selected_roster].moves
	if move_index<0 or move_index>=moves.size():return ""
	var entry:Dictionary=moves[move_index]
	if stone_index<0 or stone_index>=entry.stones.size():return ""
	var value:String=entry.stones[stone_index]
	if value.is_empty():return ""
	if value.begins_with("link:"):
		var target_name:=value.trim_prefix("link:")
		for target in moves:
			if target.name==target_name:target.stones.erase("link_from:"+str(entry.name))
	elif value.begins_with("link_from:"):
		var source_name:=value.trim_prefix("link_from:")
		for source in moves:
			if source.name==source_name:source.stones.erase("link:"+str(entry.name))
	entry.stones.remove_at(stone_index)
	return GameData.stone_effect(value)

func show_resources() -> void:
	screen="inventory"; clear_content(); make_topbar("RESOURCES & TREASURE","Everything you own is visible without needing an empty cooking pot.",true)
	var left:=panel(Rect2(30,112,585,565),Color("#fffaf0"),18); content.add_child(left)
	label(left,"INGREDIENTS",Vector2(22,19),18,GameData.COLORS.ink,true)
	label(left,"Tap Cook to use these in a deterministic recipe.",Vector2(22,48),14,GameData.COLORS.muted)
	var keys:=GameData.INGREDIENTS.keys()
	var ingredient_scroll:=ScrollContainer.new();ingredient_scroll.position=Vector2(16,78);ingredient_scroll.size=Vector2(552,398);left.add_child(ingredient_scroll)
	var ingredient_grid:=Control.new();ingredient_grid.custom_minimum_size=Vector2(532,ceili(keys.size()/2.0)*100);ingredient_scroll.add_child(ingredient_grid)
	for i in keys.size():
		var name:String=keys[i]; var info:Dictionary=GameData.INGREDIENTS[name]; var x:=(i%2)*266; var y:=(i/2)*100
		var card:=panel(Rect2(x,y,250,82),Color.WHITE,12);card.clip_contents=true;ingredient_grid.add_child(card)
		if unlocked_ingredients.has(name):
			var resource_icon:=add_ingredient_icon(card,info,Vector2(10,10),Vector2(40,54),28);resource_icon.name="ResourceIngredientIcon"
			label(card,name,Vector2(52,13),15,GameData.COLORS.ink,true)
			label(card,"× %d"%ingredients[name],Vector2(52,39),19,info.color,true)
			label(card,ingredient_tag_text(info),Vector2(128,43),10,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,112)
		else:
			var unknown_icon:=Control.new();unknown_icon.name="ResourceIngredientIcon";unknown_icon.position=Vector2(10,10);unknown_icon.size=Vector2(40,54);card.add_child(unknown_icon)
			label(unknown_icon,"?",Vector2.ZERO,28,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_CENTER,40)
			label(card,"Unknown",Vector2(52,13),15,GameData.COLORS.muted,true)
			label(card,"× 0",Vector2(52,39),19,GameData.COLORS.muted,true)
	add_button(left,"SPICE WORKSHOP",Vector2(20,493),Vector2(260,50),func():show_spice_workshop(),"gold")
	add_button(left,"GO TO COOKING",Vector2(290,493),Vector2(275,50),open_cooking_pot,"leaf")
	var right:=panel(Rect2(635,112,615,565),Color("#f7f3ff"),18); content.add_child(right)
	label(right,"SPECIAL ITEMS",Vector2(22,19),18,GameData.COLORS.ink,true)
	var desc:Dictionary=SPECIAL_ITEM_DESCRIPTIONS
	var scroll:=ScrollContainer.new(); scroll.position=Vector2(16,58); scroll.size=Vector2(582,436); right.add_child(scroll)
	var workshop_button:=add_button(right,"STONE WORKSHOP  •  combine, revitalize, convert, reforge",Vector2(16,504),Vector2(582,44),func():show_stone_workshop(),"gold");workshop_button.name="OpenStoneWorkshop"
	var vb:=VBoxContainer.new(); vb.custom_minimum_size=Vector2(560,0); vb.add_theme_constant_override("separation",7); scroll.add_child(vb)
	# Leftover jars are stored per recipe; they live here beside the special items
	# so a filled jar is visible right after cooking, not only in the Recipe Journal.
	for recipe in GameData.RECIPES:
		var stored:int=int(leftovers.get(recipe.name,0))
		if stored<=0:continue
		var jar:=panel(Rect2(0,0,560,55),Color("#fff8e7"),10);jar.custom_minimum_size=Vector2(560,55);vb.add_child(jar);jar.name="LeftoverRow"
		label(jar,"%s Leftovers"%recipe.name,Vector2(14,8),14,recipe.color,true);label(jar,"Reinvest when cooking %s again for better precision, or recycle for ingredients."%recipe.name,Vector2(14,29),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,395);label(jar,"× %d"%stored,Vector2(496,15),16,GameData.COLORS.berry,true)
		var recycle:=add_button(jar,"RECYCLE",Vector2(390,12),Vector2(96,31),func(r=recipe):recycle_leftover(r),"leaf");recycle.name="RecycleLeftovers"
	for item in special_items:
		var row:=panel(Rect2(0,0,560,55),Color.WHITE,10); row.custom_minimum_size=Vector2(560,55); vb.add_child(row);row.name="SpecialItemRow"
		var hint:String=(" (%s)"%SPECIAL_ITEM_USAGE[item]) if SPECIAL_ITEM_USAGE.has(item) else ""
		label(row,item,Vector2(14,8),14,GameData.COLORS.ink,true); label(row,str(desc[item])+hint,Vector2(14,29),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,395); label(row,"× %d"%special_items[item],Vector2(496,15),16,GameData.COLORS.berry,true)
		if item_use_screen_supported(item):
			var use:=add_button(row,"USE",Vector2(414,12),Vector2(72,31),func(name=item):show_item_use(name),"gold");use.name="UseSpecialItem";use.disabled=int(special_items[item])<=0

func show_spice_workshop()->void:
	screen="spice_workshop";clear_content();make_topbar("SPICE WORKSHOP","Drag up to five resources into the bowl; better resources create stronger seasoning.",false)
	var workbench:=panel(Rect2(30,112,560,565),Color("#fffaf0"),18);content.add_child(workbench)
	label(workbench,"MIXING BOWL",Vector2(22,16),18,GameData.COLORS.ink,true)
	label(workbench,"Drag resources in from the right. Drag one back out to remove it.",Vector2(22,42),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,516)
	for i in SPICE_MIX_MAX:
		var slot:=SPICE_MIX_SLOT_SCRIPT.new();slot.name="SpiceMixSlot%d"%i;slot.position=Vector2(20+i*106,64);slot.size=Vector2(100,112);workbench.add_child(slot);slot.setup(self,i,spice_mix[i] if i<spice_mix.size() else "")
	var result:=GameData.choose_spice(spice_mix) if not spice_mix.is_empty() else {};var quality:=GameData.spice_quality(spice_mix) if not spice_mix.is_empty() else "basic"
	var preview:=panel(Rect2(20,192,520,104),spice_quality_color(quality).lightened(.68) if not result.is_empty() else Color("#eeeeea"),14);preview.name="SpicePreview";workbench.add_child(preview)
	if result.is_empty():
		label(preview,"NO SEASONING YET",Vector2(16,20),17,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_CENTER,488);label(preview,"Fill the bowl with a matching combination of resources.",Vector2(16,55),13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,488)
	else:
		var spice_info:Dictionary=GameData.SPICES[result.name];label(preview,spice_info.icon,Vector2(20,26),36,spice_info.color);label(preview,"%s %s"%[quality.capitalize(),result.name],Vector2(78,18),19,GameData.COLORS.ink,true);label(preview,"Favors %s"%spice_info.favors,Vector2(78,50),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,430);label(preview,"Requires %s"%requirement_text(spice_recipe_need(result.name)),Vector2(78,72),11,GameData.COLORS.berry,false,HORIZONTAL_ALIGNMENT_LEFT,430)
	var craft:=add_button(workbench,"CRAFT SEASONING",Vector2(20,312),Vector2(520,54),func():craft_spice(),"gold");craft.name="CraftSeasoning";craft.disabled=result.is_empty()
	label(workbench,"QUALITY",Vector2(22,386),14,GameData.COLORS.ink,true)
	label(workbench,"Basic  →  Good  →  Great  →  Special",Vector2(22,414),17,GameData.COLORS.berry,true)
	label(workbench,"Quality depends on the average resource tier. Higher quality creates a\nmuch stronger attraction bias and a larger arrival stat bonus.",Vector2(22,448),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,510)
	add_back_button(content,BACK_BUTTON_POSITION,func():clear_spice_mix(true);show_resources())
	# Selected ingredient information, mirroring the cooking menu's info panel.
	var info_panel:=panel(Rect2(610,112,640,96),Color("#fffaf0"),14);info_panel.clip_contents=true;info_panel.name="SpiceItemInfo";content.add_child(info_panel)
	if selected_cooking_ingredient.is_empty() or not GameData.INGREDIENTS.has(selected_cooking_ingredient):
		label(info_panel,"INGREDIENT INFO",Vector2(17,13),15,GameData.COLORS.ink,true);label(info_panel,"Click any unlocked resource below to learn about it.",Vector2(17,46),13,GameData.COLORS.muted)
	else:
		var selected_info:Dictionary=GameData.INGREDIENTS[selected_cooking_ingredient];var selected_icon:=add_ingredient_icon(info_panel,selected_info,Vector2(14,12),Vector2(48,66),38);selected_icon.name="SelectedIngredientIcon";label(info_panel,selected_cooking_ingredient,Vector2(73,8),18,GameData.COLORS.ink,true);label(info_panel,"%s • tier %d • ×%d"%[ingredient_tag_text(selected_info),int(selected_info.tier),int(ingredients.get(selected_cooking_ingredient,0))],Vector2(73,36),13,Color.BLACK);label(info_panel,selected_info.feel,Vector2(73,61),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,549)
	# Draggable resource catalogue.
	var catalogue:=panel(Rect2(610,220,640,200),Color("#f7f7f7"),16);content.add_child(catalogue)
	label(catalogue,"RESOURCES",Vector2(18,12),15,GameData.COLORS.ink,true)
	var ingredient_grid:=GridContainer.new();ingredient_grid.name="SpiceIngredientGrid";ingredient_grid.position=Vector2(14,38);ingredient_grid.size=Vector2(612,150);ingredient_grid.columns=8;ingredient_grid.add_theme_constant_override("h_separation",8);ingredient_grid.add_theme_constant_override("v_separation",8);catalogue.add_child(ingredient_grid)
	for ingredient_name in GameData.INGREDIENTS:
		var card:=IngredientDragCard.new();card.custom_minimum_size=Vector2(67,82);ingredient_grid.add_child(card);card.setup(self,ingredient_name,unlocked_ingredients.has(ingredient_name),1)
	# Seasoning guide: every spice, but only ones crafted before show their details.
	var guide:=panel(Rect2(610,430,640,247),Color("#f4f7fb"),18);content.add_child(guide)
	label(guide,"SEASONING GUIDE",Vector2(18,12),15,GameData.COLORS.ink,true)
	var spice_names:=GameData.SPICES.keys()
	for i in spice_names.size():
		var spice_name:String=spice_names[i];var spice_info:Dictionary=GameData.SPICES[spice_name];var known:=unlocked_spices.has(spice_name)
		var x:=16+(i%2)*310;var y:=42+(i/2)*50
		var row:=panel(Rect2(x,y,300,46),Color.WHITE,9);row.name="SpiceGuideRow%d"%i;guide.add_child(row)
		if known:
			label(row,spice_info.icon,Vector2(8,6),20,spice_info.color)
			label(row,spice_name,Vector2(38,4),13,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,254)
			label(row,"Requires "+requirement_text(spice_recipe_need(spice_name)),Vector2(38,24),9,GameData.COLORS.berry,false,HORIZONTAL_ALIGNMENT_LEFT,254)
		else:
			label(row,"?",Vector2(8,6),20,GameData.COLORS.muted)
			label(row,"???",Vector2(38,4),13,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_LEFT,254)
			label(row,"Requires ???",Vector2(38,24),9,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,254)

# The tag requirements of the recipe that produces a given spice.
func spice_recipe_need(spice_name:String)->Dictionary:
	for recipe in GameData.SPICE_RECIPES:
		if str(recipe.name)==spice_name:return recipe.need
	return {}

# True when one more of this ingredient can be placed: it is unlocked, the bowl
# has room, and at least one is still in inventory.
func can_place_spice_ingredient(ingredient_name:String,slot_index:int)->bool:
	if not unlocked_ingredients.has(ingredient_name):return false
	if int(ingredients.get(ingredient_name,0))<=0:return false
	if slot_index<spice_mix.size():return false  # occupied slots are replaced only after a detach
	return spice_mix.size()<SPICE_MIX_MAX

# Consume one from inventory and add it to the bowl (slots fill left to right).
func place_spice_ingredient(_slot_index:int,ingredient_name:String)->void:
	if not can_place_spice_ingredient(ingredient_name,spice_mix.size()):return
	ingredients[ingredient_name]-=1;spice_mix.append(ingredient_name);selected_cooking_ingredient=ingredient_name;selected_cooking_item={};show_spice_workshop()

# Remove the ingredient at a bowl slot, refund it, and hand it to the drag.
func detach_spice_ingredient_for_drag(slot_index:int)->Dictionary:
	if slot_index<0 or slot_index>=spice_mix.size():return {}
	var ingredient_name:=spice_mix[slot_index]
	ingredients[ingredient_name]=int(ingredients.get(ingredient_name,0))+1;spice_mix.remove_at(slot_index)
	return {"kind":"ingredient","name":ingredient_name}

# Empty the bowl, optionally refunding everything to inventory.
func clear_spice_mix(refund:=true)->void:
	if refund:
		for ingredient_name in spice_mix:ingredients[ingredient_name]=int(ingredients.get(ingredient_name,0))+1
	spice_mix.clear()

func finish_spice_mix_drag()->void:
	if screen=="spice_workshop" and is_instance_valid(content):show_spice_workshop()

func craft_spice()->void:
	# Ingredients were already consumed as they were dragged in, so crafting only
	# checks that the current mixture makes a known seasoning, then banks it.
	if spice_mix.is_empty():return
	var recipe:=GameData.choose_spice(spice_mix)
	if recipe.is_empty():toast("That combination does not make a known seasoning.",GameData.COLORS.coral);return
	var quality:=GameData.spice_quality(spice_mix)
	var newly_unlocked:bool=not unlocked_spices.has(recipe.name)
	if newly_unlocked:unlocked_spices.append(recipe.name)
	spice_inventory[recipe.name][quality]+=1;spice_mix.clear();selected_cooking_ingredient="";show_spice_workshop()
	toast(("Discovered %s %s!" if newly_unlocked else "Crafted %s %s!")%[quality.capitalize(),recipe.name],spice_quality_color(quality))

func show_cooking() -> void:
	if not completed_stew_result.is_empty():show_cook_result();return
	screen="cooking";clear_content()
	var white:=ColorRect.new();white.color=Color.WHITE;white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);white.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(white)
	var pot_texture:=TextureRect.new();pot_texture.name="CookingPotTexture";pot_texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pot_texture.texture=load("res://textures/UI/CookingPot.png");pot_texture.position=Vector2(44,82);pot_texture.size=Vector2.ONE*COOKING_POT_DISPLAY_SIZE;pot_texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;pot_texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(pot_texture)
	var special_rects:=[Rect2(184,184,64,64),Rect2(264,184,64,64)]
	var spice_rects:=[Rect2(184,264,64,64),Rect2(264,264,64,64)]
	var ingredient_rects:=[Rect2(72,336,64,64),Rect2(148,336,64,64),Rect2(224,336,64,64),Rect2(300,336,64,64),Rect2(376,336,64,64)]
	# Slot rectangles are authored against the 512×512 display layout and remain
	# independent of the source texture's pixel resolution.
	var scale_factor:=COOKING_POT_DISPLAY_SIZE/COOKING_POT_REFERENCE_SIZE
	for i in special_rects.size():
		var source_rect:Rect2=special_rects[i];var slot:=PotDropSlot.new();slot.position=pot_texture.position+source_rect.position*scale_factor;slot.size=source_rect.size*scale_factor;content.add_child(slot);slot.setup(self,i,"special",special_slots[i])
	for i in spice_rects.size():
		var source_rect:Rect2=spice_rects[i];var slot:=PotDropSlot.new();slot.position=pot_texture.position+source_rect.position*scale_factor;slot.size=source_rect.size*scale_factor;content.add_child(slot);slot.setup(self,i,"spice",spice_slots[i])
	for i in ingredient_rects.size():
		var source_rect:Rect2=ingredient_rects[i];var slot:=PotDropSlot.new();slot.position=pot_texture.position+source_rect.position*scale_factor;slot.size=source_rect.size*scale_factor;content.add_child(slot);slot.setup(self,i,"ingredient",pot_slots[i])
	var total:=pot_total();var recipe:=GameData.choose_recipe(pot)
	# Predicted result sits in the middle of the pot texture's lid: "---" below five
	# ingredients, "???" until that stew has been discovered, otherwise its name.
	var predicted_text:String="---" if total<5 else (str(recipe.name) if (recipe.name=="Plain Stew" or known_recipes.has(recipe.name)) else "???")
	var predicted:=label(content,"Predicted Result: "+predicted_text,pot_texture.position+Vector2(56,80)*scale_factor,15,Color.WHITE,true,HORIZONTAL_ALIGNMENT_CENTER,int(400*scale_factor));predicted.name="PredictedResult";predicted.mouse_filter=Control.MOUSE_FILTER_IGNORE;predicted.z_index=5
	var start_text:="START COOKING"
	if not pending_stew.is_empty():
		var remaining:=int(pending_stew.expeditions_remaining)
		start_text="%d EXPEDITION%s LEFT"%[remaining,"" if remaining==1 else "S"]
	var start:=add_button(content,start_text,Vector2(128,612),Vector2(340,62),request_start_cooking,"gold");start.disabled=total<5 or not pending_stew.is_empty();start.add_theme_font_size_override("font_size",18)
	# Recipe browser: one stew at a time, stepped with the up/down arrows; the
	# stew's number sits in the top-left, and undiscovered stews show "???".
	var recipes_panel:=panel(Rect2(624,18,626,148),Color("#f4f7fb"),16);recipes_panel.name="RecipeBrowser";content.add_child(recipes_panel)
	cooking_recipe_index=wrapi(cooking_recipe_index,0,GameData.RECIPES.size())
	var shown_recipe:Dictionary=GameData.RECIPES[cooking_recipe_index];var discovered:bool=shown_recipe.name=="Plain Stew" or known_recipes.has(shown_recipe.name)
	label(recipes_panel,"#%d"%(cooking_recipe_index+1),Vector2(14,10),12,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_LEFT,40).name="RecipeNumber"
	label(recipes_panel,str(shown_recipe.name) if discovered else "???",Vector2(52,6),18,shown_recipe.color if discovered else GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_LEFT,510).name="RecipeName"
	label(recipes_panel,"REQUIRES",Vector2(18,42),10,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_LEFT,270)
	label(recipes_panel,requirement_text(shown_recipe.need) if discovered else "???",Vector2(18,58),12,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_LEFT,272).name="RecipeRequires"
	label(recipes_panel,"ATTRACTS",Vector2(300,42),10,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_LEFT,270)
	label(recipes_panel,recipe_attracts_text(shown_recipe) if discovered else "???",Vector2(300,58),12,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_LEFT,270).name="RecipeAttracts"
	label(recipes_panel,str(shown_recipe.desc) if discovered else "Discover this stew by cooking the right combination.",Vector2(18,112),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,552).name="RecipeDescription"
	add_button(recipes_panel,"▲",Vector2(578,22),Vector2(36,36),func():step_cooking_recipe(-1),"plain").name="RecipePrevious"
	add_button(recipes_panel,"▼",Vector2(578,90),Vector2(36,36),func():step_cooking_recipe(1),"plain").name="RecipeNext"
	# Selected ingredient information.
	var info_panel:=panel(Rect2(624,181,626,98),Color("#fffaf0"),14);info_panel.clip_contents=true;info_panel.name="CookingItemInfo";content.add_child(info_panel)
	if not selected_cooking_item.is_empty():
		if selected_cooking_item.kind=="spice":
			var spice_name:=str(selected_cooking_item.name);var quality:=str(selected_cooking_item.quality);var spice_info:Dictionary=GameData.SPICES.get(spice_name,{})
			label(info_panel,str(spice_info.get("icon","✦")),Vector2(18,14),40,spice_quality_color(quality),false,HORIZONTAL_ALIGNMENT_CENTER,48)
			label(info_panel,"%s (%s)"%[spice_name,quality.capitalize()],Vector2(73,8),18,GameData.COLORS.ink,true).name="SelectedItemName"
			label(info_panel,"Favors %s • bias ×%.2f"%[str(spice_info.get("favors","matching Quiblets")),spice_strength(quality)],Vector2(73,36),13,Color.BLACK)
			label(info_panel,"Arrival keeps %s. Spices bias which eligible Quiblet arrives from the finished stew."%GameData.spice_stat_text(spice_name,quality),Vector2(73,61),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,535)
		else:
			var special_id:=str(selected_cooking_item.id);var display:=cooking_slot_display("special",special_id)
			label(info_panel,str(display.icon),Vector2(18,14),40,display.color,false,HORIZONTAL_ALIGNMENT_CENTER,48)
			label(info_panel,special_id.trim_prefix("Leftovers:")+(" Leftovers" if special_id.begins_with("Leftovers:") else ""),Vector2(73,8),18,GameData.COLORS.ink,true).name="SelectedItemName"
			label(info_panel,special_item_description(special_id),Vector2(73,40),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,535)
	elif selected_cooking_ingredient.is_empty():
		label(info_panel,"INGREDIENT INFO",Vector2(17,13),15,GameData.COLORS.ink,true);label(info_panel,"Click any unlocked ingredient below to learn about it.",Vector2(17,46),13,GameData.COLORS.muted)
	else:
		var selected_info:Dictionary=GameData.INGREDIENTS[selected_cooking_ingredient];var selected_icon:=add_ingredient_icon(info_panel,selected_info,Vector2(14,12),Vector2(48,66),38);selected_icon.name="SelectedIngredientIcon";label(info_panel,selected_cooking_ingredient,Vector2(73,8),18,GameData.COLORS.ink,true);label(info_panel,ingredient_tag_text(selected_info),Vector2(73,36),13,Color.BLACK);label(info_panel,selected_info.feel,Vector2(73,61),11,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,535)
	# Ingredient, spice, and special-item sources.
	var resources_panel:=panel(Rect2(624,291,626,349),Color("#f7f7f7"),16);content.add_child(resources_panel)
	var keys:=GameData.INGREDIENTS.keys()
	var ingredient_grid:=GridContainer.new();ingredient_grid.name="CookingIngredientGrid";ingredient_grid.position=Vector2(12,10);ingredient_grid.size=Vector2(602,172);ingredient_grid.columns=8;ingredient_grid.add_theme_constant_override("h_separation",8);ingredient_grid.add_theme_constant_override("v_separation",8);resources_panel.add_child(ingredient_grid)
	for i in keys.size():
		var name:String=keys[i];var card:=IngredientDragCard.new();card.custom_minimum_size=Vector2(67,82);ingredient_grid.add_child(card);card.setup(self,name,unlocked_ingredients.has(name))
	var separator_one:=ColorRect.new();separator_one.color=Color("#c9cdd2");separator_one.position=Vector2(15,188);separator_one.size=Vector2(596,2);separator_one.mouse_filter=Control.MOUSE_FILTER_IGNORE;resources_panel.add_child(separator_one)
	var spice_scroll:=ScrollContainer.new();spice_scroll.position=Vector2(12,198);spice_scroll.size=Vector2(602,60);resources_panel.add_child(spice_scroll)
	var spice_row:=HBoxContainer.new();spice_row.add_theme_constant_override("separation",7);spice_scroll.add_child(spice_row)
	for spice_name in GameData.SPICES:
		for spice_quality in GameData.SPICE_QUALITIES:
			var count:=int(spice_inventory[spice_name][spice_quality])
			if count<=0:continue
			var spice_info:Dictionary=GameData.SPICES[spice_name];var card:=CookingItemCard.new();card.custom_minimum_size=Vector2(174,58);spice_row.add_child(card);card.setup(spice_info.icon,spice_name,spice_quality.capitalize(),count,spice_quality_color(spice_quality),{"kind":"spice","name":spice_name,"quality":spice_quality,"label":spice_name})
	var separator_two:=ColorRect.new();separator_two.color=Color("#c9cdd2");separator_two.position=Vector2(15,267);separator_two.size=Vector2(596,2);separator_two.mouse_filter=Control.MOUSE_FILTER_IGNORE;resources_panel.add_child(separator_two)
	var special_card_x:=14.0
	if int(special_items["Bountiful Berry"])>0:
		var bountiful_card:=CookingItemCard.new();bountiful_card.name="BountifulBerryCard";bountiful_card.position=Vector2(special_card_x,279);bountiful_card.size=Vector2(190,58);resources_panel.add_child(bountiful_card);bountiful_card.setup("🫐","Bountiful Berry","2–5 arrivals",int(special_items["Bountiful Berry"]),GameData.COLORS.berry,{"kind":"special","id":"Bountiful Berry","label":"Bountiful Berry"});special_card_x+=200
	if int(special_items["Empty Leftover Jar"])>0:
		var empty_jar_card:=CookingItemCard.new();empty_jar_card.name="EmptyLeftoverJarCard";empty_jar_card.position=Vector2(special_card_x,279);empty_jar_card.size=Vector2(190,58);resources_panel.add_child(empty_jar_card);empty_jar_card.setup("🫙","Empty Leftover Jar","collects leftovers",int(special_items["Empty Leftover Jar"]),GameData.COLORS.gold,{"kind":"special","id":"Empty Leftover Jar","label":"Empty Leftover Jar"});special_card_x+=200
	if total>0 and int(leftovers.get(recipe.name,0))>0:
		var leftover_card:=CookingItemCard.new();leftover_card.name="MatchingLeftoversCard";leftover_card.position=Vector2(special_card_x,279);leftover_card.size=Vector2(190,58);resources_panel.add_child(leftover_card);leftover_card.setup("🫙",recipe.name+" Leftovers","improves matching stew",int(leftovers[recipe.name]),recipe.color,{"kind":"special","id":"Leftovers:"+str(recipe.name),"label":"Leftovers"})
	add_back_button(content,Vector2(1182,646),func():request_leave_cooking(show_camp))

func step_cooking_recipe(direction:int)->void:
	cooking_recipe_index=wrapi(cooking_recipe_index+direction,0,GameData.RECIPES.size());show_cooking()

func recipe_attracts_text(recipe:Dictionary)->String:
	# A generic hint (type, colour, build) rather than the exact species pool.
	var phrase:=str(recipe.get("attracts","Quiblets"))
	return "Attracts "+phrase

func pot_total()->int:
	return pot_slots.count("")*-1+pot_slots.size()

func rebuild_pot_from_slots()->void:
	pot.clear()
	for ingredient_name in pot_slots:
		if not ingredient_name.is_empty():pot[ingredient_name]=int(pot.get(ingredient_name,0))+1

func can_drag_ingredient(name:String,slot_index:=-1)->bool:
	if not pending_stew.is_empty():return false
	if not unlocked_ingredients.has(name):return false
	if slot_index>=0 and slot_index<pot_slots.size() and pot_slots[slot_index]==name:return true
	return int(ingredients.get(name,0))>=3

func spice_quality_color(quality:String)->Color:
	return {"basic":Color("#b9a98e"),"good":Color("#78b985"),"great":Color("#6c94d8"),"special":Color("#b877d2")}.get(quality,GameData.COLORS.stone)

func cooking_slot_display(kind:String,data:Variant)->Dictionary:
	if kind=="ingredient":
		var info:Dictionary=GameData.INGREDIENTS.get(str(data),{})
		return {"icon":info.get("icon","?"),"texture":info.get("texture",""),"caption":"×3","color":info.get("color",GameData.COLORS.stone),"tooltip":str(data)}
	if kind=="spice":
		var spice_info:Dictionary=GameData.SPICES.get(str(data.get("name","")),{})
		return {"icon":spice_info.get("icon","?"),"caption":str(data.get("quality","basic")).substr(0,1).to_upper(),"color":spice_quality_color(str(data.get("quality","basic"))),"tooltip":"%s (%s) — favors %s"%[data.get("name","Spice"),str(data.get("quality","basic")).capitalize(),spice_info.get("favors","matching Quiblets")]}
	var special_id:=str(data)
	if special_id=="Bountiful Berry":return {"icon":"🫐","caption":"2–5","color":GameData.COLORS.berry,"tooltip":"Bountiful Berry — attracts 2–5 arrivals"}
	if special_id=="Empty Leftover Jar":return {"icon":"🫙","caption":"EMPTY","color":GameData.COLORS.gold,"tooltip":"Empty Leftover Jar — collects leftovers from this stew"}
	return {"icon":"🫙","caption":"BOOST","color":GameData.COLORS.gold,"tooltip":special_id.trim_prefix("Leftovers:")+" Leftovers"}

func can_drop_cooking_item(kind:String,data:Dictionary,slot_index:int)->bool:
	if not pending_stew.is_empty():return false
	if kind=="ingredient":return can_drag_ingredient(str(data.get("name","")),slot_index)
	if kind=="spice":
		var name:=str(data.get("name",""));var quality:=str(data.get("quality",""))
		if slot_index>=0 and slot_index<spice_slots.size() and spice_slots[slot_index].get("name","")==name and spice_slots[slot_index].get("quality","")==quality:return true
		return GameData.SPICES.has(name) and GameData.SPICE_QUALITIES.has(quality) and int(spice_inventory.get(name,{}).get(quality,0))>0
	if kind=="special":
		var special_id:=str(data.get("id",""))
		if slot_index>=0 and slot_index<special_slots.size() and special_slots[slot_index]==special_id:return true
		if special_id in ["Bountiful Berry","Empty Leftover Jar"]:return int(special_items.get(special_id,0))>0
		if special_id.begins_with("Leftovers:"):
			var recipe_name:=special_id.trim_prefix("Leftovers:")
			return int(leftovers.get(recipe_name,0))>0 and pot_total()>0 and GameData.choose_recipe(pot).name==recipe_name
	return false

func assign_cooking_item(kind:String,slot_index:int,data:Dictionary)->void:
	if not can_drop_cooking_item(kind,data,slot_index):return
	if kind=="ingredient":
		var ingredient_name:=str(data.name)
		if pot_slots[slot_index]==ingredient_name:return
		clear_cooking_item(kind,slot_index,true,false)
		if int(ingredients.get(ingredient_name,0))<3:return
		ingredients[ingredient_name]-=3;pot_slots[slot_index]=ingredient_name;rebuild_pot_from_slots();validate_special_slots()
	elif kind=="spice":
		var spice_name:=str(data.name);var quality:=str(data.quality)
		if spice_slots[slot_index].get("name","")==spice_name and spice_slots[slot_index].get("quality","")==quality:return
		clear_cooking_item(kind,slot_index,true,false)
		if int(spice_inventory[spice_name][quality])<=0:return
		spice_inventory[spice_name][quality]-=1;spice_slots[slot_index]={"name":spice_name,"quality":quality}
	elif kind=="special":
		var special_id:=str(data.id)
		if special_slots[slot_index]==special_id:return
		clear_cooking_item(kind,slot_index,true,false)
		if special_id in ["Bountiful Berry","Empty Leftover Jar"]:special_items[special_id]-=1
		else:leftovers[special_id.trim_prefix("Leftovers:")]-=1
		special_slots[slot_index]=special_id
	show_cooking()

func clear_cooking_item(kind:String,slot_index:int,refund:=true,redraw:=true)->void:
	if kind=="ingredient" and slot_index>=0 and slot_index<pot_slots.size() and not pot_slots[slot_index].is_empty():
		if refund:ingredients[pot_slots[slot_index]]+=3
		pot_slots[slot_index]="";rebuild_pot_from_slots();validate_special_slots()
	elif kind=="spice" and slot_index>=0 and slot_index<spice_slots.size() and not spice_slots[slot_index].is_empty():
		var old:Dictionary=spice_slots[slot_index]
		if refund:spice_inventory[old.name][old.quality]+=1
		spice_slots[slot_index]={}
	elif kind=="special" and slot_index>=0 and slot_index<special_slots.size() and not special_slots[slot_index].is_empty():
		var old_id:=special_slots[slot_index]
		if refund:
			if old_id in ["Bountiful Berry","Empty Leftover Jar"]:special_items[old_id]+=1
			else:leftovers[old_id.trim_prefix("Leftovers:")]=int(leftovers.get(old_id.trim_prefix("Leftovers:"),0))+1
		special_slots[slot_index]=""
	if redraw:show_cooking()

func validate_special_slots()->void:
	var current_recipe_name:String=str(GameData.choose_recipe(pot).name) if pot_total()>0 else ""
	for i in special_slots.size():
		var special_id:=special_slots[i]
		if special_id.begins_with("Leftovers:") and special_id.trim_prefix("Leftovers:")!=current_recipe_name:
			var old_recipe:=special_id.trim_prefix("Leftovers:");leftovers[old_recipe]=int(leftovers.get(old_recipe,0))+1;special_slots[i]=""

func assign_pot_slot(slot_index:int,name:String)->void:
	assign_cooking_item("ingredient",slot_index,{"kind":"ingredient","name":name})

func clear_pot_slot(slot_index:int,refund:=true)->void:
	clear_cooking_item("ingredient",slot_index,refund,true)

func clear_all_pot_slots(refund:=true)->void:
	for i in pot_slots.size():
		if not pot_slots[i].is_empty() and refund:ingredients[pot_slots[i]]+=3
		pot_slots[i]=""
	rebuild_pot_from_slots()

func clear_all_cooking_slots(refund:=true)->void:
	for i in spice_slots.size():clear_cooking_item("spice",i,refund,false)
	for i in special_slots.size():clear_cooking_item("special",i,refund,false)
	clear_all_pot_slots(refund)

func cooking_has_placed_items()->bool:
	return pot_total()>0 or spice_slots.any(func(slot):return not slot.is_empty()) or special_slots.any(func(slot):return not slot.is_empty())

func request_start_cooking()->void:
	if not pending_stew.is_empty() or pot_total()<5:return
	if content.find_child("StartCookingConfirmation",true,false)!=null:return
	var shade:=ColorRect.new();shade.name="StartCookingConfirmation";shade.color=Color(0,0,0,.72);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;shade.z_index=100;content.add_child(shade)
	var menu:=panel(Rect2(370,220,540,260),Color("#fffdf7"),20);shade.add_child(menu)
	label(menu,"START COOKING?",Vector2(30,28),25,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,480)
	label(menu,"Begin cooking with the ingredients currently in the pot?",Vector2(42,82),14,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,456)
	label(menu,"The selected ingredients will be consumed.",Vector2(42,112),13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,456)
	var cancel:=add_button(menu,"CANCEL",Vector2(45,171),Vector2(205,54),shade.queue_free,"plain");cancel.name="CancelStartCooking"
	var confirm:=add_button(menu,"START COOKING",Vector2(270,171),Vector2(225,54),cook,"gold");confirm.name="ConfirmStartCooking"

func request_leave_cooking(destination:Callable)->void:
	if not cooking_has_placed_items():destination.call();return
	var shade:=ColorRect.new();shade.name="CookingLeaveConfirmation";shade.color=Color(0,0,0,.72);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;shade.z_index=100;content.add_child(shade)
	var menu:=panel(Rect2(370,220,540,260),Color("#fffdf7"),20);shade.add_child(menu)
	label(menu,"LEAVE COOKING?",Vector2(30,30),25,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,480)
	label(menu,"Everything currently in the pot will be returned to your inventory.",Vector2(45,86),14,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,450)
	var cancel:=add_button(menu,"CANCEL",Vector2(45,171),Vector2(205,54),shade.queue_free,"plain");cancel.name="CancelCookingExit"
	var leave:=add_button(menu,"RETURN ITEMS & LEAVE",Vector2(270,171),Vector2(225,54),confirm_leave_cooking.bind(destination),"coral");leave.name="ConfirmCookingExit"

func confirm_leave_cooking(destination:Callable)->void:
	clear_all_cooking_slots(true)
	destination.call()

func detach_cooking_item_for_drag(kind:String,slot_index:int)->Dictionary:
	var payload:Dictionary={}
	if kind=="ingredient" and slot_index>=0 and slot_index<pot_slots.size() and not pot_slots[slot_index].is_empty():
		payload={"kind":"ingredient","name":pot_slots[slot_index]}
	elif kind=="spice" and slot_index>=0 and slot_index<spice_slots.size() and not spice_slots[slot_index].is_empty():
		payload={"kind":"spice","name":spice_slots[slot_index].name,"quality":spice_slots[slot_index].quality,"label":spice_slots[slot_index].name}
	elif kind=="special" and slot_index>=0 and slot_index<special_slots.size() and not special_slots[slot_index].is_empty():
		var special_id:=special_slots[slot_index];payload={"kind":"special","id":special_id,"label":special_id.trim_prefix("Leftovers:") if special_id.begins_with("Leftovers:") else special_id}
	if not payload.is_empty():clear_cooking_item(kind,slot_index,true,false)
	return payload

func finish_cooking_slot_drag()->void:
	if screen=="cooking" and is_instance_valid(content):show_cooking()

func grant_ingredient(ingredient_name:String,amount:int)->void:
	if not GameData.INGREDIENTS.has(ingredient_name) or amount<=0:return
	ingredients[ingredient_name]=int(ingredients.get(ingredient_name,0))+amount
	if not unlocked_ingredients.has(ingredient_name):unlocked_ingredients.append(ingredient_name)

func select_cooking_ingredient(name:String)->void:
	# Ingredient cards also live on the Training screen, which has no info panel;
	# both Cooking and the Spice Workshop show one.
	if screen not in ["cooking","spice_workshop"]:return
	if unlocked_ingredients.has(name):
		selected_cooking_ingredient=name;selected_cooking_item={}
		if screen=="cooking":show_cooking()
		else:show_spice_workshop()

func inspect_cooking_item(kind:String,slot_index:int)->void:
	# Clicking a filled pot, spice, or special slot shows that item in the info panel.
	if kind=="ingredient":
		if slot_index>=0 and slot_index<pot_slots.size() and not pot_slots[slot_index].is_empty():select_cooking_ingredient(pot_slots[slot_index])
	elif kind=="spice":
		if slot_index>=0 and slot_index<spice_slots.size() and not spice_slots[slot_index].is_empty():selected_cooking_ingredient="";selected_cooking_item={"kind":"spice","name":str(spice_slots[slot_index].name),"quality":str(spice_slots[slot_index].quality)};show_cooking()
	elif kind=="special":
		if slot_index>=0 and slot_index<special_slots.size() and not special_slots[slot_index].is_empty():selected_cooking_ingredient="";selected_cooking_item={"kind":"special","id":special_slots[slot_index]};show_cooking()

func special_item_description(special_id:String)->String:
	if special_id.begins_with("Leftovers:"):return "Leftovers from %s. Reinvesting them improves this stew's recipe precision."%special_id.trim_prefix("Leftovers:")
	return str(SPECIAL_ITEM_DESCRIPTIONS.get(special_id,""))

func inspect_equipment(kind:String,primary_index:int,secondary_index:int)->void:
	# Clicking a fitted stone selects it in the stone detail panel.
	if selected_roster<0 or selected_roster>=roster.size():return
	var q:Dictionary=roster[selected_roster];ensure_quiblet_equipment(q)
	if kind=="power":
		if primary_index<0 or primary_index>=q.power_slot_stones.size() or q.power_slot_stones[primary_index].is_empty():return
		select_inventory_stone(fitted_power_stone_data(q.power_slot_stones[primary_index],selected_roster,primary_index))
	else:
		if primary_index<0 or primary_index>=q.moves.size():return
		var entry:Dictionary=q.moves[primary_index]
		if secondary_index<0 or secondary_index>=entry.stones.size():return
		var effect:=GameData.stone_effect(str(entry.stones[secondary_index]))
		if effect.is_empty():return
		select_inventory_stone({"kind":"move_stone","effect":effect,"count":int(move_stone_inventory.get(effect,0)),"display_name":str(GameData.stone_info(effect).name),"inventory_index":-1})

func ingredient_quality_points()->float:
	var total_points:=0.0
	var total_parts:=0
	for ingredient_name in pot:
		var amount:=int(pot[ingredient_name])
		# Ingredient tiers map evenly across this score's 60-point section.
		total_points+=float((int(GameData.INGREDIENTS[ingredient_name].tier)-1)*20*amount)
		total_parts+=amount
	return total_points/float(total_parts) if total_parts>0 else 0.0

func recipe_precision_points(recipe:Dictionary)->int:
	var precision:=15 if recipe.need.is_empty() else 0
	if not recipe.need.is_empty():
		for ingredient_name in pot:
			var matches_recipe:=false
			for tag in GameData.INGREDIENTS[ingredient_name].tags:
				if recipe.need.has(tag):matches_recipe=true;break
			if matches_recipe:precision+=6*int(pot[ingredient_name])
	# Either kind of jar improves the recipe's precision without masquerading as
	# an ingredient or changing its tier score.
	if leftover_boost or empty_leftover_jar_used:precision+=12
	return mini(precision,30)

func calculate_stew_score(recipe:Dictionary)->int:
	var variety_points:=mini(pot.size()*2,10)
	return clampi(roundi(ingredient_quality_points())+recipe_precision_points(recipe)+variety_points,0,100)

func quality_from_score(score:int)->String:
	if score>=80:return "Amazing"
	if score>=60:return "Great"
	if score>=35:return "Good"
	return "Decent"

func calculate_quality()->String:
	return quality_from_score(calculate_stew_score(GameData.choose_recipe(pot)))

func quality_color(q:String)->Color:
	return {"Decent":GameData.COLORS.water,"Good":GameData.COLORS.leaf,"Great":GameData.COLORS.gold,"Amazing":GameData.COLORS.berry}.get(q,GameData.COLORS.water)

func quality_rarity_multiplier(quality:String)->float:
	return {"Decent":1.0,"Good":1.25,"Great":1.75,"Amazing":2.5}.get(quality,1.0)

func quality_stone_chance(quality:String)->float:
	return {"Decent":0.08,"Good":0.15,"Great":0.25,"Amazing":0.35}.get(quality,0.08)

func quality_level_offset(quality:String)->int:
	var level_range:Vector2i={"Decent":Vector2i(-4,-2),"Good":Vector2i(-3,-1),"Great":Vector2i(-1,1),"Amazing":Vector2i(0,2)}.get(quality,Vector2i(-4,-2))
	return randi_range(level_range.x,level_range.y)

func quality_expeditions_required(quality:String)->int:
	return {"Decent":1,"Good":2,"Great":3,"Amazing":5}.get(quality,1)

func is_rare_arrival(species_index:int)->bool:
	return species_index in [1,5,7]

func spice_strength(quality:String)->float:
	return GameData.spice_strength(quality)

# Combined stat bonuses from every spice currently in the pot; applied to each
# arrival as a permanent "spice_bonuses" entry read by GameData.quiblet_bonus_totals.
func spice_arrival_bonuses()->Dictionary:
	var totals:={}
	for spice in spice_slots:
		if spice.is_empty():continue
		var bonuses:=GameData.spice_stat_bonuses(str(spice.name),str(spice.quality))
		for stat in bonuses:totals[stat]=float(totals.get(stat,0.0))+float(bonuses[stat])
	return totals

func species_spice_affinity(species_index:int,bias:String)->float:
	var species:Dictionary=GameData.species(species_index);var moves:Array=GameData.default_moves(species_index)
	match bias:
		"attack":return clampf((float(species.base_atk)-22.0)/19.0,0.0,1.0)
		"hp":return clampf((float(species.base_hp)-125.0)/100.0,0.0,1.0)
		"swift":return 1.0 if species_index in [0,2,6] else 0.15
		"melee":return clampf((145.0-float(species.range))/75.0,0.0,1.0)
		"unusual":return 1.0 if species_index==5 or moves.has("Soothing Scent") else 0.12
		"ranged":return clampf((float(species.range)-90.0)/100.0,0.0,1.0)
		"support":return 1.0 if moves.any(func(move_name):return move_name in ["Healing Bloom","Pollen Puff","Soothing Scent","Cocoon","Last Bloom"]) else 0.08
		"rare":return 1.0 if species_index in [1,5,7] else 0.18
	return 0.0

func choose_spiced_species(pool:Array,rarity_multiplier:=1.0)->int:
	var weights:Array[float]=[];var total:=0.0
	for species_index in pool:
		var weight:=rarity_multiplier if is_rare_arrival(int(species_index)) else 1.0
		for spice in spice_slots:
			if spice.is_empty():continue
			var info:Dictionary=GameData.SPICES[spice.name];weight*=1.0+2.25*spice_strength(spice.quality)*species_spice_affinity(int(species_index),info.bias)
		weights.append(weight);total+=weight
	var roll:=randf()*total
	for i in pool.size():
		roll-=weights[i]
		if roll<=0.0:return int(pool[i])
	return int(pool[-1])

func cook()->void:
	if not pending_stew.is_empty():toast("The current stew is still cooking.",GameData.COLORS.coral);return
	if pot_total()<5: toast("Fill at least five pot sockets before cooking.",GameData.COLORS.coral); return
	var recipe:=GameData.choose_recipe(pot)
	use_bountiful=special_slots.has("Bountiful Berry");empty_leftover_jar_used=special_slots.has("Empty Leftover Jar");leftover_boost=special_slots.has("Leftovers:"+str(recipe.name))
	var stew_score:=calculate_stew_score(recipe);var quality:=quality_from_score(stew_score)
	if not known_recipes.has(recipe.name):known_recipes.append(recipe.name)
	var leftovers_received:=1 if leftover_boost or empty_leftover_jar_used else 0
	var recruits:=randi_range(2,5) if use_bountiful else 1
	var new_names:Array[String]=[]
	var arrived_species:Array[int]=[]
	var arrivals:Array[Dictionary]=[]
	var average_level:=team_average_level()
	for i in recruits:
		var species_index:int=choose_spiced_species(recipe.pool,quality_rarity_multiplier(quality));var level:=maxi(1,average_level+quality_level_offset(quality))
		var q:=GameData.make_quiblet(species_index,level,"",true)
		# An arrival is born at its level rather than levelling up to it, so grant the
		# Lv. 25 milestones it would have earned on the way (one per full 25 levels).
		apply_arrival_milestones(q)
		var seasoning:=spice_arrival_bonuses()
		if not seasoning.is_empty():q.spice_bonuses=seasoning
		var stone_chance:=quality_stone_chance(quality)
		if randf()<stone_chance:q.power_stones.append(GameData.make_power_stone(["Health","Attack"].pick_random(),GameData.power_stone_tier_for_level(level),["Move wait −4%"]))
		arrivals.append(q);arrived_species.append(species_index);new_names.append(GameData.display_name(q)+" Lv.%d"%level)
	var required:=quality_expeditions_required(quality)
	pending_stew={"recipe":recipe.name,"quality":quality,"score":stew_score,"arrivals":arrivals,"arrival_names":new_names,"arrival_species":arrived_species,"leftovers":leftovers_received,"boosted":leftover_boost,"expeditions_required":required,"expeditions_remaining":required}
	play_started_cooking_music()
	clear_all_cooking_slots(false);leftover_boost=false;empty_leftover_jar_used=false;use_bountiful=false
	# Straight back to camp, where the lid drops onto the pot.
	lid_drop_pending=true;show_camp()
	toast("%s started (%s). Ready after %d expedition%s."%[recipe.name,quality,required,"" if required==1 else "s"],GameData.COLORS.leaf)

func advance_pending_stew()->bool:
	if pending_stew.is_empty():return false
	pending_stew.expeditions_remaining=maxi(0,int(pending_stew.expeditions_remaining)-1)
	if int(pending_stew.expeditions_remaining)>0:return false
	for arrival in pending_stew.arrivals:roster.append(arrival)
	if int(pending_stew.leftovers)>0:leftovers[pending_stew.recipe]=int(leftovers.get(pending_stew.recipe,0))+int(pending_stew.leftovers)
	completed_stew_result={"recipe":pending_stew.recipe,"quality":pending_stew.quality,"score":pending_stew.score,"arrivals":pending_stew.arrival_names.duplicate(),"arrival_species":pending_stew.arrival_species.duplicate(),"leftovers":pending_stew.leftovers,"boosted":pending_stew.boosted}
	var special_arrival:bool=completed_stew_result.arrival_species.any(func(species_index):return is_rare_arrival(int(species_index)))
	pending_stew.clear()
	play_quiblet_arrival_music(special_arrival)
	return true

func show_cook_result()->void:
	if completed_stew_result.is_empty():show_cooking();return
	screen="cook_result";clear_content();make_topbar("A DELICIOUS VISITOR!","The dish stayed deterministic; randomness chose the eligible arrival.",false)
	var card:=panel(Rect2(210,130,860,500),Color("#fffaf0"),24);content.add_child(card)
	label(card,completed_stew_result.recipe,Vector2(30,28),29,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,800)
	label(card,"%s quality"%completed_stew_result.quality,Vector2(30,69),17,quality_color(completed_stew_result.quality),true,HORIZONTAL_ALIGNMENT_CENTER,800)
	var shown_species:=int(completed_stew_result.arrival_species[-1]);var p:=QuibletPortrait.new();p.position=Vector2(320,105);p.size=Vector2(220,220);p.setup(shown_species,1.1);card.add_child(p)
	label(card,"Arrived: "+", ".join(completed_stew_result.arrivals),Vector2(30,328),18,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,800)
	if int(completed_stew_result.leftovers)>0:label(card,"Your leftover jar collected %s Leftovers. Find them under Resources or the Recipe Journal: reinvest them in the same dish, or recycle them for ingredients."%completed_stew_result.recipe,Vector2(60,362),13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,760)
	add_button(card,"COOK AGAIN",Vector2(150,422),Vector2(250,52),dismiss_cooked_result,"gold")
	add_back_button(content,BACK_BUTTON_POSITION,func():show_camp())

func dismiss_cooked_result()->void:
	completed_stew_result.clear();show_cooking()

func show_recipes()->void:
	screen="recipes";clear_content();make_topbar("RECIPE JOURNAL","Discovered recipes explain their ingredient logic and can be prepared again quickly.",true)
	var journal:=panel(Rect2(80,120,1120,540),Color("#fffaf0"),20);content.add_child(journal)
	var recipe_scroll:=ScrollContainer.new();recipe_scroll.position=Vector2(14,14);recipe_scroll.size=Vector2(1092,512);journal.add_child(recipe_scroll)
	var recipe_grid:=Control.new();recipe_grid.custom_minimum_size=Vector2(1070,ceili(GameData.RECIPES.size()/2.0)*164);recipe_scroll.add_child(recipe_grid)
	for i in GameData.RECIPES.size():
		var recipe:Dictionary=GameData.RECIPES[i];var known:bool=known_recipes.has(recipe.name) or recipe.name=="Plain Stew";var x:=(i%2)*536;var y:=(i/2)*164
		var card:=panel(Rect2(x,y,516,145),Color.WHITE if known else Color("#e9e8e3"),14);recipe_grid.add_child(card)
		label(card,recipe.name if known else "Undiscovered Dish",Vector2(18,14),18,recipe.color if known else GameData.COLORS.muted,true)
		label(card,recipe.desc if known else "Experiment with meaningful ingredient tags to discover this recipe.",Vector2(18,44),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,480)
		if known:
			label(card,"Needs: "+requirement_text(recipe.need),Vector2(18,86),12,GameData.COLORS.ink,true)
			label(card,"Leftovers: %d"%int(leftovers.get(recipe.name,0)),Vector2(18,112),12,GameData.COLORS.leaf_dark)
			add_button(card,"PREPARE",Vector2(378,66),Vector2(124,32),func(r=recipe):prefill_recipe(r),"leaf")
			add_button(card,"RECYCLE",Vector2(378,104),Vector2(124,28),func(r=recipe):recycle_leftover(r),"plain")

func prefill_recipe(recipe:Dictionary)->void:
	if not pending_stew.is_empty():show_cooking();toast("The current stew is still cooking.",GameData.COLORS.coral);return
	if not completed_stew_result.is_empty():show_cook_result();return
	clear_all_pot_slots(true)
	var planned:={};var planned_total:=0;var candidates:=GameData.INGREDIENTS.keys()
	while planned_total<5:
		var best_name:String="";var best_score:=-1
		var current_tags:=GameData.tags_for_ingredients(planned)
		for candidate in candidates:
			if not unlocked_ingredients.has(candidate) or int(ingredients[candidate])<(int(planned.get(candidate,0))+1)*3:continue
			var score:=0
			for tag in recipe.need:
				if GameData.INGREDIENTS[candidate].tags.has(tag) and int(current_tags.get(tag,0))<int(recipe.need[tag]):score+=1
			if recipe.need.is_empty():score=1
			if score>best_score:best_score=score;best_name=candidate
		if best_name.is_empty():break
		planned[best_name]=int(planned.get(best_name,0))+1;planned_total+=1
	var slot_index:=0
	for ingredient_name in planned:
		for amount_index in int(planned[ingredient_name]):
			ingredients[ingredient_name]-=3;pot_slots[slot_index]=ingredient_name;slot_index+=1
	rebuild_pot_from_slots()
	validate_special_slots()
	show_cooking()

func recycle_leftover(recipe:Dictionary)->void:
	if int(leftovers.get(recipe.name,0))<=0:toast("No leftovers from that dish to recycle.",GameData.COLORS.coral);return
	leftovers[recipe.name]-=1
	var eligible:Array=[]
	for ingredient_name in GameData.INGREDIENTS:
		if recipe.need.is_empty() or GameData.INGREDIENTS[ingredient_name].tags.any(func(tag):return recipe.need.has(tag)):eligible.append(ingredient_name)
	# A jar gives back a few ingredients that fit the dish it came from.
	var recovered:=randi_range(LEFTOVER_RECYCLE_RANGE.x,LEFTOVER_RECYCLE_RANGE.y)
	var found:Array[String]=[]
	for i in recovered:
		var ingredient:String=eligible.pick_random();grant_ingredient(ingredient,1);found.append(ingredient)
	if screen=="inventory":show_resources()
	else:show_recipes()
	toast("Recycled into: "+", ".join(found),GameData.COLORS.leaf)

const LEFTOVER_RECYCLE_RANGE:=Vector2i(2,4)

func show_training()->void:
	screen="training";clear_content();add_menu_backdrop()
	validate_training_slots()
	var section:=panel(Rect2(28,68,560,624),Color("#f5f2fcf2"),18);content.add_child(section);section.name="TrainingSection"
	build_training_section(section)
	build_quiblet_side_panels(false)
	add_back_button(content,BACK_BUTTON_POSITION,show_all_quiblets)
	selection_pulse_roster=-1

func build_training_section(parent:Control)->void:
	for i in 2:
		var mode:="move" if i==0 else "exp"
		var button:=add_button(parent,"MOVE TRAINING" if i==0 else "EXP TRAINING",Vector2(18+i*272,12),Vector2(252,36),func():set_training_mode(mode),"leaf" if training_mode==mode else "plain")
		button.name="TrainingModeMove" if i==0 else "TrainingModeExp"
	var move_mode:=training_mode=="move"
	# Move training keeps the trainee on the left with its moves beside it; EXP training centres the trainee.
	if move_mode:
		label(parent,"TRAINEE",Vector2(18,54),12,GameData.COLORS.berry,true,HORIZONTAL_ALIGNMENT_LEFT,140)
		build_training_slot(parent,"trainee",0,Vector2(40,70),Vector2(96,108))
		build_training_moves(parent,Rect2(150,54,392,176))
	else:
		label(parent,"TRAINEE",Vector2(18,54),12,GameData.COLORS.berry,true,HORIZONTAL_ALIGNMENT_CENTER,524)
		build_training_slot(parent,"trainee",0,Vector2(232,70),Vector2(96,108))
	# Four helpers in a row, with the two food sockets stacked beside them.
	label(parent,"HELPERS (CONSUMED)",Vector2(18,236),12,GameData.COLORS.leaf_dark,true,HORIZONTAL_ALIGNMENT_CENTER,416)
	for i in 4:build_training_slot(parent,"helper",i,Vector2(18+i*104,252),Vector2(96,84))
	label(parent,"FOOD",Vector2(446,236),12,GameData.COLORS.gold.darkened(.25),true,HORIZONTAL_ALIGNMENT_CENTER,96)
	for i in 2:build_training_slot(parent,"food",i,Vector2(446,252+i*44),Vector2(96,40))
	var tray:=panel(Rect2(18,344,524,165),Color("#ffffffb0"),12);parent.add_child(tray);tray.name="TrainingIngredientTray"
	var grid:=GridContainer.new();grid.name="TrainingIngredientGrid";grid.position=Vector2(2,5);grid.columns=8;grid.scale=Vector2.ONE*.9;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",8);tray.add_child(grid)
	for ingredient_name in GameData.INGREDIENTS:
		var card:=IngredientDragCard.new();card.custom_minimum_size=Vector2(67,82);grid.add_child(card);card.setup(self,ingredient_name,unlocked_ingredients.has(ingredient_name),1)
	var summary:=label(parent,training_summary_text(),Vector2(24,514),12,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_CENTER,512);summary.name="TrainingSummary"
	var train_button:=add_button(parent,"TRAIN",Vector2(170,566),Vector2(220,54),request_training,"gold");train_button.name="TrainButton";train_button.add_theme_font_size_override("font_size",18)

func build_training_slot(parent:Control,role:String,index:int,pos:Vector2,slot_size:Vector2)->void:
	var slot:=TRAINING_SLOT_SCRIPT.new();slot.name="TraineeSlot" if role=="trainee" else ("HelperSlot%d"%index if role=="helper" else "FoodSlot%d"%index);slot.position=pos;slot.size=slot_size
	var occupant:Variant=training_foods[index] if role=="food" else (training_trainee if role=="trainee" else training_helpers[index])
	slot.setup(self,role,index,occupant)
	var color:Color=GameData.COLORS.berry if role=="trainee" else (GameData.COLORS.gold if role=="food" else GameData.COLORS.leaf)
	var style:=StyleBoxFlat.new();style.bg_color=Color(color,.24 if slot.has_content() else .1);style.border_color=color;style.set_border_width_all(3);style.set_corner_radius_all(10);slot.add_theme_stylebox_override("panel",style);parent.add_child(slot)
	if role=="food":
		if slot.has_content():
			var food_name:String=training_foods[index]
			add_ingredient_icon(slot,GameData.INGREDIENTS[food_name],Vector2(4,3),Vector2(34,34),20).mouse_filter=Control.MOUSE_FILTER_IGNORE
			label(slot,food_name,Vector2(40,12),9,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,54)
		else:label(slot,"DROP FOOD",Vector2(4,13),9,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_CENTER,88)
		return
	if slot.has_content():
		var compact:=slot_size.y<108
		var q:Dictionary=roster[int(occupant)];var portrait:=QuibletPortrait.new();portrait.position=Vector2(22,3) if compact else Vector2(17,6);portrait.size=Vector2(52,52) if compact else Vector2(62,66);portrait.setup(int(q.species),.9);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(portrait)
		label(slot,GameData.display_name(q),Vector2(4,56 if compact else 72),10,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,88)
		if role=="helper" and training_trainee>=0:
			var relationship:=GameData.quiblet_relationship(roster[training_trainee],q)
			var contribution:String="+%d%%"%int(GameData.MOVE_TRAINING_HELPER_CHANCE[relationship]) if training_mode=="move" else "×%.2f"%float(GameData.EXP_TRAINING_HELPER_MULTIPLIER[relationship])
			label(slot,contribution,Vector2(4,70 if compact else 88),9,GameData.COLORS.leaf_dark,true,HORIZONTAL_ALIGNMENT_CENTER,88)
	else:label(slot,"DROP HERE",Vector2(4,36 if slot_size.y<108 else 45),9,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_CENTER,88)

func build_training_moves(parent:Control,rect:Rect2)->void:
	# The trainee's moves with their Move Stone slots and fitted stones, drawn at
	# 60% of the Quiblet info menu's size. Clicking a row picks the move to retrain.
	var moves_panel:=panel(rect,Color("#5f5f5f"),14);parent.add_child(moves_panel);moves_panel.name="TrainingMoves"
	if training_trainee<0:
		label(moves_panel,"Drop a trainee to see its moves.",Vector2(12,74),12,Color("#d9d9d9"),false,HORIZONTAL_ALIGNMENT_CENTER,368);return
	var trainee:Dictionary=roster[training_trainee]
	var header:="RETRAINING: %s"%str(trainee.moves[training_move].name) if training_move>=0 and training_move<trainee.moves.size() else "CLICK A MOVE TO RETRAIN"
	label(moves_panel,header,Vector2(12,4),10,GameData.COLORS.gold if training_move>=0 else Color("#e6e6e6"),true,HORIZONTAL_ALIGNMENT_LEFT,368).name="TrainingMovesHeader"
	for move_index in trainee.moves.size():
		var entry:Dictionary=trainee.moves[move_index];var row_y:float=22.0+move_index*38.0
		var cluster_width:=move_cluster_width(entry)*.6
		if move_index==training_move:
			var highlight:=panel(Rect2(8,row_y-3,cluster_width+16,40),Color(GameData.COLORS.gold,.35),8);highlight.mouse_filter=Control.MOUSE_FILTER_IGNORE;moves_panel.add_child(highlight)
		var cluster:=build_move_cluster_display(moves_panel,entry,move_index,Vector2(14,row_y),"Training");cluster.scale=Vector2.ONE*.6
		var pick:=Button.new();pick.name="RetrainMove%d"%move_index;pick.flat=true;pick.position=Vector2(8,row_y-3);pick.size=Vector2(cluster_width+16,40);pick.tooltip_text="Retrain %s"%str(entry.name);pick.pressed.connect(select_training_move.bind(move_index));moves_panel.add_child(pick)

func move_cluster_width(entry:Dictionary)->float:
	return 54.0 if int(entry.slots)==0 else 66.0+(int(entry.slots)-1)*60.0+59.0625

func build_move_cluster_display(parent:Control,entry:Dictionary,move_index:int,pos:Vector2,name_prefix:String)->Control:
	# Read-only twin of the Quiblet info menu's move cluster: icon, stone slots, fitted stones.
	var cluster:=Control.new();cluster.name="%sMoveCluster%d"%[name_prefix,move_index];cluster.position=pos;cluster.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(cluster)
	var icon:=MOVE_ICON_SCRIPT.new();icon.name="%sMoveIcon%d"%[name_prefix,move_index];icon.position=Vector2.ZERO;icon.size=Vector2(54,54);icon.setup(str(entry.name));icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;cluster.add_child(icon)
	for stone_slot in int(entry.slots):
		var slot:=TextureRect.new();slot.name="%sStoneSlot%d_%d"%[name_prefix,move_index,stone_slot];slot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;slot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;slot.custom_minimum_size=Vector2.ZERO;slot.texture=move_stone_slot_texture(entry);slot.position=Vector2(66+stone_slot*60,0);slot.size=Vector2(59.0625,59.0625);slot.mouse_filter=Control.MOUSE_FILTER_IGNORE;cluster.add_child(slot)
		if stone_slot<entry.stones.size():add_fitted_move_stone(slot,str(entry.stones[stone_slot]))
	return cluster

func build_power_slot_display(parent:Control,q:Dictionary,slot_index:int,pos:Vector2)->void:
	build_power_cell(parent,q,slot_index,pos,false)

const RESULT_MENU_WIDTH:=740.0

func build_quiblet_menu_replica(parent:Control,q:Dictionary)->Dictionary:
	# Condensed read-only copy of the Quiblet info menu: a tight info strip on
	# top, then the stone equipment menu with the move list on the left and the
	# 4×4 Power Stone grid beside it, so no space is wasted beneath the grid.
	# The parent is resized to the layout's natural bounds.
	ensure_quiblet_equipment(q)
	var refs:={}
	var compact_info:=panel(Rect2(0,0,RESULT_MENU_WIDTH,120),Color("#fffdf7"),16);compact_info.name="ResultInfo";compact_info.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(compact_info)
	var portrait:=QuibletPortrait.new();portrait.name="ResultPortrait";portrait.position=Vector2(10,10);portrait.size=Vector2(100,100);portrait.setup(int(q.species),1.08);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;compact_info.add_child(portrait);refs.portrait=portrait
	refs.name_label=label(compact_info,GameData.display_name(q),Vector2(122,10),20,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,250);refs.name_label.name="ResultName"
	refs.level_label=label(compact_info,"Lv. %d"%int(q.level),Vector2(122,42),13,GameData.COLORS.muted,true);refs.level_label.name="ResultLevel"
	var xp:=ProgressBar.new();xp.name="ResultXP";xp.position=Vector2(122,64);xp.size=Vector2(115,18);xp.scale=Vector2(1,.5);xp.max_value=GameData.exp_to_level(int(q.level));xp.value=int(q.exp);xp.show_percentage=false;compact_info.add_child(xp);style_quiblet_xp_bar(xp);refs.xp_bar=xp
	var separator:=HSeparator.new();separator.position=Vector2(122,82);separator.size=Vector2(300,2);compact_info.add_child(separator)
	label(compact_info,"%s • %s range"%[GameData.species(int(q.species)).element,"long" if is_long_range(q) else "short"],Vector2(122,92),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,300)
	add_quiblet_stat_badge(compact_info,Vector2(RESULT_MENU_WIDTH-170,16),Vector2(150,34),"res://textures/UI/HealthIcon.png",GameData.max_hp(q),Color("#4b9fda"),"HealthStatBadge")
	add_quiblet_stat_badge(compact_info,Vector2(RESULT_MENU_WIDTH-170,62),Vector2(150,34),"res://textures/UI/AttackIcon.png",GameData.attack(q),Color("#df5b55"),"AttackStatBadge")
	refs.health_label=compact_info.find_child("HealthStatBadgeValue",true,false);refs.attack_label=compact_info.find_child("AttackStatBadgeValue",true,false)
	var move_rows:int=maxi(1,q.moves.size());var equipment_height:=maxf(move_rows*66.0+16.0,252.0+16.0)
	var equipment_menu:=panel(Rect2(0,130,RESULT_MENU_WIDTH,equipment_height),Color("#5f5f5f"),14);equipment_menu.name="ResultEquipment";equipment_menu.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(equipment_menu)
	for move_index in q.moves.size():build_move_cluster_display(equipment_menu,q.moves[move_index],move_index,Vector2(20,8+move_index*66),"Result")
	var power_grid:=Control.new();power_grid.name="ResultPowerGrid";power_grid.size=Vector2(252,252);power_grid.mouse_filter=Control.MOUSE_FILTER_IGNORE;power_grid.position=Vector2(RESULT_MENU_WIDTH-20-252,8);equipment_menu.add_child(power_grid)
	refs.grid=power_grid;refs.board=q;refs.shown_level=-1
	set_result_board_level(refs,int(q.level),int(q.exp))
	parent.size=Vector2(RESULT_MENU_WIDTH,130+equipment_height)
	return refs

func animated_unlock_progress(q:Dictionary,level:int,exp:int)->Dictionary:
	# Unlock square progress using the fractional level (level plus XP toward the
	# next level), so the square sweeps smoothly while XP animates.
	var next:=GameData.next_power_unlock(q)
	if int(next.index)<0:return next
	var fractional:=float(level)+float(exp)/maxf(1.0,float(GameData.exp_to_level(level)))
	next.progress=clampf((fractional-float(next.previous))/float(int(next.level)-int(next.previous)),0.0,1.0)
	return next

func set_result_board_level(refs:Dictionary,level:int,exp:int)->void:
	# Redraw the grid when a level boundary is crossed (slots unlock, the square
	# moves to the following slot); otherwise only advance the square's sweep.
	var view:Dictionary=refs.board.duplicate();view.level=level
	if int(refs.shown_level)!=level:
		for child in refs.grid.get_children():refs.grid.remove_child(child);child.queue_free()
		for slot_index in 16:build_power_slot_display(refs.grid,view,slot_index,Vector2((slot_index%4)*66,(slot_index/4)*66))
		refs.shown_level=level
	var ring:Control=refs.grid.find_child("UnlockProgressRing",true,false)
	if ring!=null:ring.progress=float(animated_unlock_progress(view,level,exp).progress)

func best_result_card_layout(count:int,natural:Vector2)->Dictionary:
	# Choose the row count whose scale makes every card as large as the screen allows.
	var gap:=14.0;var area:=Rect2(20,24,1240,580);var best:={"rows":1,"per_row":count,"scale":0.0}
	for rows in range(1,count+1):
		var per_row:=ceili(float(count)/rows)
		var scale_x:=(area.size.x-(per_row-1)*gap)/(per_row*natural.x);var scale_y:=(area.size.y-(rows-1)*gap)/(rows*natural.y)
		# Never enlarge past the menu's native size; a lone card is big enough at 1×.
		var card_scale:=minf(1.0,minf(scale_x,scale_y))
		if card_scale>float(best.scale):best={"rows":rows,"per_row":per_row,"scale":card_scale}
	best.gap=gap;best.area=area;return best

func select_training_move(move_index:int)->void:
	training_move=move_index;show_training()

func training_ingredient_available(ingredient_name:String)->bool:
	return unlocked_ingredients.has(ingredient_name) and int(ingredients.get(ingredient_name,0))>=1

func training_helper_dicts()->Array:
	var helpers:Array=[]
	for roster_index in training_helpers:
		if roster_index>=0 and roster_index<roster.size():helpers.append(roster[roster_index])
	return helpers

func validate_training_slots()->void:
	if training_trainee>=roster.size():training_trainee=-1
	if training_trainee<0 or training_move>=roster[training_trainee].moves.size():training_move=-1
	for i in 4:
		if training_helpers[i]>=roster.size() or training_helpers[i]==training_trainee:training_helpers[i]=-1
	for i in training_foods.size():
		if not training_foods[i].is_empty() and int(ingredients.get(training_foods[i],0))<training_foods.count(training_foods[i]):training_foods[i]=""

func set_training_mode(mode:String)->void:
	training_mode=mode;show_training()

func can_assign_training(role:String,index:int,data:Dictionary)->bool:
	if role=="food":
		var food_name:=str(data.get("name",""))
		if index<0 or index>=training_foods.size() or not training_ingredient_available(food_name):return false
		var reserved:=0
		for i in training_foods.size():
			if i!=index and training_foods[i]==food_name:reserved+=1
		return int(ingredients.get(food_name,0))>reserved
	var roster_index:=int(data.get("roster_index",-1))
	if roster_index<0 or roster_index>=roster.size():return false
	return role=="trainee" or (role=="helper" and index>=0 and index<4)

func assign_training_slot(role:String,index:int,data:Dictionary)->void:
	if not can_assign_training(role,index,data):return
	if role=="food":training_foods[index]=str(data.name)
	else:
		var roster_index:=int(data.roster_index)
		# A Quiblet fills one socket at a time.
		if training_trainee==roster_index:training_trainee=-1
		for i in 4:
			if training_helpers[i]==roster_index:training_helpers[i]=-1
		if role=="trainee":
			if training_trainee!=roster_index:training_move=-1
			training_trainee=roster_index
		else:training_helpers[index]=roster_index
		selected_roster=roster_index;selection_pulse_roster=roster_index
	show_training()

func clear_training_slot(role:String,index:int)->void:
	if role=="food":
		if index>=0 and index<training_foods.size():training_foods[index]=""
	elif role=="trainee":training_trainee=-1;training_move=-1
	elif index>=0 and index<4:training_helpers[index]=-1
	show_training()

func training_compatibility_phrase(compatibility:String)->String:
	return {"excellent":"an excellent","good":"a good","neutral":"a neutral","poor":"a poor","opposing":"an opposing"}[compatibility]

func training_summary_text()->String:
	if training_trainee<0:return "Drag a Quiblet into the trainee slot, add helpers (they are consumed), and food to give each helper a chance to stay."
	var trainee:Dictionary=roster[training_trainee];var helpers:=training_helper_dicts();var trainee_name:=GameData.display_name(trainee)
	var preserve_parts:Array[String]=[]
	for helper in helpers:preserve_parts.append("%s %d%%"%[GameData.display_name(helper),roundi(GameData.helper_preservation_chance(helper,training_foods))])
	var preserve_line:String="Add at least one helper." if helpers.is_empty() else "Chance to keep: "+", ".join(preserve_parts)
	if training_mode=="move":
		if GameData.retrain_pool(trainee).is_empty():return "%s already knows every move it can learn."%trainee_name
		if training_move<0:return "Click one of %s's moves to retrain."%trainee_name
		return "Retraining %s: %d%% success chance\n%s"%[str(trainee.moves[training_move].name),roundi(GameData.move_training_chance(trainee,helpers)),preserve_line]
	return "%s would gain %d EXP.\n%s"%[trainee_name,GameData.exp_training_reward(trainee,helpers),preserve_line]

func training_roll()->float:
	return training_rng.randf() if training_rng!=null else randf()

# "" when training can run with the current slots, otherwise the reason it cannot.
func training_problem()->String:
	if training_trainee<0 or training_trainee>=roster.size():return "Drag a Quiblet into the trainee slot first."
	var trainee:Dictionary=roster[training_trainee];var trainee_name:=GameData.display_name(trainee)
	if training_helper_indices().is_empty():return "Add at least one helper."
	if training_mode=="move" and GameData.retrain_pool(trainee).is_empty():return "%s already knows every move it can learn."%trainee_name
	if training_mode=="move" and (training_move<0 or training_move>=trainee.moves.size()):return "Click one of %s's moves to retrain."%trainee_name
	return ""

func training_helper_indices()->Array[int]:
	var helper_indices:Array[int]=[]
	for roster_index in training_helpers:
		if roster_index>=0 and roster_index<roster.size() and roster_index!=training_trainee:helper_indices.append(roster_index)
	return helper_indices

# Training consumes helpers and food, so the TRAIN button asks first: the dialog
# names the trainee and what it will do, and lists every helper with its chance to stay.
func request_training()->void:
	var problem:=training_problem()
	if problem!="":toast(problem,GameData.COLORS.coral);return
	if content.find_child("TrainingConfirmation",true,false)!=null:return
	var trainee:Dictionary=roster[training_trainee];var trainee_name:=GameData.display_name(trainee)
	var shade:=ColorRect.new();shade.name="TrainingConfirmation";shade.color=Color(0,0,0,.72);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;shade.z_index=100;content.add_child(shade)
	var menu:=panel(Rect2(370,190,540,320),Color("#fffdf7"),20);shade.add_child(menu)
	label(menu,"START TRAINING?",Vector2(30,28),25,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,480)
	var what:String=("Retrain %s's %s for a new move."%[trainee_name,str(trainee.moves[training_move].name)]) if training_mode=="move" else "Give %s EXP from its helpers."%trainee_name
	label(menu,what,Vector2(42,78),14,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,456)
	var helper_lines:Array[String]=[]
	for roster_index in training_helper_indices():
		var helper:Dictionary=roster[roster_index]
		helper_lines.append("%s (Lv. %d) • %d%% chance to stay"%[GameData.display_name(helper),int(helper.level),roundi(GameData.helper_preservation_chance(helper,training_foods))])
	label(menu,"Helpers are consumed unless they stay:",Vector2(42,110),12,GameData.COLORS.berry,true,HORIZONTAL_ALIGNMENT_LEFT,456)
	label(menu,"\n".join(helper_lines),Vector2(42,130),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,456)
	var foods:Array=training_foods.filter(func(food):return not str(food).is_empty())
	label(menu,("Food used: "+", ".join(foods)) if not foods.is_empty() else "No food added.",Vector2(42,196),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,456)
	var cancel:=add_button(menu,"CANCEL",Vector2(45,236),Vector2(205,54),shade.queue_free,"plain");cancel.name="CancelTraining"
	var confirm:=add_button(menu,"TRAIN",Vector2(270,236),Vector2(225,54),func():shade.queue_free();run_training(),"gold");confirm.name="ConfirmTraining"

func run_training()->void:
	var problem:=training_problem()
	if problem!="":toast(problem,GameData.COLORS.coral);return
	var trainee:Dictionary=roster[training_trainee];var trainee_name:=GameData.display_name(trainee)
	var helper_indices:Array[int]=training_helper_indices()
	var helpers:Array=[];for roster_index in helper_indices:helpers.append(roster[roster_index])
	var foods:Array[String]=training_foods.filter(func(food):return not str(food).is_empty())
	var result:={"mode":training_mode,"foods":foods.duplicate(),"helpers":helpers.size()}
	if training_mode=="move":
		var chance:=GameData.move_training_chance(trainee,helpers);var roll:=training_roll()*100.0
		result.merge({"chance":chance,"roll":roll,"success":roll<chance})
		if result.success:
			# Replace the chosen move with a weighted pick from the learnable pool; the
			# pool never contains moves already in a slot, so the moveset always changes.
			var learned:=GameData.pick_retrain_move(trainee,training_roll());var entry:Dictionary=trainee.moves[training_move];var retrained:String=str(entry.name)
			refund_move_stones(trainee,training_move)
			entry.name=learned
			if not trainee.memory.has(learned):trainee.memory.append(learned)
			result.merge({"learned":learned,"retrained":retrained})
		else:result.retrained=str(trainee.moves[training_move].name)
	else:
		var reward:=GameData.exp_training_reward(trainee,helpers);var level_before:=int(trainee.level)
		grant_training_exp(trainee,reward)
		result.merge({"exp":reward,"level_before":level_before,"level_after":int(trainee.level),"success":true})
	# Food is spent, then every helper rolls to stay; the rest are consumed.
	for food in foods:ingredients[food]=maxi(0,int(ingredients.get(food,0))-1)
	var preserved:Array[String]=[];var consumed:Array[String]=[];var consumed_indices:Array[int]=[]
	for roster_index in helper_indices:
		var helper:Dictionary=roster[roster_index];var keep_chance:=GameData.helper_preservation_chance(helper,foods)
		if training_roll()*100.0<keep_chance:preserved.append(GameData.display_name(helper))
		else:consumed.append(GameData.display_name(helper));consumed_indices.append(roster_index)
	result.merge({"preserved":preserved,"consumed":consumed})
	var trainee_uid:=str(trainee.get("uid",""))
	consumed_indices.sort();consumed_indices.reverse()
	for roster_index in consumed_indices:remove_roster_member(roster_index)
	training_trainee=find_roster_index(trainee_uid);training_helpers=[-1,-1,-1,-1];training_foods=["",""]
	last_training_result=result
	var outcome:String
	if training_mode=="move":outcome="%s retrained %s into %s!"%[trainee_name,result.retrained,result.learned] if result.success else "Training failed at %d%%. %s keeps %s."%[roundi(result.chance),trainee_name,result.retrained]
	else:outcome="%s gained %d EXP (Lv. %d → %d)."%[trainee_name,int(result.exp),int(result.level_before),int(result.level_after)]
	var fate:String=("Kept: "+", ".join(preserved)+". " if not preserved.is_empty() else "")+("Consumed: "+", ".join(consumed)+"." if not consumed.is_empty() else "")
	toast(outcome+" "+fate,GameData.COLORS.leaf if bool(result.success) else GameData.COLORS.coral)
	show_training()

func find_roster_index(uid:String)->int:
	for index in roster.size():
		if str(roster[index].get("uid",""))==uid:return index
	return -1

func remove_roster_member(index:int)->void:
	# Drop a Quiblet and shift every stored roster index that pointed past it.
	if index<0 or index>=roster.size() or roster.size()<=1:return
	roster.remove_at(index)
	var shifted:Array[int]=[]
	for team_index in team_indices:
		if team_index==index:continue
		shifted.append(team_index-1 if team_index>index else team_index)
	team_indices=shifted
	if team_indices.is_empty():team_indices.append(0)
	if selected_roster>index:selected_roster-=1
	selected_roster=clampi(selected_roster,0,roster.size()-1)
	if training_trainee>index:training_trainee-=1
	elif training_trainee==index:training_trainee=-1
	for i in 4:
		if training_helpers[i]>index:training_helpers[i]-=1
		elif training_helpers[i]==index:training_helpers[i]=-1

func refund_move_stones(q:Dictionary,move_index:int)->void:
	var moves:Array=q.moves;var entry:Dictionary=moves[move_index]
	while not entry.stones.is_empty():
		var value:String=str(entry.stones[0])
		if value.begins_with("link:"):
			for target in moves:
				if target.name==value.trim_prefix("link:"):target.stones.erase("link_from:"+str(entry.name))
		elif value.begins_with("link_from:"):
			for source in moves:
				if source.name==value.trim_prefix("link_from:"):source.stones.erase("link:"+str(entry.name))
		entry.stones.remove_at(0)
		var effect:=GameData.stone_effect(value)
		if not effect.is_empty():move_stone_inventory[effect]=int(move_stone_inventory.get(effect,0))+1

func grant_training_levels(q:Dictionary,levels:float)->void:
	var whole:=floori(levels);var fraction:=levels-whole
	for i in whole:grant_training_exp(q,GameData.exp_to_level(int(q.level))-int(q.exp))
	grant_training_exp(q,roundi(fraction*GameData.exp_to_level(int(q.level))))

func transfer_training(partner_index:int,amount:int)->void:
	# Legacy helper: the target receives the EXP and the helper keeps 15% of what it contributed.
	if partner_index<0 or partner_index>=roster.size() or selected_roster<0 or selected_roster>=roster.size() or partner_index==selected_roster:return
	var target:Dictionary=roster[selected_roster];var helper:Dictionary=roster[partner_index];var helper_exp:=roundi(amount*.15)
	grant_training_exp(target,amount);grant_training_exp(helper,helper_exp)
	toast("Training: %s +%d EXP • %s +%d EXP"%[GameData.display_name(target),amount,GameData.display_name(helper),helper_exp],GameData.COLORS.leaf);show_training()

func grant_training_exp(q:Dictionary,amount:int)->void:
	q.exp+=maxi(0,amount)
	while int(q.exp)>=GameData.exp_to_level(int(q.level)):
		q.exp-=GameData.exp_to_level(int(q.level));q.level+=1
		if int(q.level)%25==0:apply_milestone(q)

func apply_arrival_milestones(q:Dictionary)->void:
	for milestone in int(q.level)/25:apply_milestone(q)

func apply_milestone(q:Dictionary)->void:
	var both:bool=q.prodigy;q.prodigy=false
	var slot_outcome:=randf()<.7
	if both or slot_outcome:
		var candidates:Array=q.moves.filter(func(m):return int(m.slots)<MAX_MOVE_STONE_SLOTS)
		if not candidates.is_empty():candidates.pick_random().slots+=1
	if both or not slot_outcome:
		if q.moves.size()<4:
			var unknown:Array=GameData.learnset(int(q.species)).filter(func(name):return not q.memory.has(name))
			if not unknown.is_empty():var learned:String=unknown.pick_random();q.moves.append({"name":learned,"slots":1,"stones":[]});q.memory.append(learned)

func use_charm(kind:String)->void:
	var q:Dictionary=roster[selected_roster];var item:="Health Charm" if kind=="health" else "Attack Charm"
	if int(special_items[item])<=0:toast("You don’t have that charm.",GameData.COLORS.coral);return
	var problem:=charm_problem(q,kind)
	if problem!="":toast(problem,GameData.COLORS.coral);return
	apply_charm(q,kind);special_items[item]-=1;show_training();toast("Permanent %s growth improved."%kind,GameData.COLORS.gold)

func charm_problem(q:Dictionary,kind:String)->String:
	var dedicated:String="health_charms" if kind=="health" else "attack_charms"
	if int(q[dedicated])<3 or int(q.flex_health)+int(q.flex_attack)<3:return ""
	return "No compatible charm slot is open."

func apply_charm(q:Dictionary,kind:String)->void:
	var dedicated:String="health_charms" if kind=="health" else "attack_charms";var flex:String="flex_health" if kind=="health" else "flex_attack"
	if int(q[dedicated])<3:q[dedicated]+=1
	else:q[flex]+=1

# --- Special item use ---------------------------------------------------------
# Quiblet items target one roster member and stone items target one Power Stone
# in the inventory, both through the USE screen reached from Resources. The rest
# are used in place: cooking slots, the level-select toggles, and locked caches.
const QUIBLET_ITEMS:=["Health Charm","Attack Charm","Memory Fruit","Move Crystal","Echo Crystal","Growth Fruit","Prodigy Fruit"]
const SPECIAL_ITEM_USAGE:={"Bountiful Berry":"used in a Cooking special slot","Empty Leftover Jar":"used in a Cooking special slot","Fortune Charm":"toggled on level select","Challenger's Charm":"toggled on level select","Treasure Key":"used at locked expedition caches"}
var item_use:={}

func item_use_screen_supported(item:String)->bool:
	return item in QUIBLET_ITEMS

func remembered_moves(q:Dictionary)->Array[String]:
	var result:Array[String]=[];var current:Array=q.moves.map(func(move):return str(move.name))
	for name in q.get("memory",[]):
		if not current.has(str(name)) and not result.has(str(name)):result.append(str(name))
	return result

func fitted_move_stones(q:Dictionary)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for move_index in q.moves.size():
		for value in q.moves[move_index].stones:
			if str(value).begins_with("link_from:"):continue
			result.append({"move_index":move_index,"value":str(value),"effect":str(value).split(":")[0],"move":str(q.moves[move_index].name)})
	return result

func begin_item_use(item:String)->void:
	item_use={"item":item,"roster_index":-1,"move_index":-1,"memory_move":"","stone_index":-1,"stone_value":""}

func show_item_use(item:String)->void:
	if not item_use_screen_supported(item):show_resources();return
	if str(item_use.get("item",""))!=item:begin_item_use(item)
	screen="item_use";clear_content();add_menu_backdrop()
	var left:=panel(Rect2(30,68,585,624),Color("#fffaf0"),18);content.add_child(left);left.name="ItemUseTargets"
	label(left,"%s  × %d"%[item,int(special_items.get(item,0))],Vector2(22,16),20,GameData.COLORS.ink,true)
	label(left,str(SPECIAL_ITEM_DESCRIPTIONS.get(item,"")),Vector2(22,46),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,540)
	label(left,"Choose a Quiblet:",Vector2(22,74),13,GameData.COLORS.berry,true)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(16,100);scroll.size=Vector2(552,508);left.add_child(scroll)
	var list:=VBoxContainer.new();list.name="ItemTargetList";list.custom_minimum_size=Vector2(530,0);list.add_theme_constant_override("separation",6);scroll.add_child(list)
	for roster_index in roster.size():
		var q:Dictionary=roster[roster_index];var chosen:bool=roster_index==int(item_use.roster_index)
		var button:=add_button(list,"%s   Lv. %d"%[GameData.display_name(q),int(q.level)],Vector2.ZERO,Vector2(530,40),func(index=roster_index):item_use.roster_index=index;item_use.move_index=-1;item_use.memory_move="";item_use.stone_value="";show_item_use(item),"leaf" if chosen else "plain")
		button.custom_minimum_size=Vector2(530,40);button.name="ItemTarget%d"%roster_index
	var right:=panel(Rect2(635,68,615,624),Color("#f7f3ff"),18);content.add_child(right);right.name="ItemUseDetail"
	build_item_use_detail(right)
	add_back_button(content,BACK_BUTTON_POSITION,show_resources)

# Growth Fruit target: the average level of the team members other than the
# Quiblet itself, so growing it never moves its own goal.
func growth_target_level(q:Dictionary)->int:
	var total:=0;var count:=0
	for index in team_indices:
		if index>=0 and index<roster.size() and roster[index]!=q:total+=int(roster[index].level);count+=1
	return total/count if count>0 else 0

func item_use_target()->Dictionary:
	var index:=int(item_use.get("roster_index",-1))
	return roster[index] if index>=0 and index<roster.size() else {}

func add_choice_button(parent:Node,text:String,chosen:bool,callback:Callable,name_hint:String)->Button:
	var button:=add_button(parent,text,Vector2.ZERO,Vector2(571,36),callback,"leaf" if chosen else "plain");button.custom_minimum_size=Vector2(571,36);button.name=name_hint;return button

func build_item_use_detail(parent:Control)->void:
	var item:String=str(item_use.get("item",""))
	var q:=item_use_target()
	if q.is_empty():label(parent,"Pick a Quiblet on the left.",Vector2(22,22),16,GameData.COLORS.muted);add_item_use_footer(parent);return
	label(parent,"%s   Lv. %d"%[GameData.display_name(q),int(q.level)],Vector2(22,16),20,GameData.COLORS.ink,true)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(22,52);scroll.size=Vector2(571,400);parent.add_child(scroll)
	var choices:=VBoxContainer.new();choices.name="ItemChoiceList";choices.custom_minimum_size=Vector2(571,0);choices.add_theme_constant_override("separation",6);scroll.add_child(choices)
	match item:
		"Memory Fruit":
			var remembered:=remembered_moves(q)
			label(choices,"Remembered move to restore:" if not remembered.is_empty() else "This Quiblet has no forgotten moves.",Vector2.ZERO,13,GameData.COLORS.berry,true)
			for name in remembered:add_choice_button(choices,name,name==str(item_use.memory_move),func(pick=name):item_use.memory_move=pick;show_item_use(item),"MemoryChoice")
			if q.moves.size()>=4 and not str(item_use.memory_move).is_empty():
				label(choices,"Slot to replace (fitted Move Stones return to the inventory):",Vector2.ZERO,13,GameData.COLORS.berry,true)
				for move_index in q.moves.size():add_choice_button(choices,str(q.moves[move_index].name),move_index==int(item_use.move_index),func(pick=move_index):item_use.move_index=pick;show_item_use(item),"SlotChoice")
		"Move Crystal":
			label(choices,"Move that gains a Move Stone slot (max %d):"%MAX_MOVE_STONE_SLOTS,Vector2.ZERO,13,GameData.COLORS.berry,true)
			for move_index in q.moves.size():
				var entry:Dictionary=q.moves[move_index]
				var button:=add_choice_button(choices,"%s   (%d slots)"%[entry.name,int(entry.slots)],move_index==int(item_use.move_index),func(pick=move_index):item_use.move_index=pick;show_item_use(item),"SlotChoice")
				button.disabled=int(entry.slots)>=MAX_MOVE_STONE_SLOTS
		"Echo Crystal":
			var fitted:=fitted_move_stones(q)
			label(choices,"Fitted Move Stone to copy into the inventory:" if not fitted.is_empty() else "This Quiblet has no fitted Move Stones.",Vector2.ZERO,13,GameData.COLORS.berry,true)
			for fit in fitted:add_choice_button(choices,"%s on %s"%[GameData.stone_info(fit.effect).name,fit.move],fit.value==str(item_use.stone_value) and int(fit.move_index)==int(item_use.move_index),func(pick=fit):item_use.stone_value=pick.value;item_use.move_index=pick.move_index;show_item_use(item),"StoneChoice")
	add_item_use_footer(parent)

# Preview text plus the USE button, which is disabled until the selection is valid.
func add_item_use_footer(parent:Control)->void:
	var preview:=label(parent,item_use_preview(),Vector2(22,466),14,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_LEFT,571);preview.name="ItemUsePreview"
	var use:=add_button(parent,"USE %s"%str(item_use.get("item","")).to_upper(),Vector2(22,548),Vector2(571,54),apply_item_use,"gold");use.name="UseItemButton";use.disabled=item_use_problem()!=""

# "" when the current selection can be applied, otherwise the reason it cannot.
func item_use_problem()->String:
	var item:String=str(item_use.get("item",""))
	if int(special_items.get(item,0))<=0:return "You don’t have that item."
	if not item in QUIBLET_ITEMS:return "That item is not used from this screen."
	var q:=item_use_target()
	if q.is_empty():return "Choose a Quiblet."
	match item:
		"Health Charm":return charm_problem(q,"health")
		"Attack Charm":return charm_problem(q,"attack")
		"Memory Fruit":
			if remembered_moves(q).is_empty():return "%s has no forgotten moves to restore."%GameData.display_name(q)
			if str(item_use.memory_move).is_empty():return "Choose a remembered move."
			if q.moves.size()>=4 and int(item_use.move_index)<0:return "Choose a slot to replace."
		"Move Crystal":
			var index:=int(item_use.move_index)
			if index<0 or index>=q.moves.size():return "Choose a move."
			if int(q.moves[index].slots)>=MAX_MOVE_STONE_SLOTS:return "That move already has %d Move Stone slots."%MAX_MOVE_STONE_SLOTS
		"Echo Crystal":
			if fitted_move_stones(q).is_empty():return "%s has no fitted Move Stones to copy."%GameData.display_name(q)
			if str(item_use.stone_value).is_empty():return "Choose a fitted Move Stone."
		"Growth Fruit":
			if growth_target_level(q)<=0:return "Growth Fruit needs other team members to grow toward."
			if int(q.level)>=growth_target_level(q):return "%s is already at its teammates' average level."%GameData.display_name(q)
		"Prodigy Fruit":
			if q.get("prodigy",false):return "%s already carries a Prodigy blessing."%GameData.display_name(q)
	return ""

func item_use_preview()->String:
	var problem:=item_use_problem()
	if problem!="":return problem
	var item:String=str(item_use.get("item",""))
	var q:=item_use_target()
	match item:
		"Health Charm":return "Adds a permanent HP growth charm to %s."%GameData.display_name(q)
		"Attack Charm":return "Adds a permanent Attack growth charm to %s."%GameData.display_name(q)
		"Memory Fruit":return "Restores %s%s."%[item_use.memory_move,"" if q.moves.size()<4 else " in place of %s"%q.moves[int(item_use.move_index)].name]
		"Move Crystal":return "%s gains a Move Stone slot (%d → %d)."%[q.moves[int(item_use.move_index)].name,int(q.moves[int(item_use.move_index)].slots),int(q.moves[int(item_use.move_index)].slots)+1]
		"Echo Crystal":return "Copies the fitted %s into the inventory; the original stays fitted."%GameData.stone_info(str(item_use.stone_value).split(":")[0]).name
		"Growth Fruit":return "%s grows from Lv. %d to its teammates' average Lv. %d."%[GameData.display_name(q),int(q.level),growth_target_level(q)]
		"Prodigy Fruit":return "%s's next Lv. 25 milestone grants both a Move Stone slot and a new move."%GameData.display_name(q)
	return ""

func apply_item_use()->void:
	var problem:=item_use_problem()
	if problem!="":toast(problem,GameData.COLORS.coral);return
	var item:String=str(item_use.item);var message:=item_use_preview()
	apply_quiblet_item(item,item_use_target())
	special_items[item]-=1
	toast(message,GameData.COLORS.gold)
	if int(special_items[item])<=0:item_use={};show_resources()
	else:item_use.move_index=-1;item_use.memory_move="";item_use.stone_value="";show_item_use(item)

func apply_quiblet_item(item:String,q:Dictionary)->void:
	match item:
		"Health Charm":apply_charm(q,"health")
		"Attack Charm":apply_charm(q,"attack")
		"Memory Fruit":
			var restored:String=str(item_use.memory_move)
			if q.moves.size()<4:q.moves.append({"name":restored,"slots":1,"stones":[]})
			else:
				var index:=int(item_use.move_index);refund_move_stones(q,index);q.moves[index].name=restored
			if not q.memory.has(restored):q.memory.append(restored)
		"Move Crystal":q.moves[int(item_use.move_index)].slots=int(q.moves[int(item_use.move_index)].slots)+1
		"Echo Crystal":
			var effect:String=str(item_use.stone_value).split(":")[0];move_stone_inventory[effect]=int(move_stone_inventory.get(effect,0))+1
		"Growth Fruit":
			var target_level:=growth_target_level(q)
			while int(q.level)<target_level:
				q.level=int(q.level)+1
				if int(q.level)%25==0:apply_milestone(q)
			q.exp=0
		"Prodigy Fruit":q.prodigy=true

# ---- Stone Workshop ---------------------------------------------------------
# Combiner, Revitalizer, Converter, and Reforger act on unfitted inventory
# Power Stones from one menu. Nothing is spent but the stones themselves: the
# Combiner and Reforger consume inputs, the other two only change the stone.
const STONE_WORKSHOP_MODES:={
	"combine":{"title":"COMBINER","blurb":"Fuse 2–4 stones of one stat type that each carry a bonus. The result keeps the LOWEST input power, gains every bonus (matching stats add up), and its material follows its distinct stats: 2 Silver, 3 Gold, 4 Diamond, 5+ Obsidian. One Obsidian at most; every input is consumed. A stat holds at most 3 rolls per stone, and each stat's total across a Quiblet's equipped stones is capped."},
	"revitalize":{"title":"REVITALIZER","blurb":"Raise an old stone's power to 90% of the average drop at your highest reached loot tier. Type, bonuses, and everything else stay."},
	"convert":{"title":"CONVERTER","blurb":"Turn a Health stone into an Attack stone, or an Attack stone into a Health stone. Power and bonuses are untouched."},
	"reforge":{"title":"REFORGER","blurb":"Pick one bonus on a stone and consume a second stone that has a bonus. The picked bonus is replaced with a fresh random stat the stone does not already carry."}
}
var stone_workshop:={"mode":"combine","selected":[],"sacrifice":-1,"bonus_index":-1}

# The strongest node the player has reached: every node up to an island's
# progress, on islands that are the first, already started, or follow a cleared boss.
func highest_reached_stage_level()->int:
	var best:=int(area_level_data(0,0).level)
	for area_index in area_progress.size():
		var reached:bool=area_index==0 or int(area_progress[area_index])>0 or int(area_progress[area_index-1])>=7
		if not reached:continue
		for level_index in range(0,clampi(int(area_progress[area_index]),0,7)+1):best=maxi(best,int(area_level_data(area_index,level_index).level))
	return best

func workshop_loot_tier()->int:
	return GameData.power_stone_tier_for_level(highest_reached_stage_level())

func workshop_stone(index:int)->Dictionary:
	return GameData.normalize_power_stone(power_stone_inventory[index]) if index>=0 and index<power_stone_inventory.size() else {}

func workshop_selected_stones()->Array:
	var stones:Array=[]
	for index in stone_workshop.selected:
		var stone:=workshop_stone(int(index))
		if not stone.is_empty():stones.append(stone)
	return stones

func begin_stone_workshop(mode:String="combine")->void:
	stone_workshop={"mode":mode,"selected":[],"sacrifice":-1,"bonus_index":-1}

func set_stone_workshop_mode(mode:String)->void:
	begin_stone_workshop(mode);show_stone_workshop()

# Clicking a stone toggles it. Combiner collects up to four inputs; Reforger
# takes the stone to reforge first and the stone to consume second; the other
# modes hold a single stone.
func workshop_pick_stone(index:int)->void:
	var mode:String=str(stone_workshop.mode);var selected:Array=stone_workshop.selected
	if selected.has(index):selected.erase(index)
	elif index==int(stone_workshop.sacrifice):stone_workshop.sacrifice=-1
	elif mode=="combine":
		if selected.size()>=GameData.COMBINE_MAX_STONES:toast("At most %d stones can be combined at once."%GameData.COMBINE_MAX_STONES,GameData.COLORS.coral);return
		selected.append(index)
	elif mode=="reforge":
		if selected.is_empty():selected.append(index);stone_workshop.bonus_index=-1
		else:stone_workshop.sacrifice=index
	else:selected.clear();selected.append(index)
	if selected.is_empty():stone_workshop.sacrifice=-1;stone_workshop.bonus_index=-1
	show_stone_workshop()

# "" when the current selection can be applied, otherwise the reason it cannot.
func workshop_problem()->String:
	var stones:=workshop_selected_stones()
	match str(stone_workshop.mode):
		"combine":return GameData.combine_problem(stones)
		"revitalize":
			if stones.is_empty():return "Choose a Power Stone."
			if GameData.revitalized_power(stones[0],workshop_loot_tier())<=int(stones[0].power):return "That stone is already at or above %d power, 90%% of the average T%d drop."%[roundi(GameData.power_stone_drop_average(workshop_loot_tier())*GameData.REVITALIZE_SHARE),workshop_loot_tier()]
		"convert":
			if stones.is_empty():return "Choose a Power Stone."
		"reforge":return GameData.reforge_problem(stones[0] if not stones.is_empty() else {},workshop_stone(int(stone_workshop.sacrifice)),int(stone_workshop.bonus_index))
	return ""

# The stone the selection would produce, or {} while it is incomplete. The
# Reforger's fresh stat is random, so its preview keeps the chosen line marked.
func workshop_result()->Dictionary:
	if workshop_problem()!="":return {}
	var stones:=workshop_selected_stones()
	match str(stone_workshop.mode):
		"combine":return GameData.combine_power_stones(stones)
		"revitalize":return GameData.revitalize_power_stone(stones[0],workshop_loot_tier())
		"convert":return GameData.convert_power_stone(stones[0])
		"reforge":return stones[0]
	return {}

func workshop_preview_text()->String:
	var problem:=workshop_problem()
	if problem!="":return problem
	var stones:=workshop_selected_stones();var result:=workshop_result()
	match str(stone_workshop.mode):
		"combine":
			var rolls:Dictionary=GameData.bonus_roll_counts(stones.map(func(stone):return stone.bonuses))
			var lost:String=(" %d roll%s beyond the %d-per-stat limit %s lost."%[int(rolls.lost),"" if int(rolls.lost)==1 else "s",GameData.MAX_BONUS_STACKS,"is" if int(rolls.lost)==1 else "are"]) if int(rolls.lost)>0 else ""
			return "Combines %d stones into a %s %s stone with %d power and %d bonus stat%s. The inputs are consumed.%s"%[stones.size(),result.quality,result.type,int(result.power),result.bonuses.size(),"" if result.bonuses.size()==1 else "s",lost]
		"revitalize":return "Power %d → %d (90%% of the average T%d drop, %d)."%[int(stones[0].power),int(result.power),workshop_loot_tier(),GameData.power_stone_drop_average(workshop_loot_tier())]
		"convert":return "Becomes a%s %s stone with the same %d power and bonuses."%["n" if result.type=="Attack" else "",result.type,int(result.power)]
		"reforge":
			var sacrifice:=workshop_stone(int(stone_workshop.sacrifice))
			return "Replaces %s with a fresh random stat. The %s %s stone (%d power) is consumed."%[GameData.bonus_name(stones[0].bonuses[int(stone_workshop.bonus_index)]),sacrifice.quality,sacrifice.type,int(sacrifice.power)]
	return ""

func workshop_hint()->String:
	match str(stone_workshop.mode):
		"combine":return "Click 2–4 stones to add them (%d chosen)."%stone_workshop.selected.size()
		"revitalize":return "Click a stone. Loot tier T%d (average drop %d) → revitalized power %d."%[workshop_loot_tier(),GameData.power_stone_drop_average(workshop_loot_tier()),roundi(GameData.power_stone_drop_average(workshop_loot_tier())*GameData.REVITALIZE_SHARE)]
		"convert":return "Click a stone to convert."
		"reforge":return "Click the stone to reforge, choose its bonus, then click the stone to consume."
	return ""

func show_stone_workshop()->void:
	screen="stone_workshop";clear_content();add_menu_backdrop()
	var mode:String=str(stone_workshop.mode)
	if not STONE_WORKSHOP_MODES.has(mode):begin_stone_workshop();mode="combine"
	var left:=panel(Rect2(30,68,585,624),Color("#fffaf0"),18);content.add_child(left);left.name="StoneWorkshop"
	label(left,"STONE WORKSHOP",Vector2(22,14),20,GameData.COLORS.ink,true)
	var x:=22
	for key in STONE_WORKSHOP_MODES:
		var tab:=add_button(left,STONE_WORKSHOP_MODES[key].title,Vector2(x,46),Vector2(132,34),func(pick=key):set_stone_workshop_mode(pick),"leaf" if key==mode else "plain");tab.name="WorkshopMode_%s"%key;x+=137
	label(left,STONE_WORKSHOP_MODES[mode].blurb,Vector2(22,86),12,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,540)
	label(left,workshop_hint(),Vector2(22,164),13,GameData.COLORS.berry,true,HORIZONTAL_ALIGNMENT_LEFT,540)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(16,200);scroll.size=Vector2(552,406);left.add_child(scroll)
	var grid:=GridContainer.new();grid.name="WorkshopGrid";grid.columns=6;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);scroll.add_child(grid)
	var entries:Array=all_power_stone_entries()
	for data in entries:
		var fitted:bool=data.get("fitted",false);var index:=int(data.get("inventory_index",-1))
		var role:String="input" if not fitted and stone_workshop.selected.has(index) else ("sacrifice" if not fitted and index==int(stone_workshop.sacrifice) else "")
		var card:=STONE_CARD_SCRIPT.new();card.name=("WorkshopFitted%d_%d"%[int(data.roster_index),int(data.slot_index)]) if fitted else "WorkshopStone%d"%index;card.custom_minimum_size=Vector2(80,80);card.size=Vector2(80,80)
		var style:=StyleBoxFlat.new();style.bg_color=Color("#d7dbdd") if fitted else (Color.WHITE if role=="" else (Color("#e3f5e6") if role=="input" else Color("#fde7e0")));style.border_color=Color("#b9c1bc") if fitted else (Color("#d4ddd5") if role=="" else (GameData.COLORS.leaf if role=="input" else GameData.COLORS.coral));style.set_border_width_all(1 if role=="" else 3);style.set_corner_radius_all(11);card.add_theme_stylebox_override("panel",style)
		grid.add_child(card);card.setup(data)
		if fitted:card.chosen.connect(func(picked):toast("That stone is fitted on %s. Take it off the Quiblet first."%str(picked.get("owner","")),GameData.COLORS.coral))
		else:card.chosen.connect(func(picked):workshop_pick_stone(int(picked.inventory_index)))
		var icon:=add_power_stone_icon(card,data,Vector2(8,8),Vector2(64,64))
		if fitted:decorate_fitted_stone_card(card,icon,data)
	if entries.is_empty():label(scroll,"No Power Stones owned yet.",Vector2.ZERO,13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,540)
	elif power_stone_inventory.is_empty():label(scroll,"Every owned stone is fitted on a Quiblet. Take one off to rework it.",Vector2(0,100),13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,540)
	var right:=panel(Rect2(635,68,615,624),Color("#f7f3ff"),18);content.add_child(right);right.name="WorkshopDetail"
	build_stone_workshop_detail(right)
	add_back_button(content,BACK_BUTTON_POSITION,show_resources)

func add_workshop_stone_row(parent:Node,stone:Dictionary,caption:String,name_hint:String)->Panel:
	var lines:Array[String]=[]
	for bonus in stone.bonuses:lines.append(GameData.bonus_description(bonus))
	var bonus_text:String="; ".join(lines) if not lines.is_empty() else "No bonus stats."
	# The row grows with its bonus text, so an Obsidian stone's many lines stay readable.
	var text_width:float=ThemeDB.fallback_font.get_string_size(bonus_text,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
	var height:=maxi(74,38+15*ceili(text_width/440.0))
	var row:=panel(Rect2(0,0,571,height),Color.WHITE,10);row.custom_minimum_size=Vector2(571,height);row.name=name_hint;parent.add_child(row)
	add_power_stone_icon(row,stone,Vector2(8,10),Vector2(54,54))
	if not caption.is_empty():label(row,caption,Vector2(470,7),10,GameData.COLORS.berry,true,HORIZONTAL_ALIGNMENT_RIGHT,92)
	label(row,"%s %s • T%d • +%d %s"%[stone.quality,stone.type,int(stone.tier),int(stone.power),"max HP" if stone.type=="Health" else "Attack"],Vector2(72,8),14,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,390)
	label(row,bonus_text,Vector2(72,30),10,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,488)
	return row

func build_stone_workshop_detail(parent:Control)->void:
	var mode:String=str(stone_workshop.mode);var stones:=workshop_selected_stones()
	label(parent,STONE_WORKSHOP_MODES[mode].title,Vector2(22,16),20,GameData.COLORS.ink,true)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(22,52);scroll.size=Vector2(571,404);parent.add_child(scroll)
	var rows:=VBoxContainer.new();rows.name="WorkshopRows";rows.custom_minimum_size=Vector2(571,0);rows.add_theme_constant_override("separation",6);scroll.add_child(rows)
	if stones.is_empty():label(rows,"Pick a Power Stone on the left.",Vector2.ZERO,15,GameData.COLORS.muted)
	for stone in stones:add_workshop_stone_row(rows,stone,"INPUT" if mode=="combine" else "STONE","WorkshopInput")
	if mode=="reforge" and not stones.is_empty():
		label(rows,"Bonus to reroll:",Vector2.ZERO,13,GameData.COLORS.berry,true)
		for bonus_index in stones[0].bonuses.size():
			add_choice_button(rows,GameData.bonus_description(stones[0].bonuses[bonus_index]),bonus_index==int(stone_workshop.bonus_index),func(pick=bonus_index):stone_workshop.bonus_index=pick;show_stone_workshop(),"ReforgeBonusChoice")
		var sacrifice:=workshop_stone(int(stone_workshop.sacrifice))
		if sacrifice.is_empty():label(rows,"Then click a second stone with a bonus to consume.",Vector2.ZERO,13,GameData.COLORS.muted)
		else:add_workshop_stone_row(rows,sacrifice,"CONSUMED","WorkshopSacrifice")
	var result:=workshop_result()
	if not result.is_empty() and mode!="reforge":
		label(rows,"RESULT",Vector2.ZERO,13,GameData.COLORS.berry,true)
		add_workshop_stone_row(rows,result,"","WorkshopResult")
	var preview:=label(parent,workshop_preview_text(),Vector2(22,466),14,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_LEFT,571);preview.name="WorkshopPreview"
	var apply:=add_button(parent,"APPLY %s"%STONE_WORKSHOP_MODES[mode].title,Vector2(22,548),Vector2(571,54),apply_stone_workshop,"gold");apply.name="WorkshopApply";apply.disabled=workshop_problem()!=""

func apply_stone_workshop()->void:
	var problem:=workshop_problem()
	if problem!="":toast(problem,GameData.COLORS.coral);return
	var mode:String=str(stone_workshop.mode);var message:=workshop_preview_text();var consumed:Array=[]
	var target_index:=int(stone_workshop.selected[0]);var stones:=workshop_selected_stones()
	match mode:
		"combine":
			consumed=stone_workshop.selected.duplicate();power_stone_inventory.append(GameData.combine_power_stones(stones))
		"revitalize":power_stone_inventory[target_index]=GameData.revitalize_power_stone(stones[0],workshop_loot_tier())
		"convert":power_stone_inventory[target_index]=GameData.convert_power_stone(stones[0])
		"reforge":
			var before:=GameData.bonus_name(stones[0].bonuses[int(stone_workshop.bonus_index)])
			var reforged:=GameData.reforge_power_stone(stones[0],int(stone_workshop.bonus_index));power_stone_inventory[target_index]=reforged
			message="Reforged: %s became %s."%[before,GameData.bonus_description(reforged.bonuses[int(stone_workshop.bonus_index)])]
			consumed=[int(stone_workshop.sacrifice)]
	consumed.sort();consumed.reverse()
	for index in consumed:power_stone_inventory.remove_at(int(index))
	selected_inventory_item={}
	begin_stone_workshop(mode);toast(message,GameData.COLORS.gold);show_stone_workshop()

func show_map()->void:
	screen="map";clear_content()
	map_page=clampi(map_page,0,map_page_count()-1)
	build_level_select_world()
	transition_to_expedition_music("map")
	label(content,"CHOOSE AN ISLAND",Vector2(290,34),26,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,700)
	label(content,"Click an island to see its route.",Vector2(290,72),14,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,700)
	add_page_navigation(content,map_page,map_page_count(),Vector2(462,598),356,set_map_page)
	add_back_button(content,BACK_BUTTON_POSITION,func():show_camp())

func map_page_count()->int:
	return ceili(float(GameData.EXPEDITION_AREAS.size())/AREAS_PER_PAGE)

func visible_map_areas()->Array[int]:
	var result:Array[int]=[]
	for index in range(map_page*AREAS_PER_PAGE,mini(GameData.EXPEDITION_AREAS.size(),(map_page+1)*AREAS_PER_PAGE)):result.append(index)
	return result

func set_map_page(page:int)->void:
	map_page=clampi(page,0,map_page_count()-1);show_map()

func map_island_position(local_index:int)->Vector3:
	var count:=visible_map_areas().size()
	return Vector3((local_index-(count-1)*.5)*8.0,0,0)

func map_area_at_point(point:Vector3)->int:
	var indices:=visible_map_areas()
	for local_index in indices.size():
		var island:=map_island_position(local_index)
		if Vector2(point.x,point.z).distance_to(Vector2(island.x,island.z))<=3.4:return indices[local_index]
	return -1

func build_expedition_hud()->void:
	if not is_instance_valid(expedition) or not is_instance_valid(content):return
	var old_hud:Control=content.find_child("ExpeditionHud",false,false)
	if old_hud!=null:content.remove_child(old_hud);old_hud.queue_free()
	var hud:=Control.new();hud.name="ExpeditionHud";hud.position=Vector2.ZERO;hud.size=Vector2(1280,720);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(hud)
	add_texture_button(hud,"res://textures/UI/PauseButton.png",Vector2(26,24),Vector2(40,40),open_expedition_pause,"PauseButton")
	for i in expedition.team.size():
		var actor:QuibletActor3D=expedition.team[i]
		var card:=panel(Rect2(expedition_card_position(i),Vector2(390,66)),Color("#f4fbf6e8"),14);card.name="ExpeditionMoveCard%d"%i;hud.add_child(card)
		# Portrait in the centre, first two moves to its left, remaining moves to its right.
		var portrait:=QuibletPortrait.new();portrait.name="ExpeditionQuibletPortrait%d"%i;portrait.position=Vector2(173,3);portrait.size=Vector2(44,44);portrait.setup(int(actor.data.species),.8);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(portrait)
		var cooldown:=PORTRAIT_COOLDOWN_SCRIPT.new();cooldown.name="ExpeditionPortraitCooldown%d"%i;cooldown.position=portrait.position;cooldown.size=portrait.size;cooldown.setup(actor);card.add_child(cooldown)
		var name_label:=label(card,GameData.display_name(actor.data),Vector2(135,47),9,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,120);name_label.name="ExpeditionQuibletName%d"%i
		for move_index in actor.data.moves.size():
			var button:=ExpeditionMoveButton.new();button.name="ExpeditionMoveButton%d_%d"%[i,move_index];button.size=Vector2(42,42)
			button.position=Vector2(60+move_index*56,12) if move_index<2 else Vector2(232+(move_index-2)*56,12)
			button.setup(actor,move_index);button.move_requested.connect(expedition.manual_move);card.add_child(button)

func expedition_card_position(team_index:int)->Vector2:
	var positions:=[Vector2(445,646),Vector2(870,646),Vector2(870,574),Vector2(20,646),Vector2(20,574)]
	return positions[clampi(team_index,0,positions.size()-1)]

func refresh_expedition_hud()->void:
	if screen!="expedition":return
	build_expedition_hud()

func _process(delta:float)->void:
	if persistence_enabled:
		autosave_elapsed+=delta
		if autosave_elapsed>=AUTOSAVE_INTERVAL:autosave_elapsed=0.0;save_game()
	if screen=="expedition" and is_instance_valid(expedition):sync_expedition_health_bars()
	elif screen=="all_quiblets" and is_instance_valid(team_preview_camera):
		team_preview_angle+=delta*.35;update_team_preview_camera()
		for entry in team_preview_models:
			if is_instance_valid(entry.ring) and is_instance_valid(entry.model):entry.ring.follow_facing(entry.model)

func sync_expedition_health_bars()->void:
	if not is_instance_valid(expedition) or not is_instance_valid(content):return
	for actor in expedition_health_bars.keys():
		if not is_instance_valid(actor) or not (expedition.team.has(actor) or expedition.enemies.has(actor)):
			var old_bar=expedition_health_bars[actor]
			if is_instance_valid(old_bar):old_bar.queue_free()
			expedition_health_bars.erase(actor)
	for actor in expedition.team+expedition.enemies:
		if not is_instance_valid(actor):continue
		if expedition_health_bars.has(actor) and is_instance_valid(expedition_health_bars[actor]):continue
		var bar:=HEALTH_BAR_SCRIPT.new();bar.name="QuibletHealthBar";content.add_child(bar);bar.setup(actor,camera_3d);expedition_health_bars[actor]=bar

func open_expedition_pause()->void:
	if screen!="expedition" or not is_instance_valid(expedition) or expedition_paused:return
	expedition_paused=true
	var shade:=ColorRect.new();shade.name="PauseMenu";shade.color=Color(0.05,.07,.09,.84);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;shade.process_mode=Node.PROCESS_MODE_ALWAYS;shade.z_index=80;content.add_child(shade);pause_overlay=shade
	add_back_button(shade,BACK_BUTTON_POSITION,close_expedition_pause)
	var menu:=panel(Rect2(150,96,980,560),Color("#fffdf7"),24);shade.add_child(menu)
	label(menu,"EXPEDITION HAUL",Vector2(30,22),28,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,920)
	label(menu,"Everything collected so far will be kept if you give up.",Vector2(30,59),13,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,920)
	build_pause_reward_column(menu,"ITEMS",Vector2(28,104),"ingredient")
	build_pause_reward_column(menu,"MOVE STONES",Vector2(345,104),"move_stone")
	build_pause_reward_column(menu,"POWER STONES",Vector2(662,104),"power_stone")
	add_button(menu,"GIVE UP",Vector2(365,492),Vector2(250,48),give_up_expedition,"coral")
	get_tree().paused=true

func close_expedition_pause()->void:
	get_tree().paused=false;expedition_paused=false
	if is_instance_valid(pause_overlay):pause_overlay.queue_free()
	pause_overlay=null

func give_up_expedition()->void:
	if not is_instance_valid(expedition):close_expedition_pause();return
	close_expedition_pause();expedition.give_up()

func live_haul_entries()->Array[Dictionary]:
	# What the running expedition has collected so far, in the same shape as the final haul.
	var entries:Array[Dictionary]=[]
	if not is_instance_valid(expedition):return entries
	for ingredient in expedition.loot:
		if int(expedition.loot[ingredient])>0:entries.append({"kind":"ingredient","name":ingredient,"amount":int(expedition.loot[ingredient])})
	for effect in expedition.move_stones:
		if int(expedition.move_stones[effect])>0:
			var info:=GameData.stone_info(effect);entries.append({"kind":"move_stone","name":info.name,"amount":int(expedition.move_stones[effect]),"texture":info.texture})
	for stone in expedition.power_stones:
		var entry:=GameData.normalize_power_stone(stone);entry.kind="power_stone";entry.name="%s %s Stone"%[entry.quality,entry.type];entry.amount=1;entries.append(entry)
	return entries

func build_pause_reward_column(parent:Control,title:String,pos:Vector2,kind:String)->void:
	var column:=panel(Rect2(pos,Vector2(290,372)),Color("#f4f6f4"),14);parent.add_child(column)
	label(column,title,Vector2(14,10),14,GameData.COLORS.ink,true)
	var entries:=live_haul_entries().filter(func(entry):return entry.kind==kind)
	if entries.is_empty():label(column,"Nothing yet.",Vector2(14,44),12,GameData.COLORS.muted);return
	var scroll:=ScrollContainer.new();scroll.position=Vector2(8,36);scroll.size=Vector2(274,328);column.add_child(scroll)
	var rows:=VBoxContainer.new();rows.custom_minimum_size=Vector2(262,0);rows.add_theme_constant_override("separation",6);scroll.add_child(rows)
	for entry in entries:add_pause_reward_row(rows,kind,entry)

func add_pause_reward_row(parent:Control,kind:String,entry:Dictionary)->void:
	var row:=Control.new();row.custom_minimum_size=Vector2(262,48);parent.add_child(row)
	if kind=="ingredient":add_ingredient_icon(row,GameData.INGREDIENTS[entry.name],Vector2(4,2),Vector2(44,44),26)
	elif kind=="move_stone":
		var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.custom_minimum_size=Vector2.ZERO;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=load(entry.texture);icon.position=Vector2(4,2);icon.size=Vector2(44,44);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(icon)
	else:add_power_stone_icon(row,entry,Vector2(4,2),Vector2(44,44))
	label(row,str(entry.name),Vector2(56,6),13,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,150)
	label(row,"×%d"%int(entry.amount),Vector2(206,6),13,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_RIGHT,50)
	if kind=="power_stone":label(row,"T%d • +%d %s"%[int(entry.tier),int(entry.power),str(entry.type)],Vector2(56,26),10,GameData.COLORS.muted)

func show_expedition_reward(reward:Dictionary,world_position:Vector3)->void:
	if screen!="expedition" or not is_instance_valid(content):return
	for item_index in maxi(0,int(reward.get("amount",1))):
		var pickup:=build_reward_pickup(reward)
		if reward_pickup_delay<=0.0:start_reward_pickup(pickup,world_position)
		else:
			var delay:=pickup.create_tween()
			delay.tween_interval(reward_pickup_delay)
			delay.tween_callback(start_reward_pickup.bind(pickup,world_position))
		reward_pickup_delay+=.12

func build_reward_pickup(reward:Dictionary)->Control:
	var pickup:=Control.new();pickup.size=Vector2(44,44);pickup.name="RewardPickup";pickup.z_index=60;pickup.mouse_filter=Control.MOUSE_FILTER_IGNORE;pickup.visible=false;content.add_child(pickup,true)
	if reward.kind=="ingredient":add_ingredient_icon(pickup,GameData.INGREDIENTS[reward.name],Vector2.ZERO,Vector2(44,44),28)
	elif reward.kind=="move_stone":
		var icon:=TextureRect.new();icon.name="RewardMoveStoneIcon";icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.custom_minimum_size=Vector2.ZERO;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=load(reward.texture);icon.size=Vector2(44,44);icon.clip_contents=true;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;pickup.add_child(icon)
	elif reward.kind=="special":label(pickup,"✦",Vector2.ZERO,30,GameData.COLORS.gold,true,HORIZONTAL_ALIGNMENT_CENTER,44)
	else:
		add_power_stone_icon(pickup,reward,Vector2.ZERO,Vector2(44,44))
	var sparkle_level:=GameData.reward_sparkle_level(reward)
	if sparkle_level>0:
		# Added after the icon so the stars draw over it; the level-2 halo sits behind via z_index.
		var sparkles:=REWARD_SPARKLES_SCRIPT.new();sparkles.name="RewardSparkles";sparkles.size=pickup.size;pickup.add_child(sparkles);sparkles.setup(sparkle_level)
	return pickup

func start_reward_pickup(pickup:Control,world_position:Vector3)->void:
	# Rise from the pickup point, hover in view, then fly to the Pause button.
	reward_pickup_delay=maxf(0.0,reward_pickup_delay-.12)
	if not is_instance_valid(pickup):return
	if screen!="expedition" or not is_instance_valid(camera_3d):pickup.queue_free();return
	var start:=camera_3d.unproject_position(world_position+Vector3(0,1.2,0))-pickup.size*.5
	pickup.position=start;pickup.visible=true;pickup.modulate.a=1.0;pickup.scale=Vector2.ONE
	var target:=Vector2(46,44)-pickup.size*.5
	var tween:=pickup.create_tween()
	tween.tween_property(pickup,"position:y",start.y-38.0,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.0)
	tween.tween_property(pickup,"position",target,.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(pickup,"scale",Vector2.ONE*.8,.3)
	tween.tween_callback(pickup.queue_free)

func _input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:camp_pan_dragging=false
	if not (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed):return
	if screen in ["expedition_changes","expedition_haul"]:
		# Both result screens advance on a click once their animations have finished.
		if not result_advance_ready:return
		result_advance_ready=false
		if screen=="expedition_changes":show_expedition_haul()
		else:show_map()
		get_viewport().set_input_as_handled();return
	if screen=="camp" and is_instance_valid(camera_3d) and is_instance_valid(world_root):
		var origin:=camera_3d.project_ray_origin(event.position);var direction:=camera_3d.project_ray_normal(event.position)
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*200.0);query.collision_mask=2
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider.get_meta("camp_interaction","")=="cooking":open_cooking_pot();get_viewport().set_input_as_handled()

func start_expedition(stage_title:String)->void:
	var area_index:=GameData.EXPEDITION_AREAS.find(stage_title)
	if area_index<0:area_index=0
	start_area_level(area_index,0)

func area_level_data(area_index:int,level_index:int)->Dictionary:
	var types:=["level","level","level","berry_grove","level","level","boss","optional_berry_grove"]
	var titles:=["Level 1","Level 2","Level 3","Berry Grove","Level 4","Level 5","Boss Level","Optional Berry Grove"]
	var base:=GameData.expedition_area_level(area_index)
	var additions:=[0,2,4,3,6,8,11,9]
	return {"type":types[level_index],"title":titles[level_index],"level":base+additions[level_index],"area":GameData.EXPEDITION_AREAS[area_index],"area_index":area_index,"level_index":level_index}

func is_area_level_unlocked(area_index:int,level_index:int)->bool:
	return area_index>=0 and area_index<area_progress.size() and level_index<=clampi(area_progress[area_index],0,7)

func show_area_levels(area_index:int)->void:
	selected_area_index=clampi(area_index,0,GameData.EXPEDITION_AREAS.size()-1);map_page=selected_area_index/AREAS_PER_PAGE
	screen="area_levels";clear_content();build_area_route_world(selected_area_index);add_back_button(content,BACK_BUTTON_POSITION,show_map)
	transition_to_expedition_music("level")
	var route:=Control.new();route.name="AreaLevelRoute";route.position=Vector2(95,250);route.size=Vector2(1090,340);content.add_child(route)
	var line:=Line2D.new();line.width=8;line.default_color=Color("#b7c3c1");line.position=Vector2.ZERO;route.add_child(line)
	var positions:=[Vector2(65,65),Vector2(205,65),Vector2(345,65),Vector2(485,65),Vector2(625,65),Vector2(765,65),Vector2(905,65),Vector2(1015,205)]
	line.points=PackedVector2Array(positions)
	for i in 8:
		var data:=area_level_data(selected_area_index,i);var unlocked:=is_area_level_unlocked(selected_area_index,i);var cleared:=i<int(area_progress[selected_area_index])
		var eval:=evaluate_difficulty(data.level);var card:=panel(Rect2(positions[i]-Vector2(58,42),Vector2(116,132)),Color("#fff8d8") if str(data.type).contains("berry_grove") else (Color("#fff0e5") if data.type=="boss" else Color("#f7fbf6")),16);card.name="LevelNode%d"%i;card.modulate=Color.WHITE if unlocked else Color(.48,.5,.51,.8);route.add_child(card)
		label(card,data.title,Vector2(5,7),12,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,106)
		label(card,"Lv.%d"%data.level,Vector2(5,29),10,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_CENTER,106)
		label(card,"✓ CLEARED" if cleared else (eval.label if unlocked else "LOCKED"),Vector2(5,49),10,eval.color if unlocked else GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_CENTER,106)
		var metrics:Dictionary=eval.metrics
		label(card,"♥ %s\n⚔ %s\n◎ %s"%[metrics.Survivability,metrics.Damage,metrics.Positioning],Vector2(8,68),9,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_LEFT,100)
		var click:=Button.new();click.name="PlayLevel%d"%i;click.flat=true;click.position=Vector2.ZERO;click.size=card.size;click.disabled=not unlocked;click.tooltip_text="Play or replay this level" if unlocked else "Clear the previous level first";click.pressed.connect(start_area_level.bind(selected_area_index,i));card.add_child(click)
	var charms:=panel(Rect2(190,610,900,82),Color("#f4efffea"),14);content.add_child(charms)
	add_toggle(charms,"Fortune Charm (%d) • rarer loot"%special_items["Fortune Charm"],Vector2(18,12),fortune_active,func():fortune_active=!fortune_active;show_area_levels(selected_area_index))
	add_toggle(charms,"Challenger's Charm (%d) • more progress"%special_items["Challenger's Charm"],Vector2(468,12),challenger_active,func():challenger_active=!challenger_active;show_area_levels(selected_area_index))
	var back:TextureButton=content.find_child("BackButton",false,false);back.z_index=20

func start_area_level(area_index:int,level_index:int)->void:
	if not is_area_level_unlocked(area_index,level_index):return
	selected_area_index=area_index;selected_level_index=level_index;map_page=area_index/AREAS_PER_PAGE
	var stage:=area_level_data(area_index,level_index);difficulty_level=stage.level
	expedition_team_before.clear()
	for index in team_indices:expedition_team_before.append({"roster_index":index,"data":roster[index].duplicate(true)})
	if fortune_active and int(special_items["Fortune Charm"])<=0:fortune_active=false
	if challenger_active and int(special_items["Challenger's Charm"])<=0:challenger_active=false
	if fortune_active:special_items["Fortune Charm"]-=1
	if challenger_active:special_items["Challenger's Charm"]-=1
	screen="expedition";clear_content()
	transition_to_expedition_music(stage.type)
	clear_world()
	set_stage_fog(GameData.expedition_biome(area_index))
	expedition=Expedition3D.new();expedition.stage_name=stage.area;expedition.stage_area_index=area_index;expedition.stage_node_index=level_index;expedition.stage_kind=stage.type;world_root.add_child(expedition);expedition.setup_camera(camera_3d)
	expedition.expedition_finished.connect(_on_expedition_finished);expedition.event_message.connect(func(message):toast(message,GameData.COLORS.ink));expedition.reward_acquired.connect(show_expedition_reward);expedition.boss_fight_started.connect(play_boss_music);expedition.boss_fight_ended.connect(restore_stage_music)
	expedition.treasure_keys=int(special_items.get("Treasure Key",0));expedition.treasure_key_used.connect(func():special_items["Treasure Key"]=maxi(0,int(special_items.get("Treasure Key",0))-1))
	var team_data:Array=[]
	for index in team_indices:team_data.append(roster[index])
	expedition.begin(team_data,difficulty_level,fortune_active,challenger_active)
	build_expedition_hud()

func _on_expedition_finished(result:Dictionary)->void:
	last_result=result
	if result.victory and int(result.get("area_index",-1))>=0:
		var completed_area:=int(result.area_index);var completed_level:=int(result.get("node_index",0))
		area_progress[completed_area]=maxi(area_progress[completed_area],mini(8,completed_level+1))
		selected_area_index=completed_area;selected_level_index=completed_level
	for name in result.loot:grant_ingredient(name,int(result.loot[name]))
	if not result.special.is_empty():special_items[result.special]=int(special_items.get(result.special,0))+1
	for extra in result.get("extra_specials",[]):special_items[str(extra)]=int(special_items.get(str(extra),0))+1
	for effect in result.get("move_stones",{}):move_stone_inventory[effect]=int(move_stone_inventory.get(effect,0))+int(result.move_stones[effect])
	for stone in result.get("power_stones",[]):power_stone_inventory.append(GameData.normalize_power_stone(stone))
	for index in team_indices:
		var q:Dictionary=roster[index];q.exp+=int(result.exp)
		while int(q.exp)>=GameData.exp_to_level(int(q.level)):
			q.exp-=GameData.exp_to_level(int(q.level));q.level+=1
			if int(q.level)%25==0:apply_milestone(q)
	expedition_team_results.clear()
	for snapshot in expedition_team_before:
		var roster_index:=int(snapshot.roster_index)
		if roster_index>=0 and roster_index<roster.size():expedition_team_results.append({"before":snapshot.data,"after":roster[roster_index].duplicate(true)})
	# Every finished run advances the pot, regardless of victory, defeat, or Give Up.
	advance_pending_stew()
	show_expedition_changes()

func total_quiblet_exp(q:Dictionary)->int:
	var total:=int(q.exp)
	for level in range(1,int(q.level)):total+=GameData.exp_to_level(level)
	return total

func state_from_total_exp(total:int)->Dictionary:
	var level:=1;var remaining:=maxi(0,total)
	while remaining>=GameData.exp_to_level(level) and level<999:
		remaining-=GameData.exp_to_level(level);level+=1
	return {"level":level,"exp":remaining}

func show_expedition_changes()->void:
	screen="expedition_changes";result_advance_ready=false;clear_content()
	var background:=ColorRect.new();background.name="ResultBackdrop";background.color=Color(0.015,0.018,0.022,.68);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(background)
	# Each card is the Quiblet's condensed info menu, scaled as large as the
	# screen allows for this team size.
	var count:=expedition_team_results.size()
	if count==0:enable_result_advance("click to continue","expedition_changes");return
	var replicas:Array[Control]=[];var refs_list:Array[Dictionary]=[];var natural:=Vector2.ZERO
	for i in count:
		var replica:=Control.new();replica.name="ResultMenu";replica.mouse_filter=Control.MOUSE_FILTER_IGNORE
		refs_list.append(build_quiblet_menu_replica(replica,expedition_team_results[i].after));replicas.append(replica)
		natural=Vector2(maxf(natural.x,replica.size.x),maxf(natural.y,replica.size.y))
	var layout:=best_result_card_layout(count,natural);var card_scale:float=layout.scale;var gap:float=layout.gap;var area:Rect2=layout.area
	var card_size:=natural*card_scale;var rows:int=layout.rows;var per_row:int=layout.per_row
	var total_height:=rows*card_size.y+(rows-1)*gap;var top:=area.position.y+(area.size.y-total_height)*.5
	for i in count:
		var row:=i/per_row;var in_row:=mini(per_row,count-row*per_row);var column:=i%per_row
		var row_start_x:=area.position.x+(area.size.x-(in_row*card_size.x+(in_row-1)*gap))*.5;var target_y:=top+row*(card_size.y+gap)
		var change:Dictionary=expedition_team_results[i];var before:Dictionary=change.before;var after:Dictionary=change.after
		var card:=panel(Rect2(row_start_x+column*(card_size.x+gap),target_y,card_size.x,card_size.y),Color.WHITE,14);card.name="QuibletChangeCard%d"%i;card.clip_contents=true;content.add_child(card)
		var replica:Control=replicas[i];replica.scale=Vector2.ONE*card_scale;card.add_child(replica)
		var refs:Dictionary=refs_list[i]
		refs.portrait.setup(int(before.species),1.08);refs.name_label.text=GameData.display_name(before);refs.level_label.text="Lv. %d"%int(before.level)
		refs.xp_bar.max_value=GameData.exp_to_level(int(before.level));refs.xp_bar.value=int(before.exp)
		refs.health_label.text=str(GameData.max_hp(before));refs.attack_label.text=str(GameData.attack(before))
		set_result_board_level(refs,int(before.level),int(before.exp))
		card.modulate.a=0.0;card.position.y+=18
		var tween:=card.create_tween();tween.tween_interval(i*.12);tween.tween_property(card,"modulate:a",1.0,.22);tween.parallel().tween_property(card,"position:y",target_y,.22).set_trans(Tween.TRANS_BACK)
		tween.tween_method(update_quiblet_result_card.bind(refs,before,after),0.0,1.0,1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():var pulse:=card.create_tween();pulse.tween_property(card,"scale",Vector2.ONE*1.02,.1);pulse.tween_property(card,"scale",Vector2.ONE,.13))
	var ready:=create_tween();ready.tween_interval(.22+maxf(0,count-1)*.12+1.3);ready.tween_callback(enable_result_advance.bind("click to continue","expedition_changes"))

func update_quiblet_result_card(progress:float,refs:Dictionary,before:Dictionary,after:Dictionary)->void:
	var old_total:=total_quiblet_exp(before);var new_total:=total_quiblet_exp(after);var state:=state_from_total_exp(roundi(lerpf(old_total,new_total,progress)))
	refs.level_label.text="Lv. %d"%state.level;refs.xp_bar.max_value=GameData.exp_to_level(state.level);refs.xp_bar.value=state.exp
	set_result_board_level(refs,int(state.level),int(state.exp))
	refs.health_label.text=str(roundi(lerpf(GameData.max_hp(before),GameData.max_hp(after),progress)));refs.attack_label.text=str(roundi(lerpf(GameData.attack(before),GameData.attack(after),progress)))
	if progress>=.5 and refs.portrait.species_index!=int(after.species):refs.portrait.setup(int(after.species),1.08);refs.name_label.text=GameData.display_name(after)

func enable_result_advance(text_value:String,expected_screen:String)->void:
	if not is_instance_valid(content) or screen!=expected_screen:return
	result_advance_ready=true;var prompt:=label(content,text_value,Vector2(290,620),18,Color.WHITE,true,HORIZONTAL_ALIGNMENT_CENTER,700);prompt.name="ResultContinuePrompt";prompt.modulate.a=0;var tween:=prompt.create_tween();tween.tween_property(prompt,"modulate:a",1.0,.22)

func expedition_haul_entries()->Array[Dictionary]:
	var entries:Array[Dictionary]=[]
	for ingredient in last_result.get("loot",{}):
		if int(last_result.loot[ingredient])>0:entries.append({"kind":"ingredient","name":ingredient,"amount":int(last_result.loot[ingredient])})
	for effect in last_result.get("move_stones",{}):
		if int(last_result.move_stones[effect])>0:
			var info:=GameData.stone_info(effect);entries.append({"kind":"move_stone","name":info.name,"amount":int(last_result.move_stones[effect]),"texture":info.texture})
	for stone in last_result.get("power_stones",[]):
		var entry:=GameData.normalize_power_stone(stone);entry.kind="power_stone";entry.name="%s %s Stone"%[entry.quality,entry.type];entry.amount=1;entries.append(entry)
	if not str(last_result.get("special","")).is_empty():entries.append({"kind":"special","name":last_result.special,"amount":1})
	for extra in last_result.get("extra_specials",[]):entries.append({"kind":"special","name":str(extra),"amount":1})
	return entries

func show_expedition_haul()->void:
	screen="expedition_haul";result_advance_ready=false;clear_content()
	var background:=ColorRect.new();background.name="ResultBackdrop";background.color=Color(0.015,0.018,0.022,.68);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(background)
	var entries:=expedition_haul_entries()
	for i in entries.size():
		var entry:Dictionary=entries[i];var column:=i%12;var row:=i/12
		var card:=panel(Rect2(22+column*104,72+row*105,92,92),Color.WHITE,12);card.name="HaulItem%d"%i;content.add_child(card)
		if entry.kind=="ingredient":add_ingredient_icon(card,GameData.INGREDIENTS[entry.name],Vector2(22,8),Vector2(48,48),28)
		elif entry.kind=="move_stone":
			var icon:=TextureRect.new();icon.texture=load(entry.texture);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.position=Vector2(22,8);icon.size=Vector2(48,48);card.add_child(icon)
		elif entry.kind=="power_stone":add_power_stone_icon(card,entry,Vector2(22,8),Vector2(48,48))
		else:label(card,"✦",Vector2(20,10),30,GameData.COLORS.gold,true,HORIZONTAL_ALIGNMENT_CENTER,52)
		var display_name:String=(str(entry.quality)+"\n"+str(entry.type)+" Stone") if entry.kind=="power_stone" else str(entry.name)
		label(card,display_name,Vector2(4,57),8 if entry.kind=="power_stone" else 9,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,84);card.tooltip_text=str(entry.name)
		label(card,"×%d"%entry.amount,Vector2(58,6),9,GameData.COLORS.muted,true,HORIZONTAL_ALIGNMENT_RIGHT,27)
	if entries.is_empty():label(content,"Nothing was collected this time.",Vector2(290,300),22,Color("#d7dde3"),true,HORIZONTAL_ALIGNMENT_CENTER,700)
	enable_result_advance("click to continue","expedition_haul")

func show_expedition_result()->void:
	screen="result";clear_content();make_topbar("EXPEDITION COMPLETE" if last_result.victory else "TEAM RETURNED SAFELY","Progress and gathered items have been added to your camp.",false)
	var card:=panel(Rect2(220,125,840,520),Color("#fffaf0"),24);content.add_child(card)
	label(card,"TRAIL CLEARED!" if last_result.victory else "SAFE RETREAT",Vector2(30,30),32,GameData.COLORS.leaf_dark if last_result.victory else GameData.COLORS.coral,true,HORIZONTAL_ALIGNMENT_CENTER,780)
	label(card,"+%d EXP for every team member"%last_result.exp,Vector2(30,87),20,GameData.COLORS.berry,true,HORIZONTAL_ALIGNMENT_CENTER,780)
	var loot_lines:Array[String]=[]
	for name in last_result.loot:
		if int(last_result.loot[name])>0:loot_lines.append("%s ×%d"%[name,last_result.loot[name]])
	label(card,"GATHERED",Vector2(60,147),14,GameData.COLORS.muted,true)
	label(card,"  •  ".join(loot_lines),Vector2(60,178),16,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_CENTER,720)
	label(card,"Berry patches visited: %d"%last_result.berries,Vector2(60,242),15,GameData.COLORS.leaf_dark,true,HORIZONTAL_ALIGNMENT_CENTER,720)
	var finds:Array[String]=[]
	if not last_result.special.is_empty():finds.append(str(last_result.special))
	for extra in last_result.get("extra_specials",[]):finds.append(str(extra))
	if not finds.is_empty():label(card,"Rare find: ✦ %s"%", ".join(finds),Vector2(60,287),19,GameData.COLORS.gold,true,HORIZONTAL_ALIGNMENT_CENTER,720)
	add_button(card,"EXPLORE AGAIN",Vector2(130,420),Vector2(250,58),func():show_map(),"gold")
	add_back_button(content,BACK_BUTTON_POSITION,func():show_camp())

func evaluate_difficulty(level:int)->Dictionary:
	var hp:=0.0;var atk:=0.0;var healing:=0;var ranged:=0;var cooldown_score:=0.0
	for idx in team_indices:
		var q:Dictionary=roster[idx];hp+=GameData.max_hp(q);atk+=GameData.attack(q)
		if float(GameData.species(int(q.species)).range)>125:ranged+=1
		for move in q.moves:
			var md:Dictionary=GameData.MOVES[move.name];cooldown_score+=float(md.power)/maxf(float(md.cooldown),.5)
			if md.kind=="recover":healing+=1
	# The label follows the real matchup: enemy scaling for this island plus the level gap.
	var team_levels:Array=[]
	for idx in team_indices:team_levels.append(int(roster[idx].level))
	var team_members:Array=[]
	for idx in team_indices:team_members.append(roster[idx])
	var ratio:float=GameData.expected_matchup(team_levels,level,selected_area_index,GameData.team_stone_power(team_members))*(1.0+.08*maxi(0,team_indices.size()-3))
	var label_text:="COMFORTABLE" if ratio>1.4 else ("TESTING" if ratio>.8 else "HARD")
	return {"label":label_text,"color":GameData.COLORS.leaf if ratio>1.4 else (GameData.COLORS.gold if ratio>.8 else GameData.COLORS.coral),"metrics":{"Survivability":"Good" if hp/(level*team_indices.size()+1)>45 or healing>0 else "Low","Damage":"Good" if cooldown_score/(level+1)>5 else "Low","Matchup":"Mixed" if level>9 else "Good","Positioning":"Good" if ranged>0 and ranged<team_indices.size() else "Mixed"}}

func team_average_level()->int:
	var total:=0
	for idx in team_indices:total+=int(roster[idx].level)
	return total/maxi(1,team_indices.size())

# Soft meadow lighting: a pale sky-blue ambient fill (a hemisphere light's sky
# side), one warm gentle sun with no shadows, matte shading, and no haze.
const STAGE_AMBIENT_ENERGY:=.95
const STAGE_SUN_ENERGY:=.8

func create_3d_stage()->void:
	world_root=Node3D.new();world_root.name="World3D";add_child(world_root)
	camera_3d=Camera3D.new();camera_3d.name="MainCamera";camera_3d.position=Vector3(0,9.5,13.5);camera_3d.fov=48;add_child(camera_3d);camera_3d.look_at(Vector3(0,0,0),Vector3.UP)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#cfeeff");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#e2f5ff");env.ambient_light_energy=STAGE_AMBIENT_ENERGY;env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.0
	env.glow_enabled=false
	environment.environment=env;environment.name="StageEnvironment";add_child(environment)
	var sun:=DirectionalLight3D.new();sun.name="StageSun";sun.rotation_degrees=Vector3(-52,-32,0);sun.light_color=Color("#fff0c8");sun.light_energy=STAGE_SUN_ENERGY;sun.shadow_enabled=false;add_child(sun)
	build_camp_world()

func clear_world()->void:
	if not is_instance_valid(world_root):return
	# Detach old scenery immediately so rebuilt state nodes keep stable names and
	# stale collision bodies cannot receive input for the rest of this frame.
	for child in world_root.get_children():world_root.remove_child(child);child.queue_free()

func world_material(color:Color)->StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.88;return mat

func world_box(pos:Vector3,size:Vector3,color:Color)->MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size;var node:=MeshInstance3D.new();node.mesh=mesh;node.position=pos;node.material_override=world_material(color);world_root.add_child(node);return node

func world_sphere(pos:Vector3,size:Vector3,color:Color)->MeshInstance3D:
	var mesh:=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=9;mesh.rings=6;var node:=MeshInstance3D.new();node.mesh=mesh;node.position=pos;node.scale=size;node.material_override=world_material(color);world_root.add_child(node);return node

func camp_tree(pos:Vector3,shade:Color)->void:
	world_box(pos+Vector3(0,.65,0),Vector3(.38,1.5,.38),Color("#76553d"));world_sphere(pos+Vector3(0,1.75,0),Vector3(1.45,1.25,1.35),shade);world_sphere(pos+Vector3(.65,1.5,.15),Vector3(.8,.8,.8),shade.lightened(.05))

# No depth haze: the field stays crisp to its far edge (raise this to bring haze back).
const STAGE_FOG_DENSITY:=0.0
func set_stage_fog(biome:Dictionary)->void:
	var stage_env:WorldEnvironment=find_child("StageEnvironment",false,false)
	if stage_env==null:return
	var env:Environment=stage_env.environment
	if biome.is_empty() or STAGE_FOG_DENSITY<=0.0:env.fog_enabled=false;return
	env.fog_enabled=true;env.fog_mode=Environment.FOG_MODE_EXPONENTIAL;env.fog_density=STAGE_FOG_DENSITY;env.fog_light_color=Color("#d9f1fb").lerp(Color(biome.ground).lightened(.4),.25);env.fog_light_energy=1.0;env.fog_sun_scatter=0.0;env.fog_aerial_perspective=0.0

func build_camp_world()->void:
	set_stage_fog({})
	clear_world()
	camera_3d.position=Vector3(camp_pan_x,9.5,13.5);camera_3d.look_at(Vector3(camp_pan_x,0,0),Vector3.UP);camera_3d.fov=48
	world_box(Vector3(0,-.35,0),Vector3(30,.7,20),Color("#8fbd7f"))
	# Stepped earth platforms give the base camp a compact diorama silhouette.
	world_box(Vector3(-5,.02,-1),Vector3(7,.35,6),Color("#dcc793"));world_box(Vector3(5,.02,1),Vector3(6,.35,5),Color("#d6c18f"))
	# Imported heater sits flush beneath the cooking pot.
	var heater_scene:PackedScene=load("res://models/PotHeater.glb")
	var heater_model:=heater_scene.instantiate();heater_model.name="PotHeater";heater_model.position=Vector3.ZERO;heater_model.scale=Vector3.ONE*.48;world_root.add_child(heater_model)
	var pot_scene:PackedScene=load("res://models/CookingPot.glb")
	var pot_model:=pot_scene.instantiate()
	pot_model.name="CookingPot"
	pot_model.position=Vector3(0,.72,0)
	pot_model.scale=Vector3.ONE*.48
	world_root.add_child(pot_model)
	var pot_is_cooking:=not pending_stew.is_empty()
	var pot_is_ready:=not completed_stew_result.is_empty()
	if pot_is_cooking or pot_is_ready:build_cooking_pot_lid(pot_model)
	if pot_is_cooking:build_cooking_progress_indicator()
	elif pot_is_ready:build_cooking_ready_indicator()
	if not pot_is_cooking:build_pot_click_collider(pot_model)
	# Canvas tents and supply crates.
	var tent:=world_box(Vector3(-5.3,1.0,-1.2),Vector3(3.2,2.1,3.0),Color("#f2dfae"));tent.rotation.z=.12
	for p in [Vector3(4.1,.35,1.4),Vector3(5.2,.35,1.4),Vector3(4.65,.35,.3)]:world_box(p,Vector3(.9,.7,.9),Color("#9b6e45"))
	for entry in [[Vector3(-10,0,-5),Color("#427451")],[Vector3(10,0,-4),Color("#4d7e58")],[Vector3(-11,0,3),Color("#4a7a54")],[Vector3(10,0,4),Color("#3f704e")]]:camp_tree(entry[0],entry[1])
	# Team members wander around the hearth as genuine 3D models.
	for i in mini(5,team_indices.size()):
		var model:=QuibletModel3D.new();model.setup(int(roster[team_indices[i]].species),false,.72);model.position=Vector3(-2.8+i*1.4,.2,3.0+sin(i)*.5);world_root.add_child(model)

func build_cooking_pot_lid(pot_model:Node3D)->void:
	var lid_scene:PackedScene=load("res://models/PotLid.glb")
	var lid_model:=lid_scene.instantiate()
	lid_model.name="CookingPotLid"
	# Slightly wider than the pot so the plate overhangs the rim like a real lid.
	lid_model.scale=Vector3.ONE*.5
	world_root.add_child(lid_model)
	# Both imported meshes carry their own offsets and stretches, so measure the
	# pot's rim and the lid's underside instead of assuming unit-sized bounds.
	var rim_top:=world_mesh_bounds(pot_model).end.y
	var lid_bottom:=world_mesh_bounds(lid_model).position.y
	var resting_y:=rim_top-lid_bottom-.01;lid_model.position.y=resting_y;lid_model.set_meta("resting_y",resting_y)
	if lid_drop_pending:
		lid_drop_pending=false
		# Just after starting a stew: the lid appears a little above the expedition
		# counter, hops slightly higher, then spins fast while dropping squarely onto the rim.
		var start_y:=resting_y+(COOKING_INDICATOR_HEIGHT+.8-rim_top)
		lid_model.position.y=start_y
		var tween:=lid_model.create_tween()
		tween.tween_property(lid_model,"position:y",start_y+.5,.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(lid_model,"position:y",resting_y,.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(lid_model,"rotation:y",TAU*3.0,.45)
		tween.tween_callback(func():if is_instance_valid(lid_model):lid_model.rotation.y=0.0)

func world_mesh_bounds(model:Node3D)->AABB:
	var mesh_nodes:Array[MeshInstance3D]=[];collect_mesh_instances(model,mesh_nodes)
	var world_inverse:=world_root.global_transform.affine_inverse();var bounds:AABB;var first:=true
	for mesh_node in mesh_nodes:
		var mesh_bounds:AABB=(world_inverse*mesh_node.global_transform)*mesh_node.get_aabb()
		bounds=mesh_bounds if first else bounds.merge(mesh_bounds);first=false
	return bounds

func build_cooking_progress_indicator()->void:
	var required:=maxi(1,int(pending_stew.get("expeditions_required",1)))
	var remaining:=clampi(int(pending_stew.get("expeditions_remaining",required)),0,required)
	var completed:=required-remaining
	var progress:=Label3D.new()
	progress.name="CookingProgressIndicator"
	progress.text="%d/%d"%[completed,required]
	progress.position=Vector3(0,COOKING_INDICATOR_HEIGHT,0)
	progress.font_size=52
	progress.outline_size=12
	# Quarter of the default on-screen size, keeping the 52px raster crisp.
	progress.pixel_size=.00125
	progress.modulate=Color.WHITE
	progress.outline_modulate=Color(GameData.COLORS.ink,.92)
	progress.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	progress.fixed_size=true
	progress.no_depth_test=true
	world_root.add_child(progress)

func build_cooking_ready_indicator()->void:
	var indicator:=Node3D.new();indicator.name="CookingReadyIndicator";indicator.position=Vector3(0,COOKING_INDICATOR_HEIGHT,0);world_root.add_child(indicator)
	# Quarter of the default label size, matching the cooking counter; the rasters stay crisp.
	var circle:=Label3D.new();circle.name="Circle";circle.text="●";circle.font_size=112;circle.pixel_size=.00125;circle.modulate=Color("#f15f9b");circle.billboard=BaseMaterial3D.BILLBOARD_ENABLED;circle.fixed_size=true;circle.no_depth_test=true;circle.render_priority=1;indicator.add_child(circle)
	var mark:=Label3D.new();mark.name="Exclamation";mark.text="!";mark.font_size=54;mark.pixel_size=.00125;mark.modulate=Color.WHITE;mark.outline_size=2;mark.outline_modulate=Color.WHITE;mark.billboard=BaseMaterial3D.BILLBOARD_ENABLED;mark.fixed_size=true;mark.no_depth_test=true;mark.render_priority=2;mark.position=Vector3(0,0,.01);indicator.add_child(mark)

func build_pot_click_collider(pot_model:Node3D)->void:
	var points:=PackedVector3Array();var mesh_nodes:Array[MeshInstance3D]=[]
	collect_mesh_instances(pot_model,mesh_nodes)
	var world_inverse:=world_root.global_transform.affine_inverse()
	for mesh_node in mesh_nodes:
		if mesh_node.mesh==null:continue
		var to_world_root:=world_inverse*mesh_node.global_transform
		for surface_index in mesh_node.mesh.get_surface_count():
			var arrays:=mesh_node.mesh.surface_get_arrays(surface_index);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:points.append(to_world_root*vertex)
	if points.is_empty():return
	var shape:=ConvexPolygonShape3D.new();shape.points=points
	var body:=StaticBody3D.new();body.name="CookingPotHitbox";body.collision_layer=2;body.collision_mask=0;body.set_meta("camp_interaction","cooking")
	var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);world_root.add_child(body)

func collect_mesh_instances(node:Node,result:Array[MeshInstance3D])->void:
	if node is MeshInstance3D:result.append(node)
	for child in node.get_children():collect_mesh_instances(child,result)

func build_level_select_world()->void:
	clear_world()
	camera_3d.position=Vector3(0,9.5,14.5);camera_3d.look_at(Vector3(0,0,-.3),Vector3.UP);camera_3d.fov=46
	world_box(Vector3(0,-.8,0),Vector3(30,.5,16),Color("#72c1d0"))
	var colors:=[Color("#78af68"),Color("#69b6c8"),Color("#bc7553")]
	var indices:=visible_map_areas()
	for i in indices.size():
		var area_index:int=indices[i]
		var x:float=map_island_position(i).x
		var island_mesh:=CylinderMesh.new();island_mesh.top_radius=2.85;island_mesh.bottom_radius=2.25;island_mesh.height=1.25;island_mesh.radial_segments=10
		var island:=MeshInstance3D.new();island.mesh=island_mesh;island.position=Vector3(x,-.05,0);island.material_override=world_material(colors[i]);world_root.add_child(island)
		world_box(Vector3(x,.72,0),Vector3(4.2,.22,2.2),Color("#ddc995"))
		var marker:=Label3D.new();marker.name="AreaLabel%d"%area_index;marker.text=GameData.EXPEDITION_AREAS[area_index];marker.position=Vector3(x,2.65,.1);marker.font_size=34;marker.outline_size=10;marker.modulate=Color.WHITE;marker.outline_modulate=Color(GameData.COLORS.ink,.8);marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;world_root.add_child(marker)
		var model:=QuibletModel3D.new();model.setup((i*2+1)%GameData.SPECIES.size(),true,.67);model.position=Vector3(x,.85,.2);world_root.add_child(model)
		if i==0:
			camp_tree(Vector3(x-1.6,.5,-.5),Color("#43794f"));world_sphere(Vector3(x+1.4,.9,-.3),Vector3(.65,.45,.65),GameData.COLORS.berry)
		elif i==1:
			world_box(Vector3(x-1.45,.98,-.4),Vector3(.7,1.7,.7),Color("#8c929d"));world_sphere(Vector3(x+1.45,.75,-.5),Vector3(.8,.35,.8),Color("#b6edf0"))
		else:
			for offset in [-1.5,1.45]:world_box(Vector3(x+offset,1.05,-.4),Vector3(.8,1.9,.8),Color("#6f625c"))

func build_area_route_world(area_index:int)->void:
	clear_world()
	camera_3d.position=Vector3(0,9.5,14.5);camera_3d.look_at(Vector3(0,0,-.3),Vector3.UP);camera_3d.fov=46
	var hue:=fmod(.18+area_index*.071,1.0);var ground:=Color.from_hsv(hue,.38,.74)
	world_box(Vector3(0,-.65,0),Vector3(30,.5,16),ground.darkened(.18))
	for x in range(-12,13,2):world_box(Vector3(x,-.12,sin((x+area_index)*.48)*1.25),Vector3(2.3,.22,3.0),ground)
	for i in 6:
		var x:float=-10+i*4.0
		if area_index%3==0:camp_tree(Vector3(x,.4,-2.0+sin(i)*1.2),ground.darkened(.28))
		elif area_index%3==1:world_box(Vector3(x,.5,-2.2+sin(i)*1.1),Vector3(.8,1.6,.8),ground.lightened(.18))
		else:world_sphere(Vector3(x,.55,-2.2+sin(i)*1.1),Vector3(.8,.8,.8),ground.lightened(.22))

func screen_ray_ground(position:Vector2)->Variant:
	var origin:=camera_3d.project_ray_origin(position);var direction:=camera_3d.project_ray_normal(position)
	return Plane(Vector3.UP,0).intersects_ray(origin,direction)

func _unhandled_input(event:InputEvent)->void:
	if screen=="camp":
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			camp_pan_dragging=event.pressed
		elif event is InputEventMouseMotion and camp_pan_dragging:
			camp_pan_x=clampf(camp_pan_x-event.relative.x*.018,-7.0,7.0);camera_3d.position=Vector3(camp_pan_x,9.5,13.5);camera_3d.look_at(Vector3(camp_pan_x,0,0),Vector3.UP);get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed):return
	if screen=="map":
		var hit=screen_ray_ground(event.position)
		if hit==null:return
		var area_index:=map_area_at_point(hit)
		if area_index<0:return
		show_area_levels(area_index);get_viewport().set_input_as_handled()

func make_topbar(title:String,subtitle:String,back:=false)->void:
	# Page-level headers are intentionally omitted; only navigation remains.
	if back:add_back_button(content,BACK_BUTTON_POSITION,func():show_camp())

func panel(rect:Rect2,color:Color,radius_value:int)->Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size
	var box:=StyleBoxFlat.new();box.bg_color=color;box.set_corner_radius_all(radius_value);box.shadow_color=Color(0.1,0.2,0.16,.12);box.shadow_size=5;box.shadow_offset=Vector2(0,3);box.border_color=Color(1,1,1,.55);box.set_border_width_all(1);p.add_theme_stylebox_override("panel",box);return p

func label(parent:Node,text:String,pos:Vector2,font_size:int,color:Color,bold:=false,align:=HORIZONTAL_ALIGNMENT_LEFT,width:=0)->Label:
	# Autowrap is enabled before the text, position, and size: setting a position or
	# size clamps the Label to its minimum, and an unwrapped Label's minimum width
	# is its whole text, which would leave long lines running off their panel.
	var l:=Label.new();l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.text=text;l.add_theme_font_size_override("font_size",font_size);l.position=pos;l.size=Vector2(width if width>0 else 700,70);l.add_theme_color_override("font_color",color);l.horizontal_alignment=align;l.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	# Containers size children by their minimum width, and a wrapping Label's is
	# one pixel; give it the requested width (or its unwrapped text width) so a
	# grid or box does not squeeze it to one character per line.
	if parent is Container:l.custom_minimum_size=Vector2(width if width>0 else ceilf(ThemeDB.fallback_font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+2.0,0)
	if bold:l.add_theme_constant_override("outline_size",1);l.add_theme_color_override("font_outline_color",Color(color,.22))
	parent.add_child(l);return l

func add_button(parent:Node,text:String,pos:Vector2,size:Vector2,callback:Callable,kind:="plain")->Button:
	var b:=Button.new();b.text=text;b.position=pos;b.size=size;b.add_theme_font_size_override("font_size",14);style_button(b,kind);b.pressed.connect(callback);parent.add_child(b);return b

func add_texture_button(parent:Node,texture_path:String,pos:Vector2,button_size:Vector2,callback:Callable,node_name:String,icon_scale:=1.0)->TextureButton:
	# Padded icon art is cropped to its visible pixels so it fills the button like
	# the rest; icon_scale below 1 pads the atlas so the icon draws smaller, centred.
	var texture:Texture2D=load(texture_path);var image:=texture.get_image()
	if image!=null:
		var visible_rect:=image.get_used_rect()
		if visible_rect.size.x>0 and visible_rect.size.y>0 and (visible_rect.size!=image.get_size() or icon_scale<1.0):
			var cropped:=AtlasTexture.new();cropped.atlas=texture;cropped.region=Rect2(visible_rect)
			if icon_scale<1.0:
				var pad:=Vector2(visible_rect.size)*(1.0/icon_scale-1.0)*.5;cropped.margin=Rect2(pad,pad*2.0)
			texture=cropped
	var button:=TextureButton.new();button.name=node_name;button.ignore_texture_size=true;button.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED;button.texture_normal=texture;button.position=pos;button.size=button_size;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;button.pressed.connect(callback);parent.add_child(button);return button

func add_back_button(parent:Node,pos:Vector2,callback:Callable,button_size:=40)->TextureButton:
	var button:=add_texture_button(parent,"res://textures/UI/BackButton.png",pos,Vector2(button_size,button_size),callback,"BackButton")
	# Screens add their panels after the button; raise it once building is done so
	# an overlapping panel can never swallow the click.
	button.call_deferred("move_to_front")
	return button

func style_button(button:Button,kind:String)->void:
	var colors:={"plain":Color("#eef2ed"),"selected":Color("#dceee0"),"leaf":GameData.COLORS.leaf,"gold":GameData.COLORS.gold,"coral":GameData.COLORS.coral,"blue":GameData.COLORS.water}
	var bg:Color=colors.get(kind,colors.plain);var box:=StyleBoxFlat.new();box.bg_color=bg;box.set_corner_radius_all(10);box.border_color=bg.darkened(.12);box.set_border_width_all(1);var hover:=box.duplicate();hover.bg_color=bg.lightened(.08);var pressed:=box.duplicate();pressed.bg_color=bg.darkened(.08)
	button.add_theme_stylebox_override("normal",box);button.add_theme_stylebox_override("hover",hover);button.add_theme_stylebox_override("pressed",pressed);button.add_theme_color_override("font_color",Color.WHITE if kind in ["leaf","coral","blue"] else GameData.COLORS.ink);button.add_theme_color_override("font_hover_color",Color.WHITE if kind in ["leaf","coral","blue"] else GameData.COLORS.ink)

func add_toggle(parent:Node,text:String,pos:Vector2,on:bool,callback:Callable)->Button:
	var b:=add_button(parent,("✓  " if on else "○  ")+text,pos,Vector2(405,36),callback,"leaf" if on else "plain");b.alignment=HORIZONTAL_ALIGNMENT_LEFT;return b

func move_stone_slot_texture(entry:Dictionary)->Texture2D:
	var cache_key:String=str(entry.name)
	if move_slot_texture_cache.has(cache_key):return move_slot_texture_cache[cache_key]
	var source:Texture2D=load("res://textures/UI/MoveStoneSlot.png")
	var image:=source.get_image()
	var disabled:=Color8(97,97,97)
	for y in image.get_height():
		for x in image.get_width():
			var pixel:=image.get_pixel(x,y)
			var rgb_key:=(int(round(pixel.r*255.0))<<16)|(int(round(pixel.g*255.0))<<8)|int(round(pixel.b*255.0))
			if MOVE_SLOT_MARKERS.has(rgb_key) and not stone_compatible(MOVE_SLOT_MARKERS[rgb_key],entry):image.set_pixel(x,y,Color(disabled.r,disabled.g,disabled.b,pixel.a))
	var texture:=ImageTexture.create_from_image(image);move_slot_texture_cache[cache_key]=texture;return texture

func draw_slot(parent:Node,pos:Vector2,available:bool,text_value:String,move_index:=-1,stone_index:=-1,entry:Dictionary={})->void:
	var slot:=TextureRect.new();slot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;slot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;slot.custom_minimum_size=Vector2.ZERO;slot.texture=move_stone_slot_texture(entry);slot.position=pos-Vector2(1,1);slot.size=Vector2(36,36);slot.clip_contents=true;slot.modulate=Color(1,1,1,1 if available else .3);slot.mouse_filter=Control.MOUSE_FILTER_STOP;parent.add_child(slot)
	if not text_value.is_empty():
		var info:=GameData.stone_info(text_value)
		if not info.is_empty():
			var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2.ZERO;icon.texture=move_stone_display_texture(text_value);icon.position=Vector2.ZERO;icon.size=slot.size;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(icon);slot.tooltip_text="%s — %s\nRight-click to remove."%[info.name,info.desc]
			slot.gui_input.connect(_on_stone_slot_input.bind(move_index,stone_index))

func _on_stone_slot_input(event:InputEvent,move_index:int,stone_index:int)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:remove_fitted_stone(move_index,stone_index)

func toast(_message:String,_color:Color)->void:
	# Transient top-center notification banners are intentionally disabled.
	pass

func tag_summary(tags:Dictionary)->String:
	var parts:Array[String]=[]
	for tag in tags:parts.append("%s ×%d"%[tag,tags[tag]])
	return ", ".join(parts)

func requirement_text(need:Dictionary)->String:
	if need.is_empty():return "any five ingredients"
	var parts:Array[String]=[]
	for tag in need:parts.append("%s ×%d"%[tag,need[tag]])
	return ", ".join(parts)

func ingredient_tag_text(info:Dictionary)->String:
	var tags:Array[String]=[]
	for tag in info.tags:tags.append(str(tag).capitalize())
	return ", ".join(tags)

func add_ingredient_icon(parent:Node,info:Dictionary,pos:Vector2,icon_size:Vector2,font_size:int)->Control:
	var texture:=GameData.ingredient_texture(info)
	if texture!=null:
		var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.custom_minimum_size=Vector2.ZERO;icon.texture=texture;icon.position=pos;icon.size=icon_size;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.clip_contents=true;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(icon);return icon
	var fallback:=Label.new();fallback.text=info.get("icon","?");fallback.position=pos;fallback.size=icon_size;fallback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;fallback.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;fallback.add_theme_font_size_override("font_size",font_size);fallback.add_theme_color_override("font_color",info.get("color",GameData.COLORS.ink));fallback.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(fallback);return fallback

func charm_pips(count:int,max_count:int)->String:
	return "◆".repeat(count)+"◇".repeat(max_count-count)

func metric_color(value:String)->Color:
	return GameData.COLORS.leaf if value=="Good" else (GameData.COLORS.gold if value=="Mixed" else GameData.COLORS.coral)
