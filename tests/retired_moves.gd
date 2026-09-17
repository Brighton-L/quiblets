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
 print("Retired moves, learnsets, memory and fitted Link Stones passed")
 quit()
