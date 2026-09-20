class_name QuibletModel3D
extends Node3D

const SIZE_MULTIPLIER:=.75

var species_index := 0
var enemy := false
var body_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var floating_pivot:Node3D
var floating_center:=Vector3.ZERO
var floating_time:=0.0
var species_move_name:=""
var species_move_time:=0.0
var species_move_delay:=0.0
var gas_body:Node3D
var gas_rest_position:=Vector3.ZERO
var gas_rest_scale:=Vector3.ONE
var gas_center:=Vector3.ZERO
var gas_time:=0.0
var gas_spread:=1.0

func setup(index: int, is_enemy := false, model_scale := 1.0) -> void:
	species_index = index
	enemy = is_enemy
	scale = Vector3.ONE * model_scale * SIZE_MULTIPLIER * float(GameData.species(index).get("visual_scale",1.0))
	build_model()

func animate_walking(phase:float,bounce:float,tilt:=0.0)->void:
	# Floating species glide; their imported mesh already supplies the air gap.
	var grounded:=float(GameData.species(species_index).get("model_hover",0.0))<=0.0
	position.y=absf(sin(phase))*bounce if grounded else 0.0
	rotation.z=sin(phase)*tilt if grounded else 0.0

func material(color: Color, roughness := 0.82) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = saturated(color, model_saturation())
	apply_model_glow(mat)
	mat.roughness = roughness
	return mat

