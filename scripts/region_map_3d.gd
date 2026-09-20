class_name RegionMap3D
extends Node3D

# A continuous sculpted landmass; regions are color/landform zones, not islands.
const MAP_SCALE:=1.65
const CENTERS:=[Vector2(-16,9),Vector2(-10,10),Vector2(-10,3),Vector2(-17,2),Vector2(-18,-5),Vector2(-12,-7),Vector2(-7,-3),Vector2(-6,-11),Vector2(1,-11),Vector2(7,-13),Vector2(12,-7),Vector2(18,-4),Vector2(15,3),Vector2(19,10),Vector2(11,11),Vector2(7,4),Vector2(-7,8),Vector2(-15,-11),Vector2(10,-17),Vector2(23,7)]
const LAND_LINKS:=[Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(3,4),Vector2i(4,5),Vector2i(5,6),Vector2i(6,7),Vector2i(7,8),Vector2i(8,9),Vector2i(9,10),Vector2i(10,11),Vector2i(11,12),Vector2i(12,13),Vector2i(13,14),Vector2i(14,15),Vector2i(2,6),Vector2i(6,8),Vector2i(10,15)]
const PLATEAU_HEIGHTS:=[.65,.5,.45,1.5,.4,.8,1.2,2.1,.8,2.0,.65,1.15,.9,1.7,.85,1.15,.7,.4,1.3,.8]
# Broad, notched sections interlock around a large southern bay. These outlines
# are deliberately asymmetric; the heightfield rounds their shores and ledges.
const OUTLINES:=[
 [Vector2(-1,-.8),Vector2(-.2,-.8),Vector2(-.2,-1.1),Vector2(.8,-1.1),Vector2(.8,-.35),Vector2(1.2,-.35),Vector2(1.2,.4),Vector2(.65,.4),Vector2(.65,1),Vector2(-.35,1),Vector2(-.35,.65),Vector2(-1.1,.65)],
 [Vector2(-1,-.95),Vector2(.45,-.95),Vector2(.45,-.6),Vector2(1.1,-.6),Vector2(1.1,.55),Vector2(.6,.55),Vector2(.6,1.05),Vector2(-.15,1.05),Vector2(-.15,.65),Vector2(-1,.65)],
 [Vector2(-1.1,-.7),Vector2(-.45,-.7),Vector2(-.45,-1.1),Vector2(.75,-1.1),Vector2(.75,-.25),Vector2(1.1,-.25),Vector2(1.1,.8),Vector2(.1,.8),Vector2(.1,1.15),Vector2(-.8,1.15),Vector2(-.8,.35),Vector2(-1.1,.35)]
]
var region_outlines:Array[PackedVector2Array]=[]
func _init()->void:
 for index in CENTERS.size():
  var polygon:=PackedVector2Array()
  var size:=Vector2(3.9+(index%3)*.2,3.25+(index%4)*.2)*MAP_SCALE
  if index>=GameData.MAIN_AREA_COUNT:size*=.55
  for vertex:Vector2 in OUTLINES[index%OUTLINES.size()]:polygon.append(center(index)+(vertex*size).rotated(float(index%4)*PI*.5))
  region_outlines.append(polygon)
var visible_regions:Array[int]=[]
var biomes:Array[Dictionary]=[]

static func center(index:int)->Vector2:return CENTERS[clampi(index,0,CENTERS.size()-1)]*MAP_SCALE
func region_at(point:Vector2)->int:
 var best:=INF;var region:=0
 for index in visible_regions:
  var distance:=point.distance_squared_to(center(index))
  if index>=16:distance*=1.7
  if distance<best:best=distance;region=index
 return region
func region_coast(point:Vector2,index:int)->float:
 var polygon:=region_outlines[index];var distance:=INF
 for i in polygon.size():distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])))
 return (distance if Geometry2D.is_point_in_polygon(point,polygon) else -distance)/3.0

func connection_coast(point:Vector2,first:int,second:int)->float:
 var a:=center(first);var b:=center(second)
 var direction:=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)
 var bend:=(a+b)*.5+side*(.8+sin(first*1.7)*.7)*MAP_SCALE
 var distance:=minf(point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,bend)),point.distance_to(Geometry2D.get_closest_point_to_segment(point,bend,b)))
 var width:=(1.25+.25*(1.0+sin(first*2.1)))*MAP_SCALE
 return (width-distance)/3.0

func coastline(point:Vector2)->float:
 var coast:=-INF
 for index in visible_regions:
  if point.distance_squared_to(center(index))<90.0*MAP_SCALE*MAP_SCALE:coast=maxf(coast,region_coast(point,index))
  if index>=GameData.MAIN_AREA_COUNT:coast=maxf(coast,connection_coast(point,int(GameData.OPTIONAL_AREA_HOSTS[index]),index))
 for link:Vector2i in LAND_LINKS:coast=maxf(coast,connection_coast(point,link.x,link.y))
 return coast

func height_at(point:Vector2)->float:
 return height_for_region(point,region_at(point),coastline(point))

