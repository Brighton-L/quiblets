extends SceneTree
var arena:Node3D
var actor:QuibletActor3D
var victim:QuibletActor3D
func _initialize():call_deferred("run")
func fixture(move:String)->void:
 if is_instance_valid(arena):arena.free()
 arena=Node3D.new();root.add_child(arena)
 actor=QuibletActor3D.new();actor.setup(GameData.make_quiblet(0,10));arena.add_child(actor);actor.set_physics_process(false)
 victim=QuibletActor3D.new();victim.setup(GameData.make_quiblet(0,10),true);arena.add_child(victim);victim.set_physics_process(false)
 actor.data.moves=[{"name":move,"slots":0,"stones":[]}];actor.move_cooldowns=[0.0];actor.move_cooldown_totals=[0.0]
func run():
 for move in GameData.MOVES:
  for scenario in ["near","far","no_target","stunned","rooted","busy"]:
   fixture(move);victim.position=Vector3(1,0,0)
   if scenario=="far":victim.position.x=30
   if scenario=="no_target":victim.current_hp=0
   if scenario=="stunned":actor.add_status("stun",5,1,victim)
   if scenario=="rooted":actor.add_status("root",5,1,victim)
   if scenario=="busy":actor.motion_lock=1
   actor.request_move(0,null if scenario=="no_target" else victim)
   assert(actor.move_cooldowns[0]>0,"Immediate activation failed: %s / %s"%[move,scenario])
   var cast=arena.get_child(arena.get_child_count()-1)
   assert(cast.get("move_name")==move and not cast.done,"Move vanished: %s / %s"%[move,scenario])
   assert(float(cast.profile.get("delay",0))==0)
   var count:=arena.get_child_count();actor.request_move(0,victim);assert(arena.get_child_count()==count,"Cooldown was bypassed")
 fixture("Water Shot");actor.current_hp=0;actor.request_move(0,victim);assert(actor.move_cooldowns[0]==0)
 arena.free();await process_frame
 print("All 212 moves activate immediately near/far/without targets and while locked; cooldowns and knockout still respected")
 quit()
