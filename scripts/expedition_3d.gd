class_name Expedition3D
extends Node3D

signal expedition_finished(result:Dictionary)
signal event_message(text:String)
signal reward_acquired(reward:Dictionary,world_position:Vector3)
signal boss_fight_started
signal treasure_key_used
signal boss_fight_ended

var team_data:Array=[]
var team:Array[QuibletActor3D]=[]
var enemies:Array[QuibletActor3D]=[]
var stage_level:=7
var stage_name:="Longgrass Fields"
var stage_area_index:=0
var stage_node_index:=0
var stage_kind:="level"
var elapsed:=0.0
var wave:=0
var max_waves:=3
var intermission:=0.0
var gathered:=0
var loot:={}
var move_stones:={}
var power_stones:Array[Dictionary]=[]
var fortune:=false
var challenger:=false
var camera:Camera3D
var camera_focus:=Vector3.ZERO
var obstacles:Array[Rect2]=[Rect2(-3.8,-4.8,2.3,2.1),Rect2(2.2,1.2,3.0,1.7),Rect2(6.0,-4.5,2.1,2.4)]
var berry_nodes:Array[Node3D]=[]
# Open-field layout: the playable rectangle, sunken river cells, the land
# bridges that cross them, and interior wall cells with their block heights.
var field_rect:Rect2i=Rect2i()
# Destructible trees and boulders standing in the field, keyed by their cell.
const PROP_SCRIPT:=preload("res://scripts/expedition_prop_3d.gd")
var props:Array=[]
# Container nodes keep the expedition's own child list short: every rim
# decoration goes under Decor and every destructible prop under Props.
var decor_root:Node3D
var props_root:Node3D
var prop_cells:={}
const PROP_SPACING:=2.5
var rivers:={}
var bridges:={}
var wall_tiers:={}
# Locked treasure cache (regular and Boss levels): opened by walking a team
# member onto it while the player owns a Treasure Key. Main sets treasure_keys
# before the stage begins and consumes one per treasure_key_used signal.
var cache_node:Node3D
var treasure_keys:=0
var extra_specials:Array[String]=[]
var ended:=false

# Route map. A stage is a chain of clearings ("zones") joined by winding
# corridors, carved from a one-unit tile grid. Everything off the route rises
# into stepped cube cliffs. Zone 0 is the start; wave N waits in zone N.
const ZONE_SPACING:=10.0
const ROUTE_SAMPLES:=13
const ALERT_MARGIN:=2.5
# How close a taunting Quiblet must be to redirect an enemy onto itself.
const TAUNT_RANGE:=14.0
const MAX_DECOR:=40
var zones:Array[Dictionary]=[]
var route_points:Array[Vector2]=[]
var corridor_widths:Array[float]=[]
var walkable:Dictionary={}
var arena_rect:=Rect2(-12,-6,24,12)
var biome:Dictionary={}
var advance_waypoints:Array[Vector3]=[]
var advance_index:=-1
var decor_count:=0
var cliff_tiers:Dictionary={}

func setup_camera(new_camera:Camera3D)->void:
	camera=new_camera;camera_focus=Vector3.ZERO;camera.position=Vector3(0,13,15);camera.look_at(camera_focus,Vector3.UP);camera.fov=48

# Boss levels play like regular levels with one extra wave. Berry Groves are a
# long chain of meadows: the team gathers every patch to finish, and only a few
# slightly stronger guardians wait in every other meadow.
# Levels and Boss levels: the start clearing plus BOSS_ARENAS boss arenas; the
# boss appears in whichever arena is nearest the team once the field is clear.
func zone_count()->int:
	return GROVE_MEADOWS+1 if is_grove() else BOSS_ARENAS+1

const BOSS_ARENAS:=3
const SCATTER_GROUPS:={"level":Vector2i(4,6),"boss":Vector2i(7,9)}
const SPAWN_POINTS:=8
const SPAWN_POINT_MIN_START_DISTANCE:=10.0
const SPAWN_POINT_SPACING:=9.0
const SET_MIN_TEAM_DISTANCE:=9.0
const SCATTER_ALERT_RADIUS:=3.2
var spawn_points:Array[Vector2]=[]
var used_spawn_points:Array[int]=[]
const BOSS_INTRO_PAN_SECONDS:=4.5
# A new set holds the camera only until its last enemy has landed, plus a short linger.
const SPAWN_DROP_STAGGER:=.08
const SPAWN_DROP_SECONDS:=.54
const SET_PAN_LINGER:=.6
const BOSS_INTRO_FACE_DELAY:=2.0
var spawn_rng:=RandomNumberGenerator.new()
var exploring:=false
var camera_pan_target:=Vector3.ZERO
var camera_pan_time:=0.0
var boss_grunt_player:AudioStreamPlayer

func is_grove()->bool:
	return stage_kind in ["berry_grove","optional_berry_grove"]

const GROVE_MEADOWS:=5
const GROVE_MEADOW_RADIUS:=Vector2(5.2,4.2)
const GROVE_GUARDED_MEADOW_STEP:=2
const GROVE_GUARDIAN_LEVEL_BOOST:=2
const GROVE_GUARDIAN_HP_MULTIPLIER:=1.25
const GROVE_PATCHES:={"berry_grove":26,"optional_berry_grove":34,"level":4,"boss":4}
var grove_zone:=1

const BOSS_STAGE_WAVES:=4
const BOSS_STAGE_EXTRA_ENEMIES:=1
const BOSS_STAGE_ENEMY_LEVEL_BOOST:=1
const BOSS_STAGE_BOSS_LEVEL_BOOST:=5
const BOSS_STAGE_BOSS_HP_MULTIPLIER:=4.0
const BOSS_STAGE_BOSS_DAMAGE_MULTIPLIER:=1.7
const BOSS_STAGE_BOSS_SCALE:=1.9

# Enemy strength answers the team: see GameData.enemy_level_for_stage and enemy_stone_bonus.
var team_average_level:=0
var enemy_bonus:={"hp":0,"attack":0}

func enemy_level(wave_offset:int)->int:
	return maxi(1,GameData.enemy_level_for_stage(stage_level,team_average_level,stage_area_index)+wave_offset)

func make_enemy(species_index:int,level:int)->Dictionary:
	var q:=GameData.make_quiblet(species_index,level)
	q.hp_bonus=int(enemy_bonus.hp);q.atk_bonus=int(enemy_bonus.attack)
	return q

func begin(new_team:Array,level:int,use_fortune:bool,use_challenger:bool)->void:
	team_data=new_team;stage_level=level;fortune=use_fortune;challenger=use_challenger
	var level_total:=0
	for q in team_data:level_total+=int(q.get("level",1))
	team_average_level=level_total/maxi(1,team_data.size())
	enemy_bonus=GameData.enemy_stone_bonus(GameData.team_stone_power(team_data),stage_area_index)
	# Every stage is one field. Groves are cleared by gathering. Levels run a
	# handful of enemy sets (waves 1..n), each spawning at one of the field's
	# spawn areas only after the previous set is beaten, and then the boss.
	spawn_rng.randomize()
	var sets:Vector2i=SCATTER_GROUPS.get(stage_kind,Vector2i(4,6))
	max_waves=1 if is_grove() else spawn_rng.randi_range(sets.x,sets.y)+1
	grove_zone=1;exploring=false;next_exploration_plan=0.0;camera_pan_time=0.0;used_spawn_points.clear()
	loot.clear()
	for ingredient_name in GameData.INGREDIENTS:loot[ingredient_name]=0
	move_stones.clear();power_stones.clear()
	build_level()
	var start:Vector2=zones[0].center
	for i in team_data.size():
		var actor:=QuibletActor3D.new();actor.setup(team_data[i],false,0,i);actor.position=Vector3(start.x-.6+(i%2)*1.2,0,start.y+(i-2)*.9);place_actor(actor);team.append(actor)
	if is_instance_valid(camera):
		camera_focus=Vector3(start.x,0,start.y);camera.global_position=camera_focus+Vector3(0,13,15);camera.look_at(camera_focus+Vector3(0,.45,0),Vector3.UP)
	if not is_grove():prepare_spawn_points()
	spawn_wave()

func place_actor(actor:QuibletActor3D)->void:
	actor.arena=arena_rect;actor.obstacle_rects=flight_obstacles if actor.floats_over_water() else obstacles;actor.defeated.connect(_on_actor_defeated);actor.move_used.connect(_on_move_used);actor.stuck.connect(_on_actor_stuck);add_child(actor)

func build_level()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=stage_area_index*1009+stage_node_index*131+73
	biome=GameData.expedition_biome(stage_area_index)
	fade_weights.clear();waterfall_cells.clear();waterfalls.clear();waterfall_bubbles.clear();spanned_cells.clear();bridge_arches.clear();river_crossings.clear();obstacles.clear();berry_nodes.clear();zones.clear();route_points.clear();corridor_widths.clear();walkable.clear();rivers.clear();bridges.clear();wall_tiers.clear();props.clear();prop_cells.clear();decor_count=0;cliff_tiers={1:0,2:0,3:0};cache_node=null
	if is_instance_valid(decor_root):decor_root.free()
	if is_instance_valid(props_root):props_root.free()
	decor_root=Node3D.new();decor_root.name="Decor";add_child(decor_root)
	props_root=Node3D.new();props_root.name="Props";add_child(props_root)
	layout_zones(rng)
	carve_walkable()
	carve_rivers(rng)
	raise_walls(rng)
	place_props(rng)
	build_obstacles()
	plan_bridges()
	build_terrain(rng)
	# build_terrain seats harvestable props on the hills too; refresh the obstacle
	# runs so actors steer around them.
	obstacles.clear();build_obstacles()
	place_berry_patches(rng)
	place_treasure_cache(rng)
	build_bridges()
	build_waterfalls()
	build_clouds(rng)
	seat_on_terrain()

# Props, patches, and the cache sit on the rolling ground; fighters are seated every frame.
func seat_on_terrain()->void:
	for prop in props:
		if is_instance_valid(prop):prop.position.y=terrain_height_at(Vector2(prop.position.x,prop.position.z))
	for patch in berry_nodes:
		if is_instance_valid(patch):patch.position.y=terrain_height_at(Vector2(patch.position.x,patch.position.z))+.2
	if is_instance_valid(cache_node):cache_node.position.y=terrain_height_at(Vector2(cache_node.position.x,cache_node.position.z))

# Every Boss level hides a cache; a regular level does so only some of the time,
# decided by the level's own seed so the same node always agrees with itself.
# The cache sits in an exposed side pocket away from the trail, the clearings'
# centres, and the berry patches.
func has_treasure_cache(_rng:RandomNumberGenerator)->bool:
	if stage_kind=="boss":return true
	if stage_kind!="level":return false
	# Rolled from the node's own seed, independent of how much randomness the
	# terrain and decor happen to consume, so a level's cache never moves when the look changes.
	var cache_rng:=RandomNumberGenerator.new();cache_rng.seed=stage_area_index*1009+stage_node_index*131+4111
	return cache_rng.randf()<GameData.TREASURE_CACHE_LEVEL_CHANCE

func place_treasure_cache(rng:RandomNumberGenerator)->void:
	if not has_treasure_cache(rng):return
	var pockets:Array[Vector2i]=[];var others:Array[Vector2i]=[]
	for cell in reachable_walkable_cells():
		var point:=Vector2(cell.x,cell.y)
		if zone_index_at(point)==0 or not cell_exposed(cell):continue
		if zones.any(func(zone):return Vector2(zone.center).distance_to(point)<2.2):continue
		if berry_nodes.any(func(patch):return Vector2(patch.position.x,patch.position.z).distance_to(point)<2.0):continue
		if route_distance(point)>=1.6:pockets.append(cell)
		else:others.append(cell)
	shuffle_cells(pockets,rng);shuffle_cells(others,rng)
	var candidates:Array[Vector2i]=pockets+others
	if candidates.is_empty():return
	var cell:Vector2i=candidates[0]
	cache_node=Node3D.new();cache_node.position=Vector3(cell.x,0,cell.y);cache_node.set_meta("zone",patch_zone(Vector2(cell)))
	var body:=BoxMesh.new();body.size=Vector3(.8,.5,.55);var chest:=MeshInstance3D.new();chest.mesh=body;chest.position=Vector3(0,.25,0);var wood:=StandardMaterial3D.new();wood.albedo_color=Color("#8a5a2b");wood.roughness=.85;chest.material_override=wood;cache_node.add_child(chest)
	var lid_mesh:=BoxMesh.new();lid_mesh.size=Vector3(.84,.18,.6);var lid:=MeshInstance3D.new();lid.mesh=lid_mesh;lid.position=Vector3(0,.58,0);var gold:=StandardMaterial3D.new();gold.albedo_color=GameData.COLORS.gold;gold.metallic=.4;gold.roughness=.35;lid.material_override=gold;cache_node.add_child(lid)
	add_child(cache_node)

func open_treasure_cache()->void:
	if not is_instance_valid(cache_node) or treasure_keys<=0:return
	treasure_keys-=1;treasure_key_used.emit()
	var origin:Vector3=cache_node.global_position
	# A cache always holds a Power Stone rolled with Fortune-rate bonuses, two
	# ingredient bundles, and a Boss-rate chance at a special item.
	var power_stone:=GameData.make_power_stone(["Health","Attack"].pick_random(),GameData.power_stone_tier_for_level(stage_level),GameData.roll_power_stone_bonuses(true));power_stones.append(power_stone)
	var reward:=power_stone.duplicate(true);reward.merge({"kind":"power_stone","name":power_stone.type+" Power Stone","amount":1});reward_acquired.emit(reward,origin)
	for i in 2:
		var ingredient:=GameData.roll_ingredient(stage_level);var amount:=randi_range(BERRY_PATCH_RANGE.x,BERRY_PATCH_RANGE.y);loot[ingredient]+=amount
		reward_acquired.emit({"kind":"ingredient","name":ingredient,"amount":amount},origin)
	var special:=GameData.roll_special_item("boss",fortune)
	if special!="":extra_specials.append(special);reward_acquired.emit({"kind":"special","name":special,"amount":1},origin)
	cache_node.queue_free();cache_node=null
	event_message.emit("The Treasure Key opens the cache!")

# --- Open-field layout ---------------------------------------------------
# A level is one big open field, Pokémon Quest style, rather than a chain of
# corridors: the team starts at the left edge and the wave clearings zigzag
# across the field toward the right. Sunken rivers cut the field and can only
# be crossed at land bridges, and blocky multi-tier walls stand in the open,
# more of them the more walled-in the island's biome is.
func field_size()->Vector2i:
	# 2.5 times the former width and depth: 6.25 times the playable area.
	if is_grove():return Vector2i(160,90)
	if stage_kind=="boss":return Vector2i(150,100)
	return Vector2i(130,90)

func layout_zones(rng:RandomNumberGenerator)->void:
	var count:=zone_count();var size:=field_size()
	field_rect=Rect2i(-size.x/2,-size.y/2,size.x,size.y)
	var left:=float(field_rect.position.x)+4.0;var right:=float(field_rect.end.x)-1-(6.5 if stage_kind=="boss" else 4.0)
	var swing:=float(size.y)*.27;var side:=1.0 if rng.randf()<.5 else -1.0
	for i in count:
		var center:=Vector2(left,0.0)
		if i>0:
			center.x=lerpf(left,right,float(i)/float(count-1))+rng.randf_range(-.8,.8)
			center.y=side*swing+rng.randf_range(-1.2,1.2);side*=-1.0
		var radius:=Vector2(3.4,2.9)
		if i>0:
			if stage_kind=="boss":radius=Vector2(6.2,5.0)
			elif is_grove():radius=GROVE_MEADOW_RADIUS
			else:radius=Vector2(rng.randf_range(4.0,4.8),rng.randf_range(3.4,4.2))
		zones.append({"center":center,"radius":radius,"phase":rng.randf()*TAU})
	# The worn trail runs straight from clearing to clearing; it only colours the
	# floor and marks "off-trail" pockets for patches, since the field is open.
	for i in range(1,count):
		var a:Vector2=zones[i-1].center;var b:Vector2=zones[i].center
		corridor_widths.append(2.0)
		for step in ROUTE_SAMPLES:route_points.append(a.lerp(b,float(step)/(ROUTE_SAMPLES-1)))

func in_field(cell:Vector2i)->bool:
	return field_rect.has_point(cell)

# A few main rivers collect shorter tributaries. Uneven source spacing and
# broad, non-repeating bends keep the network from dividing the map into a grid.
const EXTRA_RIVERS_MIN:=6
const EXTRA_RIVERS_MAX:=8
var river_channels:=0
var cliff_layer_count:=0
var river_flow:={}
var bridge_approaches:={}
func carve_rivers(rng:RandomNumberGenerator)->void:
	var base_count:int=int(biome.rivers)
	var map_scale:float=float(field_rect.size.x+field_rect.size.y)/220.0
	var river_count:int=ceili(float(base_count*2+rng.randi_range(EXTRA_RIVERS_MIN,EXTRA_RIVERS_MAX))*map_scale)
	river_channels=river_count;river_flow.clear();bridge_approaches.clear()
	if river_count<=0:return
	var usable_left:=field_rect.position.x+7;var usable_right:=field_rect.end.x-8
	var usable_top:=field_rect.position.y+5;var usable_bottom:=field_rect.end.y-6
	if usable_right<=usable_left or usable_bottom<=usable_top:return
	var source_positions:Array[Vector2]=[]
	for river_index in river_count:
		var horizontal:bool=river_index==0 or (river_index>1 and rng.randf()<.5)
		var width:=4 if rng.randf()<.6 else 5
		var falls:bool=rng.randf()<WATERFALL_CHANCE
		var reverse:bool=not falls and rng.randf()<.5
		var flow:=Vector2(1,0) if horizontal else Vector2(0,1)
		if reverse:flow=-flow
		var cells:Array[Vector2i]=[];var source_cells:Array[Vector2i]=[]
		var low:float=usable_top if horizontal else usable_left
		var high:float=usable_bottom if horizontal else usable_right
		var source:=rng.randf_range(low,high)
		# Keep sources distinct without arranging them into evenly spaced lanes.
		for attempt in 20:
			var candidate:=rng.randf_range(low,high)
			source=candidate
			if not source_positions.any(func(other):return other.x==float(horizontal) and absf(other.y-candidate)<8.0):break
		source_positions.append(Vector2(float(horizontal),source))
		var bends:=FastNoiseLite.new();bends.seed=rng.randi();bends.frequency=rng.randf_range(.018,.035)
		bends.fractal_octaves=2
		var bend_size:=rng.randf_range(5.0,10.0)
		var start:int=field_rect.position.x if horizontal else field_rect.position.y
		var finish:int=field_rect.end.x if horizontal else field_rect.end.y
		var positions:Array[int]=[]
		for along in range(start-(WATERFALL_REACH if falls else 1),finish+1):positions.append(along)
		if reverse:positions.reverse()
		var join_remaining:=-1
		for along in positions:
			var cross:=roundi(clampf(source+bends.get_noise_1d(float(along))*bend_size,low,high))
			var row:Array[Vector2i]=[];var touches_river:=false
			for w in width:
				var cell:=Vector2i(along,cross+w) if horizontal else Vector2i(cross+w,along)
				row.append(cell)
				if rivers.has(cell):touches_river=true
				if falls and along<start:source_cells.append(cell)
			cells.append_array(row)
			# Tributaries merge into existing water instead of crossing the whole
			# island. Extend through the confluence to avoid a pinched dry seam.
			if river_index>=2 and touches_river and along>=start and along<finish and join_remaining<0:join_remaining=2
			if join_remaining==0:break
			if join_remaining>0:join_remaining-=1
		for cell in cells:
			rivers[cell]=true;river_flow[cell]=flow;walkable.erase(cell)
		if falls and not source_cells.is_empty():
			for cell in source_cells:
				if rivers.has(cell):waterfall_cells[cell]=true
			# The lip sits on the field's edge, across the channel's width.
			var lip:=Vector2.ZERO;var count:=0
			for cell in source_cells:
				var edge_cell:Vector2i=Vector2i(field_rect.position.x-1,cell.y) if horizontal else Vector2i(cell.x,field_rect.position.y-1)
				if cell==edge_cell:lip+=Vector2(cell);count+=1
			if count>0:waterfalls.append({"lip":lip/float(count)+flow*.5,"flow":flow,"half_width":float(width)*.5})
	move_clearings_off_rivers()
	spawn_river_bridges()

