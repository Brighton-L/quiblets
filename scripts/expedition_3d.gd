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
	grove_zone=1;exploring=false;camera_pan_time=0.0;used_spawn_points.clear()
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
	actor.arena=arena_rect;actor.obstacle_rects=obstacles;actor.defeated.connect(_on_actor_defeated);actor.move_used.connect(_on_move_used);actor.stuck.connect(_on_actor_stuck);add_child(actor)

func build_level()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=stage_area_index*1009+stage_node_index*131+73
	biome=GameData.expedition_biome(stage_area_index)
	fade_weights.clear();obstacles.clear();berry_nodes.clear();zones.clear();route_points.clear();corridor_widths.clear();walkable.clear();rivers.clear();bridges.clear();wall_tiers.clear();props.clear();prop_cells.clear();decor_count=0;cliff_tiers={1:0,2:0,3:0};cache_node=null
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
	build_terrain(rng)
	place_berry_patches(rng)
	place_treasure_cache(rng)

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
	for cell in walkable:
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
		var ingredient:=GameData.roll_ingredient(stage_level);var amount:=randi_range(3,6);loot[ingredient]+=amount
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
	if is_grove():return Vector2i(64,36)
	if stage_kind=="boss":return Vector2i(60,40)
	return Vector2i(52,36)

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

# Rivers: the biome's own channels run top to bottom, spread across the field,
# and zero to two extra rivers are added at random on top, some of them running
# left to right. Channels are one or two cells wide and meander. Every river
# gets a land bridge wherever the trail crosses it, so the route always stays
# connected, plus an occasional extra bridge elsewhere.
const EXTRA_RIVERS_MIN:=1
const EXTRA_RIVERS_MAX:=3
var river_channels:=0
var cliff_layer_count:=0
var river_flow:={}
func carve_rivers(rng:RandomNumberGenerator)->void:
	var base_count:int=int(biome.rivers);var river_count:int=base_count+rng.randi_range(EXTRA_RIVERS_MIN,EXTRA_RIVERS_MAX)
	river_channels=river_count;river_flow.clear()
	if river_count<=0:return
	var usable_left:=field_rect.position.x+7;var usable_right:=field_rect.end.x-8
	var usable_top:=field_rect.position.y+5;var usable_bottom:=field_rect.end.y-6
	if usable_right<=usable_left or usable_bottom<=usable_top:return
	for river_index in river_count:
		var horizontal:bool=river_index>=base_count and rng.randf()<.5
		# Two or three cells wide so the sunken water stays visible from the gameplay camera.
		var width:=2 if rng.randf()<.6 else 3;var drift:=rng.randf_range(-.35,.35)
		var cells:Array[Vector2i]=[]
		if horizontal:
			var z:=float(usable_top)+rng.randf()*float(usable_bottom-usable_top)
			for x in range(field_rect.position.x-1,field_rect.end.x+1):
				var wobble:=roundi(sin(float(x)*.22+float(river_index)*1.7)*1.3)+drift*float(x-field_rect.position.x)*.25
				var cz:=roundi(z+wobble)
				for w in width:cells.append(Vector2i(x,cz+w))
		else:
			var x:float
			if river_index<base_count:x=float(usable_left)+(float(river_index)+.5)/float(base_count)*float(usable_right-usable_left)+rng.randf_range(-1.5,1.5)
			else:x=float(usable_left)+rng.randf()*float(usable_right-usable_left)
			for z in range(field_rect.position.y-1,field_rect.end.y+1):
				var wobble:=roundi(sin(float(z)*.24+float(river_index)*1.7)*1.3)+drift*float(z-field_rect.position.y)*.5
				var cx:=roundi(x+wobble)
				for w in width:cells.append(Vector2i(cx+w,z))
		var flow:=Vector2(1,0) if horizontal else Vector2(0,1)
		for cell in cells:
			if bridges.has(cell):continue
			# Where the channel passes through a clearing the ground stays, as a bridge
			# slab with the water flowing on beneath it rather than a full block.
			if zones.any(func(zone):return Vector2(zone.center).distance_to(Vector2(cell))<2.6):
				if walkable.has(cell):bridges[cell]=true;river_flow[cell]=flow
				continue
			rivers[cell]=true;river_flow[cell]=flow;walkable.erase(cell)
		# Bridges where the trail crosses this river, then maybe one more.
		var bridge_keys:Array[int]=[]
		for i in range(1,zones.size()):
			var crossing=trail_crossing_cell(zones[i-1].center,zones[i].center,cells)
			if crossing!=null:
				var key:int=int((crossing as Vector2i).x if horizontal else (crossing as Vector2i).y)
				if not bridge_keys.has(key):bridge_keys.append(key)
		if rng.randf()<.5:bridge_keys.append(rng.randi_range(field_rect.position.x+2,field_rect.end.x-3) if horizontal else rng.randi_range(field_rect.position.y+2,field_rect.end.y-3))
		for key in bridge_keys:
			for cell in cells:
				var along:int=cell.x if horizontal else cell.y
				if absi(along-key)<=1:rivers.erase(cell);bridges[cell]=true;walkable[cell]=true
	# Safety net: if two rivers or an odd meander still cut a clearing off, bridge
	# every river cell along the straight line from the start to that clearing.
	var guard:=0
	while not zones_connected() and guard<8:
		guard+=1
		for zone in zones:
			var goal:Vector2=zone.center
			# Only the river cells nearest the clearing become a bridge, so a river
			# running alongside the line is crossed once instead of planked over.
			var crossing:Array=rivers.keys().filter(func(cell):return Geometry2D.get_closest_point_to_segment(Vector2(cell),zones[0].center,goal).distance_to(Vector2(cell))<1.0)
			crossing.sort_custom(func(a,b):return Vector2(a).distance_to(goal)<Vector2(b).distance_to(goal))
			for cell in crossing.slice(0,4):
				for offset in [Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(1,0)]:
					var span:Vector2i=cell+offset
					if rivers.has(span):rivers.erase(span);bridges[span]=true;walkable[span]=true

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
func raise_walls(rng:RandomNumberGenerator)->void:
	var area_scale:=float(field_rect.size.x*field_rect.size.y)/(30.0*22.0)
	var target:=roundi((2.0+14.0*float(biome.walls))*area_scale)
	var placed:=0;var attempts:=0
	while placed<target and attempts<target*12:
		attempts+=1
		var w:=rng.randi_range(1,3);var d:=rng.randi_range(1,3)
		var origin:=Vector2i(rng.randi_range(field_rect.position.x+1,field_rect.end.x-1-w),rng.randi_range(field_rect.position.y+1,field_rect.end.y-1-d))
		var cluster:Array[Vector2i]=[]
		for dx in w:
			for dz in d:cluster.append(origin+Vector2i(dx,dz))
		if cluster.any(func(cell):return not walkable.has(cell) or rivers.has(cell) or bridges.has(cell)):continue
		if cluster.any(func(cell):return zones.any(func(zone):return Vector2(zone.center).distance_to(Vector2(cell))<3.2)):continue
		if cluster.any(func(cell):return route_distance(Vector2(cell))<1.2):continue
		for cell in cluster:walkable.erase(cell)
		if not zones_connected():
			for cell in cluster:walkable[cell]=true
			continue
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

