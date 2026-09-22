class_name ExpeditionProp3D
extends Node3D

# A field prop standing on one tile of the open field: a cube-built tree,
# boulder, mushroom, crystal, pillar, cactus, mound, or block. It blocks
# movement (the expedition removes its cell from the walkable grid) and takes
# damage from any move that reaches it. Every kind, boulders included, is also
# harvestable: a team member standing beside it for HARVEST_SECONDS gathers a
# large bundle of the ingredients that prop grows. Either way, when it goes it
# bursts into a scatter of small cubes that fall, bounce, shrink, and vanish
# after a few seconds, and the tile opens up again.

signal destroyed(prop)

const SHARD_COUNT:=12
const HARVEST_SECONDS:=2.5
const HARVEST_RADIUS:=1.4
# Which ingredient tags each prop kind grows; every kind, boulders included, gives something.
const HARVEST_TAGS:={
	"flowering_shrub":["leaf", "fruit"],
	"seed_heads":["seed", "dry"],
	"mossy_boulder":["earthy", "hard"],
	"stump":["root", "dry"],
	"succulent":["juicy", "plant"],
	"weathered_stone":["hard", "earthy"],

	"tussock":["leaf", "seed"],
	"wildflowers":["leaf", "seed"],
	"fern":["leaf", "plant"],
	"heather":["leaf", "root"],
	"layered_rocks":["hard", "earthy"],
	"driftwood":["dry", "root"],
	"ice_cluster":["hard", "salty"],
	"mushroom_cluster":["fungus"],

	"grass":["leaf"],"flower":["seed","leaf"],"reeds":["leaf","root"],"tree":["fruit","leaf"],"bush":["leaf","fruit"],"big_mushroom":["fungus"],"mushroom":["fungus"],"cactus":["spicy","dry"],
	"crystal":["seed","hard"],"pillar":["earthy","hard"],"block":["earthy","hard"],"mound":["root","earthy"],"boulder":["earthy","hard"]
}
var harvest_progress:=0.0
var harvested:=false
const SHARD_GRAVITY:=14.0
const SHARD_HOLD_SECONDS:=1.4
const SHARD_SHRINK_SECONDS:=1.3

var kind:="tree"
var shape_variant:=0
var cell:Vector2i=Vector2i.ZERO
var max_hp:=100.0
var hp:=100.0
var shattered:=false
# Whether this prop yields ingredients when harvested (plain scenery does not), and
# whether it is a rare "rich" plant that gives a bigger, rarer bundle. Set by the
# expedition when the prop is placed.
var bears_fruit:=true
var rich:=false
var parts:Array[MeshInstance3D]=[]
var shards:Array[Dictionary]=[]
var colors:Array[Color]=[]
var hurt_time:=0.0
var occlusion_opacity:=1.0

static func prop_hp(prop_kind:String,stage_level:int)->float:
	var base:=40.0+float(stage_level)*9.0
	return base*(1.8 if prop_kind=="boulder" else (1.3 if prop_kind in ["pillar","block","crystal"] else 1.0))

func harvestable()->bool:
	return bears_fruit and HARVEST_TAGS.has(kind) and not shattered

func harvest_tags()->Array:
	return HARVEST_TAGS.get(kind,[])

func setup(prop_kind:String,prop_cell:Vector2i,biome:Dictionary,stage_level:int,rng:RandomNumberGenerator)->void:
	kind=prop_kind;cell=prop_cell;position=Vector3(cell.x,0,cell.y);max_hp=prop_hp(kind,stage_level);hp=max_hp
	rotation.y=rng.randf_range(0.0,TAU)
	shape_variant=rng.randi_range(0,2)
	match kind:
		"flowering_shrub":build_flowering_shrub(biome,rng)
		"seed_heads":build_seed_heads(biome,rng)
		"mossy_boulder":build_mossy_boulder(biome,rng)
		"stump":build_stump(biome,rng)
		"succulent":build_succulent(biome,rng)
		"weathered_stone":build_weathered_stone(biome,rng)
		"tussock":build_tussock(biome,rng)
		"wildflowers":build_wildflowers(biome,rng)
		"fern":build_fern(biome,rng)
		"heather":build_heather(biome,rng)
		"layered_rocks":build_layered_rocks(biome,rng)
		"driftwood":build_driftwood(biome,rng)
		"ice_cluster":build_ice_cluster(biome,rng)
		"mushroom_cluster":build_mushroom_cluster(biome,rng)
		"grass","flower","reeds":build_ground_plant(biome,rng)
		"boulder":build_boulder(biome,rng)
		"big_mushroom":build_big_mushroom(biome,rng)
		"mushroom":build_mushroom(biome,rng)
		"crystal":build_crystal(biome,rng)
		"pillar":build_pillar(biome,rng)
		"cactus":build_cactus(biome,rng)
		"mound":build_mound(biome,rng)
		"block":build_block(biome,rng)
		"bush":build_bush(biome,rng)
		_:build_tree(biome,rng)
	apply_shape_variation(biome,rng)
	set_process(false)