func move_clearings_off_rivers()->void:
	# Move encounter centres onto a nearby bank instead of punching dry holes
	# into the channel. Keep enough ground around each centre for the team.
	var safe_cells:Array[Vector2i]=[]
	for cell in walkable:
		var safe:=true
		for x in range(-2,3):
			for y in range(-2,3):
				if not walkable.has(cell+Vector2i(x,y)):safe=false;break
			if not safe:break
		if safe:safe_cells.append(cell)
	for zone in zones:
		var best:Vector2=zone.center;var distance:=INF
		for cell in safe_cells:
			var candidate_distance:=Vector2(cell).distance_squared_to(zone.center)
			if candidate_distance<distance:distance=candidate_distance;best=Vector2(cell)
		zone.center=best
	route_points.clear()
	for i in range(1,zones.size()):
		var a:Vector2=zones[i-1].center;var b:Vector2=zones[i].center
		for step in ROUTE_SAMPLES:route_points.append(a.lerp(b,float(step)/(ROUTE_SAMPLES-1)))


# Validate the complete crossing after every river is carved. This prevents a
# later tributary from flooding a bridge's landing or slicing through its deck.
func river_bridge_candidate(cell:Vector2i)->Dictionary:
	var flow:Vector2i=Vector2i(river_flow.get(cell,Vector2.DOWN))
	var axis:=Vector2i(flow.y,flow.x)
	var low:=0;var high:=0
	while low>-12 and rivers.has(cell+axis*(low-1)):low-=1
	while high<12 and rivers.has(cell+axis*(high+1)):high+=1
	for across in [-1,1]:
		var row_low:=0;var row_high:=0
		while row_low>-12 and rivers.has(cell+flow*across+axis*(row_low-1)):row_low-=1
		while row_high<12 and rivers.has(cell+flow*across+axis*(row_high+1)):row_high+=1
		low=mini(low,row_low);high=maxi(high,row_high)
	if high-low>10:return {}
	var band:Array[Vector2i]=[]
	# All three deck lanes must share solid, roomy landings on both banks.
	for across in range(-2,3):
		for along in range(low-2,high+3):
			var point:=cell+axis*along+flow*across
			if not in_field(point):return {}
			if along<low or along>high:
				if not walkable.has(point):return {}
			elif abs(across)<=1:
				if rivers.has(point):
					if Vector2i(river_flow.get(point,Vector2.ZERO))!=flow:return {}
					band.append(point)
				elif not walkable.has(point):return {}
	var center:=Vector2(cell)+Vector2(axis)*float(low+high)*.5
	return {"cells":band,"flow":Vector2(flow),"center":center,
		"half_span":float(high-low)*.5+1.25,"half_width":1.5,
		"bank_a":cell+axis*(low-1),"bank_b":cell+axis*(high+1),
		"score":route_distance(center)+float(high-low)*.3}

func spawn_river_bridges()->void:
	var candidates:Array=[];var centers:={}
	for cell in rivers:
		var candidate:=river_bridge_candidate(cell)
		if candidate.is_empty() or centers.has(candidate.center):continue
		centers[candidate.center]=true;candidates.append(candidate)
	candidates.sort_custom(func(a,b):return a.score<b.score)
	# Label land regions once, then join them as crossings are placed.
	var regions:={};var parents:Array[int]=[]
	for start in walkable:
		if regions.has(start):continue
		var region:=parents.size();parents.append(region)
		var queue:Array[Vector2i]=[start];regions[start]=region;var head:=0
		while head<queue.size():
			var here:=queue[head];head+=1
			for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next:Vector2i=here+step
				if walkable.has(next) and not regions.has(next):regions[next]=region;queue.append(next)
	for candidate in candidates:
		var a:int=regions[candidate.bank_a];var b:int=regions[candidate.bank_b]
		while parents[a]!=a:a=parents[a]
		while parents[b]!=b:b=parents[b]
		var nearby:bool=river_crossings.any(func(other):return Vector2(other.center).distance_to(candidate.center)<9.0)
		# Useful shortcuts near trails supplement the crossings joining islands.
		if a==b and (nearby or float(candidate.score)>5.0):continue
		if candidate.cells.any(func(point):return bridges.has(point)):continue
		parents[b]=a
		for point in candidate.cells:rivers.erase(point);bridges[point]=true;walkable[point]=true
		var axis:=Vector2i(Vector2(candidate.bank_b-candidate.bank_a).normalized())
		var side:=Vector2i(candidate.flow)
		for along in range(-1,roundi(Vector2(candidate.bank_b-candidate.bank_a).length())+2):
			for across in range(-2,3):bridge_approaches[candidate.bank_a+axis*along+side*across]=true
		river_crossings.append(candidate)

# The river cell where the straight trail segment a→b meets the river, or null.
func trail_crossing_cell(a:Vector2,b:Vector2,cells:Array[Vector2i]):
	var best=null;var best_distance:=INF
	for cell in cells:
		var closest:=Geometry2D.get_closest_point_to_segment(Vector2(cell),a,b)
		var distance:=closest.distance_to(Vector2(cell))
		if distance<best_distance:best_distance=distance;best=cell
	return best if best_distance<1.2 else null

# Walls: blocky clusters one to three cells wide with a taller core, dropped in
# the open. Count follows the biome's walls value (plains few, caves many).
# Any cluster that would cut the route off is discarded.
# Hills: clusters of raised cells in the open. They are terrain, not walls: every
# hill stays walkable and Quiblets simply climb over it (they ride the ground
# height), so only rivers ever block a route.
func raise_walls(rng:RandomNumberGenerator)->void:
	var area_scale:=float(field_rect.size.x*field_rect.size.y)/(30.0*22.0)
	var target:=roundi((2.0+14.0*float(biome.walls))*area_scale)
	var placed:=0;var attempts:=0
	while placed<target and attempts<target*12:
		attempts+=1
		var w:=rng.randi_range(2,4);var d:=rng.randi_range(2,4)
		var origin:=Vector2i(rng.randi_range(field_rect.position.x+1,field_rect.end.x-1-w),rng.randi_range(field_rect.position.y+1,field_rect.end.y-1-d))
		var cluster:Array[Vector2i]=[]
		for dx in w:
			for dz in d:cluster.append(origin+Vector2i(dx,dz))
		if cluster.any(func(cell):return not walkable.has(cell) or rivers.has(cell) or bridge_approaches.has(cell) or wall_tiers.has(cell)):continue
		if cluster.any(func(cell):return zones.any(func(zone):return Vector2(zone.center).distance_to(Vector2(cell))<3.2)):continue
		if cluster.any(func(cell):return route_distance(Vector2(cell))<1.2):continue
		var core:=cluster[rng.randi_range(0,cluster.size()-1)]
		for cell in cluster:wall_tiers[cell]=(3 if cell==core else (2 if rng.randf()<.45 else 1)) if cluster.size()>1 else rng.randi_range(1,2)
		placed+=1

# Destructible props: cube-built trees and boulders standing on open tiles, a
# few per field by biome density. Each one blocks its tile until a move breaks
# it, at which point the tile opens up and the obstacle grid is rebuilt.
# Every biome decoration kind stands in the field as a prop; small rocks become boulders.
func prop_kinds()->Array[String]:
	var kinds:Array[String]=[];var decor:Array=biome.decor if biome.decor is Array else [str(biome.decor)]
	for kind in decor:
		var mapped:String="boulder" if str(kind)=="rock" else str(kind)
		if not kinds.has(mapped):kinds.append(mapped)
	if kinds.is_empty():kinds.append("boulder")
	return kinds

const HARVEST_BUNDLES:=1
const HARVEST_BUNDLE_RANGE:=Vector2i(2,4)
const BREAK_BUNDLE_RANGE:=Vector2i(1,2)
const BERRY_PATCH_RANGE:=Vector2i(2,3)
# A rare "rich" patch/tree/shrub gives a bigger bundle of rarer ingredients.
const RICH_YIELD:=Vector2i(5,8)
# What share of props bear fruit (the rest are plain scenery), and the small chance
# a harvestable one is rich. Berry Groves are the lush gathering levels.
const REGULAR_HARVEST_CHANCE:=.32
const GROVE_HARVEST_CHANCE:=.9
const REGULAR_RICH_CHANCE:=.06
const GROVE_RICH_CHANCE:=.16
# Groves (and rich spots) roll ingredients as if the stage were this much deeper,
# so their loot leans toward the rarer, higher-tier resources.
const GROVE_INGREDIENT_LEVEL_BONUS:=8
# Groves grow leafy, harvestable plants regardless of the island's own decor.
const GROVE_PROP_KINDS:Array[String]=["bush","tree","bush","big_mushroom"]

# Ingredients a prop grows: the roll restricted to its tags. Groves and rich plants
# roll at a deeper effective level so they lean toward rarer resources.
func prop_ingredient(prop)->String:
	var level:=stage_level+(GROVE_INGREDIENT_LEVEL_BONUS if (is_grove() or prop.rich) else 0)
	var candidates:Array=[]
	for ingredient_name in GameData.INGREDIENTS:
		if GameData.INGREDIENTS[ingredient_name].tags.any(func(tag):return prop.harvest_tags().has(tag)):candidates.append(ingredient_name)
	return GameData.roll_ingredient(level,candidates) if not candidates.is_empty() else GameData.roll_ingredient(level)

func grant_prop_bundle(prop,bundle_range:Vector2i)->void:
	var use_range:Vector2i=RICH_YIELD if prop.rich else bundle_range
	var ingredient:=prop_ingredient(prop);var amount:=randi_range(use_range.x,use_range.y);loot[ingredient]+=amount
	reward_acquired.emit({"kind":"ingredient","name":ingredient,"amount":amount},prop.global_position)

# Harvesting: a living team member within HARVEST_RADIUS of a harvestable prop
# fills its progress; progress drains when nobody is near. A full harvest gives
# HARVEST_BUNDLES big bundles, more than a berry patch, then the prop goes.
func update_harvesting(living:Array,delta:float)->void:
	for prop in props.duplicate():
		if not prop.harvestable():continue
		var near:bool=living.any(func(member):return member.horizontal_distance(member.position,prop.position)<=prop.HARVEST_RADIUS)
		if near:
			prop.harvest_progress+=delta;prop.set_process(true)
			if prop.harvest_progress>=prop.HARVEST_SECONDS:
				for bundle in HARVEST_BUNDLES:grant_prop_bundle(prop,HARVEST_BUNDLE_RANGE)
				event_message.emit("Harvested the %s!"%prop.kind.replace("_"," "))
				prop.harvest()
		elif prop.harvest_progress>0.0:prop.harvest_progress=maxf(0.0,prop.harvest_progress-delta*.6)

# Whether a prop bears fruit, and rarely whether it is a rich plant, by level type.
func assign_prop_harvest(prop,rng:RandomNumberGenerator)->void:
	var grove:=is_grove()
	prop.bears_fruit=rng.randf()<(GROVE_HARVEST_CHANCE if grove else REGULAR_HARVEST_CHANCE)
	if prop.bears_fruit and rng.randf()<(GROVE_RICH_CHANCE if grove else REGULAR_RICH_CHANCE):
		prop.rich=true;prop.scale*=1.35

func place_props(rng:RandomNumberGenerator)->void:
	var area_scale:=float(field_rect.size.x*field_rect.size.y)/(30.0*22.0)
	var grove:=is_grove()
	# Groves are lush: denser, leafy plantings; regular levels keep the island's decor.
	var density:=maxf(float(biome.density),.65) if grove else float(biome.density)
	var target:=roundi((6.0+14.0*density)*area_scale)*(2 if grove else 1);var kinds:Array=GROVE_PROP_KINDS if grove else prop_kinds()
	var candidates:Array[Vector2i]=[]
	for cell in walkable:
		var point:=Vector2(cell)
		if bridge_approaches.has(cell) or not cell_open(cell) or route_distance(point)<1.6 or wall_tiers.has(cell):continue
		if zones.any(func(zone):return Vector2(zone.center).distance_to(point)<3.5):continue
		if bridges.keys().any(func(bridge):return Vector2(bridge).distance_to(point)<2.0):continue
		candidates.append(cell)
	shuffle_cells(candidates,rng)
	for cell in candidates:
		if props.size()>=target:break
		if prop_cells.keys().any(func(other):return Vector2(other).distance_to(Vector2(cell))<PROP_SPACING):continue
		walkable.erase(cell)
		if not neighbours_connected_locally(cell) and not zones_connected():walkable[cell]=true;continue
		var prop=PROP_SCRIPT.new();prop.setup(kinds[rng.randi_range(0,kinds.size()-1)],cell,biome,stage_level,rng)
		assign_prop_harvest(prop,rng)
		prop.destroyed.connect(_on_prop_destroyed);props_root.add_child(prop);props.append(prop);prop_cells[cell]=prop

# If all remaining neighbours connect around the removed cell, removing it
# cannot split its land region. Only tight bottlenecks need a full-map search.
func neighbours_connected_locally(cell:Vector2i)->bool:
	var neighbours:Array[Vector2i]=[]
	for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if walkable.has(cell+offset):neighbours.append(cell+offset)
	if neighbours.size()<2:return true
	var seen:={neighbours[0]:true};var queue:Array[Vector2i]=[neighbours[0]];var head:=0
	while head<queue.size():
		var here:=queue[head];head+=1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:Vector2i=here+offset;var relative:=next-cell
			if next==cell or absi(relative.x)>1 or absi(relative.y)>1 or seen.has(next) or not walkable.has(next):continue
			seen[next]=true;queue.append(next)
	return neighbours.all(func(neighbour):return seen.has(neighbour))

func _on_prop_destroyed(prop)->void:
	prop_cells.erase(prop.cell);props.erase(prop);walkable[prop.cell]=true
	# Rebuild the obstacle runs in place so every actor's reference stays valid.
	obstacles.clear();build_obstacles()
	if prop.harvested:return
	# Broken by a move: a fruit-bearing prop still drops a small bundle; plain
	# scenery gives nothing.
	if prop.bears_fruit and prop.HARVEST_TAGS.has(prop.kind) and not ended:grant_prop_bundle(prop,BREAK_BUNDLE_RANGE)
	event_message.emit("The %s breaks apart!"%prop.kind.replace("_"," "))

func props_in(center:Vector3,size:float)->Array:
	var result:Array=[]
	for prop in props:
		if not prop.shattered and Vector2(prop.position.x,prop.position.z).distance_to(Vector2(center.x,center.z))<=size+.6:result.append(prop)
	return result

func reachable_walkable_cells()->Dictionary:
	var start:=cell_of(zones[0].center);var seen:={start:true};var frontier:Array[Vector2i]=[start];var head:=0
	while head<frontier.size():
		var cell:Vector2i=frontier[head];head+=1
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next:Vector2i=cell+offset
			if walkable.has(next) and not seen.has(next):seen[next]=true;frontier.append(next)
	return seen

func zones_connected()->bool:
	var seen:=reachable_walkable_cells()
	return zones.all(func(zone):return seen.has(cell_of(zone.center)))

func zone_index_at(point:Vector2)->int:
	for i in zones.size():
		var zone:Dictionary=zones[i];var center:Vector2=zone.center;var radius:Vector2=zone.radius
		var local:=(point-center)/radius
		if local.length()<=1.0+.1*sin(atan2(local.y,local.x)*3.0+float(zone.phase)):return i
	return -1

func route_distance(point:Vector2)->float:
	var best:=INF
	# Each group samples one straight segment; its endpoints give exactly the
	# same distance without testing all twelve collinear pieces per vertex.
	for i in range(0,route_points.size(),ROUTE_SAMPLES):
		var end:=mini(i+ROUTE_SAMPLES-1,route_points.size()-1)
		best=minf(best,point.distance_to(Geometry2D.get_closest_point_to_segment(point,route_points[i],route_points[end])))
	return best

func carve_walkable()->void:
	# The whole field is open ground; only the cliff ring outside it is solid.
	var grid_min:=Vector2i(field_rect.position.x-16,field_rect.position.y-16);var grid_max:=Vector2i(field_rect.end.x-1+16,field_rect.end.y-1+16)
	for x in range(field_rect.position.x,field_rect.end.x):
		for z in range(field_rect.position.y,field_rect.end.y):walkable[Vector2i(x,z)]=true
	set_meta("grid_min",grid_min);set_meta("grid_max",grid_max)

var flight_obstacles:Array[Rect2]=[]

func build_obstacles()->void:
	var min_cell:=Vector2i(1<<30,1<<30);var max_cell:=Vector2i(-(1<<30),-(1<<30))
	for cell in walkable:min_cell=Vector2i(mini(min_cell.x,cell.x),mini(min_cell.y,cell.y));max_cell=Vector2i(maxi(max_cell.x,cell.x),maxi(max_cell.y,cell.y))
	arena_rect=Rect2(min_cell.x-.5,min_cell.y-.5,max_cell.x-min_cell.x+1.0,max_cell.y-min_cell.y+1.0)
	flight_obstacles.clear()
	# Blocked cells become row runs so the actors' obstacle checks stay cheap.
	for z in range(min_cell.y-1,max_cell.y+2):
		var run_start:=min_cell.x-1
		for x in range(min_cell.x-1,max_cell.x+3):
			var blocked:=x<=max_cell.x+1 and not walkable.has(Vector2i(x,z))
			if blocked:continue
			if x>run_start:obstacles.append(Rect2(run_start-.5,z-.5,x-run_start,1.0))
			run_start=x+1
	for z in range(min_cell.y-1,max_cell.y+2):
		var run_start:=min_cell.x-1
		for x in range(min_cell.x-1,max_cell.x+3):
			var cell:=Vector2i(x,z)
			if x<=max_cell.x+1 and not navigation_cell_open(cell,true):continue
			if x>run_start:flight_obstacles.append(Rect2(run_start-.5,z-.5,x-run_start,1.0))
			run_start=x+1

