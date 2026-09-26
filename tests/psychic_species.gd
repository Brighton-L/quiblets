extends SceneTree
const CAST=preload("res://scripts/move_cast_3d.gd")
var arena:Expedition3D
func _initialize():call_deferred("run")
func actor(species:int,enemy:=false,pos:=Vector3.ZERO)->QuibletActor3D:
 var a:=QuibletActor3D.new();a.setup(GameData.make_quiblet(species,10),enemy);arena.add_child(a);a.position=pos;a.set_physics_process(false);a.max_hp=10000;a.current_hp=10000;return a
func cast(a:QuibletActor3D,name:String,victim:QuibletActor3D,stones:Array=[]):
 var c:=CAST.new();c.setup(a,{"name":name,"slots":3,"stones":stones},victim,1.,false);arena.add_child(c);c.set_physics_process(false);return c
func run():
 seed(63);arena=Expedition3D.new();root.add_child(arena);arena.set_process(false)
 assert(GameData.SPECIES.size()==34 and GameData.LEARNSETS.size()==34)
 for id in [31,32,33]:
  assert(ResourceLoader.exists(GameData.species(id).model))
  var a:=actor(id);assert(a.model.get_child_count()>0)
  assert(GameData.learnset(id).size()=={31:9,32:10,33:13}[id])
  for move in GameData.learnset(id):assert(GameData.MOVES.has(move) and MoveBehaviors.PROFILES.has(move))
  for recipe in GameData.RECIPES:
   if recipe.attraction_kind=="any" or (recipe.attraction_kind=="type" and GameData.species_types(id).has(recipe.attraction_target)):assert(recipe.pool.has(id))
  a.free()
 assert(GameData.species(32).evolves_to==33 and GameData.species_types(33)==["Air","Psychic"])
 var wool:=actor(31);var bird:=actor(32,false,Vector3(0,0,1));var adult:=actor(33,false,Vector3(0,0,-1));var enemy:=actor(0,true,Vector3(2,0,0))
 assert(wool.bonus_value("resist")>=.15 and bird.bonus_value("evasion")>=.15 and adult.speed>bird.speed and bird.speed>wool.speed)
 var focus=cast(bird,"Focus",enemy,["sharing"]);focus._physics_process(.1)
 assert(bird.statuses.has("accuracy") and bird.statuses.empower.amount>1)
 assert(not wool.statuses.has("accuracy") and wool.statuses.empower.amount>1 and wool.statuses.empower.amount<bird.statuses.empower.amount);focus.finish(false)
 for a in [wool,bird,adult]:a.statuses.clear()
 var wind=cast(bird,"Tailwind",enemy);wind._physics_process(.1);assert(bird.statuses.has("hasten") and not wool.statuses.has("hasten"));wind.finish(false)
 wind=cast(bird,"Tailwind",enemy,["sharing"]);wind._physics_process(.1);assert(wool.statuses.has("hasten"));wind.finish(false)
 var barrier=cast(wool,"Armor",enemy);barrier._physics_process(.1);assert(wool.take_damage(100,null,false)<50);barrier.finish(false);wool.statuses.clear()
 wool.current_hp=5000
 var doze=cast(wool,"Doze",enemy);doze._physics_process(.1);assert(wool.actions_locked());wool.update_statuses(1);assert(wool.current_hp>5700 and wool.current_hp<6000);wool.update_statuses(4);assert(not wool.actions_locked());doze.finish(false)
 var walk=cast(wool,"Sleepwalk",enemy);walk._physics_process(.1);assert(wool.statuses.has("evade") and wool.current_speed()>wool.speed and not wool.actions_locked());walk.finish(false);wool.statuses.clear()
 var dream=cast(wool,"Daydream",enemy);dream._physics_process(.1);assert(dream.psychic_illusions.size()==4 and wool.statuses.evade.amount>=.75)
 for illusion in dream.psychic_illusions:assert(not illusion is CharacterBody3D)
 dream.finish(false)
 enemy.move_cooldowns=[5.0];enemy.motion_lock=1
 var drowse=cast(wool,"Drowse",enemy);drowse.hit(enemy,0);assert(enemy.statuses.has("drowse") and enemy.current_speed()<enemy.speed)
 enemy.process_actor_physics(1);assert(is_equal_approx(enemy.move_cooldowns[0],4.4));drowse.finish(false);enemy.statuses.clear()
 var lock=cast(adult,"Lock On",enemy);lock._physics_process(.1);assert(adult.locked_on_to(enemy) and not adult.locked_on_to(wool))
 assert(is_equal_approx(enemy.take_damage(100,adult,false),135.0));lock.finish(false)
 var decoy=cast(bird,"Decoy",enemy);decoy._physics_process(.1)
 var clones=arena.get_children().filter(func(n):return n is QuibletActor3D and n.get_meta("psychic_decoy",false))
 assert(clones.size()==1)
 var clone=clones[0];clone.set_physics_process(false)
 assert(clone.data.moves.is_empty() and not arena.team.has(clone) and not arena.enemies.has(clone))
 var players:Array[QuibletActor3D]=[wool,bird,adult]
 assert(arena.nearest(enemy,players)==clone)
 clone.take_damage(clone.max_hp*10);assert(clone.is_queued_for_deletion() and arena.nearest(enemy,players)!=clone);decoy.finish(false)
 decoy=cast(bird,"Decoy",enemy);decoy._physics_process(.1)
 clones=arena.get_children().filter(func(n):return n is QuibletActor3D and n.get_meta("psychic_decoy",false) and not n.is_queued_for_deletion())
 clones[0]._physics_process(8);assert(clones[0].is_queued_for_deletion());decoy.finish(false)
 adult.statuses.clear();adult.position=Vector3.ZERO;enemy.current_hp=10000;enemy.position=Vector3(2,0,0)
 var dive=cast(adult,"Perfect Dive",enemy);assert(adult.statuses.has("exposed"));dive._physics_process(.2);assert(adult.position==Vector3.ZERO)
 enemy.position=Vector3(2,0,1);dive._physics_process(.16);assert(adult.position.z>0 and enemy.current_hp<10000);dive.finish(false)
 adult.position=Vector3.ZERO;enemy.position=Vector3(2,0,0);enemy.current_hp=10000
 var mach=cast(adult,"Mach Pass",enemy)
 for i in 60:
  if mach.profile.mode=="pressure_pass":break
  mach._physics_process(.02)
 assert(mach.profile.mode=="pressure_pass" and enemy.current_hp<10000)
 var first:=enemy.current_hp;mach._physics_process(.17);assert(enemy.current_hp==first)
 mach._physics_process(.02)
 for i in 40:
  if mach.done:break
  mach._physics_process(.02)
 assert(enemy.current_hp<first and enemy.position.x>2,"Pressure wave must hit again and push the enemy")
 arena.free();await process_frame
 print("Psychic species: models, learnsets, dual typing, buffs, sleep, drowsiness, illusions, target lock, damageable decoys and two-stage Mach Pass passed");quit()
