extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(3.0).timeout
	var arrivals:Array=[GameData.make_quiblet(0,7),GameData.make_quiblet(5,12)]
	var initial_count:int=game.roster.size()
	var residents=game.world_root.get_node("CampResidents")
	var original= residents.residents[0].body
	var original_position:Vector3=original.position
	game.show_team();game.show_camp()
	assert(game.world_root.get_node("CampResidents")==residents)
	assert(original.position.is_equal_approx(original_position),"Menu buttons must not relocate residents")
	game.show_map();game.show_camp()
	assert(original.position.is_equal_approx(original_position),"Returning from map menus must preserve camp positions")
	game.pending_stew={"recipe":"Test Stew","quality":"Good","score":10,"arrivals":arrivals,"arrival_names":["Plip","Bloomie"],"arrival_species":[0,5],"leftovers":0,"boosted":false,"expeditions_remaining":1}
	assert(game.advance_pending_stew());assert(game.roster.size()==initial_count+2)
	assert(not game.quiblet_arrival_music.playing)
	game.show_camp();await create_timer(.4).timeout
	assert(game.screen=="camp" and not is_instance_valid(game.arrival_sequence),"Returning to camp must wait for collection")
	assert(game.world_root.get_node("CookingReadyIndicator").visible,"Ready stew stays marked until clicked")
	game.show_team();game.show_camp();await process_frame
	assert(not is_instance_valid(game.arrival_sequence),"Returning from menus must not collect stew")
	game.open_cooking_pot();await process_frame;await process_frame
	assert(game.screen=="quiblet_arrival" and is_instance_valid(game.arrival_sequence))
	var stew_deadline:=Time.get_ticks_msec()+5000
	while not game.arrival_sequence.can_continue and Time.get_ticks_msec()<stew_deadline:await process_frame
	assert(game.arrival_sequence.revealing_stew and game.arrival_sequence.can_continue)
	game.arrival_sequence.advance();await create_timer(.9).timeout
	assert(game.arrival_sequence.visitors.size()==2,"All visitors must enter together")
	var second_actor:Node3D=game.arrival_sequence.visitors[1].actor
	var second_start:Vector3=second_actor.position
	assert(game.content.find_child("CampTeamPanel",true,false)==null)
	assert(game.world_root.get_node("CampResidents").visible and game.world_root.get_node("CampResidents").is_processing())
	assert(not game.world_root.get_node("CookingReadyIndicator").visible)
	game.arrival_sequence.advance();assert(game.arrival_sequence.index==0)
	for visitor in 2:
		var sequence=game.arrival_sequence
		var deadline:=Time.get_ticks_msec()+(12000 if visitor==0 else 3000)
		while not sequence.can_continue and Time.get_ticks_msec()<deadline:await process_frame
		assert(sequence.can_continue,"Arrival must finish its reveal")
		if visitor==0:
			assert(second_actor.position.distance_to(second_start)>10,"Second visitor must walk in with the first")
			assert(second_actor.position.distance_to(sequence.actor.position)>1,"Visitors should stand separately beside the pot")
		else:assert(sequence.actor==second_actor,"Next card must use the visitor already beside the pot")
		assert(sequence.cards.find_child("ResultEquipment",true,false)!=null)
		assert(sequence.cards.find_child("ResultName",true,false).text==GameData.display_name(arrivals[visitor]))
		assert(game.quiblet_arrival_music.playing)
		assert(game.quiblet_arrival_music.get_meta("music_path").ends_with("GotQuibletSpecial.wav" if visitor==1 else "GotQuiblet.wav"))
		assert(game.roster.size()==initial_count+2,"Reveal must not grant duplicate arrivals")
		var revealed_actor:Node3D=sequence.actor;var revealed_position:Vector3=revealed_actor.global_position
		sequence.advance();await create_timer(1.0).timeout
		assert(is_instance_valid(revealed_actor) and revealed_actor.get_parent()==residents,"Accepting must reuse the revealed model")
		assert(revealed_actor.global_position.distance_to(revealed_position)<.3,"Accepting must leave the model beside the pot")
	assert(original.position.distance_to(original_position)>.1,"Other residents must keep wandering during arrivals")
	assert(game.screen=="camp" and game.completed_stew_result.is_empty())
	assert(game.content.find_child("CampTeamPanel",true,false)!=null)
	assert(game.world_root.get_node("CampResidents").residents.size()==game.roster.size())
	print("QUIBLETS_ARRIVAL_OK");quit()
