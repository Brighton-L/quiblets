extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	for axis in [Vector2.RIGHT,Vector2.DOWN]:
		var e:=Expedition3D.new();root.add_child(e);e.set_process(false);e.biome=GameData.expedition_biome(0)
		e.height_origin=Vector2(-10,-10);e.height_cols=61;e.height_rows=61;e.height_field.resize(61*61)
		for row in 61:
			for column in 61:
				var point:=e.height_origin+Vector2(column,row)/3.0
				e.height_field[row*61+column]=point.x*.08+point.y*.05-1.5*(1.0-smoothstep(.5,1.5,absf(point.dot(axis))))
		var arch:Dictionary={"center":Vector2.ZERO,"axis":axis,"half_span":2.75,"half_width":1.5,"base":0.0};e.bridge_arches.append(arch)
		e.terrain_material=ShaderMaterial.new();e.terrain_material.shader=e.terrain_shader();e.build_bridges()
		var deck:MeshInstance3D=e.get_node("Bridges").get_child(0);var arrays:=deck.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for t in [.01,.2,.5,.8,.99]:
			for across in [-1.3,0.0,1.3]:
				var point:Vector2=axis*((t-.5)*5.5)+Vector2(-axis.y,axis.x)*across;var highest:=-INF
				for triangle in range(0,indices.size(),3):
					var hit=Geometry3D.ray_intersects_triangle(Vector3(point.x,20,point.y),Vector3.DOWN,vertices[indices[triangle]],vertices[indices[triangle+1]],vertices[indices[triangle+2]])
					if hit!=null:highest=maxf(highest,hit.y)
				check(absf(e.deck_height_at(point)-highest)<.02,"Walking height must match the visible bridge surface")
		var top_normals:=0
		for index in vertices.size():
			var v:=vertices[index];var point:=Vector2(v.x,v.z)
			if absf(v.y-e.deck_height_at(point))<.002 and absf(point.dot(axis))<2.7:
				check(normals[index].y>0,"Bridge top must face upward");top_normals+=1
		check(top_normals>20,"Bridge top needs smoothly shaded geometry")
		var edges:={}
		for triangle in range(0,indices.size(),3):
			for side in 3:
				var a:=indices[triangle+side];var b:=indices[triangle+(side+1)%3];var key:=Vector2i(mini(a,b),maxi(a,b));edges[key]=int(edges.get(key,0))+1
		check(edges.values().all(func(count):return count==2),"Bridge sides, underside and ends must form a closed solid")
		for t in [0.0,1.0]:
			for across in [-1.5,0.0,1.5]:
				var point:Vector2=axis*((t-.5)*5.5)+Vector2(-axis.y,axis.x)*across
				check(absf(e.bridge_surface_y(arch,t,across)-e.raw_height_at(point))<.001,"Each bank join must match the terrain across its full width")
		check(e.bridge_half_width(arch,0)>e.bridge_half_width(arch,.5),"Bank approaches should flare outward")
		check(e.deck_height_at(Vector2.ZERO)>e.WATER_LEVEL+.6,"The centre must leave clearance over the water")
		e.free()
	print("QUIBLETS_BRIDGE_GEOMETRY failures=%d"%failures);quit(0 if failures==0 else 1)
