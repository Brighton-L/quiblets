extends SceneTree

func _initialize():call_deferred("run")

func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 var start:=Time.get_ticks_msec()
 game.show_map()
 print("First map transition: ",Time.get_ticks_msec()-start," ms")
 var island=game.world_root.get_node("RegionMap")
 var party=island.get_node("MapTeam")
 game.show_camp()
 assert(not island.visible and not party.can_process())
 start=Time.get_ticks_msec();game.show_map()
 print("Cached map transition: ",Time.get_ticks_msec()-start," ms")
 assert(game.world_root.get_node("RegionMap")==island)
 assert(island.visible and party.can_process())
 assert(island.get_node("MapTeam")==party)
 game.area_progress[0]=7;game.show_map()
 assert(game.world_root.get_node("RegionMap")==island)
 assert(island.get_node("MapTeam")!=party,"Newly unlocked areas must update wandering routes")
 party=island.get_node("MapTeam")
 game.roster[game.team_indices[0]].species=1;game.show_map()
 assert(island.get_node("MapTeam")!=party,"Evolution must refresh the displayed team")
 game.discovered_optional_areas.assign([16]);game.show_map()
 var expanded=game.world_root.get_node("RegionMap")
 assert(expanded!=island and expanded.visible_regions.has(16))
 assert(expanded.get_children().filter(func(child):return child.name=="AreaProgressionTrail").size()==1)
 game.queue_free();await process_frame
 print("Map cache, hidden processing, team refresh and discovery invalidation passed")
 quit()
