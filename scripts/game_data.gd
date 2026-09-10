class_name GameData
extends RefCounted

const EXPEDITION_AREAS:=[
	"Longgrass Fields","Splitstream","Tanglewood","Leaning Cliffs",
	"Soggy Bottom","Cinder Hills","Glittergut Cave","Whiteout",
	"Baked Flats","Cloudtops","Swallowed Ruins","Thunder Beach",
	"Afterdark","Giant’s Footprint","Farside Valley","???"
]

static func expedition_area_level(area_index:int)->int:
	var index:=clampi(area_index,0,EXPEDITION_AREAS.size()-1)
	# Early areas begin close to a fresh Quiblet's level, then rise smoothly.
	return [2,5,9][index] if index<3 else 13+(index-3)*4

# One biome per island: colours for the tile floor, worn trail, cube cliffs and
# rim decorations, plus which decoration kinds grow on rims and wall tops,
# how many rivers cut the field, how walled-in it is ("walls": 0 = wide open
# plains, 1 = a tight cave), and the water colour used for rivers and pools.
const EXPEDITION_BIOMES:=[
	{"name":"meadow","ground":"#a6e26a","path":"#f2df9c","cliff":"#7a4a28","accent":"#3f7650","decor":["tree","bush","rock"],"density":.24,"walls":.1,"rivers":1,"water_color":"#7fd6f7"},
	{"name":"river","ground":"#a3df68","path":"#f0dc9a","cliff":"#78482a","accent":"#3f7650","decor":["tree","bush","rock"],"water":true,"water_color":"#7fd6f7","density":.18,"walls":.1,"rivers":3},
	{"name":"forest","ground":"#8fd35c","path":"#e2cf8e","cliff":"#6a4127","accent":"#2f5f3e","decor":["tree","bush","big_mushroom"],"density":.42,"walls":.6,"rivers":1,"water_color":"#6fcbe9","rock":"#8f9a8c","trunk":"birch"},
	{"name":"cliffs","ground":"#c2b184","path":"#e6d7a8","cliff":"#9a7a52","accent":"#6e5b43","decor":["boulder","rock"],"density":.2,"walls":.7,"rivers":0,"water_color":"#5fcff0"},
	{"name":"swamp","ground":"#6f9a52","path":"#b2a66e","cliff":"#5a4a34","accent":"#8bd06a","decor":["big_mushroom","mushroom"],"water":true,"water_color":"#5f9a8e","density":.26,"walls":.35,"rivers":3,"rock":"#6f7a5e"},
	{"name":"volcanic","ground":"#7a5c55","path":"#ab7a6c","cliff":"#4a3835","accent":"#f06a3f","decor":["boulder","rock"],"density":.2,"walls":.55,"rivers":1,"water_color":"#ff7a4a","rock":"#5a3a36"},
	{"name":"cave","ground":"#66748f","path":"#95a2ba","cliff":"#3a4356","accent":"#7fe0ff","decor":["boulder","crystal","big_mushroom"],"density":.26,"walls":1.0,"rivers":1,"water_color":"#4f9fd0","rock":"#5e6d8a"},
	{"name":"snow","ground":"#eef4f8","path":"#d3e3ee","cliff":"#a9bfd0","accent":"#ffffff","decor":["mound","boulder"],"density":.24,"walls":.2,"rivers":1,"water_color":"#a9dcf5"},
	{"name":"desert","ground":"#e6cf9a","path":"#9cd66c","cliff":"#c9a267","accent":"#6ea85a","decor":["cactus","boulder"],"density":.16,"walls":.15,"rivers":0,"water_color":"#5fd0f0","rock":"#8f5f56"},
	{"name":"sky","ground":"#d5e9f8","path":"#f0f8ff","cliff":"#f2f7fc","accent":"#ffffff","decor":["mound"],"density":.2,"walls":.25,"rivers":2,"water_color":"#bfe6ff"},
	{"name":"ruins","ground":"#a3a894","path":"#cbc9b0","cliff":"#75786c","accent":"#b9b6a3","decor":["pillar","block"],"density":.22,"walls":.8,"rivers":1,"water_color":"#6fa9b4"},
	{"name":"beach","ground":"#efdea7","path":"#a4dc73","cliff":"#c9a465","accent":"#4f9f68","decor":["tree","boulder"],"water":true,"water_color":"#7fdcf7","density":.16,"walls":.05,"rivers":2},
	{"name":"night","ground":"#524873","path":"#726699","cliff":"#2f2745","accent":"#c78cff","decor":["big_mushroom","crystal"],"density":.26,"walls":.65,"rivers":1,"water_color":"#6a5fb0","rock":"#5c4c8a"},
	{"name":"crater","ground":"#a8825f","path":"#c9a883","cliff":"#6a4d37","accent":"#8c7a68","decor":["boulder"],"density":.3,"walls":.5,"rivers":0,"water_color":"#5fcff0","rock":"#8a5c4c"},
	{"name":"valley","ground":"#a9e070","path":"#f1e0a3","cliff":"#78492a","accent":"#3f7650","decor":["tree","bush","rock"],"water":true,"water_color":"#84dbf4","density":.22,"walls":.15,"rivers":2,"trunk":"birch"},
	{"name":"void","ground":"#3f365a","path":"#5c5280","cliff":"#221d33","accent":"#ff8fd2","decor":["crystal","pillar"],"density":.3,"walls":.85,"rivers":1,"water_color":"#8a66e0","rock":"#4a3f6e"}
]

# Pokémon Quest–style voxel faces: every cube in an expedition shares one 3×2
# face atlas (Godot's BoxMesh layout) of 8×8 pixel cells with light per-pixel
# noise. The top face (atlas cell 1,1) stays bright; the side faces are darker
# and warm-tinted, so a grass cube reads as a grass top over dirt sides and a
# cliff cube shows a lit cap over shaded walls, with nearest filtering so the
# pixels stay crisp. The texture multiplies each cube's own colour.
const VOXEL_FACE_PIXELS:=8
static var voxel_face_atlas:ImageTexture
static func voxel_face_texture()->ImageTexture:
	if voxel_face_atlas!=null:return voxel_face_atlas
	var cell:=VOXEL_FACE_PIXELS;var image:=Image.create(cell*3,cell*2,false,Image.FORMAT_RGB8)
	var rng:=RandomNumberGenerator.new();rng.seed=1337
	for x in cell*3:
		for y in cell*2:
			var top:bool=x>=cell and x<cell*2 and y>=cell
			var noise:=rng.randf_range(-.025,.025)
			# Top faces are nearly flat with the odd faintly darker pixel (voxel grass);
			# side cells are darker with soft horizontal bands, like stacked soil layers.
			var speck:float=-.06 if (top and rng.randf()<.12) else 0.0
			var band:float=-.09 if (not top and y%4==3) else 0.0
			var color:Color=Color(1.0+noise+speck,1.0+noise+speck,1.0+noise+speck) if top else Color(.8+noise+band,.74+noise+band,.66+noise+band)
			image.set_pixel(x,y,color)
	voxel_face_atlas=ImageTexture.create_from_image(image)
	return voxel_face_atlas

static func apply_voxel_faces(material:BaseMaterial3D)->void:
	material.albedo_texture=voxel_face_texture();material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST

# Props (trees, rocks, bushes) get a flat face with only a few faintly darker
# pixel specks, like the canopies and rocks in Pokémon Quest; terrain stays
# completely flat-coloured so it reads as clean plastic blocks, not Minecraft.
static var voxel_prop_atlas:ImageTexture
static func voxel_prop_texture()->ImageTexture:
	if voxel_prop_atlas!=null:return voxel_prop_atlas
	var cell:=VOXEL_FACE_PIXELS;var image:=Image.create(cell*3,cell*2,false,Image.FORMAT_RGB8)
	var rng:=RandomNumberGenerator.new();rng.seed=4242
	for x in cell*3:
		for y in cell*2:
			var speck:float=-.07 if rng.randf()<.09 else 0.0
			image.set_pixel(x,y,Color(1.0+speck,1.0+speck,1.0+speck))
	voxel_prop_atlas=ImageTexture.create_from_image(image)
	return voxel_prop_atlas

static func apply_prop_specks(material:BaseMaterial3D)->void:
	material.albedo_texture=voxel_prop_texture();material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST

# Detailed Quest-style faces at DETAIL_PIXELS per face cell, built on a grid of
# DETAIL_BLOCK-pixel squares the way the reference textures are: sparse small
# lighter and darker squares ("specks"), and stripes made of broken runs of
# squares rather than solid lines. Each kind is a 3×2 box atlas of multipliers.
#   "grass": a few sparse squares, lighter more often than darker.
#   "wall":  side cells get two or three broken horizontal runs of squares plus
#            specks; the top cell (under a cap anyway) only specks.
#   "leaf":  many small squares in slightly lighter and darker greens, with a
#            couple of broken horizontal runs.
#   "trunk": broken vertical runs of darker squares and a few specks.
const DETAIL_PIXELS:=24
const DETAIL_BLOCK:=3
static var detail_atlases:={}
static func detail_texture(kind:String)->ImageTexture:
	if detail_atlases.has(kind):return detail_atlases[kind]
	var cell:=DETAIL_PIXELS;var blocks:int=cell/DETAIL_BLOCK;var image:=Image.create(cell*3,cell*2,false,Image.FORMAT_RGB8)
	var rng:=RandomNumberGenerator.new();rng.seed={"wall":91,"leaf":92,"trunk":93,"grass":94}.get(kind,90)
	var speck_chance:float={"wall":.07,"leaf":.22,"trunk":.06,"grass":.05}.get(kind,.06)
	var lighter_share:float={"leaf":.5,"grass":.65}.get(kind,.35)
	for cx in 3:
		for cy in 2:
			var top:bool=cx==1 and cy==1
			var values:={}
			for bx in blocks:
				for by in blocks:
					if rng.randf()<speck_chance:values[Vector2i(bx,by)]=rng.randf_range(.03,.05) if rng.randf()<lighter_share else rng.randf_range(-.05,-.08)
			var run_count:int={"wall":3,"leaf":2,"trunk":3,"grass":0}.get(kind,0)
			if kind=="wall" and top:run_count=0
			for i in run_count:
				var lane:int=rng.randi_range(0,blocks-1);var start_block:int=rng.randi_range(0,blocks-3);var length:int=rng.randi_range(2,mini(5,blocks-start_block))
				var shade:float=rng.randf_range(-.06,-.09) if rng.randf()<.7 else rng.randf_range(.03,.05)
				for j in length:
					var key:Vector2i=Vector2i(lane,start_block+j) if kind=="trunk" else Vector2i(start_block+j,lane)
					values[key]=shade
			for x in cell:
				for y in cell:
					var value:float=1.0+float(values.get(Vector2i(x/DETAIL_BLOCK,y/DETAIL_BLOCK),0.0))
					image.set_pixel(cx*cell+x,cy*cell+y,Color(value,value,value))
	var texture:=ImageTexture.create_from_image(image);detail_atlases[kind]=texture
	return texture

# A box with rounded edges and corners, for the soft plastic look of Quest's
# props and plateau lips. Each face is a subdivided grid whose points are pushed
# out from an inner box by `radius`, giving smooth normals around every edge.
# UVs use the same 3×2 face atlas as BoxMesh (top face in cell 1,1).
static var rounded_meshes:={}
# Bits of the `exposed` mask: which faces of a rounded box are open to the air.
# An edge or corner is rounded only where every face meeting there is exposed,
# so a block keeps sharp, seamless edges on sides that touch other terrain.
const BOX_POS_X:=1
const BOX_NEG_X:=2
const BOX_POS_Y:=4
const BOX_NEG_Y:=8
const BOX_POS_Z:=16
const BOX_NEG_Z:=32
const BOX_ALL_FACES:=63