# --- Smooth terrain ------------------------------------------------------------
# The world is no longer drawn as tiles. The gameplay grid (walkable cells,
# rivers, walls) still decides where Quiblets can go, but the ground is one
# continuous heightfield: open ground is a flat plain, blocked cells rise into
# rounded hills whose height grows with the distance from the nearest open
# ground, and rivers sink into soft troughs. Nothing in the mesh follows a cell edge.
# Three samples per cell: the ground is a smoothly shaded rolling sheet.
const TERRAIN_SUBDIV:=3
# Broad rolling swells on the open ground (fighters ride the surface, so slopes are fine).
const PLAIN_ROLL:=.8
# Hills spread out: their lower slopes skirt this far into the open ground around
# them, starting at this share of the hill's height, so a wall reads as a broad
# hill rather than a mound sitting on a flat floor.
const HILL_SKIRT_RADIUS:=3.5
const HILL_SKIRT_SHARE:=.45
# A hill climbs over this run at most; thinner walls become lower, rounder bumps
# (their height is capped by their half-thickness) so slopes stay gentle.
const HILL_RAMP:=3.2
const HILL_MIN_HALF:=.55
const HILL_THICKNESS_GAIN:=1.6
const HILL_THICKNESS_BASE:=.6
const RIVER_RAMP:=1.4
const POND_DEPTH:=.45
const HILL_ROLL:=.22
# Hill heights per wall tier, in units (outer rings and thick walls stand taller).
const CLIFF_TIER_LAYERS:=[2,3,3]
var terrain_heights:={}
var pond_cells:={}
var ground_tile_count:=0
var height_field:PackedFloat32Array=PackedFloat32Array()
var terrain_classes:PackedByteArray=PackedByteArray()
var water_edge_field:PackedFloat32Array=PackedFloat32Array()
var hill_edge_field:PackedFloat32Array=PackedFloat32Array()
var height_origin:=Vector2.ZERO
var height_cols:=0
var height_rows:=0
var terrain_mesh:MeshInstance3D
var terrain_material:ShaderMaterial

func build_terrain(rng:RandomNumberGenerator)->void:
	var grid_min:Vector2i=get_meta("grid_min");var grid_max:Vector2i=get_meta("grid_max")
	# Multi-source flood distance from the open ground decides each wall cell's tier.
	var distance:={};var frontier:Array[Vector2i]=[]
	for cell in walkable:distance[cell]=0;frontier.append(cell)
	var head:=0
	while head<frontier.size():
		var cell:Vector2i=frontier[head];head+=1;var next:int=int(distance[cell])+1
		if next>4:continue
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var neighbour:Vector2i=cell+offset
			if neighbour.x<grid_min.x or neighbour.x>grid_max.x or neighbour.y<grid_min.y or neighbour.y>grid_max.y or distance.has(neighbour):continue
			distance[neighbour]=next;frontier.append(neighbour)
	# Classify every cell: plain (0), water (its depth), or hill (its peak height).
	terrain_heights.clear();pond_cells.clear();var peaks:={};var tiers:={};ground_tile_count=0
	for x in range(grid_min.x,grid_max.x+1):
		for z in range(grid_min.y,grid_max.y+1):
			var cell:=Vector2i(x,z)
			# Cells under an arched bridge stay part of the channel: the deck carries the walker.
			if spanned_cells.has(cell):terrain_heights[cell]=-RIVER_DEPTH;continue
			if walkable.has(cell) or prop_cells.has(cell):
				if wall_tiers.has(cell):
					cliff_tiers[int(wall_tiers[cell])]=int(cliff_tiers.get(int(wall_tiers[cell]),0))+1;tiers[cell]=int(wall_tiers[cell]);peaks[cell]=float(CLIFF_TIER_LAYERS[int(wall_tiers[cell])-1]);ground_tile_count+=1;continue
				terrain_heights[cell]=0.0;ground_tile_count+=1;continue
			if rivers.has(cell):terrain_heights[cell]=-RIVER_DEPTH;continue
			var tier:=int(wall_tiers[cell]) if wall_tiers.has(cell) else clampi(int(distance.get(cell,4)),1,3)
			if biome.water and tier==1 and not wall_tiers.has(cell) and rng.randf()<.4:pond_cells[cell]=true;terrain_heights[cell]=-POND_DEPTH;continue
			cliff_tiers[tier]=int(cliff_tiers.get(tier,0))+1;tiers[cell]=tier;peaks[cell]=float(CLIFF_TIER_LAYERS[tier-1])
	cliff_layer_count=peaks.size()
	# Blend neighbouring peaks so tiers roll into each other instead of stepping.
	for pass_index in 2:
		var blended:={}
		for cell in peaks:
			var total:float=float(peaks[cell]);var count:=1
			for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if peaks.has(cell+offset):total+=float(peaks[cell+offset]);count+=1
			blended[cell]=total/float(count)
		peaks=blended
	for cell in peaks:terrain_heights[cell]=float(peaks[cell])
	# The fine sample grid: TERRAIN_SUBDIV samples per cell edge, from the grid's outer edge.
	var subdiv:=TERRAIN_SUBDIV
	height_origin=Vector2(float(grid_min.x)-.5,float(grid_min.y)-.5)
	height_cols=(grid_max.x-grid_min.x+1)*subdiv+1;height_rows=(grid_max.y-grid_min.y+1)*subdiv+1
	var sample_count:=height_cols*height_rows;var step:=1.0/float(subdiv)
	# A sample takes its class from every cell it touches (a corner sample touches
	# four): open ground wins, then water, then hill. That keeps every open cell
	# perfectly flat and puts the ramps inside the hill and river cells instead.
	var classes:=PackedByteArray();classes.resize(sample_count);var sample_cells:Array=[];sample_cells.resize(sample_count)
	for r in height_rows:
		for c in height_cols:
			var point:=height_origin+Vector2(c,r)*step;var touching:Array=touching_cells(point,grid_min,grid_max)
			var kind:=2;var owner:Vector2i=touching[0]
			for cell in touching:
				var h:float=float(terrain_heights.get(cell,0.0))
				var cell_kind:int=0 if h==0.0 else (1 if h<0.0 else 2)
				if cell_kind<kind:kind=cell_kind;owner=cell
			classes[r*height_cols+c]=kind;sample_cells[r*height_cols+c]=owner
	# Distance from every water or hill sample to the nearest sample of another class.
	var water_edge:=edge_distance(classes,1,step);var hill_edge:=edge_distance(classes,2,step)
	terrain_classes=classes;water_edge_field=water_edge;hill_edge_field=hill_edge
	# Each hill sample's ridge distance: the greatest edge distance nearby, i.e. how
	# thick the hill is around it. Thin walls peak low and round; thick masses climb the full ramp.
	var ridge:=local_max(hill_edge,2*subdiv)
	# How far every open or water sample is from the nearest hill, and the tallest
	# hill peak nearby, for the skirts that spread each hill into its surroundings.
	var to_hill:=distance_to_class(classes,2,step)
	var peak_field:=PackedFloat32Array();peak_field.resize(sample_count)
	for r in height_rows:
		for c in height_cols:
			var i:=r*height_cols+c
			if classes[i]!=2:peak_field[i]=0.0;continue
			var half:float=maxf(HILL_MIN_HALF,float(ridge[i]))
			peak_field[i]=minf(peak_at(height_origin+Vector2(c,r)*step,sample_cells[i],peaks),HILL_THICKNESS_BASE+half*HILL_THICKNESS_GAIN)
	var nearby_peak:=local_max(peak_field,int(HILL_SKIRT_RADIUS*subdiv)+1)
	height_field.resize(sample_count)
	for r in height_rows:
		for c in height_cols:
			var index:=r*height_cols+c;var point:=height_origin+Vector2(c,r)*step
			# The cell the sample was classified by, never a rounded neighbour.
			var cell:Vector2i=sample_cells[index]
			var kind:int=classes[index];var h:=plain_roll(point)
			# The skirt: the nearest hill's lower slope, fading out over HILL_SKIRT_RADIUS.
			var skirt_top:float=float(nearby_peak[index])*HILL_SKIRT_SHARE
			if kind!=2:h+=skirt_top*(1.0-smoothstep(0.0,HILL_SKIRT_RADIUS,float(to_hill[index])))
			if kind==1 and waterfall_cells.has(cell):
				# The source channel is an open chute that slopes down from the border
				# hilltop into the field, so the water runs down the hillside rather
				# than dropping over a lip into a pit.
				h=waterfall_source_height(point)
			elif kind==1:
				var depth:float=-float(terrain_heights.get(cell,-RIVER_DEPTH))
				h-=depth*smoothstep(0.0,RIVER_RAMP,float(water_edge[index]))
			elif kind==2:
				var half:float=maxf(HILL_MIN_HALF,float(ridge[index]))
				var rise:=smoothstep(0.0,minf(HILL_RAMP,half),float(hill_edge[index]))
				var peak:float=peak_field[index];var base:float=peak*HILL_SKIRT_SHARE
				h+=base+(peak-base+HILL_ROLL*sin(point.x*.9+.3)*sin(point.y*.8+1.1)*minf(1.0,peak*.5))*rise
			if kind==2:
				var outside:=maxf(maxf(float(field_rect.position.x)-point.x,point.x-float(field_rect.end.x-1)),maxf(float(field_rect.position.y)-point.y,point.y-float(field_rect.end.y-1)))
				h+=smoothstep(1.0,14.0,outside)*5.5
			height_field[index]=h
	build_terrain_mesh(classes,water_edge,hill_edge,rng)
	# Details on the open grass, decor on the hills nearest the open ground.
	var detail_entries:Array[Dictionary]=[];var flower_colors:Array[Color]=[Color("#fff6d5"),Color("#ffe066"),Color("#ff9ec4"),Color("#ffffff")]
	for cell in walkable:
		if route_distance(Vector2(cell))>=2.1+sin(cell.x*.9+cell.y*.6)*.5:add_ground_detail(detail_entries,Vector2(cell),biome.ground,flower_colors,rng)
	if not detail_entries.is_empty():build_multimesh("TerrainDetails",BoxMesh.new(),detail_entries)
	for cell in peaks:
		var tier:int=int(tiers[cell])
		var rim:=[Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)].any(func(offset):return walkable.has(cell+offset))
		if rim and (tier==1 or wall_tiers.has(cell)) and decor_count<MAX_DECOR and rng.randf()<float(biome.density):add_hill_prop(cell,rng)
	build_rivers(rng)

# Broad swells of the open ground: a few overlapping long sine waves.
func plain_roll(point:Vector2)->float:
	return PLAIN_ROLL*(.6*sin(point.x*.17+1.3)*cos(point.y*.15)+.3*sin(point.x*.37+.5)*sin(point.y*.31)+.1*sin(point.x*.8)*cos(point.y*.7+1.0))

# Distance from every sample to the nearest sample of `target` class (0 on that class).
func distance_to_class(classes:PackedByteArray,target:int,step:float)->PackedFloat32Array:
	var flipped:=PackedByteArray();flipped.resize(classes.size())
	for i in classes.size():flipped[i]=9 if classes[i]!=target else target
	return edge_distance(flipped,9,step)

# The cells whose area contains the point: one inside a cell, two on an edge, four on a corner.
func touching_cells(point:Vector2,grid_min:Vector2i,grid_max:Vector2i)->Array:
	var xs:Array=[];var zs:Array=[]
	var fx:=point.x+.5;var fz:=point.y+.5
	var bx:=floori(fx+.0001);var bz:=floori(fz+.0001)
	if absf(fx-roundf(fx))<.001:xs=[bx-1,bx]
	else:xs=[bx]
	if absf(fz-roundf(fz))<.001:zs=[bz-1,bz]
	else:zs=[bz]
	var cells:Array=[]
	for x in xs:
		for z in zs:cells.append(Vector2i(clampi(x,grid_min.x,grid_max.x),clampi(z,grid_min.y,grid_max.y)))
	return cells

# Peak height for a point on the hills: bilinear across the four surrounding
# cell centres, each falling back to the point's own cell where no hill is.
func peak_at(point:Vector2,own:Vector2i,peaks:Dictionary)->float:
	var own_peak:float=float(peaks.get(own,float(CLIFF_TIER_LAYERS[0])))
	var fx:=point.x-float(own.x)+.5;var fz:=point.y-float(own.y)+.5
	var base:=Vector2i(own.x-1 if fx<.5 else own.x,own.y-1 if fz<.5 else own.y)
	var tx:=fx-.5 if fx>=.5 else fx+.5;var tz:=fz-.5 if fz>=.5 else fz+.5
	var p00:float=float(peaks.get(base,own_peak));var p10:float=float(peaks.get(base+Vector2i(1,0),own_peak))
	var p01:float=float(peaks.get(base+Vector2i(0,1),own_peak));var p11:float=float(peaks.get(base+Vector2i(1,1),own_peak))
	return lerpf(lerpf(p00,p10,tx),lerpf(p01,p11,tx),tz)

# Separable max filter over the sample grid with the given half window (in samples).
func local_max(values:PackedFloat32Array,window:int)->PackedFloat32Array:
	var pass_x:=PackedFloat32Array();pass_x.resize(values.size())
	for r in height_rows:
		for c in height_cols:
			var best:=0.0
			for k in range(maxi(0,c-window),mini(height_cols-1,c+window)+1):best=maxf(best,values[r*height_cols+k])
			pass_x[r*height_cols+c]=best
	var result:=PackedFloat32Array();result.resize(values.size())
	for r in height_rows:
		for c in height_cols:
			var best:=0.0
			for k in range(maxi(0,r-window),mini(height_rows-1,r+window)+1):best=maxf(best,pass_x[k*height_cols+c])
			result[r*height_cols+c]=best
	return result

# Chamfer distance transform: for samples of `kind`, the distance (in world
# units) to the nearest sample of any other class; other samples read 0.
func edge_distance(classes:PackedByteArray,kind:int,step:float)->PackedFloat32Array:
	var result:=PackedFloat32Array();result.resize(classes.size())
	var far:=1.0e9;var diagonal:=sqrt(2.0)
	for i in classes.size():result[i]=far if classes[i]==kind else 0.0
	for r in height_rows:
		for c in height_cols:
			var i:=r*height_cols+c
			if result[i]==0.0:continue
			var best:float=result[i]
			if c>0:best=minf(best,result[i-1]+1.0)
			if r>0:
				best=minf(best,result[i-height_cols]+1.0)
				if c>0:best=minf(best,result[i-height_cols-1]+diagonal)
				if c<height_cols-1:best=minf(best,result[i-height_cols+1]+diagonal)
			result[i]=best
	for r in range(height_rows-1,-1,-1):
		for c in range(height_cols-1,-1,-1):
			var i:=r*height_cols+c
			if result[i]==0.0:continue
			var best:float=result[i]
			if c<height_cols-1:best=minf(best,result[i+1]+1.0)
			if r<height_rows-1:
				best=minf(best,result[i+height_cols]+1.0)
				if c<height_cols-1:best=minf(best,result[i+height_cols+1]+diagonal)
				if c>0:best=minf(best,result[i+height_cols-1]+diagonal)
			result[i]=best
	for i in result.size():result[i]=(result[i] if result[i]<far else 0.0)*step
	return result

# Height a walker stands at: the ground, or a bridge deck where one spans the point.
func terrain_height_at(point:Vector2)->float:
	return maxf(raw_height_at(point),deck_height_at(point))

# Height of the ground surface itself (bilinear over the sample grid).
func raw_height_at(point:Vector2)->float:
	if height_field.is_empty():return 0.0
	var local:=(point-height_origin)*float(TERRAIN_SUBDIV)
	var c0:=clampi(floori(local.x),0,height_cols-1);var r0:=clampi(floori(local.y),0,height_rows-1)
	var c1:=mini(c0+1,height_cols-1);var r1:=mini(r0+1,height_rows-1)
	var tx:=clampf(local.x-float(c0),0.0,1.0);var tz:=clampf(local.y-float(r0),0.0,1.0)
	var h00:float=height_field[r0*height_cols+c0];var h10:float=height_field[r0*height_cols+c1]
	var h01:float=height_field[r1*height_cols+c0];var h11:float=height_field[r1*height_cols+c1]
	return lerpf(lerpf(h00,h10,tx),lerpf(h01,h11,tx),tz)

func sample_height(c:int,r:int)->float:
	return height_field[clampi(r,0,height_rows-1)*height_cols+clampi(c,0,height_cols-1)]

# Ground colours come straight from the island's palette: the ground colour
# brightens with height, the path colour lines the troughs and darkens along the
# trail, a lightened cliff tone lies under the water, and the highest ground
# takes an accent-tinted plateau colour; a faint long-wave noise breaks it up.
func build_terrain_mesh(classes:PackedByteArray,water_edge:PackedFloat32Array,_hill_edge:PackedFloat32Array,_rng:RandomNumberGenerator)->void:
	# Smoothly shaded: vertices are shared and normals come from the neighbouring samples.
	# Every island keeps exactly its own colours: sand is sand, cave rock is rock,
	# night ground is purple; nothing is pulled toward the meadow's greens.
	var tint:Color=biome.ground;var grass_low:Color=tint;var grass_high:Color=tint.lightened(.3)
	var sand:Color=Color(biome.path);var bed:Color=Color(biome.cliff).lightened(.35);var dirt:Color=Color(biome.path).darkened(.12);var plateau:Color=Color(biome.accent).lerp(tint.lightened(.15),.6)
	var step:=1.0/float(TERRAIN_SUBDIV);var water_top:=WATER_LEVEL
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in height_rows:
		for c in height_cols:
			var index:=r*height_cols+c;var point:=height_origin+Vector2(c,r)*step;var h:float=height_field[index]
			var dx:float=(sample_height(c+1,r)-sample_height(c-1,r))/(2.0*step);var dz:float=(sample_height(c,r+1)-sample_height(c,r-1))/(2.0*step)
			var normal:=Vector3(-dx,1.0,-dz).normalized()
			var color:Color
			if classes[index]==1 and h<water_top+.35:color=bed
			elif classes[index]==1 and float(water_edge[index])>0.0:color=sand
			else:
				color=grass_low.lerp(grass_high,clampf((h+1.0)/6.0,0.0,1.0))
				if h>2.4:color=color.lerp(plateau,.5)
				var trail:float=route_distance(point)
				if trail<2.6 and classes[index]==0:color=color.lerp(dirt,smoothstep(0.0,1.0,(2.6-trail)/1.6))
			var noise:float=.975+.045*sin(point.x*.83+.4)*cos(point.y*.71)
			color=Color(color.r*noise,color.g*noise,color.b*noise)
			st.set_normal(normal);st.set_color(color);st.add_vertex(Vector3(point.x,h,point.y))
	for r in height_rows-1:
		for c in height_cols-1:
			var i00:=r*height_cols+c;var i10:=i00+1;var i01:=i00+height_cols;var i11:=i01+1
			# Godot front faces wind so the geometric normal points away from the viewer's side (down, here).
			for index in [i00,i10,i01,i10,i11,i01]:st.add_index(index)
	var mesh:=st.commit()
	terrain_material=ShaderMaterial.new();terrain_material.shader=terrain_shader()
	terrain_fade_material=ShaderMaterial.new();terrain_fade_material.shader=terrain_fade_shader();terrain_material.next_pass=terrain_fade_material
	for material in terrain_materials():material.set_shader_parameter("fade_count",0)
	terrain_mesh=MeshInstance3D.new();terrain_mesh.name="TerrainMesh";terrain_mesh.mesh=mesh;terrain_mesh.material_override=terrain_material;add_child(terrain_mesh)
	build_distant_terrain()

