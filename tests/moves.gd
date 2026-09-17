extends SceneTree

const BEHAVIORS=preload("res://scripts/move_behaviors.gd")
var arena:Node3D
var user:QuibletActor3D
var victim:QuibletActor3D
var ally:QuibletActor3D
var failures:Array[String]=[]
var checks:=0

func _initialize()->void:
	call_deferred("run")

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures.append(message);push_error(message)

func actor(pos:Vector3,enemy:bool)->QuibletActor3D:
	var result:=QuibletActor3D.new();result.setup(GameData.make_quiblet(0,10),enemy);arena.add_child(result);result.position=pos;result.set_physics_process(false);result.max_hp=10000;result.current_hp=10000;result.attack=30;return result

func fixture()->void:
	if is_instance_valid(arena):arena.free()
	arena=Node3D.new();root.add_child(arena)
	user=actor(Vector3.ZERO,false);victim=actor(Vector3(2,0,0),true);ally=actor(Vector3(1,0,1),false)

func cast(move_name:String,stones:Array=[]):
	user.data.moves=[{"name":move_name,"slots":6,"stones":stones}];user.move_cooldowns=[0.0];user.move_cooldown_totals=[0.0]
	user.use_move(0,victim)
	for child in arena.get_children():
		if child.get("move_name")==move_name and not child.done:
			child.set_physics_process(false);return child
	return null

func advance(seconds:float)->void:
	for frame in ceili(seconds*60):
		for child in arena.get_children():
			if child is QuibletActor3D and child.current_hp>0:child.update_statuses(1.0/60)
			elif child.has_method("update_shot") and not child.done:child._physics_process(1.0/60)

