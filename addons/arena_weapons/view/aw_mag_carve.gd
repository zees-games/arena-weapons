extends RefCounted

## Splits a gun's magazine out of a model drawn as one welded mesh, so the magazine is a node of the weapon hierarchy
## (a child of the mesh's parent, at its transform) that a reload can pull out, carry in the support hand and seat again.
## The triangles whose middle lies in a box move to a new "Magazine" mesh; the rest stay on the gun.
## Preloaded by path (no class_name), as its siblings are.

const HandReach := preload("aw_hand_reach.gd")
const MIN_TRIANGLES := 12

## key -> {mesh path: [rest ArrayMesh, magazine ArrayMesh, magazine triangle count]}, so a weapon equipped twice is split once.
static var _cache: Dictionary = {}
## model path -> the magazine's box in the weapon's parent (holder) space, kept by the first person view that measured it so the
## watcher's model of the same gun splits the same triangles.
static var _boxes: Dictionary = {}


static func remember(model_path: String, box: AABB) -> void:
	_boxes[model_path] = box


## The box [method remember] was given for [param model_path], or an empty AABB.
static func recall(model_path: String) -> AABB:
	return _boxes.get(model_path, AABB())


## Puts a carved magazine back into the mesh it came from and frees its node, so a gun nobody is reloading is one mesh again.
static func merge_back(mag: Node3D) -> void:
	if mag == null or not is_instance_valid(mag):
		return
	var source: Variant = mag.get_meta(&"source", null)
	var whole: Variant = mag.get_meta(&"whole", null)
	if source is MeshInstance3D and is_instance_valid(source) and whole is Mesh:
		(source as MeshInstance3D).mesh = whole
	mag.get_parent().remove_child(mag)
	mag.queue_free()


## Splits [param weapon]'s magazine out and returns the new node, or null when too little of the gun lies in [param box].
## The box is in the space [param to_space] takes [param space]'s own space to ([param space] is an ancestor of [param weapon]).
## [param key] names the split for the cache.
static func carve(weapon: Node3D, space: Node3D, to_space: Transform3D, box: AABB, key: String) -> Node3D:
	var best: MeshInstance3D = null
	var best_count := 0
	var fresh := not _cache.has(key)
	var entry: Dictionary = _cache.get(key, {})
	for mi: MeshInstance3D in HandReach.meshes(weapon):
		if mi.mesh == null or mi.get_meta(&"carved", false):
			continue
		var rel := str(weapon.get_path_to(mi))
		var pair: Array = entry.get(rel, [])
		if fresh:
			pair = _split(mi.mesh, to_space * _relative(mi, space), box)
			if not pair.is_empty():
				entry[rel] = pair
		if pair.is_empty():
			continue
		if int(pair[2]) > best_count:
			best_count = int(pair[2])
			best = mi
	if fresh:
		_cache[key] = entry
	if best == null or best_count < MIN_TRIANGLES:
		return null
	var chosen: Array = entry[str(weapon.get_path_to(best))]
	var mag := MeshInstance3D.new()
	mag.name = "Magazine"
	mag.mesh = chosen[1]
	mag.transform = best.transform
	mag.set_meta(&"carved", true)
	mag.set_meta(&"source", best)
	mag.set_meta(&"whole", best.mesh)
	mag.material_override = best.material_override
	mag.layers = best.layers
	mag.cast_shadow = best.cast_shadow
	best.mesh = chosen[0]
	best.get_parent().add_child(mag)
	for s in mag.mesh.get_surface_count():
		var override := best.get_surface_override_material(s)
		if override != null:
			mag.set_surface_override_material(s, override)
	return mag


static func _relative(node: Node3D, space: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != space:
		if walk is Node3D:
			t = (walk as Node3D).transform * t
		walk = walk.get_parent()
	return t


## [rest mesh, magazine mesh, magazine triangle count], or empty when nothing of [param mesh] is in the box.
static func _split(mesh: Mesh, xf: Transform3D, box: AABB) -> Array:
	var rest := ArrayMesh.new()
	var mag := ArrayMesh.new()
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		var idx := PackedInt32Array()
		if index is PackedInt32Array and not (index as PackedInt32Array).is_empty():
			idx = index
		else:
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var keep := PackedInt32Array()
		var take := PackedInt32Array()
		for i in range(0, idx.size() - 2, 3):
			var c := (verts[idx[i]] + verts[idx[i + 1]] + verts[idx[i + 2]]) / 3.0
			if box.has_point(xf * c):
				take.append(idx[i])
				take.append(idx[i + 1])
				take.append(idx[i + 2])
			else:
				keep.append(idx[i])
				keep.append(idx[i + 1])
				keep.append(idx[i + 2])
		total += take.size() / 3
		_add_surface(rest, mesh, s, arrays, keep)
		_add_surface(mag, mesh, s, arrays, take)
	if total == 0:
		return []
	return [rest, mag, total]


static func _add_surface(into: ArrayMesh, from: Mesh, s: int, arrays: Array, idx: PackedInt32Array) -> void:
	if idx.is_empty():
		# Nothing of this material here; the slot is not needed, a mesh with no surface for it draws the same.
		return
	# Only the vertices these triangles use, so each half has its own bounds and no dead vertices.
	var remap := {}
	var order := PackedInt32Array()
	var fresh := PackedInt32Array()
	fresh.resize(idx.size())
	for i in idx.size():
		var v: int = idx[i]
		if not remap.has(v):
			remap[v] = order.size()
			order.append(v)
		fresh[i] = remap[v]
	var out := arrays.duplicate()
	for k in out.size():
		if k == Mesh.ARRAY_INDEX or out[k] == null:
			continue
		out[k] = _pick(out[k], order, k)
	out[Mesh.ARRAY_INDEX] = fresh
	into.add_surface_from_arrays(from.surface_get_primitive_type(s), out)
	into.surface_set_material(into.get_surface_count() - 1, from.surface_get_material(s))


## The entries of one vertex array at [param order]; per-vertex arrays only (tangents and bone weights have several floats a vertex).
static func _pick(arr: Variant, order: PackedInt32Array, kind: int) -> Variant:
	var size: int = int(arr.size())
	if size == 0:
		return arr
	var per := 1
	if kind == Mesh.ARRAY_TANGENT:
		per = 4
	elif kind == Mesh.ARRAY_BONES or kind == Mesh.ARRAY_WEIGHTS:
		per = 4 if size % 4 == 0 else 8
	var out: Variant = arr.duplicate()
	out.resize(order.size() * per)
	for i in order.size():
		for j in per:
			out[i * per + j] = arr[order[i] * per + j]
	return out
