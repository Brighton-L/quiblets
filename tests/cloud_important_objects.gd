extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world=Expedition3D.new();root.add_child(world);world.set_process(false)
 var camera:=Camera3D.new();world.add_child(camera);world.camera=camera;camera.position=Vector3(0,0,10);camera.look_at(Vector3.ZERO)
 var cloud:=Node3D.new();world.add_child(cloud)
 var puff:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;puff.mesh=sphere;puff.position=Vector3(0,0,5);cloud.add_child(puff)
 assert(not world.cloud_blocks_camera(cloud),"Empty ground must not trigger cloud fading")
 var treasure:=Node3D.new();world.add_child(treasure);world.cache_node=treasure
 var box:=MeshInstance3D.new();box.mesh=BoxMesh.new();treasure.add_child(box)
 assert(world.cloud_blocks_camera(cloud),"Cloud in front of treasure must fade")
 puff.position.z=-5
 assert(not world.cloud_blocks_camera(cloud),"Cloud behind treasure must stay opaque")
 puff.position=Vector3(5,0,5)
 assert(not world.cloud_blocks_camera(cloud),"Cloud beside treasure must stay opaque")
 puff.position=Vector3(0,0,5);treasure.hide()
 assert(not world.cloud_blocks_camera(cloud),"Hidden objects must not trigger fades")
 treasure.show();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 assert(world.cloud_blocks_camera(cloud),"Orthographic camera must detect important objects too")
 world.cache_node=null;world.berry_nodes.append(treasure)
 assert(world.cloud_blocks_camera(cloud),"Ingredient patches must trigger fading")
 world.berry_nodes.clear()
 var actor:=QuibletActor3D.new();world.add_child(actor);actor.set_physics_process(false)
 actor.model=QuibletModel3D.new();actor.model.setup(0);actor.add_child(actor.model);world.team.append(actor)
 assert(world.cloud_blocks_camera(cloud),"Quiblets must trigger fading")
 world.queue_free();await process_frame;print("Important-object cloud occlusion checks passed");quit()
