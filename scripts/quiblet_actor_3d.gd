class_name QuibletActor3D
extends CharacterBody3D

signal defeated(actor: QuibletActor3D)
signal revived(actor: QuibletActor3D)
signal move_used(actor: QuibletActor3D, move_name: String, target: QuibletActor3D, details: Dictionary)

var data: Dictionary
var enemy := false
var current_hp := 100.0
var max_hp := 100.0
var attack := 20.0
var damage_multiplier:=1.0
var attack_range := 4.0
var speed := 2.8
var target: QuibletActor3D
var move_cooldowns: Array[float] = []
var move_cooldown_totals: Array[float] = []
var recover_time := 0.0
var recover_total := 0.0
var recover_amount := 0.0
var desired_point := Vector3.ZERO
# Extra visual squash-and-stretch (the boss introduction animates this); the
# model's scale is rebuilt every status tick, so the multiplier lives here.
var model_stretch:=Vector3.ONE
# Extra visual height (the spawn drop animates this); added to the model's
# position every status tick alongside the launch status.
var model_lift:=0.0
# Remaining waypoints after desired_point when following a routed path.
var command_path:Array[Vector3]=[]
var has_command := false
var retreating := false
var selected := false:
	set(value):
		selected=value
		if is_instance_valid(model):model.set_selected(value)
var model: QuibletModel3D
const TEAM_RING_SCRIPT:=preload("res://scripts/team_ring_3d.gd")
var team_ring: Node3D
var arena := Rect2(-12,-6,24,12)
var obstacle_rects: Array[Rect2] = []
var knocked_out:=false
var revive_time:=0.0
var knockouts:=0
var delayed_executions_resolved:=0
const BEHAVIORS=preload("res://scripts/move_behaviors.gd")
const MOVE_CAST=preload("res://scripts/move_cast_3d.gd")
var statuses:Dictionary={}
var cast_epoch:=0
var motion_lock:=0
var status_visual:MeshInstance3D
# The last self-initiated move (name and time), so Mimbit's Copycat can replay it.
var last_move_name:=""
var last_move_time:=-1.0
# Summed Power Stone bonus stats from the equipped stones, keyed by stat.
var bonus_totals:Dictionary={}

func setup(q: Dictionary, is_enemy := false, level_boost := 0, team_slot := -1, scaling:Dictionary={}) -> void:
	data=q.duplicate(true);data.level=int(data.level)+level_boost;enemy=is_enemy
	# Enemy handicaps shrink and then flip into bonuses on later islands; see GameData.enemy_scaling.
	max_hp=GameData.max_hp(data)*(float(scaling.get("hp",.68)) if enemy else 1.0);current_hp=max_hp;attack=GameData.attack(data);damage_multiplier=float(scaling.get("damage",.58)) if enemy else 1.0
	attack_range=clampf(float(GameData.species(int(data.species)).range)/35.0,2.0,6.2)
	bonus_totals=GameData.quiblet_bonus_totals(data)
	speed=(2.4+minf(.9,attack_range*.1))*(1.0+bonus_value("speed"))
	move_cooldowns.resize(data.moves.size())
	move_cooldown_totals.resize(data.moves.size())
	for i in move_cooldowns.size():
		move_cooldowns[i]=randf_range(0,.8) if enemy else 0.0
		move_cooldown_totals[i]=move_cooldowns[i]
	var collision:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=.55;shape.height=1.5;collision.shape=shape;collision.position.y=.7;add_child(collision)
	model=QuibletModel3D.new();model.setup(int(data.species),enemy,.82);add_child(model)
	if not enemy and team_slot>=0:
		team_ring=TEAM_RING_SCRIPT.new();team_ring.setup(team_slot);add_child(team_ring)
	if enemy:model.rotation.y=PI