static func rounded_box(size:Vector3,radius:float,segments:=4,exposed:int=BOX_ALL_FACES)->ArrayMesh:
	var key:=str(size)+":"+str(radius)+":"+str(segments)+":"+str(exposed)
	if rounded_meshes.has(key):return rounded_meshes[key]
	var half:=size*.5;var r:float=minf(radius,minf(half.x,minf(half.y,half.z))*.98)
	# Faces that touch other terrain are not inset, so the rounding never reaches them.
	var inset_pos:=Vector3(r if exposed&BOX_POS_X else 0.0,r if exposed&BOX_POS_Y else 0.0,r if exposed&BOX_POS_Z else 0.0)
	var inset_neg:=Vector3(r if exposed&BOX_NEG_X else 0.0,r if exposed&BOX_NEG_Y else 0.0,r if exposed&BOX_NEG_Z else 0.0)
	var upper:=half-inset_pos;var lower:=-half+inset_neg
	var faces:Array=[[Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,1,0),Vector2(1,0)],[Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,1,0),Vector2(2,0)],[Vector3(0,1,0),Vector3(1,0,0),Vector3(0,0,-1),Vector2(1,1)],[Vector3(0,-1,0),Vector3(1,0,0),Vector3(0,0,1),Vector2(0,1)],[Vector3(0,0,1),Vector3(1,0,0),Vector3(0,1,0),Vector2(0,0)],[Vector3(0,0,-1),Vector3(-1,0,0),Vector3(0,1,0),Vector2(2,1)]]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_bits:Array=[BOX_POS_X,BOX_NEG_X,BOX_POS_Y,BOX_NEG_Y,BOX_POS_Z,BOX_NEG_Z]
	for face_index in faces.size():
		if not exposed&int(face_bits[face_index]):continue  # a covered face is never seen
		var face:Array=faces[face_index]
		var n:Vector3=face[0];var u:Vector3=face[1];var v:Vector3=face[2];var cell:Vector2=face[3]
		var half_u:float=absf(u.dot(half));var half_v:float=absf(v.dot(half));var half_n:float=absf(n.dot(half))
		var points:Array=[];var normals:Array=[];var uvs:Array=[]
		for i in segments+1:
			for j in segments+1:
				var a:float=float(i)/float(segments)*2.0-1.0;var b:float=float(j)/float(segments)*2.0-1.0
				var p:Vector3=n*half_n+u*(a*half_u)+v*(b*half_v)
				var q:=Vector3(clampf(p.x,lower.x,upper.x),clampf(p.y,lower.y,upper.y),clampf(p.z,lower.z,upper.z))
				var dir:Vector3=p-q
				if dir.length()<.0001:points.append(q);normals.append(n)
				else:dir=dir.normalized();points.append(q+dir*r);normals.append(dir)
				uvs.append(Vector2((cell.x+(a*.5+.5))/3.0,(cell.y+(b*.5+.5))/2.0))
		for i in segments:
			for j in segments:
				var i00:int=i*(segments+1)+j;var i10:int=(i+1)*(segments+1)+j;var i01:int=i*(segments+1)+j+1;var i11:int=(i+1)*(segments+1)+j+1
				for index in [i00,i11,i10,i00,i01,i11]:  # Godot front faces: geometric normal points inward, like BoxMesh
					st.set_normal(normals[index]);st.set_uv(uvs[index]);st.add_vertex(points[index])
	var mesh:=st.commit();rounded_meshes[key]=mesh
	return mesh

# One shared low-poly sphere for every leaf ball on trees and shrubs.
static var leaf_sphere_mesh:SphereMesh
static func leaf_sphere()->SphereMesh:
	if leaf_sphere_mesh==null:
		leaf_sphere_mesh=SphereMesh.new();leaf_sphere_mesh.radius=.5;leaf_sphere_mesh.height=1.0;leaf_sphere_mesh.radial_segments=10;leaf_sphere_mesh.rings=6
	return leaf_sphere_mesh

# Positions for a cluster of overlapping leaf balls filling an ellipsoid of the
# given half extents: a guaranteed core ball plus `count` scattered ones, each
# with its own radius and a slight shade shift, so canopies and shrubs read as
# fluffy masses of many spheres.
static func leaf_cluster(center:Vector3,extent:Vector3,count:int,ball:float,leaf:Color,rng:RandomNumberGenerator)->Array:
	var balls:Array=[{"pos":center,"radius":ball*1.15,"color":leaf}]
	var reach:Vector3=Vector3(maxf(0.0,extent.x-ball*.55),maxf(0.0,extent.y-ball*.55),maxf(0.0,extent.z-ball*.55))
	for i in count:
		var offset:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))
		if offset.length()>1.0:offset=offset.normalized()*rng.randf_range(.35,1.0)
		var shade:=rng.randf_range(-.08,.1)
		balls.append({"pos":center+offset*reach,"radius":ball*rng.randf_range(.7,1.25),"color":leaf.lightened(shade) if shade>0.0 else leaf.darkened(-shade)})
	return balls

# The grass detail's top cell on its own, so a continuous ground mesh can tile it once per unit.
static var terrain_tile:ImageTexture
static func terrain_tile_texture()->ImageTexture:
	if terrain_tile!=null:return terrain_tile
	var atlas:Image=detail_texture("grass").get_image();var cell:=DETAIL_PIXELS
	var tile:=Image.create(cell,cell,false,Image.FORMAT_RGB8);tile.blit_rect(atlas,Rect2i(cell,cell,cell,cell),Vector2i.ZERO)
	terrain_tile=ImageTexture.create_from_image(tile);return terrain_tile

static func apply_detail(material:BaseMaterial3D,kind:String)->void:
	material.albedo_texture=detail_texture(kind);material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST

static func expedition_biome(area_index:int)->Dictionary:
	var biome:Dictionary=EXPEDITION_BIOMES[clampi(area_index,0,EXPEDITION_BIOMES.size()-1)].duplicate(true)
	for key in ["ground","path","cliff","accent","water_color"]:
		if biome.has(key):biome[key]=Color(str(biome[key]))
	biome.water=bool(biome.get("water",false))
	biome.walls=float(biome.get("walls",.3));biome.rivers=int(biome.get("rivers",1))
	if biome.has("rock"):biome.rock=Color(str(biome.rock))
	if biome.decor is String:biome.decor=[str(biome.decor)]
	return biome

# Difficulty curve. Enemy HP and damage multipliers rise by island (linear
# between anchors of [area, hp, damage]); damage between opposing sides is
# scaled by the level gap. Knockouts always revive after a fixed ten seconds.
const ENEMY_SCALING_ANCHORS:=[[0,.68,.58],[3,.85,.75],[6,1.0,.95],[10,1.25,1.15],[15,1.55,1.4]]
const LEVEL_GAP_PER_LEVEL:=.035
const LEVEL_GAP_MIN:=.35
const LEVEL_GAP_MAX:=2.5
const KNOCKOUT_REVIVE_SECONDS:=10.0
# Team Quiblets below full health recover this fraction of max HP every second.
const PASSIVE_REGEN_PER_SECOND:=.01
const EXTRA_ENEMY_AREAS:=[6,12]

static func enemy_scaling(area_index:int)->Dictionary:
	var area:=float(clampi(area_index,0,EXPEDITION_AREAS.size()-1))
	var previous:Array=ENEMY_SCALING_ANCHORS[0]
	for anchor in ENEMY_SCALING_ANCHORS:
		if area<=float(anchor[0]):
			var span:=float(anchor[0])-float(previous[0]);var t:=0.0 if span<=0.0 else (area-float(previous[0]))/span
			return {"hp":lerpf(float(previous[1]),float(anchor[1]),t),"damage":lerpf(float(previous[2]),float(anchor[2]),t)}
		previous=anchor
	return {"hp":float(previous[1]),"damage":float(previous[2])}

# Later islands answer the team's own growth. When the team's average level is
# above the island's stage level, enemies close a share of that lead
# (ENEMY_LEVEL_CATCH_UP), and they carry a share of the team's fitted Power
# Stone strength (ENEMY_STONE_SHARE), so an over-levelled, heavily stoned team
# still meets resistance instead of one-shotting everything past the midpoint.
# Both shares are zero on the first islands so early play is untouched.
const ENEMY_LEVEL_CATCH_UP:=[[0,0.0],[2,0.0],[3,.2],[6,.45],[10,.7],[15,.9]]
const ENEMY_STONE_SHARE:=[[0,0.0],[2,0.0],[3,.25],[6,.55],[10,.85],[15,1.1]]

static func anchored_value(anchors:Array,area_index:int)->float:
	var area:=float(clampi(area_index,0,EXPEDITION_AREAS.size()-1))
	var previous:Array=anchors[0]
	for anchor in anchors:
		if area<=float(anchor[0]):
			var span:=float(anchor[0])-float(previous[0]);var t:=0.0 if span<=0.0 else (area-float(previous[0]))/span
			return lerpf(float(previous[1]),float(anchor[1]),t)
		previous=anchor
	return float(previous[1])

static func enemy_level_catch_up(area_index:int)->float:
	return anchored_value(ENEMY_LEVEL_CATCH_UP,area_index)

static func enemy_stone_share(area_index:int)->float:
	return anchored_value(ENEMY_STONE_SHARE,area_index)

# The level enemies of this stage use once the team's lead is partly closed.
static func enemy_level_for_stage(stage_level:int,team_average_level:int,area_index:int)->int:
	if team_average_level<=stage_level:return stage_level
	return stage_level+roundi(float(team_average_level-stage_level)*enemy_level_catch_up(area_index))

# Fitted Power Stone strength of one Quiblet, split by stone type.
static func fitted_stone_power(q:Dictionary)->Dictionary:
	var totals:={"hp":0,"attack":0}
	for stone in q.get("power_slot_stones",[]):
		if not stone is Dictionary or stone.is_empty():continue
		if str(stone.get("type",""))=="Health":totals.hp+=int(stone.get("power",0))
		elif str(stone.get("type",""))=="Attack":totals.attack+=int(stone.get("power",0))
	return totals

# The team's stone strength enemies scale against: the average of the team's
# mean and its strongest member, so one heavily stoned carry is not diluted.
static func team_stone_power(team:Array)->Dictionary:
	var result:={"hp":0,"attack":0}
	if team.is_empty():return result
	for stat in ["hp","attack"]:
		var total:=0;var best:=0
		for q in team:
			var value:int=int(fitted_stone_power(q)[stat]);total+=value;best=maxi(best,value)
		result[stat]=int((float(total)/team.size()+float(best))*.5)
	return result

# Flat HP and Attack bonuses an enemy on this island carries from the team's stones.
static func enemy_stone_bonus(team_power:Dictionary,area_index:int)->Dictionary:
	var share:=enemy_stone_share(area_index)
	return {"hp":int(float(team_power.get("hp",0))*share),"attack":int(float(team_power.get("attack",0))*share)}

static func level_gap_factor(attacker_level:int,victim_level:int)->float:
	return clampf(1.0+LEVEL_GAP_PER_LEVEL*float(attacker_level-victim_level),LEVEL_GAP_MIN,LEVEL_GAP_MAX)

static func knockout_revive_seconds(_knockouts:int)->float:
	# Every knockout revives after the same ten seconds.
	return KNOCKOUT_REVIVE_SECONDS

