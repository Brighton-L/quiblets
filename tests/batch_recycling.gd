extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 game.power_stone_inventory.clear()
 for i in 16:game.power_stone_inventory.append(GameData.make_power_stone("Health" if i%2==0 else "Attack",1,[]))
 game.show_quiblet_edit();game.show_power_stone_recycler()
 var picker=game.content.get_node("PowerStoneRecycler")
 for i in 16:picker.find_child("RecycleCandidate%d"%i,true,false).button_pressed=true
 assert(picker.selected.size()==15 and game.power_stone_inventory.size()==16)
 picker.confirm.pressed.emit()
 assert(game.power_stone_inventory.size()==16)
 game.content.find_child("CancelRecycleConfirmation",true,false).pressed.emit();await process_frame
 assert(game.power_stone_inventory.size()==16 and picker.selected.size()==15)
 var total:=0
 for stone in picker.selected.values():total+=game.power_stone_recycle_count(stone)
 var before:int=game.ingredients.values().reduce(func(a,b):return a+int(b),0)
 picker.confirm.pressed.emit();game.content.find_child("ConfirmRecycleBatch",true,false).pressed.emit()
 assert(game.power_stone_inventory.size()==1)
 var after:int=game.ingredients.values().reduce(func(a,b):return a+int(b),0)
 assert(after-before==total)
 assert(not game.recycle_batch_valid({0:{"type":"Attack","power":-1}}))
 print("Batch selection limit, cancellation, confirmation and rewards passed")
 game.queue_free();await process_frame;quit()
