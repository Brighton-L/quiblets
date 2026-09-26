extends Node3D
# Basic attacks are independent of equipped moves and never trigger Move Stones.
var attacker_ref:WeakRef
var target_ref:WeakRef
var damage:=0.0
var age:=0.0
func setup(attacker:QuibletActor3D,victim:QuibletActor3D)->void:
	attacker_ref=weakref(attacker);target_ref=weakref(victim)
	damage=GameData.basic_attack_damage(attacker.attack)*attacker.damage_multiplier
	if attacker.statuses.has("empower"):damage*=float(attacker.statuses.empower.amount)
	if attacker.statuses.has("weaken"):damage*=maxf(.1,1.0-float(attacker.statuses.weaken.amount))
	position=attacker.global_position+Vector3.UP*.7
func _ready()->void:
	top_level=true
	var mesh:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.10;sphere.height=.20;mesh.mesh=sphere
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("#fff2c4");mesh.material_override=material;add_child(mesh)
func _physics_process(delta:float)->void:
	if is_queued_for_deletion():return
	age+=delta
	var attacker=attacker_ref.get_ref();var victim=target_ref.get_ref()
	if not is_instance_valid(attacker) or not is_instance_valid(victim) or victim.current_hp<=0 or age>2.0:queue_free();return
	var destination:Vector3=victim.global_position+Vector3.UP*.7
	global_position=global_position.move_toward(destination,18.0*delta)
	if global_position.distance_to(destination)<.18:
		if victim.accepts_hit_from(attacker):victim.take_damage(damage,attacker)
		queue_free()
