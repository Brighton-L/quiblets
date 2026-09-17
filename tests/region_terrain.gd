extends SceneTree
func _initialize():call_deferred("run")
func run():
 for index in GameData.EXPEDITION_AREAS.size():
  var e:=Expedition3D.new();root.add_child(e);e.set_process(false);e.stage_area_index=index;e.stage_node_index=0;e.stage_level=3;e.build_level()
  assert(e.zones_connected(),"Region route disconnected: "+GameData.EXPEDITION_AREAS[index])
  assert(not e.walkable.is_empty())
  if index==8:assert(e.river_channels==0,"Parched Plains should be dry")
  if index==2:assert(e.biome.river_width<4,"Creeks should be narrow")
  if index==11:assert(e.biome.river_width>5,"Fjord channels should be wide")
  print("REGION_OK ",index," ",GameData.EXPEDITION_AREAS[index]," cells=",e.walkable.size()," rivers=",e.river_channels)
  e.free();await process_frame
 quit()