const HARVEST_BUNDLES:=2
const HARVEST_BUNDLE_RANGE:=Vector2i(4,8)
const BREAK_BUNDLE_RANGE:=Vector2i(2,4)

# Ingredients a prop grows: the stage-level roll restricted to its tags.
func prop_ingredient(prop)->String:
	var candidates:Array=[]
	for ingredient_name in GameData.INGREDIENTS:
		if GameData.INGREDIENTS[ingredient_name].tags.any(func(tag):return prop.harvest_tags().has(tag)):candidates.append(ingredient_name)
	return GameData.roll_ingredient(stage_level,candidates) if not candidates.is_empty() else GameData.roll_ingredient(stage_level)

func grant_prop_bundle(prop,bundle_range:Vector2i)->void:
	var ingredient:=prop_ingredient(prop);var amount:=randi_range(bundle_range.x,bundle_range.y);loot[ingredient]+=amount
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

func place_props(rng:RandomNumberGenerator)->void:
	var area_scale:=float(field_rect.size.x*field_rect.size.y)/(30.0*22.0)
	var target:=roundi((6.0+14.0*float(biome.density))*area_scale);var kinds:=prop_kinds()
	var candidates:Array[Vector2i]=[]
	for cell in walkable:
		var point:=Vector2(cell)
		if not cell_open(cell) or route_distance(point)<1.6:continue
		if zones.any(func(zone):return Vector2(zone.center).distance_to(point)<3.5):continue
		if bridges.keys().any(func(bridge):return Vector2(bridge).distance_to(point)<2.0):continue
		candidates.append(cell)
	shuffle_cells(candidates,rng)
	for cell in candidates:
		if props.size()>=target:break
		if prop_cells.keys().any(func(other):return Vector2(other).distance_to(Vector2(cell))<PROP_SPACING):continue
		walkable.erase(cell)
		if not zones_connected():walkable[cell]=true;continue
		var prop=PROP_SCRIPT.new();prop.setup(kinds[rng.randi_range(0,kinds.size()-1)],cell,biome,stage_level,rng)
		prop.destroyed.connect(_on_prop_destroyed);props_root.add_child(prop);props.append(prop);prop_cells[cell]=prop

