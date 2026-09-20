extends SceneTree

func _initialize() -> void:
	var expected_species := ["Plip","Swellit","Spriggle","Frondle","Vinee","Bloomie","Sparko","Scorchit","Fistor","Carapuff","Burlow","Stackle","Shellmie","Mimbit","Pidler","Gloopit","Blubber","Cysicle","Gagglet","Gaggle","Gulper","Tumblet","Miasmum","Sludgle","Arcle","Zippet","Voltick","Electrish"]
	var expected_types := ["Water","Water","Green","Green","Green","Green","Fire","Fire","Psychic","Psychic","Earth","Earth","Normal","Normal","Normal","Poison","Air","Ice","Air","Air","Poison","Earth","Poison","Poison","Electric","Electric","Electric","Electric"]
	var expected_learnsets := [
		["Water Shot","Water Jet","Splash Dash","Backwash","Water Burst","Rain Drop","Spray"],
		["Water Shot","Water Jet","Hydro Shot","Breaker","Riptide","Undertow","Whirlpool","Wave Rush","Tidal Wave","Water Spout","Downpour","Tsunami"],
		["Leaf Shot","Seed Pop","Sprout","Thorn Burst","Spore Cloud","Seed Mine","Soothing Scent"],
		["Leaf Shot","Vine Whip","Vine Spear","Rootbind","Thorn Burst","Sprout","Seed Pop","Overgrowth","Root Slam","Growth Spurt","Seed Mine"],
		["Vine Whip","Vine Spear","Vine Grab","Rootbind","Thorn Burst","Sprout","Seed Mine","Root Slam","Leech Bloom"],
		["Healing Bloom","Pollen Puff","Soothing Scent","Spore Cloud","Thorn Armor","Cocoon","Last Bloom"],
		["Fireball","Flame Burst","Spark Burst","Flare","Flame Dash","Flame Pillar","Ignite"],
		["Fireball","Flame Burst","Flare","Flame Dash","Blazing Rush","Flame Wave","Firestorm","Inferno","Flame Pillar","Ignite","Meteor Ember"],
		["Mind Jab","Psycho Punch","Fist Barrage","Helping Hand"],
		["Psy Bolt","Psychic Push","Telekinesis","Psychic Pull","Psy Barrier","Gravity Well","Mind Squeeze","Psy Wall","Psy Bounce","Puff Grab","Mind Pop"],
		["Rock Toss","Quake","Mud Shot","Pitfall","Sinkhole","Burrow","Groundbreaker","Dust Cloud","Dig Punch","Dust-Up","Tunneling Charge"],
		["Rock Toss","Quake","Stone Spikes","Stone Wall","Rock Armor","Boulder Roll","Earth Pillar","Brace","Crush","Barricade","Rock Scatter"],
		["Shell Bash","Guard","Taunt","Spin","Fortify","Cover","Body Block","Hunker Down","Shelter"],
		["Distract","Cheer","Encourage","Copycat"],
		["Web Shot","Web Snare","Web Yank","Web Line","Web Trap","Silk Sling","Tangle","Cocoon"],
		["Poison Spit","Gunk Glob","Corrode","Blinding Gunk","Toxic Pop","Noxious Cloud","Acid Rain","Nauseate","Fume Burst","Poison Bomb"],
		["Gust","Air Burst","Updraft","Vacuum","Crosswind","Tailwind","Whirlwind","Wind Wall","Downdraft","Cyclone","Deflate"],
		["Icicle Shot","Ice Spike","Cold Snap","Ice Wall","Frost Patch","Ice Cage","Glacier Rush","Hail","Iceberg","Icicle Mine","Shatter"],
		["Wingbeat","Honk","Peck","Feather Guard","Tailwind","Scare","Escort","Alarm Honk"],
		["Wingbeat","Honk","Peck","Feather Guard","Tailwind","Scare","Escort","Alarm Honk","Double Honk","Two-Headed Watch","Cross Peck","Gaggle Rush"],
		["Gulp","Poison Spit","Poison Bomb","Slosh","Acid Spray","Nectar","Belch","Sour Shot","Dribble","Lid Smack"],
		["Rollout","Unfurl","Rock Toss","Brace","Rockslide","Pound","Rolling Smash","Stone Skip","Rock Ring","Pebble Spray"],
		["Noxious Cloud","Fume Burst","Poison Spit","Smog","Nauseate","Toxic Drift","Contaminate","Fume Shot","Pressure Cloud","Miasmum"],
		["Toxic Touch","Gunk Glob","Sludge Wave","Slime Slide","Slip Slime","Poison Coat","Acid Splash","Nauseate","Mud Shot","Slick Escape"],
		["Shock Bite","Latch","Live Wire","Static Pulse","Tail Zap","Discharge","Slither","Shock Toss","Amp Drain"],
		["Zap","Shock Touch","Zip","Jolt Kick","Static Pulse","Flashstep","Friction Dash","Thunderclap","Zigzag"],
		["Horn Zap","Spark Ram","Clamp","Shock Toss","Ground Scrape","Static Pulse","Discharge","Grounded","Horn Lift","Shock Clamp"],
		["Tentacle Zap","Static Pulse","Nerve Sting","Shock Net","Live Wire","Jelly Drift","Discharge","Jolt Grab"]
	]
	assert(GameData.SPECIES.size()==28 and GameData.LEARNSETS.size()==28,"The roster and learnset table should each contain twenty-eight Quiblets")
	for i in expected_species.size():
		assert(GameData.SPECIES[i].name==expected_species[i] and GameData.SPECIES[i].element==expected_types[i],"Incorrect Quiblet identity at roster index %d"%i)
		assert(GameData.learnset(i)==expected_learnsets[i],"Incorrect learnset for "+expected_species[i])
		for move_name in expected_learnsets[i]:assert(GameData.MOVES.has(move_name),"Missing move definition: "+move_name)
	for move_name in GameData.MOVES:
		assert(GameData.MOVES[move_name].has("desc") and not str(GameData.MOVES[move_name].desc).is_empty(),"Move needs a description: "+move_name)
	for ingredient_name in GameData.INGREDIENTS:
		var ingredient_info:Dictionary=GameData.INGREDIENTS[ingredient_name]
		assert(not str(ingredient_info.get("texture","")).is_empty() and ResourceLoader.exists(str(ingredient_info.texture)) and GameData.ingredient_texture(ingredient_info)!=null,"Ingredient texture is missing or disconnected: "+ingredient_name)
		assert(not str(ingredient_info.feel).is_empty() and str(ingredient_info.feel).ends_with("."),"Ingredient needs a complete description: "+ingredient_name)
	var packed := load("res://main.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var ui_nodes_before_banner:int=game.ui.find_children("*","",true,false).size()
	game.toast("Banner regression check",Color.WHITE)
	assert(game.ui.get_child_count()==1 and game.ui.find_children("*","",true,false).size()==ui_nodes_before_banner,"Status messages should not create a top-center banner or notification overlay")
	assert(game.roster.size()==1 and game.team_indices==[0] and GameData.display_name(game.roster[0])=="Plip" and game.roster[0].level==6,"A new game should start with a single level-6 Plip")
	assert(game.ingredients.values().all(func(amount):return int(amount)==0) and game.special_items.values().all(func(amount):return int(amount)==0),"A new game should start with no ingredients or special items")
	assert(game.unlocked_ingredients.is_empty(),"A new game should start with every ingredient undiscovered")
	game.show_cooking();await process_frame
	assert(game.content.find_child("BountifulBerryCard",true,false)==null and game.content.find_child("EmptyLeftoverJarCard",true,false)==null and game.content.find_child("MatchingLeftoversCard",true,false)==null,"Unavailable special ingredients should not appear in Cooking")
	game.show_camp();await process_frame
	assert(game.move_stone_inventory.size()==GameData.MOVE_STONES.size() and game.move_stone_inventory.values().all(func(amount):return int(amount)==0) and game.power_stone_inventory.is_empty() and game.leftovers.is_empty(),"A new game should start with no Move Stones or Power Stones")
	assert(game.roster[0].power_stones.is_empty() and game.roster[0].moves.all(func(move):return move.stones.is_empty()),"Starter Plip should have no fitted Move Stones or Power Stones")
	var innate_signatures:={}
	for starter in game.roster+[GameData.make_quiblet(1,6),GameData.make_quiblet(2,6)]:
		assert(starter.power_slot_types.size()==16 and starter.power_slot_types.all(func(slot_type):return slot_type in ["Health","Attack","Flex"]) and starter.power_slot_types.has("Health") and starter.power_slot_types.has("Attack") and starter.power_slot_unlocks.size()==16 and starter.power_slot_unlocks.count(1)==1,"Each Quiblet should acquire a fixed 4×4 board with unique unlock levels and one Lv1 slot")
		innate_signatures["|".join(starter.power_slot_types)+str(starter.power_slot_unlocks)]=true
	assert(innate_signatures.size()>1,"Innate power-slot layouts should be randomly generated per individual Quiblet")
	for spice_name in game.spice_inventory:
		assert(game.spice_inventory[spice_name].values().all(func(amount):return int(amount)==0),"A new game should start with no spices")
	# Populate a test-only fixture after validating the true new-game state.
	var fixture_resources:={"Bumbleberry":12,"Emberpepper":10,"Dewmelon":11,"Knobroot":12,"Curlcap":9,"Stonebean":8,"Honeybulb":8,"Bitterleaf":10,"Puffshroom":7,"Crystalcorn":8,"Brinepod":7,"Sparkfruit":6,"Oldroot":6,"Glowcap":6,"Frostberry":5,"Sunplum":4}
	for item_name in fixture_resources:
		game.ingredients[item_name]=fixture_resources[item_name]
		if not game.unlocked_ingredients.has(item_name):game.unlocked_ingredients.append(item_name)
	game.special_items["Bountiful Berry"]=1;game.special_items["Fortune Charm"]=2;game.special_items["Challenger's Charm"]=2
	game.spice_inventory["Hot Flakes"]["basic"]=1;game.spice_inventory["Gentle Herb"]["basic"]=1
	game.roster.append(GameData.make_quiblet(1,8));game.roster.append(GameData.make_quiblet(2,7))
	for extra_index in 14:game.roster.append(GameData.make_quiblet(extra_index%GameData.SPECIES.size(),3+extra_index))
	game.team_indices.clear();game.team_indices.append_array([0,1,2]);game.show_camp();await process_frame
	var edit_team_buttons:Array=game.content.find_children("*","Button",true,false).filter(func(button):return button.text=="EDIT TEAM")
	assert(edit_team_buttons.size()==1,"Camp should have one Edit Team button")
	var camp_team_panel:Panel=game.content.find_child("CampTeamPanel",true,false);var camp_team_labels:Array=camp_team_panel.find_children("*","Label",true,false)
	assert(camp_team_labels.any(func(entry):return entry.text.begins_with("Lv. ")),"Camp team cards should show the level above each Quiblet")
	assert(not camp_team_labels.any(func(entry):return entry.text.begins_with("XP ")),"Camp team cards should not show XP text")
	assert(not camp_team_labels.any(func(entry):return entry.text.contains("♥") or entry.text.contains("⚔")),"Camp team cards should not show HP or Attack values")
	edit_team_buttons[0].pressed.emit();await process_frame
	assert(game.screen=="all_quiblets" and game.content.find_child("QuibletGrid",true,false)!=null,"Edit Team should open the separate paged All Quiblets menu")
	assert(game.content.find_children("TeamSlot*","",true,false).size()==5,"All Quiblets should always show five drag-and-drop team slots")
	var rebuilt_team_section:Panel=game.content.find_child("TeamSection",true,false);var rebuilt_info_section:Panel=game.content.find_child("QuibletInfo",true,false);var rebuilt_list_section:Panel=game.content.find_child("OwnedQuiblets",true,false)
	assert(rebuilt_team_section.size==Vector2(560,624) and rebuilt_info_section.size==Vector2(460,189) and rebuilt_list_section.size==Vector2(646,417),"The roster screen should use a narrow full-height team visualizer, half-height info panel at its original width, and a wide grid beneath it")
	var info_xp_bar:ProgressBar=rebuilt_info_section.find_child("QuibletXPBar",true,false);var info_level_label:Label=rebuilt_info_section.find_children("*","Label",true,false).filter(func(entry):return entry.text.begins_with("Lv. "))[0]
	assert(info_xp_bar.get_theme_stylebox("fill").bg_color==Color("#4b9fda"),"The Quiblet info XP bar should have a blue fill")
	assert(info_xp_bar!=null and info_xp_bar.size.x==116.5 and info_xp_bar.scale.y==.5 and info_xp_bar.position.x==info_level_label.position.x and info_xp_bar.position.y>info_level_label.position.y and not rebuilt_info_section.find_children("*","Label",true,false).any(func(entry):return entry.text.contains(" XP")),"The Quiblet info XP bar should be half-sized beneath the level and should not show exact required XP text")
	var health_badge:Panel=rebuilt_info_section.find_child("HealthStatBadge",true,false);var attack_badge:Panel=rebuilt_info_section.find_child("AttackStatBadge",true,false)
	assert(health_badge!=null and attack_badge!=null and health_badge.position.x==attack_badge.position.x and health_badge.position.y<attack_badge.position.y,"Health and Attack should appear as vertically stacked stat rectangles")
	assert(health_badge.find_child("HealthStatBadgeIcon",true,false).texture.resource_path=="res://textures/UI/HealthIcon.png" and attack_badge.find_child("AttackStatBadgeIcon",true,false).texture.resource_path=="res://textures/UI/AttackIcon.png" and not rebuilt_info_section.find_children("*","Label",true,false).any(func(entry):return entry.text in ["HEALTH","ATTACK"]),"Quiblet stats should use their icons instead of Health or Attack text")
	assert(game.content.find_child("TeamPreview3D",true,false)!=null and game.team_preview_models.size()==game.team_indices.size(),"The team section should include a 3D formation preview")
	assert(game.team_preview_models.all(func(entry):return is_instance_valid(entry.ring) and is_zero_approx(entry.ring.disc.rotation.x)),"Every preview member should stand on a horizontal colored directional team ring")
	assert(game.team_preview_models.all(func(entry):return is_equal_approx(absf(wrapf(entry.ring.rotation.y-entry.model.rotation.y,-PI,PI)),PI)),"Team-ring arrows should have the requested 180-degree facing offset")
	assert(game.content.find_children("QuibletCard*","",true,false).size()==15 and rebuilt_list_section.find_children("*","ScrollContainer",true,false).is_empty(),"The owned list should show one fixed page of Quiblets without scrolling")
	var roster_grid:GridContainer=game.content.find_child("QuibletGrid",true,false);var compact_cards:Array=game.content.find_children("QuibletCard*","",true,false)
	var listed_levels:Array=roster_grid.get_children().map(func(card):return int(game.roster[card.roster_index].level))
	assert(listed_levels==game.sorted_roster_indices().slice(0,15).map(func(index):return int(game.roster[index].level)) and range(listed_levels.size()-1).all(func(i):return listed_levels[i]>=listed_levels[i+1]),"The owned list should run from the highest level down")
	var bench_card:Control=compact_cards.filter(func(card):return not game.team_indices.has(card.roster_index))[0];var bench_style:StyleBoxFlat=bench_card.get_theme_stylebox("panel")
	var roster_team_card:Control=compact_cards.filter(func(card):return game.team_indices.has(card.roster_index))[0];var team_style:StyleBoxFlat=roster_team_card.get_theme_stylebox("panel")
	assert(bench_style.bg_color==Color.WHITE and bench_style.border_color==Color("#b9bec4") and team_style.bg_color!=Color.WHITE,"Quiblets outside the team should use white tiles with gray borders")
	assert(roster_grid!=null and roster_grid.columns==5 and compact_cards.all(func(card):return card.size==Vector2(104,104)) and compact_cards[5].position.y>compact_cards[0].position.y and compact_cards.all(func(card):return card.find_children("*","Label",true,false).any(func(entry):return entry.text.begins_with("Lv. "))),"Owned Quiblets should be compact portrait-and-level squares in a horizontal-and-vertical page grid")
	var roster_dots:Label=rebuilt_list_section.find_child("PageDots",true,false);var roster_next:Button=rebuilt_list_section.find_child("NextPage",true,false)
	assert(roster_dots!=null and roster_dots.text.contains("●") and roster_dots.text.contains("○") and not roster_next.disabled,"Multiple Quiblet pages should show dots and an enabled next arrow")
	roster_next.pressed.emit();await process_frame;assert(game.quiblet_inventory_page==1 and game.content.find_children("QuibletCard*","",true,false).size()==2,"The Quiblet next-page arrow should open the next fixed page")
	game.set_quiblet_page(0);await process_frame
	var team_slots:Array=game.content.find_children("TeamSlot*","",true,false);assert(team_slots[3]._can_drop_data(Vector2.ZERO,{"kind":"quiblet","roster_index":0}),"Team slots should accept dragged owned Quiblets")
	var old_first:int=game.team_indices[0];var old_third:int=game.team_indices[2];game.assign_team_slot(0,old_third);await process_frame
	assert(game.team_indices[0]==old_third and game.team_indices[2]==old_first,"Dropping a team member onto another occupied slot should swap them")
	game.assign_team_slot(0,old_first);await process_frame
	var dragged_team_member:int=game.team_indices[1];var team_drag_data:Dictionary=game.take_team_member_for_drag(1,dragged_team_member)
	game.assign_team_slot(0,dragged_team_member);game.finish_team_drag();await process_frame
	assert(team_drag_data.kind=="quiblet" and game.team_indices==[dragged_team_member,old_first,old_third],"Dropping an occupied team slot onto another slot should transfer it without removing either Quiblet")
	game.assign_team_slot(0,old_first);await process_frame
	team_drag_data=game.take_team_member_for_drag(1,dragged_team_member);game.finish_team_drag();await process_frame
	assert(not game.team_indices.has(dragged_team_member),"Dragging a Quiblet out of its team slot and dropping it elsewhere should remove it from the team")
	game.team_indices.assign([old_first,dragged_team_member,old_third]);game.show_all_quiblets();await process_frame
	game.show_camp();await process_frame;await process_frame
	await physics_frame
	var pan_press:=InputEventMouseButton.new();pan_press.button_index=MOUSE_BUTTON_LEFT;pan_press.pressed=true;pan_press.position=Vector2(700,180);game._unhandled_input(pan_press)
	var pan_motion:=InputEventMouseMotion.new();pan_motion.position=Vector2(800,180);pan_motion.relative=Vector2(100,0);game._unhandled_input(pan_motion)
	assert(game.camp_pan_x<0.0 and is_equal_approx(game.camera_3d.position.x,game.camp_pan_x),"Dragging horizontally should pan the camp camera")
	var pan_release:=InputEventMouseButton.new();pan_release.button_index=MOUSE_BUTTON_LEFT;pan_release.pressed=false;game._input(pan_release)
	var miss_click:=InputEventMouseButton.new();miss_click.button_index=MOUSE_BUTTON_LEFT;miss_click.pressed=true;miss_click.position=Vector2(1180,100);game._input(miss_click);await process_frame
	assert(game.screen=="camp","Clicking away from the 3D pot should not open cooking")
	var near_miss:=InputEventMouseButton.new();near_miss.button_index=MOUSE_BUTTON_LEFT;near_miss.pressed=true;near_miss.position=game.camera_3d.unproject_position(Vector3(1.7,1.45,0));game._input(near_miss);await process_frame
	assert(game.screen=="camp","Clicking immediately beside the visible pot should not trigger its hitbox")
	var pot_click := InputEventMouseButton.new()
	pot_click.button_index = MOUSE_BUTTON_LEFT
	pot_click.pressed = true
	pot_click.position = game.camera_3d.unproject_position(Vector3(0,.82,0))
	game._input(pot_click)
	await process_frame
	assert(game.screen == "cooking", "Clicking the 3D camp pot should open cooking")
	for textured_ingredient in ["Bumbleberry","Emberpepper","Knobroot","Curlcap"]:
		var texture_path:String=GameData.INGREDIENTS[textured_ingredient].texture
		assert(ResourceLoader.exists(texture_path),"Missing item texture for "+textured_ingredient)
	game.show_team()
	await process_frame
	var team_back:TextureButton=game.content.find_child("BackButton",true,false)
	assert(team_back!=null and team_back.texture_normal.resource_path=="res://textures/UI/BackButton.png" and team_back.size==Vector2(40,40),"Navigation back buttons should use the compact BackButton.png control")
	assert(not game.content.find_children("*","Label",true,false).any(func(entry):return entry.text=="TEAM & MOVES"),"Page-level headers should be removed")
	game.power_stone_inventory.assign([{"type":"Health","power":20},{"type":"Attack","power":35},{"type":"Health","power":50}]);game.move_stone_inventory.clear();game.move_stone_inventory["echo"]=1
	game.roster[game.selected_roster].level=100;game.show_quiblet_edit();await process_frame
	assert(game.screen=="edit_quiblet" and game.content.find_children("PowerStoneSlot*","",true,false).size()==16,"Power Stones should open a separate edit menu with a 4×4 power-slot grid")
	assert(game.content.find_child("QuibletXPBar",true,false).get_theme_stylebox("fill").bg_color==Color("#4b9fda"),"The edit menu XP bar should also have a blue fill")
	var square_power_slots:Array=game.content.find_children("PowerStoneSlot*","",true,false)
	assert(square_power_slots.all(func(slot):return slot.size.x==slot.size.y and slot.get_parent().size==Vector2(54,54)),"Power Stone slots and their drop areas should be square")
	assert(square_power_slots.all(func(slot):return slot.position==Vector2.ZERO and slot.size==slot.get_parent().size and slot.get_parent().get_theme_stylebox("panel").corner_detail==1),"Power Stone slots should have matching clipped corners and no inset between the background and stone bounds")
	var first_power_rect:Rect2=square_power_slots[0].get_parent().get_global_rect();var next_power_rect:Rect2=square_power_slots[1].get_parent().get_global_rect();var below_power_rect:Rect2=square_power_slots[4].get_parent().get_global_rect()
	assert(is_equal_approx(next_power_rect.position.x-first_power_rect.end.x,below_power_rect.position.y-first_power_rect.end.y),"Power Stone slots should have equal horizontal and vertical gaps")
	var power_grid:Control=game.content.find_child("PowerStoneGrid",true,false)
	assert(power_grid.position.x==20,"The Power Stone grid should align to the equipment menu's left inset")
	assert(power_grid.position.y+power_grid.size.y*power_grid.scale.y<=power_grid.get_parent().size.y-11.9,"All four rows of Power Stone slots should fit inside the equipment menu")
	var power_slot_type_icons:Array=game.content.find_children("PowerSlotTypeIcon","TextureRect",true,false)
	var typed_slot_count:int=game.roster[game.selected_roster].power_slot_types.size()
	assert(power_slot_type_icons.size()==typed_slot_count and power_slot_type_icons.all(func(icon):return icon.size==Vector2(27.5,25) and icon.position==(icon.get_parent().size-icon.size)*.5),"Health and Attack slot indicators should be 1.25× their previous size and centered without resizing their slots")
	assert(game.content.find_child("StoneEquipmentMenu",true,false)!=null and game.content.find_child("MoveStonePlaque",true,false)==null and game.content.find_child("PowerStonePlaque",true,false)==null,"Move Stone and Power Stone slots should share one equipment menu")
	assert(game.content.find_children("MoveStoneSlot*","",true,false).all(func(slot):return slot.size==Vector2(59.0625,59.0625)),"Move Stone slots should be scaled to 0.9× their previous size")
	var fitted_slot_probe:=Control.new();fitted_slot_probe.size=Vector2(59.0625,59.0625);game.add_fitted_move_stone(fitted_slot_probe,"echo");var fitted_icon_probe:TextureRect=fitted_slot_probe.get_child(0)
	assert(fitted_icon_probe.position==Vector2.ZERO and fitted_icon_probe.size==fitted_slot_probe.size,"A fitted Move Stone should occupy the entire Move Stone slot")
	fitted_slot_probe.free()
	var equipment_menu:Panel=game.content.find_child("StoneEquipmentMenu",true,false);var editable_move_icons:Array=game.content.find_children("EditableMoveIcon*","",true,false)
	assert(equipment_menu.get_theme_stylebox("panel").bg_color==Color("#5f5f5f"),"The combined stone menu background should be RGB 95, 95, 95")
	assert(game.content.find_children("PowerStoneSlot*","",true,false).all(func(slot):return slot.get_parent().get_theme_stylebox("panel").bg_color==Color("#4b4b4b")),"Every Power Stone slot background should be RGB 75, 75, 75")
	var splash_icons:Array=editable_move_icons.filter(func(icon):return icon.move_name=="Splash Dash")
	assert(splash_icons.size()==1 and splash_icons[0].icon_texture.resource_path=="res://textures/Moves/SplashDash.png","Splash Dash should use its supplied texture in the move editor")
	assert(editable_move_icons.size()==game.roster[game.selected_roster].moves.size() and not equipment_menu.find_children("*","Label",true,false).any(func(entry):return GameData.MOVES.has(entry.text) or entry.text.ends_with("s")),"Moves should appear without individual rectangles, names, or cooldown text in the equipment menu")
	assert(editable_move_icons.all(func(icon):return icon.position.y==4) and editable_move_icons[1].position.x>editable_move_icons[0].position.x,"Moves with few unlocked slots should condense onto one row")
	var moves_before_layout_test:Array=game.roster[game.selected_roster].moves.duplicate(true)
	var slot_layouts:Array=[[1,1,1,1],[6,6,1,1],[6,6,6,6]]
	for layout_index in slot_layouts.size():
		game.roster[game.selected_roster].moves=[]
		for fixture_index in 4:
			game.roster[game.selected_roster].moves.append({"name":GameData.learnset(int(game.roster[game.selected_roster].species))[fixture_index],"slots":slot_layouts[layout_index][fixture_index],"stones":[]})
		game.show_quiblet_edit();await process_frame
		var layout_icons:Array=game.content.find_children("EditableMoveIcon*","",true,false);var layout_rows:={}
		for icon in layout_icons:layout_rows[icon.position.y]=true
		assert(layout_rows.size()==[1,3,4][layout_index],"Move groups should wrap into one, three, or four rows according to their unlocked slots")
		var layout_controls:Array=layout_icons+game.content.find_children("MoveStoneSlot*","",true,false)
		for control_index in layout_controls.size():
			var control_rect:Rect2=layout_controls[control_index].get_rect()
			assert(control_rect.position.x>=20 and control_rect.end.x<=600,"Move groups should stay inside the equipment menu")
			for next_control in range(control_index+1,layout_controls.size()):assert(not control_rect.intersects(layout_controls[next_control].get_rect()),"Packed move icons and slots must not overlap")
		var fitted_power_grid:Control=game.content.find_child("PowerStoneGrid",true,false)
		assert(fitted_power_grid.position.x==20 and fitted_power_grid.position.y+fitted_power_grid.size.y*fitted_power_grid.scale.y<=452.1,"The left-aligned Power Stone grid should stay below all move rows and inside the menu")
	game.roster[game.selected_roster].moves=moves_before_layout_test;game.show_quiblet_edit();await process_frame
	var first_move_before:Dictionary=game.roster[game.selected_roster].moves[0].duplicate(true);var second_move_before:Dictionary=game.roster[game.selected_roster].moves[1].duplicate(true)
	game.roster[game.selected_roster].moves[0].slots=2;game.roster[game.selected_roster].moves[0].stones=["echo"];game.show_quiblet_edit();await process_frame
	editable_move_icons=game.content.find_children("EditableMoveIcon*","",true,false)
	var move_reorder_drag_data:Dictionary={"kind":"quiblet_move","move_index":0,"move_name":game.roster[game.selected_roster].moves[0].name}
	assert(editable_move_icons[1]._can_drop_data(Vector2.ZERO,move_reorder_drag_data),"Each move icon should accept another move from the same Quiblet")
	editable_move_icons[1]._drop_data(Vector2.ZERO,move_reorder_drag_data);await process_frame
	assert(game.roster[game.selected_roster].moves[1].name==first_move_before.name and game.roster[game.selected_roster].moves[1].slots==2 and game.roster[game.selected_roster].moves[1].stones==["echo"] and game.roster[game.selected_roster].moves[0].name==second_move_before.name,"Dropping one move onto another should swap the complete moves, including unlocked slots and fitted stones")
	game.roster[game.selected_roster].moves[0]=first_move_before;game.roster[game.selected_roster].moves[1]=second_move_before;game.show_quiblet_edit();await process_frame
	var original_slot_count:int=game.roster[game.selected_roster].moves[0].slots;game.roster[game.selected_roster].moves[0].slots=game.MAX_MOVE_STONE_SLOTS;game.show_quiblet_edit();await process_frame
	var full_slot_row:Array=game.content.find_children("MoveStoneSlot0_*","",true,false);assert(full_slot_row.size()==8 and full_slot_row[-1].position.x+full_slot_row[-1].size.x<820,"A consolidated move row should reserve enough room for eight enlarged Move Stone slots")
	game.roster[game.selected_roster].moves[0].slots=original_slot_count;game.show_quiblet_edit();await process_frame
	equipment_menu=game.content.find_child("StoneEquipmentMenu",true,false);editable_move_icons=game.content.find_children("EditableMoveIcon*","",true,false)
	var inspected_entry:Dictionary=game.roster[game.selected_roster].moves[0];editable_move_icons[0].selected.emit(str(inspected_entry.name));await process_frame
	var move_overlay:ColorRect=game.content.find_child("MoveInfoOverlay",true,false);var move_info_labels:Array=move_overlay.find_children("*","Label",true,false);var supported_count:=0
	for stone in GameData.MOVE_STONES:
		if game.stone_compatible(stone.effect,inspected_entry):supported_count+=1
	var move_description:RichTextLabel=move_overlay.find_child("MoveInfoDescription",true,false)
	assert(move_overlay!=null and move_overlay.find_child("MoveInfoLargeIcon",true,false)!=null and move_info_labels.any(func(entry):return entry.text==inspected_entry.name) and move_description!=null and move_description.text==GameData.MOVES[inspected_entry.name].desc and move_description.autowrap_mode!=TextServer.AUTOWRAP_OFF and not move_description.scroll_active and move_info_labels.any(func(entry):return entry.text.begins_with("Base cooldown:")) and move_info_labels.any(func(entry):return entry.text.begins_with("Base damage:")) and move_overlay.find_children("SupportedMoveStoneIcon*","",true,false).size()==supported_count,"Clicking a move icon should open its dimmed detail menu with wrapped description, stats, large icon, and compatible Move Stones")
	move_overlay.find_child("BackButton",true,false).pressed.emit();await process_frame
	assert(game.move_stone_display_texture("link_from:Water Burst").resource_path=="res://textures/MoveStones/LinkStoneOcupied.png" and game.move_stone_display_texture("link:Water Jet").resource_path==GameData.stone_info("link").texture,"Only the destination side of a linked move should use the occupied Link Stone texture")
	assert(game.roster[game.selected_roster].power_slot_types.all(func(value):return value in ["Health","Attack","Flex"]),"Every power slot has a fixed Health, Attack, or Flex type")
	var inventory_cards:Array=game.content.find_children("StoneInventoryCard*","",true,false)
	assert(inventory_cards.size()==2,"The Health tab should list owned Health stones")
	for inventory_card in inventory_cards:
		var stone_preview:Control=inventory_card.create_stone_drag_preview()
		assert(not stone_preview is Panel and stone_preview.find_children("*","Panel",true,false).is_empty() and stone_preview.modulate.a==1.0,"Both Power and Move Stone inventory drags must show only opaque stone art without a white card behind it")
		if inventory_card.item_data.kind=="move_stone":
			var drag_icon:TextureRect=stone_preview.get_child(0)
			assert(drag_icon.texture.resource_path==GameData.stone_info(str(inventory_card.item_data.effect)).texture and drag_icon.position+drag_icon.size*.5==Vector2.ZERO,"Inventory Move Stone drag previews must center the stone texture on the cursor")
		else:
			var power_drag_icon:Control=stone_preview.get_child(0)
			assert(power_drag_icon.position+power_drag_icon.size*.5==Vector2.ZERO and power_drag_icon.stone.power==inventory_card.item_data.power,"Inventory Power Stone drag previews must center the assembled stone on the cursor")
		stone_preview.free()
	assert(inventory_cards.all(func(card):return card.size.y==74 and card.size.x>74 and card.find_children("*","Label",true,false).is_empty()) and game.content.find_child("StoneIconGrid",true,false).columns==6,"The expanded stone inventory should fit six columns of icons")
	assert(inventory_cards.all(func(card):return card.item_data.stone_type=="Health") and inventory_cards[0].item_data.power==50 and inventory_cards[1].item_data.power==20,"Health stones sort highest power first within their tab")
	var health_slot:int=GameData.first_power_slot_accepting(game.roster[game.selected_roster],"Health");var health_slot_type:String=game.roster[game.selected_roster].power_slot_types[health_slot]
	var power_count_before:int=game.power_stone_inventory.size();game.equip_stone_from_inventory("power",health_slot,-1,inventory_cards[0].item_data);await process_frame
	assert(game.roster[game.selected_roster].power_slot_types[health_slot]==health_slot_type and game.roster[game.selected_roster].power_slot_stones[health_slot].power==50 and game.power_stone_inventory.size()==power_count_before-1,"Dropping into an unlocked compatible power slot should equip the stone without changing the slot's fixed type")
	var power_drag_data:Dictionary=game.take_equipment_for_drag("power",health_slot,-1)
	assert(game.roster[game.selected_roster].power_slot_stones[health_slot].is_empty() and game.roster[game.selected_roster].power_slot_types[health_slot]==health_slot_type and game.power_stone_inventory.size()==power_count_before and power_drag_data.kind=="power_stone","Dragging an equipped Power Stone out should detach it and return it to the owned inventory")
	game.equip_stone_from_inventory("power",health_slot,-1,power_drag_data);await process_frame
	assert(game.roster[game.selected_roster].power_slot_stones[health_slot].power==50 and game.power_stone_inventory.size()==power_count_before-1,"An equipped Power Stone drag should remain transferable to a compatible slot")
	game.remove_equipped_stone("power",health_slot,-1);await process_frame
	assert(game.roster[game.selected_roster].power_slot_stones[health_slot].is_empty() and game.power_stone_inventory.size()==power_count_before,"Right-click removal should return a Power Stone to inventory")
	game.move_stone_inventory["echo"]=1;game.equip_stone_from_inventory("move",0,0,{"kind":"move_stone","effect":"echo"});await process_frame
	var dragged_move_slot:Control=game.content.find_child("MoveStoneSlot0_0",true,false)
	var move_drag_data:Dictionary=game.take_equipment_for_drag("move",0,0)
	assert(move_drag_data.effect=="echo" and game.roster[game.selected_roster].moves[0].stones.is_empty() and game.move_stone_inventory["echo"]==1,"Dragging an equipped Move Stone out should detach it and return it to the owned inventory")
	assert(dragged_move_slot.get_child_count()==0,"The fitted stone graphic must disappear immediately when a drag removes it, before the drag ends")
	var move_stone_drag_preview:Control=dragged_move_slot.create_equipment_drag_preview(move_drag_data)
	assert(not move_stone_drag_preview is TextureRect and move_stone_drag_preview.modulate.a==1.0 and move_stone_drag_preview.get_child_count()==1 and move_stone_drag_preview.get_child(0).texture.resource_path==GameData.stone_info("echo").texture,"Dragging an equipped Move Stone should show only the opaque stone, not a faded copy of its slot")
	var equipped_drag_icon:TextureRect=move_stone_drag_preview.get_child(0)
	assert(equipped_drag_icon.position+equipped_drag_icon.size*.5==Vector2.ZERO,"Equipped Move Stone drag previews must also center the stone on the cursor")
	move_stone_drag_preview.free()
	game.finish_equipment_drag();await process_frame
	game.move_stone_inventory["echo"]=20;game.stone_inventory_tab="Moves";game.stone_inventory_page=0;game.show_quiblet_edit();await process_frame
	var stone_panel:Panel=game.content.find_child("StoneInventory",true,false);var stone_dots:Label=stone_panel.find_child("PageDots",true,false);var stone_next:Button=stone_panel.find_child("NextPage",true,false)
	assert(game.content.find_children("StoneInventoryCard*","",true,false).size()==18 and stone_dots.text.contains("○") and not stone_next.disabled,"A full stone page should show eighteen icon squares and multiple page dots")
	stone_next.pressed.emit();await process_frame;assert(game.stone_inventory_page==1 and game.content.find_children("StoneInventoryCard*","",true,false).size()==2,"The stone next-page arrow should open the remaining icon squares")
	game.move_stone_inventory["echo"]=1;game.stone_inventory_page=0;game.show_quiblet_edit();await process_frame
	var sharing_info:Dictionary=GameData.stone_info("sharing");game.select_inventory_stone({"kind":"move_stone","effect":"sharing","display_name":sharing_info.name});await process_frame
	var stone_detail_title:Label=game.content.find_child("StoneDetailTitle",true,false);var stone_detail_description:RichTextLabel=game.content.find_child("StoneDetailDescription",true,false)
	assert(stone_detail_title.text=="Sharing Stone" and stone_detail_description.autowrap_mode!=TextServer.AUTOWRAP_OFF and stone_detail_description.size.x==482 and not stone_detail_description.scroll_active,"Move Stone details should use the full Stone name and wrap descriptions inside the menu")
	game.selected_inventory_item.clear();game.show_quiblet_edit();await process_frame
	var source_counts:=image_color_counts(load("res://textures/UI/MoveStoneSlot.png").get_image())
	var projectile_entry:Dictionary=game.roster[game.selected_roster].moves[0]
	assert(game.move_slot_texture_cache.has(projectile_entry.name))
	var projectile_counts:=image_color_counts(game.move_slot_texture_cache[projectile_entry.name].get_image())
	for rgb_key in game.MOVE_SLOT_MARKERS:
		assert(int(source_counts.get(rgb_key,0))>0,"MoveStoneSlot is missing a configured compatibility color")
		var effect:String=game.MOVE_SLOT_MARKERS[rgb_key]
		if game.stone_compatible(effect,projectile_entry):assert(projectile_counts.get(rgb_key,0)==source_counts.get(rgb_key,0),"Compatible marker was incorrectly grayed: "+effect)
		else:assert(int(projectile_counts.get(rgb_key,0))==0,"Incompatible marker retained its color: "+effect)
	game.show_resources()
	await process_frame
	var resource_cards:Array=game.content.find_children("*","IngredientDragCard",true,false)
	assert(resource_cards.size()==GameData.INGREDIENTS.size(),"Resources should list every ingredient as a drag card, like Cooking")
	game.select_cooking_ingredient("Bumbleberry");await process_frame
	assert(game.content.find_child("SelectedIngredientIcon",true,false)!=null,"Clicking a resource shows its info in the shared panel")
	game.show_cooking()
	await process_frame
	var cooking_back:TextureButton=game.content.find_child("BackButton",true,false)
	assert(cooking_back!=null and cooking_back.texture_normal.resource_path=="res://textures/UI/BackButton.png","Cooking should use the shared textured back button")
	var all_cooking_slots:Array=game.content.find_children("*","PotDropSlot",true,false)
	assert(all_cooking_slots.size()==9,"Cooking pot should expose five ingredient, two spice, and two special slots")
	var cooking_pot_texture:TextureRect=game.content.find_child("CookingPotTexture",true,false)
	assert(cooking_pot_texture!=null and cooking_pot_texture.size==Vector2(512,512),"The high-resolution Cooking Pot texture should remain fitted to its original 512×512 display area; got "+str(cooking_pot_texture.size if cooking_pot_texture!=null else Vector2.ZERO))
	assert(all_cooking_slots.all(func(slot):return Rect2(cooking_pot_texture.position,cooking_pot_texture.size).encloses(Rect2(slot.position,slot.size))),"Every cooking slot must remain aligned inside the resized pot texture")
	assert(all_cooking_slots.filter(func(slot):return slot.slot_kind=="ingredient").size()==5,"Only the bottom five slots should accept ingredients")
	assert(all_cooking_slots.filter(func(slot):return slot.slot_kind=="spice").size()==2,"The middle two slots should accept spices")
	assert(all_cooking_slots.filter(func(slot):return slot.slot_kind=="special").size()==2,"The upper two slots should accept special ingredients")
	assert(game.content.find_child("BountifulBerryCard",true,false)!=null and game.content.find_child("EmptyLeftoverJarCard",true,false)==null,"Cooking should show owned special ingredients and hide unavailable ones")
	var bumbleberry_before:int=game.ingredients["Bumbleberry"]
	game.assign_pot_slot(0,"Bumbleberry")
	await process_frame
	assert(game.ingredients["Bumbleberry"]==bumbleberry_before-3,"Dropping an ingredient should reserve three units")
	assert(game.pot_slots[0]=="Bumbleberry")
	var filled_ingredient_slot:PotDropSlot=game.content.find_children("*","PotDropSlot",true,false).filter(func(slot):return slot.slot_kind=="ingredient" and slot.slot_index==0)[0]
	assert(filled_ingredient_slot.has_method("_get_drag_data"),"Occupied ingredient slots must originate drag operations")
	var right_click:=InputEventMouseButton.new();right_click.button_index=MOUSE_BUTTON_RIGHT;right_click.pressed=true
	filled_ingredient_slot._gui_input(right_click)
	assert(game.pot_slots[0]=="Bumbleberry" and game.ingredients["Bumbleberry"]==bumbleberry_before-3,"Right-clicking should not remove an ingredient from the pot")
	var ingredient_drag:Dictionary=game.detach_cooking_item_for_drag("ingredient",0)
	assert(ingredient_drag=={"kind":"ingredient","name":"Bumbleberry"} and game.pot_slots[0].is_empty() and game.ingredients["Bumbleberry"]==bumbleberry_before,"Dragging an ingredient out should remove it and refund all three units")
	game.assign_cooking_item("ingredient",0,ingredient_drag);await process_frame
	game.clear_pot_slot(0,true)
	await process_frame
	assert(game.ingredients["Bumbleberry"]==bumbleberry_before,"Removing a slotted ingredient should refund three units")
	game.ingredients["Bumbleberry"]=2;game.show_cooking();await process_frame
	var bumbleberry_cards:Array=game.content.find_children("*","IngredientDragCard",true,false).filter(func(card):return card.ingredient_name=="Bumbleberry")
	assert(not bumbleberry_cards.is_empty() and not bumbleberry_cards[0].draggable,"Resources below three should not be draggable")
	game.ingredients["Bumbleberry"]=bumbleberry_before;game.show_cooking();await process_frame
	var cooking_ingredient_grid:GridContainer=game.content.find_child("CookingIngredientGrid",true,false)
	assert(cooking_ingredient_grid!=null and cooking_ingredient_grid.columns==8 and cooking_ingredient_grid.get_child_count()==GameData.INGREDIENTS.size() and game.content.find_child("CookingIngredientScroll",true,false)==null,"Cooking should display all ingredients in a fixed two-row grid without scrolling")
	assert(cooking_ingredient_grid.get_child(8).position.y>cooking_ingredient_grid.get_child(0).position.y,"Cooking ingredients should occupy two rows")
	var ingredient_amount:Label=cooking_ingredient_grid.get_child(0).get_node("IngredientAmount")
	assert(ingredient_amount.get_theme_font_size("font_size")==13 and ingredient_amount.position.y==56,"Ingredient amounts should be 75% sized and shifted upward")
	var ingredient_card_style:StyleBoxFlat=cooking_ingredient_grid.get_child(0).get_theme_stylebox("panel")
	assert(ingredient_card_style.bg_color==Color("#ffffff") and ingredient_card_style.border_color==Color("#d6d6d6"),"Ingredient cards should use white interiors and light-gray outlines")
	game.select_cooking_ingredient("Knobroot");await process_frame;await process_frame
	assert(game.content.find_child("CookingIngredientGrid",true,false).get_child_count()==GameData.INGREDIENTS.size(),"Selecting an ingredient should preserve the complete ingredient grid")
	var selected_item_icon:Control=game.content.find_child("SelectedIngredientIcon",true,false)
	assert(selected_item_icon!=null and selected_item_icon.size==Vector2(48,66) and selected_item_icon.custom_minimum_size==Vector2.ZERO,"A textured item must stay inside its assigned information-menu icon rectangle")
	assert(GameData.INGREDIENTS["Sunplum"].texture=="res://textures/Ingredients/SunPlum.png" and GameData.ingredient_texture(GameData.INGREDIENTS["Sunplum"])!=null,"Sunplum should use its item texture")
	var bumbleberry_texture:=GameData.ingredient_texture(GameData.INGREDIENTS["Bumbleberry"])
	assert(bumbleberry_texture is AtlasTexture and bumbleberry_texture.get_width()<=512 and bumbleberry_texture.get_height()<=512,"Ingredient artwork should be trimmed to its visible 512×512 content before being fitted")
	var drop_slots:Array=game.content.find_children("*","PotDropSlot",true,false).filter(func(slot):return slot.slot_kind=="ingredient")
	assert(drop_slots[0]._can_drop_data(Vector2.ZERO,{"kind":"ingredient","name":"Bumbleberry"}),"Eligible resource drag should be accepted by a pot slot")
	drop_slots[0]._drop_data(Vector2.ZERO,{"kind":"ingredient","name":"Bumbleberry"});await process_frame
	assert(game.pot_slots[0]=="Bumbleberry" and game.ingredients["Bumbleberry"]==bumbleberry_before-3,"Drop callback did not reserve three units")
	game.clear_pot_slot(0,true);await process_frame
	var hot_before:int=game.spice_inventory["Hot Flakes"]["basic"]
	game.assign_cooking_item("spice",0,{"kind":"spice","name":"Hot Flakes","quality":"basic"});await process_frame
	assert(game.spice_slots[0].name=="Hot Flakes" and game.spice_inventory["Hot Flakes"]["basic"]==hot_before-1,"Spice slots should reserve one matching seasoning")
	var filled_spice_slot:PotDropSlot=game.content.find_children("*","PotDropSlot",true,false).filter(func(slot):return slot.slot_kind=="spice" and slot.slot_index==0)[0]
	assert(filled_spice_slot.has_method("_get_drag_data"),"Occupied spice slots must originate drag operations")
	var spice_drag:Dictionary=game.detach_cooking_item_for_drag("spice",0);assert(spice_drag.kind=="spice" and game.spice_slots[0].is_empty(),"Dragging a spice out should remove it from its slot")
	game.assign_cooking_item("spice",0,spice_drag);await process_frame;game.clear_cooking_item("spice",0,true);await process_frame
	assert(game.spice_inventory["Hot Flakes"]["basic"]==hot_before,"Removing a spice should refund it")
	var berry_before:int=game.special_items["Bountiful Berry"]
	game.assign_cooking_item("special",0,{"kind":"special","id":"Bountiful Berry"});await process_frame
	assert(game.special_slots[0]=="Bountiful Berry" and game.special_items["Bountiful Berry"]==berry_before-1,"Special slots should reserve their item")
	var filled_special_slot:PotDropSlot=game.content.find_children("*","PotDropSlot",true,false).filter(func(slot):return slot.slot_kind=="special" and slot.slot_index==0)[0]
	assert(filled_special_slot.has_method("_get_drag_data"),"Occupied special-ingredient slots must originate drag operations")
	var special_drag:Dictionary=game.detach_cooking_item_for_drag("special",0);assert(special_drag.id=="Bountiful Berry" and game.special_slots[0].is_empty(),"Dragging a special ingredient out should remove it from its slot")
	game.assign_cooking_item("special",0,special_drag);await process_frame;game.clear_cooking_item("special",0,true);await process_frame
	assert(game.special_items["Bountiful Berry"]==berry_before,"Removing a special ingredient should refund it")
	game.assign_pot_slot(0,"Bumbleberry");game.assign_cooking_item("spice",0,{"kind":"spice","name":"Hot Flakes","quality":"basic"});game.assign_cooking_item("special",0,{"kind":"special","id":"Bountiful Berry"});await process_frame
	game.request_leave_cooking(game.show_camp);await process_frame
	assert(game.screen=="cooking" and game.content.find_child("CookingLeaveConfirmation",true,false)!=null and game.cooking_has_placed_items(),"Leaving with filled cooking slots should require confirmation")
	game.content.find_child("CancelCookingExit",true,false).pressed.emit();await process_frame
	assert(game.screen=="cooking" and game.cooking_has_placed_items(),"Canceling the leave confirmation should preserve every cooking slot")
	game.request_leave_cooking(game.show_camp);game.content.find_child("ConfirmCookingExit",true,false).pressed.emit();await process_frame
	assert(game.screen=="camp" and not game.cooking_has_placed_items() and game.ingredients["Bumbleberry"]==bumbleberry_before and game.spice_inventory["Hot Flakes"]["basic"]==hot_before and game.special_items["Bountiful Berry"]==berry_before,"Confirming should return all cooking items before leaving")
	game.show_cooking();await process_frame
	game.unlocked_ingredients.erase("Sunplum");game.show_cooking();await process_frame
	var locked_cards:Array=game.content.find_children("*","IngredientDragCard",true,false).filter(func(card):return card.ingredient_name=="Sunplum")
	assert(not locked_cards.is_empty() and not locked_cards[0].unlocked and not locked_cards[0].draggable,"Locked resource display should be disabled")
	game.unlocked_ingredients.append("Sunplum")
	# The spice workshop: five drag slots, an info panel, and spices hidden until made.
	game.clear_spice_mix(false);game.spice_mix.clear();game.unlocked_spices.erase("Rare Spice");game.show_spice_workshop();await process_frame
	assert(game.content.find_children("SpiceMixSlot*","",true,false).size()==5,"The mixing bowl should have five drag slots")
	assert(game.content.find_child("SpiceRecipeBrowser",true,false)!=null and game.content.find_child("OwnedSpices",true,false)!=null,"The workshop has a recipe viewer and an owned tier list")
	var rare_before:int=game.spice_inventory["Rare Spice"]["special"]
	var plum_before:int=game.ingredients["Sunplum"];var spark_before:int=game.ingredients["Sparkfruit"];var brine_before:int=game.ingredients["Brinepod"]
	# Dragging a resource in consumes it immediately, like the cooking pot.
	game.place_spice_ingredient(0,"Sunplum");game.place_spice_ingredient(1,"Sparkfruit");game.place_spice_ingredient(2,"Brinepod");await process_frame
	assert(game.spice_mix.size()==3 and game.ingredients["Sunplum"]==plum_before-1 and game.ingredients["Sparkfruit"]==spark_before-1 and game.ingredients["Brinepod"]==brine_before-1,"Placing resources should consume one of each on the spot")
	assert(GameData.choose_spice(game.spice_mix).is_empty(),"Three ingredients cannot produce a spice")
	game.select_cooking_ingredient("Sunplum");await process_frame
	assert(game.content.find_child("SelectedIngredientIcon",true,false)!=null,"Clicking a resource shows its info panel")
	# Detaching a bowl slot refunds the resource.
	game.detach_spice_ingredient_for_drag(2);await process_frame
	assert(game.spice_mix.size()==2 and game.ingredients["Brinepod"]==brine_before,"Dragging a resource out of the bowl refunds it")
	game.place_spice_ingredient(2,"Brinepod");game.place_spice_ingredient(3,"Sunplum");game.place_spice_ingredient(4,"Sparkfruit")
	assert(GameData.choose_spice(game.spice_mix).name=="Rare Spice","Five matching ingredients produce Rare Spice")
	game.craft_spice();await process_frame
	assert(game.spice_inventory["Rare Spice"]["special"]==rare_before+1 and game.unlocked_spices.has("Rare Spice"),"Crafting should bank the seasoning by quality and unlock it")
	assert(game.ingredients["Sunplum"]==plum_before-2 and game.ingredients["Sparkfruit"]==spark_before-2 and game.ingredients["Brinepod"]==brine_before-1 and game.spice_mix.is_empty(),"Crafting consumes only what was placed and empties the bowl")
	assert(game.content.find_child("OwnedSpices",true,false).find_children("*","Panel",true,false).any(func(card):return card is CookingItemCard and card.drag_payload.name=="Rare Spice"),"The crafted spice appears in the owned tier list")
	var plain_ingredients:=["Bumbleberry","Emberpepper","Dewmelon","Knobroot","Curlcap"]
	game.leftovers.erase("Plain Stew");game.show_cooking()
	for i in plain_ingredients.size():game.assign_pot_slot(i,plain_ingredients[i])
	game.cook();await process_frame
	assert(game.screen=="camp" and game.pending_stew.quality=="Decent" and int(game.pending_stew.expeditions_remaining)==1,"A common stew should begin a one-expedition cooking timer")
	game.advance_pending_stew();assert(int(game.leftovers.get("Plain Stew",0))==0 and int(game.completed_stew_result.leftovers)==0,"Cooking without a leftover jar should not produce leftovers")
	game.completed_stew_result.clear()
	game.special_items["Empty Leftover Jar"]=1;game.show_cooking()
	for i in plain_ingredients.size():game.assign_pot_slot(i,plain_ingredients[i])
	game.assign_cooking_item("special",0,{"kind":"special","id":"Empty Leftover Jar"});game.cook();await process_frame
	assert(int(game.leftovers.get("Plain Stew",0))==0,"A jar should not receive leftovers before the stew finishes")
	for i in int(game.pending_stew.expeditions_remaining):game.advance_pending_stew()
	assert(int(game.leftovers.get("Plain Stew",0))==1 and int(game.completed_stew_result.leftovers)==1 and int(game.special_items["Empty Leftover Jar"])==0,"An empty leftover jar should collect leftovers when the stew finishes and be consumed")
	game.completed_stew_result.clear()
	game.show_cooking()
	for i in plain_ingredients.size():game.assign_pot_slot(i,plain_ingredients[i])
	game.assign_cooking_item("special",0,{"kind":"special","id":"Leftovers:Plain Stew"});game.cook();await process_frame
	for i in int(game.pending_stew.expeditions_remaining):game.advance_pending_stew()
	assert(int(game.leftovers.get("Plain Stew",0))==1 and int(game.completed_stew_result.leftovers)==1,"Cooking with a matching leftover jar should produce leftovers when finished")
	game.completed_stew_result.clear()
	var expected_stews:=["Plain Stew","Rock Bottom Broth","Hot Stuff","Deep Dish","Shock Stock","Food for Thought","Garden Variety","Midnight Snack","Heavy Helping","Light Bite","Punch Drunk","Long Shot","Comfort Food","Woodland Medley","Peak Cuisine","Coastal Catch","Fancy Feast","Mystery Meat"]
	assert(GameData.RECIPES.size()==expected_stews.size(),"The stew journal should contain all eighteen requested stews")
	var stew_names:Array=[]
	for stew in GameData.RECIPES:stew_names.append(stew.name)
	for stew_name in expected_stews:assert(stew_names.has(stew_name),"Missing stew: "+stew_name)
	assert(GameData.choose_recipe({"Emberpepper":2,"Dewmelon":1,"Curlcap":2}).name=="Hot Stuff","Spicy dry combinations should make Hot Stuff")
	assert(GameData.choose_recipe({"Sunplum":2,"Frostberry":2,"Sparkfruit":1}).name=="Fancy Feast","Sweet, sour, juicy combinations should make Fancy Feast")
	assert(GameData.choose_recipe({"Puffshroom":2,"Brinepod":2,"Emberpepper":1}).name=="Mystery Meat","Strange mixed combinations should make Mystery Meat")
	game.show_recipes()
	await process_frame
	game.show_training()
	await process_frame
	game.selected_roster=0;game.roster[0].level=1;game.roster[0].exp=0;game.roster[1].level=8;game.roster[1].exp=0
	game.transfer_training(1,100);await process_frame
	assert(game.roster[0].exp==100 and game.roster[1].exp==15,"The owned helper should earn 15% of only the EXP it contributed")
	game.team_indices.assign([0,1,2,3,4]);game.show_map()
	await process_frame
	game.start_expedition("Longgrass Fields")
	await process_frame
	assert(game.expedition_music.playing,"Expedition music should start with an expedition")
	for team_slot_index in game.expedition.team.size():
		var expedition_ring=game.expedition.team[team_slot_index].team_ring
		assert(is_instance_valid(expedition_ring) and expedition_ring.disc.material_override.albedo_texture.resource_path=="res://textures/UI/TeamRing%s.png"%game.TEAM_SLOT_NAMES[team_slot_index],"Expedition members should keep the directional ring matching their team-slot color")
	var pause_button:TextureButton=game.content.find_child("PauseButton",true,false)
	assert(pause_button!=null and pause_button.texture_normal.resource_path=="res://textures/UI/PauseButton.png" and pause_button.size==Vector2(40,40),"Expeditions need the compact textured pause button in the top-left")
	assert(not game.content.find_children("*","Button",true,false).any(func(button):return button.text=="RETREAT"),"Expeditions should not show a Retreat button")
	game.sync_expedition_health_bars();await process_frame
	assert(game.expedition_health_bars.size()==game.expedition.team.size()+game.expedition.enemies.size(),"Every expedition Quiblet should have a tracked health bar")
	var hurt_actor:QuibletActor3D=game.expedition.team[0];var hurt_bar=game.expedition_health_bars[hurt_actor]
	assert(not hurt_bar.visible,"Health bars should stay hidden at maximum health")
	hurt_actor.take_damage(10.0);hurt_bar.update_bar()
	assert(hurt_bar.visible,"A health bar should appear above a damaged Quiblet")
	var move_buttons:Array=game.content.find_children("*","ExpeditionMoveButton",true,false)
	var splash_buttons:Array=move_buttons.filter(func(button):return button.actor.data.moves[button.move_index].name=="Splash Dash")
	assert(not splash_buttons.is_empty() and splash_buttons.all(func(button):return button.icon_texture!=null and button.icon_texture.resource_path=="res://textures/Moves/SplashDash.png"),"Expedition Splash Dash buttons should use the supplied texture")
	var expected_move_buttons:=0
	for actor in game.expedition.team:expected_move_buttons+=actor.data.moves.size()
	assert(move_buttons.size()==expected_move_buttons,"Every active Quiblet should always have its full move menu visible")
	var expected_card_positions:=[Vector2(445,646),Vector2(870,646),Vector2(870,574),Vector2(20,646),Vector2(20,574)]
	for team_card_index in game.expedition.team.size():
		var team_card:Panel=game.content.find_child("ExpeditionMoveCard%d"%team_card_index,true,false)
		assert(team_card!=null and team_card.position==expected_card_positions[team_card_index] and team_card.size==Vector2(390,66),"Each Quiblet should have its own card in the requested expedition HUD position")
	var expedition_portraits:Array=game.content.find_children("ExpeditionQuibletPortrait*","",true,false);var expedition_names:Array=game.content.find_children("ExpeditionQuibletName*","",true,false)
	assert(expedition_portraits.size()==game.expedition.team.size() and expedition_names.size()==game.expedition.team.size(),"Each expedition move menu needs a centered portrait with its Quiblet name underneath")
	var first_actor_buttons:Array=move_buttons.filter(func(button):return button.actor==game.expedition.team[0]);var portrait_center_x:float=expedition_portraits[0].position.x+expedition_portraits[0].size.x*.5
	assert(first_actor_buttons.filter(func(button):return button.position.x+button.size.x*.5<portrait_center_x).size()==2,"The first two moves should sit left of the portrait")
	assert(first_actor_buttons.filter(func(button):return button.position.x+button.size.x*.5>portrait_center_x).size()==1,"Remaining available moves should sit right of the portrait")
	hurt_actor.take_damage(hurt_actor.max_hp*2.0)
	assert(hurt_actor.knocked_out and is_equal_approx(hurt_actor.revive_time,10.0),"A player Quiblet at zero HP should enter a ten-second knockout")
	assert(first_actor_buttons.all(func(button):return is_equal_approx(button.display_tint_ratio(),1.0)),"Every move should be fully cooldown-tinted while its Quiblet is knocked out")
	var portrait_cooldown=game.content.find_child("ExpeditionPortraitCooldown0",true,false);assert(portrait_cooldown!=null and is_equal_approx(portrait_cooldown.display_tint_ratio(),1.0),"A knocked-out portrait should begin fully cooldown-tinted")
	hurt_actor._physics_process(5.0);assert(is_equal_approx(portrait_cooldown.display_tint_ratio(),.5),"The portrait tint should reveal halfway around after five seconds")
	hurt_actor._physics_process(5.1);assert(not hurt_actor.knocked_out and is_equal_approx(hurt_actor.current_hp,hurt_actor.max_hp*.5) and is_equal_approx(portrait_cooldown.display_tint_ratio(),0.0),"The Quiblet should pop back up at half health after ten seconds")
	var enemy_count_before:int=game.expedition.enemies.size();var defeated_enemy:QuibletActor3D=game.expedition.enemies[0]
	defeated_enemy.take_damage(defeated_enemy.max_hp*2.0);await process_frame
	assert(game.expedition.enemies.size()==enemy_count_before-1 and not is_instance_valid(defeated_enemy),"An enemy at zero HP should drop its loot and disappear")
	assert(game.expedition.team.all(func(actor):return not actor.selected),"Expeditions should not focus a single Quiblet")
	var shared_destination:=Vector3(-2,0,2);game.expedition.command_team(shared_destination)
	assert(game.expedition.team.all(func(actor):return actor.has_command),"A field command should move the whole living team")
	game.expedition.team[0].position=Vector3(-8,0,-2);game.expedition.team[1].position=Vector3(0,0,1);game.expedition.team[2].position=Vector3(8,0,2)
	for extra_index in range(3,game.expedition.team.size()):game.expedition.team[extra_index].position=Vector3(0,0,0)
	game.expedition.camera_pan_time=0.0  # a freshly spawned set pans the camera; this checks plain following
	var stage_env:WorldEnvironment=game.find_child("StageEnvironment",false,false);var stage_sun:DirectionalLight3D=game.find_child("StageSun",false,false)
	assert(not stage_env.environment.fog_enabled,"Expeditions have no depth haze")
	assert(stage_env!=null and stage_sun!=null and stage_env.environment.ambient_light_energy>=.8 and stage_env.environment.ambient_light_energy<=1.1 and stage_sun.light_energy>=.6 and stage_sun.light_energy<=.9 and not stage_sun.shadow_enabled and not stage_env.environment.glow_enabled and stage_env.environment.tonemap_mode==Environment.TONE_MAPPER_LINEAR,"The expedition stage should be soft meadow lighting: pale sky ambient, one gentle sun, no shadows, no glow, linear tone mapping")
	game.expedition.update_group_camera(1.0)
	assert(absf(game.expedition.camera_focus.x)<.5,"The expedition camera should center itself on the whole living team")
	assert(game.camera_3d.position.y>13.0,"The expedition camera should pull back when the team spreads out")
	var first_move_button:ExpeditionMoveButton=move_buttons[0];var button_actor:QuibletActor3D=first_move_button.actor
	button_actor.move_cooldown_totals[first_move_button.move_index]=2.0;button_actor.move_cooldowns[first_move_button.move_index]=1.0;first_move_button.last_cooldown=1.0
	button_actor.move_cooldowns[first_move_button.move_index]=0.0;first_move_button._process(.01)
	assert(first_move_button.ready_pulse>0.0,"A move button should pulse when its cooldown finishes")
	assert(game.content.find_child("RouteFork",true,false)==null,"Expeditions should not show a path-choice menu")
	var banked_berries_before:int=game.ingredients["Bumbleberry"];var move_stones_before:int=int(game.move_stone_inventory.get("echo",0));var power_stones_before:int=game.power_stone_inventory.size()
	game.expedition.loot["Bumbleberry"]+=2;game.expedition.move_stones["echo"]=int(game.expedition.move_stones.get("echo",0))+1;game.expedition.power_stones.append({"type":"Health","power":22})
	var pickups_before:int=game.content.find_children("RewardPickup*","",true,false).size()
	game.show_expedition_reward({"kind":"ingredient","name":"Bumbleberry","amount":2},game.expedition.team[0].global_position)
	assert(game.content.find_child("RewardPickup",true,false)!=null,"Acquired expedition rewards should animate toward the pause button")
	var reward_pickups:Array=game.content.find_children("RewardPickup*","",true,false)
	assert(reward_pickups.size()==pickups_before+2 and not reward_pickups[-1].visible,"Each item in a stack should get a separate pickup, with later items waiting before appearing")
	assert(reward_pickups.all(func(pickup):return not pickup is Panel and not pickup.find_children("*","Label",true,false).any(func(entry):return entry.text.begins_with("×"))),"Collection animations should have neither a background nor an amount label")
	var stone_pickup_delay:float=game.reward_pickup_delay
	game.show_expedition_reward({"kind":"move_stone","name":"Echo Stone","effect":"echo","amount":1,"texture":GameData.stone_info("echo").texture},game.expedition.team[0].global_position)
	var hovering_pickup:Control=game.content.find_children("RewardPickup*","",true,false)[-1]
	var reward_stone_icon:TextureRect=hovering_pickup.find_child("RewardMoveStoneIcon",true,false);assert(reward_stone_icon!=null and reward_stone_icon.size==Vector2(44,44) and reward_stone_icon.custom_minimum_size==Vector2.ZERO,"Collected Move Stone art must remain inside its 44×44 pickup icon")
	await create_timer(stone_pickup_delay+.45).timeout
	assert(is_instance_valid(hovering_pickup) and hovering_pickup.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(hovering_pickup.modulate.a,1.0),"A collected item should remain fully visible during its hover period before flying to Pause")
	await create_timer(.8).timeout
	assert(is_instance_valid(hovering_pickup) and is_equal_approx(hovering_pickup.modulate.a,1.0) and hovering_pickup.scale.x>=.8,"A pickup should stay opaque and shrink by no more than 20% while traveling to Pause")
	await create_timer(.6).timeout
	assert(not is_instance_valid(hovering_pickup),"A pickup should disappear just before reaching the Pause button")
	game.open_expedition_pause()
	assert(game.get_tree().paused and game.expedition_paused and game.content.find_child("PauseMenu",true,false)!=null,"The pause button should pause the expedition and open its haul")
	var back_button:TextureButton=game.content.find_child("BackButton",true,false)
	assert(back_button!=null and back_button.texture_normal.resource_path=="res://textures/UI/BackButton.png","The pause menu needs the textured back button where pause was")
	var pause_labels:Array=game.pause_overlay.find_children("*","Label",true,false)
	assert(pause_labels.any(func(entry):return entry.text=="Bumbleberry") and pause_labels.any(func(entry):return entry.text=="Echo Stone"),"The pause menu should list collected items and Move Stones")
	game.close_expedition_pause();assert(not game.get_tree().paused and not game.expedition_paused,"Back should resume the expedition")
	game.open_expedition_pause();game.give_up_expedition();await process_frame;await process_frame
	assert(game.screen=="expedition_changes","Give Up should first show animated Quiblet changes")
	assert(game.ingredients["Bumbleberry"]>=banked_berries_before+2 and int(game.move_stone_inventory.get("echo",0))>=move_stones_before+1 and game.power_stone_inventory.size()>=power_stones_before+1,"Giving up should bank items, Move Stones, and Power Stones")
	assert(game.expedition_music.playing,"Expedition music should continue through the Quiblet-update results screen")
	game.show_map();game.start_expedition("Longgrass Fields");await process_frame
	var wipe_team:Array=game.expedition.team.duplicate()
	for actor in wipe_team:actor.take_damage(actor.max_hp*2.0)
	await process_frame;await process_frame
	assert(game.screen=="expedition_changes" and not game.last_result.victory,"A full-team knockout should open the Quiblet-change results screen")
	print("QUIBLETS_SMOKE_OK roster=", game.roster.size(), " team=", game.team_indices.size())
	quit(0)

func image_color_counts(image:Image)->Dictionary:
	var counts:={}
	for y in image.get_height():
		for x in image.get_width():
			var pixel:=image.get_pixel(x,y)
			var key:=(int(round(pixel.r*255.0))<<16)|(int(round(pixel.g*255.0))<<8)|int(round(pixel.b*255.0))
			counts[key]=int(counts.get(key,0))+1
	return counts
