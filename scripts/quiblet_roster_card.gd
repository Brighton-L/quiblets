class_name QuibletRosterCard
extends Panel

signal chosen(roster_index: int)

var roster_index := -1
const PULSE_DURATION := 0.32
var portrait_rect := Rect2(8,3,88,78)
var pulse := 0.0
var selection_outline:Panel

func setup(index: int, selected := false) -> void:
	roster_index = index
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if selected:
		selection_outline=Panel.new();selection_outline.name="PortraitSelectionFlash"
		selection_outline.mouse_filter=Control.MOUSE_FILTER_IGNORE;selection_outline.z_index=20
		var style:=_outline(Color.WHITE,3.0)
		style.shadow_color=Color("#244838");style.shadow_size=2
		selection_outline.add_theme_stylebox_override("panel",style);add_child(selection_outline)
		pulse=PULSE_DURATION;update_selection_outline();set_process(true)
	else:set_process(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		chosen.emit(roster_index)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := duplicate()
	preview.modulate.a = 0.86
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	return {"kind":"quiblet", "roster_index":roster_index}

func _process(delta: float) -> void:
	pulse=maxf(0.0,pulse-delta)
	update_selection_outline()
	if pulse<=0.0:set_process(false)

func update_selection_outline()->void:
	if not is_instance_valid(selection_outline):return
	selection_outline.visible=pulse>0.0
	var progress:=clampf(1.0-pulse/PULSE_DURATION,0.0,1.0)
	# Keep the outline bright while it contracts, then expands, so its size
	# change is visible instead of hidden inside the old fade-in/fade-out.
	var extent:=portrait_rect.size*(1.0-.28*sin(progress*PI))
	selection_outline.position=portrait_rect.get_center()-extent*.5
	selection_outline.size=extent
	selection_outline.modulate.a=1.0-smoothstep(.82,1.0,progress)

func _outline(color: Color, width: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(13)
	return box
