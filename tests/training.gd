extends SceneTree

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func back_buttons_bottom_right(game)->bool:
	var buttons:Array=game.content.find_children("BackButton","",true,false)
	if buttons.is_empty():return false
	if buttons.size()>1 and game.content.find_child("MoveInfoOverlay",false,false)==null:return false
	# A modal popup blocks the screen's own back button by design; only judge the popup's.
	if game.content.find_child("MoveInfoOverlay",false,false)!=null:buttons=buttons.filter(func(button):return button.get_parent().name=="MoveInfoMenu")
	for button in buttons:
		if button.get_parent().name=="MoveInfoMenu":
			var menu:Control=button.get_parent()
			if button.position.x+button.size.x<menu.size.x-20 or button.position.y+button.size.y<menu.size.y-20:return false
		elif button.global_position!=game.BACK_BUTTON_POSITION:return false
		elif not back_button_clickable(game):return false
	return true

func top_control_at(node:Control,point:Vector2)->Control:
	# Mirrors Godot's picking: later siblings and descendants sit on top, IGNORE passes through.
	if not node.visible or not node.get_global_rect().has_point(point):return null
	for i in range(node.get_child_count()-1,-1,-1):
		var child=node.get_child(i)
		if child is Control:
			var hit:=top_control_at(child,point)
			if hit!=null:return hit
	return node if node.mouse_filter!=Control.MOUSE_FILTER_IGNORE else null

func back_button_clickable(game)->bool:
	var target:Vector2=game.BACK_BUTTON_POSITION+Vector2(20,20)
	for i in range(game.content.get_child_count()-1,-1,-1):
		var child=game.content.get_child(i)
		if child is Control:
			var hit:=top_control_at(child,target)
			if hit!=null:return hit.name=="BackButton"
	return false

func backdrop_ok(game)->bool:
	var backdrop:ColorRect=game.content.find_child("MenuBackdrop",false,false)
	return backdrop!=null and backdrop.get_index()==0 and backdrop.position==Vector2.ZERO and backdrop.size==Vector2(1280,720)

func quiblet(roster_index:int)->Dictionary:
	return {"kind":"quiblet","roster_index":roster_index}

