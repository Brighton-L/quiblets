extends SceneTree
func _initialize():
 var island:=RegionMap3D.new()
 for i in GameData.MAIN_AREA_COUNT:island.visible_regions.append(i)
 var land:={};var bays:=0
 for x in range(-82,83):
  for z in range(-64,64):
   var point:=Vector2(x,z)*.5
   if island.coastline(point)>0:land[Vector2i(x,z)]=true
   elif Vector2(point.x/(17.0*RegionMap3D.MAP_SCALE),(point.y+2.0)/(15.0*RegionMap3D.MAP_SCALE)).length()<1.0:bays+=1
 assert(bays>400,"Regional shapes should leave substantial bays inside the former round outline")
 var start:=Vector2i(RegionMap3D.center(0)*2)
 var seen:={start:true};var frontier:Array[Vector2i]=[start];var head:=0
 while head<frontier.size():
  var cell:=frontier[head];head+=1
  for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next:Vector2i=cell+offset
   if land.has(next) and not seen.has(next):seen[next]=true;frontier.append(next)
 for i in GameData.MAIN_AREA_COUNT:assert(seen.has(Vector2i(RegionMap3D.center(i)*2)),"Every region must remain connected by land")
 for i in GameData.OPTIONAL_AREA_HOSTS:
  island.visible_regions.append(i)
  assert(island.coastline(RegionMap3D.center(i))>0)
 island.free();print("Irregular coastline, deep bays, 16 connected regions and optional sections passed");quit()
