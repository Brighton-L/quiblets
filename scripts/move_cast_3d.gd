extends Node3D

# A cast owns its projectiles/fields until the ENTIRE move is finished. Echo
# and Link listen to completion, not a guessed animation duration.
signal finished
const BEHAVIORS=preload("res://scripts/move_behaviors.gd")
var caster_ref:WeakRef
var target_ref:WeakRef
var epoch:int
var move_name:String
var profile:Dictionary
var entry:Dictionary
var details:Dictionary
var strength:float
var damage:float
var distance:float
var radius:float
var duration:float
var duration_scale:float
var area_scale:float
var force_scale:float
var direction:=Vector3.RIGHT
var origin:=Vector3.ZERO
var aim:=Vector3.ZERO
var elapsed:=0.0
var next_tick:=0.0
var activated:=false
var done:=false
var shots:Array[Dictionary]=[]
var patches:Array[Dictionary]=[]
var fragments:Array[Dictionary]=[]
var visuals:Array[MeshInstance3D]=[]
var color:=Color.WHITE
var travel:=0.0
var dash_hits:Dictionary={}
var base_scale:=1.0
var source_enemy:=false
var airborne_visual:MeshInstance3D
# One arcing drop per patch, so a Split raindrop/meteor visibly launches several.
var airborne_drops:Array[MeshInstance3D]=[]
var vine_visual:MeshInstance3D
var erupting_rocks:Array[MeshInstance3D]=[]
var contact_time:=0.0
var maneuver_points:Array[Vector3]=[]
var maneuver_index:=0
var owns_motion_lock:=false

func setup(source, move_entry:Dictionary, new_target, power_scale:float, is_echo:bool)->void:
	caster_ref=weakref(source);epoch=source.cast_epoch;source_enemy=source.enemy
	target_ref=weakref(new_target) if is_instance_valid(new_target) else null
	entry=move_entry.duplicate(true);move_name=entry.name;profile=BEHAVIORS.profile(move_name);strength=power_scale
	var move:Dictionary=GameData.MOVES[move_name]
	damage=(float(move.power)+source.attack*.58)*strength*source.damage_multiplier
	# Helping Hand's empower buff temporarily raises the caster's attack output;
	# a Honk's weaken lowers it.
	if source.statuses.has("empower"):damage*=float(source.statuses.empower.amount)
	if source.statuses.has("weaken"):damage*=maxf(.1,1.0-float(source.statuses.weaken.amount))
	distance=float(move.range)/35.0*pow(1.38,count("reach"))
	duration_scale=pow(1.65,count("lingering"));area_scale=pow(1.35,count("blast"));force_scale=pow(1.65,count("force"))
	if profile.get("physical",false) and source.statuses.has("growth"):
		area_scale*=source.statuses.growth.amount;force_scale*=source.statuses.growth.amount
	radius=float(profile.get("radius",1.0))*area_scale
	duration=float(profile.get("duration",0.0))*duration_scale
	origin=source.global_position;aim=origin+source.model.global_basis.z*distance
	if is_instance_valid(new_target):aim=new_target.global_position
	direction=flat(aim-origin).normalized()
	if direction.length()<.01:direction=Vector3.RIGHT
	aim=origin+direction*minf(flat(aim-origin).length(),distance)
	# A grab without a reachable target still performs its lunge/zap in the
	# aimed direction instead of disappearing as soon as it is created.
	if profile.mode=="contact" and (not is_instance_valid(new_target) or flat(new_target.global_position-origin).length()>distance+.5):
		profile.mode="dash" if profile.get("attach",false) else "line"
		profile.speed=12.0;profile.radius=maxf(.65,float(profile.get("radius",.65)));radius=float(profile.radius)*area_scale
	color=Color(move.color)
	details={"real_effect":true,"echo":is_echo,"strength":strength,"chain":false}
	for stone in ["split","seeking","blast","force","lingering"]:details[stone]=count(stone)>0

# Re-aim a cast at a remembered point (a follow-up whose target has died).
func set_aim(point:Vector3)->void:
	direction=flat(point-origin).normalized()
	if direction.length()<.01:direction=Vector3.RIGHT
	aim=origin+direction*minf(flat(point-origin).length(),distance)

func count(stone:String)->int:
	if not BEHAVIORS.supports(move_name,stone):return 0
	var n:=0
	for value in entry.stones:
		if GameData.stone_effect(str(value))==stone:n+=1
	return n

func source():
	return caster_ref.get_ref() if caster_ref!=null else null

func target():
	var result=target_ref.get_ref() if target_ref!=null else null
	return result if is_instance_valid(result) and result.current_hp>0 else null

