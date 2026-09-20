extends SceneTree
const NEW_KINDS:=["tussock","wildflowers","fern","heather","layered_rocks","driftwood","ice_cluster","mushroom_cluster","flowering_shrub","seed_heads","mossy_boulder","stump","succulent","weathered_stone"]
func _initialize():
 var seen:={};var count:=0
 for area in GameData.EXPEDITION_AREAS.size():
  var biome:=GameData.expedition_biome(area)
  assert(biome.decor.any(func(kind):return NEW_KINDS.has(kind)))
  for kind in biome.decor:
   if not NEW_KINDS.has(kind):continue
   seen[kind]=true
   for seed_value in 3:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var prop:=ExpeditionProp3D.new();prop.setup(kind,Vector2i.ZERO,biome,1,rng)
    assert(prop.harvestable() and not prop.harvest_tags().is_empty())
    assert(prop.parts.size()>=5 and prop.parts.size()<40)
    for part in prop.parts:assert(part.mesh!=null and part.position.is_finite())
    var ingredients:=GameData.INGREDIENTS.values().filter(func(info):return info.tags.any(func(tag):return prop.harvest_tags().has(tag)))
    assert(not ingredients.is_empty())
    prop.free();count+=1
 assert(seen.size()==14)
 print("Validated ",count," scenery variants across all 20 areas, with working harvest tags")
 quit()
