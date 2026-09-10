class_name ExpeditionProp3D
extends Node3D

# A field prop standing on one tile of the open field: a cube-built tree,
# boulder, mushroom, crystal, pillar, cactus, mound, or block. It blocks
# movement (the expedition removes its cell from the walkable grid) and takes
# damage from any move that reaches it. Every kind except the boulder is also
# harvestable: a team member standing beside it for HARVEST_SECONDS gathers a
# large bundle of the ingredients that prop grows. Either way, when it goes it
# bursts into a scatter of small cubes that fall, bounce, shrink, and vanish
# after a few seconds, and the tile opens up again.

signal destroyed(prop)

const SHARD_COUNT:=12
const HARVEST_SECONDS:=2.5
const HARVEST_RADIUS:=1.4
# Which ingredient tags each prop kind grows; boulders grow nothing.
const HARVEST_TAGS:={
	"tree":["fruit","leaf"],"bush":["leaf","fruit"],"big_mushroom":["fungus"],"mushroom":["fungus"],"cactus":["spicy","dry"],
	"crystal":["seed","hard"],"pillar":["earthy","hard"],"block":["earthy","hard"],"mound":["root","earthy"]
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
var parts:Array[MeshInstance3D]=[]
var shards:Array[Dictionary]=[]
var colors:Array[Color]=[]
var hurt_time:=0.0

static func prop_hp(prop_kind:String,stage_level:int)->float:
	var base:=40.0+float(stage_level)*9.0
	return base*(1.8 if prop_kind=="boulder" else (1.3 if prop_kind in ["pillar","block","crystal"] else 1.0))

func harvestable()->bool:
	return HARVEST_TAGS.has(kind) and not shattered

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

func build_big_mushroom(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var cap:Color=biome.get("accent",Color("#8bd06a"));var height:=rng.randf_range(1.3,1.9)
	cube(Vector3(0,height*.5,0),Vector3(.4,height,.4),Color("#f4ecd8"))
	cube(Vector3(0,height+.25,0),Vector3(1.5,.5,1.5),cap);cube(Vector3(0,height+.6,0),Vector3(.9,.3,.9),cap.lightened(.1));cube(Vector3(.45,height+.5,.35),Vector3(.25,.12,.25),Color("#f4ecd8"))

func build_mushroom(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var cap:Color=biome.get("accent",Color("#8bd06a"))
	cube(Vector3(-.2,.3,0),Vector3(.24,.6,.24),Color("#f4ecd8"));cube(Vector3(-.2,.72,0),Vector3(.7,.3,.7),cap)
	cube(Vector3(.3,.2,.2),Vector3(.18,.4,.18),Color("#f4ecd8"));cube(Vector3(.3,.5,.2),Vector3(.45,.22,.45),cap.lightened(.1))

func build_crystal(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var shine:Color=biome.get("accent",Color("#7fe0ff"))
	var main:=cube(Vector3(0,.8,0),Vector3(.4,1.7,.4),shine,Vector3(.15,rng.randf()*TAU,.1));main.material_override.emission_enabled=true;main.material_override.emission=shine;main.material_override.emission_energy_multiplier=.5
	cube(Vector3(.35,.45,.2),Vector3(.28,.9,.28),shine.lightened(.15),Vector3(.3,rng.randf()*TAU,-.25));cube(Vector3(-.3,.3,-.2),Vector3(.22,.6,.22),shine.darkened(.1),Vector3(-.25,0,.3))

func build_pillar(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var stone:Color=biome.get("cliff",Color("#7b7f72")).lightened(.1)
	cube(Vector3(0,.15,0),Vector3(1.0,.3,1.0),stone.darkened(.08));cube(Vector3(0,1.15,0),Vector3(.62,1.7,.62),stone);cube(Vector3(0,2.1,0),Vector3(.9,.24,.9),stone.lightened(.08))

func build_cactus(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var green:Color=biome.get("accent",Color("#6ea85a"))
	cube(Vector3(0,.7,0),Vector3(.42,1.4,.42),green);cube(Vector3(.4,.75,0),Vector3(.3,.3,.3),green);cube(Vector3(.4,1.05,0),Vector3(.3,.5,.3),green.lightened(.06));cube(Vector3(-.38,.55,0),Vector3(.28,.28,.28),green);cube(Vector3(-.38,.85,0),Vector3(.28,.45,.28),green.lightened(.06))

func build_mound(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var snow:Color=biome.get("accent",Color("#ffffff"))
	cube(Vector3(0,.25,0),Vector3(1.2,.5,1.1),snow.darkened(.05));cube(Vector3(.1,.6,-.05),Vector3(.8,.3,.75),snow);cube(Vector3(-.25,.82,.1),Vector3(.4,.2,.4),snow.lightened(.04))

func build_block(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var stone:Color=biome.get("cliff",Color("#7b7f72")).lightened(.12)
	var block:=cube(Vector3(0,.55,0),Vector3(1.1,1.1,1.1),stone,Vector3(0,rng.randf_range(-.4,.4),0));cube(Vector3(.2,1.3,.1),Vector3(.5,.4,.5),stone.lightened(.08),Vector3(0,rng.randf_range(-.6,.6),0))

func cube(offset:Vector3,size:Vector3,color:Color,tilt:=Vector3.ZERO,detail:="specks")->MeshInstance3D:
	# Rounded edges so props read as soft plastic blocks rather than sharp voxels.
	var mesh:=GameData.rounded_box(size,minf(size.x,minf(size.y,size.z))*.2);var part:=MeshInstance3D.new();part.mesh=mesh;part.position=offset;part.rotation=tilt
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.88
	if detail=="specks":GameData.apply_prop_specks(mat)
	else:GameData.apply_detail(mat,detail)
	part.material_override=mat;add_child(part);parts.append(part);colors.append(color);return part

# A leaf ball: one sphere part in the cluster that makes up a canopy or shrub.
func ball(offset:Vector3,radius:float,color:Color)->MeshInstance3D:
	var part:=MeshInstance3D.new();part.mesh=GameData.leaf_sphere();part.position=offset;part.scale=Vector3.ONE*radius*2.0
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.9;part.material_override=mat;add_child(part);parts.append(part);colors.append(color);return part

func leaf_cluster(center:Vector3,extent:Vector3,count:int,radius:float,leaf:Color,rng:RandomNumberGenerator)->void:
	for entry in GameData.leaf_cluster(center,extent,count,radius,leaf,rng):ball(entry.pos,float(entry.radius),entry.color)

# A tree: a square trunk under a canopy made of lots of overlapping leaf spheres.
# Two silhouettes: a tall column tree with a slim trunk and a tall dark canopy,
# or a big round tree with a wide bright canopy and a small tuft on top.
func build_tree(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var leaf:Color=biome.get("accent",Color("#3f7650")).lightened(rng.randf_range(-.06,.1))
	if rng.randf()<.5:
		var height:=rng.randf_range(1.6,2.6);var width:=rng.randf_range(.8,1.15);var trunk_height:=rng.randf_range(.6,1.1)
		trunk(biome,trunk_height,.3)
		leaf_cluster(Vector3(0,trunk_height-.05+height*.5,0),Vector3(width*.5,height*.5,width*.5),9,width*.42,leaf.darkened(.1),rng)
		leaf_cluster(Vector3(0,trunk_height+height+.05,0),Vector3(width*.3,.2,width*.3),3,width*.28,leaf.darkened(.02),rng)
	else:
		var width:=rng.randf_range(1.4,2.0);var height:=rng.randf_range(1.2,1.7);var trunk_height:=rng.randf_range(.8,1.2)
		trunk(biome,trunk_height,.36)
		leaf_cluster(Vector3(0,trunk_height-.05+height*.5,0),Vector3(width*.5,height*.5,width*.5*rng.randf_range(.85,1.0)),13,width*.3,leaf.lightened(.1),rng)
		leaf_cluster(Vector3(rng.randf_range(-.25,.25),trunk_height+height+.15,rng.randf_range(-.2,.2)),Vector3(width*.25,.2,width*.25),4,width*.2,leaf.lightened(.18),rng)

func trunk(biome:Dictionary,height:float,width:float)->void:
	if str(biome.get("trunk",""))=="birch":
		var bands:int=maxi(2,roundi(height/.3))
		for i in bands:cube(Vector3(0,(float(i)+.5)*height/float(bands),0),Vector3(width,height/float(bands),width),Color("#e9e6dc") if i%2==0 else Color("#7f9a6a"),Vector3.ZERO,"trunk")
	else:cube(Vector3(0,height*.5,0),Vector3(width,height,width),Color("#8a5b36"),Vector3.ZERO,"trunk")

# A shrub: a low mound of leaf spheres with a few lighter ones on top.
func build_bush(biome:Dictionary,rng:RandomNumberGenerator)->void:
	var leaf:Color=biome.get("accent",Color("#3f7650")).darkened(.08)
	leaf_cluster(Vector3(0,.42,0),Vector3(.48,.3,.45),6,.3,leaf,rng)
	leaf_cluster(Vector3(.08,.82,.04),Vector3(.25,.1,.22),3,.2,leaf.lightened(.08),rng)

# A blocky boulder: a big cube with a couple of smaller cubes leaning on it.
func build_boulder(biome:Dictionary,rng:RandomNumberGenerator)->void:
	# A pile of two or three stacked rounded-looking cubes in light grey, like the reference rocks.
	var rock:Color=Color(biome.rock) if biome.has("rock") else Color("#b7bfb4").lerp(biome.get("cliff",Color("#7a4a28")),.12)
	cube(Vector3(0,.42,0),Vector3(1.05,.84,1.0),rock,Vector3(0,rng.randf_range(-.25,.25),0))
	cube(Vector3(.12,1.05,-.05),Vector3(.72,.5,.7),rock.lightened(.05),Vector3(0,rng.randf_range(-.4,.4),0))
	cube(Vector3(-.45,.22,.3),Vector3(.45,.44,.45),rock.darkened(.06))

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
