extends "res://scripts/expedition_3d.gd"
const WILD_BERRY_REGROW_SECONDS:=180.0
var wild_berry_regrowth:Dictionary={}
var camp_berry_patches:Dictionary={}

# A compact, fixed meadow using the expedition's terrain, water and bridge style.
# No encounter generation or full-map connectivity searches run in camp.
func stream_x(z:float)->float:return -9.0+sin(maxf(z,-13.0)*.22)*1.1
func entrance_x(z:float)->float:return 2.0+14.0*smoothstep(9.0,36.0,-z)
func entrance_point(z:float)->Vector2:return Vector2(entrance_x(z),z)
func camp_height(point:Vector2)->float:
	var clearing:=smoothstep(5.5,10.0,absf(point.x))*smoothstep(-2.0,2.0,point.y+5.0)
	# A continuous, irregular ridge encloses the clearing on all four sides.
	var edge:=pow(pow(absf(point.x)/34.0,4.0)+pow(absf(point.y)/31.0,4.0),.25)
	var ridge:=smoothstep(.55,1.0,edge)*(6.0+1.3*sin(point.x*.19+point.y*.14)+.7*cos(point.x*.35-point.y*.2))
	# Broad rounded shoulders follow a bending pass, concealing its distant end.
	var passage:=(1.0-smoothstep(1.1,4.8,absf(point.x-entrance_x(point.y))))*smoothstep(6.0,12.0,-point.y)
	ridge=lerpf(ridge,smoothstep(20.0,43.0,-point.y)*1.8,passage)
	var h:=clearing*(.22+.22*sin(point.x*.4)*cos(point.y*.3))+ridge
	# A wooded rise supplies the waterfall at the stream's northern source.
	h+=3.8*exp(-pow((point.x-stream_x(-13.0))/5.0,2.0)-pow((point.y+17.5)/4.0,2.0))
	var channel:=(1.0-smoothstep(1.0,2.0,absf(point.x-stream_x(point.y))))*(1.0-smoothstep(15.0,22.0,point.y))*(1.0-smoothstep(17.0,20.0,-point.y))
	var bed:=-1.25
	if point.y<-13.0:bed=lerpf(WATER_LEVEL,WATERFALL_TOP,smoothstep(0.0,3.12,-point.y-13.0))-.04
	return lerpf(h,bed,channel)

func camp_path_distance(point:Vector2)->float:
	var camp_paths:=minf(point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(-14,2),Vector2(18,3))),point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(-5,-2),Vector2(0,0))))
	var entrance_path:=absf(point.x-entrance_x(point.y)) if point.y<-4.0 else point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(2,-4),Vector2.ZERO))
	return minf(camp_paths,entrance_path)
