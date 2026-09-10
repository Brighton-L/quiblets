class_name CookingItemCard
extends Panel

var drag_payload:Dictionary={}
var enabled:=false

func setup(icon_text:String,title:String,subtitle:String,count:int,color:Color,payload:Dictionary)->void:
	drag_payload=payload;enabled=count>0
	var style:=StyleBoxFlat.new();style.bg_color=color.lightened(.58) if enabled else Color("#b7b7b7");style.border_color=color if enabled else Color("#777777");style.set_border_width_all(2);style.set_corner_radius_all(10);add_theme_stylebox_override("panel",style)
	var icon:=Label.new();icon.text=icon_text if enabled else "?";icon.position=Vector2(3,5);icon.size=Vector2(42,42);icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;icon.add_theme_font_size_override("font_size",25);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
	var name_label:=Label.new();name_label.text=title;name_label.position=Vector2(45,7);name_label.size=Vector2(size.x-50,22);name_label.add_theme_font_size_override("font_size",11);name_label.add_theme_color_override("font_color",GameData.COLORS.ink);name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(name_label)
	var sub:=Label.new();sub.text=subtitle+"  ×%d"%count;sub.position=Vector2(45,29);sub.size=Vector2(size.x-50,22);sub.add_theme_font_size_override("font_size",9);sub.add_theme_color_override("font_color",GameData.COLORS.muted);sub.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(sub)
	mouse_default_cursor_shape=Control.CURSOR_DRAG if enabled else Control.CURSOR_FORBIDDEN

func _get_drag_data(_position:Vector2)->Variant:
	if not enabled:return null
	var preview:=Label.new();preview.text="  "+drag_payload.get("label","")+"  ";preview.add_theme_font_size_override("font_size",16);preview.add_theme_color_override("font_color",Color.WHITE);preview.add_theme_stylebox_override("normal",StyleBoxEmpty.new());set_drag_preview(preview);return drag_payload
