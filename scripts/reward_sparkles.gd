class_name RewardSparkles
extends Control

# Twinkling stars that orbit a reward pickup while it rises, hovers, and flies
# to the Pause button. Level 1 is a gold ring; level 2 adds more, larger,
# two-tone stars plus a soft pulsing glow behind the icon.
const GOLD:=Color("#f2b84b")
var level:=0
var stars:Array[Dictionary]=[]
var elapsed:=0.0
var halo:Control

class Halo extends Control:
	var owner_sparkles:RewardSparkles
	func _init()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=-1
	func _draw()->void:
		if owner_sparkles==null:return
		var center:=size*.5;var pulse:=(sin(owner_sparkles.elapsed*3.2)+1.0)*.5
		var radius:=size.x*.62+pulse*4.0
		for ring in 4:draw_circle(center,radius*(1.0-ring*.16),Color(GOLD.r,GOLD.g,GOLD.b,.1+ring*.05+pulse*.05))

func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func setup(sparkle_level:int)->void:
	level=clampi(sparkle_level,1,2)
	var rng:=RandomNumberGenerator.new()
	var count:=5 if level==1 else 9
	for i in count:
		var color:Color=GOLD if level==1 or i%2==0 else Color.WHITE
		stars.append({"angle":TAU*i/count+rng.randf_range(-.3,.3),"distance":rng.randf_range(23.0,32.0)+(0.0 if level==1 else 5.0),"phase":rng.randf()*TAU,"speed":rng.randf_range(5.0,8.0),"size":rng.randf_range(4.5,7.0)*(1.0 if level==1 else 1.4),"color":color})
	if level==2:
		halo=Halo.new();halo.name="RewardHalo";halo.owner_sparkles=self;halo.size=size;add_child(halo)

func _ready()->void:
	var parent:=get_parent()
	if parent is Control and size==Vector2.ZERO:size=parent.size
	if halo!=null:halo.size=size

func _process(delta:float)->void:
	elapsed+=delta
	queue_redraw()
	if halo!=null:halo.queue_redraw()

func star_points(center:Vector2,radius:float)->PackedVector2Array:
	var points:=PackedVector2Array()
	for i in 8:points.append(center+Vector2.from_angle(i*TAU/8.0-PI*.5)*(radius if i%2==0 else radius*.36))
	return points

func _draw()->void:
	var center:=size*.5
	for star in stars:
		var twinkle:float=(sin(elapsed*star.speed+star.phase)+1.0)*.5
		var alpha:=.2+.8*twinkle;var scale_factor:=.5+.5*twinkle
		var point:Vector2=center+Vector2.from_angle(star.angle+elapsed*.7)*star.distance
		var color:Color=star.color;color.a=alpha
		draw_colored_polygon(star_points(point,star.size*scale_factor),color)
		draw_circle(point,star.size*scale_factor*.3,Color(1,1,1,alpha))