func _physics_process(delta: float) -> void:
	if is_instance_valid(team_ring):team_ring.follow_facing(model)
	if knocked_out:
		revive_time=maxf(0.0,revive_time-delta)
		if revive_time<=0.0:revive_from_knockout()
		return
	if current_hp<=0:return
	update_statuses(delta)
	if current_hp<=0:return
	# Natural recovery: team Quiblets slowly regain HP whenever they are below full.
	if not enemy and current_hp<max_hp:current_hp=minf(max_hp,current_hp+max_hp*GameData.PASSIVE_REGEN_PER_SECOND*delta)
	# Encourage's haste speeds up cooldown recovery while it lasts.
	var cooldown_rate:float=1.0+(float(statuses.haste.amount) if statuses.has("haste") else 0.0)
	for i in move_cooldowns.size():move_cooldowns[i]=maxf(0,move_cooldowns[i]-delta*cooldown_rate)
	if actions_locked() or motion_lock>0:
		velocity=Vector3.ZERO;return
	if movement_locked():
		velocity=Vector3.ZERO
		if is_instance_valid(target):try_use_best_move(horizontal_distance(global_position,target.global_position))
		return
	if recover_time>0:
		current_hp=minf(max_hp,current_hp+recover_amount/maxf(recover_total,.01)*delta);recover_time-=delta;return
	if has_command:
		# Routed points already keep clear of cliffs, so no corner steering here: it
		# would fight the route and leave the Quiblet juddering beside a wall.
		move_toward_point(desired_point,delta,false)
		var remaining:=horizontal_distance(global_position,desired_point)
		# The last point counts as reached when it is close and progress has stopped
		# (teammates crowding the same spot keep each other from the exact point).
		if remaining<(.35 if command_path.is_empty() else .6) or (command_path.is_empty() and remaining<1.6 and stuck_timer>.45):
			if command_path.is_empty():has_command=false;stuck_timer=0.0
			else:desired_point=clamp_point(command_path.pop_front())
		return
	if not is_instance_valid(target) or target.current_hp<=0:
		velocity=velocity.move_toward(Vector3.ZERO,8*delta);move_and_slide();return
	var distance:=horizontal_distance(global_position,target.global_position)
	if retreating:
		var away:Vector3=(global_position-target.global_position);away.y=0
		move_toward_point(clamp_point(global_position+away.normalized()*4.0),delta)
		if distance>6.5:retreating=false
		return
	var ideal:=minf(attack_range*.78,4.5)
	if distance>ideal+.35:move_toward_point(target.global_position,delta)
	elif distance<ideal*.52 and attack_range>3.5:
		var away:Vector3=global_position-target.global_position;away.y=0;move_toward_point(clamp_point(global_position+away.normalized()*2.3),delta)
	else:
		velocity=velocity.move_toward(Vector3.ZERO,10*delta);move_and_slide();try_use_best_move(distance)

func move_toward_point(point: Vector3, delta: float, steer:=true) -> void:
	var flat:=point-global_position;flat.y=0;var direction:=flat.normalized()
	# The cliff look-ahead pads every rect by .7, more than half a tile, so a
	# destination beside a cliff (a berry patch against the rim, with walls on one
	# or both sides) sits inside the padding. Steering is skipped on the final
	# step so the Quiblet walks straight onto the patch instead of juddering.
	var probe:=Vector2(global_position.x+direction.x*.9,global_position.z+direction.z*.9)
	var steer_around_cliffs:=steer and flat.length()>.9
	for obstacle in obstacle_rects:
		if not steer_around_cliffs:break
		var padded:=obstacle.grow(.7)
		if padded.has_point(probe):
			var corners:=[Vector2(padded.position.x-.1,padded.position.y-.1),Vector2(padded.end.x+.1,padded.position.y-.1),Vector2(padded.position.x-.1,padded.end.y+.1),Vector2(padded.end.x+.1,padded.end.y+.1)]
			corners.sort_custom(func(a,b):return Vector2(global_position.x,global_position.z).distance_to(a)+a.distance_to(Vector2(point.x,point.z))<Vector2(global_position.x,global_position.z).distance_to(b)+b.distance_to(Vector2(point.x,point.z)))
			direction=Vector3(global_position.x,0,global_position.z).direction_to(Vector3(corners[0].x,0,corners[0].y));break
	var separation:=Vector3.ZERO
	for sibling in get_parent().get_children():
		if sibling is QuibletActor3D and sibling!=self and sibling.enemy==enemy:
			var d:=horizontal_distance(global_position,sibling.global_position)
			if d<1.35 and d>.01:var away:Vector3=global_position-sibling.global_position;away.y=0;separation+=away.normalized()*(1.35-d)
	# Ease in over the last stretch so the Quiblet settles instead of overshooting
	# and snapping back across its goal every frame.
	var arrival:=clampf(flat.length()/.9,.4,1.0)
	var before:=global_position
	velocity=(direction+separation*.7).normalized()*current_speed()*arrival;velocity.y=0;move_and_slide();global_position=clamp_point(global_position)
	face_direction(velocity,delta)
	track_progress(before,delta)

