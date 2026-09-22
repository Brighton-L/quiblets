extends SceneTree
const CAST=preload("res://scripts/move_cast_3d.gd")
var arena:Node3D
func _initialize():call_deferred("run")
func actor(species:int,enemy:=false,pos:=Vector3.ZERO)->QuibletActor3D:
 var a:=QuibletActor3D.new();a.setup(GameData.make_quiblet(species,10),enemy);arena.add_child(a);a.position=pos;a.set_physics_process(false);a.current_hp=10000;a.max_hp=10000;return a
func cast(a:QuibletActor3D,name:String,victim:QuibletActor3D,stones:Array=[]):
 var c:=CAST.new();c.setup(a,{"name":name,"slots":3,"stones":stones},victim,1.,false);arena.add_child(c);c.set_physics_process(false);return c
func run():
 arena=Node3D.new();root.add_child(arena)
 for index in [28,29,30]:
  assert(ResourceLoader.exists(GameData.species(index).model))
  var a:=actor(index);assert(a.model.get_child_count()>0)
  assert(GameData.RECIPES[0].pool.has(index))
  for move in GameData.learnset(index):assert(GameData.MOVES.has(move) and MoveBehaviors.PROFILES.has(move))
  a.free()
 assert(GameData.species(28).evolves_to==29 and GameData.species(28).evolve_level==22)
 assert(GameData.species_types(28)==["Air","Poison"] and GameData.species_type_text(29)=="Air + Poison")
 assert(GameData.quiblet_relationship({"species":28},{"species":22})=="type")
 assert(GameData.quiblet_relationship({"species":28},{"species":16})=="type")
 var bat:=actor(28);var evolved:=actor(29,false,Vector3(0,0,1));var seal:=actor(30,false,Vector3(0,0,2));var enemy:=actor(0,true,Vector3(2,0,0))
 var keen=cast(bat,"Keen Ears",enemy,["sharing"]);keen._physics_process(.1);assert(bat.statuses.has("evade") and seal.statuses.has("evade"));keen.finish(false)
 for a in [bat,evolved,seal]:a.statuses.clear()
 var armor=cast(seal,"Ice Armor",enemy,["sharing"]);armor._physics_process(.1);assert(seal.statuses.has("defense") and bat.statuses.has("defense"));assert(seal.take_damage(100,null,false)<60);armor.finish(false)
 for a in [bat,evolved,seal]:a.statuses.clear()
 var brace=cast(seal,"Brace",enemy,["sharing"]);brace._physics_process(.1)
 assert(seal.statuses.has("anchored") and seal.statuses.has("defense") and bat.statuses.has("defense") and not bat.statuses.has("anchored"))
 assert(seal.bonus_value("knockback")>=1 and seal.movement_locked())
 var before:=seal.position;seal.displace(Vector3(3,0,0));assert(seal.position==before);seal.update_statuses(7);assert(not seal.statuses.has("anchored"));brace.finish(false)
 var cloud=cast(bat,"Noxious Cloud",enemy);assert(cloud.profile.anchor=="self" and cloud.patches[0].pos==bat.position);cloud.finish(false)
 var thunder=cast(bat,"Thunderflap",enemy);var loud=cast(evolved,"Thunderflap",enemy)
 assert(thunder.radius==loud.radius and thunder.profile.knockback==loud.profile.knockback and loud.dramatic_scale>thunder.dramatic_scale);thunder.finish(false);loud.finish(false)
 var pound=cast(seal,"Pound",enemy);assert(pound.profile.visual=="heavy_ice_impact" and pound.profile.radius==MoveBehaviors.PROFILES.Pound.radius);pound.finish(false)
 var breath=cast(bat,"Frost Breath",enemy);enemy.statuses.clear();var hp:=enemy.current_hp
 breath._physics_process(.1);var first:=enemy.current_hp;breath._physics_process(.35);assert(first<hp and enemy.current_hp<first and enemy.statuses.has("slow"));breath.finish(false)
 var tusk=cast(seal,"Tuskberg",enemy);enemy.statuses.clear();tusk._physics_process(.1);assert(enemy.statuses.has("launch"));tusk.finish(false)
 arena.free();await process_frame
 print("Lombat/Lombera/Snobble models, learnsets, dual typing, recruitment, shared buffs, anchoring, sustained breath, and signature visuals passed")
 quit()