# Three silhouettes per kind, plus small seeded proportion differences. Apply
# transforms to the pieces, not the gameplay root: harvesting and blocked tiles
# keep their existing size, and the bases remain anchored to the ground.
func apply_shape_variation(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var accent:Color=biome.get("accent",Color("#6ea85a"))
	var stone:Color=biome.get("cliff",Color("#7b7f72"))
	if shape_variant>0:
		match kind:
			"cactus":
				var arm:=cylinder(Vector3(.27,.7,0),.12,.14,.5,accent);arm.rotation.z=PI*.5
				cylinder(Vector3(.5,.94,0),.12,.14,.48,accent);ball(Vector3(.5,1.18,0),Vector3.ONE*.12,accent)
				if shape_variant==2:
					var other:=cylinder(Vector3(-.25,.5,0),.11,.13,.46,accent);other.rotation.z=PI*.5
					cylinder(Vector3(-.46,.7,0),.11,.13,.4,accent)
			"mushroom","big_mushroom":
				var size:=.65 if kind=="big_mushroom" else .35
				for i in shape_variant:
					var offset:=Vector3(.4 if i==0 else -.35,0,.26 if i==0 else -.2)
					cylinder(offset+Vector3(0,size*.4,0),size*.15,size*.2,size*.8,Color("#f4ecd8"))
					ball(offset+Vector3(0,size*.85,0),Vector3(size*.6,size*.3,size*.55),prop_tone(accent,i+1))
			"pillar":
				if shape_variant==1:cube(Vector3(0,2.2,0),Vector3(.8,.22,.65),stone.lightened(.15))
				else:cube(Vector3(.32,.23,.12),Vector3(.5,.46,.48),stone)
			"block":cube(Vector3(.38,.2,.22),Vector3(.5,.4,.5),stone)
			"crystal":cube(Vector3(-.4,.35,.28),Vector3(.22,.7,.22),accent,Vector3(.15,0,-.3))
			"mound":ball(Vector3(.35,.18,.16),Vector3(.4,.22,.35),accent)
	var profiles:=[Vector3(1,1,1),Vector3(.85,1.16,.9),Vector3(1.06,.8,.91)]
	var proportions:Vector3=profiles[shape_variant]*Vector3(rng.randf_range(.96,1.04),rng.randf_range(.94,1.06),rng.randf_range(.96,1.04))
	proportions*=float(biome.get("prop_scale",1.0))
	for part in parts:
		part.position*=proportions;part.scale*=proportions

# Props in the soft-meadow style: smooth blobs and tapered cylinders in matte
# single colours, with a faint shadow disc that is not part of the breakable body.
const LEAF_GREENS:=["#5cb15c","#6fbf6a","#8ccf80","#9fd98f"]
func leaf_green(biome:Dictionary,index:int)->Color:
	return Color(LEAF_GREENS[index%LEAF_GREENS.size()]).lerp(biome.get("accent",Color("#6fbf6a")),.85 if biome.get("name","") in ["golden","forest","thicket"] else .3)

func plain_material(color:Color)->StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=1.0;mat.specular_mode=BaseMaterial3D.SPECULAR_DISABLED;return mat

# A slight per-piece shift on a base colour so a cluster reads with the same
# multi-tone shading the trees' leaves have.
func prop_tone(base:Color,index:int)->Color:
	var shifts:=[0.0,.12,-.10,.07,-.05]
	var f:float=shifts[index%shifts.size()]
	return base.lightened(f) if f>=0.0 else base.darkened(-f)

# A big mushroom in the trees' style: a tapered pale stem under a rounded cap
# built from a cluster of blobs in a few tones of the cap colour, over a shadow.
func build_big_mushroom(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var cap:Color=biome.get("accent",Color("#8bd06a"));var height:=rng.randf_range(1.3,1.8)
	cylinder(Vector3(0,height*.5,0),.18,.26,height,Color("#f4ecd8"))
	var y:=height+.02
	var blobs:Array=[[0,y+.16,0,.82,.44],[-.46,y+.02,.05,.5,.32],[.46,y+.02,-.05,.5,.32],[.05,y+.02,.44,.46,.30],[-.05,y+.02,-.44,.46,.30]]
	for i in blobs.size():
		var b:Array=blobs[i];ball(Vector3(b[0],b[1],b[2]),Vector3(float(b[3]),float(b[4]),float(b[3])),prop_tone(cap,i))
	shadow(.82)

# The small mushroom is the same clustered cap at a smaller scale.
func build_mushroom(biome:Dictionary,_rng:RandomNumberGenerator)->void:
	var cap:Color=biome.get("accent",Color("#8bd06a"))
	cylinder(Vector3(0,.3,0),.1,.13,.6,Color("#f4ecd8"))
	var y:=.64
	var blobs:Array=[[0,y+.09,0,.42,.24],[-.25,y,.03,.27,.18],[.25,y,-.03,.27,.18],[.03,y,.23,.23,.16]]
	for i in blobs.size():
		var b:Array=blobs[i];ball(Vector3(b[0],b[1],b[2]),Vector3(float(b[3]),float(b[4]),float(b[3])),prop_tone(cap,i))
	shadow(.42)

# A crystal in the trees' style: a cluster of angular shards of a few tones rising
# from the ground, matte with a soft inner glow, over a shadow.
func build_crystal(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var shine:Color=biome.get("accent",Color("#7fe0ff"))
	var shards:Array=[[0,.85,0,.42,1.7,.14,0.0],[.30,.62,.10,.26,1.15,.35,.5],[-.28,.55,-.12,.24,1.0,-.3,-.4],[.06,.42,.30,.20,.8,.5,.9]]
	for i in shards.size():
		var sh:Array=shards[i]
		var crystal:=cube(Vector3(sh[0],sh[1],sh[2]),Vector3(float(sh[3]),float(sh[4]),float(sh[3])),prop_tone(shine,i),Vector3(float(sh[5]),float(sh[6])*TAU,float(sh[5])*.6))
		crystal.material_override.emission_enabled=true;crystal.material_override.emission=shine;crystal.material_override.emission_energy_multiplier=.45
	shadow(.6)

func build_pillar(biome:Dictionary,_rng:RandomNumberGenerator)->void:
	cylinder(Vector3(0,1.1,0),.3,.36,2.2,biome.get("cliff",Color("#7b7f72")).lightened(.1))

func build_cactus(biome:Dictionary,_rng:RandomNumberGenerator)->void:
	var green:Color=biome.get("accent",Color("#6ea85a"))
	cylinder(Vector3(0,.7,0),.2,.22,1.4,green);ball(Vector3(0,1.4,0),Vector3(.2,.2,.2),green)

func build_mound(biome:Dictionary,_rng:RandomNumberGenerator)->void:
	ball(Vector3(0,.3,0),Vector3(.65,.35,.6),biome.get("accent",Color("#ffffff")))

func build_block(biome:Dictionary,rng:RandomNumberGenerator)->void:
	cube(Vector3(0,.55,0),Vector3(1.1,1.1,1.1),biome.get("cliff",Color("#7b7f72")).lightened(.12),Vector3(0,rng.randf_range(-.4,.4),0))

# A rounded box in one matte colour.
func cube(offset:Vector3,size:Vector3,color:Color,tilt:=Vector3.ZERO)->MeshInstance3D:
	var part:=MeshInstance3D.new();part.mesh=GameData.rounded_box(size,minf(size.x,minf(size.y,size.z))*.2);part.position=offset;part.rotation=tilt
	part.material_override=plain_material(color);add_child(part);parts.append(part);colors.append(color);return part

func cylinder(offset:Vector3,top_radius:float,bottom_radius:float,height:float,color:Color)->MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=top_radius;mesh.bottom_radius=bottom_radius;mesh.height=height;mesh.radial_segments=12
	var part:=MeshInstance3D.new();part.mesh=mesh;part.position=offset;part.material_override=plain_material(color);add_child(part);parts.append(part);colors.append(color);return part

# A smooth blob; `radii` are its half extents.
func ball(offset:Vector3,radii:Vector3,color:Color)->MeshInstance3D:
	var part:=MeshInstance3D.new();part.mesh=GameData.leaf_sphere();part.position=offset;part.scale=radii*2.0
	part.material_override=plain_material(color);add_child(part);parts.append(part);colors.append(color);return part

func shadow(radius:float)->void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=.02;mesh.radial_segments=20
	var disc:=MeshInstance3D.new();disc.mesh=mesh;disc.position=Vector3(0,.06,0)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.2,.31,.16,.16);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;disc.material_override=mat;add_child(disc)

# A tree is a tapered trunk under five round leaf blobs in four greens, over a shadow disc.
func build_tree(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var s:float=rng.randf_range(.28,.38)
	trunk(biome,6.0*s,1.05*s)
	var blobs:Array=[[0,8.6,0,4.6],[-3.4,7,.6,3],[3.4,7,-.6,3],[0,11,.4,2.8],[1.6,8.4,2.6,2.4]]
	if shape_variant==1:blobs=[[0,7,0,3.7],[-1.8,9,.3,3.0],[.6,11,-.3,2.8],[.3,13,0,1.9]]
	elif shape_variant==2:blobs=[[-2.4,7,0,3.9],[2.6,7.8,.4,3.6],[0,9,-1,3.4],[1.2,7,2.6,2.8]]
	for i in blobs.size():
		var blob:Array=blobs[i];ball(Vector3(blob[0],blob[1],blob[2])*s,Vector3.ONE*float(blob[3])*s,leaf_green(biome,i))
	shadow(5.2*s)

func trunk(_biome:Dictionary,height:float,width:float)->void:
	cylinder(Vector3(0,height*.5,0),width*.75,width,height,Color("#a96f42"))

# A bush is three leaf blobs.
func build_bush(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var s:float=rng.randf_range(.95,1.2)
	# A full, rounded dome of overlapping leaves rather than three stray balls.
	var blobs:Array=[[0,.40,0,.50],[.34,.32,.05,.37],[-.34,.32,-.05,.37],[.05,.32,.34,.35],[-.05,.32,-.34,.35],[.12,.60,.06,.35],[-.12,.55,-.08,.31]]
	if shape_variant==1:blobs=[[0,.4,0,.45],[.12,.7,0,.36],[-.25,.31,.05,.32],[.25,.32,-.05,.3]]
	elif shape_variant==2:blobs=[[-.34,.3,0,.38],[0,.38,.04,.45],[.38,.28,-.06,.34],[-.12,.27,.3,.31],[.18,.25,-.3,.3]]
	for i in blobs.size():
		var blob:Array=blobs[i];ball(Vector3(blob[0],blob[1],blob[2])*s,Vector3.ONE*float(blob[3])*s,leaf_green(biome,i%3))
	shadow(.85*s)

# A boulder is a cluster of three squashed grey blobs over a shadow disc.
func build_boulder(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var grey:Color=Color(biome.rock) if biome.has("rock") else Color("#b9c3cb")
	var light:Color=grey.lightened(.14);var dark:Color=grey.darkened(.1);var s:float=rng.randf_range(.7,1.05)
	# One cohesive rounded rock: overlapping squashed lumps, lighter on top, darker low.
	var lumps:Array=[[0,.40,0,.72,.50,.64,dark],[.36,.54,.12,.50,.42,.46,grey],[-.32,.50,-.16,.46,.40,.44,grey],[.06,.74,.04,.42,.36,.40,light],[-.10,.36,.34,.40,.32,.38,grey]]
	for lump in lumps:
		ball(Vector3(lump[0],lump[1],lump[2])*s,Vector3(lump[3],lump[4],lump[5])*s,lump[6])
	shadow(1.05*s)

func harvest()->void:
	if shattered:return
	harvested=true;shatter()

# Material alpha works with the Mobile renderer as well as Forward+.
func set_occlusion_opacity(value:float)->void:
	occlusion_opacity=clampf(value,0.0,1.0)
	for part in parts:
		var material:=part.material_override as StandardMaterial3D
		if material==null:continue
		part.transparency=0.0
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if occlusion_opacity<.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
		var color:=material.albedo_color;color.a=occlusion_opacity;material.albedo_color=color

func hit(amount:float)->bool:
	if shattered or amount<=0.0:return false
	hp=maxf(0.0,hp-amount);hurt_time=.15
	for i in parts.size():parts[i].material_override.albedo_color=colors[i].lightened(.45)
	set_occlusion_opacity(occlusion_opacity)
	set_process(true)
	if hp<=0.0:shatter()
	return true

func shatter()->void:
	if shattered:return
	shattered=true
	for part in parts:part.visible=false
	var rng:=RandomNumberGenerator.new();rng.randomize()
	for i in SHARD_COUNT:
		var size:=rng.randf_range(.18,.34);var color:Color=colors[rng.randi_range(0,colors.size()-1)]
		var mesh:=BoxMesh.new();mesh.size=Vector3.ONE*size;var shard:=MeshInstance3D.new();shard.mesh=mesh
		var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.85;shard.material_override=mat
		shard.position=Vector3(rng.randf_range(-.35,.35),rng.randf_range(.4,1.8),rng.randf_range(-.35,.35));shard.rotation=Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)
		add_child(shard)
		var angle:=rng.randf()*TAU;var speed:=rng.randf_range(1.5,3.6)
		shards.append({"node":shard,"velocity":Vector3(cos(angle)*speed,rng.randf_range(3.0,6.5),sin(angle)*speed),"spin":Vector3(rng.randf_range(-6,6),rng.randf_range(-6,6),rng.randf_range(-6,6)),"size":size,"age":0.0})
	set_process(true)
	destroyed.emit(self)

func _process(delta:float)->void:
	if not shattered and harvest_progress>0.0:
		rotation.z=sin(harvest_progress*22.0)*.06*minf(1.0,harvest_progress*2.0);set_process(true)
	elif not shattered:rotation.z=0.0
	if hurt_time>0.0:
		hurt_time-=delta
		if hurt_time<=0.0:
			for i in parts.size():parts[i].material_override.albedo_color=colors[i]
			set_occlusion_opacity(occlusion_opacity)
	if not shattered:
		if hurt_time<=0.0 and harvest_progress<=0.0:set_process(false)
		return
	for shard in shards.duplicate():
		var node:MeshInstance3D=shard.node;var velocity:Vector3=shard.velocity
		velocity.y-=SHARD_GRAVITY*delta;var next:Vector3=node.position+velocity*delta
		var floor_y:float=float(shard.size)*.5*node.scale.y
		if next.y<=floor_y:
			next.y=floor_y;velocity.y=-velocity.y*.35;velocity.x*=.7;velocity.z*=.7
			if absf(velocity.y)<.4:velocity.y=0.0
		node.position=next;shard.velocity=velocity;node.rotation+=Vector3(shard.spin)*delta*(1.0 if velocity.length()>.5 else 0.0)
		shard.age=float(shard.age)+delta
		if float(shard.age)>SHARD_HOLD_SECONDS:
			var remaining:=1.0-clampf((float(shard.age)-SHARD_HOLD_SECONDS)/SHARD_SHRINK_SECONDS,0.0,1.0)
			node.scale=Vector3.ONE*maxf(remaining,.001)
			if remaining<=0.0:node.queue_free();shards.erase(shard)
	if shards.is_empty():queue_free()

func build_ground_plant(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var green:Color=biome.get("accent",Color("#7aaf61"))
	for i in range(4+shape_variant):
		var offset:=Vector3(rng.randf_range(-.4,.4),0,rng.randf_range(-.4,.4));var h:=rng.randf_range(.4,.85) if kind!="reeds" else rng.randf_range(.9,1.5)
		var stem:=cylinder(offset+Vector3(0,h*.5,0),.025,.045,h,green);stem.rotation.z=rng.randf_range(-.18,.18)
		if kind=="flower":
			var color:=Color("#f4d17a") if i%2==0 else Color("#db92b4")
			ball(offset+Vector3(0,h,0),Vector3(.15,.08,.15),color)
		elif kind=="reeds":ball(offset+Vector3(0,h,0),Vector3(.07,.19,.07),Color("#967453"))

func build_tussock(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var green:Color=biome.accent
	for i in 9:
		var angle:=TAU*i/9.0;var h:=rng.randf_range(.65,1.35)
		var blade:=cube(Vector3(sin(angle)*.25,h*.48,cos(angle)*.25),Vector3(.14,h,.12),prop_tone(green,i%3))
		blade.rotation=Vector3(cos(angle)*.35,angle,-sin(angle)*.35)
		if i%3==0:ball(Vector3(sin(angle)*.45,h,cos(angle)*.45),Vector3(.1,.17,.1),Color(biome.path).lightened(.15))
	shadow(.7)

func build_wildflowers(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var petals:=[Color("#f7df83"),Color("#e5a4c5"),Color("#f0f1d8")]
	for i in 3+shape_variant:
		var angle:=i*2.4;var point:=Vector3(sin(angle)*.42,0,cos(angle)*.42);var h:=rng.randf_range(.65,1.15)
		cylinder(point+Vector3.UP*h*.5,.035,.055,h,biome.accent)
		var head:=point+Vector3.UP*h
		for j in 4:
			var a:=j*TAU/4.0;ball(head+Vector3(sin(a)*.14,0,cos(a)*.14),Vector3(.16,.09,.16),petals[(i+shape_variant)%3])
		ball(head+Vector3.UP*.055,Vector3(.09,.06,.09),Color("#bf8542"))
	shadow(.75)

func build_fern(biome:Dictionary,_rng:RandomNumberGenerator)->void:
	for i in 7:
		var angle:=TAU*i/7.0;var length:=.65+float(i%3)*.12
		for j in 2:
			var distance:=.25+j*.28
			var leaf:=ball(Vector3(sin(angle)*distance,.6-j*.17,cos(angle)*distance),Vector3(.2,.09,length*.5),prop_tone(Color(biome.accent),i%3))
			leaf.rotation=Vector3(.22,angle,0)
	cylinder(Vector3(0,.35,0),.1,.18,.7,Color(biome.accent).darkened(.15))
	shadow(.85)

func build_heather(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var dry:bool=str(biome.name)=="desert"
	for i in 5+shape_variant:
		var angle:=i*2.4;var point:=Vector3(sin(angle)*.4,.3,cos(angle)*.4)
		ball(point,Vector3(.35,.32,.35),prop_tone(Color(biome.accent),i%3))
		if not dry:ball(point+Vector3(0,rng.randf_range(.28,.5),0),Vector3(.14,.26,.14),Color("#ad83b7") if i%2==0 else Color("#d8aac7"))
	shadow(.9)

func build_layered_rocks(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var color:Color=Color(biome.cliff).lightened(.18)
	var height:=0.0
	for i in 3+shape_variant:
		var thickness:=rng.randf_range(.24,.4);var width:=1.4-i*.17
		cube(Vector3(sin(i*1.8)*.13,height+thickness*.5,cos(i*1.4)*.09),Vector3(width,thickness,width*.85),prop_tone(color,i%3),Vector3(0,rng.randf_range(-.25,.25),.035))
		height+=thickness*.95
	for side in [-1,1]:ball(Vector3(side*.55,.15,.4),Vector3(.28,.18,.24),color.darkened(.1))
	shadow(.95)

func build_driftwood(biome:Dictionary,_rng:RandomNumberGenerator)->void:
	var bark:=Color(biome.path).darkened(.24);var cut:=Color(biome.path).lightened(.12)
	var log:=cylinder(Vector3(0,.3,0),.22,.29,1.65,bark);log.rotation.z=PI*.5
	for side in [-1,1]:
		var end:=cylinder(Vector3(side*.83,.3,0),.2,.2,.03,cut);end.rotation.z=PI*.5
		var branch:=cylinder(Vector3(side*.3,.52,-.12),.06,.12,.65,bark);branch.rotation=Vector3(-.4,0,side*.65)
	shadow(.95)

func build_ice_cluster(biome:Dictionary,rng:RandomNumberGenerator)->void:
	for i in 4:
		var h:=rng.randf_range(.7,1.65);var point:=Vector3(sin(i*2.4)*.35,h*.5,cos(i*2.4)*.35)
		cube(point,Vector3(.3,h,.35),Color(biome.accent).lerp(Color("#8bc6df"),i*.15),Vector3(.12, i*.7, (i-1.5)*.12))
		ball(Vector3(point.x,.12,point.z),Vector3(.38,.16,.35),Color(biome.ground).lightened(.08))
	shadow(.8)

func build_mushroom_cluster(biome:Dictionary,rng:RandomNumberGenerator)->void:
	for i in 4+shape_variant:
		var h:=rng.randf_range(.4,1.05);var point:=Vector3(sin(i*2.4)*.4,0,cos(i*2.4)*.4)
		cylinder(point+Vector3.UP*h*.5,.08,.12,h,Color("#e0d8bc"))
		ball(point+Vector3.UP*h,Vector3(.3,.16,.3),Color(biome.accent).lerp(Color("#b792c8"),float(i%3)*.25))
		ball(point+Vector3.UP*(h+.14),Vector3(.07,.025,.07),Color("#fff0cb"))
	shadow(.85)

func build_flowering_shrub(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var green:Color=Color(biome.accent).lerp(Color("#75a759"),.4)
	for i in 5:
		var angle:=i*2.4;var point:=Vector3(sin(angle)*.4,.45+rng.randf_range(0,.2),cos(angle)*.4)
		ball(point,Vector3(.4,.42,.4),prop_tone(green,i%3))
		for j in 2:
			var bloom:=point+Vector3((j-.5)*.3,.3,.22)
			ball(bloom,Vector3(.14,.09,.14),Color("#f5cce0") if shape_variant%2==0 else Color("#f5dc86"))
			ball(bloom+Vector3.UP*.07,Vector3(.045,.03,.045),Color("#ca974d"))
	shadow(.95)

func build_seed_heads(biome:Dictionary,rng:RandomNumberGenerator)->void:
	for i in 6+shape_variant:
		var angle:=i*2.4;var point:=Vector3(sin(angle)*.38,0,cos(angle)*.38);var h:=rng.randf_range(.8,1.6)
		var stem:=cylinder(point+Vector3.UP*h*.5,.025,.045,h,Color(biome.accent));stem.rotation.z=.1
		for j in 3:
			ball(point+Vector3(.1,h+j*.12,0),Vector3(.09-j*.015,.12,.07),Color(biome.path).lightened(.15))
	shadow(.75)

func build_mossy_boulder(biome:Dictionary,rng:RandomNumberGenerator)->void:
	build_boulder(biome,rng)
	var moss:Color=Color(biome.accent).lerp(Color("#78aa57"),.45)
	for i in 4:
		var angle:=i*2.4
		ball(Vector3(sin(angle)*.3,.74+float(i%2)*.04,cos(angle)*.3),Vector3(.28,.1,.28),prop_tone(moss,i%3))

func build_stump(biome:Dictionary,_rng:RandomNumberGenerator)->void:
	var bark:=Color(biome.cliff).lerp(Color("#94623f"),.6);var top:=Color("#d8b47e")
	cylinder(Vector3(0,.38,0),.38,.48,.76,bark)
	cylinder(Vector3(0,.775,0),.34,.34,.025,top)
	cylinder(Vector3(0,.792,0),.22,.22,.012,bark.lightened(.3))
	cylinder(Vector3(0,.8,0),.16,.16,.014,top)
	for i in 5:
		var angle:=TAU*i/5.0
		cube(Vector3(sin(angle)*.4,.13,cos(angle)*.4),Vector3(.21,.23,.68),bark,Vector3(0,angle,.05))
	if shape_variant==2:ball(Vector3(.3,.81,.1),Vector3(.25,.11,.25),Color(biome.accent))
	shadow(.85)

func build_succulent(biome:Dictionary,_rng:RandomNumberGenerator)->void:
	var green:Color=Color(biome.accent).lerp(Color("#7ea58c"),.5)
	for tier in 2:
		for i in 6:
			var angle:=i*TAU/6.0+tier*.4;var spread:=.35-tier*.16
			var leaf:=ball(Vector3(sin(angle)*spread,.22+tier*.24,cos(angle)*spread),Vector3(.17,.12,.42-tier*.13),prop_tone(green,i%3))
			leaf.rotation=Vector3(.25+tier*.4,angle,0)
	if shape_variant==1:
		cylinder(Vector3(0,.68,0),.025,.04,.55,green)
		ball(Vector3(0,.98,0),Vector3(.15,.12,.15),Color("#efb277"))
	shadow(.75)

func build_weathered_stone(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var stone:Color=Color(biome.cliff).lightened(.15)
	var h:=rng.randf_range(1.1,1.8)
	cube(Vector3(0,h*.5,0),Vector3(.65,h,.58),stone,Vector3(.1,0,.12))
	cube(Vector3(.08,h*.8,0),Vector3(.72,.18,.65),stone.lightened(.13),Vector3(.1,.1,.12))
	for i in 4:
		var angle:=i*2.4
		ball(Vector3(sin(angle)*.5,.12,cos(angle)*.5),Vector3(.23,.16,.2),prop_tone(stone,i%3))
	shadow(.85)