# Movement speed after status effects: Frost/mud/web slows drag it down, while an
# air-current Tailwind speeds it up.
func current_speed()->float:
	var result:=speed
	if statuses.has("slow"):result*=maxf(.15,1.0-float(statuses.slow.amount))
	if statuses.has("hasten"):result*=1.0+float(statuses.hasten.amount)
	return result

# The model turns smoothly to face wherever the Quiblet is heading, on every
# kind of movement (routes, chases, kiting, retreats). The model's +Z is its front.
const TURN_SPEED:=11.0
func face_direction(direction:Vector3,delta:float)->void:
	if not is_instance_valid(model) or Vector2(direction.x,direction.z).length()<.05:return
	model.rotation.y=lerp_angle(model.rotation.y,atan2(direction.x,direction.z),1.0-exp(-TURN_SPEED*delta))

func facing()->Vector3:
	return model.global_basis.z if is_instance_valid(model) else Vector3.FORWARD

# Stuck detection: a Quiblet that keeps trying to move but has not gained ground
# for a while asks the expedition for a fresh route rather than jittering in place.
func track_progress(before:Vector3,delta:float)->void:
	if horizontal_distance(global_position,progress_anchor)>.3:progress_anchor=global_position;stuck_timer=0.0;return
	stuck_timer+=delta
	if stuck_timer>=STUCK_SECONDS:stuck_timer=0.0;progress_anchor=global_position;stuck.emit(self)

func try_use_best_move(distance: float) -> void:
	# Player moves start only from explicit input. Echo and Link follow-ups still
	# resolve through the normal executor after a manually activated move.
	if not enemy or actions_locked() or motion_lock>0:return
	for i in data.moves.size():
		if move_cooldowns[i]>0:continue
		var entry:Dictionary=data.moves[i];var move_name:String=entry.name;var move:Dictionary=GameData.MOVES[move_name]
		if BEHAVIORS.is_support(move_name):
			if current_hp/max_hp<.48:use_move(i,target);return
		elif distance<=float(move.range)/35.0*pow(1.38,stone_count(entry,"reach")):use_move(i,target);return

func use_move(index:int,new_target:QuibletActor3D)->void:
	if index<0 or index>=data.moves.size() or move_cooldowns[index]>0:return
	_execute_move(index,new_target,1.0,false,[],false)