func _ready()->void:
	top_level=true;global_position=Vector3.ZERO
	var actor=source()
	if not is_instance_valid(actor):finish();return
	if profile.get("escape",false):
		var danger=nearest(origin,[],6.0)
		if is_instance_valid(danger):direction=flat(origin-danger.global_position).normalized()
		else:direction=-direction
		if direction.length()<.01:direction=Vector3.BACK
		aim=origin+direction*distance
	actor.move_used.emit(actor,move_name,target(),details)
	var copies:=1+2*count("split")
	var split_scale:=1.0 if copies==1 else 1.4/float(copies)
	copies*=int(profile.get("projectile_count",profile.get("patch_count",1)))
	base_scale=split_scale
	var mode:String=profile.mode
	if profile.get("rear",false):direction=-flat(actor.facing()).normalized()
	if mode in ["projectile","wave"]:
		for i in copies:
			var angle:float=(i-(copies-1)*.5)*float(profile.get("spread",.19))
			var heading:=direction.rotated(Vector3.UP,angle)
			var visual:=orb(origin+Vector3.UP*.7,Vector3.ONE*radius*2.0)
			if move_name in ["Rockslide","Stone Skip","Pebble Spray"]:
				visual.mesh=BoxMesh.new();visual.rotation=Vector3(.3,angle,.4)
			if profile.get("visual","")=="leaf":visual.scale=Vector3(.45,.09,.8);visual.rotation.y=atan2(heading.x,heading.z)
			if profile.get("visual","")=="vine":visual.scale=Vector3(.16,.16,.45)
			if mode=="wave":visual.scale=Vector3(float(profile.get("width",radius*2))*area_scale,.9,radius*2);visual.rotation.y=atan2(heading.x,heading.z)
			shots.append({"pos":origin,"dir":heading,"travel":0.0,"hits":{},"visual":visual,"fuse":-1.0,"done":false})
	elif mode in ["field","heal_field","mine","area","firework"]:
		var center:Vector3=aim if profile.get("anchor","") in ["target","target_follow"] else origin
		for i in copies:
			var offset:=Vector3.ZERO if copies==1 else Vector3(cos(TAU*i/copies),0,sin(TAU*i/copies))*float(profile.get("patch_spread",radius*.65))
			patches.append({"pos":center+offset,"offset":offset})
			var height:=.07 if mode!="mine" else .35
			visuals.append(orb(center+offset+Vector3.UP*.08,Vector3(radius*2,height,radius*2),.22))
	elif mode=="contact":
		actor.motion_lock+=1;owns_motion_lock=true
		visuals.append(orb(origin+Vector3.UP*.65,Vector3(.13,.13,1),.8))
	elif mode=="maneuver":build_maneuver()
	elif mode=="dash":
		actor.motion_lock+=1
		if profile.get("stop_at_target",false):distance=minf(distance,flat(aim-origin).length())
		visuals.append(orb(origin+Vector3.UP*.55,Vector3(radius*2,.7,radius*2),.5))
	elif mode in ["beam","line","cone"]:
		if mode=="beam":actor.motion_lock+=1
		visuals.append(orb(origin+direction*distance*.5+Vector3.UP*.7,Vector3(radius*2,.4,distance),.35))
		visuals[0].rotation.y=atan2(direction.x,direction.z)
		if mode=="cone":
			# An actual wedge mesh makes the visible footprint match the hit test.
			var wedge:=ImmediateMesh.new();wedge.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 20:
				var a:float=-float(profile.angle)+float(profile.angle)*2*i/20
				var b:float=-float(profile.angle)+float(profile.angle)*2*(i+1)/20
				wedge.surface_add_vertex(Vector3.ZERO);wedge.surface_add_vertex(Vector3(sin(a),0,cos(a)));wedge.surface_add_vertex(Vector3(sin(b),0,cos(b)))
			wedge.surface_end();visuals[0].mesh=wedge;visuals[0].position=origin+Vector3.UP*.12;visuals[0].scale=Vector3.ONE*distance*area_scale
	# Self-support activates on the first physics frame, after callers connect.
	if profile.get("visual","") in ["rain","meteor"]:
		# One drop per patch: a Split raindrop launches one arc onto each landing spot.
		for patch in patches:airborne_drops.append(orb(origin+Vector3.UP,Vector3.ONE*.65))
	elif mode=="firework":
		airborne_visual=orb(origin+Vector3.UP,Vector3.ONE*.65)
	if profile.get("visual","")=="root_slam":
		airborne_visual=orb(aim+Vector3.UP*1.8,Vector3(.55,3.5,.55));airborne_visual.rotation.z=-.8
	if profile.get("visual","")=="vine":vine_visual=orb(origin+Vector3.UP*.7,Vector3(.1,.1,.1))
	if mode=="heal_field":flower(origin)
	if move_name=="Rock Ring":
		for i in 12:
			var angle:=TAU*i/12.0
			var rock:=orb(origin+Vector3(sin(angle)*radius*.8,-.4,cos(angle)*radius*.8),Vector3(.45,.9,.45),1.0)
			rock.mesh=BoxMesh.new();rock.rotation=Vector3(.15,angle,.2);erupting_rocks.append(rock)
	if move_name=="Whirlpool":
		for visual in visuals:
			var ring:=TorusMesh.new();ring.inner_radius=.7;ring.outer_radius=1.0;ring.rings=20;ring.ring_segments=8;visual.mesh=ring;visual.scale=Vector3(radius,.5,radius)

