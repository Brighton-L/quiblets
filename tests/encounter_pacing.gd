extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var e:=Expedition3D.new();root.add_child(e);e.set_process(false)
 e.zones.append({"center":Vector2.ZERO,"radius":Vector2(5,5)})
 for x in range(-5,501):
  for y in range(-15,16):e.walkable[Vector2i(x,y)]=true
 # A river with a single crossing forces actual detours.
 for x in range(25,29):
  for y in range(-15,16):
   if y<8 or y>11:e.walkable.erase(Vector2i(x,y))
 e.bridge_arches.append({"center":Vector2(26.5,9.5),"half_span":3.0})
 var last:=Vector2.ZERO
 for wave in range(1,10):
  e.wave=wave;e.zones[0].center=last
  var index:=e.pick_spawn_point();var point:=e.spawn_points[index]
  var distance:=e.encounter_walk_distance(last,point)
  check(distance>=e.SET_MIN_TEAM_DISTANCE and distance<=e.SET_MAX_WALK_DISTANCE,"Encounter walking distance out of bounds: %s"%distance)
  check(absf(distance-e.SET_TARGET_WALK_DISTANCE)<=3.0,"Regular waves should aim for the middle of the distance range: %.2f"%distance)
  check(point.x>last.x,"Open forward route should not send the player backward")
  check(e.cell_open(e.cell_of(point)),"Encounter must be on open ground")
  for style in ["clearing","bridge","surround"]:
   e.encounter_style=style
   var positions:=e.encounter_positions(point,4)
   for i in positions.size():
    check(e.cell_open(e.cell_of(positions[i])) and e.line_walkable(point,positions[i]),"Formation must stay reachable on land")
    for j in range(i):check(positions[i].distance_to(positions[j])>=1.0,"Formation must not overlap")
  # Ranged teams stop short of the spawn center. Do not teleport them onto
  # each encounter: that hid repeated spawn sites in the original test.
  for old in e.spawn_points.slice(0,-1):check(point.distance_to(old)>=e.ENCOUNTER_REUSE_RADIUS,"Encounter reused a cleared fighting area")
  var route:=e.find_path(last,point)
  var remaining:=distance-6.0
  var walked:=last
  for waypoint in route:
   var next:=Vector2(waypoint.x,waypoint.z);var segment:=walked.distance_to(next)
   if segment>=remaining:
    walked=walked.move_toward(next,remaining);break
   remaining-=segment;walked=next
  check(distance-6.0>=13.0,"Quiet approach should not collapse to just a few steps")
  last=walked
 # Boss placement must reject an arena right beside the team too.
 e.zones.append({"center":last+Vector2(1,0),"radius":Vector2(5,5)})
 e.zones[0].center=last
 var boss_point:=e.spawn_points[e.pick_spawn_point(true)]
 var boss_distance:=e.encounter_walk_distance(last,boss_point)
 check(absf(boss_distance-e.SET_TARGET_WALK_DISTANCE)<=2.0,"Boss should have the same medium walk even with a nearby arena")
 # A visually close location beyond the river exceeds the walk budget.
 var distance:=e.encounter_walk_distance(Vector2(23,-15),Vector2(30,-15))
 check(distance>e.SET_MAX_WALK_DISTANCE,"River detour must count toward distance")
 check(not e.encounter_distances(Vector2(23,-15)).has(Vector2i(30,-15)),"Distant crossing must exclude visually nearby enemies")
 e.free()
 # Also exercise the actual river/terrain generator and enemy spawning.
 var level:=Expedition3D.new();root.add_child(level);level.set_process(false)
 level.stage_kind="level";level.stage_area_index=0;level.stage_node_index=1;level.stage_level=2
 level.build_level();level.team_data=[GameData.make_quiblet(0,5)]
 for wave in range(1,7):
  level.wave=wave
  var from:=Vector2(level.zones[0].center)
  level.spawn_enemy_set()
  var point:Vector2=level.spawn_points.back()
  check(level.encounter_walk_distance(from,point)<=level.SET_MAX_WALK_DISTANCE,"Generated terrain exceeded travel budget")
  for enemy in level.enemies:
   check(level.cell_open(level.cell_of(Vector2(enemy.position.x,enemy.position.z))),"Spawned enemy is off walkable ground")
   enemy.free()
  level.enemies.clear();level.zones[0].center=point
 level.wave=level.max_waves
 var before_boss:=Vector2(level.zones[0].center)
 level.spawn_boss_wave()
 var boss_walk:=level.encounter_walk_distance(before_boss,Vector2(level.camera_pan_target.x,level.camera_pan_target.z))
 check(boss_walk>=level.SET_MIN_TEAM_DISTANCE and boss_walk<=level.SET_MAX_WALK_DISTANCE,"Actual boss spawn must respect both distance limits")
 level.free()
 print("ENCOUNTER_PACING checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