# forced: an Echo or Link follow-up of a move already under way. It is part of
# that move, so it fires even while the user is stunned or out of reach.
# fallback_aim: where a forced follow-up lands when its target has died and no
# enemy is within reach, so an Echo of an area move falls on the same spot
# instead of vanishing (or flying across the map to a far-off set).
func _execute_move(index:int,new_target:QuibletActor3D,effectiveness:float,ignore_cooldown:bool,visited:Array,is_echo:bool,forced:bool=false,fallback_aim:Vector3=Vector3.INF)->void:
	if current_hp<=0:return
	if not forced and (actions_locked() or motion_lock>0):return
	if index<0 or index>=data.moves.size():return
	if visited.has(index) and not is_echo:return
	var chain_visited:=visited.duplicate()
	if not chain_visited.has(index):chain_visited.append(index)
	var entry:Dictionary=data.moves[index];var move:Dictionary=GameData.MOVES[entry.name]
	var profile:Dictionary=BEHAVIORS.profile(entry.name)
	# Record the move so an ally's Copycat can replay it (never record Copycat itself).
	if not forced and not is_echo and entry.name!="Copycat":last_move_name=entry.name;last_move_time=Time.get_ticks_msec()/1000.0
	if not ignore_cooldown and move_cooldowns[index]>0:return
	if profile.has("low_hp") and current_hp/max_hp>float(profile.low_hp):return
	if profile.mode=="combust" and (not is_instance_valid(new_target) or not new_target.statuses.has("burn")):return
	if profile.mode=="dash" and movement_locked() and not forced:return
	var needs_target:bool=profile.get("anchor","")=="target" or profile.mode=="combust"
	if needs_target and (not is_instance_valid(new_target) or new_target.current_hp<=0):
		new_target=nearest_live_enemy() if not forced else null
		if not is_instance_valid(new_target) and not (forced and fallback_aim!=Vector3.INF):return
	if needs_target and not forced and horizontal_distance(global_position,new_target.global_position)>float(move.range)/35.0*pow(1.38,stone_count(entry,"reach"))+.5:return
	if not ignore_cooldown:
		var cooldown_multiplier:=pow(1.28,stone_count(entry,"heavy"))*pow(.72,stone_count(entry,"rush"))*pow(1.35,stone_count(entry,"echo"))*maxf(.1,1.0-bonus_value("cooldown"))
		move_cooldowns[index]=float(move.cooldown)*cooldown_multiplier
		move_cooldown_totals[index]=move_cooldowns[index]
	var strength:float=effectiveness*pow(1.35,stone_count(entry,"heavy"))
	var cast=MOVE_CAST.new()
	cast.setup(self,entry,new_target,strength,is_echo)
	if forced and not is_instance_valid(new_target) and fallback_aim!=Vector3.INF:cast.set_aim(fallback_aim)
	var target_reference:WeakRef=weakref(new_target) if is_instance_valid(new_target) else null
	var generation:=cast_epoch;var aim_point:Vector3=cast.aim
	cast.finished.connect(func():
		if current_hp<=0 or cast_epoch!=generation:return
		if GameData.has_stone(entry,"echo") and not is_echo:_schedule_followup(index,target_reference,effectiveness,chain_visited,true,.3,generation,aim_point)
		var linked_index:=linked_move_index(entry)
		if linked_index>=0 and not chain_visited.has(linked_index):_schedule_followup(linked_index,target_reference,effectiveness*.65,chain_visited,false,.18,generation,aim_point)
	)
	get_parent().add_child(cast)

# Echo and Link follow-ups are part of the move that started them, so a stun,
# bubble, cocoon, or launch landing in the meantime does not stop them. They
# only wait (up to FOLLOWUP_GRACE seconds) for the user's own in-progress dash
# or beam to end. A target that died or wandered out of reach is swapped for
# the nearest live enemy within the move's reach; with none there, the
# follow-up still lands on the original target if it lives, else on the spot
# the move was aimed at.
const FOLLOWUP_GRACE:=2.5
func _schedule_followup(index:int,reference:WeakRef,effectiveness:float,visited:Array,is_echo:bool,delay:float,generation:int,aim:Vector3=Vector3.INF)->void:
	await get_tree().create_timer(delay,false,true).timeout
	var waited:=0.0
	while motion_lock>0 and waited<FOLLOWUP_GRACE and current_hp>0 and cast_epoch==generation:
		await get_tree().create_timer(.1,false,true).timeout;waited+=.1
	delayed_executions_resolved+=1
	if current_hp<=0 or cast_epoch!=generation:return
	var candidate=reference.get_ref() if reference!=null else null
	var safe_target:QuibletActor3D=candidate as QuibletActor3D if is_instance_valid(candidate) else null
	if index<0 or index>=data.moves.size():return
	var entry:Dictionary=data.moves[index];var reach:float=float(GameData.MOVES[entry.name].range)/35.0*pow(1.38,stone_count(entry,"reach"))+.5
	if not is_instance_valid(safe_target) or safe_target.current_hp<=0:safe_target=nearest_live_enemy(reach)
	elif horizontal_distance(global_position,safe_target.global_position)>reach:
		var closer:=nearest_live_enemy(reach)
		if is_instance_valid(closer):safe_target=closer
	_execute_move(index,safe_target,effectiveness,true,visited,is_echo,true,aim)