func _on_prop_destroyed(prop)->void:
	prop_cells.erase(prop.cell);props.erase(prop);walkable[prop.cell]=true
	# Rebuild the obstacle runs in place so every actor's reference stays valid.
	obstacles.clear();build_obstacles()
	if prop.harvested:return
	# Broken by a move: a harvestable prop still drops a small bundle.
	if prop.HARVEST_TAGS.has(prop.kind) and not ended:grant_prop_bundle(prop,BREAK_BUNDLE_RANGE)
	event_message.emit("The %s breaks apart!"%prop.kind.replace("_"," "))

func props_in(center:Vector3,size:float)->Array:
	var result:Array=[]
	for prop in props:
		if not prop.shattered and Vector2(prop.position.x,prop.position.z).distance_to(Vector2(center.x,center.z))<=size+.6:result.append(prop)
	return result

func zones_connected()->bool:
	var start:=cell_of(zones[0].center);var seen:={start:true};var frontier:Array[Vector2i]=[start];var head:=0
	while head<frontier.size():
		var cell:Vector2i=frontier[head];head+=1
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next:Vector2i=cell+offset
			if walkable.has(next) and not seen.has(next):seen[next]=true;frontier.append(next)
	return zones.all(func(zone):return seen.has(cell_of(zone.center)))

func zone_index_at(point:Vector2)->int:
	for i in zones.size():
		var zone:Dictionary=zones[i];var center:Vector2=zone.center;var radius:Vector2=zone.radius
		var local:=(point-center)/radius
		if local.length()<=1.0+.1*sin(atan2(local.y,local.x)*3.0+float(zone.phase)):return i
	return -1

func route_distance(point:Vector2)->float:
	var best:=INF
	for i in route_points.size()-1:
		best=minf(best,point.distance_to(Geometry2D.get_closest_point_to_segment(point,route_points[i],route_points[i+1])))
	return best

func carve_walkable()->void:
	# The whole field is open ground; only the cliff ring outside it is solid.
	var grid_min:=Vector2i(field_rect.position.x-4,field_rect.position.y-4);var grid_max:=Vector2i(field_rect.end.x-1+4,field_rect.end.y-1+4)
	for x in range(field_rect.position.x,field_rect.end.x):
		for z in range(field_rect.position.y,field_rect.end.y):walkable[Vector2i(x,z)]=true
	set_meta("grid_min",grid_min);set_meta("grid_max",grid_max)

func build_obstacles()->void:
	var min_cell:=Vector2i(1<<30,1<<30);var max_cell:=Vector2i(-(1<<30),-(1<<30))
	for cell in walkable:min_cell=Vector2i(mini(min_cell.x,cell.x),mini(min_cell.y,cell.y));max_cell=Vector2i(maxi(max_cell.x,cell.x),maxi(max_cell.y,cell.y))
	arena_rect=Rect2(min_cell.x-.5,min_cell.y-.5,max_cell.x-min_cell.x+1.0,max_cell.y-min_cell.y+1.0)
	# Blocked cells become row runs so the actors' obstacle checks stay cheap.
	for z in range(min_cell.y-1,max_cell.y+2):
		var run_start:=min_cell.x-1
		for x in range(min_cell.x-1,max_cell.x+3):
			var blocked:=x<=max_cell.x+1 and not walkable.has(Vector2i(x,z))
			if blocked:continue
			if x>run_start:obstacles.append(Rect2(run_start-.5,z-.5,x-run_start,1.0))
			run_start=x+1

