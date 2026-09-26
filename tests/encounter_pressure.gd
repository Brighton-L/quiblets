extends SceneTree
class SpawnFixture extends Expedition3D:
	func pick_spawn_point(_for_boss:=false)->int:return 0
	func patch_zone(_point:Vector2)->int:return 0
	func encounter_positions(center:Vector2,count:int)->Array[Vector2]:
		var result:Array[Vector2]=[]
		for i in count:result.append(center+Vector2(i*2,0))
		return result
	func play_spawn_drop(_actor:QuibletActor3D,_delay:=0.0,_landing_squash:=true)->void:pass
	func boss_intro(_boss:QuibletActor3D)->void:pass
func _initialize():call_deferred("run")
func run():
	for kind in ["level","boss"]:
		var field:=SpawnFixture.new();root.add_child(field);field.set_physics_process(false)
		field.stage_kind=kind;field.stage_area_index=13;field.stage_level=53;field.team_average_level=100;field.spawn_points.assign([Vector2.ZERO]);field.spawn_rng.seed=23
		field.team_data=[GameData.make_quiblet(0,60),GameData.make_quiblet(1,60),GameData.make_quiblet(2,60)]
		field.enemy_bonus=GameData.stage_enemy_stone_bonus(53);field.spawn_boss_wave()
		var scaling:=GameData.enemy_scaling(13)
		var boss_count:=0;var helpers:=0
		for actor in field.enemies:
			actor.set_physics_process(false)
			var boss:bool=actor.get_meta("level_boss",false)
			var hp_scale:float=(4.5 if kind=="boss" else 2.4) if boss else 1.4
			var damage_scale:float=(1.18 if kind=="boss" else 1.15) if boss else 1.08
			assert(is_equal_approx(actor.max_hp,GameData.max_hp(actor.data)*scaling.hp*hp_scale))
			assert(is_equal_approx(actor.damage_multiplier,scaling.damage*damage_scale))
			assert(actor.current_hp==actor.max_hp)
			if boss:boss_count+=1
			else:helpers+=1;assert(actor.get_meta("boss_helper",false))
		assert(boss_count==1 and helpers==3)
		field.free()
	print("ENCOUNTER_PRESSURE_OK: regular-stage bosses, dedicated bosses, helpers, full HP and damage scaling")
	quit()
