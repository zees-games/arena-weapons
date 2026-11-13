extends SceneTree
## Prints each gun's attachment sockets in model space, for AwAttachmentSockets.SOCKETS: muzzle at the bore's tip,
## optic on the receiver top, underbarrel and side on the fore-end, magazine under the mag node.
## godot --headless --path . --script res://tools/measure_sockets.gd [-- id ...]

const SKIP := [&"knife", &"frag", &"sticky", &"flash", &"smoke", &"incendiary"]


func _initialize() -> void:
	var ids: Array = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = AwWeaponArt.WEAPONS.keys().filter(func(id: StringName) -> bool: return not SKIP.has(id))
	for id: Variant in ids:
		var art := AwWeaponVisual.new()
		AwArtDress.apply(art, AwWeaponArt.row_of(StringName(str(id))))
		var gun := AwModelCache.instantiate(art.model_path)
		if gun == null:
			print("# %s: no model %s" % [id, art.model_path])
			continue
		print(_row(StringName(str(id)), art, gun))
		gun.free()
	quit()


func _row(id: StringName, art: AwWeaponVisual, gun: Node3D) -> String:
	var f := art.model_forward.normalized()
	var verts := _verts(gun, gun)
	var tip := -INF
	var tail := INF
	for p in verts:
		tip = maxf(tip, p.dot(f))
		tail = minf(tail, p.dot(f))
	var length := tip - tail
	var bore := _centre(verts, f, tip - 0.015 * length, tip)
	bore -= f * bore.dot(f)
	var out := {}
	out["muzzle"] = bore + f * tip
	var top := _band(verts, f, tail + 0.30 * length, tail + 0.55 * length)
	out["optic"] = Vector3(bore.x, top.end.y, 0.0) + f * (tail + 0.42 * length)
	var fore := _band(verts, f, tail + 0.68 * length, tail + 0.80 * length)
	var wide := 0.0
	while fore.size == Vector3.ZERO and wide < 0.3:
		# A long tube with vertices only at its ends leaves the band empty: widen it.
		wide += 0.05
		fore = _band(verts, f, tail + (0.68 - wide) * length, tail + (0.80 + wide) * length)
	out["underbarrel"] = Vector3(bore.x, fore.position.y, 0.0) + f * (tail + 0.74 * length)
	out["side"] = Vector3(fore.end.x, bore.y, 0.0) + f * (tail + 0.70 * length)
	var mag := gun.find_child(String(art.hide_during_reload), true, false) if art.hide_during_reload != &"" else null
	if mag != null:
		var box := _box(_verts(mag, gun))
		out["magazine"] = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var parts := PackedStringArray()
	for mount: String in out:
		var v: Vector3 = out[mount]
		parts.append("\"%s\": Vector3(%.3f, %.3f, %.3f)" % [mount, v.x, v.y, v.z])
	return "\t&\"%s\": {%s},  # %.3f long" % [id, ", ".join(parts), length]


func _verts(node: Node, space: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var up: Node = mi
		while up != null and up != space:
			if up is Node3D:
				xf = (up as Node3D).transform * xf
			up = up.get_parent()
		for s in mi.mesh.get_surface_count():
			var vs: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in vs:
				out.append(xf * v)
	return out


func _centre(verts: PackedVector3Array, f: Vector3, lo: float, hi: float) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for p in verts:
		var t := p.dot(f)
		if t >= lo and t <= hi:
			sum += p
			n += 1
	return sum / maxf(n, 1)


func _band(verts: PackedVector3Array, f: Vector3, lo: float, hi: float) -> AABB:
	var inside := PackedVector3Array()
	for p in verts:
		var t := p.dot(f)
		if t >= lo and t <= hi:
			inside.append(p)
	return _box(inside)


func _box(verts: PackedVector3Array) -> AABB:
	if verts.is_empty():
		return AABB()
	var box := AABB(verts[0], Vector3.ZERO)
	for p in verts:
		box = box.expand(p)
	return box
