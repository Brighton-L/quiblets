class_name PowerStoneIcon
extends Control

var stone:Dictionary={}
var base_texture:Texture2D
var level_texture:Texture2D

func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func setup(value:Dictionary)->void:
	stone=GameData.normalize_power_stone(value)
	base_texture=load("res://textures/PowerStones/%sStoneBase.png"%stone.quality)
	level_texture=load("res://textures/PowerStones/%sStoneLV%d.png"%[stone.type,stone.tier])
	tooltip_text=describe()
	queue_redraw()

func describe()->String:
	# Exact effects of the stone: its power plus every bonus stat's fixed change.
	var lines:Array[String]=["%s %s Power Stone (T%d) • +%d %s"%[stone.quality,stone.type,stone.tier,stone.power,"max HP" if stone.type=="Health" else "Attack"]]
	for bonus in stone.bonuses:lines.append(GameData.bonus_description(bonus))
	if stone.bonuses.is_empty():lines.append("No bonus stats.")
	return "\n".join(lines)

func _notification(what:int)->void:
	if what==NOTIFICATION_RESIZED:queue_redraw()

func icon_rect()->Rect2:
	var side:=minf(size.x,size.y)
	return Rect2((size-Vector2.ONE*side)*.5,Vector2.ONE*side)

func power_number_rect()->Rect2:
	# All layers share the original 512-square canvas. The inset number panel is
	# x=156..356, y=324..424 on each base, not the overlay's visible bounds.
	var bounds:=icon_rect();var factor:=bounds.size.x/512.0
	return Rect2(bounds.position+Vector2(156,324)*factor,Vector2(200,100)*factor)

func _draw()->void:
	if stone.is_empty() or base_texture==null or level_texture==null:return
	var bounds:=icon_rect()
	draw_texture_rect(base_texture,bounds,false)
	draw_texture_rect(level_texture,bounds,false)
	var number_bounds:=power_number_rect()
	var font:=get_theme_default_font()
	var font_size:=maxi(1,roundi(number_bounds.size.y*.68))
	var text:=str(stone.power)
	while font_size>1 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>number_bounds.size.x*.85:font_size-=1
	var text_width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline:=number_bounds.get_center()+Vector2(-text_width*.5,(font.get_ascent(font_size)-font.get_descent(font_size))*.5)
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
