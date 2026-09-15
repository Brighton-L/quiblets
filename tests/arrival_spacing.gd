extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 var sequence=load("res://scripts/quiblet_arrival.gd").new();root.add_child(sequence);sequence.game=game
 var radii:Array[float]=[]
 for species in [0,5,16,2,3]:
  var body:=Node3D.new();game.world_root.add_child(body)
  var model:=QuibletModel3D.new();model.setup(species,false,preload("res://scripts/camp_roaming.gd").MODEL_SCALE);body.add_child(model)
  var bounds:AABB=model.transform*model.combined_aabb(model)
  radii.append(Vector2(bounds.size.x,bounds.size.z).length()*.5)
  sequence.visitors.append({"actor":body,"model":model})
 sequence.prepare_arrival_route()
 for step in 201:
  sequence.walk_in(float(step)/200)
  for i in sequence.visitors.size():
   for j in range(i+1,sequence.visitors.size()):
    var a:Vector3=sequence.visitors[i].actor.position;var b:Vector3=sequence.visitors[j].actor.position
    assert(Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))>radii[i]+radii[j],"Arrivals must remain separated throughout the entrance")
 print("Five mixed-size arrivals stay separated along the full route")
 sequence.queue_free();game.queue_free();await process_frame;quit()
