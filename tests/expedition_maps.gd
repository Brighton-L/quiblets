extends SceneTree
const PROP_SCRIPT:=preload("res://scripts/expedition_prop_3d.gd")

var failures:=0
var checks:=0

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func _initialize()->void:call_deferred("run")

func blocked(expedition:Expedition3D,point:Vector3)->bool:
	return expedition.obstacles.any(func(rect):return rect.has_point(Vector2(point.x,point.z)))

func cell_of(point:Vector2)->Vector2i:
	return Vector2i(roundi(point.x),roundi(point.y))

func connected(expedition:Expedition3D)->bool:
	# Flood the walkable grid from the start zone and require every zone centre.
	var seen:={};var frontier:Array[Vector2i]=[cell_of(expedition.zones[0].center)];seen[frontier[0]]=true
	while not frontier.is_empty():
		var cell:Vector2i=frontier.pop_back()
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next:Vector2i=cell+offset
			if expedition.walkable.has(next) and not seen.has(next):seen[next]=true;frontier.append(next)
	return expedition.zones.all(func(zone):return seen.has(cell_of(zone.center)))

func build(area:int,node:int,kind:String)->Expedition3D:
	var expedition:=Expedition3D.new();expedition.stage_area_index=area;expedition.stage_node_index=node;expedition.stage_kind=kind;expedition.stage_level=GameData.expedition_area_level(area)
	root.add_child(expedition);expedition.set_process(false);expedition.build_level();return expedition

