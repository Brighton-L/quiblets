extends SceneTree
func _initialize():call_deferred("run")
func run():
 var starts:={};var signatures:={};var edges:={}
 for n in 32:
  var e:=Expedition3D.new();var rng:=RandomNumberGenerator.new();rng.seed=100+n
  e.layout_zones(rng)
  var point:Vector2=e.zones[0].center
  starts[str(point)]=true;signatures[str(e.zones)]=true
  var unit:Vector2=point/(Vector2(e.field_size())*.5-Vector2(8,8))
  edges[("left" if unit.x<0 else "right") if absf(unit.x)>absf(unit.y) else ("top" if unit.y<0 else "bottom")]=true
  for zone in e.zones:assert(e.field_rect.grow(-4).has_point(Vector2i(zone.center)))
  e.free()
 assert(starts.size()==32 and signatures.size()==32 and edges.size()==4)
 var last_seed:=-1;var last_signature:=""
 for n in 4:
  var e:=Expedition3D.new();root.add_child(e);e.set_process(false)
  # Repeated regular route, constrained cliffs, and a grove.
  e.stage_area_index=0 if n<2 else 3
  e.stage_kind="berry_grove" if n==3 else "level"
  e.build_level()
  assert(e.generated_map_seed!=last_seed)
  var signature:=str(e.zones)+str(e.rivers)
  assert(signature!=last_signature,"Replaying a node must rebuild its terrain and starts")
  last_seed=e.generated_map_seed;last_signature=signature
  var reachable:=e.reachable_walkable_cells()
  for zone in e.zones:
   assert(reachable.has(e.cell_of(zone.center)),"Every clearing must be reachable from the new start")
  var start:Vector2=e.zones[0].center
  for i in 5:
   var position:=start+Vector2(-.6+(i%2)*1.2,(i-2)*.9)
   assert(e.walkable.has(e.cell_of(position)),"Every initial team position needs solid ground")
  print("REPLAY_LAYOUT_CHECK ",n," seed=",e.generated_map_seed," start=",start)
  e.free();await process_frame
 print("REPLAY_LAYOUTS_OK: varied seeds/routes, all four start edges, connected clearings and safe team starts")
 quit()