func _physics_process(delta:float)->void:
	if done:return
	var actor=source()
	# A move plays out in full once it starts: a stun, bubble, or launch landing on
	# the user no longer cuts a dash or beam short, and a projectile or area effect
	# already in flight still lands if the user is knocked out. Only a knocked-out
	# user's own body-driven dash or beam stops, and the expedition ending stops all.
	if not is_instance_valid(actor):finish(false);return
	if actor.cast_epoch!=epoch and (actor.current_hp>0 or profile.mode in ["dash","beam","contact","maneuver"]):finish(false);return
	elapsed+=delta
	actor.model.animate_species_move(move_name,elapsed,float(profile.get("delay",0.0)))
	for rock in erupting_rocks:
		rock.position.y=origin.y+lerpf(-.4,.6,clampf((elapsed-float(profile.get("delay",0.0)))/.16,0,1))
	for fragment in fragments.duplicate():
		fragment.time-=delta
		fragment.visual.position=Vector3(fragment.point)+Vector3.UP*(maxf(0,fragment.time)/.2*3.0)
		if fragment.time<=0:
			area_hits(fragment.point,1.2*area_scale,damage*.3*base_scale);pulse(fragment.point,1.2*area_scale)
			fragment.visual.queue_free();fragments.erase(fragment)
	var delay:float=profile.get("delay",0.0)
	if is_instance_valid(airborne_visual):
		var progress:=clampf(elapsed/maxf(delay,.01),0,1)
		if profile.get("visual","")=="root_slam":airborne_visual.rotation.z=lerpf(-.8,PI*.5,progress)
		else:
			airborne_visual.position=origin.lerp(aim,progress)+Vector3.UP*(sin(progress*PI)*4.0+.3)
		airborne_visual.visible=elapsed<delay
	for i in airborne_drops.size():
		var drop:MeshInstance3D=airborne_drops[i]
		if not is_instance_valid(drop):continue
		var progress:=clampf(elapsed/maxf(delay,.01),0,1)
		var landing:Vector3=patches[i].pos if i<patches.size() else aim
		drop.position=origin.lerp(landing,progress)+Vector3.UP*(sin(progress*PI)*4.0+.3)
		drop.visible=elapsed<delay
	if is_instance_valid(vine_visual):
		var tip:Vector3=aim
		if not shots.is_empty():tip=shots[0].pos
		if profile.mode=="cone":tip=origin+direction.rotated(Vector3.UP,lerpf(-float(profile.angle),float(profile.angle),minf(1,elapsed/.25)))*distance
		vine_visual.position=(actor.global_position+tip)*.5+Vector3.UP*.65
		vine_visual.scale=Vector3(.13,.13,maxf(.01,actor.global_position.distance_to(tip)))
		if actor.global_position.distance_to(tip)>.01:vine_visual.look_at(tip+Vector3.UP*.65)
	if profile.mode=="area" and profile.get("anchor","")=="self" and not activated:
		for i in patches.size():patches[i].pos=actor.global_position+patches[i].offset;visuals[i].position=patches[i].pos+Vector3.UP*.08
	if elapsed<delay:
		for v in visuals:v.transparency=.5-.25*(elapsed/maxf(delay,.01))
		return
	var mode:String=profile.mode
	match mode:
		"projectile","wave":
			for shot in shots:
				if not shot.done:update_shot(shot,delta)
			if shots.all(func(s):return s.done):finish()
		"contact":update_contact(delta)
		"maneuver":update_maneuver(delta)
		"dash":update_dash(delta)
		"beam","field","heal_field","firework":
			if profile.get("anchor","")=="target_follow":
				var followed=target()
				if not is_instance_valid(followed) or followed.current_hp<=0:finish();return
				for i in patches.size():patches[i].pos=followed.global_position+patches[i].offset;visuals[i].position=patches[i].pos+Vector3.UP*.3
			if profile.get("anchor","")=="self_follow":
				for i in patches.size():patches[i].pos=actor.global_position+patches[i].offset;visuals[i].position=patches[i].pos+Vector3.UP*.08
			if profile.get("spin",false):actor.model.rotation.y+=delta*12
			if elapsed-delay>=next_tick and elapsed-delay<=duration:
				var tick:float=profile.get("tick",.3);next_tick+=tick
				if mode=="beam":linear_hits(damage*tick/1.2)
				else:
					for patch in patches:
						if mode=="heal_field":heal_area(patch.pos,float(profile.amount)*strength)
						elif mode=="firework":
							var spread:float=0.0 if int(round(next_tick/.2))%3==1 else .65
							var fragment:Vector3=patch.pos+Vector3(cos(next_tick*17),0,sin(next_tick*17))*radius*spread
							fragments.append({"point":fragment,"time":.2,"visual":orb(fragment+Vector3.UP*3.0,Vector3(.25,.6,.25),.9)})
						elif profile.get("anchor","")=="target_follow":hit(target(),damage*tick/2.0*base_scale)
						else:area_hits(patch.pos,radius,damage*tick/2.0*base_scale)
				animate_field()
			if elapsed-delay>=duration and fragments.is_empty():finish()
		"mine":
			for patch_index in patches.size():
				var patch:Dictionary=patches[patch_index]
				if patch.get("spent",false):continue
				if not actors_in(patch.pos,float(profile.trigger_radius)*area_scale,true).is_empty():
					area_hits(patch.pos,radius,damage*base_scale);pulse(patch.pos,radius);patch.spent=true
					visuals[patch_index].visible=false
			if patches.all(func(p):return p.get("spent",false)) or elapsed-delay>=duration:finish()
		"area":
			if not activated:
				activated=true
				for patch in patches:area_hits(patch.pos,radius,damage*base_scale);pulse(patch.pos,radius)
			if elapsed-delay>.25:finish()
		"cone","line":
			if not activated:activated=true;linear_hits(damage)
			if elapsed-delay>.25:finish()
		"heal","buff","cleanse":
			if not activated:activated=true;support()
			# Buff casts last as long as their effect; Echo waits for it to end.
			if elapsed>=maxf(.25,duration):finish()
		"combust":
			if not activated:
				activated=true;var victim=target()
				if is_instance_valid(victim) and victim.statuses.has("burn"):
					var burn:Dictionary=victim.statuses.burn
					var bonus:float=burn.amount*burn.time
					victim.statuses.erase("burn");hit(victim,damage+bonus);pulse(victim.global_position,radius)
			if elapsed>.25:finish()
		"copycat":
			if not activated:activated=true;spawn_copy()
			if elapsed>.3:finish()
		"peck":
			if not activated:activated=true;do_peck()
			if elapsed>.35:finish()

