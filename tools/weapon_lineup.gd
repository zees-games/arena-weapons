extends SceneTree
## Consistent test scene for every weapon: neutral studio light (no coloured sky), the same camera angle and FOV for all.
## Per weapon two frames: <name>_fp.png (hand-held first-person: eye just behind the stock end, fixed offsets from the bounds, 74 deg vertical
## fov like the in-game hands) and <name>_tp.png (third person / world view: fixed 3/4 direction, 40 deg fov, distance fitted to the
## model's bounds so every gun fills the frame the same way).
##   godot --path . --resolution 960x540 --script tools/weapon_lineup.gd -- <out dir> <model name>...
## Env RENDER_DIR points at another folder of .glb (the "before" set, e.g. main's models).

const TP_DIR := Vector3(0.80, 0.40, -0.75)


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	DirAccess.make_dir_recursive_absolute(out)
	var dir := OS.get_environment("RENDER_DIR")
	if dir == "":
		dir = "res://addons/arena_weapons/assets/models"
	var env := WorldEnvironment.new()
	env.environment = _environment()
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.4
	root.add_child(fill)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	for i in range(1, a.size()):
		var n := a[i]
		var m: Node3D = null
		if dir.begins_with("/"):
			var gd := GLTFDocument.new()
			var gs := GLTFState.new()
			if gd.append_from_file("%s/%s.glb" % [dir, n], gs) == OK:
				m = gd.generate_scene(gs) as Node3D
		else:
			var ps := load("%s/%s.glb" % [dir, n]) as PackedScene
			if ps != null:
				m = ps.instantiate() as Node3D
		if m == null:
			print("MISSING ", n)
			continue
		root.add_child(m)
		var box := _bounds(m)
		var c := box.get_center()
		var r := box.size.length() * 0.5
		for v in ["fp", "tp"]:
			if v == "fp":
				cam.fov = 74.0
				# eye just behind the stock end and a little above and left of the gun, looking down its length (same offsets for all)
				cam.global_position = Vector3(c.x - 0.13, c.y + 0.13, box.end.z + 0.10)
				cam.look_at(Vector3(c.x - 0.04, c.y - 0.01, box.position.z + box.size.z * 0.45))
			else:
				cam.fov = 40.0
				cam.global_position = c + TP_DIR.normalized() * (r / tan(deg_to_rad(20.0)) * 0.78)
				cam.look_at(c)
			for k in 6:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, n, v])
		m.queue_free()
		await process_frame
		print("RESULT ", n)
	quit()


func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _environment() -> Environment:
	var e := Environment.new()
	var sky := Sky.new()
	var pm := ProceduralSkyMaterial.new()
	pm.sky_top_color = Color(0.62, 0.62, 0.63)
	pm.sky_horizon_color = Color(0.74, 0.73, 0.71)
	pm.ground_horizon_color = Color(0.46, 0.44, 0.42)
	pm.ground_bottom_color = Color(0.22, 0.21, 0.2)
	sky.sky_material = pm
	e.sky = sky
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.36, 0.37)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return e
