extends SceneTree
## Contact sheet of one shot's drawn kick per gun: rows are guns, columns frames after the trigger (60 fps), with the
## camera turned by view_punch as the game does. Arg 1 out.png, arg 2 "before" (pose defaults) or "after" (pack params).
const GUNS := [&"sniper", &"shotgun", &"revolver", &"rifle"]
const FRAMES := [0, 3, 6, 12, 24]
const W := 480
const H := 270


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var after := a.size() > 1 and a[1] == "after"
	root.size = Vector2i(W * 2, H * 2)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.68, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	_scenery()
	var sheet := Image.create(W * FRAMES.size(), H * GUNS.size(), false, Image.FORMAT_RGB8)
	var defs := {}
	for d in AwWeaponPack.weapons({}, "", false):
		defs[d.id] = d
	for row in GUNS.size():
		var id: StringName = GUNS[row]
		var def: DotWeaponDef = defs[id]
		var cam := Camera3D.new()
		cam.fov = 80.0
		cam.position = Vector3(0, 1.6, 0)
		root.add_child(cam)
		cam.current = true
		var view := AwViewModel.new()
		view.hands_fov = 55.0
		view.process_mode = Node.PROCESS_MODE_DISABLED
		cam.add_child(view)
		var art := AwWeaponVisual.make(id)
		AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[id])
		view.equip(art)
		view.set_kick_params(def.params if after else {})
		view.fire_interval = float(def.use_interval_ticks) / float(AwWeaponPack.TICK_RATE)
		for _i in 90:
			view.advance(1.0 / 60.0)
			await process_frame
		var b := def.tuning as DotWeaponBallistics
		var shot := DotWeaponOutcome.new()
		shot.used = true
		shot.kind = DotWeaponOutcome.KIND_SHOT
		shot.recoil = Vector2(b.recoil_pitch, b.recoil_yaw)
		shot.recoil_signed = true
		view.on_used(shot)
		var frame := 0
		var peak := 0.0
		for col in FRAMES.size():
			while frame < FRAMES[col]:
				view.advance(1.0 / 60.0)
				frame += 1
				peak = maxf(peak, view.view_punch().x)
			var p := view.view_punch()
			cam.rotation_degrees = Vector3(p.x, p.y, 0.0)
			await process_frame
			await process_frame
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(W, H)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(col * W, row * H))
		print("RESULT %s %s camera_peak=%.2f" % [id, "after" if after else "before", peak])
		view.free()
		cam.free()
	out = ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	quit()


## A floor, a far wall with a horizon line and a post at the crosshair, so a camera turn shows as the world moving.
func _scenery() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.33, 0.3)
	floor_mesh.material_override = floor_mat
	root.add_child(floor_mesh)
	for x in range(-6, 7):
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 6.0 if x == 0 else 3.0, 0.3)
		post.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.15, 0.1) if x == 0 else Color(0.8, 0.8, 0.75)
		post.material_override = m
		post.position = Vector3(x * 2.0, box.size.y * 0.5, -20.0)
		root.add_child(post)
	var bar := MeshInstance3D.new()
	var bar_box := BoxMesh.new()
	bar_box.size = Vector3(30, 0.08, 0.1)
	bar.mesh = bar_box
	bar.position = Vector3(0, 1.6, -19.8)
	root.add_child(bar)