func run()->void:
	# Data rules.
	var plip:=GameData.make_quiblet(0,8);var swellit:=GameData.make_quiblet(1,12);var spriggle:=GameData.make_quiblet(2,8);var sparko:=GameData.make_quiblet(6,20)
	check(GameData.quiblet_relationship(plip,GameData.make_quiblet(0,3))=="species" and GameData.quiblet_relationship(plip,swellit)=="family" and GameData.quiblet_relationship(spriggle,GameData.make_quiblet(4,5))=="type" and GameData.quiblet_relationship(plip,sparko)=="none","Relationships should rank species, evolution family, type, then none")
	check(GameData.ingredient_compatibility(0,"Dewmelon")=="excellent" and GameData.ingredient_compatibility(0,"Sparkfruit")=="good" and GameData.ingredient_compatibility(0,"Knobroot")=="neutral" and GameData.ingredient_compatibility(0,"Crystalcorn")=="poor" and GameData.ingredient_compatibility(0,"Emberpepper")=="opposing","Water ingredient compatibility")
	check(GameData.ingredient_compatibility(6,"Emberpepper")=="excellent" and GameData.ingredient_compatibility(6,"Frostberry")=="opposing" and GameData.ingredient_compatibility(2,"Bitterleaf")=="excellent" and GameData.ingredient_compatibility(2,"Brinepod")=="poor","Fire and Green ingredient compatibility")
	var spriggle_twin:=GameData.make_quiblet(2,8);var frondle:=GameData.make_quiblet(3,12);var vinee:=GameData.make_quiblet(4,4)
	var helpers:Array=[spriggle_twin,frondle,vinee,sparko]
	check(is_equal_approx(GameData.move_training_chance(spriggle,helpers),67.0),"Move chance: 5 base + 25 species + 20 family + 12 type + 5 unrelated")
	check(is_equal_approx(GameData.move_training_chance(spriggle,[]),5.0) and is_equal_approx(GameData.move_training_chance(spriggle,[spriggle_twin,spriggle_twin,spriggle_twin,spriggle_twin]),95.0),"Move chance starts at 5% and caps at 95%")
	var expected_exp:=0
	for helper in helpers:expected_exp+=GameData.exp_training_helper_reward(spriggle,helper)
	check(GameData.exp_training_reward(spriggle,helpers)==expected_exp and expected_exp>0,"EXP reward sums helpers using the unchanged starting trainee")
	check(is_equal_approx(GameData.helper_preservation_chance(spriggle,["Bitterleaf","Bumbleberry"]),10.0+5.0) and is_equal_approx(GameData.helper_preservation_chance(spriggle,["Sunplum","Sunplum"]),20.0+20.0) and is_equal_approx(GameData.helper_preservation_chance(spriggle,["Emberpepper"]),2.5) and is_equal_approx(GameData.helper_preservation_chance(spriggle,["","Brinepod"]),7.5),"Preservation chance sums rarity × compatibility per added food (T1 match 10, T1 neutral 5, T4 neutral 20 ×2, T1 poor 2.5, T3 poor 7.5)")
	var pool:=GameData.retrain_pool(spriggle)
	check(pool.size()==GameData.learnset(2).size()-spriggle.moves.size() and pool.all(func(name):return not spriggle.moves.any(func(move):return move.name==name)),"The retrain pool excludes every move currently in a slot")
	var picks:={}
	for i in 400:picks[GameData.pick_retrain_move(spriggle,float(i)/400.0)]=int(picks.get(GameData.pick_retrain_move(spriggle,float(i)/400.0),0))+1
	check(picks.size()==pool.size() and int(picks[pool[0]])>int(picks[pool[-1]]) and GameData.move_selection_weight(2,pool[-1])<GameData.move_selection_weight(2,pool[0]),"Later learnset moves are picked less often but remain possible")
	# Screens: backdrops, back buttons, and the training button.
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	# Evolution: a base species that reaches its evolve level becomes its evolved form.
	check(GameData.evolution_target(0,17)==-1 and GameData.evolution_target(0,18)==1 and GameData.evolution_target(1,50)==-1,"Plip evolves into Swellit at Lv. 18; Swellit does not evolve")
	var evo:Dictionary=GameData.make_quiblet(0,17,"Bubbles");var evo_stones:Array=evo.moves.duplicate(true)
	game.grant_training_exp(evo,GameData.exp_to_level(17)-int(evo.exp))
	check(int(evo.level)>=18 and int(evo.species)==1 and str(evo.nickname)=="Bubbles" and evo.moves==evo_stones,"Leveling a Plip to 18 turns it into Swellit, keeping its nickname and moves")
	var late:Dictionary=GameData.make_quiblet(6,10)
	game.grant_training_exp(late,GameData.total_exp(GameData.make_quiblet(6,17))-GameData.total_exp(late))
	check(int(late.species)==6,"A Sparko below Lv. 18 stays a Sparko")
	# Pausing evolution keeps a Quiblet in its current form even past the evolve level.
	check(GameData.can_evolve(0) and not GameData.can_evolve(1),"A base species can evolve; its evolved form cannot")
	var held:Dictionary=GameData.make_quiblet(0,17);held.evolution_paused=true
	game.grant_training_exp(held,GameData.exp_to_level(17)-int(held.exp))
	check(int(held.level)>=18 and int(held.species)==0,"A Quiblet with evolution paused does not evolve on level-up")
	held.evolution_paused=false;game.grant_training_exp(held,GameData.exp_to_level(int(held.level))-int(held.exp))
	check(int(held.species)==1,"Re-allowing evolution lets it evolve on the next level-up")
	game.show_all_quiblets();await process_frame
	check(backdrop_ok(game),"All Quiblets needs a full-screen backdrop")
	var info:Control=game.content.find_child("QuibletInfo",false,false);var list_panel:Control=game.content.find_child("OwnedQuiblets",false,false);var open_training:TextureButton=game.content.find_child("OpenTrainingButton",false,false)
	check(open_training!=null and open_training.position.x>=info.position.x+info.size.x and open_training.position.y==info.position.y and open_training.position.y+open_training.size.y<=list_panel.position.y,"The training button sits right of the info section, above the Quiblet list")
	var train_backdrop:Panel=game.content.find_child("OpenTrainingBackdrop",false,false)
	check(train_backdrop!=null and train_backdrop.position==open_training.position and train_backdrop.size==open_training.size and train_backdrop.get_theme_stylebox("panel").bg_color==GameData.COLORS.gold and train_backdrop.get_index()<open_training.get_index(),"The training button sits on a gold background rectangle")
	check(open_training.size.x==open_training.size.y and open_training.texture_normal is AtlasTexture and open_training.texture_normal.atlas.resource_path=="res://textures/UI/TrainingIcon.png" and open_training.texture_normal.region.size.x<512 and is_equal_approx(open_training.texture_normal.get_width(),open_training.texture_normal.region.size.x/.625) and is_equal_approx(open_training.texture_normal.margin.position.x,open_training.texture_normal.region.size.x*(1.0/.625-1.0)*.5),"The training button is square and draws the TrainingIcon at 62.5% size, centred")
	check(back_buttons_bottom_right(game),"All Quiblets back button belongs in the bottom-right corner")
	game.show_quiblet_edit();await process_frame
	check(backdrop_ok(game) and back_buttons_bottom_right(game),"Quiblet info menu needs a backdrop and a bottom-right back button")
	game.show_move_info(game.roster[0].moves[0]);await process_frame
	check(back_buttons_bottom_right(game),"The move info popup back button belongs in its bottom-right corner")
	game.show_resources();await process_frame;check(back_buttons_bottom_right(game),"Resources back button placement")
	game.show_spice_workshop();await process_frame;check(back_buttons_bottom_right(game),"Spice workshop back button placement")
	game.show_cooking();await process_frame;check(back_buttons_bottom_right(game),"Cooking back button placement")
	game.completed_stew_result={"recipe":"Plain Stew","quality":"Decent","arrivals":["Plip"],"arrival_names":["Plip"],"arrival_species":[0],"leftovers":0}
	game.show_cook_result();await process_frame;check(back_buttons_bottom_right(game),"Cook result back button placement");game.completed_stew_result={}
	game.last_result={"victory":true,"exp":10,"loot":{},"berries":0,"special":""}
	game.show_expedition_result();await process_frame;check(back_buttons_bottom_right(game),"Expedition result back button placement")
	game.show_area_levels(0);await process_frame;check(back_buttons_bottom_right(game),"Level route back button placement")
	game.start_area_level(0,0);await process_frame;game.open_expedition_pause();await process_frame
	check(back_buttons_bottom_right(game),"Pause menu back button placement");game.close_expedition_pause();game.give_up_expedition();await process_frame
	# Training screen.
	game.show_all_quiblets();await process_frame
	game.content.find_child("OpenTrainingButton",false,false).pressed.emit();await process_frame
	check(game.screen=="training" and backdrop_ok(game) and back_buttons_bottom_right(game),"The training button opens the training screen with a backdrop and bottom-right back button")
	check(game.content.find_child("TrainingSection",false,false)!=null and game.content.find_child("TeamSection",false,false)==null and game.content.find_child("QuibletInfo",false,false)!=null and game.content.find_child("OwnedQuiblets",false,false)!=null,"Training replaces the team preview but keeps the info section and Quiblet list")
	for node_name in ["TrainingModeMove","TrainingModeExp","TraineeSlot","HelperSlot0","HelperSlot1","HelperSlot2","HelperSlot3","FoodSlot0","FoodSlot1","TrainingIngredientTray","TrainingSummary","TrainButton"]:
		check(game.content.find_child(node_name,true,false)!=null,"Training screen is missing "+node_name)
	var ingredient_grid:GridContainer=game.content.find_child("TrainingIngredientGrid",true,false)
	check(ingredient_grid!=null and ingredient_grid.columns==8 and ingredient_grid.get_child_count()==GameData.INGREDIENTS.size() and ingredient_grid.get_child_count()==16,"The training ingredient list is two rows of eight")
	var tray_panel:Control=game.content.find_child("TrainingIngredientTray",true,false);var tray_section:Control=game.content.find_child("TrainingSection",false,false)
	check(tray_panel.position.x+tray_panel.size.x<=tray_section.size.x and ingredient_grid.size.x*ingredient_grid.scale.x<=tray_panel.size.x and ingredient_grid.size.y*ingredient_grid.scale.y<=tray_panel.size.y,"The ingredient grid fits inside its tray and section")
	game.ingredients["Bumbleberry"]=3
	if not game.unlocked_ingredients.has("Bumbleberry"):game.unlocked_ingredients.append("Bumbleberry")
	game.show_training();await process_frame
	var grid_card:IngredientDragCard=game.content.find_child("TrainingIngredientGrid",true,false).get_child(0)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;grid_card._gui_input(event)
	await process_frame
	check(game.screen=="training","Clicking an ingredient in the training grid must stay on the training screen")
	var mode_buttons:Array=[game.content.find_child("TrainingModeMove",true,false),game.content.find_child("TrainingModeExp",true,false)]
	check(mode_buttons.all(func(button):return button.position.y<game.content.find_child("TraineeSlot",true,false).position.y),"Mode buttons sit at the top of the training section")
	# Fixture: Spriggle trainee with a twin, a Frondle, a Vinee, and a Sparko as helpers.
	game.roster.append(GameData.make_quiblet(2,10));var trainee_index:int=game.roster.size()-1
	game.roster.append(GameData.make_quiblet(2,8));game.roster.append(GameData.make_quiblet(3,12));game.roster.append(GameData.make_quiblet(4,4));game.roster.append(GameData.make_quiblet(6,20))
	check(int(game.roster[trainee_index].species)==2,"Fixture Spriggle trainee")
	var twin:int=game.roster.size()-4;var roster_size:int=game.roster.size()
	for ingredient_name in ["Bitterleaf","Emberpepper","Bumbleberry","Sunplum"]:
		game.ingredients[ingredient_name]=3
		if not game.unlocked_ingredients.has(ingredient_name):game.unlocked_ingredients.append(ingredient_name)
	game.assign_training_slot("trainee",0,quiblet(trainee_index));await process_frame
	check(game.training_trainee==trainee_index and game.screen=="training","Dropping a Quiblet on the trainee slot assigns it")
	for i in 4:game.assign_training_slot("helper",i,quiblet(twin+i))
	await process_frame
	check(game.training_helpers==[twin,twin+1,twin+2,twin+3],"Helpers fill their four slots")
	game.assign_training_slot("helper",0,quiblet(trainee_index))
	check(game.training_trainee==-1 and game.training_helpers[0]==trainee_index,"A Quiblet can only occupy one training socket")
	game.assign_training_slot("trainee",0,quiblet(trainee_index));game.assign_training_slot("helper",0,quiblet(twin))
	check(game.training_trainee==trainee_index and game.training_helpers[0]==twin,"Moving a Quiblet back restores the layout")
	check(not game.can_assign_training("food",0,{"kind":"ingredient","name":"Glowcap"}),"Unowned ingredients cannot be dropped as food")
	game.ingredients["Sunplum"]=1
	game.assign_training_slot("food",0,{"kind":"ingredient","name":"Sunplum"})
	check(game.training_foods[0]=="Sunplum" and not game.can_assign_training("food",1,{"kind":"ingredient","name":"Sunplum"}),"Food slots cannot reserve more of an ingredient than is owned")
	game.assign_training_slot("food",1,{"kind":"ingredient","name":"Bitterleaf"});await process_frame
	check(game.training_foods==["Sunplum","Bitterleaf"],"Two food slots hold two ingredients")
	var trainee_slot:Control=game.content.find_child("TraineeSlot",true,false);var food_slot:Control=game.content.find_child("FoodSlot1",true,false);var helper_slot:Control=game.content.find_child("HelperSlot0",true,false)
	check(not trainee_slot.find_children("*","QuibletPortrait",true,false).is_empty() and food_slot.get_child_count()>0 and helper_slot.find_children("*","Label",true,false).any(func(item):return item.text=="+25%"),"Filled sockets show their occupant and helper contribution")
	var trainee:Dictionary=game.roster[trainee_index];var moves_before:int=trainee.moves.size()
	# Move training shows the trainee's moves with their stone slots and needs one picked.
	trainee.moves[0].slots=2;trainee.moves[0].stones=["echo"];game.show_training();await process_frame
	var moves_panel:Control=game.content.find_child("TrainingMoves",true,false)
	check(moves_panel!=null and moves_panel.find_children("RetrainMove*","Button",true,false).size()==moves_before,"Move training lists every move of the trainee as a clickable row")
	check(moves_panel.find_children("TrainingMoveIcon*","",true,false).size()==moves_before and moves_panel.find_children("TrainingStoneSlot0_*","",true,false).size()==2 and moves_panel.find_child("TrainingStoneSlot0_0",true,false).get_child_count()==1 and moves_panel.find_child("TrainingStoneSlot1_0",true,false).get_child_count()==0,"Each row shows the move icon, its Move Stone slots, and fitted stones")
	check(game.training_move<0 and game.content.find_child("TrainingSummary",true,false).text.contains("Click one of"),"No move is selected until the player clicks one")
	game.last_training_result={};game.run_training();await process_frame
	check(game.last_training_result.is_empty() and game.ingredients["Sunplum"]==1 and game.roster.size()==roster_size,"Training refuses to run before a move is chosen and spends nothing")
	moves_panel.find_child("RetrainMove0",true,false).pressed.emit();await process_frame
	# The TRAIN button asks first; cancelling changes nothing, confirming runs the training.
	game.last_training_result={};game.content.find_child("TrainButton",true,false).pressed.emit();await process_frame
	var confirmation=game.content.find_child("TrainingConfirmation",true,false)
	check(confirmation!=null and game.last_training_result.is_empty() and game.roster.size()==roster_size and confirmation.find_child("ConfirmTraining",true,false)!=null,"Pressing TRAIN should open a confirmation before anything is consumed")
	confirmation.find_child("CancelTraining",true,false).pressed.emit();await process_frame
	check(game.content.find_child("TrainingConfirmation",true,false)==null and game.last_training_result.is_empty() and game.roster.size()==roster_size,"Cancelling the training confirmation keeps every helper")
	var summary:Label=game.content.find_child("TrainingSummary",true,false)
	check(game.training_move==0 and game.content.find_child("TrainingMovesHeader",true,false).text.contains(str(trainee.moves[0].name)) and summary.text.contains("67%") and summary.text.contains("Chance to keep"),"Clicking a move selects it for retraining and shows the chance and preservation odds")
	# Force a success and a full preservation roll.
	var rng:=RandomNumberGenerator.new();rng.seed=7;game.training_rng=rng
	var retrained_name:String=trainee.moves[0].name;var echo_before:int=int(game.move_stone_inventory.get("echo",0));var known_before:Array=[]
	for move in trainee.moves:known_before.append(str(move.name))
	var twin_uid:String=game.roster[twin].uid
	game.run_training();await process_frame
	var result:Dictionary=game.last_training_result
	check(result.chance==67.0 and (result.success==(result.roll<67.0)),"The success roll is compared against the shown chance")
	if result.success:
		check(result.retrained==retrained_name and trainee.moves.size()==moves_before and trainee.moves[0].name==result.learned and result.learned!=retrained_name and not known_before.has(result.learned) and GameData.learnset(2).has(result.learned),"A success replaces the chosen move with a different learnable move not in another slot")
		check(trainee.moves[0].slots==2 and trainee.moves[0].stones.is_empty() and int(game.move_stone_inventory.get("echo",0))==echo_before+1,"The retrained move keeps its slots and refunds its fitted stones")
	else:check(trainee.moves[0].name==retrained_name and trainee.moves[0].stones==["echo"],"A failure leaves the selected move unchanged")
	check(game.ingredients["Sunplum"]==0 and game.ingredients["Bitterleaf"]==2 and game.training_foods==["",""],"Food is spent whether or not training succeeds")
	check(result.preserved.size()+result.consumed.size()==4 and game.roster.size()==roster_size-result.consumed.size() and game.training_helpers==[-1,-1,-1,-1] and game.training_trainee==game.find_roster_index(trainee.uid),"Every helper is either kept or consumed and the trainee index follows the roster")
	check(game.team_indices.all(func(index):return index>=0 and index<game.roster.size()),"Consuming helpers keeps team indices valid")
	# With no food every helper is consumed; with certain preservation every helper stays.
	var extra:=GameData.make_quiblet(2,3);game.roster.append(extra);var extra_index:int=game.roster.size()-1
	game.assign_training_slot("trainee",0,quiblet(game.find_roster_index(trainee.uid)));game.assign_training_slot("helper",0,quiblet(extra_index))
	game.set_training_mode("exp");await process_frame
	check(game.content.find_child("TrainingMoves",true,false)==null and game.content.find_child("TrainingSummary",true,false).text.contains("EXP"),"EXP training previews the EXP gain without a retrain panel")
	var expected_reward:=GameData.exp_training_helper_reward(trainee,extra);var exp_before:int=GameData.total_exp(trainee);var size_before:int=game.roster.size()
	game.run_training();await process_frame
	result=game.last_training_result
	check(result.success and int(result.exp)==expected_reward and GameData.total_exp(trainee)==exp_before+expected_reward,"EXP training always succeeds and awards the calculated helper reward")
	check(result.consumed.size()==1 and result.preserved.is_empty() and game.roster.size()==size_before-1 and game.find_roster_index(extra.uid)==-1,"Without food the helper is consumed")
	var keeper:=GameData.make_quiblet(2,3);game.roster.append(keeper)
	game.assign_training_slot("helper",0,quiblet(game.roster.size()-1));game.ingredients["Sunplum"]=2
	game.assign_training_slot("food",0,{"kind":"ingredient","name":"Sunplum"});game.assign_training_slot("food",1,{"kind":"ingredient","name":"Sunplum"})
	var forced:=RandomNumberGenerator.new();forced.seed=1
	while true:
		forced.seed+=1;var probe_seed:int=forced.seed;var value:=forced.randf();forced.seed=probe_seed
		if value*100.0<40.0:break
	game.training_rng=forced;size_before=game.roster.size()
	game.run_training();await process_frame
	result=game.last_training_result
	check(result.preserved.size()==1 and game.roster.size()==size_before and game.find_roster_index(keeper.uid)>=0 and game.ingredients["Sunplum"]==0,"A helper that passes its preservation roll stays and still gave its full EXP")
	game.training_rng=null
	game.clear_training_slot("helper",1);await process_frame
	check(game.training_helpers[1]==-1,"Clearing a socket empties it")
	game.select_roster_quiblet(0);await process_frame
	check(game.screen=="training" and game.selected_roster==0,"Selecting a Quiblet while training stays on the training screen")
	print("QUIBLETS_TRAINING_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
