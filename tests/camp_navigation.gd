extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(3).timeout
 assert(game.save_access_blocked())
 for state in ["empty","cooking","ready"]:
  game.pending_stew={"expeditions_required":3,"expeditions_remaining":1} if state=="cooking" else {}
  game.completed_stew_result={"recipe":"Test"} if state=="ready" else {}
  game.show_map();await process_frame
  var nav=game.content.get_node("CampNavigation")
  assert(nav.button.text=="BASE CAMP  ›" and nav.button.global_position==Vector2(995,620))
  assert(game.content.find_child("BackButton",true,false)==null)
  assert((nav.find_child("StatusPotLid",true,false)!=null)==(state=="cooking"))
  assert((nav.find_child("PotReadyBadge",true,false)!=null)==(state=="ready"))
  if state=="cooking":assert(nav.find_child("PotExpeditionCount",true,false).text=="2/3")
  assert(game.content.get_node_or_null("MenuLayout")==null)
  nav.button.pressed.emit();assert(game.screen=="camp")
 game.pending_stew={};game.completed_stew_result={}
 game.show_quiblet_edit();await process_frame
 assert(game.content.find_child("CharmSlots",true,false)!=null)
 game.show_area_levels(0);await process_frame
 assert(game.content.get_node_or_null("CampNavigation")==null)
 var back=game.content.find_child("BackButton",true,false)
 assert(back!=null and back.global_position==game.BACK_BUTTON_POSITION)
 back.pressed.emit();assert(game.screen=="map")
 game.show_team();await process_frame
 assert(game.content.get_node_or_null("CampNavigation")==null and game.content.get_node_or_null("MenuLayout")==null)
 assert(game.content.find_child("BackButton",true,false)!=null)
 print("Camp navigation and all pot states passed")
 game.queue_free();await process_frame;quit()
