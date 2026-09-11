class_name QuibletModel3D
extends Node3D

var species_index := 0
var enemy := false
var body_material: StandardMaterial3D
var accent_material: StandardMaterial3D

func setup(index: int, is_enemy := false, model_scale := 1.0) -> void:
	species_index = index
	enemy = is_enemy
	scale = Vector3.ONE * model_scale
	build_model()

func material(color: Color, roughness := 0.82) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
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
		build_imported_model(str(s.model));return
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

# Imported glTF models are authored facing a different way than the procedural
# bodies (+Z forward); rotate them so they line up with everything else.
const IMPORTED_MODEL_YAW := PI / 2.0  # counter-clockwise 90° (viewed from above)

func build_imported_model(path: String) -> void:
	var scene: PackedScene = load(path)
	if scene == null:return
	var inst: Node3D = scene.instantiate() as Node3D
	if inst == null:return
	add_child(inst)
	inst.rotation.y = IMPORTED_MODEL_YAW
	# Fit the model to roughly the toy body's height, feet on the ground, centered —
	# accounting for the yaw so the recentre still lands it over the origin.
	var box := combined_aabb(inst)
	if box.size.y > 0.001:
		var factor := 1.8 / box.size.y
		inst.scale = Vector3.ONE * factor
		# Where the local centre ends up in parent space after yaw + scale.
		var placed := inst.basis * box.get_center()
		inst.position = Vector3(-placed.x, -box.position.y * factor, -placed.z)

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
