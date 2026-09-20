extends SceneTree
func _initialize():call_deferred("run")
func run():
 for node in [0,3,6]:
  var e:=Expedition3D.new();root.add_child(e);e.set_process(false);e.stage_area_index=2;e.stage_node_index=node;e.stage_level=3;e.build_level()
  assert(e.zones_connected(),"River changes must preserve crossing routes")
  var checked:=0
  for cell in e.rivers:
   if not e.in_field(cell) or e.waterfall_cells.has(cell):continue
   var point:=Vector2(cell)
   assert(e.raw_height_at(point)<e.WATER_LEVEL-.1,"Narrow river centre must stay submerged, including on hills")
   checked+=1
   for offset in [Vector2i.RIGHT,Vector2i.DOWN]:
    var next=cell+offset
    if not e.rivers.has(next) or not e.in_field(next) or e.waterfall_cells.has(next):continue
    assert(e.raw_height_at(point+Vector2(offset)*.5)<e.WATER_LEVEL-.1,"Connected river cells must not have a dry seam")
  assert(checked>100)
  print("Narrow river centres and seams submerged; crossings connected: node ",node," cells ",checked)
  e.free();await process_frame
 quit()
