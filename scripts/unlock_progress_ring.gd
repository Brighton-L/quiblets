class_name UnlockProgressRing
extends Control

# Progress toward the next Power Stone slot unlock:
# progress = (current level - previous unlock level) / (next unlock level - previous unlock level).
# Drawn as a square outline traced clockwise from the top centre around the
# locked slot rectangle (or as a ring when shape is "circle").
# The unfilled track matches the slot background colour.
const TRACK:=Color("#4b4b4b")
const FILL:=Color("#f2b84b")
const WIDTH:=2.5
var shape:="square"
var progress:=0.0:
	set(value):
		progress=clampf(value,0.0,1.0);queue_redraw()

func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func square_path(fraction:float)->PackedVector2Array:
	# Perimeter from the top centre, clockwise, covering `fraction` of the square.
	var inset:=WIDTH*.5;var side:=minf(size.x,size.y)-WIDTH
	var top_left:=Vector2(inset,inset);var corners:=[Vector2(side*.5,0),Vector2(side,0),Vector2(side,side),Vector2(0,side),Vector2(0,0),Vector2(side*.5,0)]
	var remaining:=fraction*side*4.0;var points:=PackedVector2Array([top_left+corners[0]])
	for i in range(1,corners.size()):
		var segment_length:float=corners[i].distance_to(corners[i-1])
		if remaining>=segment_length:points.append(top_left+corners[i]);remaining-=segment_length
		else:points.append(top_left+corners[i-1].lerp(corners[i],remaining/segment_length));break
	return points

func _draw()->void:
	if shape=="circle":
		var center:=size*.5;var radius:=minf(size.x,size.y)*.5-2.0
		draw_arc(center,radius,0.0,TAU,48,TRACK,3.0,true)
		if progress>0.0:draw_arc(center,radius,-PI*.5,-PI*.5+TAU*progress,48,FILL,3.0,true)
		return
	draw_polyline(square_path(1.0),TRACK,WIDTH,true)
	if progress>0.0:draw_polyline(square_path(progress),FILL,WIDTH,true)
