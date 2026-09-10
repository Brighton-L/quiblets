class_name QuibletRosterCard
extends Panel

signal chosen(roster_index: int)

var roster_index := -1
var pulse := 0.0

func setup(index: int, selected := false) -> void:
	roster_index = index
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if selected:
		pulse = 0.36
		set_process(true)
	queue_redraw()

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
	pulse = maxf(0.0, pulse - delta)
	queue_redraw()
	if pulse <= 0.0:
		set_process(false)

func _draw() -> void:
	if pulse <= 0.0:
		return
	var progress := 1.0 - pulse / 0.36
	var inset := lerpf(12.0, 1.0, progress)
	var alpha := sin(progress * PI)
	draw_style_box(_outline(Color(1, 1, 1, alpha), 4.0), Rect2(Vector2(inset, inset), size - Vector2.ONE * inset * 2.0))

func _outline(color: Color, width: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(13)
	return box
