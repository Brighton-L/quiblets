extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var e:=Expedition3D.new()
	var ring:Array[Vector2i]=[]
	for x in range(-1,2):
		for y in range(-1,2):
			if x!=0 or y!=0:ring.append(Vector2i(x,y))
	for mask in 256:
		e.walkable.clear()
		for i in ring.size():
			if mask&(1<<i):e.walkable[ring[i]]=true
		var neighbours:Array[Vector2i]=[]
		for cell in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if e.walkable.has(cell):neighbours.append(cell)
		var connected:=true
		if not neighbours.is_empty():
			var seen:={neighbours[0]:true};var queue:Array[Vector2i]=[neighbours[0]]
			while not queue.is_empty():
				var cell:Vector2i=queue.pop_front()
				for next in e.walkable:
					if not seen.has(next) and Vector2(next-cell).length()==1.0:seen[next]=true;queue.append(next)
			connected=neighbours.all(func(cell):return seen.has(cell))
		check(e.neighbours_connected_locally(Vector2i.ZERO)==connected,"Local connectivity must handle every neighbour pattern")
	var rng:=RandomNumberGenerator.new();rng.seed=73;e.layout_zones(rng)
	for i in 500:
		var point:=Vector2(rng.randf_range(-80,80),rng.randf_range(-60,60));var original:=INF
		for j in e.route_points.size()-1:original=minf(original,point.distance_to(Geometry2D.get_closest_point_to_segment(point,e.route_points[j],e.route_points[j+1])))
		check(absf(e.route_distance(point)-original)<.0001,"Path coloring distances must match the sampled route")
	e.free();print("QUIBLETS_MAP_OPTIMIZATIONS failures=",failures);quit(failures)