func update_shot(shot:Dictionary,delta:float)->void:
	if shot.fuse>=0:
		shot.fuse-=delta
		if shot.fuse<=0:area_hits(shot.pos,float(profile.splash)*area_scale,damage*base_scale);pulse(shot.pos,float(profile.splash)*area_scale);end_shot(shot)
		return
	var actor=source();var victim=target()
	if count("seeking")>0:
		if not is_instance_valid(victim):victim=nearest(shot.pos,[],distance)
		if is_instance_valid(victim):shot.dir=Vector3(shot.dir).slerp(flat(victim.global_position-shot.pos).normalized(),minf(1,delta*5)).normalized()
	var start:Vector3=shot.pos
	var step:float=minf(float(profile.speed)*delta,distance-float(shot.travel))
	var end:Vector3=actor.safe_displacement(start,start+Vector3(shot.dir)*step,.1)
	var blocked:bool=end.distance_to(start+Vector3(shot.dir)*step)>.01
	var hits:Array=[]
	for other in opponents():
		if shot.hits.has(other.get_instance_id()) and profile.mode!="wave":
			if not profile.has("repeat_hit") or elapsed-float(shot.hits[other.get_instance_id()])<float(profile.repeat_hit):continue
		var hit_radius:float=radius+.5
		if profile.mode=="wave":
			var relative:Vector3=other.global_position-end;var across:=Vector3(shot.dir).cross(Vector3.UP)
			if absf(relative.dot(across))<=float(profile.get("width",2))*area_scale*.5+.5 and absf(relative.dot(shot.dir))<=radius+.5+step:hits.append({"actor":other,"t":0.0})
		else:
			var t:=segment_hit(start,end,other.global_position,hit_radius)
			if t>=0:hits.append({"actor":other,"t":t})
	hits.sort_custom(func(a,b):return a.t<b.t)
	for record in hits:
		var other=record.actor
		if not is_instance_valid(other) or other.current_hp<=0:continue
		var point:Vector3=start.lerp(end,record.t)
		if profile.has("fuse"):
			shot.pos=point;shot.fuse=float(profile.fuse);shot.visual.position=point+Vector3.UP*.15;return
		if not shot.hits.has(other.get_instance_id()) or (profile.has("repeat_hit") and elapsed-float(shot.hits[other.get_instance_id()])>=float(profile.repeat_hit)):
			shot.hits[other.get_instance_id()]=elapsed
			if profile.has("splash"):area_hits(point,float(profile.splash)*area_scale,damage*base_scale);pulse(point,float(profile.splash)*area_scale)
			else:hit(other,damage*base_scale*float(profile.get("direct_scale",1.0)))
		if profile.get("carry",false) and other.current_hp>0:other.displace(Vector3(shot.dir)*step)
		if profile.mode=="projectile" and not profile.get("pierce",false):end_shot(shot);return
	shot.pos=end;shot.travel+=step;shot.visual.position=end+Vector3.UP*.7
	if profile.get("skip",false):shot.visual.scale=Vector3(1,.25,1);shot.visual.position.y=end.y+.15+absf(sin(shot.travel*4.0))*.5
	if blocked:
		# A shot stopped by a tree or boulder breaks against it.
		var splash:float=float(profile.get("splash",0.0))*area_scale
		if splash>0.0:prop_hits(end,splash,damage*base_scale)
		else:prop_hits(end+Vector3(shot.dir)*.6,radius+.3,damage*base_scale*float(profile.get("direct_scale",1.0)))
	if blocked or shot.travel>=distance-.001:
		if profile.has("fuse"):shot.fuse=float(profile.fuse)
		else:end_shot(shot)

