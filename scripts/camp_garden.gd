extends Node
var game
var selected:=0
var slots:Array=["","","","",""]
var menu:Control
var camera_home:Transform3D
var tween:Tween
var ingredients:Dictionary:
	get:
		var counts:Dictionary=game.ingredients.duplicate()
		for item in slots:
			if not str(item).is_empty():counts[item]=maxi(0,int(counts.get(item,0))-1)
		return counts

func select_cooking_ingredient(_ingredient:String)->void:pass
func can_place(item:String,index:int)->bool:
	return GameData.INGREDIENTS.has(item) and (int(ingredients.get(item,0))>0 or slots[index]==item)
static func fertilizer_bonus(points:int,roll:float)->int:
	return int(points/3)+int(roll<float(points%3)*.1)
func advance()->void:
	for plot in game.garden_plots:
		if not plot.is_empty():plot.remaining=maxi(0,int(plot.remaining)-1)
func position_for(index:int)->Vector3:
	return Vector3(-5.8+(index%2)*2.3,.08,-2.4+int(index/2)*2.4)
func build()->void:
	game.garden_plots.resize(4)
	var terrain=game.world_root.get_node_or_null("CampLandscape")
	for i in 4:
		if not game.garden_plots[i] is Dictionary:game.garden_plots[i]={}
		var plot:Dictionary=game.garden_plots[i]
		var root:=Node3D.new();root.name="GardenPatch%d"%i;root.position=position_for(i);game.world_root.add_child(root)
		terrain.plant_box(root,Vector3.ZERO,Vector3(1.9,.15,1.85),Color("#71513b"))
		for row in 4:terrain.plant_box(root,Vector3(-.65+row*.43,.09,0),Vector3(.13,.08,1.6),Color("#937052"))
		if not plot.is_empty():
			var progress:=1.0-float(plot.remaining)/float(plot.required)
			var plant:=Node3D.new();plant.name="Crop";plant.position.y=.16;root.add_child(plant)
			if progress<.34:
				terrain.build_resource_plant_base(plant,str(plot.ingredient))
			else:terrain.build_berry_patch_shape(plant,str(plot.ingredient))
			plant.scale=Vector3.ONE*lerpf(.3,1.1,progress)
		var counter:=Label3D.new();counter.text="+" if plot.is_empty() else ("!" if int(plot.remaining)==0 else str(int(plot.remaining)));counter.position.y=1.35;counter.font_size=40;counter.pixel_size=.00065;counter.fixed_size=true;counter.billboard=BaseMaterial3D.BILLBOARD_ENABLED;counter.no_depth_test=true;root.add_child(counter)
		var body:=StaticBody3D.new();body.collision_layer=2;body.collision_mask=0;body.set_meta("garden_patch",i);root.add_child(body)
		var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(2,1.5,2);collision.shape=shape;collision.position.y=.5;body.add_child(collision)