func run()->void:
	var kinds:={0:"level",3:"berry_grove",6:"boss",7:"optional_berry_grove"}
	var signatures:={}
	for area in [0,4,7,11,15]:
		for node in kinds:
			var e:=build(area,node,kinds[node])
			check(e.zones.size()==(6 if node in [3,7] else 4),"Levels need a start clearing plus three boss arenas; groves five meadows")
			check(e.walkable.size()>60 and not e.obstacles.is_empty(),"Maps must carve walkable tiles enclosed by cliffs")
			for zone in e.zones:
				var center:Vector2=zone.center
				check(e.walkable.has(cell_of(center)) and not blocked(e,Vector3(center.x,0,center.y)),"Zone centres must be walkable")
				check(e.arena_rect.has_point(center),"Arena bounds must cover every zone")
			check(connected(e),"Every zone must connect to the start along walkable corridors")
			check(e.zones.slice(1).all(func(zone):return zone.center.x>e.zones[0].center.x),"The route should lead onward from the start clearing")
			if node==6:check(e.zones.slice(1).all(func(zone):return zone.radius.x>=6.0),"Boss stages need three large arenas")
			if node!=0 and node!=6:check(e.zones.slice(1).all(func(zone):return zone.radius.x>=5.0),"Berry Groves need wide meadows")
			check(e.berry_nodes.size()==(34 if node==7 else (26 if node==3 else 4)),"Wrong berry patch count")
			for patch in e.berry_nodes:
				var point:=Vector2(patch.position.x,patch.position.z)
				check(e.cell_exposed(cell_of(point)),"Berry patches must sit on fully exposed ground, never against a cliff or in a nook")
				check(str(patch.get_meta("shape",""))==str(patch.get_meta("ingredient","")) and patch.get_child_count()>0,"Every patch is shaped after the ingredient it will give")
				check(e.walkable.has(cell_of(point)) and not blocked(e,patch.position) and point.distance_to(e.zones[0].center)>1.5,"Berry patches must stand on walkable ground away from the start")
			# The ground is one smooth heightfield: open ground flat, hills rounded, rivers soft troughs, no tile cubes.
			var terrain_node:MeshInstance3D=e.get_node("TerrainMesh")
			check(terrain_node.mesh is ArrayMesh and terrain_node.mesh.surface_get_array_len(0)==e.height_cols*e.height_rows and e.TERRAIN_SUBDIV==3 and e.get_node("Clouds").get_child_count()>0 and terrain_node.material_override is ShaderMaterial and terrain_node.material_override.shader.code.contains("fade_points") and terrain_node.material_override.next_pass is ShaderMaterial,"The ground is a single heightfield mesh wearing the fading terrain shader")
			check(e.find_children("Terrain*","MultiMeshInstance3D",true,false).all(func(node3d):return node3d.name=="TerrainDetails"),"No tile cubes remain; only tufts and flowers are instanced")
			var flat:=true
			for cell in e.walkable.keys().slice(0,600):
				if e.wall_tiers.has(cell) or e.deck_height_at(Vector2(cell))>-1.0e8:continue
				if absf(e.terrain_height_at(Vector2(cell)))>e.PLAIN_ROLL+e.HILL_SKIRT_SHARE*(float(e.CLIFF_TIER_LAYERS[1])+e.HILL_ROLL)+.001:flat=false
			check(flat,"Open ground away from hills and bridges only rolls within its swells plus the hills' skirts")
			# Hills are walkable ground: every hill cell is walkable and rises above the plain.
			check(e.wall_tiers.keys().all(func(cell):return e.walkable.has(cell) or e.prop_cells.has(cell)) and e.wall_tiers.keys().any(func(cell):return e.raw_height_at(Vector2(cell))>.8),"Hills stay walkable ground (a prop may stand on one) and rise above the plain")
			var tallest:=0.0;var steepest:=0.0
			for r in e.height_rows:
				for c in range(e.height_cols-1):
					var a:float=e.height_field[r*e.height_cols+c];var b:float=e.height_field[r*e.height_cols+c+1]
					tallest=maxf(tallest,a);steepest=maxf(steepest,absf(a-b))
			# The steepest smooth ramp (peak × the smoothstep's 1.5 slope ÷ HILL_RAMP) per sample is the limit; a seam would be far larger.
			var ramp_limit:float=(float(e.CLIFF_TIER_LAYERS[1])+e.HILL_ROLL)*1.5/e.HILL_MIN_HALF/float(e.TERRAIN_SUBDIV)*.5+e.PLAIN_ROLL*.3+.12
			# A waterfall's lip is a deliberate drop from the high source channel into the trough.
			if not e.waterfall_cells.is_empty():ramp_limit=maxf(ramp_limit,e.WATERFALL_TOP+e.RIVER_DEPTH+.3)
			check(tallest>1.6 and steepest<ramp_limit,"Hills reach plateau height (%.2f) with no step between neighbouring samples beyond the ramp (%.2f, limit %.2f)"%[tallest,steepest,ramp_limit])
			var lowest:=0.0
			for cell in e.rivers:lowest=minf(lowest,e.terrain_height_at(Vector2(cell)))
			if not e.rivers.is_empty():check(lowest<-.9,"Rivers sink into troughs (%.2f)"%lowest)
			# Voxel look: every cube shares the pixel face atlas with a bright top cell and darker warm sides, nearest-filtered.
			var atlas:ImageTexture=GameData.voxel_face_texture();var atlas_image:=atlas.get_image();var px:int=GameData.VOXEL_FACE_PIXELS
			check(atlas.get_width()==px*3 and atlas.get_height()==px*2 and atlas_image.get_pixel(px+px/2,px+px/2).get_luminance()>atlas_image.get_pixel(px/2,px/2).get_luminance()+.1,"The voxel face atlas should be a 3×2 box atlas with a brighter top cell")
			var wall_detail:ImageTexture=GameData.detail_texture("wall")
			check(wall_detail.get_width()==GameData.DETAIL_PIXELS*3 and not terrain_node.material_override.shader.code.contains("texture(") and terrain_node.material_override.shader.code.contains("SPECULAR=0.0"),"The ground wears no texture and shades matte")
			var leaf_image:Image=GameData.detail_texture("leaf").get_image();var trunk_image:Image=GameData.detail_texture("trunk").get_image();var dp:int=GameData.DETAIL_PIXELS
			var leaf_dark_rows:int=0;var trunk_dark_columns:int=0
			for i in dp:
				if leaf_image.get_pixel(dp/2,i).get_luminance()<.97:leaf_dark_rows+=1
				if trunk_image.get_pixel(i,dp/2).get_luminance()<.97:trunk_dark_columns+=1
			check(leaf_dark_rows>=2 and leaf_dark_rows<=dp*2/3 and trunk_dark_columns>=2 and trunk_dark_columns<=dp*2/3,"Leaf detail has a few partial horizontal runs and trunk detail a few vertical runs, never a fully banded face")
			# Quest-style detail is built from DETAIL_BLOCK-pixel squares: every pixel in a block shares its value.
			var blocky:=true
			for bx in range(0,dp,GameData.DETAIL_BLOCK):
				for by in range(0,dp,GameData.DETAIL_BLOCK):
					var first:=leaf_image.get_pixel(bx,by)
					for ox in GameData.DETAIL_BLOCK:
						for oy in GameData.DETAIL_BLOCK:
							if not leaf_image.get_pixel(bx+ox,by+oy).is_equal_approx(first):blocky=false
			check(blocky,"Detail textures are made of small uniform squares, not single pixels")
			# Every prop part is a plain matte piece with no texture: a smooth blob, a cylinder, or a rounded box.
			check(e.props.is_empty() or e.props.all(func(prop):return prop.parts.all(func(part):return part.material_override.albedo_texture==null and part.material_override.roughness==1.0 and (part.mesh is ArrayMesh or part.mesh is SphereMesh or part.mesh is CylinderMesh))),"Props are plain matte untextured pieces")
			var rounded:ArrayMesh=GameData.rounded_box(Vector3.ONE,.2);var rounded_aabb:AABB=rounded.get_aabb()
			check(rounded.get_surface_count()==1 and rounded_aabb.size.is_equal_approx(Vector3.ONE) and rounded.surface_get_array_len(0)==6*4*4*6,"The rounded box is a single closed surface the size of its box")
			# With only the top and +X open, the top face reaches the -X edge square but curves away before +X, and covered faces are dropped.
			var partial:ArrayMesh=GameData.rounded_box(Vector3.ONE,.2,4,GameData.BOX_POS_Y|GameData.BOX_POS_X);var top_min_x:=INF;var top_max_x:=-INF
			for vertex in partial.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if absf(vertex.y-.5)<.001:top_min_x=minf(top_min_x,vertex.x);top_max_x=maxf(top_max_x,vertex.x)
			check(partial.surface_get_array_len(0)==2*4*4*6 and is_equal_approx(top_min_x,-.5) and top_max_x<.5-.15 and partial.get_aabb().size.is_equal_approx(Vector3.ONE),"Rounding happens only where two open faces meet")
			var river_meshes:Array=e.find_children("River*","MeshInstance3D",true,false)
			if e.rivers.is_empty():check(river_meshes.is_empty(),"No river meshes without rivers")
			else:
				check(river_meshes.size()==1 and river_meshes[0].name=="RiverWater" and river_meshes[0].mesh is ArrayMesh and e.find_child("RiverBed",true,false)==null,"Rivers are troughs in the ground mesh with one translucent water sheet, no bed cubes or ripple slivers")
				check(e.bridges.keys().all(func(cell):return e.walkable.has(cell)) and (e.bridge_arches.is_empty() or (e.get_node("Bridges").get_child_count()==e.bridge_arches.size() and e.spanned_cells.keys().any(func(cell):return e.bridge_lift(Vector2(cell))>.5))),"Crossings carry an arched wooden bridge whose deck lifts the walker over the channel")
				var water_node:MeshInstance3D=e.find_child("RiverWater",true,false);var water_cells:int=e.rivers.size()+e.pond_cells.size()+e.spanned_cells.size()-e.waterfall_cells.size()
				check(water_node.mesh.surface_get_array_len(0)==water_cells*e.TERRAIN_SUBDIV*e.TERRAIN_SUBDIV*6,"The water sheet covers every river and pond cell and runs on under every bridge")
				var water_arrays:Array=water_node.mesh.surface_get_arrays(0);var water_colors:PackedColorArray=water_arrays[Mesh.ARRAY_COLOR];var water_uv2:PackedVector2Array=water_arrays[Mesh.ARRAY_TEX_UV2]
				check(water_colors.size()==water_node.mesh.surface_get_array_len(0) and water_uv2.size()==water_colors.size() and Array(water_colors.slice(0,64)).all(func(color):return is_equal_approx(color.a,water_colors[0].a)),"Every water vertex carries flow, one shared phase, and shore depth for the shader")
				var shallow:=0;var deep:=0
				for uv in water_uv2:
					if uv.x<.3:shallow+=1
					elif uv.x>.7:deep+=1
				check(shallow>0 and deep>0,"The water sheet is shallow along the banks and deep mid-channel")
				check(water_node.material_override.shader.code.contains("shore_foam") and water_node.material_override.shader.code.contains("VIEW_MATRIX*vec4(bump"),"The water shader foams the shallows and glints on world-space rippled normals")
				# Bridges never end in the water and the river runs on beneath them.
				# No channel cell is ever a dry, waterless gap: every bridge cell has water
				# under its deck, so a river reads as one continuous ribbon.
				check(e.bridges.keys().all(func(cell):return e.spanned_cells.has(cell)),"Every crossing is spanned, so the river runs on continuously with no dry gaps")
				for arch in e.bridge_arches:
					check(e.deck_height_at(arch.center)>e.raw_height_at(arch.center)+.4,"The deck arches over the channel it spans")
				if not e.bridge_arches.is_empty():
					check(e.get_node("Bridges").get_children().all(func(deck):return deck.mesh is ArrayMesh and deck.get_child_count()==0),"Bridges are one earthen terrain deck each, with no rails or posts")
				check(e.bridge_arches.all(func(arch):return arch.axis==Vector2(1,0) or arch.axis==Vector2(0,1)),"Bridges lie along one of the two crossing orientations")
				if not e.waterfall_cells.is_empty():
					check(e.get_node("Waterfalls").get_child_count()==e.waterfalls.size() and e.waterfall_cells.keys().all(func(cell):return not e.field_rect.has_point(cell)) and e.waterfall_cells.keys().any(func(cell):return e.raw_height_at(Vector2(cell))>.8),"A waterfall's source channel slopes down out of the border hills into the field and its sheet is built")
					check(e.get_node("Waterfalls").get_children().all(func(fall):return fall.find_child("WaterfallSheet",true,false)!=null and fall.find_child("WaterfallSheet",true,false).material_override.shader==water_node.material_override.shader and fall.find_child("WaterfallSheet",true,false).material_override.get_shader_parameter("tint")==water_node.material_override.get_shader_parameter("tint") and fall.find_child("WaterfallSheet",true,false).material_override.get_shader_parameter("surface_flow")==true),"Waterfalls share the river shader and tint, with continuous flow coordinates for their slope")
					check(e.get_node("Waterfalls").get_children().all(func(fall):return fall.get_child_count()>=9) and e.waterfall_bubbles.size()>=10,"Each waterfall foot churns with many soft foam patches")
					var bubble=e.waterfall_bubbles[0].node;var before:float=bubble.scale.x;e.elapsed+=1.7;e.update_waterfall_bubbles()
					check(not is_equal_approx(bubble.scale.x,before),"Foam patches expand as they drift and dissolve")
				check(e.RIVER_DEPTH>=1.2,"Rivers should be sunk deep")
				check(water_node.material_override is ShaderMaterial and water_node.material_override.shader.code.contains("TIME") and e.river_channels>=int(e.biome.rivers)+e.EXTRA_RIVERS_MIN,"River water should flow with a time-driven shader fed each river's direction, with extra rivers guaranteed")
			check(int(e.cliff_tiers[1])>0 and int(e.cliff_tiers[2])>0 and int(e.cliff_tiers[3])>0 and e.cliff_layer_count==int(e.cliff_tiers[1])+int(e.cliff_tiers[2])+int(e.cliff_tiers[3]),"Every wall tier is present and the hill count matches the tier tallies")
			check(e.get_child_count()<140,"Maps should stay lightweight")
			for cell in e.walkable:check(not blocked(e,Vector3(cell.x,0,cell.y)),"Walkable tiles must not be covered by obstacle rects")
			signatures["%d/%d"%[area,node]]=str(e.obstacles)
			var again:=build(area,node,kinds[node])
			check(str(again.obstacles)==str(e.obstacles) and again.zones.size()==e.zones.size() and range(e.zones.size()).all(func(i):return again.zones[i].center==e.zones[i].center),"Level generation must be deterministic")
			e.free();again.free()
	# Open fields: every cell inside the field is ground, river, bridge, or wall; rivers are uncrossable except at bridges.
	var wall_counts:={}
	for area in [0,6]:
		var field:=build(area,0,"level")
		var inside:=0;var open_cells:=0
		for x in range(field.field_rect.position.x,field.field_rect.end.x):
			for z in range(field.field_rect.position.y,field.field_rect.end.y):
				var cell:=Vector2i(x,z);inside+=1
				var cell_kinds:int=int(field.walkable.has(cell))+int(field.rivers.has(cell))+int(field.prop_cells.has(cell))
				check(cell_kinds==1 and (not field.wall_tiers.has(cell) or field.walkable.has(cell) or field.prop_cells.has(cell)),"Each field cell is exactly one of ground, river, or prop, and every hill is walkable ground or a prop's tile")
				if field.walkable.has(cell):open_cells+=1
		check(open_cells>inside*.6,"An open field should be mostly walkable ground: area %d"%area)
		check(field.rivers.keys().all(func(cell):return not field.walkable.has(cell)) and field.bridges.keys().all(func(cell):return field.walkable.has(cell)),"Rivers block movement and bridges allow it")
		var river_columns:={}
		for cell in field.rivers:river_columns[cell.x]=true
		if int(GameData.expedition_biome(area).rivers)>0:check(not field.rivers.is_empty() and not field.bridges.is_empty(),"A river biome should carve rivers with bridges: area %d"%area)
		check(field.wall_tiers.values().any(func(tier):return int(tier)>=2),"Walls should stack more than one layer somewhere")
		check(connected(field),"Rivers and walls must leave every clearing reachable")
		wall_counts[area]=field.wall_tiers.size();field.free()
	check(int(wall_counts[6])>int(wall_counts[0])*2,"Glittergut Cave should be far more walled than Longgrass Fields (%d vs %d)"%[wall_counts[6],wall_counts[0]])
	check(GameData.expedition_biome(6).decor.has("boulder") and GameData.expedition_biome(4).decor.has("big_mushroom") and GameData.expedition_biome(0).decor.has("tree"),"Biomes should list their own prop kinds")
	# Destructible props: cube-built trees and boulders block their tile until a move breaks them.
	var wood:=build(0,1,"level")
	check(wood.props.size()>=8 and wood.props.all(func(prop):return prop.get_child_count()>=1 and not wood.walkable.has(prop.cell) and wood.prop_cells.has(prop.cell) and wood.field_rect.has_point(prop.cell)),"Levels should hold simple props that block their tiles")
	var cave:=build(6,1,"level")
	check(wood.props.any(func(prop):return prop.kind=="tree") and cave.props.any(func(prop):return prop.kind=="boulder") and cave.props.any(func(prop):return prop.kind in ["crystal","big_mushroom"]),"Meadows grow trees; caves hold boulders, crystals, and big mushrooms")
	cave.free()
	# Regular levels mix fruit-bearing plants with plain scenery; Berry Groves are
	# lush gathering fields — denser and mostly harvestable.
	var lv_h:=0;var lv_t:=0
	for node in [0,1,2]:
		var lv:=build(0,node,"level");lv_h+=lv.props.filter(func(prop):return prop.harvestable()).size();lv_t+=lv.props.size();lv.free()
	var grove_sample:=build(0,3,"berry_grove");var gv_h:=grove_sample.props.filter(func(prop):return prop.harvestable()).size();var gv_t:=grove_sample.props.size()
	check(lv_t>0 and lv_h>0 and lv_h<lv_t,"Regular levels mix fruit-bearing plants with plain scenery (%d of %d bear fruit)"%[lv_h,lv_t])
	check(gv_t>0 and float(gv_h)/gv_t>float(lv_h)/lv_t+.3 and gv_t>lv_t/3.0,"A Berry Grove is denser and far more harvestable (%d/%d vs %d/%d over three levels)"%[gv_h,gv_t,lv_h,lv_t])
	check(grove_sample.props.any(func(prop):return prop.kind in ["bush","tree"]),"A Berry Grove grows leafy shrubs and trees")
	grove_sample.free()
	# Harvesting: stand beside a tree for a while to gather big bundles; the tree then goes.
	var orchard=wood.props.filter(func(prop):return prop.kind=="tree")[0];var orchard_cell:Vector2i=orchard.cell
	orchard.bears_fruit=true;orchard.rich=false  # this test harvests it, so make sure it bears fruit
	# Trees are a tapered trunk under five round leaf blobs in four greens; shrubs are three blobs.
	var tree_balls:Array=orchard.parts.filter(func(part):return part.mesh is SphereMesh)
	check(tree_balls.size()==5 and orchard.parts.size()==6 and orchard.parts[0].mesh is CylinderMesh and GameData.leaf_sphere().radial_segments>=16 and tree_balls.map(func(part):return part.material_override.albedo_color).reduce(func(seen,color):return seen if seen.has(color) else seen+[color],[]).size()>=4,"A tree is a tapered trunk under five smooth leaf blobs in four greens")
	var shrub=PROP_SCRIPT.new();shrub.setup("bush",Vector2i(0,0),GameData.expedition_biome(0),5,RandomNumberGenerator.new());root.add_child(shrub)
	check(shrub.parts.size()==7 and shrub.parts.all(func(part):return part.mesh is SphereMesh),"A shrub is a rounded dome of leaf blobs");shrub.free()
	var picker:=QuibletActor3D.new();picker.setup(GameData.make_quiblet(2,10),false,0,1);wood.place_actor(picker);picker.set_physics_process(false);wood.team.append(picker)
	picker.position=Vector3(orchard_cell.x+1.0,0,orchard_cell.y)
	var harvest_rewards:Array=[];wood.reward_acquired.connect(func(reward,_position):harvest_rewards.append(reward))
	var loot_before:int=0
	for name in wood.loot:loot_before+=int(wood.loot[name])
	for name in GameData.INGREDIENTS:wood.loot[name]=int(wood.loot.get(name,0))
	wood.update_harvesting([picker],1.0)
	check(orchard.harvest_progress>0.0 and not orchard.shattered and wood.loot.values().reduce(func(a,b):return int(a)+int(b),0)==loot_before,"A harvest takes a while: nothing is gathered after one second")
	wood.update_harvesting([],1.0);check(orchard.harvest_progress<1.0,"Harvest progress drains when nobody stands by the prop")
	for i in 4:wood.update_harvesting([picker],1.0)
	var harvested_total:int=harvest_rewards.filter(func(reward):return reward.kind=="ingredient").reduce(func(sum,reward):return sum+int(reward.amount),0)
	check(orchard.shattered and orchard.harvested and wood.walkable.has(orchard_cell) and harvest_rewards.size()==wood.HARVEST_BUNDLES and harvested_total>=2 and harvested_total<=4,"A full harvest gives a modest bundle and clears the tree's tile")
	check(harvest_rewards.all(func(reward):return GameData.INGREDIENTS[reward.name].tags.any(func(tag):return tag in ["fruit","leaf"])),"A tree harvest gives fruit or leaf ingredients")
	wood.team.erase(picker)
	check(connected(wood),"Props must never cut a clearing off")
	var target_prop=wood.props[0];var prop_cell:Vector2i=target_prop.cell
	check(blocked(wood,Vector3(prop_cell.x,0,prop_cell.y)),"A standing prop is an obstacle")
	var breaker:=QuibletActor3D.new();var breaker_data:=GameData.make_quiblet(0,10);breaker_data.moves=[{"name":"Water Burst","slots":1,"stones":[]}];breaker.setup(breaker_data,false,0,0);wood.place_actor(breaker);breaker.set_physics_process(false)
	breaker.position=Vector3(prop_cell.x+1.2,0,prop_cell.y);breaker.use_move(0,null)
	await create_timer(.4).timeout
	check(target_prop.hp<target_prop.max_hp,"An area move should damage a nearby prop")
	target_prop.hit(100000.0)
	check(target_prop.shattered and wood.walkable.has(prop_cell) and not wood.prop_cells.has(prop_cell) and not wood.props.has(target_prop) and not blocked(wood,Vector3(prop_cell.x,0,prop_cell.y)),"Breaking a prop should open its tile and clear its obstacle")
	check(target_prop.get_children().filter(func(child):return child is MeshInstance3D and child.visible).size()>=target_prop.SHARD_COUNT,"A broken prop should burst into a scatter of cubes")
	await create_timer(1.0).timeout
	check(target_prop.shards.all(func(shard):return shard.node.position.y<1.0),"The cubes should fall toward the ground")
	await create_timer(2.4).timeout
	check(not is_instance_valid(target_prop),"The cubes should shrink away and the prop should be gone after a few seconds")
	wood.free()
	var unique:={}
	for signature in signatures.values():unique[signature]=true
	check(unique.size()==signatures.size(),"Every area and node should get its own layout")
	var grounds:={}
	for area in GameData.EXPEDITION_AREAS.size():
		var biome:=GameData.expedition_biome(area);grounds[str(biome.ground)]=true
		check(biome.ground is Color and biome.cliff is Color and not str(biome.decor).is_empty(),"Every area needs a complete biome")
	check(grounds.size()>=12,"Islands need distinct biome palettes")
	# Live progression: ambush zones, auto-advance, and player override.
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_area_level(0,0);await process_frame
	var e:Expedition3D=game.expedition;e.set_process(false)
	for actor in e.team+e.enemies:actor.set_physics_process(false)
	check(e.team.all(func(member):return not blocked(e,member.position) and e.zone_index_at(Vector2(member.position.x,member.position.z))==0),"The team should start inside the start clearing")
	check(e.spawn_points.size()==e.SPAWN_POINTS and e.spawn_points.all(func(point):return e.cell_open(e.cell_of(point)) and Vector2(point).distance_to(e.zones[0].center)>=e.SPAWN_POINT_MIN_START_DISTANCE),"Spawn areas should sit on open ground well away from the start")
	var spread_ok:=true
	for a in e.spawn_points.size():
		for b in e.spawn_points.size():
			if a<b and e.spawn_points[a].distance_to(e.spawn_points[b])<e.SPAWN_POINT_SPACING:spread_ok=false
	check(spread_ok,"Spawn areas should be spread across the field")
	check(e.wave==1 and e.enemies.size()>=1 and e.enemies.all(func(enemy):return int(enemy.get_meta("group"))==1 and not blocked(e,enemy.position) and e.walkable.has(e.cell_of(Vector2(enemy.position.x,enemy.position.z)))),"Only the first set should be on the field at the start, standing on open ground")
	e._process(1.0/60)
	check(e.enemies.all(func(enemy):return not enemy.get_meta("alerted") and enemy.target==null) and e.team.all(func(member):return member.target==null),"The set should idle, and the team should not chase it, until the team comes close")
	check(e.team.all(func(member):return member.has_command),"The team should auto-explore toward the idle set")
	var start:Vector2=e.zones[0].center;e.command_team(Vector3(start.x,0,start.y))
	check(e.advance_index<0 and e.team.all(func(member):return member.has_command),"A player command should override exploration")
	var first_group:Vector2=e.enemies[0].get_meta("alert_center")
	for member in e.team:member.position=Vector3(first_group.x,0,first_group.y)
	e._process(1.0/60)
	check(e.enemies.all(func(enemy):return enemy.get_meta("alerted") and enemy.target!=null),"The set should engage once the team comes close")
	var seen_points:={}
	while e.wave<e.max_waves:
		for enemy in e.enemies:seen_points[int(enemy.get_meta("spawn_point"))]=true
		for enemy in e.enemies.duplicate():e._on_actor_defeated(enemy)
		check(e.intermission>0.0 and e.enemies.is_empty(),"Nothing new spawns until the current set is beaten")
		for member in e.team:member.position=Vector3(start.x,0,start.y)
		e.intermission=.01;e._process(.02)
		if e.wave<e.max_waves:
			check(e.enemies.all(func(enemy):return int(enemy.get_meta("group"))==e.wave and Vector2(enemy.get_meta("alert_center")).distance_to(start)>=e.SET_MIN_TEAM_DISTANCE),"Each new set appears at a spawn area away from the team")
			var set_center:Vector2=e.enemies[0].get_meta("alert_center")
			check(e.camera_pan_time>0.0 and Vector2(e.camera_pan_target.x,e.camera_pan_target.z)==set_center,"The camera should pan to a newly spawned set")
			check(is_equal_approx(e.camera_pan_time,e.spawn_drop_duration(e.enemies.size())+e.SET_PAN_LINGER) and e.camera_pan_time<1.6,"The set pan should last only until the last enemy lands plus a short linger")
			check(e.enemies.all(func(enemy):return enemy.model_lift>.5),"New enemies should pop in above the ground")
			if e.wave==2:
				var dropper:QuibletActor3D=e.enemies[0];var lifts:Array[float]=[]
				for i in 8:
					await create_timer(.1).timeout;lifts.append(dropper.model_lift)
				check(lifts.max()>.9 and is_zero_approx(lifts[-1]),"A new enemy should hop up a little and then fall to the ground")
				dropper.update_statuses(.016);check(is_zero_approx(dropper.model.position.y),"The model should land back on the ground")
	check(seen_points.size()>=mini(e.max_waves-1,4),"Sets should use different spawn areas")
	var arena_index:int=e.nearest_arena_index()
	check(e.wave==e.max_waves and e.enemies.any(func(enemy):return enemy.get_meta("level_boss",false)) and e.enemies.all(func(enemy):return int(enemy.get_meta("zone"))==arena_index and not enemy.get_meta("alerted")),"The boss and its escorts should wait in the arena nearest the team")
	check(e.camera_pan_time>0.0 and Vector2(e.camera_pan_target.x,e.camera_pan_target.z)==Vector2(e.zones[arena_index].center),"The boss introduction should pan the camera to its arena")
	var boss_actor:QuibletActor3D=e.enemies.filter(func(enemy):return enemy.get_meta("level_boss",false))[0]
	check(boss_actor.model_stretch==Vector3.ONE,"The boss starts at its normal size")
	# Sample the intro: nothing for the first ~2s, then a stretch up, then a squash down, then back to normal.
	var samples:Array[Vector2]=[]
	for i in 36:
		await create_timer(.1).timeout
		samples.append(Vector2(float(i+1)*.1,boss_actor.model_stretch.y))
	var early_still:bool=samples.filter(func(sample):return sample.x<1.6).all(func(sample):return is_equal_approx(sample.y,1.0))
	var peak:Vector2=samples.reduce(func(best,sample):return sample if sample.y>best.y else best,samples[0]);var dip:Vector2=samples.reduce(func(best,sample):return sample if sample.y<best.y else best,samples[0])
	check(early_still and peak.y>1.1 and dip.y<.9 and peak.x<dip.x and peak.x>1.6 and e.get_node_or_null("BossGrunt")!=null and e.get_node("BossGrunt").stream is AudioStreamWAV,"A couple of seconds after the pan the boss should grunt, stretch upward, then squash down")
	check(samples[-1].y>.99 and samples[-1].y<1.01,"The boss should settle back to its normal size")
	boss_actor.update_statuses(.016);check(boss_actor.model.scale.is_equal_approx(Vector3.ONE*.82),"The model scale follows the stretch multiplier back to normal")
	var grunt:AudioStreamWAV=e.get_node("BossGrunt").stream
	check(grunt.mix_rate==22050 and grunt.data.size()>22050*2*.9,"The grunt should be a synthesised clip just under a second long")
	# Commanded runs are routed around cliffs: every leg stays on walkable tiles.
	var grove:=build(0,7,"optional_berry_grove");var routed_turns:=0
	var grove_start:Vector2=grove.zones[0].center
	for patch in grove.berry_nodes:
		var goal:=Vector2(patch.position.x,patch.position.z);var path:Array[Vector3]=grove.find_path(grove_start,goal)
		check(not path.is_empty() and Vector2(path[-1].x,path[-1].z).distance_to(goal)<.01,"A patch run should end exactly at the patch")
		var previous:=grove_start;var legal:=true
		for point in path:
			var next:=Vector2(point.x,point.z);legal=legal and grove.walkable.has(cell_of(next)) and grove.line_walkable(previous,next);previous=next
		check(legal,"Every leg of a patch run must stay on walkable tiles with clearance from cliffs")
		if path.size()>1:routed_turns+=1
	check(routed_turns>0,"Runs to pocket patches should bend around cliffs instead of heading straight at them")
	var far_goal:Vector2=grove.zones[-1].center;var far_path:Array[Vector3]=grove.find_path(grove_start,far_goal)
	check(far_path.size()>=1 and Vector2(far_path[-1].x,far_path[-1].z).distance_to(far_goal)<.01,"A run across the grove should end at the far meadow")
	var runner:QuibletActor3D=QuibletActor3D.new();runner.setup(GameData.make_quiblet(0,5),false,0,0);grove.place_actor(runner);runner.set_physics_process(false)
	runner.follow_path(far_path)
	check(runner.has_command and runner.desired_point==far_path[0] and runner.command_path.size()==far_path.size()-1,"Following a path should command the first leg and queue the rest")
	runner.command(Vector3(grove_start.x,0,grove_start.y))
	check(runner.command_path.is_empty(),"A direct command should drop any queued path")
	# Patch shapes differ per ingredient so the likely reward is readable from afar.
	var shapes:={}
	for ingredient_name in GameData.INGREDIENTS:
		var sample:=Node3D.new();grove.build_berry_patch_shape(sample,ingredient_name);var signature:Array=[]
		for part in sample.get_children():signature.append([part.mesh.get_class(),str(part.mesh.size) if part.mesh is BoxMesh else "%.2f/%.2f"%[part.mesh.top_radius if part.mesh is CylinderMesh else part.mesh.radius,part.mesh.height],str(part.position),str(part.rotation)])
		shapes[ingredient_name]=str(signature);sample.free()
	var unique_shapes:={}
	for signature in shapes.values():unique_shapes[signature]=true
	check(unique_shapes.size()==GameData.INGREDIENTS.size(),"Every resource needs its own distinct plant shape (got %d of %d)"%[unique_shapes.size(),GameData.INGREDIENTS.size()])
	var level_patch_names:={}
	for area_index in GameData.EXPEDITION_AREAS.size():
		for node_index in [0,1,2,4,5]:
			var level:=build(area_index,node_index,"level")
			for patch in level.berry_nodes:level_patch_names[str(patch.get_meta("ingredient"))]=true
			level.free()
	check(level_patch_names.keys().any(func(name):return not name in grove.BERRY_INGREDIENTS),"Regular-level patches should grow resources beyond the four berries")
	var grove_berries:=0;var grove_others:=0
	for area_index in GameData.EXPEDITION_AREAS.size():
		for node_index in [3,7]:
			var meadow:=build(area_index,node_index,"berry_grove" if node_index==3 else "optional_berry_grove")
			for patch in meadow.berry_nodes:
				if str(patch.get_meta("ingredient")) in meadow.BERRY_INGREDIENTS:grove_berries+=1
				else:grove_others+=1
			meadow.free()
	check(grove_others>0 and grove_berries>grove_others,"Berry Groves should grow other resources too while staying mostly berries (berries %d, others %d)"%[grove_berries,grove_others])
	# Chasing across a river: a target on the far bank is reached by a routed path, not a straight walk into the channel.
	var chase_field:=build(0,1,"level")
	var crossing_cell=null
	for cell in chase_field.rivers:
		var west:Vector2i=cell+Vector2i(-2,0);var east:Vector2i=cell+Vector2i(2,0)
		if chase_field.walkable.has(west) and chase_field.walkable.has(east) and chase_field.cell_open(west) and chase_field.cell_open(east) and not chase_field.line_walkable(Vector2(west),Vector2(east)):crossing_cell=cell;break
	check(crossing_cell!=null,"The fixture needs a river with open ground on both banks")
	var chaser:=QuibletActor3D.new();chaser.setup(GameData.make_quiblet(0,10),false,0,2);chase_field.place_actor(chaser);chaser.set_physics_process(false);chase_field.team.append(chaser)
	var quarry:=QuibletActor3D.new();quarry.setup(GameData.make_quiblet(3,10),true);chase_field.place_actor(quarry);quarry.set_physics_process(false);chase_field.enemies.append(quarry)
	chaser.position=Vector3(crossing_cell.x-2,0,crossing_cell.y);quarry.position=Vector3(crossing_cell.x+2,0,crossing_cell.y);chaser.target=quarry;quarry.set_meta("alerted",true)
	chase_field.update_chase_routing(1.0)
	check(chaser.has_command and chaser.get_meta("chase_routed",false),"A chaser without a clear line should follow a routed path")
	var chase_points:Array[Vector3]=[chaser.desired_point];chase_points.append_array(chaser.command_path)
	var chase_legal:=true;var chase_previous:=Vector2(chaser.position.x,chaser.position.z)
	for point in chase_points:
		var next:=Vector2(point.x,point.z);chase_legal=chase_legal and chase_field.walkable.has(cell_of(next)) and chase_field.line_walkable(chase_previous,next);chase_previous=next
	check(chase_legal and chase_previous.distance_to(Vector2(quarry.position.x,quarry.position.z))<=minf(chaser.attack_range*.78,4.5)+.01 and chase_field.line_walkable(chase_previous,Vector2(quarry.position.x,quarry.position.z)),"The chase path stays on walkable ground and ends with a clear line within attack reach")
	chaser.position=quarry.position+Vector3(.3,0,0);chase_field.update_chase_routing(1.0)
	check(not chaser.has_command and not chaser.get_meta("chase_routed",false),"With a clear line the chaser drops the routed path and chases directly")
	chaser.command(Vector3(crossing_cell.x-2,0,crossing_cell.y));chaser.position=Vector3(crossing_cell.x-2,0,crossing_cell.y);chase_field.update_chase_routing(1.0)
	check(chaser.has_command and not chaser.get_meta("chase_routed",false) and chaser.command_path.is_empty(),"A player command is never replaced by chase routing")
	chase_field.free()
	# Carve a synthetic one-tile nook ("wall, cell, wall") and make sure runs stop on open ground beside it.
	var nook:Vector2i=cell_of(grove.zones[1].center)
	for offset in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:grove.walkable.erase(nook+offset)
	check(grove.walkable.has(nook) and not grove.cell_open(nook),"The synthetic nook should be walkable but not open")
	var nook_path:Array[Vector3]=grove.find_path(grove_start,Vector2(nook))
	var nook_end:=Vector2(nook_path[-1].x,nook_path[-1].z)
	check(grove.cell_open(cell_of(nook_end)) and nook_end.distance_to(Vector2(nook))<=2.0,"A run aimed into a nook should stop on the nearest open ground beside it")
	grove.free()
	game.area_progress[0]=8;game.start_area_level(0,6);await process_frame
	var boss:Expedition3D=game.expedition
	check(boss.zones.size()==4 and boss.max_waves>=8 and boss.enemies.size()>=2 and not boss.enemies.any(func(enemy):return enemy.get_meta("level_boss",false)) and boss.enemies.all(func(enemy):return enemy.has_meta("alert_center") and not enemy.get_meta("alerted",false)),"The first boss-level wave should wait in the first clearing")
	print("QUIBLETS_EXPEDITION_MAPS_OK checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
