extends SceneTree
var failures:=0
func check(value:bool,message:String)->void:
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 check(game.save_access_blocked(),"Tests must block saves")
 game.selected_roster=0
 var q:Dictionary=game.roster[0]
 q.erase("charm_slots");q.health_charms=2;q.attack_charms=1;q.flex_health=1;q.flex_attack=1
 game.ensure_charm_slots(q)
 check(q.charm_slots==["Health","Health","","Attack","","","Health","Attack",""],"Existing equipped bonuses must be preserved")
 game.special_items["Health Charm"]=2;game.special_items["Attack Charm"]=2
 game.show_quiblet_edit()
 var board=game.content.find_child("CharmSlots",true,false)
 check(board!=null and board.find_children("CharmSlot*","TextureRect",false,false).size()==9,"Nine charm slots")
 check(game.content.find_child("StoneTabCharms",true,false)!=null,"Owned charms show inventory section")
 var health=game.content.find_child("CharmSlot2",true,false)
 check(health._can_drop_data(Vector2.ZERO,game.charm_inventory_data("Health")),"Health accepts health")
 check(not health._can_drop_data(Vector2.ZERO,game.charm_inventory_data("Attack")),"Health rejects attack")
 check(not health._can_drop_data(Vector2.ZERO,{"kind":"power_stone","stone_type":"Health"}),"Charm slot rejects stones")
 game.equip_stone_from_inventory("charm",2,-1,game.charm_inventory_data("Health"))
 check(q.health_charms==3 and game.special_items["Health Charm"]==1,"Equip updates bonus and inventory")
 game.equip_stone_from_inventory("charm",8,-1,game.charm_inventory_data("Attack"))
 check(q.flex_attack==2,"Flex accepts attack")
 game.equip_stone_from_inventory("charm",8,-1,game.charm_inventory_data("Health"))
 check(q.flex_attack==1 and q.flex_health==2 and game.special_items["Attack Charm"]==2,"Replacing returns old charm")
 var drag:Dictionary=game.take_equipment_for_drag("charm",2,-1)
 check(drag.kind=="charm" and q.health_charms==2 and game.special_items["Health Charm"]==1,"Dragging out returns charm and removes bonus")
 game.finish_equipment_drag()
 check(q.charm_slots[2]=="","Dropped outside stays unequipped")
 var snapshot:Dictionary=game.save_data()
 game.apply_save_data(snapshot)
 check(game.roster[0].charm_slots[2]=="" and game.roster[0].flex_health==2,"In-memory serialization preserves slot positions")
 game.special_items["Health Charm"]=0;game.special_items["Attack Charm"]=0;game.stone_inventory_tab="Charms";game.show_quiblet_edit()
 check(game.content.find_child("StoneTabCharms",true,false)==null,"No loose charms hides section")
 print("Charm equipment checks: ",failures," failures")
 game.queue_free();await process_frame;quit(1 if failures else 0)
