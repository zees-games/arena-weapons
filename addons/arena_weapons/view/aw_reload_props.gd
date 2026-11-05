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


## Carries a copy of the gun's own magazine [param node] (at [param rest] in the holder) for the magazine tracks, not a built part.
func use_own(node: Node3D, rest: Transform3D) -> void:
	_own = node
	_own_rest = rest


## Places every track of [param seq] at [param f]; [param to_holder] takes Aim space to this node's, [param size] scales the parts.
func show_at(seq: RefCounted, f: float, to_holder: Transform3D, size: float) -> void:
	for e: Dictionary in seq.call(&"props_at", f):
		var node: Node3D = _nodes.get(e.index)
		if not e.shown:
			if node != null:
				node.visible = false
			continue
		if node == null:
			node = _own_copy() if _own != null and e.get("own", false) else ReloadParts.build(e.part)
			if node == null:
				continue
			add_child(node)
			if on_top.is_valid():
				on_top.call(node)
			_nodes[e.index] = node
		var turn: Vector3 = e.turn
		var at: Vector3 = to_holder * (e.at as Vector3)
		var turned := Basis.from_euler(turn * (PI / 180.0))
		node.transform = Transform3D(turned if node.has_meta(&"own") else turned.scaled(Vector3.ONE * size), at)
		node.visible = at.is_finite()


## How many parts named [param part] are drawn now; every part when empty.
func shown(part: StringName = &"") -> int:
	var n := 0
	for k: Variant in _nodes:
		var node: Node3D = _nodes[k]
		if node.visible and (part == &"" or node.get_meta(&"part", &"") == part):
			n += 1
	return n


## The own magazine as drawn in the gun, centred on its middle so the hand carries it by its body.
func _own_copy() -> Node3D:
	var copy := _own.duplicate() as Node3D
	copy.visible = true
	copy.transform = Transform3D(_own_rest.basis, _own_rest.basis * -HandReach.bounds_in(_own, _own).get_center())
	var node := Node3D.new()
	node.set_meta(&"own", true)
	node.set_meta(&"part", &"own_magazine")
	node.add_child(copy)
	return node