# A coarse outer apron continues the detailed field into distant higher land.
# It shares the detailed mesh edge and palette and renders from either side.
func build_distant_terrain()->void:
	var rim:Array[Vector2]=[];var step:=1.0/float(TERRAIN_SUBDIV)
	for c in height_cols:rim.append(height_origin+Vector2(c,0)*step)
	for r in range(1,height_rows):rim.append(height_origin+Vector2(height_cols-1,r)*step)
	for c in range(height_cols-2,-1,-1):rim.append(height_origin+Vector2(c,height_rows-1)*step)
	for r in range(height_rows-2,0,-1):rim.append(height_origin+Vector2(0,r)*step)
	var center:=height_origin+Vector2(height_cols-1,height_rows-1)*step*.5
	var half:=Vector2(height_cols-1,height_rows-1)*step*.5
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rim.size():
		for ring in 4:
			var vertices:Array[Vector3]=[]
			for corner in [Vector2i(i,ring),Vector2i((i+1)%rim.size(),ring),Vector2i(i,ring+1),Vector2i((i+1)%rim.size(),ring+1)]:
				var edge:Vector2=rim[corner.x];var amount:=float(corner.y)/4.0
				var point:=center+(edge-center)*(Vector2.ONE+Vector2(80.0,80.0)/half*amount)
				var h:=raw_height_at(edge)+amount*10.0+sin(point.x*.15)*cos(point.y*.12)*amount*2.0
				vertices.append(Vector3(point.x,h,point.y))
			for index in [0,1,2,1,3,2]:
				var v:Vector3=vertices[index];st.set_color(terrain_surface_color(Vector2(v.x,v.z),v.y));st.add_vertex(v)
	st.index();st.generate_normals()
	var distant:=MeshInstance3D.new();distant.name="DistantTerrain";distant.mesh=st.commit();var distant_material:=ShaderMaterial.new();var distant_shader:=Shader.new();distant_shader.code=TERRAIN_SHADER.replace("cull_back","cull_disabled");distant_material.shader=distant_shader;distant.material_override=distant_material;add_child(distant)

# --- Terrain shader and occlusion fading ----------------------------------------
# Vertex colours carry the biome palette (authored in sRGB) modulated by a tiny
# tiling detail texture. Any ground standing between the camera and a Quiblet
# or enemy fades to WALL_FADE_ALPHA around the line of sight: the CPU marches
# each fighter's line to the camera through the heightfield and ramps a
# per-fighter weight smoothly. The terrain draws in two passes so the water in
# the troughs is never overdrawn: the opaque pass cuts a hole wherever the
# ground lies on a faded line, and a transparent next pass fills that hole at
# the faded alpha, easing back to solid at the hole's soft edge.
const WALL_FADE_ALPHA:=.2
# Fade the ground in front of a waterfall whenever it is within view range of the
# camera (it sits at the field edge, well beyond the team's centre, so this gates
# on the camera's own position, not the focus).
const WATERFALL_FADE_RANGE:=42.0
const WALL_FADE_SPEED:=5.0
const WALL_FADE_RADIUS:=1.4
const WALL_RAY_STEP:=.4
const MAX_FADE_POINTS:=16
var fade_weights:={}
var terrain_fade_material:ShaderMaterial
const TERRAIN_SHADER_COMMON:="""
uniform int fade_count=0;
uniform vec3 fade_points[16];
uniform float fade_weights[16];
uniform vec3 eye=vec3(0.0,10.0,10.0);
uniform float fade_radius=1.1;
uniform float fade_alpha=.2;
varying vec3 world_pos;
varying vec4 tint;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;tint=COLOR;}
float fade_factor(){
	float f=0.0;
	for(int i=0;i<fade_count;i++){
		vec3 a=fade_points[i];vec3 ab=eye-a;float t=clamp(dot(world_pos-a,ab)/max(dot(ab,ab),.0001),0.0,1.0);
		vec3 on_ray=a+ab*t;float d=length(world_pos-on_ray);
		float above=step(on_ray.y-.35,world_pos.y)*step(.03,t);
		f=max(f,(1.0-smoothstep(fade_radius*.55,fade_radius,d))*fade_weights[i]*above);
	}
	return f;
}
"""
const TERRAIN_SHADER:="""
shader_type spatial;
render_mode cull_back;
"""+TERRAIN_SHADER_COMMON+"""
void fragment(){
	if(fade_factor()>.02)discard;
	ALBEDO=pow(tint.rgb,vec3(2.2));ROUGHNESS=1.0;SPECULAR=0.0;
}
"""
const TERRAIN_FADE_SHADER:="""
shader_type spatial;
render_mode cull_back,blend_mix,depth_draw_never;
"""+TERRAIN_SHADER_COMMON+"""
void fragment(){
	float f=fade_factor();
	if(f<=.02)discard;
	ALBEDO=pow(tint.rgb,vec3(2.2));ROUGHNESS=1.0;SPECULAR=0.0;ALPHA=1.0-f*(1.0-fade_alpha);
}
"""
static var terrain_shader_resource:Shader
static var terrain_fade_shader_resource:Shader
func terrain_shader()->Shader:
	if terrain_shader_resource==null:terrain_shader_resource=Shader.new();terrain_shader_resource.code=TERRAIN_SHADER
	return terrain_shader_resource

func terrain_fade_shader()->Shader:
	if terrain_fade_shader_resource==null:terrain_fade_shader_resource=Shader.new();terrain_fade_shader_resource.code=TERRAIN_FADE_SHADER
	return terrain_fade_shader_resource

func terrain_materials()->Array:
	return [terrain_material,terrain_fade_material].filter(func(material):return material!=null)

# True when the ground rises through the line from the fighter up to the camera.
func occluded_by_terrain(actor:QuibletActor3D)->bool:
	return point_occluded_by_terrain(actor.global_position+Vector3(0,.5,0))

# True when the ground rises through the line from a world point up to the camera.
func point_occluded_by_terrain(from:Vector3)->bool:
	if not is_instance_valid(camera) or height_field.is_empty():return false
	var eye:Vector3=camera.global_position
	var steps:=maxi(1,ceili(from.distance_to(eye)/WALL_RAY_STEP))
	for i in range(1,steps+1):
		var p:Vector3=from.lerp(eye,float(i)/float(steps))
		if p.y>4.5:break
		if terrain_height_at(Vector2(p.x,p.z))>p.y+.05:return true
	return false

func update_wall_fades(delta:float)->void:
	if terrain_material==null or not is_instance_valid(camera):return
	var points:=PackedVector3Array();var weights:=PackedFloat32Array();var seen:={}
	for actor in team+enemies:
		if not is_instance_valid(actor):continue
		var id:int=actor.get_instance_id();seen[id]=true
		var target:float=1.0 if actor.current_hp>0 and occluded_by_terrain(actor) else 0.0
		var weight:float=move_toward(float(fade_weights.get(id,0.0)),target,WALL_FADE_SPEED*delta)
		if weight<=0.0:fade_weights.erase(id);continue
		fade_weights[id]=weight
		if points.size()<MAX_FADE_POINTS:points.append(actor.global_position+Vector3(0,.5,0));weights.append(weight)
	# Keep a nearby waterfall's foot (and mid-sheet) visible: while the camera is
	# looking near it, fade any hill that stands between it and the camera, the same
	# way fighters behind walls are revealed. Far-off waterfalls are left alone.
	for i in waterfalls.size():
		var foot:Vector3=waterfalls[i].get("foot",Vector3.ZERO)
		var near:bool=Vector2(foot.x,foot.z).distance_to(Vector2(camera.global_position.x,camera.global_position.z))<=WATERFALL_FADE_RANGE
		for j in 2:
			var pt:Vector3=foot+Vector3.UP*(float(j)*(WATERFALL_TOP-WATER_LEVEL)*.5)
			var id:int=-(i*2+j+1);seen[id]=true
			var target:float=1.0 if (near and point_occluded_by_terrain(pt)) else 0.0
			var weight:float=move_toward(float(fade_weights.get(id,0.0)),target,WALL_FADE_SPEED*delta)
			if weight<=0.0:fade_weights.erase(id);continue
			fade_weights[id]=weight
			if points.size()<MAX_FADE_POINTS:points.append(pt);weights.append(weight)
	for id in fade_weights.keys():
		if not seen.has(id):fade_weights.erase(id)
	var count:=points.size()
	while points.size()<MAX_FADE_POINTS:points.append(Vector3.ZERO);weights.append(0.0)
	for material in terrain_materials():
		material.set_shader_parameter("fade_count",count);material.set_shader_parameter("fade_points",points);material.set_shader_parameter("fade_weights",weights)
		material.set_shader_parameter("eye",camera.global_position);material.set_shader_parameter("fade_radius",WALL_FADE_RADIUS);material.set_shader_parameter("fade_alpha",WALL_FADE_ALPHA)

# Fighters currently fading the ground in front of them.
func fading_wall_count()->int:
	return fade_weights.size()

# Ground details in the reference style: little cross-shaped tufts of darker
# grass and tiny pixel flowers (a centre dot, four petals, two leaves).
func add_ground_detail(entries:Array[Dictionary],point:Vector2,ground:Color,flower_colors:Array[Color],rng:RandomNumberGenerator)->void:
	var roll:=rng.randf()
	var origin:=Vector3(point.x+rng.randf_range(-.32,.32),0,point.y+rng.randf_range(-.32,.32))
	if roll<.07:
		var tuft:Color=ground.darkened(.16)
		for offset in [Vector3.ZERO,Vector3(.1,0,0),Vector3(-.1,0,0),Vector3(0,0,.1),Vector3(0,0,-.1)]:
			entries.append({"transform":Transform3D(Basis.IDENTITY.scaled(Vector3(.09,.03,.09)),origin+offset+Vector3(0,.015,0)),"color":tuft})
	elif roll<.105:
		var petal:Color=flower_colors[rng.randi_range(0,flower_colors.size()-1)];var center:Color=Color("#ffd94a") if petal!=Color("#ffe066") else Color("#fff8e0")
		for offset in [Vector3(.1,0,0),Vector3(-.1,0,0),Vector3(0,0,.1),Vector3(0,0,-.1)]:
			entries.append({"transform":Transform3D(Basis.IDENTITY.scaled(Vector3(.09,.03,.09)),origin+offset+Vector3(0,.02,0)),"color":petal})
		entries.append({"transform":Transform3D(Basis.IDENTITY.scaled(Vector3(.08,.04,.08)),origin+Vector3(0,.025,0)),"color":center})
		for offset in [Vector3(.16,0,.12),Vector3(-.15,0,-.13)]:
			entries.append({"transform":Transform3D(Basis.IDENTITY.scaled(Vector3(.1,.02,.06)),origin+offset+Vector3(0,.012,0)),"color":ground.darkened(.22)})

# Flowing water: crests scroll along each river's flow direction (carried per
# tile in the instance custom data) and the surface bobs gently. Ripple slivers
# use the same shader so they drift downstream and wrap within their tile.
# Water is one smooth translucent sheet per level. Each vertex carries its flow
# direction (COLOR.rgb, encoded), a phase (COLOR.a, one value per sheet so the
# crests never break at a cell edge), and how deep the
# water is below it (UV2.x), so crests scroll downstream, the surface bobs and
# glints in the sun, and pale foam gathers along the shallow banks. The same
# shader drives the falling sheets of waterfalls with a downward flow.
const WATER_SHADER:="""
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 tint:source_color=vec4(.5,.84,.97,.82);
uniform float flow_speed=1.2;
uniform float crest_scale=1.3;
uniform float shore_foam=.55;
uniform bool surface_flow=false;
varying vec3 world_pos;
varying vec3 flow_dir;
varying float phase;
varying float depth;
void vertex(){
	flow_dir=normalize(COLOR.rgb*2.0-1.0);phase=COLOR.a;depth=UV2.x;
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float bob=sin(world_pos.x*1.3+world_pos.z*1.1+TIME*1.6+phase*6.283)*.03*(1.0-abs(flow_dir.y));
	VERTEX+=inverse(mat3(MODEL_MATRIX))*vec3(0.0,bob,0.0);
}
void fragment(){
	vec3 side=normalize(cross(flow_dir,abs(flow_dir.y)>.5?vec3(1.0,0.0,0.0):vec3(0.0,1.0,0.0)));
	// Curved cascades use continuous surface coordinates, so changing slope
	// cannot stretch the river wave pattern into abrupt bands.
	float along=surface_flow?UV.y:dot(world_pos,flow_dir);
	float across=surface_flow?UV.x:dot(world_pos,side);float t=TIME*flow_speed;
	float wave=sin(along*crest_scale*3.14159-t*3.0+phase*6.283+sin(across*1.7)*.8);
	float second=sin(along*crest_scale*7.1+across*2.3-t*4.7+phase*3.0);
	float crest=smoothstep(.6,.95,wave)*.6+smoothstep(.75,1.0,second)*.4;
	float shallow=1.0-smoothstep(0.0,.5,depth);
	float foam=shallow*(.5+.5*sin(along*4.0-t*2.5+across*3.0))*shore_foam;
	vec3 color=mix(tint.rgb,tint.rgb*.72,depth*.45);
	color=mix(color,vec3(1.0),clamp(crest*.35+foam,0.0,1.0));
	ALBEDO=color;ALPHA=clamp(tint.a-depth*.05+foam*.2,0.0,1.0);
	ROUGHNESS=.12;METALLIC=.05;SPECULAR=.7;
	vec3 bump=flow_dir*cos(along*crest_scale*3.14159-t*3.0)*.12+side*sin(across*2.3-t*1.3)*.06;
	NORMAL=normalize(NORMAL+(VIEW_MATRIX*vec4(bump,0.0)).xyz);
	EMISSION=tint.rgb*.1+vec3(.2)*crest*.5;
}
"""
static var water_shader_resource:Shader
func water_shader()->Shader:
	if water_shader_resource==null:water_shader_resource=Shader.new();water_shader_resource.code=WATER_SHADER
	return water_shader_resource

func water_material()->ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=water_shader()
	var water:Color=biome.water_color;material.set_shader_parameter("tint",Color(water.r,water.g,water.b,.82))
	return material

# Encode a flow direction and a phase into a vertex colour for the water shader.
func water_vertex_color(flow:Vector3,phase:float)->Color:
	var f:=flow.normalized()*.5+Vector3(.5,.5,.5);return Color(f.x,f.y,f.z,phase)

# One quad of a water sheet, TERRAIN_SUBDIV × TERRAIN_SUBDIV small quads per
# cell so the shore depth fades smoothly along the banks.
func add_water_cell(st:SurfaceTool,cell:Vector2i,level:float,flow:Vector2,phase:float)->void:
	var color:=water_vertex_color(Vector3(flow.x,0,flow.y),phase);var subdiv:=TERRAIN_SUBDIV;var step:=1.0/float(subdiv)
	for i in subdiv:
		for j in subdiv:
			var corners:Array=[]
			for corner in [Vector2(i,j),Vector2(i+1,j),Vector2(i,j+1),Vector2(i+1,j+1)]:
				var point:Vector2=Vector2(float(cell.x)-.5,float(cell.y)-.5)+corner*step
				var depth:float=clampf((level-raw_height_at(point))/1.1,0.0,1.0)
				corners.append({"pos":Vector3(point.x,level,point.y),"depth":depth,"uv":point})
			for tri in [[0,1,2],[1,3,2]]:
				for k in tri:
					var v:Dictionary=corners[k]
					st.set_normal(Vector3.UP);st.set_color(color);st.set_uv(v.uv);st.set_uv2(Vector2(float(v.depth),0));st.add_vertex(v.pos)

const RIVER_DEPTH:=1.3
# Waterfalls: a river may begin in the border hills and drop over the field's edge.
const WATERFALL_CHANCE:=.5
const WATERFALL_REACH:=4
const WATERFALL_TOP:=3.1
var waterfall_cells:={}
var waterfalls:Array=[]
# Recorded crossings: each is {cells:Array[Vector2i], flow:Vector2}. One arch is
# built per crossing so its deck spans that river with the right orientation.
var river_crossings:Array=[]
# Soft foam patches drift downstream from the foot and dissolve.
var waterfall_bubbles:Array=[]
func build_rivers(rng:RandomNumberGenerator)->void:
	if rivers.is_empty() and pond_cells.is_empty() and spanned_cells.is_empty():return
	# One smooth sheet: rivers at their level, source channels up in the hills,
	# ponds shallower, and the water running on under every bridge.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in rivers.keys()+pond_cells.keys()+spanned_cells.keys():
		if waterfall_cells.has(cell):continue
		var level:float=WATER_LEVEL if (rivers.has(cell) or spanned_cells.has(cell)) else (-POND_DEPTH+.22)
		add_water_cell(st,cell,level,river_flow.get(cell,Vector2(0,1)),0.0)
	var water_node:=MeshInstance3D.new();water_node.name="RiverWater";water_node.mesh=st.commit();water_node.material_override=water_material();add_child(water_node)

# --- Bridges -------------------------------------------------------------------
# Each run of bridge cells is a crossing. The bridge is planned before the
# terrain is built: its axis is whichever direction lands both ends on dry
# ground (never in the water), and the cells it spans stay part of the channel
# so the river runs on underneath. The arched deck is what Quiblets walk on.
const BRIDGE_RISE:=.55
const BRIDGE_MAX_HALF_WIDTH:=1.6
# River water sits this high in the trough (the trough floor is RIVER_DEPTH down).
const WATER_LEVEL:=-RIVER_DEPTH+.55
var bridge_arches:Array=[]
var spanned_cells:={}

