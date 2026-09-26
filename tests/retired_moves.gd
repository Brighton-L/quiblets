extends SceneTree
func _initialize():
 for name in GameData.MOVES:assert(not name.to_lower().contains("bubble"))
 for learnset in GameData.LEARNSETS:
  assert(learnset.size()==learnset.duplicate().reduce(func(unique,name):
   if not unique.has(name):unique.append(name)
   return unique,[]).size())
  for name in learnset:assert(GameData.MOVES.has(name) and not name.to_lower().contains("bubble"))
 assert(GameData.learnset(0).has("Water Jet"))
 var q:=GameData.make_quiblet(0,6)
 q.moves=[{"name":"Water Jet","slots":2,"stones":["link:Bubble Shot"]},{"name":"Bubble Shot","slots":3,"stones":["link_from:Water Jet","echo"]},{"name":"Bubble Shield","slots":1,"stones":["sharing"]}]
 q.memory=["Bubble Shot","Bubble Shield","Bubble Trap"]
 GameData.replace_retired_moves(q)
 assert(q.moves[0].name!=q.moves[1].name)
 assert(q.moves[0].stones[0]=="link:"+q.moves[1].name)
 assert(q.moves[1].slots==3 and q.moves[1].stones==["link_from:Water Jet","echo"])
 assert(q.moves[2].name=="Guard" and q.moves[2].stones==["sharing"])
 for name in q.memory:assert(GameData.MOVES.has(name) and not name.contains("Bubble"))
 assert(not GameData.MOVES.has("Fire Trail"))
 for learnset in GameData.LEARNSETS:assert(not learnset.has("Fire Trail"))
 var fire:=GameData.make_quiblet(7,6)
 fire.moves=[{"name":"Fire Trail","slots":3,"stones":["echo","heavy"]}];fire.memory=["Fire Trail"]
 GameData.replace_retired_moves(fire)
 assert(fire.moves[0].name=="Flame Dash" and fire.moves[0].slots==3 and fire.moves[0].stones==["echo","heavy"] and fire.memory==["Flame Dash"])
 assert(not GameData.MOVES.has("Combust"))
 for learnset in GameData.LEARNSETS:assert(not learnset.has("Combust"))
 assert(GameData.learnset(7).has("Meteor Ember"))
 fire.moves=[{"name":"Combust","slots":2,"stones":["echo"]}];fire.memory=["Combust"]
 GameData.replace_retired_moves(fire)
 assert(fire.moves[0].name=="Meteor Ember" and fire.moves[0].slots==2 and fire.moves[0].stones==["echo"] and fire.memory==["Meteor Ember"])
 var species_by_old:={"Hunker Down":12,"Distract":13,"Double Honk":19,"Shock Clamp":26,"Puff Grab":9,"Blazing Rush":7}
 for old in GameData.RETIRED_CONSOLIDATED_MOVES:
  var replacement:String=GameData.RETIRED_CONSOLIDATED_MOVES[old]
  assert(not GameData.MOVES.has(old) and not MoveBehaviors.PROFILES.has(old))
  for learnset in GameData.LEARNSETS:assert(not learnset.has(old))
  assert(GameData.learnset(species_by_old[old]).count(replacement)==1)
  for already_equipped in [false,true]:
   var fixture:Dictionary={"species":species_by_old[old],"moves":[{"name":old,"slots":3,"stones":["echo","link_from:"+replacement]},{"name":replacement if already_equipped else "Water Shot","slots":2,"stones":["link:"+old]}],"memory":[old,replacement]}
   GameData.replace_retired_moves(fixture)
   assert(fixture.moves[0].name!=fixture.moves[1].name)
   assert(GameData.MOVES.has(fixture.moves[0].name))
   if not already_equipped:assert(fixture.moves[0].name==replacement)
   assert(fixture.moves[0].slots==3 and fixture.moves[0].stones==["echo","link_from:"+replacement])
   assert(fixture.moves[1].stones==["link:"+fixture.moves[0].name])
   assert(not fixture.memory.has(old))
   var once:Dictionary=fixture.duplicate(true)
   GameData.replace_retired_moves(fixture)
   assert(fixture==once,"Move conversion must be idempotent")
 print("Retired moves, unique learnsets, memory, duplicate handling and fitted Link Stones passed")
 quit()