func height_for_region(point:Vector2,index:int,coast:float)->float:
 var b:Dictionary=biomes[index]
 var h:float=PLATEAU_HEIGHTS[index]+float(b.get("relief",.5))*.22*sin(point.x*.48)*cos(point.y*.43)
 if b.landform in ["ridges","ravine","looming"]:h+=.65*smoothstep(.35,.85,absf(sin(point.x*.35+point.y*.19)))
 if b.landform=="basin":h+=clampf(point.distance_to(center(index))*.09,0,.5)
 return lerpf(-.55,h,smoothstep(-.06,.18,coast))

func setup(regions:Array[int])->void:
 visible_regions=regions.duplicate()
 for i in GameData.EXPEDITION_AREAS.size():biomes.append(GameData.expedition_biome(i))
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var step:=.45
 # Shared grid vertices are evaluated once, not once per triangle corner.
 var samples:Dictionary={}
 for x in range(-90,93):
  for z in range(-70,66):
   var cell:=Vector2i(x,z)
   if not samples.has(cell):samples[cell]=terrain_sample(Vector2(cell)*step)
   if float(samples[cell].coast)<-.05:continue
   for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
    var vertex:Vector2i=cell+offset
    if not samples.has(vertex):samples[vertex]=terrain_sample(Vector2(vertex)*step)
    var sample:Dictionary=samples[vertex]
    st.set_color(sample.color);st.add_vertex(sample.position)
 st.generate_normals();var land:=MeshInstance3D.new();land.name="ContinuousIsland";land.mesh=st.commit()
 var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=1;land.material_override=mat;add_child(land)
 var sea:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(400,400);sea.mesh=plane;sea.position.y=-.56
 var water:=StandardMaterial3D.new();water.albedo_color=Color("#78c7d7");water.roughness=.3;sea.material_override=water;add_child(sea)
 for index in visible_regions:
  var rng:=RandomNumberGenerator.new();rng.seed=index*101+74
  var b:Dictionary=biomes[index]
  var planted:=0;var target:=22+int(float(b.density)*28)
  for n in target*3:
   if planted>=target:break
   var point:=center(index)+Vector2(rng.randf_range(-5.8,5.8),rng.randf_range(-5.7,5.7))
   if coastline(point)<.12 or region_at(point)!=index:continue
   var kinds:Array=b.decor;var kind:String=kinds[rng.randi_range(0,kinds.size()-1)]
   var prop:=ExpeditionProp3D.new();prop.setup("boulder" if kind=="rock" else kind,Vector2i.ZERO,b,1,rng);prop.bears_fruit=false
   prop.scale=Vector3.ONE*rng.randf_range(.35,.54);prop.position=Vector3(point.x,height_at(point),point.y);add_child(prop);planted+=1
   prop.set_meta("map_scenery",true)

func terrain_sample(point:Vector2)->Dictionary:
 var index:=region_at(point);var b:Dictionary=biomes[index];var coast:=coastline(point)
 var h:=height_for_region(point,index,coast);var color:Color=b.ground
 var grain:=.03*sin(point.x*13.0)*cos(point.y*11.0)
 color=color.lightened(grain) if grain>0 else color.darkened(-grain)
 if h>1.5:color=color.lerp(b.cliff,clampf((h-1.5)*.3,0,.65))
 if coast<.1:color=color.lerp(b.path,.6)
 var creek:=absf(sin(point.x*.65+sin(point.y*.6)))
 if int(b.rivers)>0 and creek<.035*float(b.river_width) and coast>.12:color=b.water_color;h-=.06
 return {"coast":coast,"color":color.srgb_to_linear(),"position":Vector3(point.x,h,point.y)}

func add_progression_trail()->void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for index in range(GameData.MAIN_AREA_COUNT-1):
  var a:=center(index);var b:=center(index+1);var direction:=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)
  var bend:=(a+b)*.5+side*(.8+sin(index*1.7)*.7)*MAP_SCALE
  for segment in [[a,bend],[bend,b]]:
   var start:Vector2=segment[0];var end:Vector2=segment[1];var count:=maxi(1,ceili(start.distance_to(end)/.9))
   for j in count:
    var point:=start.lerp(end,float(j)/count)
    if point.distance_to(a)<1.1 or point.distance_to(b)<1.1:continue
    for k in 6:
     for offset in [Vector2.ZERO,Vector2.from_angle(TAU*k/6.0)*.085,Vector2.from_angle(TAU*(k+1)/6.0)*.085]:
      var v:Vector2=point+offset;st.add_vertex(Vector3(v.x,height_at(v)+.045,v.y))
 var dots:=MeshInstance3D.new();dots.name="AreaProgressionTrail";dots.mesh=st.commit()
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.albedo_color=Color("#f7e2b1");dots.material_override=mat;add_child(dots)

func add_wandering_team(team:Array,areas:Array[int])->void:
 var signature:Array=[areas.duplicate()]
 for member in team:signature.append([str(member.get("uid","")),int(member.species)])
 if get_meta("team_signature",[])==signature and has_node("MapTeam"):return
 set_meta("team_signature",signature)
 var old:=get_node_or_null("MapTeam")
 if old!=null:remove_child(old);old.queue_free()
 var wanderers:=preload("res://scripts/region_map_wanderers.gd").new();wanderers.name="MapTeam";add_child(wanderers);wanderers.setup(team,self,areas)
 if not has_node("AreaProgressionTrail"):add_progression_trail()
