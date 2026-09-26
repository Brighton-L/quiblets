extends SceneTree
class StationaryActor extends QuibletActor3D:
 func move_toward_point(_point:Vector3,_delta:float,_steer:=true)->void:pass
func _initialize():call_deferred("run")
func run():
 var arena:=Node3D.new();root.add_child(arena)
 var q:=GameData.make_quiblet(0,50);q.moves=[]
 var foe:=StationaryActor.new();foe.setup(q,true);arena.add_child(foe);foe.set_physics_process(false)
 var player:=StationaryActor.new();player.setup(q);arena.add_child(player);player.set_physics_process(false)
 player.position=Vector3(1,0,0);player.max_hp=100000;player.current_hp=100000
 foe.target=player;foe.attack_range=6.0
 foe.try_enemy_retreat()
 assert(foe.retreating and is_equal_approx(foe.current_speed(),foe.speed*.55))
 var episodes:=1;var previous:=true;var longest:=0;var consecutive:=0;var cooldown_ticks:=0
 for tick in 720:
  # Repeated damage requests and close-range kiting cannot refresh the timer.
  foe.try_enemy_retreat();foe.process_actor_physics(1.0/60)
  if foe.retreating:
   consecutive+=1;longest=maxi(longest,consecutive)
   if not previous:
    assert(cooldown_ticks>=350,"Enemies must fight for roughly six seconds between retreats")
    episodes+=1;cooldown_ticks=0
  else:
   consecutive=0;cooldown_ticks+=1
  previous=foe.retreating
 assert(episodes==2 and longest<=46,"Retreats are short and cannot restart continuously")
 foe.retreating=false;foe.enemy_retreat_cooldown=0;player.position.x=4
 foe.try_enemy_retreat();assert(not foe.retreating,"An enemy already out of close range must not flee farther")
 player.target=foe;player.try_enemy_retreat();assert(not player.retreating,"Enemy limits do not issue retreat orders to players")
 arena.free();await process_frame
 print("ENEMY_RETREAT_OK: bounded duration, recovery window, reduced speed and distance limit")
 quit()
