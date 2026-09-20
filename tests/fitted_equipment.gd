extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.selected_roster=0
 var q:Dictionary=game.roster[0];game.ensure_quiblet_equipment(q)
 q.moves[0].stones=["heavy"];q.charm_slots[0]="Health";q.charm_slots[3]="Attack"
 game.special_items["Health Charm"]=0;game.special_items["Attack Charm"]=0
 for effect in game.move_stone_inventory:game.move_stone_inventory[effect]=0
 var moves:Array=game.all_move_stone_entries();var charms:Array=game.all_charm_entries()
 assert(moves.size()==1 and charms.size()==2)
 for entry in moves+charms:
  assert(entry.fitted and entry.roster_index==0 and entry.owner==GameData.display_name(q))
  game.stone_inventory_tab="Moves" if entry.kind=="move_stone" else "Charms"
  game.selected_inventory_item=entry;game.show_quiblet_edit()
  assert(game.content.find_child("FittedStoneNote",true,false)!=null)
  assert(game.content.find_child("StoneTabCharms",true,false)!=null)
  var cards=game.content.find_children("StoneInventoryCard*","Panel",true,false)
  assert(not cards.is_empty())
  for card in cards:
   assert(card.get_node_or_null("FittedOwnerBadge")!=null and card.get_node_or_null("FittedStoneIcon")!=null)
   assert(card._get_drag_data(Vector2.ZERO)==null)
 game.move_stone_inventory.heavy=1;assert(game.all_move_stone_entries().size()==2)
 game.special_items["Health Charm"]=1;assert(game.all_charm_entries().size()==3)
 game.equip_stone_from_inventory("charm",1,-1,charms[0]);assert(q.charm_slots[1]=="" and game.special_items["Health Charm"]==1)
 game.inspect_equipment("charm",0,-1);assert(game.selected_inventory_item.fitted)
 game.inspect_equipment("move",0,0);assert(game.selected_inventory_item.fitted)
 game.queue_free();await process_frame
 print("Equipped move stones and charms show owner badges and notes, remain listed, and cannot be dragged from inventory")
 quit()