# --- Smooth terrain ------------------------------------------------------------
# The world is no longer drawn as tiles. The gameplay grid (walkable cells,
# rivers, walls) still decides where Quiblets can go, but the ground is one
# continuous heightfield: open ground is a flat plain, blocked cells rise into
# rounded hills whose height grows with the distance from the nearest open
# ground, and rivers sink into soft troughs. Nothing in the mesh follows a cell edge.
const TERRAIN_SUBDIV:=3
# A hill climbs over this run at most; thinner walls become lower, rounder bumps
# (their height is capped by their half-thickness) so slopes stay gentle.
const HILL_RAMP:=3.2
const HILL_MIN_HALF:=.55
const HILL_THICKNESS_GAIN:=.8
const HILL_THICKNESS_BASE:=.2
const RIVER_RAMP:=.9
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
			if walkable.has(cell) or prop_cells.has(cell):terrain_heights[cell]=0.0;ground_tile_count+=1;continue
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
	var classes:=PackedByteArray();classes.resize(sample_count)
	for r in height_rows:
		for c in height_cols:
			var cell:=Vector2i(grid_min.x+mini(c/subdiv,grid_max.x-grid_min.x),grid_min.y+mini(r/subdiv,grid_max.y-grid_min.y))
			var h:float=float(terrain_heights.get(cell,0.0))
			classes[r*height_cols+c]=0 if h==0.0 else (1 if h<0.0 else 2)
	# Distance from every water or hill sample to the nearest sample of another class.
	var water_edge:=edge_distance(classes,1,step);var hill_edge:=edge_distance(classes,2,step)
	terrain_classes=classes;water_edge_field=water_edge;hill_edge_field=hill_edge
	# Each hill sample's ridge distance: the greatest edge distance nearby, i.e. how
	# thick the hill is around it. Thin walls peak low and round; thick masses climb the full ramp.
	var ridge:=local_max(hill_edge,2*subdiv)
	height_field.resize(sample_count)
	for r in height_rows:
		for c in height_cols:
			var index:=r*height_cols+c;var point:=height_origin+Vector2(c,r)*step
			# The same cell the sample was classified by (floor mapping), never a rounded neighbour.
			var cell:=Vector2i(grid_min.x+mini(c/subdiv,grid_max.x-grid_min.x),grid_min.y+mini(r/subdiv,grid_max.y-grid_min.y))
			var kind:int=classes[index];var h:=0.0
			if kind==1:
				var depth:float=-float(terrain_heights.get(cell,-RIVER_DEPTH))
				h=-depth*smoothstep(0.0,RIVER_RAMP,float(water_edge[index]))
			elif kind==2:
				var half:float=maxf(HILL_MIN_HALF,float(ridge[index]))
				var rise:=smoothstep(0.0,minf(HILL_RAMP,half),float(hill_edge[index]))
				var peak:float=minf(peak_at(point,cell,peaks),HILL_THICKNESS_BASE+half*HILL_THICKNESS_GAIN)
				h=(peak+HILL_ROLL*sin(point.x*.9+.3)*sin(point.y*.8+1.1)*minf(1.0,peak*.5))*rise
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
		if rim and (tier==1 or wall_tiers.has(cell)) and decor_count<MAX_DECOR and rng.randf()<float(biome.density):add_decor(Vector3(cell.x,terrain_height_at(Vector2(cell)),cell.y),rng)
	build_rivers(rng)

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

# Height of the ground surface at any point (bilinear over the sample grid).
func terrain_height_at(point:Vector2)->float:
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

