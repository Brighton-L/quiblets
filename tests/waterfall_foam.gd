extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	for flow in [Vector2.RIGHT,Vector2.DOWN]:
		var e:=Expedition3D.new();root.add_child(e);e.set_process(false);e.biome=GameData.expedition_biome(0)
		var lip:=Vector2(12,8);e.waterfalls.append({"lip":lip,"flow":flow,"half_width":2.0})
		for along in range(-5,6):
			for across in range(-2,3):e.rivers[Vector2i(lip+flow*along+Vector2(-flow.y,flow.x)*across)]=true
		e.build_waterfalls()
		for time in [0.0,.3,1.1,2.7]:
			e.elapsed=time;e.update_waterfall_bubbles();var visible_count:=0
			for bubble in e.waterfall_bubbles:
				var node:MeshInstance3D=bubble.node
				if not node.visible:continue
				visible_count+=1
				var point:=Vector2(node.global_position.x,node.global_position.z)
				check(e.rivers.has(e.cell_of(point)),"Foam must stay over water in both orientations")
				check((point-lip).dot(flow)>=0.0 and (point-lip).dot(flow)<2.0,"Foam must drift downstream from the foot")
				check(is_equal_approx(node.global_position.y,e.WATER_LEVEL+.085),"Foam must sit just above the water sheet")
				check(node.mesh is PlaneMesh,"Foam should use soft surface patches")
			check(visible_count>10,"The waterfall foot must retain visible foam")
		# A bridge covering the pool must hide the foam instead of receiving bubbles.
		for cell in e.rivers:e.bridges[cell]=true
		e.update_waterfall_bubbles()
		check(e.waterfall_bubbles.all(func(bubble):return not bubble.node.visible),"Foam must not appear on bridges")
		e.free()
	print("QUIBLETS_WATERFALL_FOAM failures=",failures);quit(failures)
