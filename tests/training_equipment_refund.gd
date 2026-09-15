extends SceneTree
var failures:=0
func check(value:bool,message:String)->void:
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 check(game.save_access_blocked(),"Save access must stay blocked")
 var helper:=GameData.make_quiblet(0,6)
 helper.moves=[{"name":"Water Shot","slots":3,"stones":["echo","link:Water Burst",""]},{"name":"Water Burst","slots":2,"stones":["link_from:Water Shot","heavy"]}]
 var stone:=GameData.make_power_stone("Health",2,[])
 helper.power_slot_stones=[stone.duplicate(true)]
 helper.health_charms=3;helper.attack_charms=2;helper.flex_health=1;helper.flex_attack=2
 var before_echo:=int(game.move_stone_inventory.get("echo",0));var before_link:=int(game.move_stone_inventory.get("link",0));var before_heavy:=int(game.move_stone_inventory.get("heavy",0))
 var before_power:int=game.power_stone_inventory.size();var before_health:int=game.special_items["Health Charm"];var before_attack:int=game.special_items["Attack Charm"]
 game.roster.append(helper);game.training_trainee=0;game.training_helpers.assign([game.roster.size()-1,-1,-1,-1]);game.training_foods.assign(["",""]);game.training_mode="exp"
 game.run_training()
 check(game.find_roster_index(helper.uid)==-1,"Helper consumed without food")
 check(game.move_stone_inventory.echo==before_echo+1 and game.move_stone_inventory.heavy==before_heavy+1,"All regular Move Stones refunded")
 check(game.move_stone_inventory.link==before_link+1,"Paired Link Stone refunded exactly once")
 check(game.power_stone_inventory.size()==before_power+1 and game.power_stone_inventory.back()==stone,"Power Stone returned with original stats")
 check(game.special_items["Health Charm"]==before_health+4 and game.special_items["Attack Charm"]==before_attack+4,"Dedicated and flex charms refunded")
 game.refund_helper_equipment(helper)
 check(game.move_stone_inventory.link==before_link+1 and game.power_stone_inventory.size()==before_power+1 and game.special_items["Health Charm"]==before_health+4,"Refund cannot duplicate equipment")
 print("Training equipment refund checks: ",failures," failures")
 game.queue_free();await process_frame;quit(1 if failures else 0)
