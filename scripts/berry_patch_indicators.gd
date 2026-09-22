extends Control

# A viewport-space compass for the remaining grove harvests. It never catches clicks.
var expedition:Node3D
const INSET:=12.0
const HALF_SIZE:=5.0
var marker_style:=StyleBoxFlat.new()

func _ready()->void:
	marker_style.set_corner_radius_all(3)
	marker_style.anti_aliasing=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_priority=10 # Read the camera after the expedition has moved it.

func _process(_delta:float)->void:
	queue_redraw()

func marker_for(point:Vector3)->Dictionary:
	if not is_instance_valid(expedition) or not is_instance_valid(expedition.camera):return {}
	var camera:Camera3D=expedition.camera
	var view:Rect2=camera.get_viewport().get_visible_rect()
	var projected:=camera.unproject_position(point)
	var behind:=camera.is_position_behind(point)
	if not behind and view.has_point(projected):return {}
	# Clamp the projected coordinates independently: a patch above the right
	# corner belongs at that corner, not along a ray from the screen centre.
	var inverse:=get_global_transform_with_canvas().affine_inverse()
	var bounds:=Rect2(inverse*view.position,(inverse*view.end)-(inverse*view.position)).grow(-INSET)
	var local_point:Vector2=inverse*projected
	if behind:
		var direction:Vector2=(inverse*view.get_center())-local_point
		if direction.length_squared()<.001:direction=Vector2.DOWN
		var half:=bounds.size*.5
		var distance:=minf(half.x/maxf(absf(direction.x),.001),half.y/maxf(absf(direction.y),.001))
		local_point=bounds.get_center()+direction*distance
	return {"position":local_point.clamp(bounds.position,bounds.end)}

func _draw()->void:
	if not is_instance_valid(expedition) or not expedition.is_grove():return
	for patch in expedition.berry_nodes:
		if not is_instance_valid(patch) or patch.is_queued_for_deletion() or not patch.is_visible_in_tree():continue
		var marker:=marker_for(patch.global_position+Vector3(0,.35,0))
		if marker.is_empty():continue
		var point:Vector2=marker.position
		var color:Color=GameData.INGREDIENTS.get(str(patch.get_meta("ingredient","")),{}).get("color",Color.WHITE)
		var rect:=Rect2(point-Vector2.ONE*HALF_SIZE,Vector2.ONE*HALF_SIZE*2.0)
		marker_style.bg_color=color
		draw_style_box(marker_style,rect)
