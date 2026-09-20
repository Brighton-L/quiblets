extends SceneTree
const NEW_TAGS:={"Puckerpear":["bitter","sour","spicy","juicy","fruit"],"Twinplum":["sweet","sour","juicy","fruit"],"Splitcap":["bitter","sour","hard","plant"],"Mudtruffle":["earthy","savory","salty","soft","fungus"],"Crinkleberry":["sweet","spicy","soft","fruit"]}
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 for ingredient in NEW_TAGS:
  var info:Dictionary=GameData.INGREDIENTS[ingredient]
  assert(info.tier==4 and info.tags==NEW_TAGS[ingredient])
  assert(GameData.ingredient_texture(info)!=null)
  assert(is_equal_approx(GameData.ingredient_drop_weight(ingredient,24),.05) and is_equal_approx(GameData.ingredient_drop_weight(ingredient,1),.002))
  assert(game.ingredients[ingredient]==0)
  game.grant_ingredient(ingredient,7)
 var saved:Dictionary=game.save_data();game.apply_save_data(saved)
 for ingredient in NEW_TAGS:assert(game.ingredients[ingredient]==7 and game.unlocked_ingredients.has(ingredient))
 for view in [["show_cooking","CookingIngredientGrid"],["show_spice_workshop","SpiceIngredientGrid"],["show_resources","ResourceIngredientGrid"],["show_training","TrainingIngredientGrid"]]:
  game.call(view[0]);await process_frame
  var grid=game.content.find_child(view[1],true,false)
  assert(grid.get_child_count()==21)
  assert(grid.columns==7)
  assert(game.content.find_child(view[1]+"Scroll",true,false)==null)
  var parent_rect:Rect2=grid.get_parent().get_global_rect()
  for card in grid.get_children():
   assert(parent_rect.encloses(card.get_global_rect()),"Every ingredient must fit within its panel without scrolling")
 var expedition:=Expedition3D.new()
 for ingredient in NEW_TAGS:
  var patch:=Node3D.new();expedition.build_berry_patch_shape(patch,ingredient)
  assert(patch.get_child_count()>0);patch.free()
 expedition.free()
 print("Tier-4 tags, textures, drops, in-memory inventory, all four three-row menus and plant models passed")
 game.queue_free();await process_frame;quit()
