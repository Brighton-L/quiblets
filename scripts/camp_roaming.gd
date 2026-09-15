extends Node3D

const MODEL_SCALE:=1.3

var terrain:Node3D
var residents:Array[Dictionary]=[]
var grid:=AStarGrid2D.new()
var flight_grid:=AStarGrid2D.new()
var spots:Array[Vector2i]=[]
var rng:=RandomNumberGenerator.new()
var clock:=0.0

func setup(roster:Array,landscape:Node3D)->void:
	terrain=landscape;rng.randomize()
	grid.region=Rect2i(-34,-24,69,49);grid.cell_size=Vector2.ONE*.75
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	flight_grid.region=grid.region;flight_grid.cell_size=grid.cell_size;flight_grid.diagonal_mode=grid.diagonal_mode;flight_grid.update()
	for x in range(-34,35):
		for y in range(-24,25):
			var cell:=Vector2i(x,y);var point:=Vector2(cell)*.75
			var blocked:=not clear_ground(point)
			grid.set_point_solid(cell,blocked);flight_grid.set_point_solid(cell,not clear_ground(point,true))
			if not blocked:spots.append(cell)
	sync_roster(roster)

func resident_uid(q:Dictionary)->String:
	return str(q.get("uid","species_%s"%q.species))

func sync_roster(roster:Array)->void:
	var wanted:Array=roster.map(resident_uid)
	for resident in residents.duplicate():
		if not wanted.has(resident.uid):resident.body.queue_free();residents.erase(resident)
	for q in roster:
		var existing:Array=residents.filter(func(resident):return resident.uid==resident_uid(q))
		if not existing.is_empty():
			var resident:Dictionary=existing[0]
			if int(resident.species)!=int(q.species):
				resident.model.queue_free();var model:=QuibletModel3D.new();model.setup(int(q.species),false,MODEL_SCALE);resident.body.add_child(model);resident.model=model;resident.species=int(q.species)
			continue
		var cell:=spots[rng.randi_range(0,spots.size()-1)]
		for attempt in 80:
			cell=spots[rng.randi_range(0,spots.size()-1)]
			if residents.all(func(resident):return Vector2(resident.body.position.x,resident.body.position.z).distance_to(Vector2(cell)*.75)>2.6):break
		var point:=Vector2(cell)*.75
		var body:=Node3D.new();add_child(body);body.position=Vector3(point.x,resident_height(point,int(q.species)),point.y)
		var model:=QuibletModel3D.new();model.setup(int(q.species),false,MODEL_SCALE);body.add_child(model)
		adopt_resident(q,body,model)

func adopt_resident(q:Dictionary,body:Node3D,model:QuibletModel3D)->void:
	# The revealed model becomes the resident in place, retaining its transform.
	if body.get_parent()!=self:body.reparent(self,true)
	body.name="Resident%s"%body.get_instance_id()
	residents.append({"uid":resident_uid(q),"species":int(q.species),"body":body,"model":model,"path":PackedVector2Array(),"wait":rng.randf_range(.5,2.5),"speed":rng.randf_range(.65,1.05),"phase":rng.randf()*TAU})

func clear_ground(point:Vector2,flying:=false)->bool:
	# Leave room around the pot and expedition scenery.
	if point.length()<1.7:return false
	for child in terrain.get_children():
		if child is ExpeditionProp3D or child.has_meta("camp_obstacle_radius"):
			if point.distance_to(Vector2(child.position.x,child.position.z))<float(child.get_meta("camp_obstacle_radius",1.45)):return false
	for offset in [Vector2.ZERO,Vector2.LEFT*.4,Vector2.RIGHT*.4,Vector2.UP*.4,Vector2.DOWN*.4]:
		if not flying and terrain.terrain_height_at(point+offset)<-.1:return false
	return true

func _process(delta:float)->void:
	clock+=delta
	for resident in residents:
		var body:Node3D=resident.body;var model:QuibletModel3D=resident.model
		var path:PackedVector2Array=resident.path
		if path.is_empty():
			model.position.y=lerpf(model.position.y,0.0,minf(1.0,delta*8.0));model.rotation.z=lerpf(model.rotation.z,0.0,minf(1.0,delta*8.0))
			resident.wait=float(resident.wait)-delta
			if float(resident.wait)>0:continue
			var from:=Vector2i(roundi(body.position.x/.75),roundi(body.position.z/.75))
			for attempt in 12:
				var goal:=spots[rng.randi_range(0,spots.size()-1)]
				if Vector2(goal-from).length()<2.0 or Vector2(goal-from).length()>12.0:continue
				path=(flight_grid if floats(int(resident.species)) else grid).get_point_path(from,goal)
				if not path.is_empty():path.remove_at(0);break
			resident.path=path;resident.wait=rng.randf_range(1.0,3.5);continue
		var position2:=Vector2(body.position.x,body.position.z);var target:=path[0]
		var direction:=target-position2;var next:=position2.move_toward(target,float(resident.speed)*delta)
		body.position=Vector3(next.x,resident_height(next,int(resident.species)),next.y)
		body.rotation.y=lerp_angle(body.rotation.y,atan2(direction.x,direction.y),minf(1.0,delta*7.0))
		model.animate_walking(clock*8.0+float(resident.phase),.055,.035)
		if next.distance_to(target)<.015:path.remove_at(0);resident.path=path

func floats(species:int)->bool:return float(GameData.species(species).get("model_hover",0.0))>0.0
func resident_height(point:Vector2,species:int)->float:
	return terrain.flight_height_at(point) if floats(species) else terrain.terrain_height_at(point)