func end_shot(shot:Dictionary)->void:
	shot.done=true;shot.visual.visible=false

func update_dash(delta:float)->void:
	var actor=source()
	var start:Vector3=actor.global_position
	var step:float=minf(float(profile.speed)*delta,maxf(0,distance-travel))
	var end:Vector3=actor.safe_displacement(start,start+direction*step,.55)
	actor.global_position=end;actor.model.look_at(end+direction,Vector3.UP,true);travel+=step
	if profile.get("leap",false):actor.model.position.y=sin(clampf(travel/maxf(distance,.01),0,1)*PI)*1.5
	visuals[0].position=end+Vector3.UP*.55
	for other in opponents():
		if not dash_hits.has(other.get_instance_id()) and segment_hit(start,end,other.global_position,radius+.5)>=0:
			dash_hits[other.get_instance_id()]=true;hit(other,damage)
			if profile.get("stop_on_hit",false):travel=distance;break
	if profile.has("trail") and (patches.is_empty() or Vector3(patches[-1].pos).distance_to(end)>.6):
		patches.append({"pos":end,"time":float(profile.trail)*duration_scale,"tick":0.0})
		var trail_width:=float(profile.get("trail_radius",.65))*2.0
		visuals.append(orb(end+Vector3.UP*.12,Vector3(trail_width,.25,trail_width),.4 if move_name=="Toxic Drift" else .65))
	for patch in patches:
		patch.time-=delta;patch.tick-=delta
		if patch.time>0 and patch.tick<=0:patch.tick=.4;area_hits(patch.pos,float(profile.get("trail_radius",.8)),damage*.12)
	if travel>=distance-.001 or end.distance_to(start+direction*step)>.01:
		if profile.has("end_burst"):
			area_hits(end,float(profile.end_burst)*area_scale,damage*float(profile.get("burst_scale",1.0)));pulse(end,float(profile.end_burst)*area_scale)
		if profile.has("trail"):
			# Leave the flames behind, but release the user to move and cast.
			profile.mode="field";profile.anchor="trail";profile.tick=.4
			profile.duration=float(profile.trail)*duration_scale;duration=profile.duration;elapsed=0;next_tick=.4;radius=float(profile.get("trail_radius",.8))
			actor.motion_lock=maxi(0,actor.motion_lock-1);visuals[0].visible=false
		else:finish()

func update_contact(delta:float)->void:
	var actor=source();var victim=target()
	if not is_instance_valid(victim) or victim.current_hp<=0 or actor.current_hp<=0:finish();return
	var gap:=flat(victim.global_position-actor.global_position)
	if gap.length()>distance+.5:finish();return
	if profile.get("attach",false):
		var desired:Vector3=victim.global_position-gap.normalized()*.75
		var proposed:Vector3=actor.global_position.move_toward(desired,12.0*delta)
		actor.global_position=actor.safe_displacement(actor.global_position,proposed,.55)
		if flat(victim.global_position-actor.global_position).length()>1.2:
			if elapsed>1.0:finish()
			return
	contact_time+=delta
	if profile.get("restrain",false):victim.add_status("root",.18,1.0,actor)
	var beam_start:Vector3=actor.global_position+Vector3.UP*.65
	var beam_end:Vector3=victim.global_position+Vector3.UP*.65
	visuals[0].position=(beam_start+beam_end)*.5;visuals[0].scale=Vector3(.13,.13,maxf(.01,beam_start.distance_to(beam_end)))
	if beam_start.distance_to(beam_end)>.01:visuals[0].look_at(beam_end)
	if contact_time>=next_tick:
		var tick:float=profile.get("tick",.4);next_tick+=tick
		hit(victim,damage*tick/1.2)
	if contact_time>=duration:
		if profile.has("release_knockback") and victim.current_hp>0:
			victim.displace(gap.normalized()*float(profile.release_knockback)*force_scale)
		finish()