func nearest_live_enemy(within:float=INF)->QuibletActor3D:
	var result:QuibletActor3D=null;var best:=within
	for actor in nearby_actors(true,100):
		var d:=horizontal_distance(global_position,actor.global_position)
		if d<best:result=actor;best=d
	return result

func linked_move_index(entry:Dictionary)->int:
	for value in entry.stones:
		var text:=str(value)
		if text.begins_with("link:"):
			var target_name:=text.trim_prefix("link:")
			for i in data.moves.size():
				if data.moves[i].name==target_name and data.moves[i].stones.has("link_from:"+str(entry.name)):return i
	return -1

func stone_count(entry:Dictionary,effect:String)->int:
	if not BEHAVIORS.supports(entry.name,effect):return 0
	var count:=0
	for value in entry.stones:
		if GameData.stone_effect(str(value))==effect:count+=1
	return count

func nearby_actors(want_enemies:bool,radius:float,around:QuibletActor3D=null)->Array[QuibletActor3D]:
	var result:Array[QuibletActor3D]=[]
	var center:QuibletActor3D=around if is_instance_valid(around) else self
	for sibling in get_parent().get_children():
		if sibling is QuibletActor3D and sibling!=self and sibling.current_hp>0:
			var opposing:bool=sibling.enemy!=enemy
			if opposing==want_enemies and horizontal_distance(sibling.position,center.position)<=radius:result.append(sibling)
	return result

func nearest_other_target(from_target:QuibletActor3D,excluded:Array,radius:float)->QuibletActor3D:
	var result:QuibletActor3D;var best:=INF
	for sibling in get_parent().get_children():
		if sibling is QuibletActor3D and sibling.enemy!=enemy and sibling.current_hp>0 and sibling!=from_target and not excluded.has(sibling):
			var distance:=horizontal_distance(sibling.position,from_target.position)
			if distance<=radius and distance<best:best=distance;result=sibling
	return result

func apply_force(hit_target:QuibletActor3D,entry:Dictionary,base_distance:float)->void:
	var distance:=(base_distance+(1.25*stone_count(entry,"force")))*maxf(0.0,1.0-hit_target.bonus_value("knockback"))
	var away:=hit_target.position-position;away.y=0
	if away.length()>.01:hit_target.position=hit_target.clamp_point(hit_target.position+away.normalized()*distance)

func bonus_value(stat:String)->float:
	return float(bonus_totals.get(stat,0.0))

func receive_shared_heal(amount:float)->void:
	if current_hp>0:current_hp=minf(max_hp,current_hp+maxf(0,amount)*(1.0+bonus_value("healing")))

func take_damage(amount:float,attacker:QuibletActor3D=null,reflectable:bool=true)->float:
	if current_hp<=0 or amount<=0:return 0.0
	# Power Stone bonuses: the attacker's critical hits, then the victim's damage resistance.
	if reflectable and is_instance_valid(attacker) and attacker!=self and attacker.bonus_value("crit")>0.0 and randf()<minf(1.0,attacker.bonus_value("crit")):amount*=GameData.CRITICAL_HIT_MULTIPLIER
	amount*=maxf(0.0,1.0-bonus_value("resist"))
	# Corrode and similar effects lower the victim's defense, so it takes more.
	if statuses.has("defense_down"):amount*=1.0+float(statuses.defense_down.amount)
	# Level gap: under-levelled fighters deal less to and take more from higher-level foes.
	if is_instance_valid(attacker) and attacker!=self and attacker.enemy!=enemy:amount*=GameData.level_gap_factor(int(attacker.data.get("level",1)),int(data.get("level",1)))
	var incoming:=amount
	if statuses.has("shield"):
		var blocked:=minf(amount,statuses.shield.amount)
		statuses.shield.amount-=blocked;amount-=blocked
		if statuses.shield.amount<=0:statuses.erase("shield")
	if statuses.has("bubble"):
		statuses.bubble.amount-=incoming
		if statuses.bubble.amount<=0:statuses.erase("bubble")
	var actual:=minf(current_hp,amount)
	current_hp=maxf(0,current_hp-amount);model.set_hurt(true)
	if reflectable and statuses.has("thorns") and is_instance_valid(attacker) and attacker!=self:
		attacker.take_damage(incoming*float(statuses.thorns.amount),self,false)
	var tween:=create_tween();tween.tween_interval(.12);tween.tween_callback(func():if is_instance_valid(model):model.set_hurt(false))
	if current_hp/max_hp<.22 and randf()<.32:retreating=true
	if current_hp<=0:
		velocity=Vector3.ZERO;has_command=false;command_path.clear();retreating=false;target=null
		cast_epoch+=1;statuses.clear()
		if is_instance_valid(status_visual):status_visual.visible=false
		if enemy:defeated.emit(self)
		else:begin_knockout()
	return actual

