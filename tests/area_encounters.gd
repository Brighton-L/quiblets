extends SceneTree
func _initialize():
 assert(GameData.AREA_ENCOUNTER_TYPES.size()==GameData.EXPEDITION_AREAS.size())
 for area in GameData.EXPEDITION_AREAS.size():
  var rng:=RandomNumberGenerator.new();rng.seed=9000+area
  var matching:=0;var seen:={}
  var type:=GameData.area_encounter_type(area)
  for roll in 10000:
   var species:=GameData.roll_area_species(area,rng)
   assert(species>=0 and species<GameData.SPECIES.size())
   if GameData.species_types(species).has(type):matching+=1
   seen[species]=true
  assert(matching>7700 and matching<8300,"Region must strongly favor its specialty but retain visitors")
  assert(seen.size()==GameData.SPECIES.size(),"All species should remain possible in the regional mix")
  for roll in 100:
   assert(GameData.species_types(GameData.roll_area_species(area,rng,true)).has(type),"Boss must match the area")
  print(GameData.EXPEDITION_AREAS[area],": ",type," ",matching/100.0,"%")
 print("Regional encounters: all 20 areas, mixed species, dual types and themed bosses passed")
 quit()
