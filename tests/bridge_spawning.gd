extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var failures:=0
	for area in 16:
		for kind in ["level","boss","berry_grove"]:
			var e:=Expedition3D.new();e.stage_area_index=area;e.stage_kind=kind;e.stage_level=GameData.expedition_area_level(area);e.biome=GameData.expedition_biome(area)
			var rng:=RandomNumberGenerator.new();rng.seed=area*1009+73
			e.layout_zones(rng);e.carve_walkable()
			var original_centres:Array=e.zones.map(func(zone):return zone.center)
			e.carve_rivers(rng)
			for centre in original_centres:
				var cell:=e.cell_of(centre)
				# An encounter moved away from water must leave the channel wet.
				if e.river_flow.has(cell) and not e.rivers.has(cell) and not e.bridges.has(cell):push_error("Encounter left a dry river gap");failures+=1
			for zone in e.zones:
				for x in range(-2,3):
					for y in range(-2,3):
						if not e.walkable.has(e.cell_of(zone.center)+Vector2i(x,y)):push_error("Encounter needs a dry bank clearing");failures+=1
			if not e.zones_connected():push_error("Disconnected rivers: %d %s"%[area,kind]);failures+=1
			for crossing in e.river_crossings:
				for bank in [crossing.bank_a,crossing.bank_b]:
					if not e.walkable.has(bank) or e.bridges.has(bank):push_error("Bridge needs a dry landing");failures+=1
				for cell in crossing.cells:
					if not e.bridges.has(cell):push_error("Crossing must be walkable");failures+=1
			e.plan_bridges()
			if e.bridge_arches.size()!=e.river_crossings.size():push_error("Each crossing needs exactly one arch");failures+=1
			e.free()
		await process_frame
	print("RIVER_ROUTES 48 layouts failures=",failures);quit(failures)