func begin_knockout()->void:
	knockouts+=1;knocked_out=true;revive_time=GameData.knockout_revive_seconds(knockouts)
	var tween:=create_tween();tween.set_parallel(true);tween.tween_property(model,"rotation:x",-PI*.5,.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);tween.tween_property(model,"position:y",.18,.28)
	if is_instance_valid(team_ring):team_ring.visible=false
	defeated.emit(self)

func revive_from_knockout()->void:
	if not knocked_out:return
	knocked_out=false;current_hp=max_hp*.5;revive_time=0.0;model.scale=Vector3.ONE*.78
	if is_instance_valid(team_ring):team_ring.visible=true
	var tween:=create_tween();tween.set_parallel(true);tween.tween_property(model,"rotation:x",0.0,.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);tween.tween_property(model,"position:y",.35,.14);tween.tween_property(model,"scale",Vector3.ONE*1.08,.18)
	tween.set_parallel(false);tween.tween_property(model,"position:y",0.0,.12);tween.parallel().tween_property(model,"scale",Vector3.ONE,.12);tween.tween_callback(func():revived.emit(self))

const STUCK_SECONDS:=.7
signal stuck(actor:QuibletActor3D)
var stuck_timer:=0.0
var progress_anchor:=Vector3.ZERO

func floats_over_water()->bool:
	return float(GameData.species(int(data.species)).get("model_hover",0.0))>0.0

func command(point:Vector3)->void:
	set_meta("auto_route",false)
	# Any fresh command (a player click, exploration, or a new chase route) ends a
	# previous chase route; the expedition re-marks its own routes after this.
	if has_meta("chase_routed"):set_meta("chase_routed",false)
	command_path.clear();desired_point=clamp_point(point);has_command=true;retreating=false

# Walk a routed path: the first point becomes the current command and the rest
# are visited in order, so the Quiblet threads corridor gaps instead of pushing into cliffs.
func follow_path(path:Array[Vector3])->void:
	if path.is_empty():has_command=false;command_path.clear();return
	command(path[0]);command_path=path.slice(1)

func clamp_point(p:Vector3)->Vector3:
	return Vector3(clampf(p.x,arena.position.x,arena.end.x),0,clampf(p.z,arena.position.y,arena.end.y))

func horizontal_distance(a:Vector3,b:Vector3)->float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))

# Status timers use physics time, so pausing freezes effects and cooldowns alike.
func add_status(kind:String,seconds:float,amount:float,from_actor:QuibletActor3D=null,drain:float=0.0)->void:
	if current_hp<=0:return
	if kind=="shield":amount=max_hp*amount
	if kind=="bubble":amount=max_hp*.12*amount
	var previous:Dictionary=statuses.get(kind,{})
	statuses[kind]={"time":maxf(seconds,float(previous.get("time",0))),"total":seconds,"amount":maxf(amount,float(previous.get("amount",0))),"source":weakref(from_actor) if is_instance_valid(from_actor) else null,"drain":drain}

