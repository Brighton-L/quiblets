class_name QuibletPortrait
extends Control

var species_index := 0
var mood := "happy"
var scale_factor := 1.0
var selected := false
var hp_ratio := 1.0
var facing := 1.0

func setup(index: int, new_scale: float = 1.0) -> void:
	species_index = index
	scale_factor = new_scale
	queue_redraw()

func _draw() -> void:
	var s := GameData.species(species_index)
	var c: Color = s.color
	var a: Color = s.accent
	var center := size * 0.5
	var r: float = min(size.x, size.y) * 0.31 * scale_factor
	if selected:
		draw_circle(center, r * 1.34, Color(1, 0.78, 0.25, 0.24))
		draw_arc(center, r * 1.34, 0, TAU, 40, GameData.COLORS.gold, 3.0)
	# Soft shadow.
	draw_ellipse(center + Vector2(0, r * 0.78), r * 0.82, r * 0.27, Color(0.15,0.2,0.22,0.16))
	# Species silhouettes.
	match s.shape:
		"ears":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.7,-r*.45),center+Vector2(-r*.52,-r*1.25),center+Vector2(-r*.12,-r*.62)]), c)
			draw_colored_polygon(PackedVector2Array([center+Vector2(r*.7,-r*.45),center+Vector2(r*.52,-r*1.25),center+Vector2(r*.12,-r*.62)]), c)
		"fins":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.72,-r*.15),center+Vector2(-r*1.28,-r*.65),center+Vector2(-r*1.05,r*.2)]), a)
			draw_colored_polygon(PackedVector2Array([center+Vector2(r*.72,-r*.15),center+Vector2(r*1.28,-r*.65),center+Vector2(r*1.05,r*.2)]), a)
		"horn":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.25,-r*.72),center+Vector2(0,-r*1.35),center+Vector2(r*.25,-r*.72)]), a)
		"tuft", "crest":
			var pts := PackedVector2Array([center+Vector2(-r*.55,-r*.62),center+Vector2(-r*.2,-r*1.2),center+Vector2(0,-r*.72),center+Vector2(r*.35,-r*1.3),center+Vector2(r*.55,-r*.58)])
			draw_colored_polygon(pts, a)
		"moon":
			draw_circle(center+Vector2(r*.28,-r*.62),r*.46,a)
			draw_circle(center+Vector2(r*.43,-r*.72),r*.37,c)
		"shell":
			draw_circle(center+Vector2(-r*.4,-r*.05),r*.72,a)
			draw_arc(center+Vector2(-r*.4,-r*.05),r*.4,0,TAU,24,c,3.0)
	# Body and belly.
	draw_circle(center, r, c)
	draw_circle(center+Vector2(0,r*.22), r*.64, c.lightened(.08))
	if s.shape == "tail":
		draw_circle(center+Vector2(r*.88,r*.18),r*.34,a)
		draw_circle(center+Vector2(r*1.05,r*.02),r*.18,GameData.COLORS.gold)
	# Face.
	var eye_y: float = center.y-r*.18
	var eye_dx: float = r*.32
	for ex in [-eye_dx, eye_dx]:
		if mood == "hurt":
			draw_line(Vector2(center.x+ex-r*.09,eye_y-r*.05),Vector2(center.x+ex+r*.09,eye_y+r*.05),GameData.COLORS.ink,2.5)
		else:
			draw_circle(Vector2(center.x+ex,eye_y),r*.085,GameData.COLORS.ink)
			draw_circle(Vector2(center.x+ex-r*.025,eye_y-r*.03),r*.026,Color.WHITE)
	if mood == "happy":
		draw_arc(center+Vector2(0,r*.04),r*.2,0.18,PI-0.18,14,GameData.COLORS.ink,2.5)
	elif mood == "determined":
		draw_line(center+Vector2(-r*.16,r*.12),center+Vector2(r*.16,r*.12),GameData.COLORS.ink,2.5)
	else:
		draw_arc(center+Vector2(0,r*.28),r*.16,PI+0.2,TAU-0.2,10,GameData.COLORS.ink,2.5)
	# Tiny cheek marks.
	draw_circle(center+Vector2(-r*.55,r*.06),r*.1,Color(a,0.55))
	draw_circle(center+Vector2(r*.55,r*.06),r*.1,Color(a,0.55))
