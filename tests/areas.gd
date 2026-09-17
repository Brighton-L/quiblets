extends SceneTree

const EXPECTED:=["Rolling Steppe","Windy Fields","Winding Creeks","Crooked Cliffs","Soggy Lowlands","Lush Basin","Glimmering Grotto","Shivering Shelf","Parched Plains","Highland Peaks","Muddy Moor","Foaming Fjord","Gloomy Glade","Looming Lowlands","Distant Downs","Mystery Meadow","Rustling Thicket","Pebbled Shoals","Rocky Ravine","Golden Grove"]
const TYPES:=["level","level","level","berry_grove","level","level","boss","optional_berry_grove"]
var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func run()->void:
	check(GameData.EXPEDITION_AREAS==EXPECTED,"Area names/order changed")
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	for species_index in [1,2,6,5]:game.roster.append(GameData.make_quiblet(species_index,6))
	game.team_indices.assign([0,1,2,3,4])
	check(game.map_page_count()==1,"The island should be one map")
	game.show_map();await process_frame
	check(game.visible_map_areas().size()==16,"Only main regions should begin visible")
	for index in game.visible_map_areas():
		check(game.content.find_child("AreaLabel%d"%index,true,false).text==EXPECTED[index],"Wrong region label")
		check(game.map_area_at_point(game.map_island_position(index))==index,"Region hit target resolves incorrectly")
	check(GameData.expedition_area_level(0)==2 and GameData.expedition_area_level(1)==5 and GameData.expedition_area_level(15)==61,"Expedition level scaling should start gently and rise smoothly")
	game.area_progress[14]=7;game.show_map();await process_frame
	game.content.find_child("RegionButton15",true,false).pressed.emit();await process_frame
	check(game.screen=="area_levels" and game.selected_area_index==15 and game.expedition==null,"Island click bypassed the level menu")
	check(game.content.find_child("BackButton",true,false)!=null,"Level menu needs a return button")
	for area in 16:
		game.area_progress.fill(0)
		if area>0:game.area_progress[area-1]=7
		game.show_area_levels(area);await process_frame
		check(game.area_progress[area]==0,"Fresh area unexpectedly has progress")
		for node in 8:
			var data:Dictionary=game.area_level_data(area,node);var card:Control=game.content.find_child("LevelNode%d"%node,true,false);var play:Button=card.get_node("PlayLevel%d"%node)
			check(data.type==TYPES[node] and card!=null,"Incorrect route node sequence")
			check(play.disabled==(node>0),"Only the first level should begin unlocked")
			check(card.find_children("*","Label",true,false).any(func(item):return str(item.text).contains("♥") and str(item.text).contains("⚔") and str(item.text).contains("◎")),"Level lacks difficulty details")
	game.area_progress.fill(0)
	game.show_area_levels(0);await process_frame;game.start_area_level(0,1);check(game.screen=="area_levels","Locked level was playable")
	for node in 8:
		game.start_area_level(0,node);await process_frame
		check(game.screen=="expedition" and game.expedition.stage_node_index==node and game.expedition.stage_kind==TYPES[node],"Unlocked node launched wrong level")
		check(not str(game.expedition.obstacles).is_empty(),"Level map was not built")
		if node==0:
			var first:Expedition3D=game.expedition
			check(first.max_waves>=5 and first.max_waves<=7 and first.spawn_points.size()==1 and first.enemies.size()>=1 and first.enemies.size()<=2 and first.enemies.all(func(enemy):return int(enemy.get_meta("group"))==1 and is_equal_approx(enemy.damage_multiplier,.58) and not enemy.get_meta("alerted",false)),"A level should open with one small idle set at a spawn area, with more sets and the boss to come")
			var member:QuibletActor3D=first.team[0];member.current_hp=member.max_hp*.5
			var first_point:int=int(first.enemies[0].get_meta("spawn_point"))
			for enemy in first.enemies.duplicate():first._on_actor_defeated(enemy)
			check(is_equal_approx(member.current_hp,member.max_hp*.75),"Surviving Quiblets should recover 25% health between sets")
			check(first.intermission>0.0 and first.enemies.is_empty(),"The next set must not appear until the previous one is beaten")
			first.intermission=.01;first._process(.02)
			check(first.wave==2 and not first.enemies.is_empty() and first.enemies.all(func(enemy):return int(enemy.get_meta("spawn_point"))!=first_point),"The second set should appear at a different spawn area")
		game.expedition.finish(true);await process_frame
		check(game.screen=="expedition_changes" and game.area_progress[0]==node+1,"Victory did not unlock the next node or show results")
		game.show_area_levels(0);await process_frame
	game.start_area_level(0,0);await process_frame;check(game.screen=="expedition","Cleared level could not be replayed");game.expedition.finish(false);await process_frame;game.show_area_levels(0);await process_frame
	check(game.area_progress[0]==8,"Replay loss incorrectly removed progress")
	game.start_area_level(0,6);await process_frame
	var boss_stage:Expedition3D=game.expedition
	check(boss_stage.max_waves>=8 and boss_stage.max_waves<=10 and boss_stage.zones.size()==4 and boss_stage.enemies.size()>=2 and not boss_stage.enemies.any(func(enemy):return enemy.get_meta("level_boss",false)),"Boss level should run more enemy sets than a regular level, each one larger, with the boss last")
	check(boss_stage.enemies.all(func(enemy):return int(enemy.data.level)>=boss_stage.enemy_level(-1)+1),"Boss-level sets should be at least one level stronger than regular enemies")
	# Park the team deeper into the map, then beat every set.
	var far_arena:Vector2=boss_stage.zones[3].center
	for member in boss_stage.team:member.position=Vector3(far_arena.x-3.0,0,far_arena.y)
	var sets_seen:int=0
	while boss_stage.wave<boss_stage.max_waves:
		sets_seen+=1
		check(not boss_stage.enemies.is_empty() and not boss_stage.enemies.any(func(enemy):return enemy.get_meta("level_boss",false)),"Each set before the boss should be ordinary enemies")
		for enemy in boss_stage.enemies.duplicate():boss_stage._on_actor_defeated(enemy)
		boss_stage.intermission=.01;boss_stage._process(.02)
	var bosses:Array=boss_stage.enemies.filter(func(enemy):return enemy.get_meta("level_boss",false))
	check(sets_seen==boss_stage.max_waves-1 and bosses.size()==1 and boss_stage.enemies.size()==4 and boss_stage.encounter_walk_distance(boss_stage.team_centroid(),Vector2(boss_stage.camera_pan_target.x,boss_stage.camera_pan_target.z))<=boss_stage.SET_MAX_WALK_DISTANCE and boss_stage.camera_pan_time>0.0,"Beating the last set should bring the boss and its escorts within walking range and pan the camera there")
	var stage_boss:QuibletActor3D=bosses[0];var escort:QuibletActor3D=boss_stage.enemies.filter(func(enemy):return not enemy.get_meta("level_boss",false))[0]
	check(stage_boss.scale.x>1.8 and int(stage_boss.data.level)==int(escort.data.level)+4 and stage_boss.max_hp>GameData.max_hp(stage_boss.data)*float(GameData.enemy_scaling(0).hp)*3.9 and stage_boss.damage_multiplier>escort.damage_multiplier*1.6,"The stage boss should be much tougher than its escorts")
	var rewards:Array=[];boss_stage.reward_acquired.connect(func(reward,_position):rewards.append(reward))
	var escorts:int=boss_stage.enemies.size()-1;boss_stage._on_actor_defeated(stage_boss)
	check(boss_stage.enemies.is_empty() and boss_stage.intermission>0.0 and rewards.filter(func(reward):return reward.kind=="ingredient").size()==escorts+1,"Beating the stage boss should defeat every escort and hand out each one's loot")
	game.expedition.finish(false);await process_frame;game.show_area_levels(0);game.start_area_level(0,7);await process_frame
	var grove:Expedition3D=game.expedition
	check(grove.max_waves==1 and grove.zones.size()==6 and grove.berry_nodes.size()==34 and grove.enemies.size()==2 and grove.enemies.all(func(enemy):return enemy.get_meta("guardian",false) and not enemy.get_meta("alerted",false)),"Optional Berry Grove should be a long meadow chain with a few idle guardians")
	check(grove.enemies.all(func(enemy):return int(enemy.data.level)==maxi(1,grove.stage_level-1)+2 and int(enemy.get_meta("zone"))%2==0),"Grove guardians should be slightly stronger and wait in every other meadow")
	grove._process(.02)
	check(grove.team.all(func(member):return member.target==null),"The team must not chase idle grove guardians")
	for enemy in grove.enemies.duplicate():grove._on_actor_defeated(enemy)
	grove._process(.02)
	check(grove.intermission<=0.0 and not grove.ended and grove.berry_nodes.size()==34,"Defeating every guardian must not end a grove")
	var gatherer:QuibletActor3D=grove.team[0];var gathered_safety:=0
	while not grove.berry_nodes.is_empty() and gathered_safety<80:
		gatherer.position=grove.berry_nodes[0].position;grove._process(.02);gathered_safety+=1
	check(grove.gathered==34 and grove.intermission>0.0 and not grove.ended,"Gathering the last patch should start the grove's finish")
	grove.intermission=.01;grove._process(.02);await process_frame
	check(grove.ended and game.screen=="expedition_changes" and game.last_result.victory and int(game.last_result.berries)==34,"A grove should end in victory once every patch is gathered")
	game.expedition.finish(false);await process_frame;game.show_area_levels(0);await process_frame
	var signatures:Array=[]
	for node in 8:
		var expedition:=Expedition3D.new();expedition.stage_area_index=4;expedition.stage_node_index=node;expedition.stage_kind=TYPES[node];root.add_child(expedition);expedition.build_level();signatures.append(str(expedition.obstacles));expedition.free()
	check(signatures.all(func(signature):return signatures.count(signature)==1),"Levels reused the same map layout")
	if OS.get_cmdline_user_args().has("--render-gallery"):
		game.show_map();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/private/tmp/quiblets-islands-no-cards.png")
		game.area_progress[4]=8;game.show_area_levels(4);await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/private/tmp/quiblets-level-route.png")
	print("QUIBLETS_AREAS_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
