extends SceneTree
const FIXTURE=preload("res://tests/progression_curve.gd")
const AUDIT=preload("res://tests/looming_combat_audit.gd")
class GroveArena extends AUDIT.Arena:
 func begin_advance(_target_zone:int)->void:pass
func _initialize():call_deferred("run")
func run():
 var cases:=0
 var seed_offset:=0
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-offset="):seed_offset=int(arg.get_slice("=",1))
 var benchmark:="--late-benchmark" in OS.get_cmdline_user_args()
 for area in (range(12,16) if benchmark else range(20)):
  for node in (range(8) if "--all-nodes" in OS.get_cmdline_user_args() else ([1,2,3,4,7] if "--remaining-nodes" in OS.get_cmdline_user_args() else [0,5,6])):
   seed(172+area*19+node+seed_offset)
   var field=GroveArena.new();root.add_child(field);field.set_process(false);field.process_physics_priority=-100
   field.arena_rect=Rect2(-24,-20,48,40);field.stage_area_index=area;field.stage_node_index=node
   field.stage_kind="boss" if node==6 else ("berry_grove" if node in [3,7] else "level")
   field.stage_level=GameData.expedition_node_level(area,node);field.enemy_bonus=GameData.stage_enemy_stone_bonus(field.stage_level)
   field.spawn_points.assign([Vector2(4,0)]);field.spawn_rng.seed=172+area*19+node+seed_offset
   # Same synthetic developed party across all four final regions; never
   # load player data or rebuild a saved roster for the benchmark.
   field.team_data=FIXTURE.fixture_team(13,0,1.20) if benchmark else FIXTURE.fixture_team(area,node);field.team_average_level=GameData.average_team_level(field.team_data)
   for i in field.team_data.size():
    var actor=AUDIT.MeterActor.new();actor.setup(field.team_data[i]);field.place_actor(actor);actor.position=Vector3(-3,0,-3+i*1.5);actor.in_combat=true;field.team.append(actor)
    actor.revived.connect(func(_a):field.revivals+=1)
   field.min_alive=field.team.size()
   if node in [3,7]:
    field.zones.assign([{"center":Vector2.ZERO},{"center":Vector2(2,0)},{"center":Vector2(4,0)}]);field.spawn_grove_guardians()
   elif node in [5,6]:field.spawn_boss_wave()
   else:field.spawn_enemy_set()
   for foe in field.enemies:foe.set_meta("alerted",true)
   while field.audit_time<75 and field.outcome=="timeout":await physics_frame
   var row:={"area":area,"node":node,"team_power":GameData.team_power_rating(field.team_data),"seed_offset":seed_offset,"seconds":snappedf(field.audit_time,.1),"result":field.outcome,"min_alive":field.min_alive,"revivals":field.revivals,"boss_casts":field.boss_casts,"hp":[]}
   for actor in field.team:row.hp.append(snappedf(actor.current_hp/actor.max_hp,.01))
   print("CAMPAIGN ",JSON.stringify(row));cases+=1
   field.free();await process_frame
 print("CAMPAIGN_AUDIT_COMPLETE ",cases," cases")
 quit()
