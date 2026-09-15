extends Control

var button:Button

func setup(game:Node,return_to_camp:Callable)->void:
 name="CampNavigation";position=Vector2(995,450);size=Vector2(255,242);mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=30
 button=game.add_button(self,"BASE CAMP  ›",Vector2(0,170),Vector2(255,72),return_to_camp,"gold")
 button.name="BaseCampButton";button.add_theme_font_size_override("font_size",20)
 var cooking:bool=not game.pending_stew.is_empty()
 var ready:bool=not game.completed_stew_result.is_empty()
 var view_container:=SubViewportContainer.new();view_container.name="PotStatusIcon";view_container.position=Vector2(47,24);view_container.size=Vector2(160,140);view_container.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(view_container)
 var viewport:=SubViewport.new();viewport.name="PotViewport";viewport.size=Vector2i(160,140);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;view_container.add_child(viewport)
 var pot:Node3D=load("res://models/CookingPot.glb").instantiate();pot.name="StatusPot";viewport.add_child(pot)
 if cooking:
  var lid:Node3D=load("res://models/PotLid.glb").instantiate();lid.name="StatusPotLid";lid.scale=Vector3.ONE*(25.0/24.0);lid.position.y=3.5+.2*(25.0/24.0)-.01;viewport.add_child(lid)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.8;viewport.add_child(camera);camera.position=Vector3(7,6,10);camera.look_at(Vector3(0,1.8,0));camera.current=true
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0,0,0,0);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;viewport.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);viewport.add_child(sun)
 if cooking:
  var required:=maxi(1,int(game.pending_stew.get("expeditions_required",1)))
  var remaining:=clampi(int(game.pending_stew.get("expeditions_remaining",required)),0,required)
  var count:Label=game.label(self,"%d/%d"%[required-remaining,required],Vector2(0,0),22,Color.WHITE,true,HORIZONTAL_ALIGNMENT_CENTER,255);count.name="PotExpeditionCount";count.size.y=30;count.add_theme_color_override("font_outline_color",Color("#20382d"));count.add_theme_constant_override("outline_size",6)
 elif ready:
  var badge:Panel=game.panel(Rect2(111,0,34,34),Color("#f15f9b"),17);badge.name="PotReadyBadge";badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(badge)
  var mark:Label=game.label(badge,"!",Vector2.ZERO,26,Color.WHITE,true,HORIZONTAL_ALIGNMENT_CENTER,34);mark.size=Vector2(34,34);mark.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var pot_button:=Button.new();pot_button.name="PotStatusButton";pot_button.flat=true;pot_button.position=Vector2(47,0);pot_button.size=Vector2(160,164);pot_button.tooltip_text="Stew ready — collect it at base camp" if ready else ("Stew cooking" if cooking else "Pot empty");pot_button.pressed.connect(return_to_camp);add_child(pot_button)
