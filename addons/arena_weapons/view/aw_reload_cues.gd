extends RefCounted

## Which handling sound plays at which moment of a reload: a plan of [code]{t, cue, db}[/code] read off the phases of an
## AwReloadSequence, so a sound lands on the part of the animation that makes it (the magazine leaving, the slide
## going forward, the cover shutting) instead of at the start and end of the reload.
##
## Pure: no nodes, no audio. [method plan] is what the view model plays from and what the headless checks read.
## The cue names are dot-audio's `stock/weapons/cue_<name>_<n>.ogg`.

## Per style: phase name -> [[where in the phase 0..1, cue name, decibels], ...].
const TABLE := {
	&"magazine": {
		&"mag_out": [[0.0, &"mag_release", -6.0], [0.4, &"mag_out", 0.0]],
		&"pouch": [[0.5, &"pouch", -8.0]],
		&"mag_in": [[0.7, &"mag_slide_in", -3.0]],
		&"seat": [[0.6, &"mag_seat", 0.0]],
		&"charge_back": [[0.0, &"charge_back", -2.0], [1.0, &"charge_fwd", -2.0]],
	},
	&"pistol": {
		&"mag_out": [[0.0, &"mag_release", -6.0], [0.4, &"mag_out", 0.0]],
		&"pouch": [[0.5, &"pouch", -8.0]],
		&"mag_in": [[0.7, &"mag_slide_in", -3.0]],
		&"seat": [[0.6, &"mag_seat", 0.0]],
		&"slide_back": [[0.0, &"rack_back", -2.0], [1.0, &"rack_fwd", -2.0]],
	},
	&"cell": {
		&"mag_out": [[0.3, &"cell_out", 0.0]],
		&"pouch": [[0.5, &"pouch", -8.0]],
		&"mag_in": [[0.7, &"cell_in", -2.0]],
		&"charge_back": [[0.0, &"cell_charge", -2.0]],
	},
	&"revolver": {
		&"open": [[0.2, &"cyl_open", 0.0]],
		&"dump": [[0.4, &"cyl_dump", 0.0]],
		&"fetch": [[0.5, &"pouch", -9.0]],
		&"load": [[0.4, &"speedloader_in", -2.0]],
		&"twist": [[0.5, &"cyl_twist", -4.0]],
		&"close": [[0.9, &"cyl_close", 0.0]],
	},
	&"launcher": {
		&"open": [[0.2, &"break_open", 0.0]],
		&"eject": [[0.4, &"case_eject", -2.0]],
		&"close": [[0.9, &"break_close", 0.0]],
	},
	&"tube": {
		&"pump_back": [[0.2, &"pump_back", 0.0]],
		&"pump": [[0.3, &"pump_fwd", 0.0]],
	},
	&"bolt": {
		&"bolt_up": [[0.3, &"bolt_lift", -2.0]],
		&"bolt_back": [[0.3, &"bolt_back", 0.0]],
		&"clip_c": [[0.4, &"clip_in", -2.0]],
		&"press_c": [[0.8, &"clip_press", -2.0]],
		&"bolt_fwd": [[0.3, &"bolt_fwd", 0.0]],
		&"bolt_down": [[0.8, &"bolt_down", -2.0]],
	},
	&"belt": {
		&"cover_open": [[0.3, &"cover_open", 0.0]],
		&"box_out": [[0.5, &"box_out", -2.0]],
		&"box_in": [[0.7, &"box_in", -2.0]],
		&"belt_lay": [[0.4, &"belt_lay", -3.0]],
		&"cover_close": [[0.8, &"cover_close", -1.0]],
		&"slap": [[0.4, &"cover_slap", 0.0]],
		&"charge": [[0.3, &"charge_back", -2.0]],
		&"charge_back": [[0.8, &"charge_fwd", -2.0]],
	},
}

## Extra cues for a revolver's single rounds and a launcher's shells, which have a numbered phase each.
const NUMBERED := {
	&"revolver": {&"load_": [0.9, &"round_tick", -4.0]},
	&"launcher": {&"load_": [0.9, &"shell_load", -2.0]},
}

## An empty magazine falls instead of being carried off.
const DROP := [0.8, &"mag_drop", -3.0]


## Every cue name this module can ask for, so a test can check the stock has them all.
static func all_cues() -> Array[StringName]:
	var seen: Array[StringName] = []
	for style: StringName in TABLE:
		for phase: StringName in TABLE[style]:
			for e: Array in TABLE[style][phase]:
				if not seen.has(e[1]):
					seen.append(e[1])
	seen.append(DROP[1])
	for style: StringName in NUMBERED:
		for k: StringName in NUMBERED[style]:
			if not seen.has(NUMBERED[style][k][1]):
				seen.append(NUMBERED[style][k][1])
	return seen


## The plan for [param seq]: [code][{t, cue, db, phase}][/code] sorted by [code]t[/code] (a fraction of the reload, 0 to 1).
## Empty for a style without a table or a sequence without phases.
static func plan(seq: RefCounted) -> Array:
	var out: Array = []
	if seq == null or not seq.get(&"phases") is Array:
		return out
	var style: StringName = seq.get(&"style")
	var table: Dictionary = TABLE.get(style, {})
	var numbered: Dictionary = NUMBERED.get(style, {})
	var empty: bool = bool(seq.get(&"empty"))
	for p: Dictionary in seq.phases:
		var name: StringName = p.name
		var rows: Array = table.get(name, [])
		for k: StringName in numbered:
			if String(name).begins_with(String(k)):
				rows = [numbered[k]]
		if empty and name == &"mag_out" and (style == &"magazine" or style == &"pistol"):
			rows = rows + [DROP]
		for e: Array in rows:
			var t0 := float(p.t0)
			var t1 := float(p.t1)
			out.append({"t": clampf(lerpf(t0, t1, float(e[0])), 0.0, 1.0), "cue": e[1], "db": float(e[2]), "phase": name})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	return out


## The cues of [param cue_plan] due at reload fraction [param f] that have not played (those at index [param next] on).
## Returns the new index in [code]next[/code] of the result and the due cues in [code]due[/code].
static func due(cue_plan: Array, next: int, f: float) -> Dictionary:
	var due_cues: Array = []
	while next < cue_plan.size() and float(cue_plan[next].t) <= f:
		due_cues.append(cue_plan[next])
		next += 1
	return {"next": next, "due": due_cues}
