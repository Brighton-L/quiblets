extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 game.power_stone_inventory.clear()
 for i in 16:game.power_stone_inventory.append(GameData.make_power_stone("Health" if i%2==0 else "Attack",1,[]))
 game.show_quiblet_edit();game.show_power_stone_recycler()
 assert(game.content.get_node_or_null("PowerStoneRecycler")==null)
 for i in 16:game.select_inventory_stone(game.power_stone_inventory_data(game.power_stone_inventory[i],i))
 game.stone_inventory_tab="Attack";game.set_stone_page(0)
 assert(game.recycling_stones and game.recycle_selection.size()==15 and game.power_stone_inventory.size()==16)
 var card=game.content.find_child("StoneIconGrid",true,false).get_child(0)
 assert(card.drag_disabled)
 assert(game.content.find_child("StoneTabMoves",true,false)==null)
 game.content.find_child("ReviewBatchRecycle",true,false).pressed.emit()
 assert(game.power_stone_inventory.size()==16)
 game.content.find_child("CancelRecycleConfirmation",true,false).pressed.emit();await process_frame
 assert(game.power_stone_inventory.size()==16 and game.recycle_selection.size()==15)
 var total:=0
 for stone in game.recycle_selection.values():total+=game.power_stone_recycle_count(stone)
 var before:int=game.ingredients.values().reduce(func(a,b):return a+int(b),0)
 game.content.find_child("ReviewBatchRecycle",true,false).pressed.emit();game.content.find_child("ConfirmRecycleBatch",true,false).pressed.emit()
 assert(game.power_stone_inventory.size()==1)
 var after:int=game.ingredients.values().reduce(func(a,b):return a+int(b),0)
 assert(after-before==total)
 var results=game.content.find_child("RecyclingResults",true,false)
 assert(results!=null)
 var rewards:Dictionary=results.get_meta("rewards")
 assert(rewards.values().reduce(func(a,b):return a+int(b),0)==total)
 var rows=results.find_child("RecyclingRewardList",true,false)
 assert(rows.get_child_count()==rewards.size())
 for row in rows.get_children():assert(row.get_meta("amount")==rewards[row.get_meta("ingredient")])
 results.find_child("CloseRecyclingResults",true,false).pressed.emit();await process_frame
 assert(game.content.find_child("RecyclingResults",true,false)==null)
 assert(game.ingredients.values().reduce(func(a,b):return a+int(b),0)==after)
 var recipe:Dictionary=GameData.RECIPES[0]
 game.leftovers[recipe.name]=1
 game.recycle_leftover(recipe)
 assert(game.content.find_child("RecyclingResults",true,false)!=null)
 assert(game.leftovers[recipe.name]==0)
 assert(not game.recycle_batch_valid({0:{"type":"Attack","power":-1}}))
 print("Batch selection limit, cancellation, confirmation and rewards passed")
 game.queue_free();await process_frame;quit()
