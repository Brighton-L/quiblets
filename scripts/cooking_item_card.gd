class_name CookingItemCard
extends Panel

var drag_payload:Dictionary={}
var enabled:=false

func setup(icon_text:String,title:String,subtitle:String,count:int,color:Color,payload:Dictionary)->void:
	drag_payload=payload;enabled=count>0
	tooltip_text=title+"\n"+subtitle
	var style:=StyleBoxFlat.new();style.bg_color=Color.WHITE if enabled else Color("#ededed");style.border_color=color;style.set_border_width_all(2);style.set_corner_radius_all(12);add_theme_stylebox_override("panel",style)
	var icon:=Label.new();icon.text=icon_text;icon.position=Vector2(0,3);icon.size=Vector2(67,38);icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;icon.add_theme_font_size_override("font_size",26);icon.add_theme_color_override("font_color",color.darkened(.2));icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
	var count_label:=Label.new();count_label.text=str(count);count_label.position=Vector2(0,42);count_label.size=Vector2(67,20);count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;count_label.add_theme_font_size_override("font_size",14);count_label.add_theme_color_override("font_color",GameData.COLORS.ink);count_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(count_label)
	mouse_default_cursor_shape=Control.CURSOR_DRAG if enabled else Control.CURSOR_POINTING_HAND

signal chosen(data:Dictionary)

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:chosen.emit(drag_payload)

func _get_drag_data(_position:Vector2)->Variant:
	if not enabled:return null
	var preview:=Label.new();preview.text="  "+drag_payload.get("label","")+"  ";preview.add_theme_font_size_override("font_size",16);preview.add_theme_color_override("font_color",Color.WHITE);preview.add_theme_stylebox_override("normal",StyleBoxEmpty.new());set_drag_preview(preview);return drag_payload