func update_statuses(delta:float)->void:
	for kind in statuses.keys():
		if not statuses.has(kind):continue
		var status:Dictionary=statuses[kind]
		var active_time:=minf(delta,status.time)
		var ref:WeakRef=status.source
		var from_actor:QuibletActor3D=ref.get_ref() as QuibletActor3D if ref!=null else null
		if kind in ["burn","leech","poison"]:
			var actual:=take_damage(float(status.amount)*active_time,from_actor,false)
			if is_instance_valid(from_actor):from_actor.receive_shared_heal(actual*(float(status.drain)+(.5 if kind=="leech" else 0.0)))
		elif kind=="cocoon":receive_shared_heal(max_hp*float(status.amount)*active_time)
		status.time-=delta
		if status.time<=0:statuses.erase(kind)
	if is_instance_valid(model) and current_hp>0:
		model.scale=Vector3.ONE*.82*(float(statuses.growth.amount) if statuses.has("growth") else 1.0)*model_stretch
		model.position.y=(sin(PI*(1.0-float(statuses.launch.time)/float(statuses.launch.total)))*float(statuses.launch.amount) if statuses.has("launch") else 0.0)+model_lift
	update_status_visual()

func actions_locked()->bool:
	return statuses.has("cocoon") or statuses.has("stun") or statuses.has("bubble") or statuses.has("launch")

func movement_locked()->bool:
	return actions_locked() or statuses.has("root")

func cleanse()->void:
	for kind in ["burn","leech","root","stun","bubble","smoke","poison","slow","confuse","defense_down","weaken"]:statuses.erase(kind)

func accepts_hit_from(attacker:QuibletActor3D)->bool:
	var miss:=0.0
	if statuses.has("evade"):miss=maxf(miss,minf(.85,float(statuses.evade.amount)))
	if is_instance_valid(attacker) and attacker.statuses.has("smoke"):miss=1-(1-miss)*.5
	# A confused (or scared) attacker's own strikes often go wide.
	if is_instance_valid(attacker) and attacker.statuses.has("confuse"):miss=maxf(miss,minf(.9,float(attacker.statuses.confuse.amount)))
	if bonus_value("evasion")>0.0:miss=1-(1-miss)*(1-minf(1.0,bonus_value("evasion")))
	return randf()>=miss

func displace(offset:Vector3)->void:
	if current_hp>0:global_position=safe_displacement(global_position,global_position+offset*maxf(0.0,1.0-bonus_value("knockback")),.55)

func safe_displacement(start:Vector3,end:Vector3,padding:float)->Vector3:
	var clamped:=clamp_point(end);var length:=horizontal_distance(start,clamped)
	var steps:=maxi(1,ceili(length/.08));var last:=start
	for i in range(1,steps+1):
		var point:=start.lerp(clamped,float(i)/steps);var blocked:=false
		for obstacle in obstacle_rects:
			if obstacle.grow(padding).has_point(Vector2(point.x,point.z)):blocked=true;break
		if blocked:break
		last=point
	return last

func update_status_visual()->void:
	if not is_instance_valid(status_visual):
		status_visual=MeshInstance3D.new();var shape:=SphereMesh.new();shape.radius=.7;shape.height=1.5;shape.radial_segments=16;shape.rings=8
		status_visual.mesh=shape;status_visual.position.y=.65;add_child(status_visual)
		var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		status_visual.material_override=mat
	status_visual.visible=not statuses.is_empty() and current_hp>0
	var tint:=Color(.7,.7,.7,.3)
	for kind in ["burn","leech","root","stun","smoke","evade","thorns","cocoon","bubble","shield","empower","poison","slow","confuse","defense_down","taunt","haste","hasten","weaken"]:
		if not statuses.has(kind):continue
		match kind:
			"burn":tint=Color(1,.25,.03,.45)
			"root","leech","thorns":tint=Color(.3,.6,.12,.4)
			"bubble","shield":tint=Color(.2,.7,1,.35)
			"cocoon":tint=Color(.85,1,.65,.8)
			"stun","confuse":tint=Color(.7,.3,.85,.4)
			"empower":tint=Color(.63,.44,.85,.4)
			"poison":tint=Color(.55,.8,.2,.45)
			"slow":tint=Color(.5,.7,.95,.4)
			"defense_down":tint=Color(.85,.5,.2,.4)
			"taunt":tint=Color(.95,.55,.2,.4)
			"haste","hasten":tint=Color(.95,.9,.4,.4)
			"weaken":tint=Color(.6,.55,.5,.4)
	status_visual.material_override.albedo_color=tint
