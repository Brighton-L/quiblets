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
		var style:=_outline(Color("#85898f"),3.0)
		selection_outline.add_theme_stylebox_override("panel",style);add_child(selection_outline)
		pulse=0.0;update_selection_outline();set_process(true)
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
	pulse=fposmod(pulse+delta,PULSE_DURATION)
	update_selection_outline()

func update_selection_outline()->void:
	if not is_instance_valid(selection_outline):return
	var progress:=pulse/PULSE_DURATION
	# Loop only the border's size, keeping it centered, opaque, and unfilled.
	var contraction:=(1.0-cos(progress*TAU))*.5
	var extent:=portrait_rect.size*(1.0-.28*contraction)
	selection_outline.position=portrait_rect.get_center()-extent*.5
	selection_outline.size=extent

func _outline(color: Color, width: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(13)
	return box
