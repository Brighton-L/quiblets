extends SceneTree
const CAST=preload("res://scripts/move_cast_3d.gd")
func _initialize():call_deferred("run")
func run():
 seed(8182)
 var arena:=Node3D.new();root.add_child(arena)
 var source:=QuibletActor3D.new();source.setup(GameData.make_quiblet(22,10));arena.add_child(source);source.set_physics_process(false)
 var target:=QuibletActor3D.new();target.setup(GameData.make_quiblet(23,10),true);arena.add_child(target);target.set_physics_process(false);target.position=Vector3(2,0,0);target.max_hp=1000000;target.current_hp=1000000
 assert(is_instance_valid(source.model.gas_body))
 for index in [22,23]:
  assert(ResourceLoader.exists(GameData.species(index).model))
  assert(GameData.learnset(index).size()==10)
  assert(GameData.RECIPES.any(func(recipe):return recipe.pool.has(index)))
 var cast:=CAST.new();cast.setup(source,{"name":"Contaminate","stones":[],"slots":0},target,1.0,false);arena.add_child(cast);cast.set_physics_process(false)
 target.position=Vector3(3,0,1);cast._physics_process(.5)
 assert(cast.patches[0].pos==target.position and target.statuses.has("contaminated") and target.current_hp<target.max_hp)
 cast.finish(false)
 var spit:=CAST.new();spit.setup(source,{"name":"Poison Spit","stones":[],"slots":0},target,1.0,false);arena.add_child(spit);spit.set_physics_process(false)
 var plain:=0;var contaminated:=0
 for i in 300:
  target.statuses.clear();spit.hit(target,1)
  if target.statuses.has("poison"):plain+=1
  target.statuses.clear();target.add_status("contaminated",3,.4,source);spit.hit(target,1)
  if target.statuses.has("poison"):contaminated+=1
 assert(contaminated>plain+60)
 spit.finish(false)
 target.statuses.clear();target.add_status("nauseated",12,.3,source)
 var interruptions:=0
 for i in 14:
  target.statuses.erase("stun");target.update_statuses(.8)
  if target.statuses.has("stun"):interruptions+=1
 assert(interruptions>0)
 target.statuses.clear();target.add_status("slippery",3,.8,source);target.velocity=Vector3(-2,0,0);target.move_toward_point(target.position+Vector3(5,0,0),1.0/60,false)
 assert(target.velocity.x<0,"Slippery movement must retain momentum instead of instantly reversing")
 target.cleanse()
 assert(not target.statuses.has("slippery"))
 var escape:=CAST.new();target.position=Vector3(1,0,0);escape.setup(source,{"name":"Slick Escape","stones":[],"slots":0},target,1.0,false);arena.add_child(escape);escape.set_physics_process(false)
 assert(escape.direction.x<0)
 for i in 40:escape._physics_process(1.0/60)
 assert(source.position.x<0 and escape.patches.size()>1 and escape.profile.mode=="field")
 escape.finish(false)
 arena.queue_free();await process_frame
 print("New Poison species, models, following haze, poison susceptibility, nausea, skid and escape trail passed")
 quit()
