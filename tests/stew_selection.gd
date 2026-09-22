extends SceneTree
var pots:=0
var winners:={}
var better_fit_over_priority:=false
var specificity_over_priority:=false
func _initialize():
 assert(GameData.RECIPES.size()==16)
 assert(GameData.choose_recipe({"Bumbleberry":4}).name=="Plain Stew")
 for recipe in GameData.RECIPES:
  assert(not recipe.pool.is_empty())
  for id in GameData.SPECIES.size():
   var eligible:bool=recipe.attraction_kind=="any" or (recipe.attraction_kind=="type" and GameData.species_types(id).has(recipe.attraction_target)) or (recipe.attraction_kind=="color" and GameData.RECIPE_COLOR_GROUPS[recipe.attraction_target].has(id))
   assert(recipe.pool.has(id)==eligible,"Incorrect recruitment pool: "+recipe.name)
 visit({},0,5)
 assert(winners.size()==GameData.RECIPES.size())
 assert(better_fit_over_priority and specificity_over_priority)
 print("Checked ",pots," five-ingredient pots: all stews reachable; specificity, relevant excess and hidden priority ordering passed")
 quit()
func visit(pot:Dictionary,start:int,left:int):
 if left==0:
  verify(pot);return
 var names:=GameData.INGREDIENTS.keys()
 for i in range(start,names.size()):
  var name:String=names[i];pot[name]=int(pot.get(name,0))+1
  visit(pot,i,left-1)
  pot[name]-=1
  if pot[name]==0:pot.erase(name)
func verify(pot:Dictionary):
 pots+=1
 var tags:=GameData.tags_for_ingredients(pot)
 var matches:Array=[]
 for recipe in GameData.RECIPES:
  if recipe.need.is_empty():continue
  var valid:=true;var specificity:=0;var excess:=0
  for tag in recipe.need:
   valid=valid and tags.get(tag,0)>=recipe.need[tag]
   specificity+=recipe.need[tag];excess+=int(tags.get(tag,0))-recipe.need[tag]
  if valid:matches.append({"recipe":recipe,"specificity":specificity,"excess":excess})
 matches.sort_custom(func(a,b):
  if a.specificity!=b.specificity:return a.specificity>b.specificity
  if a.excess!=b.excess:return a.excess<b.excess
  return a.recipe.priority>b.recipe.priority)
 var expected:String="Plain Stew" if matches.is_empty() else str(matches[0].recipe.name)
 assert(GameData.choose_recipe(pot).name==expected,str(pot))
 winners[expected]=true
 if matches.size()>1:
  var top:Dictionary=matches[0]
  for other in matches.slice(1):
   if top.recipe.priority<other.recipe.priority:
    if top.specificity>other.specificity:specificity_over_priority=true
    elif top.excess<other.excess:better_fit_over_priority=true
