extends SceneTree
## Contact sheet of fitted attachments: rows are guns (args after the output), columns the first-person hip and aimed
## frames and a side-on third-person frame for fitting A (holo or red dot, suppressor, vertical grip, laser, extended
## magazine), then aimed and third person for fitting B (scope or prism, compensator, angled grip). A mount the gun lacks
## or an attachment it refuses is left off. tools/render_attachments.sh <out.png under the project> <gun>...

const W := 480
const H := 270
const FIT_A := {&"optic": [&"holo", &"red_dot"], &"muzzle": [&"suppressor"], &"underbarrel": [&"vertical_grip"], &"side": [&"laser"], &"magazine": [&"extended_mag"]}
const FIT_B := {&"optic": [&"scope_6x", &"prism_3x", &"red_dot"], &"muzzle": [&"compensator"], &"underbarrel": [&"angled_grip"]}
const FOV := 80.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var guns: Array = a.slice(1)
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
	var cat := AwSpawnProvider.attachment_defs()
	var defs := {}
	for d in AwWeaponPack.weapons({}, "", false):
		defs[d.id] = d
	var sheet := Image.create(W * 5, H * guns.size(), false, Image.FORMAT_RGB8)
	for row in guns.size():
		var id := StringName(guns[row])
		var def: DotWeaponDef = defs[id]
		var choices := cat.choices_for(def)
		var fa := _fitting(id, choices, FIT_A)
		var fb := _fitting(id, choices, FIT_B)
		print("RESULT %s mounts=%s A=%s B=%s valid=%s/%s" % [id, def.mounts, fa.ids(), fb.ids(), cat.validate_fitting(def, fa).ok, cat.validate_fitting(def, fb).ok])
		await _first_person(id, fa, false, sheet, Vector2i(0, row))
		await _first_person(id, fa, true, sheet, Vector2i(1, row))
		await _third_person(id, fa, sheet, Vector2i(2, row))
		await _first_person(id, fb, true, sheet, Vector2i(3, row))
		await _third_person(id, fb, sheet, Vector2i(4, row))
	out = ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	quit()


func _fitting(id: StringName, choices: Dictionary, wanted: Dictionary) -> DotWeaponFitting:
	var fit := DotWeaponFitting.make(id)
	for mount: StringName in wanted:
		for att: StringName in wanted[mount]:
			if (choices.get(mount, []) as Array).has(att):
				fit.fit(mount, att)
				break
	return fit


func _camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.position = Vector3(0, 1.6, 0)
	root.add_child(cam)
	cam.current = true
	return cam


func _first_person(id: StringName, fit: DotWeaponFitting, aimed: bool, sheet: Image, cell: Vector2i) -> void:
	var cam := _camera()
	var view := AwViewModel.new()
	view.hands_fov = 55.0
	view.process_mode = Node.PROCESS_MODE_DISABLED
	cam.add_child(view)
	var art := AwWeaponVisual.make(id)
	AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[id])
	view.equip(art)
	view.set_fitting(fit)
	view.aim(aimed)
	for _i in 120:
		view.advance(1.0 / 60.0)
		cam.fov = FOV * view.aim_fov_scale()
		await process_frame
	await _grab(sheet, cell)
	view.free()
	cam.free()


## The gun held 1.6 m ahead, muzzle to the right and its ejection port to the camera.
func _third_person(id: StringName, fit: DotWeaponFitting, sheet: Image, cell: Vector2i) -> void:
	var cam := _camera()
	cam.fov = 40.0
	var held := AwWorldModel.new()
	held.sounds = false
	held.effects = false
	root.add_child(held)
	held.position = Vector3(-0.15, 1.5, -1.6)
	held.rotation_degrees = Vector3(0, -90, 0)
	var art := AwWeaponVisual.make(id)
	AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[id])
	held.equip(art)
	held.set_fitting(fit)
	for _i in 10:
		await process_frame
	await _grab(sheet, cell)
	held.free()
	cam.free()


func _grab(sheet: Image, cell: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(W, H)
	sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(cell.x * W, cell.y * H))


## A floor and a far wall of posts with a red one at the crosshair, so an optic's picture has something to show.
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
