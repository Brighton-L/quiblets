extends SceneTree
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:push_error(message);quit(1)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 check(game.save_access_blocked(),"Tests must not touch saves")
 check(GameData.OPTIONAL_AREA_HOSTS=={16:1,17:5,18:9,19:13},"Optional discoveries should be spaced across areas 2, 6, 10 and 14")
 check(GameData.EXPEDITION_AREAS.size()==20,"Expected 16 main and four optional regions")
 check(game.visible_map_areas().size()==16,"Optional areas should start hidden")
 check(not game.is_area_level_unlocked(16,0),"Hidden optional levels must be inaccessible")
 game.show_map();await process_frame
 check(game.world_root.find_child("ContinuousIsland",true,false)!=null,"Map needs one terrain mesh")
 check(game.content.find_child("RegionButton16",true,false)==null,"Hidden area must have no marker")
 var saved:Dictionary=game.save_data();saved.discovered_optional_areas=[16]
 saved.area_progress=saved.area_progress.slice(0,16)
 saved.area_progress[3]=4
 saved.area_progress[0]=7
 saved.area_progress[1]=7
 game.apply_save_data(saved);game.show_map();await process_frame
 check(game.area_progress.size()==20 and game.area_progress[3]==4,"Existing progression must be preserved when adding optional areas")
 check(game.discovered_optional_areas==[16] and game.is_area_level_unlocked(16,0),"Discovery must round trip in memory")
 check(game.content.find_child("RegionButton16",true,false)!=null,"Discovered region must appear")
 var exp:=Expedition3D.new();root.add_child(exp);exp.set_process(false);exp.stage_area_index=5;exp.stage_node_index=0;exp.stage_level=2;exp.build_level()
 check(exp.hidden_area_index==17 and is_instance_valid(exp.hidden_entrance),"Host region needs a discoverable entrance")
 var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(0,5));exp.place_actor(actor);actor.set_physics_process(false);exp.team.append(actor)
 actor.position=exp.hidden_entrance.position;exp.update_hidden_discovery()
 check(exp.discovered_areas==[17],"Approaching entrance should discover destination")
 check(is_instance_valid(actor.exclamation_icon),"Discovery should show exclamation art")
 check(not game.discovered_optional_areas.has(17),"Discovery must wait until expedition ends")
 var results:Dictionary={}
 exp.expedition_finished.connect(func(value):results.merge(value))
 exp.finish(false)
 check(results.get("discovered_areas",[])==[17],"Discovery must survive returning without victory")
 game._on_expedition_finished(results)
 check(game.discovered_optional_areas.has(17),"Run results should unlock discovery")
 var enemy:=QuibletActor3D.new();enemy.setup(GameData.make_quiblet(1,5),true);exp.place_actor(enemy);enemy.set_physics_process(false);exp.enemies.append(enemy);enemy.position=actor.position
 exp._on_move_used(enemy,"Distract",actor,{})
 check(is_instance_valid(actor.exclamation_icon),"Distract should put the icon above affected opponents")
 await create_timer(3.1).timeout
 check(not is_instance_valid(actor.exclamation_icon),"Exclamation should disappear")
 exp.free();game.queue_free();await process_frame
 print("REGIONS_AND_DISCOVERY checks=",checks);quit()