func open(index:int)->void:
	selected=index;slots=["","","","",""];game.screen="garden";game.camp_pan_dragging=false
	for child in game.content.get_children():child.hide()
	camera_home=game.camera_3d.transform
	var target:=position_for(index)+Vector3(-1.6,0,0)
	var camera:Camera3D=game.camera_3d
	var destination:=Transform3D(Basis.IDENTITY,target+Vector3(0,5,7)).looking_at(target,Vector3.UP)
	tween=game.create_tween();tween.tween_property(camera,"transform",destination,.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	draw_menu()
	menu.position.x=-566
	var reveal:=menu.create_tween();reveal.tween_property(menu,"position:x",24.0,.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func draw_menu()->void:
	if is_instance_valid(menu):menu.free()
	menu=game.panel(Rect2(24,70,566,590),Color("#f4fbf6f2"),20);menu.name="GardenMenu";game.content.add_child(menu)
	game.label(menu,"PLANTING PATCH %d"%(selected+1),Vector2(22,16),24,GameData.COLORS.ink,true)
	var plot:Dictionary=game.garden_plots[selected]
	if not plot.is_empty():
		game.add_ingredient_icon(menu,GameData.INGREDIENTS[plot.ingredient],Vector2(225,110),Vector2(100,100),48)
		game.label(menu,str(plot.ingredient),Vector2(24,230),24,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,518)
		game.label(menu,"Ready to harvest" if int(plot.remaining)==0 else "%d successful expeditions until fully grown"%int(plot.remaining),Vector2(24,280),18,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_CENTER,518)
		if int(plot.remaining)==0:game.add_button(menu,"Harvest",Vector2(306,515),Vector2(230,50),harvest,"leaf")
		game.add_button(menu,"Back",Vector2(26,515),Vector2(230,50),close)
		return
	game.label(menu,"Drag an ingredient into the seed slot. Fertilizer is optional.",Vector2(22,58),15,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,520)
	var names:Array=GameData.INGREDIENTS.keys()
	for i in names.size():
		var card:=IngredientDragCard.new();menu.add_child(card);card.position=Vector2(22+(i%7)*75,108+int(i/7)*87);card.setup(self,str(names[i]),game.unlocked_ingredients.has(names[i]),1,78);card.tooltip_text=str(names[i])
	for i in 5:
		game.label(menu,"Seed" if i==0 else "Fertilizer",Vector2(23+i*106,376),13,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_CENTER,90)
		var slot=preload("res://scripts/garden_slot.gd").new();slot.garden=self;slot.index=i;slot.position=Vector2(30+i*106,402);slot.size=Vector2(76,76);menu.add_child(slot);slot.tooltip_text="Right-click to remove"
		var style:=StyleBoxFlat.new();style.bg_color=Color("#e0eadc");style.border_color=GameData.COLORS.leaf;style.set_border_width_all(2);style.set_corner_radius_all(14);slot.add_theme_stylebox_override("panel",style)
		if not str(slots[i]).is_empty():game.add_ingredient_icon(slot,GameData.INGREDIENTS[slots[i]],Vector2(6,6),Vector2(64,64),34)
	game.add_button(menu,"Cancel",Vector2(26,515),Vector2(230,50),close)
	game.add_button(menu,"Plant",Vector2(306,515),Vector2(230,50),confirm_plant,"leaf").disabled=str(slots[0]).is_empty()
func confirm_plant()->void:
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.45);shade.size=Vector2(1280,720);shade.z_index=100;game.content.add_child(shade)
	var box=game.panel(Rect2(350,205,580,310),Color("#f4fbf6"),18);shade.add_child(box)
	var points:=0
	for item in slots.slice(1):
		if not str(item).is_empty():points+=int(GameData.INGREDIENTS[item].tier)
	var tier:=int(GameData.INGREDIENTS[slots[0]].tier)
	game.label(box,"Plant %s?"%slots[0],Vector2(24,22),23,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,532)
	game.label(box,"Uses the seed and all selected fertilizer.\nGrowth: %s successful expeditions\nBase yield: %s   •   Fertilizer: +%d%s"%["5–6" if tier==4 else str(tier+1),["3–5","2–4","2–3","2–3"][tier-1],int(points/3)," (%d%% chance of +1 more)"%((points%3)*10) if points%3 else ""],Vector2(24,80),17,GameData.COLORS.ink,false,HORIZONTAL_ALIGNMENT_LEFT,532)
	game.add_button(box,"Cancel",Vector2(24,235),Vector2(250,50),shade.queue_free)
	game.add_button(box,"Plant",Vector2(306,235),Vector2(250,50),func():
		if commit_plant():shade.queue_free();close(),"leaf")
func commit_plant()->bool:
	if not game.garden_plots[selected].is_empty() or str(slots[0]).is_empty():return false
	var used:Dictionary={};var points:=0
	for i in 5:
		var item:=str(slots[i])
		if item.is_empty():continue
		if not GameData.INGREDIENTS.has(item):return false
		used[item]=int(used.get(item,0))+1
		if i>0:points+=int(GameData.INGREDIENTS[item].tier)
	for item in used:
		if int(game.ingredients.get(item,0))<int(used[item]):return false
	var tier:=int(GameData.INGREDIENTS[slots[0]].tier)
	var duration:=randi_range(5,6) if tier==4 else tier+1
	var base:=randi_range(3,5) if tier==1 else randi_range(2,4 if tier==2 else 3)
	for item in used:game.ingredients[item]-=int(used[item])
	game.garden_plots[selected]={"ingredient":str(slots[0]),"required":duration,"remaining":duration,"yield":base+fertilizer_bonus(points,randf())}
	game.save_game();return true
func harvest()->void:
	var plot:Dictionary=game.garden_plots[selected]
	if plot.is_empty() or int(plot.remaining)>0:return
	game.grant_ingredient(str(plot.ingredient),int(plot["yield"]));game.garden_plots[selected]={};game.save_game()
	for child in menu.get_children():child.queue_free()
	game.label(menu,"Harvested %d %s!"%[int(plot["yield"]),str(plot.ingredient)],Vector2(24,220),26,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,518)
	game.add_button(menu,"Done",Vector2(165,360),Vector2(230,50),close,"leaf")
func close()->void:
	if is_instance_valid(menu):menu.hide()
	game.screen="garden_closing"
	if is_instance_valid(tween):tween.kill()
	tween=game.create_tween();tween.tween_property(game.camera_3d,"transform",camera_home,.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT);tween.tween_callback(game.show_camp)