static func extra_enemies_for_area(area_index:int)->int:
	var extra:=0
	for threshold in EXTRA_ENEMY_AREAS:
		if area_index>=int(threshold):extra+=1
	return extra

static func expected_matchup(team_levels:Array,stage_level:int,area_index:int,team_power:Dictionary={}) -> float:
	# Time-to-kill ratio of one average team member against one average enemy of
	# this stage: above 1 the team kills faster than it dies. Uses species-average
	# bases, the team's stone strength, and the enemies' catch-up level and stone share.
	if team_levels.is_empty():return 0.0
	var base_hp:=0.0;var base_atk:=0.0
	for entry in SPECIES:base_hp+=float(entry.base_hp);base_atk+=float(entry.base_atk)
	base_hp/=SPECIES.size();base_atk/=SPECIES.size()
	var level:=0.0
	for value in team_levels:level+=float(value)
	level/=team_levels.size()
	var scaling:=enemy_scaling(area_index)
	var enemy_level:=enemy_level_for_stage(stage_level,roundi(level),area_index);var enemy_bonus:=enemy_stone_bonus(team_power,area_index)
	var player_hp:=base_hp+level*15.0+float(team_power.get("hp",0));var player_damage:=(50.0+(base_atk+level*3.0+float(team_power.get("attack",0)))*.58)*level_gap_factor(roundi(level),enemy_level)
	var enemy_hp:=(base_hp+enemy_level*15.0+float(enemy_bonus.hp))*float(scaling.hp);var enemy_damage:=(50.0+(base_atk+enemy_level*3.0+float(enemy_bonus.attack))*.58)*float(scaling.damage)*level_gap_factor(enemy_level,roundi(level))
	return (player_damage/enemy_hp)/(enemy_damage/player_hp)

# Material follows the number of distinct bonus stats on the stone: Regular (0),
# Bronze (1), Silver (2), Gold (3), Diamond (4), Obsidian (5 or more). Drops roll
# at most four bonuses, so Obsidian only comes out of the Stone Workshop's Combiner.
const POWER_STONE_QUALITIES:=["Regular","Bronze","Silver","Gold","Diamond","Obsidian"]
const POWER_STONE_RANGES:=[Vector2i(20,120),Vector2i(90,220),Vector2i(190,360),Vector2i(330,520),Vector2i(480,700)]
const DEFAULT_ENEMY_STONE_DROP_CHANCE:=0.468
# Every Power Stone bonus stat has one exact, fixed effect. Bonuses on equipped
# stones stack additively per stat. Chances are clamped to 100%.
# A bonus entry on a stone is either the bonus name (one roll) or
# {"name":..., "stacks":n} when the Combiner merged n rolls of the same stat into
# one line; the effect is the fixed amount times the stacks. "template" renders
# the merged line with its combined percentage.
const POWER_STONE_BONUSES:={
	"Health":{"stat":"max_hp","amount":.05,"text":"+5% max HP","template":"+%d%% max HP"},
	"Attack":{"stat":"attack","amount":.05,"text":"+5% Attack","template":"+%d%% Attack"},
	"Critical Hit Rate":{"stat":"crit","amount":.08,"text":"+8% chance for a critical hit (1.5× damage)","template":"+%d%% chance for a critical hit (1.5× damage)"},
	"Movement Speed":{"stat":"speed","amount":.10,"text":"+10% movement speed","template":"+%d%% movement speed"},
	"Move Cooldown":{"stat":"cooldown","amount":.06,"text":"−6% move cooldowns","template":"−%d%% move cooldowns"},
	"Damage Resistance":{"stat":"resist","amount":.05,"text":"−5% damage taken","template":"−%d%% damage taken"},
	"Healing Received":{"stat":"healing","amount":.10,"text":"+10% healing received","template":"+%d%% healing received"},
	"Knockback Resistance":{"stat":"knockback","amount":.25,"text":"−25% knockback and pull distance","template":"−%d%% knockback and pull distance"},
	"Evasion":{"stat":"evasion","amount":.04,"text":"+4% chance to dodge a move","template":"+%d%% chance to dodge a move"}
}
const CRITICAL_HIT_MULTIPLIER:=1.5
# Special items only drop from expedition victories and are deliberately rare:
# a small chance on any win, a larger one for Boss levels, and a common one
# while a Fortune Charm is active. Weights pick which item drops.
const SPECIAL_ITEM_DROP_CHANCE:={"level":.03,"boss":.08,"fortune":.48}
# Treasure Keys roll separately on every victory so they stay fairly common
# compared with the other specials; the cache they open is the rare part.
const TREASURE_KEY_DROP_CHANCE:={"level":.12,"boss":.25,"fortune":.35}
const TREASURE_CACHE_LEVEL_CHANCE:=.45
const SPECIAL_ITEM_DROP_WEIGHTS:={
	"Memory Fruit":4,"Move Crystal":4,"Echo Crystal":3,"Growth Fruit":4,
	"Bountiful Berry":3,"Empty Leftover Jar":4,"Fortune Charm":2,"Challenger's Charm":2,
	"Health Charm":1,"Attack Charm":1,"Prodigy Fruit":1
}

static func special_item_drop_chance(stage_kind:String,fortune:bool)->float:
	if fortune:return float(SPECIAL_ITEM_DROP_CHANCE.fortune)
	return float(SPECIAL_ITEM_DROP_CHANCE.boss) if stage_kind=="boss" else float(SPECIAL_ITEM_DROP_CHANCE.level)

static func treasure_key_drop_chance(stage_kind:String,fortune:bool)->float:
	if fortune:return float(TREASURE_KEY_DROP_CHANCE.fortune)
	return float(TREASURE_KEY_DROP_CHANCE.boss) if stage_kind=="boss" else float(TREASURE_KEY_DROP_CHANCE.level)

static func roll_treasure_key(stage_kind:String,fortune:bool,rng:RandomNumberGenerator=null)->bool:
	return (rng.randf() if rng!=null else randf())<treasure_key_drop_chance(stage_kind,fortune)

# Returns the special item a victorious expedition drops, or "" for none.
static func roll_special_item(stage_kind:String,fortune:bool,rng:RandomNumberGenerator=null)->String:
	var roll:=rng.randf() if rng!=null else randf()
	if roll>=special_item_drop_chance(stage_kind,fortune):return ""
	var total:=0
	for weight in SPECIAL_ITEM_DROP_WEIGHTS.values():total+=int(weight)
	var pick:=(rng.randi_range(0,total-1) if rng!=null else randi_range(0,total-1))
	for item in SPECIAL_ITEM_DROP_WEIGHTS:
		pick-=int(SPECIAL_ITEM_DROP_WEIGHTS[item])
		if pick<0:return str(item)
	return ""
# Chance that a dropped Power Stone carries 1–4 bonus stats; Fortune doubles it.
const POWER_STONE_BONUS_DROP_CHANCE:=[.18,.06,.02,.005]

static func bonus_info(bonus_name:String)->Dictionary:
	return POWER_STONE_BONUSES.get(bonus_name,{})

static func bonus_name(bonus:Variant)->String:
	return str(bonus.get("name",bonus.get("description",""))) if bonus is Dictionary else str(bonus)

static func bonus_stacks(bonus:Variant)->int:
	return maxi(1,int(bonus.get("stacks",1))) if bonus is Dictionary else 1

static func bonus_text(name:String,stacks:int=1)->String:
	var info:=bonus_info(name)
	if info.is_empty():return "(no effect)"
	return str(info.text) if stacks<=1 else str(info.template)%roundi(float(info.amount)*stacks*100.0)

static func bonus_description(bonus:Variant)->String:
	# Unknown or legacy bonus names are shown as-is with no claimed effect.
	var name:=bonus_name(bonus);var stacks:=bonus_stacks(bonus)
	if bonus_info(name).is_empty():return name+" (no effect)"
	# A merged line reads like any other, with the added-together amount.
	return "%s: %s"%[name,bonus_text(name,stacks)]

static func stone_bonus_totals(stones:Array)->Dictionary:
	var totals:={}
	for stone in stones:
		if not stone is Dictionary or stone.is_empty():continue
		for bonus in stone.get("bonuses",[]):
			var info:=bonus_info(bonus_name(bonus))
			if info.is_empty():continue
			totals[info.stat]=float(totals.get(info.stat,0.0))+float(info.amount)*bonus_stacks(bonus)
	for stat in totals:totals[stat]=minf(float(totals[stat]),bonus_cap(str(stat)))
	return totals

# One stat can hold at most this many rolls on a single stone; rolls beyond it
# are lost when stones are combined (the Combiner preview says how many).
const MAX_BONUS_STACKS:=3
# Each stat's total across a Quiblet's equipped stones is capped, so sixteen
# slots of stacked stones cannot reach guaranteed criticals, dodges, or the like.
const POWER_STONE_BONUS_CAPS:={"max_hp":.6,"attack":.6,"crit":.5,"speed":.6,"cooldown":.5,"resist":.4,"healing":1.0,"knockback":1.0,"evasion":.3}

static func bonus_cap(stat:String)->float:
	return float(POWER_STONE_BONUS_CAPS.get(stat,INF))

# Merges bonus lists into one list of canonical entries (a name for a single
# roll, {"name","stacks"} for repeated stats, never above MAX_BONUS_STACKS) in first-seen order.
static func merge_power_stone_bonuses(lists:Array)->Array:
	var stacks:={};var order:Array=[]
	for bonuses in lists:
		for bonus in bonuses:
			var name:=bonus_name(bonus)
			if name.is_empty():continue
			if not stacks.has(name):stacks[name]=0;order.append(name)
			stacks[name]=int(stacks[name])+bonus_stacks(bonus)
	var merged:Array=[]
	for name in order:
		var count:=mini(int(stacks[name]),MAX_BONUS_STACKS)
		merged.append(name if count<=1 else {"name":name,"stacks":count})
	return merged

# Total rolls in the lists, before and after the per-stat stack cap.
static func bonus_roll_counts(lists:Array)->Dictionary:
	var raw:=0
	for bonuses in lists:
		for bonus in bonuses:raw+=bonus_stacks(bonus)
	var kept:=0
	for bonus in merge_power_stone_bonuses(lists):kept+=bonus_stacks(bonus)
	return {"raw":raw,"kept":kept,"lost":raw-kept}

static func power_stone_material(bonuses:Array)->String:
	return POWER_STONE_QUALITIES[mini(merge_power_stone_bonuses([bonuses]).size(),POWER_STONE_QUALITIES.size()-1)]

static func power_stone_tier_for_power(power:int)->int:
	for index in POWER_STONE_RANGES.size():
		if power<=POWER_STONE_RANGES[index].y:return index+1
	return POWER_STONE_RANGES.size()

# The average raw power of a freshly dropped stone of the given tier.
static func power_stone_drop_average(tier:int)->int:
	var power_range:Vector2i=POWER_STONE_RANGES[clampi(tier,1,POWER_STONE_RANGES.size())-1]
	return roundi((power_range.x+power_range.y)*.5)

const REVITALIZE_SHARE:=.90
const COMBINE_MIN_STONES:=2
const COMBINE_MAX_STONES:=4

# Stone Workshop: Revitalizer. The stone's power becomes 90% of the average drop
# at the given loot tier, unless it is already stronger than that.
static func revitalized_power(stone:Dictionary,loot_tier:int)->int:
	return maxi(int(stone.power),roundi(power_stone_drop_average(loot_tier)*REVITALIZE_SHARE))

