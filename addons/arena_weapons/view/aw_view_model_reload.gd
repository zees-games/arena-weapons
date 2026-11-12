@tool
extends "aw_view_model_core.gd"

## AwViewModel's reload: the weapon's own phases, the parts the hand carries and the handling-sound cues.

const ReloadCues := preload("aw_reload_cues.gd")

## A handling sound is due: the reload reached the part of the animation that makes it (see AwReloadCues).
## Emitted once per cue, on the first update at or after its moment, so it is at most one update late.
signal reload_cue(cue: StringName, db: float)

## How far through a reload, 0 to 1; the magazine is animated from the same number.
func on_reload(fraction: float) -> void:
	_reload_fraction = clampf(fraction, 0.0, 1.0) if is_finite(fraction) else 0.0
	if _seq != null:
		if _reload_fraction > 0.0:
			_seq_ran = true
		elif _seq_ran:
			_end_sequence()
	_pose.set_reload(_reload_fraction)
	_animate_magazine(_reload_fraction)
	_fire_cues(_reload_fraction)


## True while a reload plays its handling sounds from the animation: the rig then leaves the two fixed reload sounds out.
func has_reload_cues() -> bool:
	return not _cue_plan.is_empty()


## The cue plan of the reload playing now (see [method AwReloadCues.plan]).
func reload_cue_plan() -> Array:
	return _cue_plan


func _fire_cues(f: float) -> void:
	if _cue_plan.is_empty() or f <= 0.0:
		return
	var step: Dictionary = ReloadCues.due(_cue_plan, _cue_next, f)
	_cue_next = int(step.next)
	for c: Dictionary in step.due:
		reload_cue.emit(c.cue, float(c.db))

var _seq_ran := false
var _cue_plan: Array = []
var _cue_next := 0


## A reload began with [param left] of [param magazine] rounds in: plays the weapon's own phases, sized to what is there.
## [param start_share] is the part before the first round of a reload by the round. Off under `cl_vm_reload_detail` 0.
func on_reload_begin(left: int, magazine: int, start_share: float = 0.0) -> void:
	_end_sequence()
	if _art == null or _weapon == null or _holder == null or feel_rules.reload_detail <= 0.0:
		return
	if ReloadSequence.style_of(_art) == &"generic":
		return
	var to_aim := _holder.transform
	var well: Variant = _well if _has_well and _art.reload.is_empty() else null
	var own := _own_magazine()
	if own != null and not (_art.reload.get("anchors", {}) as Dictionary).has("well"):
		well = to_aim * _in_holder(own) * HandReach.bounds_in(own, own).get_center()
	var anchors := ReloadSequence.anchors_for(_grip_at, _fore_at, to_aim * (_weapon.transform * _muzzle), well, _art.reload.get("anchors", {}), to_aim)
	var seq := ReloadSequence.new()
	seq.drop_always = feel_rules.reload_drop >= 0.5
	seq.charge_always = feel_rules.reload_charge >= 0.5
	seq.compose(_art, anchors, magazine, left, start_share)
	if seq.phases.is_empty():
		return
	_seq = seq
	_seq_ran = false
	_cue_plan = ReloadCues.plan(seq)
	_cue_next = 0
	_pose.tunables.reload_keys = seq.gun_keys
	var props := ReloadProps.new()
	props.name = "ReloadProps"
	props.on_top = _set_on_top
	if own != null:
		props.use_own(own, _in_holder(own))
	_holder.add_child(props)
	_props = props


## The gun's own magazine node (the row's `mag_node`), which the reload carries out and back in, or null.
func _own_magazine() -> Node3D:
	if _carved != null and is_instance_valid(_carved):
		return _carved
	if _art.hide_during_reload == &"" or _weapon == null:
		return null
	return _weapon.find_child(String(_art.hide_during_reload), true, false) as Node3D


## [param node]'s transform in the holder's space.
func _in_holder(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != _holder:
		if walk is Node3D:
			t = (walk as Node3D).transform * t
		walk = walk.get_parent()
	return t


## How many magazines are in sight now: the gun's own plus any built one. Exactly one in a sound reload, bar the moment the hand is fetching the next.
func reload_magazines_visible() -> int:
	if _props != null:
		return _props.magazines_visible()
	return 1 if _own_magazine() != null and _own_magazine().is_visible_in_tree() else 0


## The sequence playing now, or null.
func reload_sequence() -> ReloadSequence:
	return _seq


## How many reload parts named [param part] are drawn now (every part when empty).
func reload_parts_shown(part: StringName = &"") -> int:
	return _props.shown(part) if _props != null else 0


func _end_sequence() -> void:
	_set_bolt(0.0)
	_seq = null
	_cue_plan = []
	_cue_next = 0
	_seq_ran = false
	if _props != null:
		_props.restore_own()
		_props.queue_free()
		_props = null
	if _art != null:
		_pose.tunables.reload_keys = _default_reload_keys()
		if _carved != null and is_instance_valid(_carved):
			_carved.visible = true
		if _magazine != null:
			_magazine.visible = true
			_magazine.transform = _art.magazine_transform()


func _default_reload_keys() -> Array:
	return _art.reload_keys if not _art.reload_keys.is_empty() else AwWeaponArtTable.reload_keys(_art.pose)