func build_maneuver()->void:
	var actor=source();var victim=target()
	actor.motion_lock+=1;owns_motion_lock=true
	var center:Vector3=aim
	var across:=direction.cross(Vector3.UP)
	match str(profile.pattern):
		"touch":maneuver_points=[center-direction*.65,origin]
		"side":maneuver_points=[center+across*.7,center-across*1.4]
		"zigzag":maneuver_points=[center+across*.6,center-direction*.6,center-across*.6,center+direction*.6,origin]
	visuals.append(orb(origin+Vector3.UP*.5,Vector3(.6,.6,.6),.5))

func update_maneuver(delta:float)->void:
	var actor=source()
	if actor.current_hp<=0 or maneuver_index>=maneuver_points.size():finish();return
	var start:Vector3=actor.global_position;var goal:Vector3=maneuver_points[maneuver_index]
	var desired:=start.move_toward(goal,float(profile.speed)*delta)
	var end:Vector3=actor.safe_displacement(start,desired,.55);actor.global_position=end;visuals[0].position=end+Vector3.UP*.5
	var returning:bool=profile.pattern in ["touch","zigzag"] and maneuver_index==maneuver_points.size()-1
	if not returning:
		for victim in opponents():
			if not dash_hits.has(victim.get_instance_id()) and segment_hit(start,end,victim.global_position,radius+.5)>=0:
				dash_hits[victim.get_instance_id()]=true;hit(victim,damage)
	if end.distance_to(desired)>.05:finish();return
	if end.distance_to(goal)<.08:
		maneuver_index+=1;dash_hits.clear()
		if maneuver_index>=maneuver_points.size():finish()

func linear_hits(amount:float)->void:
	var actor=source();var end:Vector3=actor.safe_displacement(origin,origin+direction*distance,.05)
	for other in opponents():
		var relative:=flat(other.global_position-origin)
		if profile.mode=="cone":
			if relative.length()>distance*area_scale+.5 or direction.dot(relative.normalized())<cos(float(profile.angle)):continue
			if actor.safe_displacement(origin,other.global_position,.05).distance_to(other.global_position)>.2:continue
		elif segment_hit(origin,end,other.global_position,radius+.5)<0:continue
		hit(other,amount)
	var field=get_parent()
	if field!=null and field.has_method("props_in"):
		for prop in field.props_in(origin,distance*area_scale):
			if profile.mode=="cone":
				var relative:Vector3=flat(prop.global_position-origin)
				if direction.dot(relative.normalized())>=cos(float(profile.angle)):prop.hit(amount)
			elif segment_hit(origin,end,prop.global_position,radius+.5)>=0:prop.hit(amount)

func area_hits(center:Vector3,size:float,amount:float)->void:
	for other in actors_in(center,size,true):hit(other,amount,center)
	prop_hits(center,size,amount)

# Destructible field props (trees, boulders) take damage from anything that reaches them.
func prop_hits(center:Vector3,size:float,amount:float)->void:
	var field=get_parent()
	if field==null or not field.has_method("props_in"):return
	for prop in field.props_in(center,size):prop.hit(amount)

func hit(victim,amount:float,center:Vector3=Vector3.INF,chain_depth:int=0,visited:Array=[])->void:
	var actor=source()
	if not is_instance_valid(actor) or done or not is_instance_valid(victim) or victim.current_hp<=0:return
	if not victim.accepts_hit_from(actor):return
	# A no-damage move (Scare) only applies its status/effect; it never hurts.
	var actual:float=victim.take_damage(0.0 if profile.get("no_damage",false) else amount,actor)
	if actor.current_hp>0:
		actor.receive_shared_heal(actual*(.15*count("drain")+float(profile.get("leech",0))))
	if victim.current_hp>0:
		var pivot:Vector3=origin if center==Vector3.INF else center
		var away:=flat(victim.global_position-pivot).normalized()
		if away.length()<.01:away=direction
		var effect_scale:float=strength*base_scale*pow(.6,chain_depth)
		var push:float=float(profile.get("knockback",0.0))*force_scale*effect_scale
		if count("force")>0 and profile.get("physical",false) and push==0:push=.8*force_scale
		if push>0:victim.displace(away*push)
		if profile.has("pull"):
			var to_center:Vector3=actor.global_position-victim.global_position
			victim.displace(flat(to_center).normalized()*minf(float(profile.pull)*force_scale*effect_scale,maxf(0,flat(to_center).length()-.8)))
		if profile.has("swirl"):victim.displace(away.cross(Vector3.UP)*float(profile.swirl)*force_scale)
		if profile.has("launch"):victim.add_status("launch",.8,float(profile.launch)*force_scale*effect_scale,actor)
		if profile.has("burn"):victim.add_status("burn",float(profile.burn)*duration_scale,damage*.12*base_scale*pow(.6,chain_depth),actor,.15*count("drain"))
		if profile.has("poison") and randf()<minf(1.0,float(profile.get("poison_chance",1.0))+(float(victim.statuses.contaminated.amount) if victim.statuses.has("contaminated") else 0.0)):victim.add_status("poison",float(profile.poison)*duration_scale,damage*.10*base_scale*pow(.6,chain_depth),actor,.15*count("drain"))
		if profile.has("status") and randf()<float(profile.get("status_chance",1.0)):
			# Control statuses (slow, confuse, defense_down) carry an explicit fractional
			# "amount"; leech scales with damage; everything else uses the effect scale.
			var magnitude:float=damage*.12*base_scale*pow(.6,chain_depth) if profile.status=="leech" else float(profile.get("amount",effect_scale))
			victim.add_status(profile.status,float(profile.status_duration)*duration_scale*pow(.6,chain_depth),magnitude,actor,.15*count("drain"))
		# A Honk interrupts (a short stun); a Scare sends the victim fleeing.
		if profile.get("interrupt",false):victim.add_status("stun",.4,1.0,actor)
		if profile.get("flee",false):victim.retreating=true
	if chain_depth<count("chain"):
		var excluded:=visited.duplicate();excluded.append(victim.get_instance_id())
		var next=nearest(victim.global_position,excluded,4.0)
		if is_instance_valid(next):
			var chain_details:=details.duplicate();chain_details.chain=true
			actor.move_used.emit(actor,move_name,next,chain_details)
			ribbon(victim.global_position,next.global_position);hit(next,amount*.6,center,chain_depth+1,excluded)

