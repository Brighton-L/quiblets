extends QuibletActor3D

var lifetime:=7.0

func configure(caster:QuibletActor3D,seconds:float,hp_fraction:float)->void:
 setup(caster.data,caster.enemy)
 arena=caster.arena;obstacle_rects=caster.obstacle_rects.duplicate();model.rotation=caster.model.rotation
 lifetime=seconds;max_hp=maxf(1.0,caster.max_hp*hp_fraction);current_hp=max_hp
 collision_layer=0;collision_mask=0;bonus_totals.clear()
 set_meta("psychic_decoy",true)
 data.moves=[];move_cooldowns.clear();move_cooldown_totals.clear()
 model.set_psychic_appearance(.72)

func _physics_process(delta:float)->void:
 lifetime-=delta
 if lifetime<=0 or current_hp<=0:
  current_hp=0;queue_free();return
 update_statuses(delta)

func begin_knockout()->void:
 current_hp=0;queue_free()

func take_damage(amount:float,attacker:QuibletActor3D=null,reflectable:bool=true)->float:
 var dealt:=super.take_damage(amount,attacker,reflectable)
 if current_hp<=0:queue_free()
 return dealt
