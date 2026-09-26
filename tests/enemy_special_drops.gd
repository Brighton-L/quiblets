extends SceneTree
func _initialize():call_deferred("run")
func run():
 var rng:=RandomNumberGenerator.new();rng.seed=507
 for entry in [["level",false,.12],["boss",false,.25],["berry_grove",false,.12],["level",true,.60],["boss",true,.60],["enemy",false,.01],["enemy",true,.03],["cache",false,.08],["cache",true,.48]]:
  assert(is_equal_approx(GameData.special_item_drop_chance(entry[0],entry[1]),entry[2]))
  var drops:=0
  for i in 20000:
   var item:=GameData.roll_special_item(entry[0],entry[1],rng)
   if item!="":
    assert(GameData.SPECIAL_ITEM_DROP_WEIGHTS.has(item) and item!="Treasure Key")
    drops+=1
  assert(absf(drops/20000.0-entry[2])<.015)
 var field:=Expedition3D.new();root.add_child(field);field.set_process(false)
 for ingredient in GameData.INGREDIENTS:field.loot[ingredient]=0
 var rewards:Array=[];field.reward_acquired.connect(func(reward,_pos):rewards.append(reward))
 # Find a deterministic successful roll, then exercise the actual death path.
 var successful_seed:=0
 while true:
  seed(successful_seed)
  if randf()<.01:break
  successful_seed+=1
 var foe:=QuibletActor3D.new();foe.setup(GameData.make_quiblet(0,5),true);field.add_child(foe);foe.set_physics_process(false);field.enemies.append(foe)
 seed(successful_seed);field._on_actor_defeated(foe)
 assert(field.extra_specials.size()>=1 and rewards.filter(func(r):return r.kind=="special").size()==field.extra_specials.size())
 var reward_count:=rewards.size();field._on_actor_defeated(foe)
 assert(rewards.size()==reward_count,"A repeated defeat notification cannot duplicate loot")
 var results:Array=[];field.expedition_finished.connect(func(result):results.append(result))
 field.finish(false)
 assert(results.size()==1 and results[0].special=="" and results[0].extra_specials==field.extra_specials,"Enemy loot is retained without granting a loss a clear roll")
 field.free();await process_frame
 print("ENEMY_SPECIAL_DROPS_OK: rates, weighted pool, enemy rewards, duplicate protection and results")
 quit()
