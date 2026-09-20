extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 var sequence=load("res://scripts/quiblet_arrival.gd").new();root.add_child(sequence);sequence.game=game
 for species in [0,16,13,22,26,27]:
  var body:=Node3D.new();game.world_root.add_child(body);body.position=Vector3(2.7,0,1.6)
  var model:=QuibletModel3D.new();model.setup(species,false,preload("res://scripts/camp_roaming.gd").MODEL_SCALE);body.add_child(model)
  sequence.visitors.clear();sequence.visitors.append({"model":model})
  var framing:Dictionary=sequence.reveal_framing(model);sequence.pose_camera(framing.position,framing.focus)
  await process_frame
  for phase in [0.0,1.5,3.0,6.0]:
   model.update_floating_pose(phase)
   var bounds:AABB=model.global_transform*model.combined_aabb(model)
   for corner in 8:
    var point:=bounds.get_endpoint(corner)
    assert(not game.camera_3d.is_position_behind(point))
    var screen:Vector2=game.camera_3d.unproject_position(point)/Vector2(game.get_viewport().get_visible_rect().size)
    assert(screen.x>.48 and screen.x<.98 and screen.y>.05 and screen.y<.88,"Reveal body must remain beside cards and within the screen: %s %s"%[species,screen])
  if species==16:assert(sequence.entrance_camera_lift()>3.0)
  body.queue_free()
 sequence.queue_free();game.queue_free();await process_frame
 print("Arrival framing keeps grounded, floating, and large models visible beside their cards")
 quit()
