extends SceneTree
## Renders the charge ball's early-release fizzle as a contact sheet, one cell per frame at 60 fps.
## Run: xvfb-run godot --rendering-method gl_compatibility --rendering-driver opengl3 --path . --script tools/render_fizzle.gd -- <out.png> [frames]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var n := int(a[1]) if a.size() > 1 else 16
	root.size = Vector2i(400, 400)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.12)
	root.add_child(env)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 0, 0.5)
	cam.current = true
	var fx := preload("res://addons/arena_weapons/view/aw_charge_fx.gd").new()
	root.add_child(fx)
	fx.process_mode = Node.PROCESS_MODE_DISABLED
	fx.set_charge(0.6)
	print("DBG vis=%s" % fx.visible)
	for i in 30:
		fx.advance(1.0 / 60.0)
	await process_frame
	var cell := 240
	var cols := 6
	var sheet := Image.create(cols * cell, ((n + cols - 1) / cols) * cell, false, Image.FORMAT_RGB8)
	print("DBG pre vis=%s shown=%.3f" % [fx.visible, fx.shown()])
	fx.set_charge(0.0)
	print("RESULT fizzling=%s collapse_time=%.3f" % [fx.is_fizzling(), fx.collapse_time()])
	for i in n:
		fx.advance(1.0 / 60.0)
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		if i == 0: print("DBG img %s ball=%s" % [img.get_size(), cam.unproject_position(Vector3.ZERO)])
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img.get_region(Rect2i(img.get_width() / 2 - 120, img.get_height() / 2 - 120, 240, 240)), Rect2i(0, 0, cell, cell), Vector2i((i % cols) * cell, (i / cols) * cell))
		print("FRAME %d visible=%s shown=%.3f" % [i, fx.visible, fx.shown()])
	sheet.save_png(out)
	quit()