static func revitalize_power_stone(stone:Dictionary,loot_tier:int)->Dictionary:
	var result:=normalize_power_stone(stone);var power:=revitalized_power(result,loot_tier)
	if power>int(result.power):result.power=power;result.tier=maxi(int(result.tier),clampi(loot_tier,1,POWER_STONE_RANGES.size()))
	return normalize_power_stone(result)

# Stone Workshop: Converter. Everything stays except the stat type.
static func convert_power_stone(stone:Dictionary)->Dictionary:
	var result:=normalize_power_stone(stone);result.type="Attack" if str(result.type)=="Health" else "Health"
	return normalize_power_stone(result)

# Stone Workshop: Combiner. "" when the stones can be combined, else the reason.
static func combine_problem(stones:Array)->String:
	if stones.size()<COMBINE_MIN_STONES:return "Choose %d to %d Power Stones to combine."%[COMBINE_MIN_STONES,COMBINE_MAX_STONES]
	if stones.size()>COMBINE_MAX_STONES:return "At most %d Power Stones can be combined at once."%COMBINE_MAX_STONES
	var first:=normalize_power_stone(stones[0]);var obsidian:=0
	for value in stones:
		var stone:=normalize_power_stone(value)
		if str(stone.type)!=str(first.type):return "Every stone must share one stat type: all Attack or all Health."
		if stone.bonuses.is_empty():return "Every stone must carry at least one bonus stat."
		if str(stone.quality)=="Obsidian":obsidian+=1
	if obsidian>1:return "Only one Obsidian stone can go into a combination."
	return ""

# The combined stone: the lowest input power, every bonus merged by stat, and a
# material read from the number of distinct stats (five or more make Obsidian).
static func combine_power_stones(stones:Array)->Dictionary:
	assert(combine_problem(stones).is_empty())
	var weakest:=normalize_power_stone(stones[0]);var lists:Array=[]
	for value in stones:
		var stone:=normalize_power_stone(value);lists.append(stone.bonuses)
		if int(stone.power)<int(weakest.power):weakest=stone
	var bonuses:=merge_power_stone_bonuses(lists)
	return normalize_power_stone({"type":str(weakest.type),"tier":int(weakest.tier),"power":int(weakest.power),"bonuses":bonuses,"quality":power_stone_material(bonuses)})

# Stone Workshop: Reforger. "" when the chosen bonus line can be rerolled using
# the sacrificed stone, else the reason.
static func reforge_problem(stone:Dictionary,sacrifice:Dictionary,bonus_index:int)->String:
	if stone.is_empty():return "Choose the Power Stone to reforge."
	var target:=normalize_power_stone(stone)
	if target.bonuses.is_empty():return "That stone has no bonus to reforge."
	if bonus_index<0 or bonus_index>=target.bonuses.size():return "Choose which bonus to reroll."
	if reforge_pool(target).is_empty():return "That stone already carries every bonus stat."
	if sacrifice.is_empty():return "Choose a second Power Stone with a bonus to consume."
	if normalize_power_stone(sacrifice).bonuses.is_empty():return "The consumed stone must carry at least one bonus stat."
	return ""

static func reforge_pool(stone:Dictionary)->Array:
	var owned:Array=stone.get("bonuses",[]).map(func(bonus):return bonus_name(bonus))
	return POWER_STONE_BONUSES.keys().filter(func(name):return not owned.has(name))

# Replaces the chosen bonus line (all of its stacks) with one fresh roll of a stat
# the stone does not already carry; the other lines keep their place.
static func reforge_power_stone(stone:Dictionary,bonus_index:int,rng:RandomNumberGenerator=null)->Dictionary:
	var result:=normalize_power_stone(stone);var pool:=reforge_pool(result)
	assert(bonus_index>=0 and bonus_index<result.bonuses.size() and not pool.is_empty())
	result.bonuses[bonus_index]=pool[rng.randi_range(0,pool.size()-1) if rng!=null else randi_range(0,pool.size()-1)]
	result.quality=power_stone_material(result.bonuses)
	return normalize_power_stone(result)

static func quiblet_bonus_totals(q:Dictionary)->Dictionary:
	# Equipped Power Stone bonuses plus any permanent seasoning the Quiblet
	# arrived with from spiced stews; both stack additively per stat.
	var totals:=stone_bonus_totals(q.get("power_slot_stones",[]))
	var seasoning=q.get("spice_bonuses",{})
	if seasoning is Dictionary:
		for stat in seasoning:totals[stat]=float(totals.get(stat,0.0))+float(seasoning[stat])
	return totals

static func roll_power_stone_bonuses(fortune:bool=false,rng:RandomNumberGenerator=null)->Array:
	var roll:=rng.randf() if rng!=null else randf();var count:=0
	for index in POWER_STONE_BONUS_DROP_CHANCE.size():
		if roll<float(POWER_STONE_BONUS_DROP_CHANCE[index])*(2.0 if fortune else 1.0):count=index+1
	var pool:Array=POWER_STONE_BONUSES.keys();var chosen:Array=[]
	for i in count:
		var pick:int=(rng.randi_range(0,pool.size()-1) if rng!=null else randi_range(0,pool.size()-1))
		chosen.append(pool[pick]);pool.remove_at(pick)
	return chosen
const POWER_STONE_DROP_SHARE:=0.96

static func roll_enemy_stone_kind(enemy_data:Dictionary,rng:RandomNumberGenerator=null)->String:
	# Preserve the old chance of at least one stone: 1 - (1 - .30) * (1 - .24).
	# Individual enemies can override stone_drop_chance (a probability from 0–1).
	var chance:=clampf(float(enemy_data.get("stone_drop_chance",DEFAULT_ENEMY_STONE_DROP_CHANCE)),0.0,1.0)
	var drop_roll:=rng.randf() if rng!=null else randf()
	if chance<=0.0 or (chance<1.0 and drop_roll>=chance):return ""
	# Only a successful drop rolls its type. Never award both types to one enemy.
	var kind_roll:=rng.randf() if rng!=null else randf()
	return "power_stone" if kind_roll<POWER_STONE_DROP_SHARE else "move_stone"

static func normalize_power_stone(value:Dictionary)->Dictionary:
	# Legacy stones keep their exact power and bonuses. Only missing presentation
	# metadata is inferred; overlapping ranges never change an explicitly saved tier.
	var stone:=value.duplicate(true)
	stone.type=str(stone.get("type",stone.get("stone_type","Health")))
	stone.power=int(stone.get("power",20))
	# Bonus lines are canonical and merged by stat; the material always follows
	# the number of distinct stats, so a stone never claims a quality it lacks.
	stone.bonuses=merge_power_stone_bonuses([stone.get("bonuses",[])])
	stone.quality=power_stone_material(stone.bonuses)
	stone.bonus_count=stone.bonuses.size()
	var tier:=int(stone.get("tier",0))
	if tier<1 or tier>5:
		tier=5
		for index in POWER_STONE_RANGES.size():
			if stone.power<=POWER_STONE_RANGES[index].y:
				tier=index+1;break
	stone.tier=tier
	return stone

static func make_power_stone(stone_type:String,tier:int,bonuses:Array=[])->Dictionary:
	assert(stone_type in ["Health","Attack"] and tier>=1 and tier<=5 and bonuses.size()<=POWER_STONE_BONUSES.size())
	# Quality is independent of power tier and corresponds exactly to the supplied
	# bonus stats. No undefined bonus effects or rarity weights are invented here.
	var power_range:Vector2i=POWER_STONE_RANGES[tier-1]
	return normalize_power_stone({"type":stone_type,"tier":tier,"power":randi_range(power_range.x,power_range.y),"bonuses":bonuses.duplicate(true)})

static func power_stone_tier_for_level(level:int)->int:
	# Keep the existing level * 6 progression as the tier selector. Roll the actual
	# power only after the tier is chosen, using its inclusive configured range.
	var expected_power:=level*6
	for index in range(POWER_STONE_RANGES.size()-1,-1,-1):
		if expected_power>=POWER_STONE_RANGES[index].x:return index+1
	return 1

const COLORS := {
	"ink": Color("#243447"), "muted": Color("#718096"), "cream": Color("#fff8e7"),
	"paper": Color("#fffdf5"), "leaf": Color("#4f9f68"), "leaf_dark": Color("#2f6f4e"),
	"berry": Color("#8f5bd7"), "gold": Color("#f2b84b"), "coral": Color("#ed6a5a"),
	"water": Color("#6dc7d9"), "sky": Color("#dff4ea"), "stone": Color("#8492a6")
}

const SPECIES := [
	{"name":"Plip", "element":"Water", "color":Color("#69c8e5"), "accent":Color("#d8f6ff"), "shape":"fins", "base_hp":150, "base_atk":30, "range":165.0, "family":"plip"},
	{"name":"Swellit", "element":"Water", "color":Color("#3f91c7"), "accent":Color("#bfe9ff"), "shape":"fins", "base_hp":198, "base_atk":35, "range":180.0, "family":"plip"},
	{"name":"Spriggle", "element":"Green", "color":Color("#78bd64"), "accent":Color("#daf09b"), "shape":"ears", "base_hp":152, "base_atk":30, "range":155.0, "family":"spriggle"},
	{"name":"Frondle", "element":"Green", "color":Color("#4f9f68"), "accent":Color("#c9e785"), "shape":"crest", "base_hp":196, "base_atk":34, "range":125.0, "family":"spriggle"},
	{"name":"Vinee", "element":"Green", "color":Color("#65ad65"), "accent":Color("#e1ef8b"), "shape":"tail", "base_hp":174, "base_atk":37, "range":100.0, "family":"vinee"},
	{"name":"Bloomie", "element":"Green", "color":Color("#8dcf75"), "accent":Color("#f2b7d2"), "shape":"tuft", "base_hp":185, "base_atk":24, "range":145.0, "family":"bloomie"},
	{"name":"Sparko", "element":"Fire", "color":Color("#f07a4d"), "accent":Color("#ffd25f"), "shape":"tail", "base_hp":140, "base_atk":39, "range":145.0, "family":"sparko"},
	{"name":"Scorchit", "element":"Fire", "color":Color("#d94b3f"), "accent":Color("#ffad48"), "shape":"horn", "base_hp":192, "base_atk":43, "range":105.0, "family":"sparko"}
]