func build()->void:
	set_process(false);biome=GameData.expedition_biome(0);field_rect=Rect2i(-28,-23,56,46)
	waterfalls.append({"lip":Vector2(stream_x(-13.0),-13.0),"flow":Vector2.DOWN,"half_width":1.5})
	height_origin=Vector2(-44,-48);height_cols=265;height_rows=277;height_field.resize(height_cols*height_rows)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in height_rows:
		for col in height_cols:
			var point:=height_origin+Vector2(col,row)/3.0;var h:=camp_height(point);height_field[row*height_cols+col]=h
			var normal:=Vector3(camp_height(point-Vector2(.05,0))-camp_height(point+Vector2(.05,0)),.1,camp_height(point-Vector2(0,.05))-camp_height(point+Vector2(0,.05))).normalized()
			var color:=Color(biome.ground).lerp(Color(biome.ground).lightened(.2),clampf(h*.25,0.0,1.0))
			color=color.lerp(Color(biome.path),1.0-smoothstep(.55,1.2,camp_path_distance(point)))
			if h<-.25:color=Color(biome.path).lerp(Color(biome.cliff).lightened(.3),clampf(-h-.3,0.0,1.0))
			st.set_color(color);st.set_normal(normal);st.add_vertex(Vector3(point.x,h,point.y))
	for row in height_rows-1:
		for col in height_cols-1:
			var a:=row*height_cols+col
			for index in [a,a+1,a+height_cols,a+1,a+height_cols+1,a+height_cols]:st.add_index(index)
	terrain_material=ShaderMaterial.new();terrain_material.shader=terrain_shader()
	terrain_mesh=MeshInstance3D.new();terrain_mesh.name="CampGround";terrain_mesh.mesh=st.commit();terrain_mesh.material_override=terrain_material;add_child(terrain_mesh)
	var water:=SurfaceTool.new();water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-13,23):
		for x in range(-12,-5):
			if absf(float(x)-stream_x(z))<2.5:
				rivers[Vector2i(x,z)]=true;add_water_cell(water,Vector2i(x,z),WATER_LEVEL,Vector2.DOWN,0.0)
	var river:=MeshInstance3D.new();river.name="CampStream";river.mesh=water.commit();river.material_override=water_material();add_child(river)
	bridge_arches.append({"center":Vector2(stream_x(2),2),"axis":Vector2.RIGHT,"half_span":2.3,"half_width":1.0,"base":0.0});build_bridges();build_waterfalls()
	var rng:=RandomNumberGenerator.new();rng.seed=904
	for cell in [Vector2i(-14,-7),Vector2i(-12,6),Vector2i(-5,-7),Vector2i(5,-10),Vector2i(13,-10),Vector2i(17,-3),Vector2i(16,8),Vector2i(-15,2),Vector2i(7,6),Vector2i(-3,-9),Vector2i(-22,-10),Vector2i(-23,8),Vector2i(21,-9),Vector2i(23,5),Vector2i(18,15),Vector2i(-18,15),Vector2i(8,-16)]:
		var prop:=ExpeditionProp3D.new();prop.setup("tree" if rng.randf()<.65 else "boulder",cell,biome,1,rng);prop.bears_fruit=false;prop.set_process(false);prop.position.y=camp_height(Vector2(cell));add_child(prop)
	# Small groves and garden pockets give the outer clearing distinct landmarks.
	var occupied:Array[Vector2]=[]
	for child in get_children():
		if child is ExpeditionProp3D:occupied.append(Vector2(child.position.x,child.position.z))
	var anchors:=[Vector2(-20,-11),Vector2(-21,11),Vector2(-14,17),Vector2(20,-12),Vector2(23,9),Vector2(12,18),Vector2(3,-17)]
	for cluster in anchors.size():
		for attempt in 12:
			var point:Vector2=anchors[cluster]+Vector2(rng.randf_range(-4,4),rng.randf_range(-3,3));point=point.round()
			if camp_path_distance(point)<2.2 or absf(point.x-stream_x(point.y))<3.2 or camp_height(point)<0 or camp_height(point)>3.0:continue
			if occupied.any(func(other):return other.distance_to(point)<2.3):continue
			occupied.append(point)
			if attempt%4==0:
				var patch:=Node3D.new();patch.name="CampBerryGarden";patch.position=Vector3(point.x,camp_height(point),point.y);patch.set_meta("camp_obstacle_radius",.9);add_child(patch)
				var ingredient:String=["Bumbleberry","Dewmelon","Sunplum","Curlcap"][cluster%4]
				build_berry_patch_shape(patch,ingredient)
				var patch_id:="%d:%d"%[int(point.x),int(point.y)]
				patch.set_meta("ingredient",ingredient);camp_berry_patches[patch_id]=patch
				var body:=StaticBody3D.new();body.name="HarvestHitbox";body.collision_layer=2;body.collision_mask=0;body.set_meta("camp_berry_patch",patch_id);patch.add_child(body)
				var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.5,1.5,1.5);collision.shape=shape;collision.position.y=.55;body.add_child(collision)
			else:
				var kind:String=["tree","bush","boulder","big_mushroom","bush"][attempt%5]
				var prop:=ExpeditionProp3D.new();prop.setup(kind,Vector2i(point),biome,1,rng);prop.bears_fruit=false;prop.set_process(false);prop.position.y=camp_height(point);add_child(prop)
	var details:Array[Dictionary]=[];var flowers:Array[Color]=[Color("#fff6d5"),Color("#ffe066"),Color("#ff9ec4")]
	for x in range(-26,27):
		for z in range(-21,22):
			var point:=Vector2(x,z)
			if camp_height(point)<0 or camp_path_distance(point)<1.5 or (absf(point.x)<6 and absf(point.y)<4):continue
			add_ground_detail(details,point,Color(biome.ground),flowers,rng)
	if not details.is_empty():build_multimesh("CampFlowers",BoxMesh.new(),details)

	set_process(true)

func _process(delta:float)->void:
	elapsed+=delta;update_waterfall_bubbles();refresh_wild_berries()

func flight_height_at(point:Vector2)->float:
	return maxf(0.0,camp_height(point))

func refresh_wild_berries(now:float=Time.get_unix_time_from_system())->void:
	for patch_id in camp_berry_patches:
		var patch:Node3D=camp_berry_patches[patch_id]
		var ready:=now>=float(wild_berry_regrowth.get(patch_id,0.0))
		patch.visible=ready
		patch.get_node("HarvestHitbox").collision_layer=2 if ready else 0

func harvest_wild_berry(patch_id:String,now:float=Time.get_unix_time_from_system())->String:
	if not camp_berry_patches.has(patch_id) or now<float(wild_berry_regrowth.get(patch_id,0.0)):return ""
	var patch:Node3D=camp_berry_patches[patch_id]
	var ingredient:=str(patch.get_meta("ingredient"))
	wild_berry_regrowth[patch_id]=now+WILD_BERRY_REGROW_SECONDS*int(GameData.INGREDIENTS[ingredient].tier)
	refresh_wild_berries(now)
	return ingredient