func run()->void:
	seed(76341)
	check(BEHAVIORS.PROFILES.size()==GameData.MOVES.size(),"Every listed move must have an explicit runtime profile")
	# Exercise EVERY move without stones: each must change its intended target
	# or support state. Then test spatial/timing properties independently below.
	for move_name in GameData.MOVES:
		fixture();var p:Dictionary=BEHAVIORS.profile(move_name)
		user.current_hp=2000;ally.current_hp=2000
		if p.mode=="mine":victim.position.x=1
		if p.mode=="cleanse":user.add_status("burn",4,2,victim)
		if p.mode=="combust":victim.add_status("burn",4,2,user)
		var effect=cast(move_name)
		check(is_instance_valid(effect),move_name+" did not create a cast")
		advance(1.8)
		if p.mode=="buff":check((ally if p.get("ally",false) else user).statuses.has(p.status),move_name+" did not grant its specific buff")
		elif p.mode=="cleanse":check(not user.statuses.has("burn"),move_name+" did not cleanse")
		elif p.mode in ["heal","heal_field"]:check(user.current_hp>2000 and ally.current_hp>2000,move_name+" did not heal both user and nearby ally")
		elif p.get("no_damage",false):check(is_equal_approx(victim.current_hp,10000.0) and (victim.statuses.has(p.get("status","")) or victim.retreating),move_name+" should apply its effect without dealing damage")
		else:check(victim.current_hp<10000,move_name+" did not apply damage through its delivery mechanic")
		if p.has("status") and p.mode!="buff" and p.status!="leech":check(victim.statuses.has(p.status),move_name+" did not apply "+p.status)
		if p.has("burn"):check(victim.statuses.has("burn"),move_name+" did not apply Burn")
		if p.mode=="dash":check(user.position.x>1,move_name+" did not move the user")
	# Every compatible modifier is also exercised against every move. This
	# catches profile paths that would otherwise only run after equipping stones.
	for name in GameData.MOVES:
		for stone in GameData.MOVE_STONES:
			if stone.effect=="link" or not BEHAVIORS.supports(name,stone.effect):continue
			fixture();user.current_hp=2000
			var modified=cast(name,[stone.effect])
			check(is_instance_valid(modified),name+" failed to cast with "+stone.effect)
			advance(.15)
	# Projectile speed, missed shots, independent Split paths, piercing, homing.
	fixture();victim.position.x=4;cast("Water Shot");advance(.08);check(victim.current_hp==10000,"Water Shot hits before its projectile arrives");advance(.25);check(victim.current_hp<10000,"Water Shot never collided")
	fixture();cast("Water Shot");victim.position.z=2;advance(.5);check(victim.current_hp==10000,"Non-homing projectile damaged a target that dodged its path")
	fixture();var split=cast("Water Shot",["split"]);check(split.shots.size()==3,"Split does not create three independent projectiles");check(split.shots[0].dir!=split.shots[1].dir,"Split copies share the same trajectory")
	fixture();var rainsplit=cast("Rain Drop",["split"]);check(rainsplit.patches.size()==3 and rainsplit.airborne_drops.size()==3,"Split Rain Drop launches three separate drops")
	fixture();cast("Water Shot",["seeking"]);victim.position.z=1;advance(.6);check(victim.current_hp<10000,"Seeking did not steer toward a moving target")
	fixture();var behind:=actor(Vector3(3.5,0,0),true);cast("Hydro Shot");advance(.5);check(victim.current_hp<10000 and behind.current_hp<10000,"Hydro Shot did not pierce two enemies")
	fixture();cast("Seed Pop");advance(.3);check(victim.current_hp==10000,"Seed Pop damaged before its fuse");advance(.7);check(victim.current_hp<10000,"Seed Pop did not burst after its fuse")
	fixture();user.obstacle_rects=[Rect2(.9,-1,.4,2)];cast("Water Shot");advance(.5);check(victim.current_hp==10000,"Projectile passed through a level obstacle")
	# Spatial shapes: rear/side targets must not take forward-only hits.
	for name in ["Spray","Vine Whip","Vine Spear","Water Jet"]:
		fixture();var rear:=actor(Vector3(-1,0,0),true);var side:=actor(Vector3(0,0,2),true);cast(name);advance(.4)
		check(victim.current_hp<10000 and rear.current_hp==10000 and side.current_hp==10000,name+" did not respect its direction/width")
	fixture();cast("Water Jet");advance(.05);var jet_hp:=victim.current_hp;advance(.5);check(victim.current_hp<jet_hp,"Water Jet did not hit repeatedly")
	fixture();var far_side:=actor(Vector3(2,0,2.3),true);cast("Tidal Wave");advance(.7);check(far_side.current_hp<10000 and victim.position.x>2.3,"Tidal Wave did not hit its broad front and carry enemies")
	fixture();cast("Splash Dash");advance(.5);check(user.position.x>2.8 and victim.current_hp<10000,"Splash Dash did not sweep its route")
	fixture();user.obstacle_rects=[Rect2(.9,-1,.4,2)];cast("Splash Dash");advance(.5);check(user.position.x<.9 and victim.current_hp==10000,"Dash passed through an obstacle")
	fixture();cast("Undertow");advance(.1);check(victim.position.x<1,"Undertow did not pull inward")
	fixture();cast("Backwash");advance(.1);check(victim.position.x>4,"Backwash did not strongly knock back")
	fixture();cast("Water Spout");advance(.65);check(victim.statuses.has("launch") and victim.model.position.y>.1,"Water Spout did not launch its victim");advance(1);check(not victim.statuses.has("launch") and victim.model.position.y==0,"Launched victim never landed")
	fixture();cast("Rain Drop");advance(.4);check(victim.current_hp==10000,"Rain Drop hit before falling");victim.position.z=4;advance(.6);check(victim.current_hp==10000,"Rain Drop followed a target after the impact location was set")
	fixture();cast("Downpour");advance(.5);var rain_hp:=victim.current_hp;advance(.7);check(victim.current_hp<rain_hp,"Downpour was not persistent")
	for name in ["Seed Mine","Fire Mine"]:
		fixture();victim.position.x=5;cast(name);advance(1);check(victim.current_hp==10000,name+" triggered without a nearby enemy");victim.position.x=1;advance(.1);check(victim.current_hp<10000,name+" did not trigger on approach")
	# Status interactions and their expiry, not just visual flags.
	fixture();cast("Guard");advance(.1);var shield_hp:=user.current_hp;user.take_damage(30,victim);check(user.current_hp==shield_hp,"Guard healed instead of absorbing damage");user.take_damage(4000,victim);check(not user.statuses.has("shield") and user.current_hp<shield_hp,"Shield did not break when exhausted")
	fixture();cast("Rootbind");advance(.1);check(victim.movement_locked() and not victim.actions_locked(),"Roots should immobilize without blocking attacks");advance(3.2);check(not victim.movement_locked(),"Roots did not expire")
	fixture();cast("Thorn Armor");advance(.1);user.take_damage(100,victim);check(victim.current_hp==9960,"Thorn Armor did not reflect damage")
	fixture();user.current_hp=2000;cast("Cocoon");advance(.2);check(user.actions_locked() and user.current_hp>2000,"Cocoon did not lock actions and heal gradually");var invalid=cast("Water Shot");check(invalid==null,"Cocoon allowed another move");advance(4);check(not user.actions_locked(),"Cocoon did not unlock actions on completion")
	fixture();cast("Heat Haze");advance(.1);var misses:=0
	for i in 1000:
		if not user.accepts_hit_from(victim):misses+=1
	check(misses>350 and misses<550,"Heat Haze did not reduce actual hit accuracy")
	fixture();cast("Smoke Cloud");advance(.1);misses=0
	for i in 1000:
		if not user.accepts_hit_from(victim):misses+=1
	check(misses>400 and misses<600,"Smoke Cloud did not reduce the affected enemy's accuracy")
	fixture();cast("Ignite");advance(.3);var ignite_hp:=victim.current_hp;advance(.5);check(victim.current_hp<ignite_hp,"Ignite did not deal damage over time")
	fixture();user.current_hp=1000;cast("Leech Bloom");advance(.6);check(user.current_hp>1000,"Leech Bloom did not heal from damage")
	fixture();user.add_status("burn",3,1,victim);cast("Cauterize");advance(.1);check(not user.statuses.has("burn") and user.current_hp<10000,"Cauterize did not pay its health cost and cleanse")
	fixture();cast("Growth Spurt");advance(.1);var enlarged=cast("Vine Whip");check(enlarged.area_scale>1 and enlarged.force_scale>1,"Growth Spurt did not enlarge physical attack size and force")
	# Helping Hand empowers a nearby ally (not the caster) and raises its damage.
	fixture();cast("Helping Hand");advance(.1);check(ally.statuses.has("empower") and not user.statuses.has("empower"),"Helping Hand should empower an ally rather than the user")
	fixture();user.attack=100;victim.current_hp=10000;user.data.moves=[{"name":"Mind Jab","slots":6,"stones":[]}];user.move_cooldowns=[0.0];user.move_cooldown_totals=[0.0];user.use_move(0,victim);advance(.5);var base_loss:=10000.0-victim.current_hp
	fixture();user.attack=100;victim.current_hp=10000;user.add_status("empower",8,1.5,ally);user.data.moves=[{"name":"Mind Jab","slots":6,"stones":[]}];user.move_cooldowns=[0.0];user.move_cooldown_totals=[0.0];user.use_move(0,victim);advance(.5);check(10000.0-victim.current_hp>base_loss*1.4,"Empower raises the empowered Quiblet's outgoing damage")
	# New status mechanics: poison ticks, slow/hasten alter speed, confuse makes
	# the attacker miss, defense_down raises damage taken, and team buffs spread.
	fixture();cast("Poison Spit");advance(.3);check(victim.statuses.has("poison"),"Poison Spit did not poison");var poison_hp:=victim.current_hp;advance(.6);check(victim.current_hp<poison_hp,"Poison did not deal damage over time")
	fixture();var base_speed:float=user.speed;user.add_status("slow",3,.5);check(user.current_speed()<base_speed,"Slow did not reduce movement speed");user.statuses.erase("slow");user.add_status("hasten",3,.4);check(user.current_speed()>base_speed,"Tailwind hasten did not raise movement speed")
	fixture();user.add_status("confuse",3,.9);var confused_misses:=0
	for i in 400:
		if not victim.accepts_hit_from(user):confused_misses+=1
	check(confused_misses>250,"Confuse did not make the attacker miss")
	fixture();victim.current_hp=10000;victim.take_damage(100.0,user,false);var normal_hit:=10000.0-victim.current_hp;victim.current_hp=10000;victim.add_status("defense_down",4,.5);victim.take_damage(100.0,user,false);check(10000.0-victim.current_hp>normal_hit*1.4,"Corrode defense_down did not raise damage taken")
	fixture();cast("Cheer");advance(.1);check(user.statuses.has("empower") and ally.statuses.has("empower"),"A team buff should reach the caster and nearby allies")
	# Copycat replays an ally's most recent move: an ally that last used Ignite makes Copycat apply Burn.
	fixture();ally.last_move_name="Ignite";ally.last_move_time=Time.get_ticks_msec()/1000.0;cast("Copycat");advance(.5);check(victim.statuses.has("burn") or victim.current_hp<10000,"Copycat did not replay an ally move")
	fixture();var pecked:=actor(Vector3(-2,0,1),true);cast("Peck");advance(.4);check(victim.current_hp<10000 and pecked.current_hp<10000,"Peck did not strike every living enemy once")
	# Stone modifiers affect real delivery and durations, rather than fake hits.
	fixture();var normal=cast("Downpour");var normal_duration:float=normal.duration;normal.finish(false);var lingering=cast("Downpour",["lingering"]);check(lingering.duration>normal_duration,"Lingering does not extend a real persistent field")
	fixture();var ordinary=cast("Fireball");var ordinary_area:float=ordinary.area_scale;ordinary.finish(false);var blast=cast("Fireball",["blast"]);check(blast.area_scale>ordinary_area,"Blast did not expand the splash size")
	fixture();var plain=cast("Water Shot");var plain_range:float=plain.distance;plain.finish(false);var reach=cast("Water Shot",["reach"]);check(reach.distance>plain_range,"Reach did not extend projectile travel")
	fixture();user.current_hp=1000;victim.current_hp=10;cast("Water Shot",["drain"]);advance(.3);check(is_equal_approx(user.current_hp,1001.5),"Drain healed from nominal damage instead of actual damage dealt")
	fixture();cast("Guard",["sharing"]);advance(.1);check(ally.statuses.has("shield") and ally.statuses.shield.amount<user.statuses.shield.amount,"Sharing did not grant a reduced shield to nearby allies")
	fixture();var canceled=cast("Water Shot");user.cast_epoch+=1;advance(.5);check(canceled.done and victim.current_hp==10000,"Stale cast continued after knockout/expedition end")
	fixture();var freed=cast("Water Shot",["seeking"]);victim.free();advance(.5);check(freed.done,"Projectile did not safely finish after its target was freed")
	arena.free()
	print("QUIBLETS_MOVES checks=",checks," moves=",GameData.MOVES.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
