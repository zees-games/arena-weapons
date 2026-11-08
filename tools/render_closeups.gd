extends SceneTree
## Close-up model viewer: every named model under studio light (sun, fill, sky reflections), fixed cameras each, one png per view.
## A fixed camera per view (fitted to the model's bounds) so a before and an after frame line up exactly.
##   godot --path . --resolution 1600x900 --script tools/render_closeups.gd -- <out dir> <model name>...
## Views: side (whole profile), q34 (front three-quarter from above), q34b (rear three-quarter from below), detail (receiver, 0.30 m away, a
## first-person distance), muzzle (front end close up). Env RENDER_DIR points at another models folder (to render a before build).

const VIEWS := ["side", "q34", "q34b", "detail", "muzzle", "fp"]


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
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 140, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.8, 0.88, 1.0)
	root.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 40.0
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
		for v in VIEWS:
			var pos := Vector3()
			var look := c
			var f := 40.0
			var dist := r / tan(deg_to_rad(f * 0.5)) * 1.05
			match v:
				"side":
					pos = c + Vector3(1, 0, 0) * dist
				"q34":
					pos = c + Vector3(0.75, 0.55, -0.9).normalized() * dist
				"q34b":
					pos = c + Vector3(-0.8, -0.35, 0.8).normalized() * dist
				"detail":
					pos = c + Vector3(0.30, 0.10, 0.0)
					f = 50.0
				"fp":
					# hand-held: eye behind the stock, weapon low right of centre, in-game hands fov (~74 deg vertical)
					pos = Vector3(c.x - 0.13, c.y + 0.13, box.end.z + 0.10)
					look = Vector3(c.x - 0.04, c.y - 0.01, box.position.z + box.size.z * 0.45)
					f = 74.0
				"muzzle":
					var mz := Vector3(c.x, c.y, box.position.z + minf(box.size.z * 0.12, 0.12))
					pos = mz + Vector3(0.22, 0.09, -0.18)
					look = mz
					f = 50.0
			cam.fov = f
			cam.global_position = pos
			cam.look_at(look)
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
	pm.sky_top_color = Color(0.32, 0.5, 0.82)
	pm.sky_horizon_color = Color(0.72, 0.78, 0.86)
	pm.ground_horizon_color = Color(0.55, 0.52, 0.48)
	pm.ground_bottom_color = Color(0.2, 0.19, 0.18)
	sky.sky_material = pm
	e.sky = sky
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.30, 0.32, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return e
