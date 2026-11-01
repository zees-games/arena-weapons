extends SceneTree
## Renders each named model, prints draw calls, primitives and frame time. Run: xvfb-run godot --path . --script tools/render_models.gd -- <out dir> <name>...
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	DirAccess.make_dir_recursive_absolute(out)
	var win := root
	win.size = Vector2i(900, 500)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.37, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	for i in range(1, a.size()):
		var n := a[i]
		var ps := load("res://addons/arena_weapons/assets/models/%s.glb" % n) as PackedScene
		var m := ps.instantiate() as Node3D
		root.add_child(m)
		m.rotation_degrees.y = 90
		cam.position = Vector3(0.25, 0.25, 1.5)
		cam.look_at(Vector3(0, 0.1, -0.1))
		for f in 30:
			await process_frame
		var t0 := Time.get_ticks_usec()
		for f in 60:
			await process_frame
		var ms := (Time.get_ticks_usec() - t0) / 60000.0
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("RESULT %s draw_calls=%d prims=%d frame_ms=%.2f" % [n, dc, pr, ms])
		root.get_texture().get_image().save_png("%s/%s.png" % [out, n])
		m.queue_free()
		await process_frame
	quit()