func build_terrain_mesh(classes:PackedByteArray,water_edge:PackedFloat32Array,hill_edge:PackedFloat32Array,_rng:RandomNumberGenerator)->void:
	var ground:Color=biome.ground;var path:Color=biome.path;var cliff:Color=biome.cliff;var bed:Color=Color("#2a1d14")
	var hill_grass:Color=ground.darkened(.06);var step:=1.0/float(TERRAIN_SUBDIV)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in height_rows:
		for c in height_cols:
			var index:=r*height_cols+c;var point:=height_origin+Vector2(c,r)*step;var h:float=height_field[index]
			# Normal from central differences; slope drives the grass-to-dirt blend on hills.
			var dx:float=(sample_height(c+1,r)-sample_height(c-1,r))/(2.0*step);var dz:float=(sample_height(c,r+1)-sample_height(c,r-1))/(2.0*step)
			var normal:=Vector3(-dx,1.0,-dz).normalized();var slope:=Vector2(dx,dz).length()
			var mottle:=sin(point.x*.42+point.y*.17)*sin(point.y*.39-point.x*.11)
			var shade:float=.045 if mottle>.15 else (-.03 if mottle<-.35 else 0.0)
			var color:Color
			match int(classes[index]):
				0:color=path if route_distance(point)<2.1+sin(point.x*.9+point.y*.6)*.5 else ground
				1:color=ground.lerp(bed,smoothstep(0.0,RIVER_RAMP,float(water_edge[index])))
				_:color=hill_grass.lerp(cliff,smoothstep(1.3,2.0,slope)).lightened(clampf(h*.025,0.0,.08))
			color=color.darkened(maxf(shade,0.0)).lightened(maxf(-shade,0.0))
			st.set_normal(normal);st.set_color(color);st.set_uv(Vector2(point.x,point.y));st.add_vertex(Vector3(point.x,h,point.y))
	for r in height_rows-1:
		for c in height_cols-1:
			var i00:=r*height_cols+c;var i10:=i00+1;var i01:=i00+height_cols;var i11:=i01+1
			# Godot front faces wind so the geometric normal points away from the viewer's side (down, here).
			for index in [i00,i10,i01,i10,i11,i01]:st.add_index(index)
	var mesh:=st.commit()
	terrain_material=ShaderMaterial.new();terrain_material.shader=terrain_shader()
	terrain_fade_material=ShaderMaterial.new();terrain_fade_material.shader=terrain_fade_shader();terrain_material.next_pass=terrain_fade_material
	for material in terrain_materials():material.set_shader_parameter("detail",GameData.terrain_tile_texture());material.set_shader_parameter("fade_count",0)
	terrain_mesh=MeshInstance3D.new();terrain_mesh.name="TerrainMesh";terrain_mesh.mesh=mesh;terrain_mesh.material_override=terrain_material;add_child(terrain_mesh)

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
const WALL_FADE_SPEED:=5.0
const WALL_FADE_RADIUS:=1.4
const WALL_RAY_STEP:=.4
const MAX_FADE_POINTS:=16
var fade_weights:={}
var terrain_fade_material:ShaderMaterial
const TERRAIN_SHADER_COMMON:="""
uniform sampler2D detail:filter_nearest,repeat_enable;
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
	ALBEDO=pow(tint.rgb,vec3(2.2))*texture(detail,UV).rgb;ROUGHNESS=.95;
}
"""
const TERRAIN_FADE_SHADER:="""
shader_type spatial;
render_mode cull_back,blend_mix,depth_draw_never;
"""+TERRAIN_SHADER_COMMON+"""
void fragment(){
	float f=fade_factor();
	if(f<=.02)discard;
	ALBEDO=pow(tint.rgb,vec3(2.2))*texture(detail,UV).rgb;ROUGHNESS=.95;ALPHA=1.0-f*(1.0-fade_alpha);
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
	if not is_instance_valid(camera) or height_field.is_empty():return false
	var from:Vector3=actor.global_position+Vector3(0,.5,0);var eye:Vector3=camera.global_position
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
const WATER_SHADER:="""
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform float flow_speed=1.4;
uniform float crest_scale=1.6;
uniform float crest_strength=.42;
uniform float drift=0.0;
varying vec3 world_pos;
varying vec4 flow;
varying vec4 tint;
void vertex(){
	flow=INSTANCE_CUSTOM;tint=COLOR;
	vec3 shift=vec3(flow.x,0.0,flow.y)*fract(TIME*flow_speed*.35+flow.z)*drift;
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX+=(inverse(mat3(MODEL_MATRIX))*shift)*(1.0/max(length(MODEL_MATRIX[0].xyz),.001))*length(MODEL_MATRIX[0].xyz);
	VERTEX.y+=sin(world_pos.x*1.7+world_pos.z*1.3+TIME*2.2)*.025/max(length(MODEL_MATRIX[1].xyz),.001);
}
void fragment(){
	float along=dot(world_pos.xz,flow.xy);
	float wave=sin(along*crest_scale*3.14159-TIME*flow_speed*3.0+flow.z*6.283);
	float second=sin(along*crest_scale*7.1+dot(world_pos.xz,vec2(-flow.y,flow.x))*2.3-TIME*flow_speed*4.7);
	float crest=smoothstep(.55,.95,wave)*.7+smoothstep(.7,1.0,second)*.3;
	vec3 base=pow(tint.rgb,vec3(2.2));  // instance colour is sRGB
	ALBEDO=mix(base,base+vec3(.4),crest*crest_strength*2.0);
	ALPHA=tint.a;ROUGHNESS=.2;METALLIC=.1;EMISSION=base*.15+vec3(.25)*crest*crest_strength;
}
"""
func flowing_water_material(for_ripples:bool)->ShaderMaterial:
	var shader:=Shader.new();shader.code=WATER_SHADER
	var material:=ShaderMaterial.new();material.shader=shader
	material.set_shader_parameter("drift",.9 if for_ripples else 0.0);material.set_shader_parameter("crest_strength",.25 if for_ripples else .42)
	return material

# River channels are proper divots: a dark bed RIVER_DEPTH below the ground,
# soil banks down every edge that meets ground, a translucent glossy water
# slab just above the bed with a scatter of pale ripple slivers, and plank
# bridges that span the gap at ground level.
const RIVER_DEPTH:=1.3
func build_rivers(rng:RandomNumberGenerator)->void:
	if rivers.is_empty() and pond_cells.is_empty():return
	var water:Color=biome.water_color
	var water_entries:Array[Dictionary]=[];var ripple_entries:Array[Dictionary]=[]
	# Flat water sheets sit in the troughs: rivers at their depth, ponds shallower.
	# The trough itself is the terrain mesh, so there is no separate bed to draw.
	for cell in rivers.keys()+pond_cells.keys():
		var x:=float(cell.x);var z:=float(cell.y);var checker:=.03 if (cell.x+cell.y)%2==0 else 0.0
		var water_top:float=(-RIVER_DEPTH+.28) if rivers.has(cell) else (-POND_DEPTH+.22)
		var flow:Vector2=river_flow.get(cell,Vector2(0,1));var flow_data:=Color(flow.x,flow.y,rng.randf(),0)
		water_entries.append({"transform":Transform3D(Basis.IDENTITY.scaled(Vector3(1,.16,1)),Vector3(x,water_top-.08,z)),"color":Color(water.r,water.g,water.b,.88).darkened(checker),"custom":flow_data})
		# Long pale streaks along the flow, like the reference's white water lines.
		if rivers.has(cell) and rng.randf()<.3:
			var streak:=Vector3(rng.randf_range(.9,1.6),.02,rng.randf_range(.05,.08))
			ripple_entries.append({"transform":Transform3D(Basis.IDENTITY.scaled(streak).rotated(Vector3.UP,atan2(flow.y,flow.x)*-1.0+rng.randf_range(-.08,.08)),Vector3(x+rng.randf_range(-.2,.2),water_top+.02,z+rng.randf_range(-.2,.2))),"color":Color("#f4fbff"),"custom":flow_data})
	var water_node:=build_multimesh("RiverWater",BoxMesh.new(),water_entries);water_node.material_override=flowing_water_material(false)
	var ripples:=build_multimesh("RiverRipples",BoxMesh.new(),ripple_entries);ripples.material_override=flowing_water_material(true)

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
func add_decor(pos:Vector3,rng:RandomNumberGenerator)->void:
	decor_count+=1
	var accent:Color=biome.accent;var cliff:Color=biome.cliff
	var kinds:Array=biome.decor if biome.decor is Array else [str(biome.decor)]
	match str(kinds[rng.randi_range(0,kinds.size()-1)]):
		"tree":add_tree(pos)
		"bush":add_bush(pos)
		"rock":add_box(pos+Vector3(0,.24,0),Vector3(rng.randf_range(.4,.6),.45,rng.randf_range(.4,.6)),rock_color())
		"boulder":
			var size:=rng.randf_range(.9,1.4);var rock:=add_box(pos+Vector3(0,size*.45,0),Vector3(size,size*.9,size*.95),rock_color());rock.rotation.y=rng.randf_range(-.3,.3)
			add_box(pos+Vector3(size*.45,size*.25,size*.2),Vector3(size*.5,size*.5,size*.5),rock_color().darkened(.08))
		"big_mushroom":
			var height:=rng.randf_range(1.4,2.1);add_box(pos+Vector3(0,height*.5,0),Vector3(.4,height,.4),GameData.COLORS.cream)
			add_sphere(pos+Vector3(0,height+.1,0),Vector3(1.4,.5,1.4),accent);add_sphere(pos+Vector3(.5,height+.35,.3),Vector3(.25,.12,.25),GameData.COLORS.cream)
		"block":
			var block:=add_box(pos+Vector3(0,.55,0),Vector3(1.1,1.1,1.1),cliff.lightened(.12));block.rotation.y=rng.randf_range(-.4,.4)
		"crystal":
			var crystal:=add_box(pos+Vector3(0,.7,0),Vector3(.35,1.5,.35),accent);crystal.rotation=Vector3(.15,rng.randf()*TAU,.1)
		"pillar":add_box(pos+Vector3(0,1.05,0),Vector3(.7,2.2,.7),cliff.lightened(.1))
		"cactus":add_box(pos+Vector3(0,.7,0),Vector3(.4,1.4,.4),accent);add_box(pos+Vector3(.35,.9,0),Vector3(.3,.6,.3),accent)
		"mushroom":add_box(pos+Vector3(0,.35,0),Vector3(.25,.7,.25),GameData.COLORS.cream);add_sphere(pos+Vector3(0,.8,0),Vector3(.55,.25,.55),accent)
		_:add_sphere(pos+Vector3(0,.2,0),Vector3(.6,.35,.6),accent)

# Rocks are neutral grey with a touch of the island's cliff tone, never plain dirt.
func rock_color()->Color:
	if biome.has("rock"):return Color(biome.rock)
	return Color("#b7bfb4").lerp(Color(biome.cliff),.12)

# Birch-striped trunks on islands that ask for them, plain brown otherwise.
func add_trunk(pos:Vector3,height:float,width:float)->void:
	if str(biome.get("trunk",""))=="birch":
		var bands:int=maxi(2,roundi(height/.3))
		for i in bands:add_box(pos+Vector3(0,(float(i)+.5)*height/float(bands),0),Vector3(width,height/float(bands),width),Color("#e9e6dc") if i%2==0 else Color("#7f9a6a"),"trunk")
	else:add_box(pos+Vector3(0,height*.5,0),Vector3(width,height,width),Color("#8a5b36"),"trunk")

func add_box(pos:Vector3,size:Vector3,color:Color,detail:="specks")->MeshInstance3D:
	var mesh:=GameData.rounded_box(size,minf(size.x,minf(size.y,size.z))*.2);var node:=MeshInstance3D.new();node.mesh=mesh;node.position=pos;var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.88
	if detail=="specks":GameData.apply_prop_specks(mat)
	else:GameData.apply_detail(mat,detail)
	node.material_override=mat;(decor_root if is_instance_valid(decor_root) else self).add_child(node);return node

func add_sphere(pos:Vector3,size:Vector3,color:Color)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=GameData.leaf_sphere();node.position=pos;node.scale=size*2.0;var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.9;node.material_override=mat;(decor_root if is_instance_valid(decor_root) else self).add_child(node);return node

# Rim trees match the field props: either a tall column tree (a slim trunk under
# a tall dark canopy) or a big round one (a wide bright canopy with a smaller cube on top).
# Canopies and shrubs are clusters of many overlapping leaf spheres in slightly
# different shades (the same recipe the field props use), so every tree still
# rolls its own shape, size, and tint from its position.
func add_leaf_cluster(center:Vector3,extent:Vector3,count:int,radius:float,leaf:Color,rng:RandomNumberGenerator)->void:
	for entry in GameData.leaf_cluster(center,extent,count,radius,leaf,rng):add_sphere(entry.pos,Vector3.ONE*float(entry.radius),entry.color)

func add_tree(pos:Vector3)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=int(absf(pos.x*1327.0+pos.z*7919.0))+stage_area_index
	var leaf:Color=biome.get("accent",Color("#3f7650")).lightened(rng.randf_range(-.06,.1))
	if rng.randf()<.5:
		var height:=rng.randf_range(1.6,2.6);var width:=rng.randf_range(.8,1.15);var trunk_height:=rng.randf_range(.6,1.1)
		add_trunk(pos,trunk_height,.3)
		add_leaf_cluster(pos+Vector3(0,trunk_height-.05+height*.5,0),Vector3(width*.5,height*.5,width*.5),9,width*.42,leaf.darkened(.1),rng)
		add_leaf_cluster(pos+Vector3(0,trunk_height+height+.05,0),Vector3(width*.3,.2,width*.3),3,width*.28,leaf.darkened(.02),rng)
	else:
		var width:=rng.randf_range(1.4,2.0);var height:=rng.randf_range(1.2,1.7);var trunk_height:=rng.randf_range(.8,1.2)
		add_trunk(pos,trunk_height,.36)
		add_leaf_cluster(pos+Vector3(0,trunk_height-.05+height*.5,0),Vector3(width*.5,height*.5,width*.5*rng.randf_range(.85,1.0)),13,width*.3,leaf.lightened(.1),rng)
		add_leaf_cluster(pos+Vector3(rng.randf_range(-.25,.25),trunk_height+height+.15,rng.randf_range(-.2,.2)),Vector3(width*.25,.2,width*.25),4,width*.2,leaf.lightened(.18),rng)

func add_bush(pos:Vector3)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=int(absf(pos.x*911.0+pos.z*4177.0))+stage_area_index
	var leaf:Color=biome.get("accent",Color("#3f7650")).darkened(.08)
	add_leaf_cluster(pos+Vector3(0,.42,0),Vector3(.48,.3,.45),6,.3,leaf,rng)
	add_leaf_cluster(pos+Vector3(.08,.82,.04),Vector3(.25,.1,.22),3,.2,leaf.lightened(.08),rng)

# Each patch is rolled its ingredient up front and is shaped after it, so the
# team can tell from a distance what a patch is likely to give. Any resource can
# grow anywhere; Berry Groves lean toward the four berries (GROVE_BERRY_SHARE of
# their patches) while regular and Boss levels roll from the whole list.
const BERRY_INGREDIENTS:=["Bumbleberry","Dewmelon","Frostberry","Sunplum"]
const GROVE_BERRY_SHARE:=.6
func add_berry_patch(pos:Vector3)->void:
	var berry_only:bool=is_grove() and randf()<GROVE_BERRY_SHARE
	var patch:=Node3D.new();patch.position=pos;patch.set_meta("ingredient",GameData.roll_ingredient(stage_level,BERRY_INGREDIENTS if berry_only else []))
	patch.set_meta("zone",patch_zone(Vector2(pos.x,pos.z)))
	build_berry_patch_shape(patch,str(patch.get_meta("ingredient")))
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

# One recognisable plant per resource. Every ingredient in GameData.INGREDIENTS
# has its own branch; the fallback only guards against unknown names.
func build_berry_patch_shape(patch:Node3D,ingredient:String)->void:
	var color:Color=GameData.INGREDIENTS.get(ingredient,{}).get("color",GameData.COLORS.berry)
	var leaf:Color=GameData.COLORS.leaf;var dark_leaf:Color=GameData.COLORS.leaf_dark;var soil:=Color("#6b4b30")
	patch.set_meta("shape",ingredient)
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
	for cell in walkable:
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
	if intermission>0:
		intermission-=delta
		if intermission<=0:
			if wave>=max_waves:finish(true)
			else:spawn_wave()
	var living:Array=team.filter(func(actor):return actor.current_hp>0)
	# The team only engages enemies that have noticed it, so a distant idle group
	# never drags the team straight across rivers and walls; exploration routes
	# the team to the next group along walkable ground instead.
	var targets:Array[QuibletActor3D]=alerted_enemies()
	for actor in team:
		if actor.current_hp>0:actor.target=nearest(actor,targets)
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
	update_advance(living)
	for patch in berry_nodes.duplicate():
		for actor in team:
			if actor.current_hp>0 and actor.horizontal_distance(actor.position,patch.position)<1.1:
				var amount:=randi_range(3,6);var ingredient:String=patch.get_meta("ingredient");loot[ingredient]+=amount;gathered+=1
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
		if enemy.get_meta("alerted",false):result.append(enemy)
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

func issue_route_command(point:Vector3,living:Array)->void:
	for i in living.size():
		var spacing:=(float(i)-float(living.size()-1)*.5)*.9;var goal:=point+Vector3(spacing,0,0)
		living[i].follow_path(find_path(Vector2(living[i].position.x,living[i].position.z),Vector2(goal.x,goal.z)))

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
func line_walkable(a:Vector2,b:Vector2)->bool:
	var steps:=maxi(1,ceili(a.distance_to(b)/.25))
	for i in steps+1:
		var p:=a.lerp(b,float(i)/steps)
		for offset in [Vector2.ZERO,Vector2(.4,0),Vector2(-.4,0),Vector2(0,.4),Vector2(0,-.4)]:
			if not walkable.has(cell_of(p+offset)):return false
	return true

func find_path(from:Vector2,to:Vector2)->Array[Vector3]:
	# Targets on cliffs or in one-tile nooks are moved to the nearest open cell.
	var goal_cell:=nearest_open_cell(to);var goal:=to if cell_open(cell_of(to)) else Vector2(goal_cell)
	var direct:Array[Vector3]=[Vector3(goal.x,0,goal.y)]
	if walkable.is_empty() or line_walkable(from,goal):return direct
	var start_cell:=nearest_walkable_cell(from)
	var parents:={start_cell:start_cell};var frontier:Array[Vector2i]=[start_cell];var head:=0
	while head<frontier.size() and not parents.has(goal_cell):
		var cell:Vector2i=frontier[head];head+=1
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next:Vector2i=cell+offset
			if walkable.has(next) and not parents.has(next):parents[next]=cell;frontier.append(next)
	if not parents.has(goal_cell):return direct
	var cells:Array[Vector2]=[];var cursor:=goal_cell
	while cursor!=start_cell:cells.push_front(Vector2(cursor));cursor=parents[cursor]
	cells.append(goal)
	var path:Array[Vector3]=[];var anchor:=from;var index:=0
	while index<cells.size():
		var furthest:=cells.size()-1
		while furthest>index and not line_walkable(anchor,cells[furthest]):furthest-=1
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
	var result:QuibletActor3D;var best:=INF
	for candidate in pool:
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
		if line_walkable(from,to):
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
		var routed:bool=actor.get_meta("chase_routed",false)
		actor.follow_path(find_path(from,Vector2(goal.x,goal.z)))
		if routed:actor.set_meta("chase_routed",true)
	elif is_instance_valid(actor.target) and actor.target.current_hp>0:
		actor.retreating=false
		actor.follow_path(chase_path(actor,from,Vector2(actor.target.position.x,actor.target.position.z)));actor.set_meta("chase_routed",true)

# The routed path toward a target, cut short at the first point that has a
# clear line to the target within the chaser's attack reach.
func chase_path(actor:QuibletActor3D,from:Vector2,to:Vector2)->Array[Vector3]:
	var path:=find_path(from,to);var reach:float=minf(actor.attack_range*.78,4.5)
	for i in path.size():
		var point:=Vector2(path[i].x,path[i].z)
		if point.distance_to(to)<=reach and line_walkable(point,to):return path.slice(0,i+1)
	return path

func update_exploration(living:Array)->void:
	if not exploring or ended or living.is_empty() or advance_index>=0:return
	if enemies.any(func(enemy):return enemy.current_hp>0 and enemy.get_meta("alerted",false)):return
	if living.any(func(member):return member.has_command):return
	var centroid:=Vector3.ZERO
	for member in living:centroid+=member.position
	centroid/=living.size()
	var goal:QuibletActor3D=null;var best:=INF
	for enemy in idle_enemies():
		var distance:=centroid.distance_to(enemy.position)
		if distance<best:best=distance;goal=enemy
	if goal==null:return
	var center:Vector2=goal.get_meta("alert_center",Vector2(goal.position.x,goal.position.z))
	issue_route_command(Vector3(center.x,0,center.y),living)

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
	issue_route_command(point,active)

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