# The deck's height over a point, or -INF where no bridge spans it.
# The deck's world height along its span (t: 0 at the start bank, 1 at the end):
# it meets each bank at that bank's ground height and arches to the higher bank
# plus BRIDGE_RISE at the middle, so it always clears the channel.
func bridge_deck_y(t:float,start_h:float,end_h:float)->float:
	var line:float=lerpf(start_h,end_h,smoothstep(0.0,1.0,t))
	return line+(maxf(start_h,end_h)-line+BRIDGE_RISE)*pow(sin(PI*t),2.0)

func bridge_half_width(arch:Dictionary,t:float)->float:
	# Broad shoulders blend into the banks, with a narrower centre over water.
	return float(arch.half_width)+.35*pow(absf(2.0*t-1.0),2.0)

func bridge_surface_y(arch:Dictionary,t:float,across:float)->float:
	var axis:Vector2=arch.axis;var side:=Vector2(-axis.y,axis.x);var center:Vector2=arch.center
	var start_h:=raw_height_at(center-axis*float(arch.half_span)+side*across)
	var end_h:=raw_height_at(center+axis*float(arch.half_span)+side*across)
	var crown:=.10*pow(sin(PI*t),2.0)*(1.0-pow(clampf(across/bridge_half_width(arch,t),-1.0,1.0),2.0))
	return bridge_deck_y(t,start_h,end_h)+crown

func deck_height_at(point:Vector2)->float:
	var best:=-INF
	for arch in bridge_arches:
		var local:Vector2=point-arch.center;var along:float=local.dot(arch.axis);var across:float=local.dot(Vector2(-arch.axis.y,arch.axis.x))
		if absf(along)>float(arch.half_span)+.001:continue
		var t:float=clampf(along/float(arch.half_span)*.5+.5,0.0,1.0)
		if absf(across)>bridge_half_width(arch,t)+.001:continue
		best=maxf(best,bridge_surface_y(arch,t,across))
	return best

func bridge_lift(point:Vector2)->float:
	return maxf(0.0,deck_height_at(point)-raw_height_at(point))

func plan_bridges()->void:
	bridge_arches.clear();spanned_cells.clear()
	# One arch per recorded crossing: it spans that river across its own flow and
	# reaches onto the banks, and its cells stay part of the channel so the water
	# runs on underneath. Nothing is ever left as a dry, waterless gap.
	for crossing in river_crossings:
		var cells:Array=crossing.cells
		if cells.is_empty():continue
		var flow:Vector2=crossing.flow;if flow.length()<.01:flow=Vector2(0,1)
		var center:=Vector2.ZERO
		for cell in cells:center+=Vector2(cell)
		center/=cells.size()
		center=crossing.get("center",center)
		var axis:Vector2=Vector2(1,0) if absf(flow.y)>=absf(flow.x) else Vector2(0,1);var side:=Vector2(axis.y,axis.x)
		var half_span:=0.0;var half_width:=0.0
		for cell in cells:half_span=maxf(half_span,absf((Vector2(cell)-center).dot(axis)));half_width=maxf(half_width,absf((Vector2(cell)-center).dot(side)))
		half_span=float(crossing.get("half_span",half_span+1.25));half_width=float(crossing.get("half_width",maxf(half_width+.5,.9)))
		# Reach a little further so each end settles on the bank, capped short.
		for reach in 3:
			var grew:=false
			for end_sign in [-1.0,1.0]:
				if not walkable.has(cell_of(center+axis*end_sign*(half_span+1.0))):grew=true
			if not grew:break
			half_span+=1.0
		bridge_arches.append({"center":center,"axis":axis,"half_span":half_span,"half_width":half_width,"base":0.0})
		for cell in cells:spanned_cells[cell]=true
	# Any stray bridge cell without an arch still gets water under it (defensive).
	for cell in bridges:
		if not spanned_cells.has(cell):spanned_cells[cell]=true

# The exact ground colour the terrain mesh paints at a point and height, so the
# bridge deck (and anything else) can match the surrounding ground precisely.
func terrain_surface_color(point:Vector2,h:float)->Color:
	var tint:Color=biome.ground;var grass_low:Color=tint;var grass_high:Color=tint.lightened(.3)
	var dirt:Color=Color(biome.path).darkened(.12);var plateau:Color=Color(biome.accent).lerp(tint.lightened(.15),.6)
	var color:=grass_low.lerp(grass_high,clampf((h+1.0)/6.0,0.0,1.0))
	if h>2.4:color=color.lerp(plateau,.5)
	var trail:float=route_distance(point)
	if trail<2.6:color=color.lerp(dirt,smoothstep(0.0,1.0,(2.6-trail)/1.6))
	var noise:float=.975+.045*sin(point.x*.83+.4)*cos(point.y*.71)
	return Color(color.r*noise,color.g*noise,color.b*noise)

func build_bridges()->void:
	if bridge_arches.is_empty():return
	var bridge_root:=Node3D.new();bridge_root.name="Bridges";add_child(bridge_root)
	# Closed earthen arches: gently crowned tops, rounded shoulders and a solid
	# underside. Every top sample also drives the height used by walking actors.
	var section:Array[Vector2]=[Vector2(-1,0),Vector2(-.9,0),Vector2(-.65,0),Vector2(0,0),Vector2(.65,0),Vector2(.9,0),Vector2(1,0),Vector2(1,.22),Vector2(.94,.75),Vector2(.8,1),Vector2(-.8,1),Vector2(-.94,.75),Vector2(-1,.22)]
	for arch in bridge_arches:
		var center:Vector2=arch.center;var axis:Vector2=arch.axis;var half_span:float=arch.half_span;var side:=Vector2(-axis.y,axis.x)
		arch.start_h=raw_height_at(center-axis*half_span);arch.end_h=raw_height_at(center+axis*half_span);arch.base=maxf(arch.start_h,arch.end_h)
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var segments:=maxi(20,ceili(half_span*12.0));var rings:Array=[]
		for i in range(segments+1):
			var t:=float(i)/segments;var half_width:=bridge_half_width(arch,t)
			var thickness:=lerpf(.85,.38,pow(sin(PI*t),2.0));var ring:Array[Vector3]=[]
			for profile in section:
				var across:=profile.x*half_width;var point:=center+axis*((t-.5)*2.0*half_span)+side*across
				var top:=bridge_surface_y(arch,t,across);var height:=top-profile.y*thickness
				ring.append(Vector3(point.x,height,point.y))
				var color:=terrain_surface_color(point,top).lerp(Color(biome.cliff).darkened(.12),profile.y*.55)
				st.set_color(color);st.add_vertex(ring[-1])
			rings.append(ring)
		for i in segments:
			for j in section.size():
				var a:=i*section.size()+j;var b:=i*section.size()+(j+1)%section.size();var c:=a+section.size();var d:=b+section.size()
				for index in [a,c,b,b,c,d]:st.add_index(index)
		# Close both bank ends; these sit below the ground surface.
		for end_index in [0,segments]:
			var ring:Array=rings[end_index];var middle:=Vector3.ZERO
			for point in ring:middle+=point
			middle/=ring.size();var cap_index:=(segments+1)*section.size()+(0 if end_index==0 else 1)
			st.set_color(Color(biome.cliff).darkened(.12));st.add_vertex(middle)
			for j in section.size():
				var a:int=end_index*section.size()+j;var b:int=end_index*section.size()+(j+1)%section.size()
				for index in ([cap_index,b,a] if end_index==0 else [cap_index,a,b]):st.add_index(index)
		st.generate_normals()
		var deck:=MeshInstance3D.new();deck.name="BridgeDeck";deck.mesh=st.commit();deck.material_override=terrain_material;bridge_root.add_child(deck)

# The chute floor height at a point on a waterfall's source channel: it slopes
# from the border hilltop (WATERFALL_TOP, at the far source) down to water level
# where it enters the field, so the water runs down the hillside.
func waterfall_source_height(point:Vector2)->float:
	var best_h:=WATERFALL_TOP;var best_perp:=INF
	for fall in waterfalls:
		var flow:Vector2=fall.flow;if flow.length()>.001:flow=flow.normalized()
		var rel:Vector2=point-Vector2(fall.lip)
		var along:float=rel.dot(flow);var perp:float=absf(rel.dot(Vector2(-flow.y,flow.x)))
		if perp>float(fall.half_width)+1.2:continue
		if perp<best_perp:
			best_perp=perp
			best_h=lerpf(WATER_LEVEL,WATERFALL_TOP,smoothstep(0.0,.78,clampf(-along/float(WATERFALL_REACH),0.0,1.0)))
	return best_h

# --- Waterfalls ----------------------------------------------------------------
# A waterfall's source channel slopes down out of the border hills into the
# field; the water sheet rides that slope so it flows downhill, with foam where
# it meets the field.
func waterfall_material()->ShaderMaterial:
	var material:=water_material();material.set_shader_parameter("surface_flow",true);return material

func build_waterfalls()->void:
	if waterfalls.is_empty():return
	var root:=Node3D.new();root.name="Waterfalls";add_child(root)
	for fall in waterfalls:
		var lip:Vector2=fall.lip;var flow:Vector2=fall.flow;var half_width:float=fall.half_width
		var node:=Node3D.new();node.position=Vector3(lip.x,0,lip.y);node.rotation.y=atan2(flow.x,flow.y);root.add_child(node)
		var flow_dir:Vector2=flow;if flow_dir.length()>.001:flow_dir=flow_dir.normalized()
		var perp:=Vector2(-flow_dir.y,flow_dir.x)
		# The sheet rides the chute from up the source slope down to where it meets the
		# field, sitting just above the sloping ground so the water visibly runs downhill.
		var along_top:=-float(WATERFALL_REACH)*.9;var along_bottom:=1.6
		# Remember the foot (where the water reaches the field) so the terrain fade can
		# keep whatever hill sits between it and the camera see-through.
		fall.foot=Vector3(lip.x,WATER_LEVEL,lip.y)+Vector3(flow_dir.x,0,flow_dir.y)*1.2
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var columns:=maxi(8,int(half_width*8.0));var rows:=32
		for i in columns:
			for j in rows:
				var corners:Array=[]
				for corner in [Vector2(i,j),Vector2(i+1,j),Vector2(i,j+1),Vector2(i+1,j+1)]:
					var u:float=corner.x/float(columns);var v:float=corner.y/float(rows)
					var along:float=lerpf(along_top,along_bottom,v);var localx:float=-half_width+u*half_width*2.0
					var world:Vector2=Vector2(lip.x,lip.y)+flow_dir*along+perp*localx
					var y:float=waterfall_source_height(world)+.055+sin(u*PI*8.0)*.018*sin(v*PI)
					corners.append({"pos":Vector3(localx,y,along),"depth":clampf(.3+.5*sin(v*PI),0.0,1.0),"uv":Vector2(-localx+lip.dot(perp),along+lip.dot(flow)-(y-WATER_LEVEL)*.5)})
				for tri in [[0,1,2],[1,3,2]]:
					for k in tri:
						var vert:Dictionary=corners[k]
						var slope:float=(waterfall_source_height(Vector2(lip)+flow_dir*(float(vert.pos.z)+.05))-waterfall_source_height(Vector2(lip)+flow_dir*(float(vert.pos.z)-.05)))/.1
						st.set_normal(Vector3(0,1,-slope).normalized());st.set_color(water_vertex_color(Vector3(flow_dir.x,slope,flow_dir.y),0.0));st.set_uv(vert.uv);st.set_uv2(Vector2(float(vert.depth),0));st.add_vertex(vert.pos)
		var sheet:=MeshInstance3D.new();sheet.name="WaterfallSheet";sheet.mesh=st.commit();sheet.material_override=waterfall_material();node.add_child(sheet)
		var foam_rng:=RandomNumberGenerator.new();foam_rng.seed=int(absf(lip.x*337.0+lip.y*911.0))
		var foam_shader:=Shader.new();foam_shader.code=WATERFALL_FOAM_SHADER
		var foam_mesh:=PlaneMesh.new();foam_mesh.size=Vector2.ONE
		for i in maxi(24,int(half_width*24.0)):
			var bubble:=MeshInstance3D.new();bubble.name="WaterfallFoam";bubble.mesh=foam_mesh
			bubble.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material:=ShaderMaterial.new();material.shader=foam_shader
			material.set_shader_parameter("foam_color",Color(biome.water_color).lerp(Color.WHITE,.96))
			bubble.material_override=material;node.add_child(bubble)
			waterfall_bubbles.append({"node":bubble,"material":material,
				"origin":Vector3(foam_rng.randf_range(-half_width+.4,half_width-.4),WATER_LEVEL+.085,foam_rng.randf_range(.05,.55)),
				"base":foam_rng.randf_range(.3,.55),"phase":foam_rng.randf(),
				"lifetime":foam_rng.randf_range(1.0,2.0),"drift":foam_rng.randf_range(.6,1.3),
				"sideways":foam_rng.randf_range(-.12,.12)})
	update_waterfall_bubbles()

const WATERFALL_FOAM_SHADER:="""
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float opacity = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float rim = smoothstep(0.35, 0.65, radius) * (1.0 - smoothstep(0.7, 0.98, radius));
	float body = (1.0 - smoothstep(0.35, 0.95, radius)) * 0.8;
	ALBEDO = foam_color.rgb;
	ALPHA = max(rim, body) * opacity;
}
"""

func update_waterfall_bubbles()->void:
	for bubble in waterfall_bubbles:
		var node:MeshInstance3D=bubble.node
		if not is_instance_valid(node):continue
		var age:=fposmod(elapsed/float(bubble.lifetime)+float(bubble.phase),1.0)
		node.position=Vector3(bubble.origin)+Vector3(float(bubble.sideways)*age,0,float(bubble.drift)*age)
		var size:float=float(bubble.base)*lerpf(.65,1.6,age)
		node.scale=Vector3(size,1,size*1.2)
		bubble.material.set_shader_parameter("opacity",smoothstep(0.0,.12,age)*(1.0-smoothstep(.65,1.0,age)))
		# Check the actual world footprint, including the rotated waterfall parent.
		# Foam must sit on the river, never on a bank or on top of a bridge.
		var local_point:=to_local(node.global_position)
		var point:=Vector2(local_point.x,local_point.z)
		var wet:=true
		for offset in [Vector2.ZERO,Vector2.LEFT*size*.6,Vector2.RIGHT*size*.6,Vector2.UP*size*.6,Vector2.DOWN*size*.6]:
			var cell:=cell_of(point+offset)
			if not rivers.has(cell) or bridges.has(cell):wet=false;break
		node.visible=wet

func plain_material(color:Color)->StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=1.0;mat.specular_mode=BaseMaterial3D.SPECULAR_DISABLED;return mat

# --- Clouds ----------------------------------------------------------------------
# A few puffy sphere clouds drift slowly high over the field.
const CLOUD_BLOCKED_OPACITY:=.2
const CLOUD_FADE_SECONDS:=.22
var clouds:Array=[]
func build_clouds(rng:RandomNumberGenerator)->void:
	clouds.clear()
	var cloud_root:=Node3D.new();cloud_root.name="Clouds";add_child(cloud_root)
	for i in 4:
		var cloud:=Node3D.new();cloud.position=Vector3(rng.randf_range(field_rect.position.x,field_rect.end.x),rng.randf_range(9.0,12.0),rng.randf_range(field_rect.position.y,field_rect.end.y));cloud_root.add_child(cloud)
		# The reference's proportions: puffs overlap into one cloud rather than a row of balls.
		var material:=plain_material(Color.WHITE);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		var puff_scale:float=rng.randf_range(.32,.46)
		for puff in [[0,0,0,5.0],[-4.5,-.6,.5,3.4],[4.5,-.6,-.4,3.6],[1.5,1.8,0,3.0]]:
			var ball:=MeshInstance3D.new();ball.mesh=GameData.leaf_sphere();ball.scale=Vector3.ONE*float(puff[3])*2.0*puff_scale;ball.position=Vector3(puff[0],puff[1],puff[2])*puff_scale;ball.material_override=material;ball.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cloud.add_child(ball)
		clouds.append({"node":cloud,"material":material,"opacity":1.0,"speed":rng.randf_range(.12,.2)*(1.0 if i%2==0 else -1.0)})

# Fade the whole cloud when a visible puff lies between the camera and the
# playable ground. Projecting rays also handles orthographic cameras and pans.
func cloud_blocks_camera(node:Node3D)->bool:
	if not is_instance_valid(camera):return false
	var view:=camera.get_viewport().get_visible_rect()
	for puff in node.get_children():
		if not puff is MeshInstance3D:continue
		var center:Vector3=puff.global_position
		var radius:float=puff.mesh.get_aabb().size.x*.5*puff.global_basis.get_scale().x
		if camera.global_position.distance_to(center)<radius:return true
		if camera.is_position_behind(center):continue
		var projected:=camera.unproject_position(center)
		var screen_radius:=projected.distance_to(camera.unproject_position(center+camera.global_basis.x*radius))
		if not view.intersects(Rect2(projected-Vector2.ONE*screen_radius,Vector2.ONE*screen_radius*2.0)):continue
		# Sample the puff's centre and edges so the fade starts before its centre
		# crosses the field edge, instead of popping as the cloud drifts past it.
		for offset in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var screen_point:Vector2=projected+offset*screen_radius*.75
			if not view.has_point(screen_point):continue
			var origin:=camera.project_ray_origin(screen_point);var direction:=camera.project_ray_normal(screen_point)
			if direction.y>=-.001:continue
			var distance:float=-origin.y/direction.y
			var ground:=origin+direction*distance
			for pass_index in 2:
				distance=(terrain_height_at(Vector2(ground.x,ground.z))-origin.y)/direction.y
				ground=origin+direction*distance
			if distance>origin.distance_to(center)-radius and Rect2(field_rect).has_point(Vector2(ground.x,ground.z)):return true
	return false

func update_clouds(delta:float)->void:
	for cloud in clouds:
		var node:Node3D=cloud.node
		if not is_instance_valid(node):continue
		node.position.x+=float(cloud.speed)*delta
		if node.position.x>field_rect.end.x+6:node.position.x=field_rect.position.x-6
		if node.position.x<field_rect.position.x-6:node.position.x=field_rect.end.x+6
		var target:=CLOUD_BLOCKED_OPACITY if cloud_blocks_camera(node) else 1.0
		cloud.opacity=move_toward(float(cloud.opacity),target,(1.0-CLOUD_BLOCKED_OPACITY)*delta/CLOUD_FADE_SECONDS)
		var material:StandardMaterial3D=cloud.material;material.albedo_color=Color(1,1,1,float(cloud.opacity))

func build_multimesh(node_name:String,mesh:Mesh,entries:Array[Dictionary])->MultiMeshInstance3D:
	var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true;multimesh.use_custom_data=entries.any(func(entry):return entry.has("custom"));multimesh.mesh=mesh;multimesh.instance_count=entries.size()
	for i in entries.size():
		multimesh.set_instance_transform(i,entries[i].transform);multimesh.set_instance_color(i,entries[i].color)
		if multimesh.use_custom_data:multimesh.set_instance_custom_data(i,entries[i].get("custom",Color(0,0,0,0)))
	var node:=MultiMeshInstance3D.new();node.name=node_name;node.multimesh=multimesh
	# Instance colours are authored in sRGB (the biome palette); without this
	# flag they are read as linear and every tile renders washed out.
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.roughness=.9;node.material_override=material;add_child(node);return node

