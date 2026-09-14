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
	"tree":["fruit","leaf"],"bush":["leaf","fruit"],"big_mushroom":["fungus"],"mushroom":["fungus"],"cactus":["spicy","dry"],
	"crystal":["seed","hard"],"pillar":["earthy","hard"],"block":["earthy","hard"],"mound":["root","earthy"],"boulder":["earthy","hard"]
}
var harvest_progress:=0.0
var harvested:=false
const SHARD_GRAVITY:=14.0
const SHARD_HOLD_SECONDS:=1.4
const SHARD_SHRINK_SECONDS:=1.3

var kind:="tree"
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

static func prop_hp(prop_kind:String,stage_level:int)->float:
	var base:=40.0+float(stage_level)*9.0
	return base*(1.8 if prop_kind=="boulder" else (1.3 if prop_kind in ["pillar","block","crystal"] else 1.0))

func harvestable()->bool:
	return bears_fruit and HARVEST_TAGS.has(kind) and not shattered

func harvest_tags()->Array:
	return HARVEST_TAGS.get(kind,[])

func setup(prop_kind:String,prop_cell:Vector2i,biome:Dictionary,stage_level:int,rng:RandomNumberGenerator)->void:
	kind=prop_kind;cell=prop_cell;position=Vector3(cell.x,0,cell.y);max_hp=prop_hp(kind,stage_level);hp=max_hp
	rotation.y=rng.randf_range(-.5,.5)
	match kind:
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
	set_process(false)

# Props in the soft-meadow style: smooth blobs and tapered cylinders in matte
# single colours, with a faint shadow disc that is not part of the breakable body.
const LEAF_GREENS:=["#5cb15c","#6fbf6a","#8ccf80","#9fd98f"]
func leaf_green(biome:Dictionary,index:int)->Color:
	return Color(LEAF_GREENS[index%LEAF_GREENS.size()]).lerp(biome.get("accent",Color("#6fbf6a")),.3)

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

func hit(amount:float)->bool:
	if shattered or amount<=0.0:return false
	hp=maxf(0.0,hp-amount);hurt_time=.15
	for i in parts.size():parts[i].material_override.albedo_color=colors[i].lightened(.45)
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
