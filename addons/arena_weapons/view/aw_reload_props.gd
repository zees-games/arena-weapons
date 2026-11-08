extends Node3D

## What a reload sequence (aw_reload_sequence.gd) has in sight this frame: one part per track, built in code on first
## use and placed in the holder's space. Preloaded by path (no class_name), as the sequence is.

const ReloadParts := preload("aw_reload_parts.gd")
const HandReach := preload("aw_hand_reach.gd")

## Called on every part built, so it draws as the view model does (no shadow, sorted over the world).
var on_top: Callable
var _nodes: Dictionary = {}
var _own: Node3D = null
var _own_rest := Transform3D.IDENTITY
var _own_local := Transform3D.IDENTITY
var _own_centre := Vector3.ZERO


## Carries the gun's own magazine [param node] (at [param rest] in the holder) for the magazine tracks: the node itself, which
## is a part of the weapon, pulled out of it and put back, not a copy beside it.
func use_own(node: Node3D, rest: Transform3D) -> void:
	_own = node
	_own_rest = rest
	_own_local = node.transform
	# Centred on its middle so the hand carries it by its body.
	_own_centre = HandReach.bounds_in(node, node).get_center()


## Puts the gun's own magazine back in its well, as the model has it.
func restore_own() -> void:
	if _own != null and is_instance_valid(_own):
		_own.transform = _own_local
		_own.visible = true


## Places every track of [param seq] at [param f]; [param to_holder] takes Aim space to this node's, [param size] scales the parts.
func show_at(seq: RefCounted, f: float, to_holder: Transform3D, size: float) -> void:
	var own_moving := false
	for e: Dictionary in seq.call(&"props_at", f):
		var is_own: bool = _own != null and e.get("own", false)
		var node: Node3D = null if is_own else _nodes.get(e.index)
		if not e.shown:
			if node != null:
				node.visible = false
			continue
		var turn: Vector3 = e.turn
		var at: Vector3 = to_holder * (e.at as Vector3)
		var turned := Basis.from_euler(turn * (PI / 180.0))
		if is_own:
			if at.is_finite():
				_own.global_transform = global_transform * (Transform3D(turned, at) * Transform3D(_own_rest.basis, _own_rest.basis * -_own_centre))
				_own.visible = true
				own_moving = true
			continue
		if node == null:
			node = ReloadParts.build(e.part)
			if node == null:
				continue
			add_child(node)
			if on_top.is_valid():
				on_top.call(node)
			_nodes[e.index] = node
		node.transform = Transform3D(turned.scaled(Vector3.ONE * size), at)
		node.visible = at.is_finite()
	if _own != null and not own_moving:
		# In its well until the hand pulls it, out of sight while the hand fetches the next, in its well again.
		_own.transform = _own_local
		_own.visible = not bool(seq.call(&"own_magazine_out", f))


## How many parts named [param part] are drawn now; every part when empty.
func shown(part: StringName = &"") -> int:
	var n := 1 if _own != null and is_instance_valid(_own) and _own.visible and part in [&"", &"own_magazine"] else 0
	for k: Variant in _nodes:
		var node: Node3D = _nodes[k]
		if node.visible and (part == &"" or node.get_meta(&"part", &"") == part):
			n += 1
	return n


## Magazines in sight now: the gun's own, if it is, and every built magazine, cell or box part.
func magazines_visible() -> int:
	var n := 1 if _own != null and is_instance_valid(_own) and _own.is_visible_in_tree() else 0
	for k: Variant in _nodes:
		var node: Node3D = _nodes[k]
		if node.visible and node.get_meta(&"part", &"") in [&"box_magazine", &"cell", &"ammo_box"]:
			n += 1
	return n