# Props on cliff rims and wall tops. Each biome lists the kinds it grows; open
# plains lean on trees and small rocks while caves, ruins, and craters use
# boulders, big mushrooms, crystals, pillars, and blocks instead.
# Decor in the soft-meadow style: smooth blobs, tapered trunks, and a faint shadow disc.
const LEAF_GREENS:=["#5cb15c","#6fbf6a","#8ccf80","#9fd98f"]
func leaf_green(index:int)->Color:
	return Color(LEAF_GREENS[index%LEAF_GREENS.size()]).lerp(biome.get("accent",Color("#6fbf6a")),.3)

# A hill-top prop: the same ExpeditionProp3D used on open ground, so hills carry
# the island's plants too. Most are plain scenery; only some bear fruit (assigned
# like any prop). It blocks its own cell; hills stay walkable around it.
func add_hill_prop(cell:Vector2i,rng:RandomNumberGenerator)->void:
	if bridge_approaches.has(cell) or prop_cells.has(cell) or not field_rect.has_point(cell):return
	if prop_cells.keys().any(func(other):return Vector2(other).distance_to(Vector2(cell))<PROP_SPACING):return
	var had:bool=walkable.has(cell)
	walkable.erase(cell)
	if not zones_connected():
		if had:walkable[cell]=true
		return
	decor_count+=1
	var kinds:=prop_kinds()
	var prop=PROP_SCRIPT.new();prop.setup(kinds[rng.randi_range(0,kinds.size()-1)],cell,biome,stage_level,rng)
	assign_prop_harvest(prop,rng)
	prop.destroyed.connect(_on_prop_destroyed);props_root.add_child(prop);props.append(prop);prop_cells[cell]=prop

func add_decor(pos:Vector3,rng:RandomNumberGenerator)->void:
	decor_count+=1
	var accent:Color=biome.accent;var cliff:Color=biome.cliff
	var kinds:Array=biome.decor if biome.decor is Array else [str(biome.decor)]
	match str(kinds[rng.randi_range(0,kinds.size()-1)]):
		"tree":add_tree(pos)
		"bush":add_bush(pos)
		"rock","boulder":add_rocks(pos,rng.randf_range(.6,1.0),rng)
		"big_mushroom":
			var height:=rng.randf_range(1.4,2.1);add_cylinder(pos+Vector3(0,height*.5,0),.2,.26,height,GameData.COLORS.cream);add_sphere(pos+Vector3(0,height+.1,0),Vector3(.7,.28,.7),accent);add_shadow(pos,.8)
		"block":
			var block:=add_box(pos+Vector3(0,.55,0),Vector3(1.1,1.1,1.1),cliff.lightened(.12));block.rotation.y=rng.randf_range(-.4,.4)
		"crystal":
			var crystal:=add_box(pos+Vector3(0,.7,0),Vector3(.35,1.5,.35),accent);crystal.rotation=Vector3(.15,rng.randf()*TAU,.1)
		"pillar":add_cylinder(pos+Vector3(0,1.05,0),.3,.36,2.1,cliff.lightened(.1))
		"cactus":add_cylinder(pos+Vector3(0,.7,0),.2,.22,1.4,accent);add_sphere(pos+Vector3(0,1.4,0),Vector3(.2,.2,.2),accent)
		"mushroom":add_cylinder(pos+Vector3(0,.35,0),.1,.13,.7,GameData.COLORS.cream);add_sphere(pos+Vector3(0,.8,0),Vector3(.5,.22,.5),accent)
		_:add_sphere(pos+Vector3(0,.2,0),Vector3(.6,.35,.6),accent)

func rock_color()->Color:
	if biome.has("rock"):return Color(biome.rock)
	return Color("#b9c3cb")

# A tight cluster of squashed grey blobs, each seated on the ground under it.
func add_rocks(pos:Vector3,scale:float,_rng:RandomNumberGenerator)->void:
	var grey:Color=rock_color();var light:Color=grey.lightened(.14);var dark:Color=grey.darkened(.1)
	# One cohesive rounded rock: overlapping squashed lumps, lighter on top, darker low.
	var lumps:Array=[[0,.40,0,.72,.50,.64,dark],[.36,.54,.12,.50,.42,.46,grey],[-.32,.50,-.16,.46,.40,.44,grey],[.06,.74,.04,.42,.36,.40,light],[-.10,.36,.34,.40,.32,.38,grey]]
	for lump in lumps:
		var offset:Vector3=Vector3(lump[0],0,lump[2])*scale;var radii:Vector3=Vector3(lump[3],lump[4],lump[5])*scale
		var ground:float=terrain_height_at(Vector2(pos.x+offset.x,pos.z+offset.z))
		add_sphere(Vector3(pos.x+offset.x,ground+float(lump[1])*scale,pos.z+offset.z),radii,lump[6])
	add_shadow(pos,1.05*scale)

func add_trunk(pos:Vector3,height:float,width:float)->void:
	add_cylinder(pos+Vector3(0,height*.5,0),width*.75,width,height,Color("#a96f42"))

# Plain matte pieces: a rounded box, a tapered cylinder, or a smooth blob.
func add_box(pos:Vector3,size:Vector3,color:Color)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=GameData.rounded_box(size,minf(size.x,minf(size.y,size.z))*.2);node.position=pos;node.material_override=plain_material(color);(decor_root if is_instance_valid(decor_root) else self).add_child(node);return node

func add_cylinder(pos:Vector3,top_radius:float,bottom_radius:float,height:float,color:Color)->MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=top_radius;mesh.bottom_radius=bottom_radius;mesh.height=height;mesh.radial_segments=12
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=pos;node.material_override=plain_material(color);(decor_root if is_instance_valid(decor_root) else self).add_child(node);return node

func add_sphere(pos:Vector3,size:Vector3,color:Color)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=GameData.leaf_sphere();node.position=pos;node.scale=size*2.0;node.material_override=plain_material(color);(decor_root if is_instance_valid(decor_root) else self).add_child(node);return node

# A soft translucent disc on the ground under a tree, bush, or rock pile.
func add_shadow(pos:Vector3,radius:float)->MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=.02;mesh.radial_segments=20
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=pos+Vector3(0,.06,0)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.2,.31,.16,.16);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;node.material_override=mat
	(decor_root if is_instance_valid(decor_root) else self).add_child(node);return node

# A tree is a tapered trunk under five round leaf blobs in four greens, over a shadow disc.
func add_tree(pos:Vector3)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=int(absf(pos.x*1327.0+pos.z*7919.0))+stage_area_index
	var s:float=rng.randf_range(.28,.38)
	add_trunk(pos,6.0*s,1.05*s)
	var blobs:Array=[[0,8.6,0,4.6],[-3.4,7,.6,3],[3.4,7,-.6,3],[0,11,.4,2.8],[1.6,8.4,2.6,2.4]]
	for i in blobs.size():
		var blob:Array=blobs[i];add_sphere(pos+Vector3(blob[0],blob[1],blob[2])*s,Vector3.ONE*float(blob[3])*s,leaf_green(i))
	add_shadow(pos,5.2*s)

# A bush is three leaf blobs.
func add_bush(pos:Vector3)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=int(absf(pos.x*911.0+pos.z*4177.0))+stage_area_index
	var s:float=rng.randf_range(.95,1.2)
	# A full, rounded dome of overlapping leaves rather than three stray balls.
	var blobs:Array=[[0,.40,0,.50],[.34,.32,.05,.37],[-.34,.32,-.05,.37],[.05,.32,.34,.35],[-.05,.32,-.34,.35],[.12,.60,.06,.35],[-.12,.55,-.08,.31]]
	for i in blobs.size():
		var blob:Array=blobs[i];add_sphere(pos+Vector3(blob[0],blob[1],blob[2])*s,Vector3.ONE*float(blob[3])*s,leaf_green(i%3))
	add_shadow(pos,.85*s)

# Each patch is rolled its ingredient up front and is shaped after it, so the
# team can tell from a distance what a patch is likely to give. Any resource can
# grow anywhere; Berry Groves lean toward the four berries (GROVE_BERRY_SHARE of
# their patches) while regular and Boss levels roll from the whole list.
const BERRY_INGREDIENTS:=["Bumbleberry","Dewmelon","Frostberry","Sunplum"]
const GROVE_BERRY_SHARE:=.6
func add_berry_patch(pos:Vector3)->void:
	var grove:=is_grove()
	var rich:bool=randf()<(GROVE_RICH_CHANCE if grove else REGULAR_RICH_CHANCE)
	# Groves (and rich patches) roll deeper, so they lean to rarer resources.
	var level:=stage_level+(GROVE_INGREDIENT_LEVEL_BONUS if (grove or rich) else 0)
	var berry_only:bool=grove and randf()<GROVE_BERRY_SHARE
	var patch:=Node3D.new();patch.position=Vector3(pos.x,terrain_height_at(Vector2(pos.x,pos.z)),pos.z);patch.set_meta("ingredient",GameData.roll_ingredient(level,BERRY_INGREDIENTS if berry_only else []))
	patch.set_meta("zone",patch_zone(Vector2(pos.x,pos.z)));patch.set_meta("rich",rich)
	build_berry_patch_shape(patch,str(patch.get_meta("ingredient")))
	if rich:patch.scale*=1.4
	add_child(patch);berry_nodes.append(patch)

func berry_orb(patch:Node3D,offset:Vector3,radius:float,color:Color,glow:=0.0,squash:=1.0)->MeshInstance3D:
	var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2.0*squash;mesh.radial_segments=8;mesh.rings=5
	var berry:=MeshInstance3D.new();berry.mesh=mesh;berry.position=offset
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.7
	if glow>0.0:mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=glow
	berry.material_override=mat;patch.add_child(berry);return berry

func plant_box(patch:Node3D,offset:Vector3,size:Vector3,color:Color,rotation:=Vector3.ZERO)->MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size;var part:=MeshInstance3D.new();part.mesh=mesh;part.position=offset;part.rotation=rotation
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.85;part.material_override=mat;patch.add_child(part);return part

func plant_stem(patch:Node3D,from:Vector3,to:Vector3,radius:float,color:Color)->void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius*.7;mesh.bottom_radius=radius;mesh.height=from.distance_to(to);mesh.radial_segments=7
	var part:=MeshInstance3D.new();part.mesh=mesh;part.position=(from+to)*.5;part.quaternion=Quaternion(Vector3.UP,(to-from).normalized());part.material_override=plain_material(color);patch.add_child(part)

func plant_leaf(patch:Node3D,pos:Vector3,angle:float,length:=.35)->void:
	var leaf:=berry_orb(patch,pos,.12,GameData.COLORS.leaf,0.0,.22);leaf.scale=Vector3(length/.12,1,.65);leaf.rotation.y=angle;leaf.rotation.z=.25

func build_resource_plant_base(patch:Node3D,ingredient:String)->void:
	var green:Color=GameData.COLORS.leaf_dark
	match ingredient:
		"Bumbleberry":
			for side in [-1.0,1.0]:
				plant_stem(patch,Vector3(0,0,0),Vector3(side*.3,.62,.06),.035,green)
				for i in 3:
					var p:=Vector3(side*(.12+i*.06),.18+i*.14,.04);plant_leaf(patch,p,side*.7,.23)
					berry_orb(patch,p+Vector3(side*.09,.04,.09),.085,GameData.INGREDIENTS[ingredient].color)
		"Dewmelon","Brinepod","Stonebean":
			for i in 7:
				var a:=float(i)*.65;var p:=Vector3(sin(a)*.65,.035,cos(a)*.45)
				plant_stem(patch,Vector3.ZERO,p,.023,green);plant_leaf(patch,p,a,.22)
		"Frostberry":
			for i in 7:
				var a:=i*TAU/7.0;plant_leaf(patch,Vector3(cos(a)*.25,.04,sin(a)*.25),a,.24)
		"Sunplum","Sparkfruit":
			plant_stem(patch,Vector3.ZERO,Vector3(0,.85,0),.05,Color("#755238"))
			for i in 5:
				var a:=i*TAU/5.0;var tip:=Vector3(cos(a)*.4,.65+float(i%2)*.2,sin(a)*.4)
				plant_stem(patch,Vector3(0,.5,0),tip,.025,green);plant_leaf(patch,tip,a,.28)
				berry_orb(patch,tip-Vector3(0,.10,0),.13,GameData.INGREDIENTS[ingredient].color)
		"Curlcap","Puffshroom","Glowcap":
			for i in 3:
				var pos:=Vector3(-.32+i*.29,.01,.25);plant_stem(patch,pos,pos+Vector3(0,.18,0),.028,GameData.COLORS.cream);berry_orb(patch,pos+Vector3(0,.2,0),.13,GameData.INGREDIENTS[ingredient].color,0.0,.45)
		_:
			for i in 4:
				var a:=i*TAU/4.0;plant_leaf(patch,Vector3(cos(a)*.12,.04,sin(a)*.12),a,.28)

# One recognisable plant per resource. Every ingredient in GameData.INGREDIENTS
# has its own branch; the fallback only guards against unknown names.
func build_berry_patch_shape(patch:Node3D,ingredient:String)->void:
	var color:Color=GameData.INGREDIENTS.get(ingredient,{}).get("color",GameData.COLORS.berry)
	var leaf:Color=GameData.COLORS.leaf;var dark_leaf:Color=GameData.COLORS.leaf_dark;var soil:=Color("#6b4b30")
	patch.set_meta("shape",ingredient)
	# Roots, vines, canes, and mushroom beds define different silhouettes.
	build_resource_plant_base(patch,ingredient)
	match ingredient:
		"Bumbleberry":  # a pair of plump purple berries
			berry_orb(patch,Vector3(-.2,.22,0),.22,color);berry_orb(patch,Vector3(.2,.26,.12),.22,color)
		"Dewmelon":  # one big round teal melon on a stem
			berry_orb(patch,Vector3(0,.32,0),.34,color);plant_box(patch,Vector3(0,.72,0),Vector3(.08,.22,.08),dark_leaf)
		"Frostberry":  # a scatter of tiny glowing pale-blue berries
			for offset in [Vector3(-.4,.1,.1),Vector3(-.15,.12,-.3),Vector3(.1,.1,.25),Vector3(.35,.12,-.05),Vector3(.05,.1,-.05),Vector3(-.25,.1,.35)]:berry_orb(patch,offset,.09,color,.6)
		"Sunplum":  # a single warm plum that glows, with a sprig
			berry_orb(patch,Vector3(0,.42,0),.26,color,.6);plant_box(patch,Vector3(.18,.72,0),Vector3(.3,.05,.14),leaf,Vector3(0,0,.5))
		"Emberpepper":  # three slender upright red pods with green caps
			for i in 3:
				var x:=-.28+i*.28;plant_box(patch,Vector3(x,.32,0),Vector3(.12,.6,.12),color,Vector3(0,0,-.25+i*.25));plant_box(patch,Vector3(x,.64,0),Vector3(.16,.08,.16),dark_leaf)
		"Knobroot":  # a knobbly brown lump half buried with a sprout on top
			berry_orb(patch,Vector3(0,.12,0),.3,color,0.0,.7);berry_orb(patch,Vector3(-.3,.1,.15),.14,color);berry_orb(patch,Vector3(.25,.12,-.2),.12,color);plant_box(patch,Vector3(0,.45,0),Vector3(.06,.3,.06),leaf);plant_box(patch,Vector3(.08,.58,0),Vector3(.22,.04,.1),leaf)
		"Curlcap":  # a tan mushroom whose cap curls at one edge
			plant_box(patch,Vector3(0,.2,0),Vector3(.14,.4,.14),GameData.COLORS.cream);berry_orb(patch,Vector3(0,.42,0),.32,color,0.0,.45);berry_orb(patch,Vector3(.24,.34,0),.12,color)
		"Stonebean":  # three grey beans sitting in a dark pod
			plant_box(patch,Vector3(0,.12,0),Vector3(.9,.14,.34),dark_leaf)
			for i in 3:plant_box(patch,Vector3(-.26+i*.26,.26,0),Vector3(.18,.18,.18),color,Vector3(0,PI/4,PI/4))
		"Honeybulb":  # a golden bulb on a tall stalk with a drooping tip
			berry_orb(patch,Vector3(0,.2,0),.24,color,.5,.9);plant_box(patch,Vector3(0,.62,0),Vector3(.06,.5,.06),leaf);berry_orb(patch,Vector3(.12,.9,0),.09,color,.8)
		"Bitterleaf":  # a fan of three flat green leaves
			for i in 3:plant_box(patch,Vector3(0,.3,0),Vector3(.7,.04,.24),color,Vector3(0,-.9+i*.9,.6))
			plant_box(patch,Vector3(0,.12,0),Vector3(.08,.24,.08),dark_leaf)
		"Puffshroom":  # a lilac puffball on a short stalk with two tiny puffs
			plant_box(patch,Vector3(0,.12,0),Vector3(.12,.24,.12),GameData.COLORS.cream);berry_orb(patch,Vector3(0,.42,0),.3,color);berry_orb(patch,Vector3(.4,.1,.15),.1,color);berry_orb(patch,Vector3(-.35,.1,-.2),.08,color)
		"Crystalcorn":  # a glowing yellow cob wrapped in two green husks
			berry_orb(patch,Vector3(0,.45,0),.16,color,.5,2.4);plant_box(patch,Vector3(-.14,.3,0),Vector3(.1,.5,.26),leaf,Vector3(0,0,.35));plant_box(patch,Vector3(.14,.3,0),Vector3(.1,.5,.26),leaf,Vector3(0,0,-.35))
		"Brinepod":  # a long teal pod lying on its side with a ridge
			var pod:=berry_orb(patch,Vector3(0,.18,0),.16,color,0.0,2.6);pod.rotation.z=PI/2;plant_box(patch,Vector3(0,.34,0),Vector3(.7,.05,.06),dark_leaf)
		"Sparkfruit":  # a bright yellow fruit crackling with a tiny zigzag
			berry_orb(patch,Vector3(0,.3,0),.24,color,.9);plant_box(patch,Vector3(-.05,.62,0),Vector3(.16,.04,.04),color,Vector3(0,0,.7));plant_box(patch,Vector3(.06,.7,0),Vector3(.16,.04,.04),color,Vector3(0,0,-.7))
		"Oldroot":  # a gnarled grey root, two crossed limbs half buried
			plant_box(patch,Vector3(0,.12,0),Vector3(.8,.14,.14),color,Vector3(0,.5,.2));plant_box(patch,Vector3(0,.16,0),Vector3(.7,.12,.12),color,Vector3(0,-.9,-.25));berry_orb(patch,Vector3(0,.08,0),.18,soil,0.0,.5)
		"Glowcap":  # a taller mushroom with a glowing green cap
			plant_box(patch,Vector3(0,.28,0),Vector3(.12,.56,.12),GameData.COLORS.cream);berry_orb(patch,Vector3(0,.6,0),.28,color,.7,.5)
		_:
			berry_orb(patch,Vector3(-.2,.22,0),.22,color);berry_orb(patch,Vector3(.2,.26,.12),.22,color)

