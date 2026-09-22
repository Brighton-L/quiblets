extends SceneTree
func _initialize():call_deferred("run")
func run():
 var actor:=QuibletActor3D.new();root.add_child(actor);actor.setup(GameData.make_quiblet(0,5));actor.set_physics_process(false)
 actor.collision_layer=5;actor.collision_mask=9
 var shape:=SphereShape3D.new();shape.radius=.3
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=Vector3(0,.7,0);query.collision_mask=5
 await physics_frame;await physics_frame
 assert(not root.world_3d.direct_space_state.intersect_shape(query).is_empty(),"Living Quiblet must collide")
 actor.take_damage(actor.max_hp*10)
 assert(actor.knocked_out and actor.collision_layer==0 and actor.collision_mask==0)
 await physics_frame;await physics_frame
 assert(root.world_3d.direct_space_state.intersect_shape(query).is_empty(),"Fainted Quiblet must not block physics queries")
 actor.revive_from_knockout()
 assert(actor.collision_layer==5 and actor.collision_mask==9,"Revival must restore original collision settings")
 await physics_frame;await physics_frame
 assert(not root.world_3d.direct_space_state.intersect_shape(query).is_empty(),"Revived Quiblet must collide again")
 actor.current_hp=0
 assert(actor.collision_layer==0 and actor.collision_mask==0,"Direct defeat must also remove collision")
 actor.queue_free();await process_frame
 print("Fainted collision: knockout, physics overlap, revival and direct defeat passed");quit()
