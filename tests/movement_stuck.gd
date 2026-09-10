extends SceneTree

# Quiblets must not jitter in place against terrain: routed runs skip corner
# steering, arrivals settle, and a Quiblet that stops gaining ground asks for a
# fresh route. Physics is stepped by hand so the runs are deterministic.
var failures:=0
var checks:=0
const STEP:=1.0/60.0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func build(area:int,node:int)->Expedition3D:
	var e:=Expedition3D.new();e.stage_area_index=area;e.stage_node_index=node;e.stage_kind="level";e.stage_level=GameData.expedition_area_level(area)
	root.add_child(e);e.set_process(false);e.build_level();return e

func add_actor(e:Expedition3D,is_enemy:bool,at:Vector2)->QuibletActor3D:
	var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(3 if is_enemy else 0,10),is_enemy,0,-1 if is_enemy else 2);e.place_actor(actor);actor.set_physics_process(false)
	actor.position=Vector3(at.x,0,at.y);actor.progress_anchor=actor.position
	if is_enemy:e.enemies.append(actor);actor.set_meta("alerted",true)
	else:e.team.append(actor)
	return actor

# A blocked cell with open ground two tiles to either side and no straight line between them.
func blocked_crossing(e:Expedition3D)->Vector2i:
	for x in range(e.field_rect.position.x+3,e.field_rect.end.x-3):
		for z in range(e.field_rect.position.y+3,e.field_rect.end.y-3):
			var cell:=Vector2i(x,z)
			if e.walkable.has(cell):continue
			var west:=cell+Vector2i(-2,0);var east:=cell+Vector2i(2,0)
			if e.walkable.has(west) and e.walkable.has(east) and e.cell_open(west) and e.cell_open(east) and not e.line_walkable(Vector2(west),Vector2(east)) and e.find_path(Vector2(west),Vector2(east)).size()>1:return cell
	return Vector2i(-9999,-9999)

func step(e:Expedition3D,actors:Array,seconds:float,with_chase_routing:bool)->void:
	for i in int(seconds/STEP):
		if with_chase_routing:e.update_chase_routing(STEP)
		for actor in actors:actor._physics_process(STEP)

func run()->void:
	var e:=build(0,1)
	var crossing:=blocked_crossing(e)
	check(crossing.x>-9000,"Test needs a blocked cell with open ground on both sides")
	var west:=Vector2(crossing+Vector2i(-2,0));var east:=Vector2(crossing+Vector2i(2,0))
	# A commanded run around the obstacle arrives and settles.
	var runner:=add_actor(e,false,west)
	e.issue_route_command(Vector3(east.x,0,east.y),[runner])
	check(runner.has_command,"The run should be issued as a route")
	step(e,[runner],8.0,false)
	check(runner.horizontal_distance(runner.position,Vector3(east.x,0,east.y))<1.0 and not runner.has_command,"A routed run around terrain should arrive and drop its command (ended %.2f away)"%runner.horizontal_distance(runner.position,Vector3(east.x,0,east.y)))
	# A chase across the same obstacle closes in instead of jittering against it.
	var chaser:=add_actor(e,false,west);var quarry:=add_actor(e,true,east);chaser.target=quarry
	var start_distance:=chaser.horizontal_distance(chaser.position,quarry.position)
	step(e,[chaser],8.0,true)
	var end_distance:=chaser.horizontal_distance(chaser.position,quarry.position)
	check(end_distance<minf(chaser.attack_range*.78,4.5)+.6,"A chaser routed around terrain should reach attack reach (from %.2f to %.2f)"%[start_distance,end_distance])
	# Crowding: five Quiblets sent to one spot all settle instead of shoving each other forever.
	var open_center:=Vector2(e.zones[0].center)
	var crowd:Array=[]
	for i in 5:crowd.append(add_actor(e,false,open_center+Vector2(-6+i*.8,4)))
	e.issue_route_command(Vector3(open_center.x,0,open_center.y),crowd)
	step(e,crowd,7.0,false)
	check(crowd.all(func(member):return not member.has_command),"Crowded arrivals should all count as arrived (%d still trying)"%crowd.filter(func(member):return member.has_command).size())
	check(crowd.all(func(member):return member.horizontal_distance(member.position,Vector3(open_center.x,0,open_center.y))<2.6),"Crowded arrivals should end near the target")
	# Steering off a route never leaves a Quiblet inside terrain for long: from a wall pocket it re-routes out.
	var pocket:=Vector2(crossing);var escaper:=add_actor(e,false,pocket);var far_goal:=Vector3(east.x,0,east.y)
	var fired:=[0];escaper.stuck.connect(func(_actor):fired[0]+=1)
	escaper.command(far_goal);step(e,[escaper],6.0,false)
	check(escaper.horizontal_distance(escaper.position,far_goal)<1.0,"A Quiblet starting inside a blocked cell should still reach its goal (ended %.2f away, stuck fired %d)"%[escaper.horizontal_distance(escaper.position,far_goal),fired[0]])
	# A moving Quiblet turns to face its direction of travel, on a route and on a chase alike.
	var walker:=add_actor(e,false,open_center+Vector2(-5,-5));walker.model.rotation.y=PI
	walker.command(Vector3(open_center.x+5,0,open_center.y-5));step(e,[walker],.6,false)
	var heading:=Vector3(walker.velocity.x,0,walker.velocity.z).normalized();var front:=walker.facing();front.y=0
	check(heading.length()>.5 and front.normalized().angle_to(heading)<.2,"A routed Quiblet should face the way it walks (off by %.2f rad)"%front.normalized().angle_to(heading))
	var hunter:=add_actor(e,false,open_center+Vector2(6,6));var prey:=add_actor(e,true,open_center+Vector2(-6,6));hunter.target=prey;hunter.model.rotation.y=0
	step(e,[hunter],.6,true)
	var chase_heading:=Vector3(hunter.velocity.x,0,hunter.velocity.z).normalized();var chase_front:=hunter.facing();chase_front.y=0
	check(chase_heading.length()>.5 and chase_front.normalized().angle_to(chase_heading)<.2,"A chasing Quiblet should face the way it runs (off by %.2f rad)"%chase_front.normalized().angle_to(chase_heading))
	e.free()
	print("QUIBLETS_MOVEMENT_STUCK_OK checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