# The clearing a patch belongs to; corridor patches count toward the nearest clearing.
func patch_zone(point:Vector2)->int:
	var inside:=zone_index_at(point)
	if inside>=0:return inside
	var best:=0;var best_distance:=INF
	for i in zones.size():
		var distance:=Vector2(zones[i].center).distance_to(point)
		if distance<best_distance:best_distance=distance;best=i
	return best

# A cell is "open" when it sits in at least one fully walkable 2×2 block, so a
# Quiblet can stand on it without the cliff padding on both sides pinching it.
# One-tile nooks ("wall, berry, wall") fail this and are never used for patches.
func cell_open(cell:Vector2i)->bool:
	if not walkable.has(cell):return false
	for dx in [-1,1]:
		for dz in [-1,1]:
			if walkable.has(cell+Vector2i(dx,0)) and walkable.has(cell+Vector2i(0,dz)) and walkable.has(cell+Vector2i(dx,dz)):return true
	return false

# Fully exposed: the cell and all eight neighbours are walkable, so a patch
# never sits against a cliff face at all.
func cell_exposed(cell:Vector2i)->bool:
	for dx in [-1,0,1]:
		for dz in [-1,0,1]:
			if not walkable.has(cell+Vector2i(dx,dz)):return false
	return true

# Which diagonal neighbour block of an open cell is fully walkable, so a group
# can be laid out inside it without anyone standing on a wall or in a river.
func open_block_direction(cell:Vector2i)->Vector2i:
	for dx in [1,-1]:
		for dz in [1,-1]:
			if walkable.has(cell+Vector2i(dx,0)) and walkable.has(cell+Vector2i(0,dz)) and walkable.has(cell+Vector2i(dx,dz)):return Vector2i(dx,dz)
	return Vector2i(1,1)

func nearest_open_cell(point:Vector2)->Vector2i:
	var cell:=cell_of(point)
	if cell_open(cell):return cell
	var best:=cell;var best_distance:=INF
	for candidate in walkable:
		if not cell_open(candidate):continue
		var distance:=Vector2(candidate).distance_squared_to(point)
		if distance<best_distance:best_distance=distance;best=candidate
	return best

func place_berry_patches(rng:RandomNumberGenerator)->void:
	var berry_count:int=GROVE_PATCHES.get(stage_kind,2)
	# Side pockets away from the trail first, then anywhere along the route; only
	# exposed cells qualify so no patch ends up wedged in a one-tile nook.
	var pockets:Array[Vector2i]=[];var others:Array[Vector2i]=[]
	for cell in reachable_walkable_cells():
		var point:=Vector2(cell.x,cell.y)
		if zone_index_at(point)==0 or not cell_exposed(cell):continue
		if route_distance(point)>=1.6:pockets.append(cell)
		else:others.append(cell)
	shuffle_cells(pockets,rng);shuffle_cells(others,rng)
	var placed:Array[Vector2]=[]
	for cell in pockets+others:
		if placed.size()>=berry_count:break
		var point:=Vector2(cell.x,cell.y)
		if placed.any(func(other):return other.distance_to(point)<2.0):continue
		if zones.any(func(zone):return Vector2(zone.center).distance_to(point)<1.8):continue
		placed.append(point);add_berry_patch(Vector3(point.x,.2,point.y))

func shuffle_cells(cells:Array[Vector2i],rng:RandomNumberGenerator)->void:
	for i in range(cells.size()-1,0,-1):
		var j:=rng.randi_range(0,i);var swap:Vector2i=cells[i];cells[i]=cells[j];cells[j]=swap

func _process(delta:float)->void:
	elapsed+=delta
	update_group_camera(delta)
	update_wall_fades(delta)
	update_clouds(delta)
	update_waterfall_bubbles()
	# Fighters ride the rolling ground (and the bridge arches).
	for actor in team+enemies:
		if is_instance_valid(actor):actor.position.y=flight_height_at(Vector2(actor.position.x,actor.position.z)) if actor.floats_over_water() else terrain_height_at(Vector2(actor.position.x,actor.position.z))
	if intermission>0:
		intermission-=delta
		if intermission<=0:
			if wave>=max_waves:finish(true)
			else:spawn_wave()
	var living:Array=team.filter(func(actor):return actor.current_hp>0)
	# The team only engages enemies that have noticed it, so a distant idle group
	# never drags the team straight across rivers and walls; exploration routes
	# the team to the next group along walkable ground instead.
	for actor in enemies:
		if actor.current_hp<=0:continue
		if not actor.get_meta("alerted",true):
			var center:Vector2;var reach:float
			if actor.has_meta("alert_center"):center=actor.get_meta("alert_center");reach=float(actor.get_meta("alert_radius",SCATTER_ALERT_RADIUS))
			else:
				var zone:Dictionary=zones[clampi(int(actor.get_meta("zone",0)),0,zones.size()-1)];center=zone.center;reach=maxf(zone.radius.x,zone.radius.y)
			var reached:bool=living.any(func(member):return Vector2(member.position.x,member.position.z).distance_to(center)<=reach+ALERT_MARGIN)
			if reached or actor.current_hp<actor.max_hp:
				actor.set_meta("alerted",true)
				if advance_index>=0:
					advance_index=-1
					for member in living:member.has_command=false
			else:actor.target=null;continue
		actor.target=nearest(actor,team)
	update_team_targets()
	update_advance(living)
	for patch in berry_nodes.duplicate():
		for actor in team:
			if actor.current_hp>0 and actor.horizontal_distance(actor.position,patch.position)<1.1:
				var patch_range:Vector2i=RICH_YIELD if patch.get_meta("rich",false) else BERRY_PATCH_RANGE;var amount:=randi_range(patch_range.x,patch_range.y);var ingredient:String=patch.get_meta("ingredient");loot[ingredient]+=amount;gathered+=1
				reward_acquired.emit({"kind":"ingredient","name":ingredient,"amount":amount},patch.global_position)
				berry_nodes.erase(patch);patch.queue_free();event_message.emit("Berry patch gathered: +%d %s"%[amount,ingredient]);break
	update_harvesting(living,delta)
	update_chase_routing(delta)
	if is_grove():update_grove()
	else:update_exploration(living)
	if is_instance_valid(cache_node) and not ended:
		for actor in team:
			if actor.current_hp>0 and actor.horizontal_distance(actor.position,cache_node.position)<1.2:
				if treasure_keys>0:open_treasure_cache()
				elif not cache_node.get_meta("warned",false):cache_node.set_meta("warned",true);event_message.emit("A locked treasure cache. Bring a Treasure Key to open it.")
				break

# A grove ends once every patch is gathered, whether or not guardians remain.
# Between fights the team is led onward as soon as the meadows behind it are picked clean.
func alerted_enemies()->Array[QuibletActor3D]:
	var result:Array[QuibletActor3D]=[]
	for enemy in enemies:
		if enemy.current_hp>0 and enemy.get_meta("alerted",false):result.append(enemy)
	return result

func update_grove()->void:
	if ended:return
	if berry_nodes.is_empty():
		if intermission<=0:intermission=1.3;event_message.emit("Every berry patch is gathered — the grove is complete.")
		return
	if advance_index>=0 or grove_zone>=zones.size()-1:return
	if enemies.any(func(enemy):return enemy.current_hp>0 and enemy.get_meta("alerted",false)):return
	if not berry_nodes.any(func(patch):return int(patch.get_meta("zone",0))<=grove_zone):grove_zone+=1;begin_advance(grove_zone)

func begin_advance(target_zone:int)->void:
	advance_waypoints.clear();advance_index=-1
	var segment:=target_zone-1
	if segment<0 or segment>=zones.size()-1:return
	for step in [3,6,9,ROUTE_SAMPLES-1]:
		var point:Vector2=route_points[segment*ROUTE_SAMPLES+step];advance_waypoints.append(Vector3(point.x,0,point.y))
	advance_index=0

func update_advance(living:Array)->void:
	if advance_index<0:return
	if advance_index>=advance_waypoints.size() or living.is_empty():advance_index=-1;return
	var centroid:=Vector3.ZERO
	for member in living:centroid+=member.position
	centroid/=living.size()
	var waypoint:Vector3=advance_waypoints[advance_index]
	if Vector2(centroid.x,centroid.z).distance_to(Vector2(waypoint.x,waypoint.z))<1.4:
		advance_index+=1
		if advance_index>=advance_waypoints.size():advance_index=-1;return
		issue_route_command(advance_waypoints[advance_index],living)
	elif not living.any(func(member):return member.has_command):issue_route_command(waypoint,living)

func issue_route_command(point:Vector3,living:Array,automatic:=true)->void:
	for i in living.size():
		var spacing:=(float(i)-float(living.size()-1)*.5)*.9;var goal:=point+Vector3(spacing,0,0)
		living[i].follow_path(find_path(Vector2(living[i].position.x,living[i].position.z),Vector2(goal.x,goal.z),living[i].floats_over_water()))
		living[i].set_meta("auto_route",automatic)

# --- Path-finding over the walkable tile grid -------------------------------
# Commanded runs (berry patches tucked into side pockets especially) are routed
# through the carved corridors: a breadth-first search over walkable cells, then
# string-pulled so the Quiblet only turns where the cliffs make it necessary.
func cell_of(point:Vector2)->Vector2i:
	return Vector2i(roundi(point.x),roundi(point.y))

func nearest_walkable_cell(point:Vector2)->Vector2i:
	var cell:=cell_of(point)
	if walkable.has(cell):return cell
	var best:=cell;var best_distance:=INF
	for candidate in walkable:
		var distance:=Vector2(candidate).distance_squared_to(point)
		if distance<best_distance:best_distance=distance;best=candidate
	return best

# True when the straight segment stays on walkable tiles with a little clearance from cliffs.
func flight_height_at(point:Vector2)->float:
	# Follow the land's broad elevation, ignoring river troughs and bridge arches.
	return maxf(plain_roll(point),raw_height_at(point))

func navigation_cell_open(cell:Vector2i,flying:bool)->bool:
	return walkable.has(cell) or (flying and rivers.has(cell) and in_field(cell))

func line_walkable(a:Vector2,b:Vector2,flying:=false)->bool:
	var steps:=maxi(1,ceili(a.distance_to(b)/.25))
	for i in steps+1:
		var p:=a.lerp(b,float(i)/steps)
		for offset in [Vector2.ZERO,Vector2(.4,0),Vector2(-.4,0),Vector2(0,.4),Vector2(0,-.4)]:
			if not navigation_cell_open(cell_of(p+offset),flying):return false
	return true

func find_path(from:Vector2,to:Vector2,flying:=false)->Array[Vector3]:
	# Targets on cliffs or in one-tile nooks are moved to the nearest open cell.
	var goal_cell:=cell_of(to) if flying and navigation_cell_open(cell_of(to),true) else nearest_open_cell(to);var goal:=to if (flying and navigation_cell_open(cell_of(to),true)) or cell_open(cell_of(to)) else Vector2(goal_cell)
	var direct:Array[Vector3]=[Vector3(goal.x,0,goal.y)]
	if walkable.is_empty() or line_walkable(from,goal,flying):return direct
	var start_cell:=cell_of(from) if flying and navigation_cell_open(cell_of(from),true) else nearest_walkable_cell(from)
	var parents:={start_cell:start_cell};var frontier:Array[Vector2i]=[start_cell];var head:=0
	while head<frontier.size() and not parents.has(goal_cell):
		var cell:Vector2i=frontier[head];head+=1
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next:Vector2i=cell+offset
			if navigation_cell_open(next,flying) and not parents.has(next):parents[next]=cell;frontier.append(next)
	if not parents.has(goal_cell):return []
	var cells:Array[Vector2]=[];var cursor:=goal_cell
	while cursor!=start_cell:cells.push_front(Vector2(cursor));cursor=parents[cursor]
	cells.append(goal)
	var path:Array[Vector3]=[];var anchor:=from;var index:=0
	while index<cells.size():
		var furthest:=cells.size()-1
		while furthest>index and not line_walkable(anchor,cells[furthest],flying):furthest-=1
		anchor=cells[furthest];path.append(Vector3(anchor.x,0,anchor.y));index=furthest+1
	return path

func update_group_camera(delta:float)->void:
	if not is_instance_valid(camera) or team.is_empty():return
	var followed:Array=team.filter(func(actor):return actor.current_hp>0)
	if followed.is_empty():followed=team
	var min_x:=INF;var max_x:=-INF;var min_z:=INF;var max_z:=-INF
	for actor in followed:
		min_x=minf(min_x,actor.global_position.x);max_x=maxf(max_x,actor.global_position.x)
		min_z=minf(min_z,actor.global_position.z);max_z=maxf(max_z,actor.global_position.z)
	var group_center:=Vector3((min_x+max_x)*.5,0,(min_z+max_z)*.5)
	var spread:=maxf(max_x-min_x,max_z-min_z)
	# A boss introduction pans the camera over to the arena for a few seconds.
	if camera_pan_time>0.0:
		camera_pan_time-=delta;group_center=camera_pan_target;spread=6.0
	# Catch up faster the further the focus lags behind the team, so a new route
	# or a long dash never leaves the camera trailing behind.
	var weight:=1.0-exp(-(3.0+camera_focus.distance_to(group_center)*.6)*delta)
	camera_focus=camera_focus.lerp(group_center,weight)
	var height:=clampf(12.5+spread*.34,12.5,17.5)
	var depth:=clampf(14.0+spread*.55,14.0,22.0)
	var desired_position:=camera_focus+Vector3(0,height,depth)
	camera.global_position=camera.global_position.lerp(desired_position,weight)
	camera.look_at(camera_focus+Vector3(0,.45,0),Vector3.UP)

func nearest(from:QuibletActor3D,pool:Array[QuibletActor3D])->QuibletActor3D:
	# A Taunt/Distract pulls attention: while any reachable candidate is taunting,
	# only taunters are considered, so enemies converge on the tank.
	var taunters:Array[QuibletActor3D]=[]
	for candidate in pool:
		if candidate.current_hp>0 and candidate.statuses.has("taunt") and from.horizontal_distance(from.position,candidate.position)<=TAUNT_RANGE:taunters.append(candidate)
	var considered:Array[QuibletActor3D]=taunters if not taunters.is_empty() else pool
	var result:QuibletActor3D;var best:=INF
	for candidate in considered:
		if candidate.current_hp<=0:continue
		var d:=from.horizontal_distance(from.position,candidate.position)
		if d<best:best=d;result=candidate
	return result

func spawn_wave()->void:
	wave+=1
	if is_grove():spawn_grove_guardians()
	elif wave<max_waves:spawn_enemy_set()
	else:spawn_boss_wave()

# --- Spawn areas and enemy sets ---------------------------------------------
# A field has a handful of spawn areas at random open spots, re-rolled on every
# expedition (spawn_rng is randomised, unlike the seeded map). Enemy sets come
# one at a time: each set appears at an unused spawn area away from the team
# only after the previous set is beaten, idles until the team comes close, and
# the team auto-explores toward it along walkable ground until the player
# clicks elsewhere. When the last set falls, the boss takes the nearest arena.
func prepare_spawn_points()->void:
	spawn_points.clear();used_spawn_points.clear()
	var start:Vector2=zones[0].center;var candidates:Array[Vector2i]=[]
	for cell in walkable:
		if cell_open(cell) and Vector2(cell).distance_to(start)>=SPAWN_POINT_MIN_START_DISTANCE:candidates.append(cell)
	shuffle_cells(candidates,spawn_rng)
	for cell in candidates:
		if spawn_points.size()>=SPAWN_POINTS:break
		var point:=Vector2(cell)
		if spawn_points.any(func(other):return other.distance_to(point)<SPAWN_POINT_SPACING):continue
		spawn_points.append(point)

func team_centroid()->Vector2:
	var living:Array=team.filter(func(actor):return actor.current_hp>0)
	if living.is_empty():return zones[0].center
	var centroid:=Vector2.ZERO
	for member in living:centroid+=Vector2(member.position.x,member.position.z)
	return centroid/living.size()

# An unused spawn area at least SET_MIN_TEAM_DISTANCE from the team; failing
# that the farthest unused one, and failing that any spawn area.
func pick_spawn_point()->int:
	var centroid:=team_centroid();var unused:Array[int]=[]
	for i in spawn_points.size():
		if not used_spawn_points.has(i):unused.append(i)
	if unused.is_empty():
		used_spawn_points.clear()
		for i in spawn_points.size():unused.append(i)
	var far:Array[int]=unused.filter(func(i):return spawn_points[i].distance_to(centroid)>=SET_MIN_TEAM_DISTANCE)
	if not far.is_empty():return far[spawn_rng.randi_range(0,far.size()-1)]
	var best:int=unused[0];var best_distance:=-1.0
	for i in unused:
		var distance:=spawn_points[i].distance_to(centroid)
		if distance>best_distance:best_distance=distance;best=i
	return best

func spawn_enemy_set()->void:
	if spawn_points.is_empty():prepare_spawn_points()
	var point_index:=pick_spawn_point();used_spawn_points.append(point_index);var center:Vector2=spawn_points[point_index]
	var scaling:=GameData.enemy_scaling(stage_area_index);var extra:=GameData.extra_enemies_for_area(stage_area_index)
	var team_scaled_cap:=maxi(1,ceili(team_data.size()*.75))
	var count:=mini(1+spawn_rng.randi_range(0,1),team_scaled_cap)+extra+(1 if challenger else 0)+(BOSS_STAGE_EXTRA_ENEMIES if stage_kind=="boss" else 0)
	for i in count:
		var level_boost:=(2 if challenger else (1 if fortune else 0))+(BOSS_STAGE_ENEMY_LEVEL_BOOST if stage_kind=="boss" else 0)
		var q:=make_enemy((stage_area_index+stage_node_index+wave*3+i)%GameData.SPECIES.size(),enemy_level(spawn_rng.randi_range(-1,1)))
		var actor:=QuibletActor3D.new();actor.setup(q,true,level_boost,-1,scaling)
		var block:=open_block_direction(Vector2i(center))
		actor.position=Vector3(center.x+(i%2)*.9*float(block.x),0,center.y+(i/2)*.9*float(block.y))
		actor.set_meta("zone",patch_zone(center));actor.set_meta("group",wave);actor.set_meta("spawn_point",point_index);actor.set_meta("alert_center",center);actor.set_meta("alert_radius",SCATTER_ALERT_RADIUS);actor.set_meta("alerted",false)
		place_actor(actor);enemies.append(actor);play_spawn_drop(actor,i*SPAWN_DROP_STAGGER)
	exploring=true
	camera_pan_target=Vector3(center.x,0,center.y);camera_pan_time=spawn_drop_duration(count)+SET_PAN_LINGER
	event_message.emit("Enemy set %d of %d appears somewhere in the field."%[wave,max_waves-1] if wave>1 else "Enemies stir somewhere in the field. Beat every set to draw out the boss.")

