extends SceneTree
## Measures each model's mesh bounds per surface (model space) and a profile of the vertices along Y, to place grip_socket / support_grip.
## godot --headless --path . --script res://tools/grip_probe.gd -- revolver pistol_ph


func _initialize() -> void:
	for name: String in OS.get_cmdline_user_args():
		var scene: Node = (load("res://addons/arena_weapons/assets/models/%s.glb" % name) as PackedScene).instantiate()
		root.add_child(scene)
		print("MODEL %s" % name)
		var all := AABB()
		var seeded := false
		var verts: PackedVector3Array = []
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != scene.get_parent():
				if n is Node3D:
					xf = (n as Node3D).transform * xf
				n = n.get_parent()
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var b := AABB()
				for i in vs.size():
					var p := xf * vs[i]
					verts.append(p)
					b = AABB(p, Vector3.ZERO) if i == 0 else b.expand(p)
				var mat := mi.mesh.surface_get_material(s)
				print("  surf %s/%d mat=%s pos=%s size=%s" % [mi.name, s, mat.resource_name if mat else "-", _f(b.position), _f(b.size)])
				all = b if not seeded else all.merge(b)
				seeded = true
		print("  ALL pos=%s size=%s centre=%s" % [_f(all.position), _f(all.size), _f(all.get_center())])
		for k in 10:
			var y0 := all.position.y + all.size.y * k / 10.0
			var y1 := y0 + all.size.y / 10.0
			var zmin := INF
			var zmax := -INF
			var cnt := 0
			for p in verts:
				if p.y >= y0 and p.y < y1 + (0.0001 if k == 9 else 0.0):
					zmin = minf(zmin, p.z)
					zmax = maxf(zmax, p.z)
					cnt += 1
			print("  y[%.3f..%.3f] z[%.3f..%.3f] n=%d" % [y0, y1, zmin, zmax, cnt])
		scene.queue_free()
	quit()


func _f(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]