func support()->void:
	var actor=source();var mode:String=profile.mode
	if mode=="heal":heal_area(origin,float(profile.amount)*strength);pulse(origin,radius);return
	# Ally-targeted buffs (Helping Hand) land on the strongest nearby teammate,
	# falling back to the caster when it is alone so the move is never wasted.
	var primary=actor
	if profile.get("ally",false):
		var mate=best_ally(actor)
		if mate!=null:primary=mate
	var recipients:Array=[primary]
	# Team buffs (Cheer, Shelter, Tailwind) reach the caster and every nearby ally.
	if profile.get("team",false):
		for mate in actors_in(actor.global_position,4.0,false):
			if not recipients.has(mate):recipients.append(mate)
	if count("sharing")>0:recipients.append_array(actors_in(origin,3.2,false).filter(func(a):return a!=primary))
	for other in recipients:
		var share:float=1.0 if other==primary else .55
		if mode=="cleanse":
			if profile.has("self_cost") and other==actor:other.take_damage(minf(other.current_hp-1,other.max_hp*float(profile.self_cost)))
			other.cleanse()
		else:other.add_status(profile.status,duration*share,float(profile.amount)*strength*share,actor)
		pulse(other.global_position,.9)

func best_ally(actor):
	var best=null;var best_attack:=-1.0
	for other in actors_in(actor.global_position,8.0,false):
		if other==actor:continue
		if other.attack>best_attack:best_attack=other.attack;best=other
	return best

# Copycat replays the most recent move an ally used, at reduced strength and with
# the copier's own Move Stones. With no ally move on record it falls back to a
# basic strike so the move is never wasted.
func spawn_copy()->void:
	var actor=source()
	if not is_instance_valid(actor):return
	var copied:="";var best_time:=-1.0
	for mate in actors_in(actor.global_position,12.0,false):
		if mate==actor:continue
		var name:=str(mate.last_move_name)
		var t:float=float(mate.last_move_time)
		if name!="" and name!="Copycat" and GameData.MOVES.has(name) and t>best_time:best_time=t;copied=name
	if copied=="":copied="Mind Jab"
	var clone=get_script().new()
	clone.setup(actor,{"name":copied,"slots":int(entry.get("slots",1)),"stones":entry.get("stones",[])},target(),strength*.6,false)
	get_parent().add_child(clone)

# Peck (and Cross Peck) strikes every living enemy within reach exactly once, then
# the pecker settles beside the last one it hit.
func do_peck()->void:
	var actor=source()
	if not is_instance_valid(actor):return
	var last=null
	for other in opponents():
		if not is_instance_valid(other) or other.current_hp<=0:continue
		if flat(other.global_position-origin).length()>distance+.5:continue
		hit(other,damage);pulse(other.global_position,radius);last=other
	if is_instance_valid(last):
		var approach:Vector3=last.global_position-flat(last.global_position-actor.global_position).normalized()*1.1
		actor.global_position=actor.safe_displacement(actor.global_position,actor.clamp_point(approach),.4)

func heal_area(center:Vector3,amount:float)->void:
	var extra:float=1.8 if count("sharing")>0 else 0.0
	for other in actors_in(center,radius+extra,false):
		var multiplier:float=.55 if flat(other.global_position-center).length()>radius else 1.0
		other.receive_shared_heal(other.max_hp*amount*multiplier)

