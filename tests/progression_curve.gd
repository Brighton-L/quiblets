extends SceneTree
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 assert(ok,message)
func _initialize():call_deferred("run")
static func fixture_team(area:int,node:int,gear_scale:=1.0)->Array:
 var target:=GameData.expedition_target(area,node)
 var team:Array=[]
 var species_list:=[0,10,6,12,5]
 for index in int(target.members):
  var q:=GameData.make_quiblet(species_list[index],int(target.level))
  var evolved:=GameData.evolution_target(int(q.species),int(q.level))
  if evolved>=0:q.species=evolved
  var unlocks:Array=[]
  for band in GameData.POWER_BOARD_UNLOCK_BANDS:
   for j in int(band[2]):unlocks.append(int(band[0])+floori((float(j)+.5)*(int(band[1])-int(band[0])+1)/int(band[2])))
  for slot in 16:
   q.power_slot_unlocks[slot]=unlocks[slot]
   q.power_slot_types[slot]="Health" if (slot+index)%2==0 else "Attack"
   q.power_slot_stones[slot]=GameData.normalize_power_stone({"type":q.power_slot_types[slot],"power":roundi(float(target.stone_power)*gear_scale),"bonuses":[]}) if unlocks[slot]<=int(q.level) else {}
  # Developed, legal move loadouts. One support/tank once the party grows.
  var move_names:Array=GameData.learnset(int(q.species)).slice(0,3)
  if index==3:move_names=["Shell Bash","Guard","Taunt"]
  if index==4:move_names=["Healing Bloom","Pollen Puff","Spore Cloud"]
  if int(q.level)>=75:
   for candidate in GameData.learnset(int(q.species)):
    if not move_names.has(candidate):move_names.append(candidate);break
  q.moves=[]
  var budget:=3+roundi(.8*floori(int(q.level)/25.0))
  for move_index in move_names.size():
   var slots:=maxi(1,budget/move_names.size()+(1 if move_index<budget%move_names.size() else 0))
   var stones:Array=[]
   if area>=3:stones.append("rush")
   if slots>=2:stones.append("heavy")
   if slots>=3:stones.append("blast")
   q.moves.append({"name":move_names[move_index],"slots":slots,"stones":stones})
  team.append(q)
 return team
func run():
 var rng:=RandomNumberGenerator.new();rng.seed=1129
 var previous_entry:=0
 for area in 20:
  var previous_normal:=0
  for node in 8:
   var t:=GameData.expedition_target(area,node)
   var team:=fixture_team(area,node)
   check(int(t.level)==GameData.expedition_node_level(area,node),"Stage target and actual node level agree")
   check(team.size()==int(t.members),"Expected party size")
   var base:float=GameData.expected_matchup(team.map(func(q):return q.level),int(t.level),area,{},team,node)
   check(base>.70 and base<1.40,"Generated baseline is near its target: %d/%d %.2f"%[area,node,base])
   var stronger:=fixture_team(area,node,1.5)
   check(GameData.expected_matchup(stronger.map(func(q):return q.level),int(t.level),area,{},stronger,node)>base,"Upgrades improve preparedness")
   for q in team:
    for i in 16:
     if not q.power_slot_stones[i].is_empty():check(GameData.power_slot_accepts(q,i,q.power_slot_stones[i].type),"Fixture only equips legal unlocked slots")
   for trial in 12:
    var stone:=GameData.make_stage_power_stone("Attack",int(t.level),[],rng)
    check(int(stone.power)>=roundi(t.drop_power*.9) and int(stone.power)<=roundi(t.drop_power*1.1),"Stage reward range")
   check(GameData.revitalizer_base_power(int(t.level))==int(t.drop_power),"Revitalizer follows actual average drops")
   check(GameData.stage_exp_reward(area,node,true)>GameData.stage_exp_reward(area,node,false),"Victory is worth more XP")
   if node in [0,1,2,4,5,6]:
    check(int(t.power)>previous_normal,"Combat targets rise within each route")
    previous_normal=int(t.power)
   if node==0 and area<16:
    check(int(t.power)>previous_entry,"Main-area entry targets rise")
    previous_entry=int(t.power)
   print("TARGET ",area," ",node," ",JSON.stringify(t))
  if area>=16:
   var host:=GameData.progression_area(area)
   check(GameData.expedition_node_level(area,5)==GameData.expedition_node_level(host,5),"Optional route inherits host level")
  # Reward enough XP to keep pace through one route, without requiring
  # optional groves or repeating the entire route to reach the next region.
  var xp:=0
  for node in 7:xp+=GameData.stage_exp_reward(area,node,true)
  var level:=GameData.expedition_area_level(area)
  var remaining:=xp
  while remaining>=GameData.exp_to_level(level):remaining-=GameData.exp_to_level(level);level+=1
  check(level>=GameData.expedition_area_level(area)+GameData.progression_level_span(area)-2,"Victory XP supports the next region")
 # New equipment may exceed the historical tier ceiling, without changing old stones.
 var legacy={"type":"Attack","power":517,"tier":4,"bonuses":[]}
 check(GameData.normalize_power_stone(legacy).power==517 and legacy.power==517,"Existing stone power remains exact")
 check(GameData.stage_drop_power(172)>GameData.stage_drop_power(104),"Late rewards keep growing")
 var main=load("res://main.tscn").instantiate();root.add_child(main);await process_frame
 check(main.save_access_blocked(),"Tests never access persistence")
 for area in 20:
  for node in 8:check(int(main.area_level_data(area,node).level)==GameData.expedition_node_level(area,node),"UI and combat share node data")
 main.queue_free();await process_frame
 print("PROGRESSION_CURVE_OK ",checks," checks across 160 nodes")
 quit()
