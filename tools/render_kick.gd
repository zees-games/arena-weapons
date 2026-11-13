extends SceneTree
## Contact sheet of one shot's drawn kick per gun: rows are guns, columns frames after the trigger (60 fps), with the
## camera turned by view_punch as the game does. Arg 1 out.png, arg 2 "before" (pose defaults), "after" (pack params),
## "fx" (after, plus the rig's muzzle flash and spent case) or "tp" (a held gun seen side-on firing, as a watcher sees it).
## Arg 3 "proc" draws the procedural flash instead of dot-fx's, to compare the two ("-" keeps dot-fx's). Arg 4, a comma list of
## gun ids, replaces the default rows (e.g. "lmg,minigun,launcher,battle_rifle" for the big guns).
## Run with --fixed-fps 60 (tools/render_kick.sh) so the effects step one 60th a frame.
const GUNS := [&"sniper", &"shotgun", &"revolver", &"rifle"]
const FRAMES := [0, 3, 6, 12, 24]
## The fx columns: the shot frame, the flash fading, and the case leaving (a bolt or a pump throws it about 25 frames late).
const FX_FRAMES := [0, 1, 3, 8, 26, 30, 36]
const W := 480
const H := 270
var _proc := false
var _guns: Array = GUNS


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var mode: String = a[1] if a.size() > 1 else "before"
	var after := mode != "before"
	_proc = a.size() > 2 and a[2] == "proc"
	if a.size() > 3 and a[3] != "":
		_guns = Array(a[3].split(",")).map(func(g: String) -> StringName: return StringName(g))
	var frames: Array = FX_FRAMES if mode in ["fx", "tp"] else FRAMES
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
	var sheet := Image.create(W * frames.size(), H * _guns.size(), false, Image.FORMAT_RGB8)
	var defs := {}
	for d in AwWeaponPack.weapons({}, "", false):
		defs[d.id] = d
	for row in _guns.size():
		var id: StringName = _guns[row]
		var def: DotWeaponDef = defs[id]
		var cam := Camera3D.new()
		cam.fov = 80.0
		cam.position = Vector3(0, 1.6, 0)
		root.add_child(cam)
		cam.current = true
		if mode == "tp":
			await _third_person(id, cam, frames, sheet, row)
			cam.free()
			continue
		var view := AwViewModel.new()
		view.hands_fov = 55.0
		view.process_mode = Node.PROCESS_MODE_DISABLED
		cam.add_child(view)
		var art := AwWeaponVisual.make(id)
		AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[id])
		view.equip(art)
		view.set_kick_params(def.params if after else {})
		view.fire_interval = float(def.use_interval_ticks) / float(AwWeaponPack.TICK_RATE)
		var fx: AwShotFx = null
		if mode == "fx":
			fx = _shot_fx(true)
			# As the game's load cover does: the gun's first-person flash is built before the first shot.
			var category: String = AwShotFx.CLASS_CATEGORY.get(AwWeaponSound.class_for(id, DotWeaponOutcome.KIND_SHOT), "rifle")
			DotWeaponMuzzle.warm(fx, category, def, true)
			# And, as its load gate does, the effects' shared materials are drawn once, so no shot compiles one.
			var warmup := DotRenderWarmup.new()
			warmup.add_items(AwShotFx.warm())
			cam.add_child(warmup)
			warmup.start()
			await warmup.finished
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
		if fx != null:
			fx.first_person_flash_scale = view.flash_scale()
			fx.play_use(shot, view.muzzle_transform(), id)
			if view.ejects():
				fx.play_eject(view.eject_transform(), id, view.eject_speed(), view.eject_scale())
		var frame := 0
		var peak := 0.0
		for col in frames.size():
			while frame < int(frames[col]):
				view.advance(1.0 / 60.0)
				frame += 1
				peak = maxf(peak, view.view_punch().x)
				if fx != null:
					await process_frame
			var p := view.view_punch()
			cam.rotation_degrees = Vector3(p.x, p.y, 0.0)
			if fx != null:
				await RenderingServer.frame_post_draw
			else:
				await process_frame
				await process_frame
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(W, H)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(col * W, row * H))
		print("RESULT %s %s camera_peak=%.2f%s" % [id, mode, peak, _fx_line(fx)])
		if fx != null:
			fx.free()
		view.free()
		cam.free()
	out = ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	quit()


func _shot_fx(first_person: bool) -> AwShotFx:
	var fx := AwShotFx.new()
	fx.first_person = first_person
	fx.sounds = false
	fx.binbun_flash = not _proc
	root.add_child(fx)
	return fx


func _fx_line(fx: AwShotFx) -> String:
	return "" if fx == null else " shells=%d live=%d" % [fx.shell_count(), fx.live_count()]


## The gun held 2.2 m ahead, muzzle to the right and its ejection port to the camera, fired as somebody else's shot.
func _third_person(id: StringName, cam: Camera3D, frames: Array, sheet: Image, row: int) -> void:
	cam.fov = 40.0
	var held := AwWorldModel.new()
	held.sounds = false
	root.add_child(held)
	held.position = Vector3(-0.2, 1.45, -2.2)
	held.rotation_degrees = Vector3(0, -90, 0)
	held.effects = true
	var art := AwWeaponVisual.make(id)
	AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[id])
	held.equip(art)
	for _i in 10:
		await process_frame
	var fx: AwShotFx = held._shot_fx()
	fx.binbun_flash = not _proc
	held.on_fired(Vector2(0.5, 0.1), AwWeaponNet.KIND_SHOT, true)
	var frame := 0
	for col in frames.size():
		while frame < int(frames[col]):
			frame += 1
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(W, H)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(col * W, row * H))
	print("RESULT %s tp%s" % [id, _fx_line(fx)])
	held.free()


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
