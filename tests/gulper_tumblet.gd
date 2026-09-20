extends SceneTree
const CAST=preload("res://scripts/move_cast_3d.gd")
func _initialize():call_deferred("run")
func run():
 var arena:=Node3D.new();root.add_child(arena)
 var gulper:=QuibletActor3D.new();gulper.setup(GameData.make_quiblet(20,10));arena.add_child(gulper);gulper.set_physics_process(false)
 var tumblet:=QuibletActor3D.new();tumblet.setup(GameData.make_quiblet(21,10),true);arena.add_child(tumblet);tumblet.set_physics_process(false);tumblet.position=Vector3(1,0,0);tumblet.max_hp=10000;tumblet.current_hp=10000
 assert(GameData.species(20).shape=="sphere" and GameData.species(21).shape=="sphere")
 assert(not gulper.model.has_node("PitcherLid") and not tumblet.model.has_node("PillbugBody"))
 assert(tumblet.bonus_value("knockback")==.5 and tumblet.speed<gulper.speed)
 tumblet.model.animate_species_move("Rollout",.2,0)
 tumblet.model.animate_species_move("Unfurl",.6,.45)
 for index in [20,21]:
  assert(GameData.learnset(index).size()==10)
  assert(GameData.RECIPES.any(func(recipe):return recipe.pool.has(index)))
  for name in GameData.learnset(index):assert(GameData.MOVES.has(name) and MoveBehaviors.PROFILES.has(name))
 for name in ["Dribble","Rockslide","Pebble Spray","Stone Skip","Pound"]:
  var cast:=CAST.new();cast.setup(gulper,{"name":name,"stones":[],"slots":0},tumblet,1.0,false);arena.add_child(cast);cast.set_physics_process(false)
  if name=="Dribble":assert(cast.patches.size()==5 and cast.patches[0].pos!=cast.patches[1].pos)
  if name=="Rockslide":assert(cast.shots.size()==5)
  if name=="Pebble Spray":assert(cast.shots.size()==7)
  if name=="Pound":
   cast.profile.status_chance=1.0;cast._physics_process(.85);assert(tumblet.statuses.has("stun"))
  if name=="Stone Skip":
   var hits:=0;var hp:=tumblet.current_hp
   for i in 30:
    cast._physics_process(1.0/60)
    if tumblet.current_hp<hp:hits+=1;hp=tumblet.current_hp
   assert(hits>=2,"Skipping rock must damage the same enemy repeatedly")
  cast.finish(false)
 arena.queue_free();await process_frame
 print("Gulper/Tumblet models, stats, recruitment, learnsets, volleys, puddles, paralysis and repeated hits passed")
 quit()