func mesh_part(mesh: PrimitiveMesh, pos: Vector3, mat: Material, part_scale := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.scale = part_scale
	part.material_override = mat
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(part)
	return part

func sphere(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return mesh_part(mesh, pos, mat, size)

func box(pos: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := mesh_part(mesh, pos, mat)
	part.rotation = rotation
	return part

func build_model() -> void:
	var s := GameData.species(species_index)
	body_material = material(s.color)
	accent_material = material(s.accent)
	# Some species ship a real 3D model (res://models/*.glb) instead of the
	# procedural toy body; load and auto-fit it to the same scale.
	if s.has("model") and ResourceLoader.exists(str(s.model)):
		build_imported_model(str(s.model),float(s.get("model_yaw",IMPORTED_MODEL_YAW)),float(s.get("model_hover",0.0)));return
	if s.shape=="pitcher":build_pitcher();return
	if s.shape=="pillbug":build_pillbug();return
	var dark := material(GameData.COLORS.ink, 0.55)
	var white := material(Color.WHITE, 0.45)
	# Chunky low-poly body.
	sphere(Vector3(0,0.68,0),Vector3(1.22,1.16,1.08),body_material)
	sphere(Vector3(0,0.38,0.08),Vector3(.76,.62,.82),material(s.color.lightened(.09)))
	# Feet establish a grounded, toy-like silhouette.
	sphere(Vector3(-.34,.08,.14),Vector3(.4,.2,.5),accent_material)
	sphere(Vector3(.34,.08,.14),Vector3(.4,.2,.5),accent_material)
	match s.shape:
		"ears":
			box(Vector3(-.38,1.35,0),Vector3(.38,.8,.34),body_material,Vector3(0,0,-.28))
			box(Vector3(.38,1.35,0),Vector3(.38,.8,.34),body_material,Vector3(0,0,.28))
		"tail":
			sphere(Vector3(.82,.56,.1),Vector3(.58,.58,.58),accent_material)
			sphere(Vector3(1.06,.78,.1),Vector3(.3,.3,.3),material(GameData.COLORS.gold))
		"fins":
			box(Vector3(-.76,.75,0),Vector3(.65,.18,.52),accent_material,Vector3(0,.1,.35))
			box(Vector3(.76,.75,0),Vector3(.65,.18,.52),accent_material,Vector3(0,-.1,-.35))
		"horn":
			var cone := CylinderMesh.new(); cone.top_radius=0.0; cone.bottom_radius=.23; cone.height=.72; cone.radial_segments=7
			mesh_part(cone,Vector3(0,1.48,0),accent_material)
		"tuft", "crest":
			for x in [-.32,0.0,.32]:
				var cone := CylinderMesh.new();cone.top_radius=0.0;cone.bottom_radius=.18;cone.height=.55;cone.radial_segments=6
				mesh_part(cone,Vector3(x,1.35,0),accent_material)
		"fists":
			# Two psychic fists float free beside the body, slightly forward.
			for fx in [-1.0, 1.0]:
				sphere(Vector3(fx*1.15,.82,.28),Vector3(.52,.5,.52),accent_material)
				for knuckle in [-.16,0.0,.16]:
					sphere(Vector3(fx*1.32,.82+knuckle*.55,.5),Vector3(.14,.14,.14),body_material)
		"puff":
			# A soft psychic puff of accent blobs haloing the head.
			for i in 6:
				var ang:float=TAU*i/6.0
				sphere(Vector3(cos(ang)*.62,1.05+sin(ang)*.34,sin(ang)*.2),Vector3(.42,.42,.42),accent_material)
		"boulder":
			# A loose pile of rocky lumps on its back.
			for off in [Vector3(-.4,1.02,-.1),Vector3(.12,1.28,.05),Vector3(.44,1.0,-.05)]:
				sphere(off,Vector3(.5,.46,.48),accent_material)
		"web":
			# Spindly spider legs to either side.
			for fx in [-1.0,1.0]:
				for k in 3:
					box(Vector3(fx*.95,.5+k*.34,.1),Vector3(.7,.1,.1),material(GameData.COLORS.ink,.7),Vector3(0,0,fx*(.4-k*.2)))
		"gloop":
			# Drippy sludge blobs sliding off its dome.
			for off in [Vector3(-.5,1.0,.1),Vector3(.2,1.24,-.05),Vector3(.5,.92,.12)]:
				sphere(off,Vector3(.4,.5,.4),accent_material)
		"balloon":
			# Puffer spikes ringing a round body.
			for i in 10:
				var ang:float=TAU*i/10.0
				var spike:=CylinderMesh.new();spike.top_radius=0.0;spike.bottom_radius=.1;spike.height=.34;spike.radial_segments=5
				var bump:=mesh_part(spike,Vector3(cos(ang)*.95,.75+sin(ang)*.5,.15),accent_material);bump.rotation.z=-ang+PI*.5
		"spikes":
			# A crest of ice spikes.
			for x in [-.4,-.13,.14,.41]:
				var ice:=CylinderMesh.new();ice.top_radius=0.0;ice.bottom_radius=.14;ice.height=.6;ice.radial_segments=5
				mesh_part(ice,Vector3(x,1.4,0),accent_material)
		"moon":
			var torus := TorusMesh.new();torus.inner_radius=.23;torus.outer_radius=.39;torus.rings=10;torus.ring_segments=6
			var moon := mesh_part(torus,Vector3(.18,1.35,0),accent_material);moon.rotation.x=PI/2
		"shell":
			var shell:=sphere(Vector3(-.2,.78,-.36),Vector3(.95,.95,.35),accent_material);shell.rotation.z=.2
	# Face points toward +Z.
	for x in [-.27,.27]:
		sphere(Vector3(x,.84,.51),Vector3(.15,.19,.1),dark)
		sphere(Vector3(x-.025,.89,.565),Vector3(.045,.055,.025),white)
	# Tiny nose and blush cubes.
	box(Vector3(0,.65,.56),Vector3(.11,.07,.06),dark)
	sphere(Vector3(-.48,.64,.5),Vector3(.13,.08,.05),material(Color(s.accent,.8)))
	sphere(Vector3(.48,.64,.5),Vector3(.13,.08,.05),material(Color(s.accent,.8)))

func build_pitcher()->void:
	var dark:=material(Color("#403544"));var liquid:=material(Color("#996bb3"))
	sphere(Vector3(0,.25,0),Vector3(.95,.42,.95),body_material)
	for x in [-.3,.3]:sphere(Vector3(x,.08,.15),Vector3(.28,.18,.4),accent_material)
	for i in 12:
		var angle:=TAU*i/12.0
		box(Vector3(sin(angle)*.53,.65,cos(angle)*.53),Vector3(.32,.85,.2),body_material,Vector3(0,angle,0))
	var pool:=CylinderMesh.new();pool.top_radius=.47;pool.bottom_radius=.47;pool.height=.04;pool.radial_segments=16
	mesh_part(pool,Vector3(0,.78,0),liquid)
	var rim:=TorusMesh.new();rim.inner_radius=.46;rim.outer_radius=.7;rim.rings=16;rim.ring_segments=6
	mesh_part(rim,Vector3(0,1.06,0),accent_material)
	var lid:=box(Vector3(0,1.38,-.46),Vector3(.95,.12,.65),body_material,Vector3(-.7,0,0));lid.name="PitcherLid"
	for side in [-1,1]:
		box(Vector3(side*.7,.4,-.1),Vector3(.6,.12,.32),body_material,Vector3(0,side*.35,side*.3))
		sphere(Vector3(side*.25,.8,.64),Vector3(.14,.18,.08),dark)
		sphere(Vector3(side*.25-.02,.84,.685),Vector3(.04,.05,.02),material(Color.WHITE))

func build_pillbug()->void:
	var dark:=material(Color("#403d38"))
	sphere(Vector3(0,.35,0),Vector3(1.1,.55,1.45),dark)
	for i in 5:
		var z:float=-.56+i*.27;var width:=1.1-.18*absf(i-2)
		sphere(Vector3(0,.52,z),Vector3(width,.72,.32),body_material if i%2==0 else accent_material)
	for side in [-1,1]:
		for z in [-.42,0.0,.42]:box(Vector3(side*.53,.12,z),Vector3(.32,.16,.16),accent_material,Vector3(0,side*.35,0))
		sphere(Vector3(side*.22,.43,.76),Vector3(.13,.15,.08),dark)
		box(Vector3(side*.26,.64,.8),Vector3(.07,.3,.07),accent_material,Vector3(.3,0,side*-.3))
	var body:=Node3D.new();body.name="PillbugBody"
	var parts:=get_children();add_child(body)
	for part in parts:remove_child(part);body.add_child(part)
	var curled:=sphere(Vector3(0,.62,0),Vector3(1.24,1.24,1.24),body_material);curled.name="CurledShell";curled.visible=false
	for i in 5:
		var ring:=TorusMesh.new();ring.inner_radius=.56;ring.outer_radius=.62;ring.rings=12;ring.ring_segments=4
		var band:=mesh_part(ring,Vector3.ZERO,accent_material);remove_child(band);curled.add_child(band);band.rotation.x=PI*.5;band.rotation.y=i*PI/5.0

func animate_species_move(move_name:String,time:float,delay:float)->void:
	species_move_name=move_name;species_move_time=time;species_move_delay=delay
	if is_instance_valid(gas_body):
		gas_spread=1.0
		if move_name=="Miasmum":gas_spread=lerpf(1.0,1.5,minf(time/.5,1.0))
		elif move_name in ["Fume Shot","Pressure Cloud"]:gas_spread=1.0-.25*sin(clampf(time/.45,0,1)*PI)
	var lid:=get_node_or_null("PitcherLid")
	if lid!=null:
		lid.rotation.x=-.7
		if move_name in ["Gulp","Lid Smack"]:lid.rotation.x=-.7+sin(minf(time/.25,1.0)*PI)*1.5
	if move_name=="Pound":position.y=sin(clampf(time/maxf(delay,.01),0,1)*PI)*2.8
	var body:=get_node_or_null("PillbugBody")
	if body!=null:
		var curled:bool=move_name in ["Rollout","Rolling Smash"] or (move_name=="Unfurl" and time<delay)
		var actor:=get_parent()
		if actor is QuibletActor3D and actor.statuses.has("shield"):curled=true
		body.visible=not curled;get_node("CurledShell").visible=curled
		get_node("CurledShell").rotation.x=time*10.0 if move_name in ["Rollout","Rolling Smash"] else 0.0

# Imported glTF models are authored facing a different way than the procedural
# bodies (+Z forward); rotate them so they line up with everything else.
const IMPORTED_MODEL_YAW := PI / 2.0  # counter-clockwise 90° (viewed from above)

func build_imported_model(path: String, yaw := IMPORTED_MODEL_YAW, hover := 0.0) -> void:
	var scene: PackedScene = load(path)
	if scene == null:return
	var inst: Node3D = scene.instantiate() as Node3D
	if inst == null:return
	add_child(inst)
	inst.rotation.y = yaw
	# Fit the model to roughly the toy body's height, feet on the ground, centered —
	# accounting for the yaw so the recentre still lands it over the origin.
	var box := combined_aabb(inst)
	if box.size.y > 0.001:
		var factor := 1.8 / box.size.y
		inst.scale = Vector3.ONE * factor
		# Where the local centre ends up in parent space after yaw + scale.
		var placed := inst.basis * box.get_center()
		inst.position = Vector3(-placed.x, -box.position.y * factor, -placed.z)
	# Keep floating species above their ground anchor in camp, combat and reveals.
	inst.position.y+=hover
	if str(GameData.species(species_index).name)=="Miasmum":
		gas_body=inst;gas_rest_position=inst.position;gas_rest_scale=inst.scale;gas_center=inst.transform*box.get_center()
	restore_imported_colors(inst)
	if GameData.species(species_index).get("model_corner_roll",false):
		# Roll around the body centre rather than the feet, leaving navigation,
		# facing and the ground anchor independent of the floating animation.
		floating_center=inst.transform*box.get_center()
		floating_pivot=Node3D.new();floating_pivot.name="FloatingBody";add_child(floating_pivot)
		floating_pivot.position=floating_center
		remove_child(inst);floating_pivot.add_child(inst);inst.position-=floating_center
		update_floating_pose(0.0)

func _process(delta:float)->void:
	if is_instance_valid(gas_body):
		gas_time+=delta;gas_body.scale=gas_rest_scale*gas_spread
		gas_body.position=gas_center+(gas_rest_position-gas_center)*gas_spread+Vector3.UP*sin(gas_time*1.4)*.12
	if GameData.species(species_index).shape=="pillbug" and get_parent() is QuibletActor3D :animate_species_move(species_move_name,species_move_time,species_move_delay)
	if not is_instance_valid(floating_pivot):return
	floating_time+=delta;update_floating_pose(floating_time)

func update_floating_pose(time:float)->void:
	if not is_instance_valid(floating_pivot):return
	# Keep the top face upward while the lowest bottom corner advances clockwise.
	var turns:=time/3.0;var corner:=floorf(turns);var progress:=smoothstep(0.0,1.0,turns-corner)
	var angle:=PI*.25+(corner+progress)*PI*.5
	var tilt:=deg_to_rad(8.0)
	floating_pivot.rotation=Vector3(tilt*sin(angle),0.0,-tilt*cos(angle))
	floating_pivot.position=floating_center+Vector3.UP*sin(time*TAU/6.0)*.25

# Soften chromatic colours consistently across imported and procedural Quiblets.
# A small amount of self-emission keeps colours visible in shade.
const MODEL_SATURATION := 1.0
const MODEL_EMISSION := 0.12

func apply_model_glow(mat:StandardMaterial3D)->void:
	var strength:=float(GameData.species(species_index).get("model_emission",MODEL_EMISSION))
	mat.emission_enabled=strength>0.0
	mat.emission=mat.albedo_color
	mat.emission_energy_multiplier=strength

func model_saturation()->float:
	return float(GameData.species(species_index).get("model_saturation",MODEL_SATURATION))

func restore_imported_colors(inst: Node3D) -> void:
	# Purely a rendering tweak; the headless dummy rasterizer has no real material
	# storage, so skip it there (and spare the test logs its null-material noise).
	if DisplayServer.get_name() == "headless":return
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:continue
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			if not (src is StandardMaterial3D):continue
			var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			m.albedo_color = saturated(m.albedo_color, model_saturation())
			apply_model_glow(m)
			mi.set_surface_override_material(s, m)

# Adjust distance from grey (1.0 = unchanged), preserving black, white and alpha.
func saturated(c: Color, amount: float) -> Color:
	var grey := (c.r + c.g + c.b) / 3.0
	return Color(
		clampf(grey + (c.r - grey) * amount, 0.0, 1.0),
		clampf(grey + (c.g - grey) * amount, 0.0, 1.0),
		clampf(grey + (c.b - grey) * amount, 0.0, 1.0),
		c.a)

func combined_aabb(node: Node) -> AABB:
	var result := AABB();var started := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = child.get_aabb()
		var xform: Transform3D = child.transform
		var parent := child.get_parent()
		while parent != null and parent != node:
			xform = parent.transform * xform;parent = parent.get_parent()
		box = xform * box
		if not started:result = box;started = true
		else:result = result.merge(box)
	return result

func set_hurt(hurt: bool) -> void:
	rotation.z = .14 if hurt else 0.0

func set_selected(value: bool) -> void:
	var existing := get_node_or_null("SelectionRing")
	if value and existing == null:
		var ring_mesh := TorusMesh.new();ring_mesh.inner_radius=.7;ring_mesh.outer_radius=.8;ring_mesh.rings=20;ring_mesh.ring_segments=6
		var ring := MeshInstance3D.new();ring.name="SelectionRing";ring.mesh=ring_mesh;ring.position.y=.03;ring.material_override=material(GameData.COLORS.gold, .35);add_child(ring)
	elif not value and existing:
		existing.queue_free()
