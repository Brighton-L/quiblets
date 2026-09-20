extends SceneTree
const CAST=preload("res://scripts/move_cast_3d.gd")
var arena:Node3D
var source:QuibletActor3D
var victim:QuibletActor3D
func _initialize():call_deferred("run")
func fixture():
 if is_instance_valid(arena):arena.free()
 arena=Node3D.new();root.add_child(arena)
 source=QuibletActor3D.new();source.setup(GameData.make_quiblet(24,10));arena.add_child(source);source.set_physics_process(false)
 victim=QuibletActor3D.new();victim.setup(GameData.make_quiblet(25,10),true);arena.add_child(victim);victim.set_physics_process(false);victim.position=Vector3(2,0,0);victim.max_hp=10000;victim.current_hp=10000
func cast(name:String):
 var effect:=CAST.new();effect.setup(source,{"name":name,"stones":[],"slots":0},victim,1.0,false);arena.add_child(effect);effect.set_physics_process(false);return effect
func advance(effect,seconds:float):
 for frame in ceili(seconds*60):
  source.update_statuses(1.0/60);victim.update_statuses(1.0/60)
  if not effect.done:effect._physics_process(1.0/60)
func run():
 for i in range(24,28):
  assert(GameData.species(i).element=="Electric")
  var model:=QuibletModel3D.new();root.add_child(model);model.setup(i)
  assert(not model.find_children("*","MeshInstance3D",true,false).is_empty());model.free()
  for move in GameData.learnset(i):assert(GameData.MOVES.has(move) and MoveBehaviors.PROFILES.has(move))
 var recipe:Dictionary=GameData.RECIPES.filter(func(r):return r.name=="Shock Stock")[0]
 assert(recipe.pool==[24,25,26,27])
 fixture();var wire=cast("Live Wire");advance(wire,.4);assert(victim.current_hp<10000 and source.motion_lock==1)
 victim.position.x=9;advance(wire,.1);assert(wire.done and source.motion_lock==0)
 fixture();source.current_hp=source.max_hp*.4;var hp:=source.current_hp;var drain=cast("Amp Drain");advance(drain,.5)
 assert(source.current_hp>hp and source.position.x>.5 and source.motion_lock>0)
 hp=source.current_hp;source.take_damage(10,victim);assert(source.current_hp<hp,"Attached caster must remain vulnerable")
 victim.position.z=.8;advance(drain,.3);assert(source.position.z>.1);advance(drain,3);assert(drain.done and source.motion_lock==0)
 fixture();var clamp=cast("Shock Clamp");advance(clamp,.6);assert(victim.statuses.has("root") and source.motion_lock>0);advance(clamp,3);victim.update_statuses(.3);assert(not victim.statuses.has("root") and source.motion_lock==0)
 fixture();var toss=cast("Shock Toss");advance(toss,1.5);assert(victim.position.x>4 and toss.done)
 for move in ["Shock Touch","Zigzag"]:
  fixture();var maneuver=cast(move);advance(maneuver,2)
  assert(source.position.length()<.1 and victim.current_hp<10000 and source.motion_lock==0,move+" must return to its origin")
 fixture();var side=cast("Flashstep");advance(side,1);assert(absf(source.position.z)>1 and victim.current_hp<10000)
 fixture();var friction=cast("Friction Dash");advance(friction,1);assert(friction.done and victim.current_hp<10000 and source.position.x<2)
 fixture();var grounded=cast("Grounded");advance(grounded,.1);source.displace(Vector3(5,0,0));assert(source.position.x<.6)
 source.add_status("paralyzed",2,1,victim);assert(source.statuses.paralyzed.time<.3);source.update_statuses(.3);assert(not source.actions_locked())
 source.cleanse();assert(source.statuses.has("grounded"));advance(grounded,6);assert(not source.statuses.has("grounded"))
 fixture();victim.position=Vector3(0,0,-2);var tail=cast("Tail Zap");advance(tail,.3);assert(victim.current_hp<10000)
 arena.queue_free();await process_frame
 print("Electric models, recruitment, learnsets, attachments, tethers, drain, throws, maneuvers, bursts and Grounded passed")
 quit()
