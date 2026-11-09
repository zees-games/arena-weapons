extends SceneTree
## Per-weapon-model draw calls, surfaces, distinct materials and frame time, one model on screen at a time (the view-model case).
## Run under xvfb: godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tools/weapon_draw_probe.gd
## Models are every glb in assets/models (the art table is empty without a game's role config). Prints one "DRAW <name> surf=N mats=M tris=T draw_calls=D frame_ms=X" row per AwWeaponArtTable model and a DRAW_TOTAL line.
const FRAMES := 120


func _paths() -> Array[String]:
	var out: Array[String] = []
	var dir := "res://addons/arena_weapons/assets/models"
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb"):
			out.append(dir + "/" + f)
	out.sort()
	return out


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	var tot_dc := 0
	var tot_surf := 0
	var tot_mats := 0
	var n := 0
	await process_frame
	for path in _paths():
		var model := AwModelCache.instantiate(path)
		if model == null:
			continue
		root.add_child(model)
		cam.look_at_from_position(Vector3(0.6, 0.2, 1.0), Vector3.ZERO)
		var surf := 0
		var tris := 0
		var mats := {}
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				surf += 1
				var m := mesh.surface_get_material(s)
				mats[m.get_instance_id() if m else 0] = true
				tris += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3
		for f in 20:
			await process_frame
		var t0 := Time.get_ticks_usec()
		for f in FRAMES:
			await process_frame
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		print("DRAW %s surf=%d mats=%d tris~%d draw_calls=%d frame_ms=%.2f" % [path.get_file(), surf, mats.size(), tris, dc, ms])
		tot_dc += dc
		tot_surf += surf
		tot_mats += mats.size()
		n += 1
		model.queue_free()
		await process_frame
	print("DRAW_TOTAL models=%d surf=%d mats=%d draw_calls=%d avg_dc=%.1f" % [n, tot_surf, tot_mats, tot_dc, float(tot_dc) / maxf(n, 1)])
	quit(0)
