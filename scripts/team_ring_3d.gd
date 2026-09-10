class_name TeamRing3D
extends Node3D

const COLORS := ["Red", "Green", "Blue", "Cyan", "Yellow"]

var disc: MeshInstance3D

func setup(slot_index: int, ring_size := 1.75) -> void:
	name = "TeamRing%d" % slot_index
	disc = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ring_size, ring_size)
	disc.mesh = plane
	# PlaneMesh already lies on the X/Z ground plane. Rotating it around X made
	# the ring stand vertically like a sign.
	disc.position.y = 0.025
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://textures/UI/TeamRing%s.png" % COLORS[clampi(slot_index, 0, 4)])
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material_override = material
	add_child(disc)
	rotation.y = PI

func follow_facing(source: Node3D) -> void:
	if is_instance_valid(source):
		rotation.y = source.rotation.y + PI
