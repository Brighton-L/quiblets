extends SceneTree
const CAST=preload("res://scripts/move_cast_3d.gd")
func _initialize():call_deferred("run")
func run():
 var arena:=Node3D.new();root.add_child(arena)
 var actors:Array[QuibletActor3D]=[]
 for species in [12,30]:
  var a:=QuibletActor3D.new();a.setup(GameData.make_quiblet(species,10));arena.add_child(a);a.set_physics_process(false);a.max_hp=1000;a.current_hp=1000;actors.append(a)
 actors[1].position=Vector3(1,0,0)
 for name in ["Guard","Armor","Brace"]:
  for a in actors:a.statuses.clear();a.current_hp=1000
  var c:=CAST.new();c.setup(actors[0],{"name":name,"stones":["sharing"],"slots":1},null,1.,false);arena.add_child(c);c.set_physics_process(false);c._physics_process(.1)
  if name=="Guard":
   assert(is_equal_approx(actors[0].statuses.shield.amount,400) and is_equal_approx(actors[1].statuses.shield.amount,220))
   assert(actors[0].take_damage(500,null,false)==100)
   assert(actors[0].take_damage(100,null,false)==100,"Shield must be exhausted")
  elif name=="Armor":
   assert(is_equal_approx(actors[0].take_damage(500,null,false),275))
   assert(is_equal_approx(actors[0].take_damage(100,null,false),55))
   assert(not actors[0].movement_locked())
  else:
   assert(is_equal_approx(actors[0].take_damage(500,null,false),200))
   assert(actors[0].movement_locked() and actors[0].bonus_value("knockback")>=1)
   assert(actors[1].statuses.has("defense") and not actors[1].movement_locked())
   assert(actors[0].body_displacement(Vector3.ZERO,Vector3.RIGHT*4,.5)==Vector3.ZERO)
   var start:=actors[0].position;actors[0].displace(Vector3.RIGHT*4);assert(actors[0].position==start)
  actors[0].update_statuses(6.1);assert(not actors[0].statuses.has("defense") and not actors[0].statuses.has("shield") and not actors[0].movement_locked())
  c.finish(false)
 for id in GameData.SPECIES.size():
  var seen:={}
  for move in GameData.learnset(id):
   assert(not seen.has(move) and GameData.MOVES.has(move));seen[move]=true
   assert(not GameData.RETIRED_DEFENSE_MOVES.has(move))
 for old in GameData.RETIRED_DEFENSE_MOVES:
  assert(not GameData.MOVES.has(old) and not MoveBehaviors.PROFILES.has(old))
  var q:Dictionary={"species":9,"moves":[{"name":old,"slots":3,"stones":["sharing","link:Water Shot"]},{"name":"Water Shot","slots":1,"stones":["link_from:"+old]}],"memory":[old]}
  GameData.replace_retired_moves(q)
  var replacement:String=GameData.RETIRED_DEFENSE_MOVES[old]
  assert(q.moves[0].name==replacement and q.moves[0].slots==3 and q.moves[0].stones==["sharing","link:Water Shot"])
  assert(q.moves[1].stones==["link_from:"+replacement] and q.memory==[replacement])
 var dromble:Dictionary={"species":31,"moves":[{"name":"Psy Barrier","slots":2,"stones":["heavy"]}],"memory":["Psy Barrier"]}
 GameData.replace_retired_moves(dromble);assert(dromble.moves[0].name=="Armor" and dromble.memory==["Armor"])
 assert(GameData.LEARNSETS[12].count("Guard")==1)
 arena.free();await process_frame
 print("Defenses: finite shield, sustained reduction, immobile Brace, Sharing, expiry, unique learnsets and in-memory legacy equipment/link preservation passed");quit()
