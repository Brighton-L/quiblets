extends SceneTree
const S=preload("res://scripts/move_slots.gd")
var failures:=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;push_error(message)
func fixture(counts:Array)->Dictionary:
 var q:=GameData.make_quiblet(7,25);q.moves=[]
 for i in counts.size():q.moves.append({"name":["Flare","Fireball","Flame Dash","Flame Wave"][i],"slots":counts[i],"stones":[]})
 S.ensure(q);return q
func _initialize():call_deferred("run")
func run():
 var q:=fixture([1,5,5])
 var original:String=q.moves[1].move_id
 for i in 4:check(S.transfer(q,1,0,0),"Four incoming slots allowed")
 check(q.moves[0].slots==5 and S.transferred(q.moves[0])==4,"Home one + four incoming = five")
 check(not S.transfer(q,2,0,0),"Fifth transferred slot rejected")
 check(not S.transfer(q,1,2,0),"Cannot transfer donor's last slot")
 check(q.moves[0].slot_data[1].origin==S.NATIVE and q.moves[0].slot_data[1].home_move_id==original,"Transfers preserve origin/home")
 check(S.transfer(q,0,1,1),"Return a slot home")
 check(S.transferred(q.moves[1])==0,"Returned slot is home again")
 check(S.add_slot(q,0,S.CRYSTAL),"Crystal adds permanent home capacity")
 var crystal:Dictionary=q.moves[0].slot_data.back().duplicate(true)
 check(S.transfer(q,0,2,int(q.moves[0].slots)-1),"Crystal slots transfer")
 check(q.moves[2].slot_data.back().origin==S.CRYSTAL and q.moves[2].slot_data.back().home_move_id==crystal.home_move_id,"Transferred crystal retains origin")
 var quoted:=S.quote(q,[[2,int(q.moves[2].slots)-1]])
 check(quoted.total==1 and quoted.created==0,"Transferred crystal refunds 1:1")
 var result:=S.extract(q,[[2,int(q.moves[2].slots)-1]])
 check(result.total==1 and not q.has("skipped_development_rolls"),"Refund does not skip development")
 q=fixture([1,1,1]);var before:=q.duplicate(true)
 check(S.extract(q,[[0,0]]).error!="" and q==before,"Odd selection rejected without mutation")
 check(S.extract(q,[[0,0],[0,0]]).error!="" and q==before,"Duplicate selection rejected")
 result=S.extract(q,[[0,0],[1,0]])
 check(result.created==1 and q.moves[0].slots==0 and q.moves[1].slots==0 and not q.has("skipped_development_rolls"),"Cross-move Native pair creates crystal and zero-slot moves")
 for i in 5:S.add_slot(q,2,S.NATIVE)
 for i in 4:check(S.transfer(q,2,0,0),"Zero-home move can receive four slots")
 check(not S.transfer(q,2,0,0),"Zero-home move capped at four incoming")
 result=S.extract(q,[[0,0],[0,1]])
 check(result.created==1,"Transferred Native slots remain eligible")
 q=fixture([7,0,0])
 for i in 3:S.add_slot(q,1,S.CRYSTAL)
 result=S.extract(q,S.all_slots(q),true)
 check(result.total==6 and result.created==3 and result.refunds==3 and result.unused_native==1,"Full extraction: seven Native + three Crystal yields six")
 check(S.extract(q,S.all_slots(q),true).total==0,"Extraction cannot be repeated for profit")
 q=fixture([7,1,1]);check(S.add_slot(q,0,S.CRYSTAL),"Eighth home slot allowed")
 check(not S.add_slot(q,0,S.CRYSTAL) and not S.transfer(q,1,0,0),"Eight-slot hard cap")
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 check(game.save_access_blocked(),"Tests must never access player saves")
 q=fixture([2,2,1]);game.roster=[q,fixture([1,1,1])];game.selected_roster=0;game.team_indices.clear();game.team_indices.append(0)
 q.moves[0].stones=["link:Fireball","heavy"];q.moves[1].stones=["link_from:Flare"]
 game.move_stone_inventory.clear();game.special_items["Move Crystal"]=0
 result=game.extract_move_slots(q,[[0,0],[1,0]])
 check(result.total==1 and game.special_items["Move Crystal"]==1,"Crystallization returns existing special item")
 check(game.move_stone_inventory.get("link",0)==1 and q.moves[0].stones==["heavy"],"Paired Link refunded once; remaining equipment stays")
 var snapshot:Array=q.moves.duplicate(true);q.prodigy=true;q.skipped_development_rolls=3;game.apply_milestone(q)
 check(not q.has("skipped_development_rolls") and not q.prodigy and q.moves!=snapshot,"Legacy roll penalties are discarded; development and Prodigy proceed normally")
 game.item_use={"move_index":0};game.apply_quiblet_item("Move Crystal",q)
 check(q.moves[0].slot_data.back().origin==S.CRYSTAL,"Move Crystal creates Crystal origin")
 var move_id:String=q.moves[0].move_id;q.moves[0].name="Flame Pillar";S.ensure(q)
 check(q.moves[0].move_id==move_id,"Retraining preserves stable home identity")
 var saved:Dictionary=game.save_data();var expected:Dictionary=q.duplicate(true)
 game.apply_save_data(JSON.parse_string(JSON.stringify(saved)))
 check(game.roster[0].moves==expected.moves and not game.roster[0].has("skipped_development_rolls"),"Slot metadata survives JSON save/load in memory")
 game.selected_roster=0;game.show_quiblet_edit();game.show_move_slot_manager();await process_frame
 check(game.content.find_child("MoveSlotManager",true,false)!=null,"Slot management UI opens")
 check(game.content.find_child("ExtractSelectedMoveSlots",true,false)==null,"Edit menu offers transfers only")
 game.show_stone_workshop();check(game.content.find_child("OpenCrystallization",true,false)!=null,"Crystallization entry is in Stone Workshop")
 game.show_move_slot_manager();game.move_slot_selection=[[0,0],[1,0]];game.show_move_slot_manager(false);game.confirm_move_slot_extraction();await process_frame
 check(game.content.find_child("ConfirmMoveSlotExtraction",true,false)!=null,"Destructive action requires confirmation")
 var before_confirmation:int=game.special_items["Move Crystal"]
 game.content.find_child("ConfirmMoveSlotExtraction",true,false).pressed.emit();await process_frame
 check(game.special_items["Move Crystal"]==before_confirmation+1 and game.screen=="stone_workshop","Confirmation awards crystals and returns to workshop")
 var helper:=fixture([7,0,0]);for i in 3:S.add_slot(helper,1,S.CRYSTAL)
 helper.moves[0].stones=["echo"];game.roster.append(helper)
 var crystals_before:int=game.special_items["Move Crystal"]
 game.remove_roster_member(game.roster.size()-1)
 check(game.special_items["Move Crystal"]==crystals_before+6 and game.move_stone_inventory.get("echo",0)>=1,"Removal refunds equipment plus Native/Crystal slot value")
 game.queue_free();await process_frame
 print("MOVE_SLOT_ORIGINS failures=",failures)
 quit(0 if failures==0 else 1)