const MOVES := {
	"Water Shot":{"power":30.0,"cooldown":1.3,"range":200.0,"color":Color("#5bb9dc"),"kind":"projectile","desc":"Fires a fast, compact projectile of water."},
	"Water Jet":{"power":24.0,"cooldown":3.0,"range":220.0,"color":Color("#5bb9dc"),"kind":"projectile","desc":"Fires a continuous narrow stream that repeatedly damages enemies caught in it."},
	"Bubble Shot":{"power":34.0,"cooldown":2.0,"range":180.0,"color":Color("#5bb9dc"),"kind":"projectile","desc":"Fires a slow bubble that pops on impact, damaging a small area."},
	"Bubble Burst":{"power":42.0,"cooldown":3.2,"range":95.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Creates bubbles around the user that burst, damaging nearby enemies."},
	"Bubble Trap":{"power":18.0,"cooldown":5.5,"range":170.0,"color":Color("#5bb9dc"),"kind":"projectile","desc":"Encases an enemy in a bubble and temporarily prevents movement."},
	"Bubble Shield":{"power":0.0,"cooldown":7.0,"range":0.0,"color":Color("#5bb9dc"),"kind":"recover","desc":"Encases the user in a bubble that absorbs a limited amount of incoming damage."},
	"Big Bubble":{"power":62.0,"cooldown":5.5,"range":175.0,"color":Color("#5bb9dc"),"kind":"projectile","desc":"Sends a huge, slow bubble forward that damages and pushes enemies along with it."},
	"Splash Dash":{"power":44.0,"cooldown":3.0,"range":110.0,"color":Color("#5bb9dc"),"kind":"burst","icon":"res://textures/Moves/SplashDash.png","desc":"The user surges forward in a splash of water, damaging enemies it hits."},
	"Backwash":{"power":56.0,"cooldown":4.0,"range":90.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Fires a powerful short-range blast of water with strong knockback."},
	"Water Burst":{"power":50.0,"cooldown":4.2,"range":105.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Releases an explosion of water in every direction around the user."},
	"Rain Drop":{"power":48.0,"cooldown":4.5,"range":190.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Launches water upward so it falls onto a targeted area."},
	"Hydro Shot":{"power":72.0,"cooldown":5.2,"range":240.0,"color":Color("#5bb9dc"),"kind":"projectile","desc":"Fires a large, compressed water projectile that deals heavy damage and pierces enemies."},
	"Breaker":{"power":64.0,"cooldown":5.0,"range":100.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Creates a tall wave in front of the user that crashes onto nearby enemies."},
	"Riptide":{"power":46.0,"cooldown":4.0,"range":160.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Sends a moving current across the ground that carries enemies in its direction."},
	"Undertow":{"power":38.0,"cooldown":5.0,"range":115.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Creates an inward current that drags nearby enemies toward the user."},
	"Whirlpool":{"power":54.0,"cooldown":6.0,"range":120.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Creates swirling water that repeatedly damages and pulls nearby enemies around."},
	"Wave Rush":{"power":58.0,"cooldown":4.5,"range":130.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Creates a wave that the user rides forward through enemies."},
	"Tidal Wave":{"power":74.0,"cooldown":6.5,"range":180.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Sends a broad wave forward that damages and carries enemies."},
	"Water Spout":{"power":66.0,"cooldown":5.5,"range":190.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Erupts a column of water underneath an enemy, damaging and launching it upward."},
	"Spray":{"power":38.0,"cooldown":2.6,"range":95.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Blasts a wide cone of water at close range."},
	"Downpour":{"power":68.0,"cooldown":7.0,"range":190.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Creates heavy rain over an area, repeatedly damaging enemies inside."},
	"Tsunami":{"power":92.0,"cooldown":10.0,"range":220.0,"color":Color("#5bb9dc"),"kind":"burst","desc":"Unleashes a massive wave across a broad area, dealing extreme damage and carrying enemies."},
	"Leaf Shot":{"power":30.0,"cooldown":1.3,"range":200.0,"color":Color("#65b96d"),"kind":"projectile","desc":"Fires a sharp leaf as a fast projectile."},
	"Vine Whip":{"power":42.0,"cooldown":2.6,"range":100.0,"color":Color("#65b96d"),"kind":"burst","desc":"Sweeps a long vine across an arc in front of the user."},
	"Vine Spear":{"power":48.0,"cooldown":3.0,"range":190.0,"color":Color("#65b96d"),"kind":"projectile","desc":"Thrusts a vine straight forward as a long piercing stab."},
	"Vine Grab":{"power":30.0,"cooldown":4.5,"range":160.0,"color":Color("#65b96d"),"kind":"projectile","desc":"Grabs an enemy with a vine and pulls it toward the user."},
	"Rootbind":{"power":22.0,"cooldown":5.0,"range":170.0,"color":Color("#65b96d"),"kind":"burst","desc":"Grows roots around an enemy, temporarily holding it in place."},
	"Thorn Burst":{"power":52.0,"cooldown":4.0,"range":165.0,"color":Color("#65b96d"),"kind":"burst","desc":"Causes sharp thorns to erupt from the ground around a targeted location."},
	"Sprout":{"power":40.0,"cooldown":3.0,"range":170.0,"color":Color("#65b96d"),"kind":"burst","desc":"Rapidly grows a plant underneath an enemy, striking it from below."},
	"Seed Pop":{"power":38.0,"cooldown":2.5,"range":190.0,"color":Color("#65b96d"),"kind":"projectile","desc":"Fires a seed that sticks where it lands and bursts shortly afterward."},
	"Healing Bloom":{"power":0.0,"cooldown":7.0,"range":0.0,"color":Color("#65b96d"),"kind":"recover","desc":"Grows a flower that periodically heals nearby allies."},
	"Pollen Puff":{"power":0.0,"cooldown":5.0,"range":0.0,"color":Color("#65b96d"),"kind":"recover","desc":"Releases healing pollen that restores HP to the user and nearby allies."},
	"Soothing Scent":{"power":0.0,"cooldown":6.0,"range":0.0,"color":Color("#65b96d"),"kind":"recover","desc":"Removes negative status effects from the user."},
	"Overgrowth":{"power":76.0,"cooldown":7.0,"range":150.0,"color":Color("#65b96d"),"kind":"burst","desc":"Causes a huge mass of vegetation to erupt, damaging and pushing enemies."},
	"Spore Cloud":{"power":24.0,"cooldown":6.0,"range":130.0,"color":Color("#65b96d"),"kind":"burst","desc":"Releases spores that inflict a disabling status on enemies caught inside."},
	"Thorn Armor":{"power":0.0,"cooldown":7.5,"range":0.0,"color":Color("#65b96d"),"kind":"recover","desc":"Temporarily covers the user in thorns so enemies that hit it take damage."},
	"Seed Mine":{"power":58.0,"cooldown":5.5,"range":160.0,"color":Color("#65b96d"),"kind":"burst","desc":"Plants a dormant seed that violently sprouts when an enemy approaches."},
	"Root Slam":{"power":72.0,"cooldown":6.0,"range":155.0,"color":Color("#65b96d"),"kind":"burst","desc":"Grows a massive root that rises and slams down onto an area."},
	"Vine Swing":{"power":38.0,"cooldown":3.0,"range":180.0,"color":Color("#65b96d"),"kind":"burst","desc":"Attaches a vine to a target or location and rapidly pulls the user toward it."},
	"Growth Spurt":{"power":0.0,"cooldown":8.0,"range":0.0,"color":Color("#65b96d"),"kind":"recover","desc":"Temporarily makes the user larger, increasing the size and force of physical attacks."},
	"Cocoon":{"power":0.0,"cooldown":9.0,"range":0.0,"color":Color("#65b96d"),"kind":"recover","desc":"Encases the user and gradually heals it while preventing other actions."},
	"Leech Bloom":{"power":46.0,"cooldown":5.0,"range":155.0,"color":Color("#65b96d"),"kind":"projectile","desc":"Grows a parasitic bloom that damages a target and restores HP to the user."},
	"Last Bloom":{"power":0.0,"cooldown":11.0,"range":0.0,"color":Color("#65b96d"),"kind":"recover","desc":"Creates a powerful final bloom that greatly heals nearby allies when the user is in danger."},
	"Fireball":{"power":36.0,"cooldown":1.6,"range":205.0,"color":Color("#ef654c"),"kind":"projectile","desc":"Fires a basic ball of flame that explodes on impact."},
	"Flame Burst":{"power":46.0,"cooldown":2.7,"range":95.0,"color":Color("#ef654c"),"kind":"burst","desc":"Releases a concentrated blast of fire directly in front of the user."},
	"Spark Burst":{"power":42.0,"cooldown":3.0,"range":100.0,"color":Color("#ef654c"),"kind":"burst","desc":"Releases fire outward around the user."},
	"Flare":{"power":54.0,"cooldown":4.0,"range":110.0,"color":Color("#ef654c"),"kind":"burst","desc":"Creates a sudden fiery explosion around the user with knockback."},
	"Flame Dash":{"power":48.0,"cooldown":3.2,"range":120.0,"color":Color("#ef654c"),"kind":"burst","desc":"Engulfs the user in fire and dashes through enemies."},
	"Blazing Rush":{"power":66.0,"cooldown":5.0,"range":145.0,"color":Color("#ef654c"),"kind":"burst","desc":"Performs a longer, heavier fiery charge through enemies."},
	"Fire Trail":{"power":52.0,"cooldown":4.5,"range":145.0,"color":Color("#ef654c"),"kind":"burst","desc":"Rushes forward while leaving persistent flames behind."},
	"Flame Wave":{"power":64.0,"cooldown":5.0,"range":180.0,"color":Color("#ef654c"),"kind":"burst","desc":"Sends a broad moving wall of fire forward."},
	"Firestorm":{"power":72.0,"cooldown":7.0,"range":190.0,"color":Color("#ef654c"),"kind":"burst","desc":"Causes repeated flame eruptions throughout a targeted area."},
	"Inferno":{"power":100.0,"cooldown":11.0,"range":120.0,"color":Color("#ef654c"),"kind":"burst","desc":"Creates an enormous explosion around the user with a very long cooldown."},
	"Flame Pillar":{"power":64.0,"cooldown":5.5,"range":190.0,"color":Color("#ef654c"),"kind":"burst","desc":"Causes a column of fire to erupt beneath a target."},
	"Meteor Ember":{"power":70.0,"cooldown":6.5,"range":210.0,"color":Color("#ef654c"),"kind":"burst","desc":"Launches fire high into the air before it crashes onto a targeted location."},
	"Flame Spin":{"power":56.0,"cooldown":4.5,"range":100.0,"color":Color("#ef654c"),"kind":"burst","desc":"Spins while engulfed in fire, repeatedly damaging nearby enemies."},
	"Heat Haze":{"power":0.0,"cooldown":7.0,"range":0.0,"color":Color("#ef654c"),"kind":"recover","desc":"Surrounds the user with distorted hot air, reducing enemy accuracy."},
	"Ignite":{"power":34.0,"cooldown":4.0,"range":180.0,"color":Color("#ef654c"),"kind":"projectile","desc":"Sets an enemy on fire, dealing damage over time."},
	"Fire Mine":{"power":58.0,"cooldown":5.5,"range":165.0,"color":Color("#ef654c"),"kind":"burst","desc":"Leaves a dormant ember that explodes when an enemy approaches."},
	"Combust":{"power":70.0,"cooldown":5.0,"range":165.0,"color":Color("#ef654c"),"kind":"burst","desc":"Causes a Burning enemy to erupt for immediate damage, consuming its Burn."},
	"Smoke Cloud":{"power":20.0,"cooldown":6.0,"range":135.0,"color":Color("#ef654c"),"kind":"burst","desc":"Fills an area with smoke that interferes with enemy accuracy and targeting."},
	"Cauterize":{"power":0.0,"cooldown":6.0,"range":0.0,"color":Color("#ef654c"),"kind":"recover","desc":"Damages the user slightly to remove applicable negative status effects."},
	"Firework":{"power":76.0,"cooldown":7.0,"range":210.0,"color":Color("#ef654c"),"kind":"burst","desc":"Launches fire upward, where it explodes and rains burning fragments over an area."}
}

const LEARNSETS := [
	["Water Shot","Bubble Shot","Splash Dash","Backwash","Water Burst","Rain Drop","Spray"],
	["Water Shot","Water Jet","Hydro Shot","Breaker","Riptide","Undertow","Whirlpool","Wave Rush","Tidal Wave","Water Spout","Downpour","Tsunami"],
	["Leaf Shot","Seed Pop","Sprout","Thorn Burst","Spore Cloud","Seed Mine","Soothing Scent"],
	["Leaf Shot","Vine Whip","Vine Spear","Rootbind","Thorn Burst","Sprout","Seed Pop","Overgrowth","Root Slam","Growth Spurt","Seed Mine"],
	["Vine Whip","Vine Spear","Vine Grab","Rootbind","Thorn Burst","Sprout","Seed Mine","Root Slam","Leech Bloom"],
	["Healing Bloom","Pollen Puff","Soothing Scent","Spore Cloud","Thorn Armor","Cocoon","Last Bloom"],
	["Fireball","Flame Burst","Spark Burst","Flare","Flame Dash","Flame Pillar","Ignite"],
	["Fireball","Flame Burst","Flare","Flame Dash","Blazing Rush","Fire Trail","Flame Wave","Firestorm","Inferno","Flame Pillar","Ignite","Combust"]
]

const MOVE_STONES := [
	{"name":"Echo Stone","color":"🟣","desc":"Repeats the entire move shortly after it finishes. Other equipped stones apply to the repeat, but the move’s cooldown is 35% longer.","effect":"echo","texture":"res://textures/MoveStones/EchoStone.png"},
	{"name":"Heavy Stone","color":"🟠","desc":"Increases power or effect strength by 35%, but increases cooldown by 28%.","effect":"heavy","texture":"res://textures/MoveStones/HeavyStone.png"},
	{"name":"Reach Stone","color":"🩵","desc":"Increases range and travel distance by 38%.","effect":"reach","texture":"res://textures/MoveStones/ReachStone.png"},
	{"name":"Chain Stone","color":"🟡","desc":"Jumps from a hit target to another nearby target at 60% effectiveness.","effect":"chain","texture":"res://textures/MoveStones/ChainStone.png"},
	{"name":"Sharing Stone","color":"🩷","desc":"Shares compatible healing or support effects with nearby allies at 55% effectiveness.","effect":"sharing","texture":"res://textures/MoveStones/SharingStone.png"},
	{"name":"Split Stone","color":"🔴","desc":"Creates three independent copies at 46% effectiveness each.","effect":"split","texture":"res://textures/MoveStones/SplitStone.png"},
	{"name":"Rush Stone","color":"🔵","desc":"Reduces cooldown by 28% with no power or effect-strength penalty.","effect":"rush","texture":"res://textures/MoveStones/RushStone.png"},
	{"name":"Seeking Stone","color":"🟩","desc":"Compatible projectiles home and curve toward their targets.","effect":"seeking","texture":"res://textures/MoveStones/SeekingStone.png"},
	{"name":"Lingering Stone","color":"🟪","desc":"Compatible effects last 65% longer. Damaging areas gain a lingering pulse.","effect":"lingering","texture":"res://textures/MoveStones/LingeringStone.png"},
	{"name":"Blast Stone","color":"🟤","desc":"Increases compatible effect area and size by 65%.","effect":"blast","texture":"res://textures/MoveStones/BlastStone.png"},
	{"name":"Force Stone","color":"💚","desc":"Greatly increases knockback and displacement.","effect":"force","texture":"res://textures/MoveStones/ForceStone.png"},
	{"name":"Drain Stone","color":"🩸","desc":"Heals the user for 15% of damage dealt by the move.","effect":"drain","texture":"res://textures/MoveStones/DrainStone.png"},
	{"name":"Link Stone","color":"⬜","desc":"Links this move to another linked move. The next move activates at 65% effectiveness and ignores cooldown. Link chains cannot revisit a move.","effect":"link","texture":"res://textures/MoveStones/LinkStone.png"}
]

const INGREDIENTS := {
	"Bumbleberry":{"icon":"●","texture":"res://textures/Items/BumbleBerry.png","color":Color("#a65ac7"),"tags":["sweet","soft","fruit"],"tier":1,"feel":"A pair of plump berries with a sweet, fizzy taste. They make a faint buzz when shaken."},
	"Emberpepper":{"icon":"♠","texture":"res://textures/Items/Emberpepper.png","color":Color("#e45d3f"),"tags":["spicy","dry","plant"],"tier":1,"feel":"A scorching pepper that gets hotter the longer you chew it. Swallowing quickly is advised."},
	"Dewmelon":{"icon":"◉","texture":"res://textures/Items/Dewmelon.png","color":Color("#74cfd0"),"tags":["sweet","juicy","fruit"],"tier":1,"feel":"A cool, watery melon with a thin, crisp rind. Cutting one open releases an impressive amount of juice."},
	"Knobroot":{"icon":"◆","texture":"res://textures/Items/Knobroot.png","color":Color("#9a7148"),"tags":["earthy","hard","root"],"tier":1,"feel":"A crunchy root with a thick, flavorful knob at the end. Most Quiblets save the knob for last."},
	"Curlcap":{"icon":"♣","texture":"res://textures/Items/Curlcap.png","color":Color("#bb8060"),"tags":["savory","soft","fungus"],"tier":1,"feel":"A firm mushroom with a cap that curls inward as it grows. The curled edges are especially chewy."},
	"Stonebean":{"icon":"⬢","texture":"res://textures/Items/Stonebean.png","color":Color("#78818b"),"tags":["savory","hard","seed"],"tier":2,"feel":"A dense bean with a shell nearly as hard as stone. It takes some determined chewing to get inside."},
	"Honeybulb":{"icon":"⬟","texture":"res://textures/Items/Honeybulb.png","color":Color("#e4ad39"),"tags":["sweet","earthy","root"],"tier":2,"feel":"A soft bulb filled with warm, sticky nectar. Biting into one without making a mess is nearly impossible."},
	"Bitterleaf":{"icon":"❧","texture":"res://textures/Items/BitterLeaf.png","color":Color("#679b4c"),"tags":["bitter","dry","leaf"],"tier":1,"feel":"A thick, crunchy leaf with an incredibly bitter taste. Interestingly, some Quiblets can't get enough of it."},
	"Puffshroom":{"icon":"☁","texture":"res://textures/Items/Puffshroom.png","color":Color("#b99ac9"),"tags":["bitter","soft","fungus"],"tier":2,"feel":"A soft mushroom with a cap full of tiny air pockets. Biting into one makes it collapse with a little puff."},
	"Crystalcorn":{"icon":"✦","texture":"res://textures/Items/Crystalcorn.png","color":Color("#efc748"),"tags":["sweet","dry","seed"],"tier":2,"feel":"A hard, glassy kernel that cracks apart with a surprisingly sweet crunch."},
	"Brinepod":{"icon":"◒","texture":"res://textures/Items/Brinepod.png","color":Color("#4aa7b8"),"tags":["salty","juicy","seed"],"tier":3,"feel":"A soft pod swollen with salty water. Bite too hard and most of it won't end up in your mouth."},
	"Sparkfruit":{"icon":"⚡","texture":"res://textures/Items/Sparkfruit.png","color":Color("#e8d833"),"tags":["sour","juicy","fruit"],"tier":3,"feel":"A prickly fruit that builds up a small electric charge as it ripens. Tingly on the tongue."},
	"Oldroot":{"icon":"⬣","texture":"res://textures/Items/Oldroot.png","color":Color("#69717a"),"tags":["bitter","hard","root"],"tier":3,"feel":"An incredibly tough root that can bend without breaking. Most Quiblets prefer to gnaw on it slowly."},
	"Glowcap":{"icon":"✺","texture":"res://textures/Items/Glowcap.png","color":Color("#72c98b"),"tags":["savory","soft","fungus"],"tier":3,"feel":"A tender mushroom with a cap that gives off a faint green glow."},
	"Frostberry":{"icon":"❄","texture":"res://textures/Items/FrostBerry.png","color":Color("#8bd9e8"),"tags":["sour","soft","fruit"],"tier":3,"feel":"A tiny berry that's always cold to the touch. Its frozen skin gives way with a sharp little crunch."},
	"Sunplum":{"icon":"☀","texture":"res://textures/Items/SunPlum.png","color":Color("#ed9346"),"tags":["sweet","juicy","fruit"],"tier":4,"feel":"A juicy plum that stays pleasantly warm from the sun. Its flesh gets sweeter as it heats up."}
}

# Stage level at which each ingredient tier drops at full weight. Below that the
# weight fades over INGREDIENT_TIER_RAMP levels down to INGREDIENT_TIER_FLOOR, so
# rare ingredients stay possible early but uncommon. Initial balance values.
const INGREDIENT_TIER_LEVELS:=[0,6,14,24]
const INGREDIENT_TIER_RAMP:=6.0
const INGREDIENT_TIER_FLOOR:=.04

static func ingredient_drop_weight(ingredient_name:String,stage_level:int)->float:
	var tier:=clampi(int(INGREDIENTS[ingredient_name].get("tier",1)),1,INGREDIENT_TIER_LEVELS.size())
	var full_level:int=INGREDIENT_TIER_LEVELS[tier-1]
	if stage_level>=full_level:return 1.0
	return lerpf(INGREDIENT_TIER_FLOOR,1.0,clampf((stage_level-(full_level-INGREDIENT_TIER_RAMP))/INGREDIENT_TIER_RAMP,0.0,1.0))

static func roll_ingredient(stage_level:int,candidates:Array=[],rng:RandomNumberGenerator=null)->String:
	var names:Array=candidates if not candidates.is_empty() else INGREDIENTS.keys()
	var weights:Array[float]=[];var total:=0.0
	for ingredient_name in names:
		var weight:=ingredient_drop_weight(ingredient_name,stage_level);weights.append(weight);total+=weight
	var roll:=(rng.randf() if rng!=null else randf())*total
	for index in names.size():
		roll-=weights[index]
		if roll<0.0:return names[index]
	return names[-1]

# Rarity of an expedition pickup for the collection animation: 0 plain, 1 good
# (gold sparkles), 2 great (brighter two-tone sparkles with a glow). Move Stones
# are the 4% stone drop, so every one counts as good.
static func reward_sparkle_level(reward:Dictionary)->int:
	match str(reward.get("kind","")):
		"ingredient":
			var tier:=int(INGREDIENTS.get(str(reward.get("name","")),{}).get("tier",1))
			return 2 if tier>=4 else (1 if tier==3 else 0)
		"move_stone":return 1
		"special":return 2
		"power_stone":
			var stone:=normalize_power_stone(reward)
			if int(stone.tier)>=4 or int(stone.bonus_count)>=2:return 2
			if int(stone.tier)>=3 or int(stone.bonus_count)>=1:return 1
	return 0

# Training. Helpers are consumed unless preserved by the added ingredients.
# Move training rolls a success chance from helper relationships only; EXP
# training always succeeds and converts a share of each helper's lifetime EXP.
# Relationships: same species, same evolution family, same type, none.
const MOVE_TRAINING_BASE_CHANCE:=5.0
const MOVE_TRAINING_MAX_CHANCE:=95.0
const MOVE_TRAINING_HELPER_CHANCE:={"species":25.0,"family":20.0,"type":12.0,"none":5.0}
const EXP_TRAINING_SHARE:=.30
const EXP_TRAINING_HELPER_MULTIPLIER:={"species":1.75,"family":1.5,"type":1.2,"none":1.0}
# Preservation chance per added ingredient: rarity tier × compatibility with the helper.
const PRESERVATION_CHANCE:={1:{"poor":2.5,"neutral":5.0,"match":10.0},2:{"poor":5.0,"neutral":10.0,"match":20.0},3:{"poor":7.5,"neutral":15.0,"match":30.0},4:{"poor":10.0,"neutral":20.0,"match":40.0}}
# Later learnset entries are rarer: each step down the learnset multiplies the pick weight by this.
const MOVE_RARITY_DECAY:=.7
# Per element: named excellent and opposing ingredients, then tag-based poor and
# good matches (poor is checked first); everything else is neutral.
const INGREDIENT_AFFINITY:={
	"Water":{"excellent":["Dewmelon","Brinepod","Frostberry"],"good_tags":["juicy","fruit"],"poor_tags":["dry","spicy"],"opposing":["Emberpepper"]},
	"Green":{"excellent":["Bitterleaf","Honeybulb","Glowcap"],"good_tags":["plant","leaf","root","earthy","fungus"],"poor_tags":["salty","spicy"],"opposing":["Emberpepper"]},
	"Fire":{"excellent":["Emberpepper","Sparkfruit","Sunplum"],"good_tags":["spicy","dry","seed"],"poor_tags":["juicy","soft"],"opposing":["Frostberry","Dewmelon"]}
}

static func quiblet_relationship(a:Dictionary,b:Dictionary)->String:
	if int(a.species)==int(b.species):return "species"
	var species_a:=species(int(a.species));var species_b:=species(int(b.species))
	if str(species_a.get("family",""))==str(species_b.get("family","")):return "family"
	if str(species_a.element)==str(species_b.element):return "type"
	return "none"

static func ingredient_compatibility(species_index:int,ingredient_name:String)->String:
	if not INGREDIENTS.has(ingredient_name):return "neutral"
	var affinity:Dictionary=INGREDIENT_AFFINITY.get(str(species(species_index).element),{})
	if affinity.is_empty():return "neutral"
	if affinity.opposing.has(ingredient_name):return "opposing"
	if affinity.excellent.has(ingredient_name):return "excellent"
	var tags:Array=INGREDIENTS[ingredient_name].tags
	if tags.any(func(tag):return affinity.poor_tags.has(tag)):return "poor"
	if tags.any(func(tag):return affinity.good_tags.has(tag)):return "good"
	return "neutral"

static func preservation_category(compatibility:String)->String:
	if compatibility in ["excellent","good"]:return "match"
	return "neutral" if compatibility=="neutral" else "poor"

static func helper_preservation_chance(helper:Dictionary,foods:Array)->float:
	var chance:=0.0
	for food in foods:
		var food_name:=str(food)
		if food_name.is_empty() or not INGREDIENTS.has(food_name):continue
		var tier:=clampi(int(INGREDIENTS[food_name].get("tier",1)),1,4)
		chance+=float(PRESERVATION_CHANCE[tier][preservation_category(ingredient_compatibility(int(helper.species),food_name))])
	return clampf(chance,0.0,100.0)

static func total_exp(q:Dictionary)->int:
	var total:=int(q.exp)
	for level in range(1,int(q.level)):total+=exp_to_level(level)
	return total

static func move_training_chance(trainee:Dictionary,helpers:Array)->float:
	var chance:=MOVE_TRAINING_BASE_CHANCE
	for helper in helpers:
		if helper is Dictionary and not helper.is_empty():chance+=float(MOVE_TRAINING_HELPER_CHANCE[quiblet_relationship(trainee,helper)])
	return clampf(chance,0.0,MOVE_TRAINING_MAX_CHANCE)

static func exp_training_reward(trainee:Dictionary,helpers:Array)->int:
	var total:=0
	for helper in helpers:
		if helper is Dictionary and not helper.is_empty():total+=roundi(float(total_exp(helper))*EXP_TRAINING_SHARE*float(EXP_TRAINING_HELPER_MULTIPLIER[quiblet_relationship(trainee,helper)]))
	return total

static func retrain_pool(q:Dictionary)->Array:
	# Learnset moves not currently in any slot, so a success always changes the moveset.
	var known:Array=[]
	for move in q.moves:known.append(str(move.name))
	return learnset(int(q.species)).filter(func(move_name):return not known.has(move_name))

static func move_selection_weight(species_index:int,move_name:String)->float:
	var index:=learnset(species_index).find(move_name)
	return pow(MOVE_RARITY_DECAY,maxi(0,index))

static func pick_retrain_move(q:Dictionary,roll:float)->String:
	var pool:=retrain_pool(q)
	if pool.is_empty():return ""
	var total:=0.0
	for move_name in pool:total+=move_selection_weight(int(q.species),move_name)
	var remaining:=clampf(roll,0.0,.999999)*total
	for move_name in pool:
		remaining-=move_selection_weight(int(q.species),move_name)
		if remaining<0.0:return move_name
	return pool[-1]

static func ingredient_texture(info:Dictionary)->Texture2D:
	var texture_path:=str(info.get("texture",""))
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):return null
	var source:=load(texture_path) as Texture2D
	if source==null:return null
	var image:=source.get_image()
	if image==null:return source
	var visible_rect:=image.get_used_rect()
	if visible_rect.size.x<=0 or visible_rect.size.y<=0:return source
	var cropped:=AtlasTexture.new()
	cropped.atlas=source
	cropped.region=Rect2(visible_rect)
	return cropped

# Each spice biases which eligible Quiblet arrives and also seasons the arrival
# with a small permanent stat bonus. "stats" lists the bonus per stat at Great
# quality; it is scaled by spice strength (Basic ×0.35 … Special ×1.5) and uses
# the same stat keys as Power Stone bonuses, so battle code needs no changes.
const SPICES := {
	"Hot Flakes":{"icon":"♨","color":Color("#e75d3f"),"favors":"aggressive / high Attack","bias":"attack","stats":{"attack":.04}},
	"Iron Flakes":{"icon":"▰","color":Color("#7c8793"),"favors":"tough / high HP","bias":"hp","stats":{"max_hp":.04}},
	"Swift Spice":{"icon":"➤","color":Color("#4ebbc5"),"favors":"fast / mobile","bias":"swift","stats":{"speed":.05}},
	"Punch Pepper":{"icon":"✊","color":Color("#d77b34"),"favors":"melee / physical-move users","bias":"melee","stats":{"attack":.02,"resist":.02}},
	"Brain Salt":{"icon":"◉","color":Color("#a77bd4"),"favors":"psychic / unusual-move users","bias":"unusual","stats":{"cooldown":.03}},
	"Sharp Salt":{"icon":"➶","color":Color("#6aa6da"),"favors":"ranged / projectile users","bias":"ranged","stats":{"crit":.03}},
	"Gentle Herb":{"icon":"❧","color":Color("#68a96b"),"favors":"support / healing users","bias":"support","stats":{"healing":.05,"max_hp":.02}},
	"Rare Spice":{"icon":"✦","color":Color("#d6a83e"),"favors":"rarer members of the stew pool","bias":"rare","stats":{"max_hp":.015,"attack":.015}}
}

# Spice quality → strength multiplier for both the arrival bias and stat bonus.
static func spice_strength(quality:String)->float:
	return {"basic":0.35,"good":0.65,"great":1.0,"special":1.5}.get(quality,0.35)

# Stat bonuses one spice of the given quality seasons an arrival with.
static func spice_stat_bonuses(spice_name:String,quality:String)->Dictionary:
	var result:={}
	var stats:Dictionary=SPICES.get(spice_name,{}).get("stats",{})
	for stat in stats:result[stat]=float(stats[stat])*spice_strength(quality)
	return result

# Short text such as "+6% Attack, −3% cooldowns" describing spice_stat_bonuses.
static func spice_stat_text(spice_name:String,quality:String)->String:
	var parts:Array[String]=[]
	var bonuses:=spice_stat_bonuses(spice_name,quality)
	var names:={"max_hp":"max HP","attack":"Attack","speed":"movement speed","cooldown":"move cooldowns","crit":"crit chance","resist":"damage taken","healing":"healing received","knockback":"knockback","evasion":"evasion"}
	for stat in bonuses:
		var amount:=float(bonuses[stat])
		var negative:bool=str(stat) in ["cooldown","resist","knockback"]
		parts.append("%s%.1f%% %s"%["−" if negative else "+",amount*100.0,names.get(stat,stat)])
	return ", ".join(parts)

const SPICE_RECIPES := [
	{"name":"Hot Flakes","need":{"spicy":2}}, {"name":"Iron Flakes","need":{"hard":2}},
	{"name":"Swift Spice","need":{"juicy":2}}, {"name":"Punch Pepper","need":{"root":1,"hard":1}},
	{"name":"Brain Salt","need":{"bitter":2,"soft":1}}, {"name":"Sharp Salt","need":{"dry":2,"seed":1}},
	{"name":"Gentle Herb","need":{"soft":2}}, {"name":"Rare Spice","need":{"sweet":1,"sour":1,"salty":1}}
]

const SPICE_QUALITIES := ["basic","good","great","special"]

const RECIPES := [
	{"name":"Plain Stew","need":{},"priority":0,"desc":"A simple mixed stew with a broad general pool.","pool":[0,1,2,3,4,5,6,7],"attracts":"any Quiblet","color":Color("#b98c64")},
	{"name":"Rock Bottom Broth","need":{"earthy":2,"hard":2},"priority":10,"desc":"A dense mineral broth for Stone and rocky Quiblets.","pool":[3,4],"attracts":"sturdy Green-type Quiblets","color":Color("#777c86")},
	{"name":"Hot Stuff","need":{"spicy":2,"dry":2},"priority":10,"desc":"A fiery stew for heat-loving Quiblets.","pool":[6,7],"attracts":"Fire-type Quiblets","color":Color("#df6246")},
	{"name":"Deep Dish","need":{"salty":2,"juicy":3},"priority":10,"desc":"A briny, juicy dish for Water and aquatic Quiblets.","pool":[0,1],"attracts":"Water-type Quiblets","color":Color("#55abc7")},
	{"name":"Shock Stock","need":{"sour":2,"seed":2},"priority":10,"desc":"A crackling stock that draws Electric Quiblets.","pool":[6],"attracts":"sparky orange Quiblets","color":Color("#e1c53c")},
	{"name":"Food for Thought","need":{"bitter":2,"soft":2},"priority":10,"desc":"A curious dish favored by Psychic Quiblets.","pool":[5],"attracts":"thoughtful Green-type Quiblets","color":Color("#9a78c7")},
	{"name":"Garden Variety","need":{"leaf":2,"soft":2},"priority":10,"desc":"A green stew for Plant and leafy Quiblets.","pool":[2,3,4,5],"attracts":"Green-type Quiblets","color":Color("#69a45e")},
	{"name":"Midnight Snack","need":{"bitter":3,"fungus":2},"priority":20,"desc":"A dark, earthy meal for nocturnal and shadowy Quiblets.","pool":[4,7],"attracts":"dark, nocturnal Quiblets","color":Color("#625a83")},
	{"name":"Heavy Helping","need":{"hard":3,"savory":2},"priority":20,"desc":"A weighty meal for large, bulky, tanky Quiblets.","pool":[1,3,7],"attracts":"big, bulky Quiblets","color":Color("#8c735e")},
	{"name":"Light Bite","need":{"soft":3,"juicy":2},"priority":20,"desc":"A light dish for small, nimble Quiblets.","pool":[0,2,6],"attracts":"small, nimble Quiblets","color":Color("#76c7b0")},
	{"name":"Punch Drunk","need":{"spicy":2,"hard":2},"priority":25,"desc":"A forceful stew for melee and aggressive Quiblets.","pool":[4,6,7],"attracts":"aggressive melee Quiblets","color":Color("#cf7041")},
	{"name":"Long Shot","need":{"dry":3,"seed":2},"priority":25,"desc":"A crisp seed stew for ranged Quiblets.","pool":[0,1,2,3,6,7],"attracts":"long-range Quiblets","color":Color("#6e9bc5")},
	{"name":"Comfort Food","need":{"sweet":3,"soft":2},"priority":25,"desc":"A soothing meal for healing and support-oriented Quiblets.","pool":[5],"attracts":"healing, supportive Quiblets","color":Color("#d49b9f")},
	{"name":"Woodland Medley","need":{"fungus":2,"leaf":1,"earthy":1},"priority":15,"desc":"A forest medley enjoyed by woodland Quiblets across types.","pool":[2,3,4,5],"attracts":"woodland Green-type Quiblets","color":Color("#638b58")},
	{"name":"Peak Cuisine","need":{"root":3,"hard":3},"priority":15,"desc":"A sturdy dish for mountain, cave, and highland Quiblets.","pool":[1,3,7],"attracts":"mountain and cave Quiblets","color":Color("#7c818c")},
	{"name":"Coastal Catch","need":{"salty":2,"juicy":2},"priority":15,"desc":"A shore-inspired dish broader than a purely aquatic stew.","pool":[0,1,2,3],"attracts":"shoreline Quiblets","color":Color("#4fa7a6")},
	{"name":"Fancy Feast","need":{"sweet":2,"sour":2,"juicy":2},"priority":30,"desc":"An elaborate dish that attracts unusual and rare Quiblets.","pool":[1,5,7],"attracts":"rare and unusual Quiblets","color":Color("#c17fc4")},
	{"name":"Mystery Meat","need":{"spicy":1,"salty":1,"bitter":1,"savory":1},"priority":30,"desc":"A strange mixed dish with an unpredictable, weird pool.","pool":[0,1,2,3,4,5,6,7],"attracts":"unpredictable Quiblets","color":Color("#826177")}
]

static func species(index: int) -> Dictionary:
	return SPECIES[posmod(index, SPECIES.size())]

static func default_moves(species_index: int) -> Array:
	var result:Array=[]
	var available:Array=learnset(species_index)
	for i in mini(3,available.size()):result.append(available[i])
	return result

static func rolled_moves(species_index:int,count:=3,rng:RandomNumberGenerator=null)->Array:
	var available:Array=learnset(species_index)
	# Fisher-Yates with an optional RNG keeps tests reproducible while normal
	# acquisitions use the game's live random stream.
	for i in range(available.size()-1,0,-1):
		var swap_index:=rng.randi_range(0,i) if rng!=null else randi_range(0,i)
		var held=available[i];available[i]=available[swap_index];available[swap_index]=held
	return available.slice(0,mini(count,available.size()))

static func learnset(species_index: int) -> Array:
	return LEARNSETS[posmod(species_index, LEARNSETS.size())].duplicate()

static func make_quiblet(species_index: int, level: int, nickname: String = "",randomize_initial_moves:=false,rng:RandomNumberGenerator=null) -> Dictionary:
	var s := species(species_index)
	var uid:=str(Time.get_unix_time_from_system())+"-"+str(randi())
	var rolled_move_count:=(rng.randi_range(1,3) if rng!=null else randi_range(1,3)) if randomize_initial_moves else 3
	var initial_moves:=rolled_moves(species_index,rolled_move_count,rng) if randomize_initial_moves else default_moves(species_index)
	var board:=generate_power_board(uid)
	var move_list: Array = []
	for move_name in initial_moves:
		move_list.append({"name":move_name,"slots":1,"stones":[]})
	return {
		"uid":uid,
		"species":species_index, "nickname":nickname, "level":level, "exp":0,
		"hp_bonus":0, "atk_bonus":0, "moves":move_list, "memory":initial_moves.duplicate(),
		"health_charms":0, "attack_charms":0, "flex_health":0, "flex_attack":0,
		"prodigy":false, "power_stones":[],
		"power_slot_types":board.types,"power_slot_unlocks":board.unlocks,
		"power_slot_stones":[{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}]
	}

# Power Stone board. Every Quiblet rolls one fixed 4×4 board when it is created:
# each position is Attack, Health, or Flex (45/45/10, with at least one Attack
# and one Health), and each position has a unique unlock level drawn from these
# bands. Positions and unlock order are shuffled independently.
const POWER_BOARD_TYPE_WEIGHTS:={"Attack":.45,"Health":.45,"Flex":.10}
const POWER_BOARD_UNLOCK_BANDS:=[[1,1,1],[2,10,2],[11,25,3],[26,45,3],[46,65,3],[66,82,2],[83,94,1],[95,100,1]]

static func board_rng(individual_seed:="")->RandomNumberGenerator:
	var generator:=RandomNumberGenerator.new()
	if str(individual_seed).is_empty():generator.randomize()
	else:generator.seed=int(hash(str(individual_seed)))
	return generator

static func generate_power_board(individual_seed:="")->Dictionary:
	var generator:=board_rng(individual_seed)
	var types:Array[String]=[]
	for i in 16:
		var roll:=generator.randf()
		types.append("Attack" if roll<float(POWER_BOARD_TYPE_WEIGHTS.Attack) else ("Health" if roll<float(POWER_BOARD_TYPE_WEIGHTS.Attack)+float(POWER_BOARD_TYPE_WEIGHTS.Health) else "Flex"))
	var forced_attack:=-1
	if not types.has("Attack"):forced_attack=generator.randi_range(0,15);types[forced_attack]="Attack"
	if not types.has("Health"):
		var index:=generator.randi_range(0,15)
		while index==forced_attack:index=generator.randi_range(0,15)
		types[index]="Health"
	var levels:Array[int]=[]
	for band in POWER_BOARD_UNLOCK_BANDS:
		var pool:Array[int]=[]
		for level in range(int(band[0]),int(band[1])+1):pool.append(level)
		for i in int(band[2]):
			var pick:=generator.randi_range(0,pool.size()-1);levels.append(pool[pick]);pool.remove_at(pick)
	for i in range(levels.size()-1,0,-1):
		var j:=generator.randi_range(0,i);var swap:=levels[i];levels[i]=levels[j];levels[j]=swap
	return {"types":types,"unlocks":levels}

static func default_power_slot_types(_species_index:int,individual_seed:="")->Array[String]:
	return generate_power_board(individual_seed).types

static func power_slot_unlock_level(q:Dictionary,index:int)->int:
	var unlocks:Array=q.get("power_slot_unlocks",[])
	return int(unlocks[index]) if index>=0 and index<unlocks.size() else 1

static func power_slot_unlocked(q:Dictionary,index:int)->bool:
	return int(q.level)>=power_slot_unlock_level(q,index)

static func power_slot_accepts(q:Dictionary,index:int,stone_type:String)->bool:
	if not power_slot_unlocked(q,index):return false
	var slot_type:=str(q.power_slot_types[index]) if index>=0 and index<q.power_slot_types.size() else ""
	return slot_type=="Flex" or slot_type==stone_type

static func first_power_slot_accepting(q:Dictionary,stone_type:String,require_empty:=true)->int:
	for index in q.power_slot_types.size():
		if power_slot_accepts(q,index,stone_type) and (not require_empty or q.power_slot_stones[index].is_empty()):return index
	return -1

static func next_power_unlock(q:Dictionary)->Dictionary:
	# The lowest unlock level above the current level, with ring progress measured
	# from the highest unlock level already reached.
	var level:=int(q.level);var next_index:=-1;var next_level:=1<<30;var previous_level:=1
	for index in q.get("power_slot_unlocks",[]).size():
		var unlock:=power_slot_unlock_level(q,index)
		if unlock>level and unlock<next_level:next_level=unlock;next_index=index
		if unlock<=level:previous_level=maxi(previous_level,unlock)
	if next_index<0:return {"index":-1,"level":-1,"previous":previous_level,"progress":1.0}
	return {"index":next_index,"level":next_level,"previous":previous_level,"progress":clampf(float(level-previous_level)/float(next_level-previous_level),0.0,1.0)}

static func display_name(q: Dictionary) -> String:
	return q.nickname if not q.nickname.is_empty() else species(int(q.species)).name

static func max_hp(q: Dictionary) -> int:
	var s := species(int(q.species))
	var charm_scale := int(q.health_charms) + int(q.flex_health)
	var stone_power:=0
	for stone in q.get("power_slot_stones",[]):
		if stone is Dictionary and stone.get("type","")=="Health":stone_power+=int(stone.get("power",0))
	return int((int(s.base_hp) + int(q.level) * 15 + int(q.hp_bonus)+stone_power) * (1.0 + charm_scale * 0.065) * (1.0+float(quiblet_bonus_totals(q).get("max_hp",0.0))))

static func attack(q: Dictionary) -> int:
	var s := species(int(q.species))
	var charm_scale := int(q.attack_charms) + int(q.flex_attack)
	var stone_power:=0
	for stone in q.get("power_slot_stones",[]):
		if stone is Dictionary and stone.get("type","")=="Attack":stone_power+=int(stone.get("power",0))
	return int((int(s.base_atk) + int(q.level) * 3 + int(q.atk_bonus)+stone_power) * (1.0 + charm_scale * 0.06) * (1.0+float(quiblet_bonus_totals(q).get("attack",0.0))))

static func exp_to_level(level: int) -> int:
	return 80 + level * 24

static func tags_for_ingredients(items: Dictionary) -> Dictionary:
	var tags := {}
	for ingredient_name in items:
		if not INGREDIENTS.has(ingredient_name): continue
		for tag in INGREDIENTS[ingredient_name].tags:
			tags[tag] = int(tags.get(tag, 0)) + int(items[ingredient_name])
	return tags

static func choose_recipe(items: Dictionary) -> Dictionary:
	var tags := tags_for_ingredients(items)
	var best:Dictionary=RECIPES[0];var best_score:=-1
	for recipe in RECIPES:
		if recipe.need.is_empty(): continue
		var matches := true
		for tag in recipe.need:
			if int(tags.get(tag, 0)) < int(recipe.need[tag]): matches = false
		if matches:
			var specificity:=0
			for amount in recipe.need.values():specificity+=int(amount)
			var score:=specificity*100+int(recipe.get("priority",0))
			if score>best_score:best=recipe;best_score=score
	return best

static func choose_spice(items:Array[String])->Dictionary:
	var counts:={}
	for ingredient_name in items:
		for tag in INGREDIENTS[ingredient_name].tags:counts[tag]=int(counts.get(tag,0))+1
	var best:Dictionary={};var best_specificity:=-1
	for recipe in SPICE_RECIPES:
		var matches:=true
		for tag in recipe.need:
			if int(counts.get(tag,0))<int(recipe.need[tag]):matches=false
		if matches:
			var specificity:=0
			for amount in recipe.need.values():specificity+=int(amount)
			if specificity>best_specificity:best=recipe;best_specificity=specificity
	return best

static func spice_quality(items:Array[String])->String:
	if items.is_empty():return "basic"
	var total:=0.0
	for ingredient_name in items:total+=float(INGREDIENTS[ingredient_name].tier)
	var average:=total/items.size()
	return "special" if average>=3.25 else ("great" if average>=2.5 else ("good" if average>=1.75 else "basic"))

static func stone_effect(value: String) -> String:
	if value.begins_with("link:") or value.begins_with("link_from:"): return "link"
	return value

static func stone_info(value: String) -> Dictionary:
	var effect := stone_effect(value)
	for stone in MOVE_STONES:
		if stone.effect == effect: return stone
	return {}

static func has_stone(entry: Dictionary, effect: String) -> bool:
	for value in entry.stones:
		if stone_effect(value) == effect: return true
	return false