# New enemies pop in slightly above their spot, hop up a little, then drop to
# the ground. The lift goes through the actor's model_lift offset because the
# model's position is rebuilt every status tick.
# Seconds until the last of `count` staggered enemies has landed.
func spawn_drop_duration(count:int)->float:
	return float(maxi(0,count-1))*SPAWN_DROP_STAGGER+SPAWN_DROP_SECONDS

func play_spawn_drop(actor:QuibletActor3D,delay:=0.0,landing_squash:=true)->void:
	actor.model_lift=.6
	var tween:=actor.create_tween()
	if delay>0.0:tween.tween_interval(delay)
	tween.tween_property(actor,"model_lift",1.1,.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor,"model_lift",0.0,SPAWN_DROP_SECONDS-.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if landing_squash:
		tween.tween_property(actor,"model_stretch",Vector3(1.12,.86,1.12),.08)
		tween.tween_property(actor,"model_stretch",Vector3.ONE,.16).set_trans(Tween.TRANS_BACK)

func idle_enemies()->Array[QuibletActor3D]:
	var result:Array[QuibletActor3D]=[]
	for enemy in enemies:
		if enemy.current_hp>0 and not enemy.get_meta("alerted",false):result.append(enemy)
	return result

# Chasing a target is a straight line by default, which walks a Quiblet into a
# river or wall whenever its target is on the far side. When the straight line
# is not walkable, the chaser follows a routed path instead, re-planned a few
# times a second as the target moves, and stops early once it has a clear line
# within its own attack reach. Player commands are never overridden by this.
const CHASE_REPLAN_SECONDS:=.35
var chase_replan_timer:=0.0
func update_chase_routing(delta:float)->void:
	chase_replan_timer-=delta
	var replan:bool=chase_replan_timer<=0.0
	if replan:chase_replan_timer=CHASE_REPLAN_SECONDS
	for actor in team+enemies:
		if actor.current_hp<=0 or not is_instance_valid(actor.target) or actor.target.current_hp<=0:
			if actor.get_meta("chase_routed",false):actor.set_meta("chase_routed",false);actor.command_path.clear();actor.has_command=false
			continue
		var from:=Vector2(actor.position.x,actor.position.z);var to:=Vector2(actor.target.position.x,actor.target.position.z)
		if line_walkable(from,to,actor.floats_over_water()):
			if actor.get_meta("chase_routed",false):actor.set_meta("chase_routed",false);actor.command_path.clear();actor.has_command=false
			continue
		if actor.has_command and not actor.get_meta("chase_routed",false):continue
		if actor.has_command and not replan:continue
		actor.follow_path(chase_path(actor,from,to));actor.set_meta("chase_routed",true)

# A Quiblet that stopped gaining ground gets a fresh route to wherever it was
# heading: the rest of its command, or its chase target. A chaser that was
# retreating gives that up too, since the retreat is what ran it into terrain.
func _on_actor_stuck(actor:QuibletActor3D)->void:
	if ended or actor.current_hp<=0:return
	var from:=Vector2(actor.position.x,actor.position.z)
	if actor.has_command:
		var goal:Vector3=actor.command_path.back() if not actor.command_path.is_empty() else actor.desired_point
		var routed:bool=actor.get_meta("chase_routed",false);var automatic:bool=actor.get_meta("auto_route",false)
		actor.follow_path(find_path(from,Vector2(goal.x,goal.z),actor.floats_over_water()))
		if routed:actor.set_meta("chase_routed",true)
		actor.set_meta("auto_route",automatic)
	elif is_instance_valid(actor.target) and actor.target.current_hp>0:
		actor.retreating=false
		actor.follow_path(chase_path(actor,from,Vector2(actor.target.position.x,actor.target.position.z)));actor.set_meta("chase_routed",true)

# The routed path toward a target, cut short at the first point that has a
# clear line to the target within the chaser's attack reach.
func chase_path(actor:QuibletActor3D,from:Vector2,to:Vector2)->Array[Vector3]:
	var path:=find_path(from,to,actor.floats_over_water());var reach:float=minf(actor.attack_range*.78,4.5)
	for i in path.size():
		var point:=Vector2(path[i].x,path[i].z)
		if point.distance_to(to)<=reach and line_walkable(point,to,actor.floats_over_water()):return path.slice(0,i+1)
	return path

# Keep pursuing the current opponent; only choose a new one when it is gone.
# Actual route length accounts for rivers and bridges when selecting a target.
func reachable_enemy(actor:QuibletActor3D,candidates:Array[QuibletActor3D])->QuibletActor3D:
	var from:=Vector2(actor.position.x,actor.position.z);var best:=INF;var chosen:QuibletActor3D=null
	var ordered:=candidates.duplicate()
	ordered.sort_custom(func(a,b):return actor.horizontal_distance(actor.position,a.position)<actor.horizontal_distance(actor.position,b.position))
	for enemy in ordered:
		var to:=Vector2(enemy.position.x,enemy.position.z)
		if from.distance_to(to)>=best:continue
		var path:=find_path(from,to,actor.floats_over_water())
		if path.is_empty():continue
		var distance:=0.0;var previous:=from
		for point in path:
			var next:=Vector2(point.x,point.z);distance+=previous.distance_to(next);previous=next
		if distance<best:best=distance;chosen=enemy
	return chosen

func update_team_targets()->void:
	var targets:=alerted_enemies()
	for actor in team:
		if actor.current_hp<=0:continue
		if not is_instance_valid(actor.target) or actor.target.current_hp<=0 or not targets.has(actor.target):
			actor.target=reachable_enemy(actor,targets)
		if is_instance_valid(actor.target) and actor.get_meta("auto_route",false):
			actor.command_path.clear();actor.has_command=false;actor.set_meta("auto_route",false)

var next_exploration_plan:=0.0
func update_exploration(living:Array)->void:
	if not exploring or ended or living.is_empty() or advance_index>=0:return
	if not alerted_enemies().is_empty():return
	# Explicit destinations take priority until reached. Automatic exploration
	# does not make idle teammates wait for a straggler's old route to finish.
	if living.any(func(member):return member.has_command and not member.get_meta("auto_route",false) and not member.get_meta("chase_routed",false)):return
	if elapsed<next_exploration_plan:return
	next_exploration_plan=elapsed+.75
	var idle:=idle_enemies()
	for member in living:
		if member.has_command:continue
		var goal:=reachable_enemy(member,idle)
		if goal==null:continue
		member.follow_path(find_path(Vector2(member.position.x,member.position.z),Vector2(goal.position.x,goal.position.z),member.floats_over_water()))
		member.set_meta("auto_route",true)

# --- The boss ---------------------------------------------------------------
# Once the field is clear the boss and its escorts appear in whichever arena is
# nearest the team. The camera pans over; a couple of seconds later the boss
# turns to face it, grunts, and stretches up then squashes down before the team arrives.
func nearest_arena_index()->int:
	var living:Array=team.filter(func(actor):return actor.current_hp>0)
	var centroid:Vector2=zones[0].center
	if not living.is_empty():
		centroid=Vector2.ZERO
		for member in living:centroid+=Vector2(member.position.x,member.position.z)
		centroid/=living.size()
	var best:=1;var best_distance:=INF
	for i in range(1,zones.size()):
		var distance:=centroid.distance_to(Vector2(zones[i].center))
		if distance<best_distance:best_distance=distance;best=i
	return best

func spawn_boss_wave()->void:
	var arena_index:=nearest_arena_index();var center:Vector2=zones[arena_index].center
	var team_scaled_cap:=maxi(1,ceili(team_data.size()*.75));var extra:=GameData.extra_enemies_for_area(stage_area_index)
	var count:=mini(2,team_scaled_cap)+extra+(1 if challenger else 0)+(BOSS_STAGE_EXTRA_ENEMIES if stage_kind=="boss" else 0)+1
	var scaling:=GameData.enemy_scaling(stage_area_index);var boss:QuibletActor3D=null
	for i in count:
		var is_level_boss:=i==count-1
		var level_boost:=(2 if challenger else (1 if fortune else 0))
		if stage_kind=="boss":level_boost+=BOSS_STAGE_BOSS_LEVEL_BOOST if is_level_boss else BOSS_STAGE_ENEMY_LEVEL_BOOST
		var q:=make_enemy((stage_area_index+stage_node_index+7+i)%GameData.SPECIES.size(),enemy_level(1));var actor:=QuibletActor3D.new();actor.setup(q,true,level_boost,-1,scaling)
		# The boss drops in too, but its landing squash is left to its own introduction.
		actor.position=Vector3(center.x-.65+(i%2)*1.3,0,center.y-1.6+(i/2)*1.6);actor.set_meta("zone",arena_index);actor.set_meta("alerted",false);place_actor(actor);enemies.append(actor);play_spawn_drop(actor,i*SPAWN_DROP_STAGGER,not is_level_boss)
		if is_level_boss:
			actor.set_meta("level_boss",true);var boss_scale:=BOSS_STAGE_BOSS_SCALE if stage_kind=="boss" else 1.3;actor.scale=Vector3.ONE*boss_scale;actor.max_hp*=BOSS_STAGE_BOSS_HP_MULTIPLIER if stage_kind=="boss" else 1.45;actor.current_hp=actor.max_hp;actor.damage_multiplier*=BOSS_STAGE_BOSS_DAMAGE_MULTIPLIER if stage_kind=="boss" else 1.12
			boss=actor
	exploring=true
	camera_pan_target=Vector3(center.x,0,center.y);camera_pan_time=BOSS_INTRO_PAN_SECONDS
	if boss!=null:boss_intro(boss)
	event_message.emit("The field is clear — a boss emerges in the nearest arena!")

func boss_intro(boss:QuibletActor3D)->void:
	await get_tree().create_timer(BOSS_INTRO_FACE_DELAY,false,true).timeout
	if ended or not is_instance_valid(boss) or boss.current_hp<=0:return
	if is_instance_valid(camera) and is_instance_valid(boss.model):
		var toward:=camera.global_position;toward.y=boss.model.global_position.y
		if toward.distance_to(boss.model.global_position)>.1:boss.model.look_at(toward,Vector3.UP,true)
	play_boss_grunt()
	# The Boss theme starts with the grunt, not with the spawn or the camera pan.
	boss_fight_started.emit()
	# The stretch and squash go through the actor's model_stretch multiplier
	# (the model's scale is rebuilt every tick, and the physics body itself must
	# stay uniformly scaled): up during the "errr", down during the "grrnt".
	var tween:=boss.create_tween()
	tween.tween_property(boss,"model_stretch",Vector3(.94,1.16,.94),.42).set_trans(Tween.TRANS_SINE)
	tween.tween_property(boss,"model_stretch",Vector3(1.08,.86,1.08),.42).set_trans(Tween.TRANS_SINE)
	tween.tween_property(boss,"model_stretch",Vector3.ONE,.3).set_trans(Tween.TRANS_BACK)

# A synthesised "errr… grrnt": a rising buzzy growl for the stretch, then a
# falling, raspier grunt for the squash. Generated once, no audio asset needed.
static func make_boss_grunt_stream()->AudioStreamWAV:
	var rate:=22050;var frames:=int(rate*.95);var data:=PackedByteArray();data.resize(frames*2)
	var phase:=0.0;var rasp_rng:=RandomNumberGenerator.new();rasp_rng.seed=7
	for i in frames:
		var t:=float(i)/rate;var first:=t<.45
		var frequency:=(78.0+t/.45*34.0) if first else (112.0-(t-.45)/.5*52.0)
		phase+=frequency/rate
		var buzz:=signf(sin(phase*TAU))*.5+sin(phase*TAU)*.3+sin(phase*TAU*2.0)*.22+sin(phase*TAU*3.0)*.1
		var rasp:=rasp_rng.randf_range(-1.0,1.0)*(.12 if first else .3)
		var envelope:=(minf(1.0,t/.08)*(1.0-(t/.45)*.25)) if first else lerpf(.9,0.0,pow((t-.45)/.5,.8))
		data.encode_s16(i*2,int(clampf((buzz+rasp)*envelope*.6,-1.0,1.0)*32767.0))
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.stereo=false;stream.data=data
	return stream

func play_boss_grunt()->void:
	if not is_instance_valid(boss_grunt_player):
		boss_grunt_player=AudioStreamPlayer.new();boss_grunt_player.name="BossGrunt";boss_grunt_player.stream=make_boss_grunt_stream();boss_grunt_player.volume_db=-3.0;add_child(boss_grunt_player)
	boss_grunt_player.play()

# One guardian idles in every other meadow, a little stronger than a regular enemy.
func spawn_grove_guardians()->void:
	var scaling:=GameData.enemy_scaling(stage_area_index);var guardian_index:=0
	for zone_index in range(GROVE_GUARDED_MEADOW_STEP,zones.size(),GROVE_GUARDED_MEADOW_STEP):
		var center:Vector2=zones[zone_index].center
		var q:=make_enemy((stage_area_index+stage_node_index+zone_index*2+guardian_index)%GameData.SPECIES.size(),enemy_level(-1))
		var actor:=QuibletActor3D.new();actor.setup(q,true,GROVE_GUARDIAN_LEVEL_BOOST+(2 if challenger else (1 if fortune else 0)),-1,scaling)
		actor.max_hp*=GROVE_GUARDIAN_HP_MULTIPLIER;actor.current_hp=actor.max_hp
		actor.position=Vector3(center.x,0,center.y-1.2);actor.set_meta("zone",zone_index);actor.set_meta("alerted",false);actor.set_meta("guardian",true);place_actor(actor);enemies.append(actor)
		guardian_index+=1
	begin_advance(1)
	event_message.emit("Gather every berry patch to finish the grove. Guardians roam the deeper meadows.")

func manual_move(actor:QuibletActor3D,index:int)->void:
	if ended:return
	if is_instance_valid(actor) and actor.current_hp>0:
		var new_target:=nearest(actor,enemies)
		actor.use_move(index,new_target)

func command_team(point:Vector3,from_player:=true)->void:
	if from_player:advance_index=-1
	var active:Array[QuibletActor3D]=team.filter(func(actor):return actor.current_hp>0)
	issue_route_command(point,active,not from_player)

func retreat()->void:
	var start:Vector2=zones[0].center if not zones.is_empty() else Vector2(-11,-4)
	for i in team.size():if team[i].current_hp>0:team[i].command(Vector3(start.x-2.0,0,start.y-1.8+i*.9))
	event_message.emit("Team is navigating to the safe exit…");await get_tree().create_timer(1.6).timeout;finish(false)

func give_up()->void:
	finish(false)

func _on_actor_defeated(actor:QuibletActor3D)->void:
	if actor.enemy:
		if actor.get_meta("level_boss",false):rout_escorts(actor)
		var ingredient:=GameData.roll_ingredient(stage_level);var amount:=int(ceil(randi_range(1,3)*(1.65 if challenger else 1.0)));loot[ingredient]+=amount
		reward_acquired.emit({"kind":"ingredient","name":ingredient,"amount":amount},actor.global_position)
		var stone_kind:=GameData.roll_enemy_stone_kind(actor.data)
		if stone_kind=="move_stone":
			var stone:Dictionary=GameData.MOVE_STONES.pick_random();var effect:String=stone.effect;move_stones[effect]=int(move_stones.get(effect,0))+1
			reward_acquired.emit({"kind":"move_stone","name":stone.name,"effect":effect,"amount":1,"texture":stone.texture},actor.global_position)
		elif stone_kind=="power_stone":
			var power_stone:=GameData.make_power_stone(["Health","Attack"].pick_random(),GameData.power_stone_tier_for_level(stage_level),GameData.roll_power_stone_bonuses(fortune));power_stones.append(power_stone)
			var reward:=power_stone.duplicate(true);reward.merge({"kind":"power_stone","name":power_stone.type+" Power Stone","amount":1})
			reward_acquired.emit(reward,actor.global_position)
		enemies.erase(actor);actor.queue_free()
		if enemies.is_empty() and not is_grove():
			if wave<max_waves:
				for member in team:
					if member.current_hp>0:member.receive_shared_heal(member.max_hp*.25)
				event_message.emit("Set beaten — the team catches its breath." if wave<max_waves-1 else "The field is clear. The team catches its breath as something stirs…")
			intermission=1.3
	else:
		event_message.emit("%s is knocked out — reviving in 10 seconds."%GameData.display_name(actor.data))
		if team.all(func(member):return member.knocked_out or member.current_hp<=0.0):finish(false)

# A fallen boss routs the rest of its wave: every surviving escort is defeated on
# the spot and drops exactly the loot it would have dropped in a fight. The boss
# itself is rewarded by the caller afterward, and the Boss theme keeps playing.
func rout_escorts(boss:QuibletActor3D)->void:
	for escort in enemies.duplicate():
		if escort==boss or escort.current_hp<=0:continue
		escort.current_hp=0.0
		event_message.emit("%s flees as the boss falls!"%GameData.display_name(escort.data))
		_on_actor_defeated(escort)

func _on_move_used(_actor:QuibletActor3D,_move_name:String,_new_target:QuibletActor3D,_details:Dictionary)->void:
	# MoveCast3D now owns visuals and collisions together. There is no separate
	# cosmetic projectile launched after instant damage.
	pass

func _unhandled_input(event:InputEvent)->void:
	if ended:return
	if not is_instance_valid(camera):return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var origin:=camera.project_ray_origin(event.position);var direction:=camera.project_ray_normal(event.position);var plane:=Plane(Vector3.UP,0);var hit=plane.intersects_ray(origin,direction)
		if hit==null:return
		var point:Vector3=hit
		command_team(point);get_viewport().set_input_as_handled()

func finish(victory:bool)->void:
	if ended:return
	ended=true
	set_process(false)
	for child in get_children():
		if child.has_method("finish") and child.get("caster_ref")!=null:child.finish(false)
	for actor in team+enemies:actor.cast_epoch+=1
	for team_actor in team:team_actor.set_physics_process(false)
	for enemy_actor in enemies:enemy_actor.set_physics_process(false)
	var exp_reward:=int((85+stage_level*18)*(1.8 if challenger else 1.0)) if victory else int(25+stage_level*4);var special:=""
	if victory:
		special=GameData.roll_special_item(stage_kind,fortune)
		if GameData.roll_treasure_key(stage_kind,fortune):extra_specials.append("Treasure Key")
	expedition_finished.emit({"victory":victory,"exp":exp_reward,"loot":loot,"move_stones":move_stones,"power_stones":power_stones,"special":special,"extra_specials":extra_specials.duplicate(),"berries":gathered,"elapsed":elapsed,"area_index":stage_area_index,"node_index":stage_node_index,"stage_kind":stage_kind})