func opponents()->Array:
	var result:Array=[]
	for child in get_parent().get_children():
		if child is CharacterBody3D and child.get("current_hp")!=null and child.current_hp>0 and child.enemy!=source_enemy:result.append(child)
	return result

func actors_in(center:Vector3,size:float,opposing:bool)->Array:
	var result:Array=[]
	for child in get_parent().get_children():
		if child is CharacterBody3D and child.get("current_hp")!=null and child.current_hp>0 and (child.enemy!=source_enemy)==opposing and flat(child.global_position-center).length()<=size+.5:result.append(child)
	return result

func nearest(center:Vector3,excluded:Array,size:float):
	var best=null;var best_distance:=size
	for other in opponents():
		if excluded.has(other.get_instance_id()):continue
		var d:=flat(other.global_position-center).length()
		if d<best_distance:best_distance=d;best=other
	return best

static func flat(v:Vector3)->Vector3:
	return Vector3(v.x,0,v.z)

static func segment_hit(a:Vector3,b:Vector3,point:Vector3,size:float)->float:
	var d:=flat(b-a);var offset:=flat(a-point)
	var c:=offset.length_squared()-size*size
	if c<=0:return 0.0
	var length_squared:=d.length_squared()
	if length_squared<.000001:return -1.0
	var dot:=offset.dot(d);var discriminant:=dot*dot-length_squared*c
	if discriminant<0:return -1.0
	var t:=(-dot-sqrt(discriminant))/length_squared
	return t if t>=0 and t<=1 else -1.0

func orb(point:Vector3,dimensions:Vector3,alpha:float=.8)->MeshInstance3D:
	var visual:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1.0;sphere.radial_segments=12;sphere.rings=6
	visual.mesh=sphere;visual.position=point;visual.scale=dimensions.max(Vector3.ONE*.01)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color,alpha);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	visual.material_override=mat;add_child(visual);return visual

func pulse(point:Vector3,size:float)->void:
	var visual:=orb(point+Vector3.UP*.3,Vector3(size*1.5,.6,size*1.5),.55)
	var look:String=profile.get("visual","")
	if look in ["pillar","plant","roots","thorns","root_slam"]:visual.scale=Vector3(size,3,size)
	var tween:=visual.create_tween();tween.set_parallel(true);tween.tween_property(visual,"scale",visual.scale*1.3,.22);tween.tween_property(visual,"transparency",1.0,.22);tween.chain().tween_callback(visual.queue_free)

func ribbon(a:Vector3,b:Vector3)->void:
	var visual:=orb((a+b)*.5+Vector3.UP*.6,Vector3(.12,.12,a.distance_to(b)),.9);visual.look_at(b+Vector3.UP*.6)
	var tween:=visual.create_tween();tween.tween_property(visual,"transparency",1.0,.2);tween.tween_callback(visual.queue_free)

func animate_field()->void:
	for patch in patches:
		var look:String=profile.get("visual","")
		if look=="rain":
			for i in 7:
				var point:Vector3=patch.pos+Vector3(cos(i*2.4+elapsed),0,sin(i*2.4+elapsed))*radius*.75
				var drop:=orb(point+Vector3.UP*2.5,Vector3(.1,.7,.1),.7)
				var tween:=drop.create_tween();tween.tween_property(drop,"position",point,.3);tween.tween_callback(drop.queue_free)
		elif look in ["eruptions","cloud","flower"]:pulse(patch.pos,radius*.65)
		else:
			for visual in visuals:visual.rotation.y+=.35

func flower(point:Vector3)->void:
	orb(point+Vector3.UP*.45,Vector3(.12,.9,.12),1)
	for i in 6:
		var petal:=orb(point+Vector3(cos(i*TAU/6)*.32,.85,sin(i*TAU/6)*.32),Vector3(.55,.15,.55),.9)
		petal.material_override.albedo_color=Color(1,.8,.85,.9)
	var center:=orb(point+Vector3.UP*.9,Vector3(.35,.2,.35),1)
	center.material_override.albedo_color=Color(1,.85,.2)

func finish(emit_completion:bool=true)->void:
	if done:return
	done=true
	var actor=source()
	if is_instance_valid(actor):
		actor.model.animate_species_move("",0,0)
		if profile.get("jump",false) or profile.get("leap",false):actor.model.position.y=0.0
		if owns_motion_lock:actor.motion_lock=maxi(0,actor.motion_lock-1);owns_motion_lock=false
	if is_instance_valid(actor) and profile.mode in ["dash","beam"]:actor.motion_lock=maxi(0,actor.motion_lock-1)
	if emit_completion:finished.emit()
	set_physics_process(false)
	# Let impact pulses finish rendering, with no further gameplay updates.
	if emit_completion:
		var cleanup:=create_tween();cleanup.tween_interval(.24);cleanup.tween_callback(queue_free)
	else:queue_free()
