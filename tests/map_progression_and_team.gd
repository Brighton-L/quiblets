extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 assert(game.is_area_unlocked(0) and not game.is_area_unlocked(1))
 game.show_map();await process_frame
 assert(game.content.find_child("RegionButton1",true,false).disabled)
 game.start_area_level(1,0);assert(game.screen=="map","Locked areas must not launch")
 game.area_progress[0]=6;assert(not game.is_area_unlocked(1),"Regular waves are not the area's boss")
 game.area_progress[0]=7;assert(game.is_area_unlocked(1) and not game.is_area_unlocked(2))
 game.discovered_optional_areas.assign([16]);assert(game.is_area_unlocked(16))
 game.show_map();await process_frame
 assert(not game.content.find_child("RegionButton1",true,false).disabled)
 var island=game.world_root.get_node("RegionMap");var party=island.get_node("MapTeam")
 assert(party.residents.size()==game.team_indices.size())
 var initial:Vector3=party.residents[0].body.position
 for i in 300:party._process(1.0/60.0)
 assert(party.residents[0].body.position.distance_to(initial)>.25,"Map party should wander")
 for resident in party.residents:assert(island.coastline(Vector2(resident.body.position.x,resident.body.position.z))>.1,"Party must stay on land")
 assert(island.get_children().filter(func(child):return child.get_meta("map_scenery",false)).size()>200,"Map needs denser scenery")
 game.map_zoom=1.7;game.map_pan=Vector2.ZERO;game.update_region_map_camera()
 print("Map progression, direct-launch gate, optional discovery, scenery density and wandering team passed")
 game.queue_free();await process_frame;quit()
