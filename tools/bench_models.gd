extends SceneTree
## Frame time with many copies of a model on screen, old vs new GLB. Needs two dirs of GLBs (old from git, new); copy with the script into a bare project and run under xvfb on a GPU box: godot --path . --script res://bench_models.gd -- <old dir> <new dir> <copies> <name>...
const FRAMES := 800

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dirs := [a[0], a[1]]
	var copies := int(a[2])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1920, 1080)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, -35, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var side := int(ceil(sqrt(copies)))
	cam.position = Vector3(0, side * 0.55, side * 0.9)
	cam.look_at_from_position(cam.position, Vector3(0, 0, 0))
	await process_frame
	for round in 6:
		for i in range(3, a.size()):
			for d in 2:
				var path := "%s/%s.glb" % [dirs[d], a[i]]
				var doc := GLTFDocument.new()
				var st := GLTFState.new()
				doc.append_from_file(path, st)
				var scene := doc.generate_scene(st)
				var holder := Node3D.new()
				root.add_child(holder)
				for k in copies:
					var m: Node3D = scene.duplicate()
					m.position = Vector3((k % side - side / 2.0) * 1.1, 0, (k / side - side / 2.0) * 1.1)
					holder.add_child(m)
				for f in 40:
					await process_frame
				var t0 := Time.get_ticks_usec()
				for f in FRAMES:
					await process_frame
				var ms := (Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
				var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
				print("RESULT round=%d %s %s copies=%d frame_ms=%.3f fps=%.1f draw_calls=%d prims=%d" % [round, a[i], "old" if d == 0 else "new", copies, ms, 1000.0 / ms, dc, pr])
				holder.queue_free()
				scene.queue_free()
				await process_frame
	quit()
