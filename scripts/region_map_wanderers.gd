extends Node3D

var terrain:RegionMap3D
var grid:=AStarGrid2D.new()
var spots:Dictionary={}
var residents:Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var clock:=0.0

func setup(team:Array,island:RegionMap3D,areas:Array[int])->void:
 terrain=island;rng.seed=1771
 grid.region=Rect2i(-43,-32,87,64);grid.cell_size=Vector2.ONE
 grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
 for area in areas:spots[area]=[]
 var scenery:Array=[]
 for child in terrain.get_children():
  if child.get_meta("map_scenery",false):scenery.append(Vector2(child.position.x,child.position.z))
 for x in range(-43,44):
  for y in range(-32,32):
   var cell:=Vector2i(x,y);var point:=Vector2(cell);var area:=terrain.region_at(point)
   var blocked:=not spots.has(area) or terrain.coastline(point)<.18
   if not blocked:blocked=scenery.any(func(other):return other.distance_squared_to(point)<.7)
   grid.set_point_solid(cell,blocked)
   if not blocked:spots[area].append(cell)
 var available:Array=areas.filter(func(area):return not spots[area].is_empty())
 if available.is_empty():return
 for i in team.size():
  var area:int=available[i%available.size()];var cells:Array=spots[area]
  var cell:Vector2i=cells[rng.randi_range(0,cells.size()-1)]
  var body:=Node3D.new();body.name="MapTeamMember%d"%i;add_child(body)
  body.position=Vector3(cell.x,terrain.height_at(Vector2(cell)),cell.y)
  var model:=QuibletModel3D.new();model.setup(int(team[i].species),false,.95);body.add_child(model)
  residents.append({"body":body,"model":model,"area":area,"path":PackedVector2Array(),"wait":rng.randf_range(.1,.8),"phase":rng.randf()*TAU,"floating":float(GameData.species(int(team[i].species)).get("model_hover",0.0))>0})

func _process(delta:float)->void:
 clock+=delta
 for resident in residents:
  var body:Node3D=resident.body;var model:QuibletModel3D=resident.model
  var path:PackedVector2Array=resident.path
  if path.is_empty():
   model.position.y=lerpf(model.position.y,0.0,minf(1.0,delta*8));model.rotation.z=lerpf(model.rotation.z,0.0,minf(1.0,delta*8))
   resident.wait=float(resident.wait)-delta
   if resident.wait>0:continue
   var from:=Vector2i(roundi(body.position.x),roundi(body.position.z));var cells:Array=spots[resident.area]
   for attempt in 12:
    var goal:Vector2i=cells[rng.randi_range(0,cells.size()-1)]
    if Vector2(goal-from).length()<2 or Vector2(goal-from).length()>7:continue
    path=grid.get_point_path(from,goal)
    if not path.is_empty():path.remove_at(0);break
   resident.path=path;resident.wait=rng.randf_range(.6,2.2);continue
  var point:=Vector2(body.position.x,body.position.z);var direction:=path[0]-point
  var next:=point.move_toward(path[0],delta*1.25)
  body.position=Vector3(next.x,terrain.height_at(next),next.y)
  if direction.length_squared()>.001:body.rotation.y=lerp_angle(body.rotation.y,atan2(direction.x,direction.y),minf(1,delta*7))
  if not resident.floating:model.animate_walking(clock*8+resident.phase,.05,.025)
  if next.distance_to(path[0])<.02:path.remove_at(0);resident.path=path
