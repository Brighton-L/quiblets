extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 game.move_stone_inventory.clear();game.move_stone_inventory.heavy=2
 game.roster.clear();game.roster.append(GameData.make_quiblet(0,5));game.roster.append(GameData.make_quiblet(2,5))
 game.roster[1].moves[0].stones=["echo","link:Leaf Shot"]
 game.roster[1].moves[1].stones=["link_from:Water Shot"]
 game.special_items["Echo Crystal"]=3
 game.show_item_use("Echo Crystal");await process_frame
 assert(game.item_use.roster_index==-1 and game.echo_crystal_stones().link==1)
 assert(game.content.find_child("EchoStoneChoice_heavy",true,false)!=null)
 assert(game.content.find_child("EchoStoneChoice_echo",true,false)!=null)
 assert(game.content.find_child("EchoStoneChoice_rush",true,false)==null)
 game.content.find_child("EchoStoneChoice_heavy",true,false).pressed.emit();await process_frame
 assert(game.item_use_problem()=="")
 game.apply_item_use();await process_frame
 assert(game.move_stone_inventory.heavy==3 and game.special_items["Echo Crystal"]==2)
 var fitted=game.roster[1].moves.duplicate(true)
 game.item_use.stone_value="echo";game.apply_item_use();await process_frame
 assert(game.move_stone_inventory.echo==1 and game.roster[1].moves==fitted and game.special_items["Echo Crystal"]==1)
 game.item_use.stone_value="heavy";game.move_stone_inventory.heavy=0
 assert(game.item_use_problem()!="")
 game.apply_item_use();assert(game.special_items["Echo Crystal"]==1)
 game.item_use.stone_value="made_up";assert(game.item_use_problem()!="")
 print("Echo Crystal: loose/fitted selection, no Quiblet required, exact consumption, original preservation, Link counting and stale selection passed")
 game.queue_free();await process_frame;quit()
