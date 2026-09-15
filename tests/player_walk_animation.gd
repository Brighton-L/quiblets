extends SceneTree
func _initialize():call_deferred("run")
func run():
 var arena:=Node3D.new();root.add_child(arena)
 for species in [0,16]:
  var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(species,6));arena.add_child(actor);actor.set_physics_process(false)
  var start:=actor.position;actor.command(Vector3(5,0,0))
  var bounced:=false
  for i in 15:
   actor._physics_process(1.0/60.0)
   if actor.model.position.y>.001:bounced=true
  assert(actor.position.x>start.x)
  assert(bounced==(species!=16),"Only grounded player Quiblets should bob while walking")
  actor.has_command=false;actor.velocity=Vector3.ZERO
  for i in 60:actor._physics_process(1.0/60.0)
  assert(absf(actor.model.position.y)<.001 and absf(actor.model.rotation.z)<.001,"Idle animation should settle")
  actor.model_lift=2;actor._physics_process(1.0/60.0)
  assert(absf(actor.model.position.y-2)<.001,"Spawn lift must be preserved")
  actor.queue_free();await process_frame
 arena.queue_free();await process_frame;print("Player walking, idle, floating and lift checks passed");quit()
