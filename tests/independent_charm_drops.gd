extends SceneTree
func _initialize():call_deferred("run")
func run():
 var rng:=RandomNumberGenerator.new();rng.seed=622
 for source in ["enemy","level","boss","berry_grove","cache"]:
  for fortune in [false,true]:
   var counts:={"Attack Charm":0,"Health Charm":0,"Combiner Charm":0};var multiple:=0
   for i in 30000:
    var drops:=GameData.roll_drop_charms(source,fortune,rng)
    if drops.size()>1:multiple+=1
    for item in drops:counts[item]+=1
   for item in counts:
    assert(not GameData.SPECIAL_ITEM_DROP_WEIGHTS.has(item))
    assert(absf(counts[item]/30000.0-GameData.charm_drop_chance(item,source,fortune))<.012)
   assert(counts["Combiner Charm"]<counts["Attack Charm"] and counts["Combiner Charm"]<counts["Health Charm"])
   assert(multiple>0,"Charm rolls must permit multiple charms together")
 # Exercise all award paths with a failed rare-special roll and successful charms.
 for source in ["enemy","level","boss","cache"]:
  var chosen_seed:=0;var expected:Array[String]=[]
  while true:
   seed(chosen_seed)
   var special:=GameData.roll_special_item(source,false)
   expected=GameData.roll_drop_charms(source,false)
   if special=="" and not expected.is_empty():break
   chosen_seed+=1
  var field:=Expedition3D.new();root.add_child(field);field.set_process(false)
  for ingredient in GameData.INGREDIENTS:field.loot[ingredient]=0
  var rewards:Array=[];field.reward_acquired.connect(func(reward,_pos):rewards.append(reward))
  if source=="enemy":
   var foe:=QuibletActor3D.new();foe.setup(GameData.make_quiblet(0,5),true);field.add_child(foe);foe.set_physics_process(false);field.enemies.append(foe)
   seed(chosen_seed);field._on_actor_defeated(foe)
   assert(field.extra_specials==expected)
   assert(rewards.filter(func(r):return r.kind=="special").size()==expected.size())
   field._on_actor_defeated(foe);assert(field.extra_specials==expected)
  elif source=="cache":
   # The cache and enemy share this independent awarding helper.
   seed(chosen_seed);assert(GameData.roll_special_item(source,false)=="")
   field.award_drop_charms(source,Vector3.ZERO)
   assert(field.extra_specials==expected and rewards.size()==expected.size())
  else:
   field.stage_kind=source
   var results:Array=[];field.expedition_finished.connect(func(result):results.append(result))
   seed(chosen_seed);field.finish(true)
   assert(results.size()==1 and results[0].special=="")
   for item in expected:assert(results[0].extra_specials.has(item))
  field.free();await process_frame
 print("INDEPENDENT_CHARM_DROPS_OK: all rates, Fortune, rarity ordering, independent rewards and multi-drops")
 quit()
