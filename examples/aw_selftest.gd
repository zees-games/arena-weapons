extends "aw_selftest_grenades.gd"

## Headless suite: models load with the muzzle where the table says and the stock clear of the eye at the sights,
## the provider's contract, the pack's own weapon definitions, and a base art dressed by role.
## What it cannot see is how they look: tools/screenshot.sh in game-arena renders the hands.

const IronSight := preload("res://addons/dot_weapon/view/dot_weapon_iron_sight.gd")
const CHECKS := 399
## Guns whose model shows its own notch, aperture or post (the rest aim at their row's written aim).
const ReloadSequence := preload("../addons/arena_weapons/view/aw_reload_sequence.gd")
const ReloadCues := preload("../addons/arena_weapons/view/aw_reload_cues.gd")
const OWN_SIGHTED := 9

func _ready() -> void:
	print("fc-weapons self-test")
	_models()
	_download_groups()
	_spans()
	_provider()
	_sound_classes()
	_defs()
	_fire_feel()
	_dress()
	await _fire_fx()
	_own_sights()
	_scope_hides_gun()
	_scope_modes()
	_reload_cues()
	_reload_drop_charge()
	await _floor_clip()
	await _near_plane_clip()
	await _shot_fx_pool()
	await _fx_pool()
	await _previews()
	_grenades()
	_attachments()
	_utility()
	_glove_cache()
	_shared_catalogue()
	_mag_carve()
	_assets_pack()
	_charge_fizzle()
	await _one_arm_set()
	_charge_fizzle()
	_idle_sleep()
	_person_carry()
	_would_idle()
	await _finish()


## Every gun's reload plays its handling sounds off the animation's own phases: each cue sits inside the phase that
## makes it, they run in order, and a reload that ticks through fires each exactly once, at most one tick late.
func _reload_cues() -> void:
	_begin("reload sounds follow the reload animation")
	var rows := AwWeaponArt.weapon_rows("")
	var planned := 0
	var unplanned: Array[StringName] = []
	var off_phase: Array[String] = []
	var unsorted: Array[StringName] = []
	var late: Array[String] = []
	var named: Array[StringName] = []
	var empty_drop := 0
	var empty_mags := 0
	for role: StringName in rows:
		var row: Dictionary = rows[role]
		if row["motion"] != "gun":
			continue
		var art := AwWeaponVisual.make(role)
		AwArtDress.apply(art, row)
		var style := ReloadSequence.style_of(art)
		if style == &"generic":
			continue
		for left in [30, 0]:
			var seq := ReloadSequence.new()
			var anchors := ReloadSequence.anchors_for(Vector3.ZERO, Vector3(0, 0, -0.3), Vector3(0, 0, -0.6), null, art.reload.get("anchors", {}), Transform3D.IDENTITY)
			seq.compose(art, anchors, 30, left, 0.0)
			var plan := ReloadCues.plan(seq)
			if plan.is_empty():
				# A tube with nothing to pump (a reload that only pushes shells in) has no handling sound of its own.
				if not (style == &"tube" and left > 0):
					unplanned.append(role)
				continue
			planned += 1
			if left == 30 and "--plans" in OS.get_cmdline_user_args():
				print("PLAN ", JSON.stringify({"role": role, "style": style, "plan": plan.map(func(c: Dictionary) -> Dictionary: return {"t": snappedf(float(c.t), 0.001), "cue": c.cue, "db": c.db})}))
			var last := -1.0
			for c: Dictionary in plan:
				var ph := {}
				for p: Dictionary in seq.phases:
					if p.name == c.phase:
						ph = p
				if ph.is_empty() or float(c.t) < float(ph.t0) - 0.0001 or float(c.t) > float(ph.t1) + 0.0001:
					off_phase.append("%s/%s" % [role, c.cue])
				if float(c.t) < last or float(c.t) < 0.0 or float(c.t) > 1.0:
					unsorted.append(role)
				last = float(c.t)
				if not named.has(c.cue):
					named.append(c.cue)
			if left == 0 and (style == &"magazine" or style == &"pistol"):
				empty_mags += 1
				if plan.any(func(c: Dictionary) -> bool: return c.cue == &"mag_drop"):
					empty_drop += 1
			# Tick through a 90-tick reload: each cue fires once, on the first tick at or after its moment.
			var ticks := 90
			var next := 0
			var fired := 0
			for k in range(1, ticks):
				var step := ReloadCues.due(plan, next, float(k) / float(ticks))
				next = int(step.next)
				for c: Dictionary in step.due:
					fired += 1
					if float(k) / float(ticks) - float(c.t) >= 1.0 / float(ticks):
						late.append("%s/%s" % [role, c.cue])
			if fired != plan.filter(func(c: Dictionary) -> bool: return float(c.t) < float(ticks - 1) / float(ticks)).size():
				late.append("%s count %d" % [role, fired])
	_check("%d reloads (full and empty) of every non-generic gun have a cue plan (%s)" % [planned, str(unplanned)], planned > 0 and unplanned.is_empty())
	_check("every cue lies inside the phase that makes it (%s)" % str(off_phase.slice(0, 5)), off_phase.is_empty())
	_check("cues run in order inside 0..1 (%s)" % str(unsorted), unsorted.is_empty())
	_check("ticking a reload fires each cue once, at most one tick late (%s)" % str(late.slice(0, 5)), late.is_empty())
	var have := 0
	for cue in ReloadCues.all_cues():
		if DotWeaponSound.count(StringName("cue_%s" % cue)) > 0:
			have += 1
	_check("an empty magazine's reload drops it (%d of %d); stock has %d of %d cues (0 when dot-audio is not linked)" % [empty_drop, empty_mags, have, ReloadCues.all_cues().size()],
		empty_drop == empty_mags and (have == 0 or have == ReloadCues.all_cues().size()))
	_end()


## A magazine reload drops the old magazine and works the action on every reload by default (`cl_vm_reload_drop`,
## `cl_vm_reload_charge`, both 1), and only on an empty one with both 0; the new magazine ends exactly in its well, unturned,
## and the old and the new are never in sight together.
func _reload_drop_charge() -> void:
	_begin("magazine reloads drop the old magazine, seat the new one and work the action")
	var rows := AwWeaponArt.weapon_rows("")
	var wrong_default: Array[String] = []
	var wrong_off: Array[String] = []
	var off_well: Array[String] = []
	var both: Array[String] = []
	var rocked: Array[String] = []
	var mags := 0
	for role: StringName in rows:
		if rows[role]["motion"] != "gun":
			continue
		var art := AwWeaponVisual.make(role)
		AwArtDress.apply(art, rows[role])
		var style := ReloadSequence.style_of(art)
		if style != &"magazine" and style != &"pistol":
			continue
		mags += 1
		var anchors := ReloadSequence.anchors_for(Vector3.ZERO, Vector3(0, 0, -0.3), Vector3(0, 0, -0.6), null, art.reload.get("anchors", {}), Transform3D.IDENTITY)
		var action := &"slide_back" if style == &"pistol" else &"charge_back"
		for always: bool in [true, false]:
			for left: int in [30, 0]:
				var seq := ReloadSequence.new()
				seq.drop_always = always
				seq.charge_always = always
				seq.compose(art, anchors, 30, left, 0.0)
				var names: Array = seq.describe().phases
				var want := always or left == 0
				var dropped := names.has("drop") and ReloadCues.plan(seq).any(func(c: Dictionary) -> bool: return c.cue == &"mag_drop")
				var charged := names.has(String(action))
				var thrown := seq.props.any(func(p: Dictionary) -> bool: return p.part == &"round")
				if dropped != want or charged != want or thrown != (want and left > 0):
					(wrong_default if always else wrong_off).append("%s/%d" % [role, left])
				var seat_end := 0.0
				for p: Dictionary in seq.phases:
					if p.name == &"seat":
						seat_end = float(p.t1)
				# The ejected round (a full reload) comes first among the props: the magazines are the own ones, old then new.
				var end: Dictionary = seq.props_at(seat_end - 0.0005).filter(func(e: Dictionary) -> bool: return e.own)[1]
				if not end.shown or (end.at as Vector3).distance_to(anchors[&"well"]) > 0.004 or (end.turn as Vector3).length() > 0.5:
					off_well.append("%s/%d %s" % [role, left, str(end.at)])
				for k in 400:
					var shown := 0
					for e: Dictionary in seq.props_at(float(k) / 400.0):
						shown += 1 if e.own and e.shown else 0
					if shown > 1:
						both.append("%s/%d at %.3f" % [role, left, float(k) / 400.0])
						break
				if always and left == 30 and float(art.reload.get("rock", 0.0)) > 0.0:
					var out_end := 0.0
					for p: Dictionary in seq.phases:
						if p.name == &"mag_out":
							out_end = float(p.t1)
					var turn: Vector3 = seq.props_at(out_end - 0.0005).filter(func(e: Dictionary) -> bool: return e.own)[0].turn
					if absf(turn.x - float(art.reload.rock)) > 1.0:
						rocked.append("%s %.1f" % [role, turn.x])
	_check("%d magazine weapons: by default every reload drops the magazine (mag_drop cue) and works the action, a full one throwing its round (%s)" % [mags, str(wrong_default.slice(0, 4))], mags > 0 and wrong_default.is_empty())
	_check("with both off only an empty reload drops and works the action (%s)" % str(wrong_off.slice(0, 4)), wrong_off.is_empty())
	_check("the new magazine ends seated in its well, unturned (%s)" % str(off_well.slice(0, 3)), off_well.is_empty())
	_check("the old and the new magazine are never in sight together, and a rocking magazine leaves the well rocked (%s %s)" % [str(both.slice(0, 3)), str(rocked)], both.is_empty() and rocked.is_empty())
	var feel := AwViewFeel.new()
	var defaults := feel.reload_drop == 1.0 and feel.reload_charge == 1.0
	var set_ok := feel.set_cvar(AwViewFeel.CVAR_RELOAD_DROP, "0") and feel.set_cvar(AwViewFeel.CVAR_RELOAD_CHARGE, "0")
	_check("cl_vm_reload_drop and cl_vm_reload_charge default to 1 and set to 0 (%s %s)" % [defaults, set_ok],
		defaults and set_ok and feel.reload_drop == 0.0 and feel.reload_charge == 0.0)
	# The rifle's own bolt node rides back with the charging hand and is home again before the reload ends.
	var rifle := AwWeaponVisual.make(&"rifle")
	AwArtDress.apply(rifle, rows[&"rifle"])
	var bolt_seq := ReloadSequence.new()
	bolt_seq.compose(rifle, ReloadSequence.anchors_for(Vector3.ZERO, Vector3(0, 0, -0.3), Vector3(0, 0, -0.6), null, rifle.reload.get("anchors", {}), Transform3D.IDENTITY), 30, 30, 0.0)
	var peak := 0.0
	var start_back := bolt_seq.bolt_back(0.0)
	var end_back := bolt_seq.bolt_back(0.999)
	for k in 400:
		peak = maxf(peak, bolt_seq.bolt_back(float(k) / 400.0))
	var still := ReloadSequence.new()
	still.charge_always = false
	still.compose(rifle, ReloadSequence.anchors_for(Vector3.ZERO, Vector3(0, 0, -0.3), Vector3(0, 0, -0.6), null, rifle.reload.get("anchors", {}), Transform3D.IDENTITY), 30, 30, 0.0)
	var still_peak := 0.0
	for k in 400:
		still_peak = maxf(still_peak, still.bolt_back(float(k) / 400.0))
	var model := AwModelCache.instantiate(rifle.model_path) if ResourceLoader.exists(rifle.model_path) else null
	var has_bolt := model != null and model.find_child(String(rifle.bolt_node), true, false) != null and model.find_child(String(rifle.hide_during_reload), true, false) != null
	if model != null:
		model.free()
	_check("the rifle's bolt node (%s, %s) is drawn back with the charge and home at both ends (peak %.2f, start %.2f, end %.2f, uncharged %.2f)" % [rifle.bolt_node, has_bolt, peak, start_back, end_back, still_peak],
		has_bolt and rifle.bolt_travel > 0.0 and peak > 0.95 and start_back == 0.0 and end_back == 0.0 and still_peak == 0.0)
	_end()


## The hand spans of every model (IronSight.spans: bare faces and one TriangleMesh) equal the per-triangle
## ray tests (IronSight.span) they replaced, which cost 60-400 ms a weapon of GDScript at load.
func _spans() -> void:
	_begin("hand spans, fast against reference")
	var holder := Node3D.new()
	add_child(holder)
	var worst := 0.0
	var compared := 0
	var mismatched := PackedStringArray()
	var ref_usec := 0
	var fast_usec := 0
	var all := AwWeaponArt.weapon_rows("")
	for role: StringName in all:
		var scene := load(str((all[role] as Dictionary)["model"])) as PackedScene
		if scene == null:
			continue
		var model := scene.instantiate() as Node3D
		holder.add_child(model)
		var forward := Vector3(0, 0, -1)
		var fractions := [0.62, 0.30]
		var t0 := Time.get_ticks_usec()
		var tris := IronSight.triangles_of(model, holder)
		var want: Array = []
		for fraction: float in fractions:
			want.append(IronSight.span(model, holder, forward, fraction, tris))
		var t1 := Time.get_ticks_usec()
		var got := IronSight.spans(IronSight.faces_of(model, holder), forward, fractions)
		var t2 := Time.get_ticks_usec()
		ref_usec += t1 - t0
		fast_usec += t2 - t1
		for k in fractions.size():
			var a: Dictionary = want[k]
			var b: Dictionary = got[k]
			compared += 1
			if a.is_empty() != b.is_empty():
				mismatched.append("%s[%d] empty %s vs %s" % [role, k, a.is_empty(), b.is_empty()])
				continue
			for key in a:
				var d := absf(float(a[key]) - float(b[key]))
				worst = maxf(worst, d)
				if d > 0.0001:
					mismatched.append("%s[%d].%s %f vs %f" % [role, k, key, a[key], b[key]])
		holder.remove_child(model)
		model.free()
	holder.queue_free()
	print("  spans: %d compared, worst difference %.7f m, reference %d ms, fast %d ms" % [compared, worst, ref_usec / 1000, fast_usec / 1000])
	_check("hand spans: %d compared, none differs (%s)" % [compared, ", ".join(mismatched)], compared > 20 and mismatched.is_empty())
	_end()


func _sound_classes() -> void:
	_begin("sound classes")
	var plain := AwWeaponPack.sound_classes("")
	var gun_ids := 0
	for id: StringName in AwWeaponPack.IDS:
		if id in [&"knife", &"frag", &"sticky", &"flash", &"smoke", &"incendiary"]:
			continue
		gun_ids += 1
		if not plain.has(id):
			_check("%s has a sound class" % id, false)
	_check("every gun has a sound class (%d)" % gun_ids, plain.size() == gun_ids)
	_check("lmg has its own sound class, not the rifle's", plain[&"lmg"] == &"lmg")
	_check("a prefix is applied to the ids", AwWeaponPack.sound_classes("aw_").has(&"aw_quad_launcher"))
	_check("the prefixed class is the same", AwWeaponPack.sound_classes("aw_")[&"aw_quad_launcher"] == &"launcher")
	_end()


func _models() -> void:
	_begin("models")
	var all := AwWeaponArt.weapon_rows("")

	for role: StringName in all:
		var row: Dictionary = all[role]
		var path := str(row["model"])
		_check("%s: %s exists" % [role, path.get_file()], ResourceLoader.exists(path))
		var scene := load(path) as PackedScene
		_check("%s loads as a scene" % role, scene != null)

		if scene == null or row["motion"] != "gun":
			continue

		var node := scene.instantiate() as Node3D
		var box := _aabb(node, Transform3D.IDENTITY)
		var rear_top := _rear_top(node, Transform3D.IDENTITY, float(row["muzzle"]), -INF, Vector3.ZERO)
		var mark := node.find_child("sight_rear", true, false) as Node3D
		if mark != null:
			rear_top = mark.transform.origin
		node.free()
		if rear_top != Vector3.ZERO:
			var aim_in: Vector3 = (row["view"] as Dictionary).get("aim", Vector3.ZERO)
			var low := rad_to_deg(atan2(rear_top.y + aim_in.y, -(aim_in.z + rear_top.z)))
			_check("%s: the rear sight sits %.2f degrees off the crosshair, under 0.15" % [role, low], absf(low) < 0.15)
		_check("%s: the barrel end is %.3f m ahead of the grip, as the table says" % [role, row["muzzle"]], absf(-box.position.z - float(row["muzzle"])) < 0.02)
		_check("%s: a gun, not a tiny prop (%.2f m long)" % [role, box.size.z], box.size.z > 0.08 and box.size.z < 1.6)
		var aim: Vector3 = (row["view"] as Dictionary).get("aim", Vector3.ZERO)
		_check("%s: at the sights the stock ends %.2f m ahead of the eye" % [role, -(aim.z + box.end.z)], aim.z + box.end.z < -0.1)

	for prop in AwWeaponArt.PROPS:
		_check("prop %s ships" % prop, ResourceLoader.exists(AwWeaponArt.model_path(prop)))
	_end()


## groups.json: every non-core weapon's model sits in its own group and a core weapon's in none.
func _download_groups() -> void:
	_begin("download groups")
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://groups.json"))
	_check("groups.json is an object", doc is Dictionary)
	var groups: Dictionary = doc if doc is Dictionary else {}
	_check("one group per weapon but the two core ones", groups.size() == AwWeaponPack.IDS.size() - AwWeaponGroups.CORE.size())
	var uncovered: Array[String] = []
	for id: StringName in AwWeaponArt.WEAPONS:
		var g := AwWeaponGroups.group_of(id)
		var model := String(AwWeaponArt.WEAPONS[id]["model"])
		if g == "":
			continue
		var found := false
		for pattern: String in groups.get(g, []):
			if pattern.contains("assets/models/" + model + "."):
				found = true
		if not found:
			uncovered.append(String(id))
	_check("every grouped weapon's model is in its group (missing: %s)" % ", ".join(uncovered), uncovered.is_empty())
	_check("the core weapons have no group", AwWeaponGroups.group_of(&"knife") == "" and AwWeaponGroups.group_of(&"pistol") == "")
	_check("groups_for skips core and unknown ids and repeats", AwWeaponGroups.groups_for([&"knife", &"rifle", &"rifle", &"nope"]) == PackedStringArray(["weapon-rifle"]))
	_check("all_groups is every group groups.json defines", AwWeaponGroups.all_groups().size() == groups.size())
	var stray: Array[String] = []
	for name: String in AwWeaponGroups.all_groups():
		if not groups.has(name):
			stray.append(name)
	_check("every group the code names is in groups.json", stray.is_empty())
	_check("the sniper's textures are extracted, so its model is a few hundred KB, not 4.8 MB", FileAccess.file_exists("res://addons/arena_weapons/assets/models/sniper_ph_0.jpg"))
	_end()


func _provider() -> void:
	_begin("provider contract")
	var rows := AwSpawnProvider.art_rows()
	var entries := AwSpawnProvider.spawn_entries()
	_check("one art row per weapon this pack defines", rows.size() == AwWeaponPack.IDS.size() and AwWeaponArt.WEAPONS.size() == AwWeaponPack.IDS.size())
	var pistol := AwWeaponArt.row_of(&"pistol")
	_check("the pistol row keeps its own hand scale, not the tier's 0.36", is_equal_approx(float(pistol["hand_scale"]), 0.4))
	_check("the pistol row slims its forearm so it does not fill the lower right", float(pistol.get("forearm_scale", 1.0)) < 1.0)
	_check("the pistol row names a support grip", (pistol["support_grip"] as Vector3).is_finite())
	_check("the grenade launcher is drawn smaller than a long gun", float(AwWeaponArt.row_of(&"grenade_launcher")["view"]["scale"]) < 0.5)
	_check("a pistol keeps the runtime's wall defaults", AwWeaponArt.wall_row(&"pistol").is_empty())
	_check("a rifle retreats deeper from a wall than the 0.34 m default", float(AwWeaponArt.wall_row(&"rifle")["wall_max"]) > 0.34)
	_check("a launcher retreats deeper than a rifle", float(AwWeaponArt.wall_row(&"launcher")["wall_max"]) > float(AwWeaponArt.wall_row(&"rifle")["wall_max"]))
	_check("a knife shortens its wall reach", float(AwWeaponArt.wall_row(&"knife")["wall_reach"]) < 1.0)
	var rifle_def := AwWeaponPack.weapons({}, "", false).filter(func(d: DotWeaponDef) -> bool: return d.id == &"rifle")[0] as DotWeaponDef
	_check("the rifle def carries its wall row in params.ads", (rifle_def.params["ads"] as Dictionary).has("wall_max"))
	var rules := AwAdsRules.new()
	rules.set_def_row(&"rifle", rifle_def.params["ads"])
	_check("the ADS rules accept the rifle's wall row whole", float(rules.wall_for(&"rifle")["max"]) == float((rifle_def.params["ads"] as Dictionary)["wall_max"]))
	_check("every weapon id carries the pack prefix", rows.keys().all(func(k: StringName) -> bool: return String(k).begins_with("aw_")))
	_check("one spawn entry per weapon", entries.size() == rows.size())
	_check("role_art is keyed by role, not by this pack's ids", AwSpawnProvider.role_art().has(&"rifle") and not AwSpawnProvider.role_art().has(&"aw_rifle"))
	var credit := AwSpawnProvider.credits()[0]
	_check("the credit names Styloo, CC0 and the page", credit["author"] == "Styloo" and str(credit["licence"]).begins_with("CC0") and str(credit["url"]).begins_with("https://styloo.itch.io/"))
	_check("every credit is CC0 with a page", AwSpawnProvider.credits().all(func(c: Dictionary) -> bool: return str(c["licence"]).begins_with("CC0") and str(c["url"]).begins_with("https://")))
	AwSpawnProvider.set_id_prefix("")
	var plain := AwSpawnProvider.art_rows()
	_check("a host that owns the plain ids gets `rifle`, not `aw_rifle`", plain.has(&"rifle") and not plain.has(&"aw_rifle") and AwSpawnProvider.role_art().is_empty())
	AwSpawnProvider.set_id_prefix(AwSpawnProvider.DEFAULT_PREFIX)
	_end()


func _defs() -> void:
	_begin("the pack's own weapon definitions")
	var defs := AwSpawnProvider.weapon_defs()
	_check("every pack weapon has a definition", defs.size() == AwWeaponPack.IDS.size() and AwWeaponPack.errors.is_empty())
	var ids := {}
	var tiered := true
	for def in defs:
		ids[def.id] = true
		var n := 0
		for t: StringName in [&"sidearm", &"primary", &"heavy", &"melee", &"thrown"]:
			n += 1 if def.tags.has(t) else 0
		tiered = tiered and n == 1
	_check("ids are unique", ids.size() == defs.size())
	_check("each has exactly one tier tag", tiered)
	_check("the rifle is a primary with a magazine", _def(defs, &"aw_rifle").slot == AwWeaponPack.SLOT_PRIMARY and _def(defs, &"aw_rifle").magazine > 0)
	_check("the quad launcher fires the launcher's ammunition", _def(defs, &"aw_quad_launcher").ammo_type == _def(defs, &"aw_launcher").ammo_type)
	_check("default layout: the frag is on the thrown slot, the sniper on the heavy slot", _def(defs, &"aw_frag").slot == AwWeaponIds.thrown_slot() and _def(defs, &"aw_sniper").slot == AwWeaponIds.heavy_slot() and AwWeaponIds.thrown_slot() == AwWeaponIds.SLOT_THROWN)
	_check("one weapon per slot at least", [1, 2, 3, 4, 5].all(func(s: int) -> bool: return defs.any(func(d: DotWeaponDef) -> bool: return d.slot == s)))
	var rifle_modes := _def(defs, &"aw_rifle").allowed_fire_modes()
	_check("the rifle's selector offers semi, burst and auto", rifle_modes.size() == 3 and rifle_modes.has(DotWeaponDef.Fire.AUTO) and rifle_modes.has(DotWeaponDef.Fire.SEMI))
	_check("the pistol's selector has no auto it cannot fire", not _def(defs, &"aw_pistol").allowed_fire_modes().has(DotWeaponDef.Fire.AUTO))
	_check("the smg's selector offers more than one mode", _def(defs, &"aw_smg").allowed_fire_modes().size() > 1)
	_check("every selector starts on a mode its gun allows", defs.all(func(d: DotWeaponDef) -> bool: return d.allowed_fire_modes().has(d.fire_mode)))
	# As a host's registered source: it must not recurse through the host's own weapons().
	AwWeaponCatalogue.add_source(&"aw_selftest", Callable(AwSpawnProvider, &"weapon_defs"))
	var hosted := AwWeaponCatalogue.weapons()
	AwWeaponCatalogue.remove_source(&"aw_selftest")
	var found := 0
	for d in hosted:
		found += 1 if String(d.id).begins_with("aw_") else 0
	_check("registered as a catalogue source, every weapon joins the catalogue once", found == defs.size())
	_check("and the catalogue is the host's plus the pack's", hosted.size() == AwWeaponCatalogue.weapons().size() + defs.size())
	_end()


## Each gun's drawn kick (presentation only) as measured off the pose spring: one shot from rest, 120 frames a second.
## Returns [peak camera pitch, peak gun pitch, peak push-back, camera pitch left after a second].
func _kick_trace(params: Dictionary, recoil: Vector2, interval: float) -> Array[float]:
	var pose := AwWeaponPose.make()
	pose.tunables.apply_kick(params)
	pose.fire_interval = interval
	pose.punch(recoil, true)
	var out: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in range(120):
		pose.advance(1.0 / 120.0, Vector2.ZERO, 0.0, true)
		out[0] = maxf(out[0], pose.view_punch().x)
		out[1] = maxf(out[1], pose._kick_rotation.x + pose._extra_pitch)
		out[2] = maxf(out[2], pose._kick + pose._extra_back)
	out[3] = absf(pose.view_punch().x)
	return out


## The sniper's shot climbs and shoves the gun and turns the camera well past the old default; an automatic's gun climbs
## more while its camera share stays near the bullets' own climb; every kick settles; the bullets' recoil is untouched.
func _fire_feel() -> void:
	_begin("per-weapon fire feel")
	var defs := AwSpawnProvider.weapon_defs()
	var shot := func(id: StringName, own: bool) -> Array[float]:
		var d := _def(defs, id)
		var b := d.tuning as DotWeaponBallistics
		var interval := float(d.use_interval_ticks) / float(AwWeaponPack.TICK_RATE)
		return _kick_trace(d.params if own else {}, Vector2(b.recoil_pitch, b.recoil_yaw), interval)
	var sniper: Array[float] = shot.call(&"aw_sniper", true)
	var sniper_old: Array[float] = shot.call(&"aw_sniper", false)
	var rifle: Array[float] = shot.call(&"aw_rifle", true)
	var rifle_old: Array[float] = shot.call(&"aw_rifle", false)
	print("  sniper camera %.2f deg (was %.2f), gun %.2f deg (was %.2f), back %.3f m (was %.3f); rifle camera %.2f (was %.2f), gun %.2f (was %.2f)" % [
		sniper[0], sniper_old[0], sniper[1], sniper_old[1], sniper[2], sniper_old[2], rifle[0], rifle_old[0], rifle[1], rifle_old[1]])
	_check("a sniper shot turns the camera at least 4 degrees, 2.5 times the default", sniper[0] >= 4.0 and sniper[0] >= sniper_old[0] * 2.5)
	_check("a sniper shot climbs the gun at least 12 degrees and shoves it back at least 8 cm", sniper[1] >= 12.0 and sniper[2] >= 0.08)
	_check("a rifle shot climbs the gun 1.4 times the default, its camera within 0.8 to 1.3 times", rifle[1] >= rifle_old[1] * 1.4 and rifle[0] >= rifle_old[0] * 0.8 and rifle[0] <= rifle_old[0] * 1.3)
	_check("every kick has settled a second later", sniper[3] < 0.05 and rifle[3] < 0.05)
	var sim_kept := (_def(defs, &"aw_sniper").tuning as DotWeaponBallistics).recoil_pitch == (AwWeaponPack.sniper().tuning as DotWeaponBallistics).recoil_pitch \
		and not _def(defs, &"aw_sniper").params.has(&"recoil_pitch")
	_check("the feel lives in params only: the bullets' recoil is the ballistics' own", sim_kept and (AwWeaponPack.sniper().tuning as DotWeaponBallistics).recoil_pitch == 4.0)
	_end()


## Every class but the beam (a flashless stream) has a flash, dressed guns throw cases (a held one too), and each gun but the launchers and energy guns has its own report.
func _fire_fx() -> void:
	_begin("muzzle flash, cases and per-gun reports")
	var no_flash: Array[String] = []
	for gun: StringName in AwWeaponPack.SOUND_CLASSES:
		if gun != &"beamer" and not AwShotFx.FLASH.has(AwWeaponPack.SOUND_CLASSES[gun]):
			no_flash.append(String(gun))
	_check("every gun's class has a flash row: %s" % ", ".join(no_flash), no_flash.is_empty())
	var rows := AwWeaponArt.weapon_rows("")
	var eject_bad: Array[String] = []
	for gun: StringName in AwWeaponPack.SOUND_CLASSES:
		var art := AwWeaponVisual.make(gun)
		AwArtDress.apply(art, rows[gun])
		if art.ejects != bool((rows[gun] as Dictionary).get("ejects", true)):
			eject_bad.append(String(gun))
	_check("dressing keeps each row's ejects (default on): %s" % ", ".join(eject_bad),
		eject_bad.is_empty() and rows[&"revolver"].get("ejects", true) == false)
	var silent: Array[String] = []
	var own := 0
	for gun: StringName in AwWeaponPack.SOUND_CLASSES:
		if AwShotLayers.has_gun_sound(gun):
			own += 1
		elif not gun in [&"launcher", &"quad_launcher", &"grenade_launcher", &"beamer", &"charge_rifle"]:
			silent.append(String(gun))
	_check("every gun but the launchers and energy guns has its own report: %s" % ", ".join(silent), silent.is_empty() and own > 0)
	_check("a host's prefix still finds the gun", AwShotLayers.gun_of(&"fc_burst_rifle") == &"burst_rifle"
		and AwShotLayers.gun_of(&"fc_rifle") == &"rifle" and AwShotLayers.gun_of(&"axe") == &"")
	var registered := own
	if AwShotLayers.available():
		var layers := AwShotLayers.new()
		add_child(layers)
		registered = 0
		if layers.setup(&"Master"):
			for gun: StringName in AwWeaponPack.SOUND_CLASSES:
				registered += 1 if layers.plays_gun(gun) else 0
		layers.free()
	_check("the layered player registers each gun's own shot (%d of %d)" % [registered, own], registered == own)
	var host_def := AwShotLayers.gun_shot(&"sniper")
	_check("a host's own shot player gets a gun's report under its id (aw_gun_sniper, attack layers)",
		AwShotLayers.gun_shot_id(&"fc_sniper") == &"aw_gun_sniper" and AwShotLayers.gun_shot_id(&"axe") == &""
		and AwShotLayers.gun_shot(&"axe") == null and (not AwShotLayers.available()
		or (host_def != null and host_def.get(&"id") == &"aw_gun_sniper" and not (host_def.get(&"attack") as PackedStringArray).is_empty())))
	var shells := []
	for gun: StringName in [&"sniper", &"revolver"]:
		var held := AwWorldModel.new()
		held.sounds = false
		held.effects = true
		add_child(held)
		var art := AwWeaponVisual.make(gun)
		AwArtDress.apply(art, rows[gun])
		held.equip(art)
		await get_tree().process_frame
		held.on_fired(Vector2(0.5, 0.1), AwWeaponNet.KIND_SHOT, true)
		shells.append(held._shot_fx().shell_count())
		held.free()
	_check("a held gun seen firing throws a case, a revolver none (%s)" % str(shells), shells == [1, 0])
	_end()


func _dress() -> void:
	_begin("dressing a base art by role")
	AwWeaponArtTable.drop_cache()
	var before := AwWeaponArtTable.rifle()
	var rows := AwSpawnProvider.role_art()
	var art := AwWeaponVisual.make(&"rifle")
	AwArtDress.apply(art, rows[&"rifle"])
	_check("the model is this pack's", art.model_path == AwWeaponArt.model_path("rifle"))
	_check("the muzzle is the table's", is_equal_approx(art.muzzle_distance, 0.573))
	_check("the base art itself is untouched until a game applies it", before.model_path != art.model_path)
	_check("a grenade dressed keeps the throw carry", _thrown())
	_check("every gun row names its own reload style: %s" % ", ".join(_unstyled()), _unstyled().is_empty())
	var belt_bad := _style_mismatch("belt", "belt_feed", true)
	_check("every belt-reload gun draws a moving belt (belt_feed): %s" % ", ".join(belt_bad), belt_bad.is_empty())
	var feed_bad := _style_mismatch("belt", "belt_feed", false)
	_check("and nothing else is marked belt_feed: %s" % ", ".join(feed_bad), feed_bad.is_empty())
	var rev_bad: Array[String] = []
	var all_rows := AwWeaponArt.weapon_rows("")
	for role: StringName in all_rows:
		var reload: Dictionary = (all_rows[role] as Dictionary).get("reload", {})
		if str(reload.get("style", "")) == "revolver" and all_rows[role].get("tier", "") != "sidearm":
			rev_bad.append(String(role))
	_check("revolver-style reloads are sidearms: %s" % ", ".join(rev_bad), rev_bad.is_empty())
	_end()


## Roles breaking "reload style [param style] iff [param key] is set"; [param want] picks the direction checked.
func _style_mismatch(style: String, key: String, want: bool) -> Array[String]:
	var out: Array[String] = []
	var rows := AwWeaponArt.weapon_rows("")
	for role: StringName in rows:
		var row: Dictionary = rows[role]
		var is_style := str((row.get("reload", {}) as Dictionary).get("style", "")) == style
		var has_key := bool(row.get(key, false))
		if (want and is_style and not has_key) or (not want and has_key and not is_style):
			out.append(String(role))
	return out


## Gun rows whose `reload` names no known style (the view model would play the generic reload).
func _unstyled() -> Array[String]:
	var out: Array[String] = []
	var rows := AwWeaponArt.weapon_rows("")
	for role: StringName in rows:
		var row: Dictionary = rows[role]
		var style := str((row.get("reload", {}) as Dictionary).get("style", ""))
		if row["motion"] == "gun" and not style in ["magazine", "pistol", "revolver", "tube", "bolt", "belt", "launcher", "cell"]:
			out.append(String(role))
	return out


func _scope_hides_gun() -> void:
	_begin("scoped gun model hidden once the scope picture is up")
	var view := AwViewModel.new()
	view.scope_mode = AwViewModel.SCOPE_FULL
	view.show_arms = false
	add_child(view)
	var row: Dictionary = AwWeaponArt.weapon_rows("")[&"sniper"]
	var art := AwWeaponVisual.make(&"sniper")
	AwArtDress.apply(art, row)
	view.equip(art)
	view._process(0.02)
	_check("hip: gun drawn, no scope picture", view._animated.visible and not view.scope_picture_up())
	view.aim(true)
	var hid_early := false
	var shown_late := false
	for _i in 80:
		view._process(0.02)
		var up := view.scope_picture_up()
		if up and view._animated.visible:
			hid_early = true
		if not up and not view._animated.visible and not view.is_scoped():
			shown_late = true
	_check("gun never drawn while the scope picture is half up", not hid_early)
	_check("gun not hidden before the picture is half up", not shown_late)
	view.queue_free()
	_end()


func _scope_modes() -> void:
	_begin("scope views: lens on screen, full screen, server pin, see-through on the move")
	var view := AwViewModel.new()
	view.show_arms = false
	add_child(view)
	var art := AwWeaponVisual.make(&"sniper")
	AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[&"sniper"])
	view.equip(art)
	_check("the scope lens is the default view", view.scope_mode == AwViewModel.SCOPE_LENS)
	view.aim(true)
	for _i in 80:
		view.drive(Vector2.ZERO, 0.0, true)
		view._process(0.02)
	_check("lens: the camera keeps the hip field of view", is_equal_approx(view.view_fov_scale(), 1.0))
	_check("lens: the scope still zooms", view.aim_fov_scale() < 0.9)
	_check("lens: the gun is hidden so it does not cover the glass", not view._animated.visible)
	_check("standing, the picture is solid", view.scope_clear() < 0.01)
	view.drive(Vector2.ZERO, 6.0, true)
	view._process(0.02)
	_check("running, the picture goes part clear", view.scope_clear() > 0.4 and view.scope_clear() < 1.0)
	view.scope_walk_clear = 0.0
	_check("a clear of 0 keeps it solid at a run", view.scope_clear() == 0.0)
	view.scope_mode = AwViewModel.SCOPE_FULL
	view._process(0.02)
	_check("full: the camera takes the whole zoom", is_equal_approx(view.view_fov_scale(), view.aim_fov_scale()))
	_check("full: the gun is hidden behind the scope", not view._animated.visible)

	var rules := AwAdsRules.new()
	_check("no server rule: the client chooses 2", rules.resolve_scope_mode(&"sniper", 2) == 2)
	_check("no server rule: the client chooses 1", rules.resolve_scope_mode(&"sniper", 1) == 1)
	_check("a wild client value is clamped", rules.resolve_scope_mode(&"sniper", 9) == 2)
	var _ok := rules.set_value(&"", "scope_mode", 2)
	_check("server pins the full-screen scope", rules.resolve_scope_mode(&"sniper", 1) == 2)
	var client := AwAdsRules.new()
	_check("the pin travels on the wire", client.adopt_wire(rules.to_wire()) and client.resolve_scope_mode(&"sniper", 1) == 2)
	view.ads_rules = rules
	_check("the view model applies the server's pin", view.resolve_scope_mode(1) == 2)

	var overlay := AwScopeOverlay.new()
	add_child(overlay)
	overlay.fraction = 1.0
	_check("the overlay is headless-safe in lens mode", not overlay.lens_active() and overlay.mode == 1)
	overlay.follow(view)
	_check("the overlay takes mode and clear from the view", overlay.mode == AwViewModel.SCOPE_FULL and overlay.clear == 0.0)
	_check("the sniper row brings its own lens size", is_equal_approx(overlay.lens_circle, float(art.scope_style.get("lens_circle", -1.0))))
	var share := 0.62
	var lens_fov := 75.0 * AwScopeOverlay.lens_fov_share(75.0, 0.3, share)
	_check("the lens magnifies by the zoom over the hip view", absf(tan(deg_to_rad(lens_fov) * 0.5) / (tan(deg_to_rad(37.5)) * share) - 0.3) < 0.001)
	var camera := Camera3D.new()
	camera.fov = 75.0
	add_child(camera)
	overlay.bind_camera(camera)
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.size = Vector2(1920.0, 1080.0)
	overlay.follow(view)
	_check("a bound lens narrows past the camera's zoom", overlay.lens_zoom < view.aim_fov_scale() * 0.75)
	var plain := AwWeaponVisual.make(&"rifle")
	AwArtDress.apply(plain, AwWeaponArt.weapon_rows("")[&"rifle"])
	view.equip(plain)
	overlay.follow(view)
	_check("the next gun does not keep the last gun's lens", is_equal_approx(overlay.lens_circle, 0.46))
	camera.queue_free()
	overlay.queue_free()
	view.queue_free()
	_end()


func _own_sights() -> void:
	_begin("aimed down each model's own sight")
	var view := AwViewModel.new()
	view.show_arms = false
	add_child(view)
	var own := 0
	var built: Array[StringName] = []
	var blocked: Array[StringName] = []
	var worst := 0.0
	var sighted: AwWeaponVisual = null
	var means_before := AwViewArms._means.size()
	var rows := AwWeaponArt.weapon_rows("")
	for role: StringName in rows:
		var row: Dictionary = rows[role]
		if row["motion"] != "gun" or (row["view"] as Dictionary).get("scoped", false):
			continue
		var art := AwWeaponVisual.make(role)
		AwArtDress.apply(art, row)
		view.equip(art)
		view.aim(true)
		for _i in 40:
			view._process(0.02)
		if view.find_child("Sight", true, false) != null and not (row["view"] as Dictionary).get("iron", false):
			built.append(role)
		_aim_clear(view, role, blocked)
		var points := view.sight_points()
		if points.is_empty():
			continue
		own += 1
		sighted = art
		for p: Vector3 in [points.rear, points.front]:
			worst = maxf(worst, Vector2(p.x, p.y).length())
	_check("an armless view still leaves the guns' texture means cached for the first armed equip",
		AwViewArms._means.size() > means_before)
	_check_sight_cache(view, sighted)
	view.queue_free()
	_check("no gun has a sight built over its own (%s)" % str(built), built.is_empty())
	_check("%d guns aim down a notch, aperture or post of their own" % own, own >= OWN_SIGHTED)
	_check("each own sight line runs through the screen's centre (worst %.4f m)" % worst, worst < 0.002)
	_check("no gun has any of its model inside the see-through cone round the aim line (%s)" % str(blocked), blocked.is_empty())
	_check_stepped_prewarm()
	_end()


## A gun's sight line measured once is reused: the cached fit puts the sight where a fresh measurement does.
func _check_sight_cache(view: AwViewModel, art: AwWeaponVisual) -> void:
	if art == null:
		_check("a gun with its own sight to fit from the cache", false)
		return
	view.equip(art)
	var cached := str(view.sight_points())
	AwViewModel.SightFit.line_cache = false
	view.equip(art)
	var measured := str(view.sight_points())
	AwViewModel.SightFit.line_cache = true
	_check("a gun's sight line from the cache matches a fresh measurement",
		not AwViewModel.SightFit._lines.is_empty() and cached == measured)


## A weapon prewarmed a stage at a time ends dropped again, in as many calls as it has stages.
func _check_stepped_prewarm() -> void:
	var view := AwViewModel.new()
	view.show_arms = false
	add_child(view)
	var rows := AwWeaponArt.weapon_rows("")
	var role: StringName = &""
	for r: StringName in rows:
		if rows[r]["motion"] == "gun":
			role = r
			break
	var art := AwWeaponVisual.make(role)
	AwArtDress.apply(art, rows[role])
	var spans: Dictionary = AwViewModel.HandReach._span_cache
	for key: String in spans.keys():
		if key.begins_with("%s|" % art.id):
			spans.erase(key)
	var before := spans.size()
	var ready := [0]
	view.model_ready.connect(func(_id: StringName, _node: Node3D) -> void: ready[0] += 1)
	var steps := 0
	var parts_cold := not AwViewModel._parts_warmed
	var part_steps := AwViewModel.WARM_KINDS.size() + AwViewModel.ReloadParts.part_names().size() if parts_cold else 0
	var began := view.prewarm_begin(art)
	var weapon_loaded := view.weapon_node() != null
	while began and view.prewarm_step():
		steps += 1
	view.queue_free()
	_check("stepped prewarm loads the model, then runs %d stages and drops the weapon" % AwViewModel.EQUIP_STAGES, began and weapon_loaded and steps == AwViewModel.EQUIP_STAGES - 1 + part_steps and view.weapon_node() == null)
	_check("stepped prewarm leaves every reload part warmed (one a step when cold: %d)" % part_steps, AwViewModel._parts_warmed and view._parts_left.is_empty() and view._kinds_held.is_empty())
	var warmed := spans.size()
	var hot := AwViewModel.new()
	hot.show_arms = false
	add_child(hot)
	var _r := hot.equip(art)
	hot.queue_free()
	_check("stepped prewarm warms what equip reads, as prewarm does (model_ready %d, hand spans %d -> %d, equip adds %d)" % [ready[0], before, warmed, spans.size() - warmed], ready[0] == 1 and warmed > before and spans.size() == warmed)


## Rays from the aimed eye inside the sight cone, as far as the front post, hit nothing of the gun.
func _aim_clear(view: AwViewModel, role: StringName, blocked: Array[StringName]) -> void:
	var roots: Array = [view._weapon]
	var cone: Dictionary = AwViewModel.SightFit.cone_for(view._art, view.ads_rules, roots, view._holder, view._aim_target(), view._sight_line)
	if cone.is_empty() or AwViewModel.SightFit.Cut.occluders(view._weapon, view._holder, cone) > 0:
		blocked.append(role)


## Looking steeply down at a flat floor, no part of the drawn gun may be seen going through it: its lowest vertex stays above the floor plane, or the wall-free pass that draws it over the world is on.
## The lens draws the gun larger and farther from the eye than the wall probe assumes, so a barrel can be through a floor the probe never reaches.
func _floor_clip() -> void:
	_begin("the gun at the floor when looking down")
	var eye_height := 1.6
	var camera := Camera3D.new()
	camera.fov = 100.0
	add_child(camera)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 0.4, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -eye_height - 0.2, 0.0)
	add_child(floor_body)
	var view := AwViewModel.new()
	view.show_arms = false
	# The player's lens: a narrower field of view for the hands than for the world makes the gun larger and flatter.
	view.hands_fov = 55.0
	camera.add_child(view)
	var art := AwWeaponVisual.make(&"rifle")
	AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[&"rifle"])
	view.equip(art)
	for _i in 3:
		await get_tree().physics_frame
	var floor_y := -eye_height
	for pitch: float in [0.0, -45.0, -70.0, -89.0]:
		camera.rotation_degrees = Vector3(pitch, 0.0, 0.0)
		for _i in 60:
			await get_tree().physics_frame
			view.advance(0.02)
		var lowest := INF
		for mesh in AwViewModel.HandReach.meshes(view._animated):
			if mesh.mesh == null or not mesh.is_visible_in_tree():
				continue
			for surface in mesh.mesh.get_surface_count():
				var vertices: Variant = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				if vertices == null:
					continue
				for v: Vector3 in vertices:
					lowest = minf(lowest, (mesh.global_transform * v).y)
		var covered: bool = view._overlay != null and view._overlay.is_active()
		if pitch < -40.0:
			_check("pitch %d: the gun's lowest vertex is %.2f m from the floor plane, or the wall-free pass draws it (pass %s)" % [pitch, lowest - floor_y, covered], lowest >= floor_y or covered)
		else:
			_check("pitch %d: looking level the gun is not pulled back or tipped (wall %.3f)" % [pitch, view.wall_amount()], view.wall_amount() < 0.05)
	var space := view.get_world_3d().direct_space_state
	_check("the sphere before the drawn-gun rays misses a floor out of reach", not view._world_near(space, camera.global_position, eye_height * 0.5))
	_check("and finds it within reach", view._world_near(space, camera.global_position, eye_height + 0.1))
	view.queue_free()
	camera.queue_free()
	floor_body.queue_free()
	_end()


## A wall shoved against the muzzle retracts the gun toward the eye; no drawn mesh may then be cut by the camera near plane inside the view
## (that slices it open into flat faces), at the narrow and the wide field of view alike, and the clamp must not push the gun past its free pose.
func _near_plane_clip() -> void:
	_begin("the gun at the near plane against a wall")
	for fov: float in [75.0, 120.0]:
		var camera := Camera3D.new()
		camera.fov = fov
		add_child(camera)
		var view := AwViewModel.new()
		view.show_arms = false
		view.hands_fov = 55.0
		camera.add_child(view)
		var art := AwWeaponVisual.make(&"rifle")
		AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[&"rifle"])
		view.equip(art)
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(20.0, 20.0, 0.4)
		shape.shape = box
		wall.add_child(shape)
		add_child(wall)
		var worst := 0.0
		var clear := camera.near + AwViewModel.NEAR_CLEAR
		for gap: float in [1.2, 0.8, 0.5, 0.35, 0.25, 0.15]:
			wall.position = Vector3(0.0, 0.0, -gap - 0.2)
			for _i in 40:
				await get_tree().physics_frame
				view.advance(0.02)
			worst = maxf(worst, view.weapon_cut_depth(camera, clear))
		_check("fov %d: the near plane cuts no part of the gun inside the view (worst %.3f m)" % [fov, worst], worst < 0.001)
		wall.position = Vector3(0.0, 0.0, -50.0)
		for _i in 80:
			await get_tree().physics_frame
			view.advance(0.02)
		_check("fov %d: free of the wall the gun is not pulled back (wall %.3f)" % [fov, view.wall_amount()], view.wall_amount() < 0.05)
		wall.queue_free()
		view.queue_free()
		camera.queue_free()
	var probe := AwViewModel.new()
	var rect := PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	var inside: Array[Vector3] = []
	var outside: Array[Vector3] = []
	for i in 8:
		inside.append(Vector3(0.5 if i & 4 else -0.5, 0.5 if i & 2 else -0.5, -0.1 if i & 1 else -1.0))
		outside.append(Vector3(5.5 if i & 4 else 4.5, 0.5 if i & 2 else -0.5, -0.1 if i & 1 else -1.0))
	_check("a box cutting the near plane inside the view counts", probe._section_meets(inside, 0.5, rect))
	_check("a box cutting the near plane outside the view does not", not probe._section_meets(outside, 0.5, rect))
	probe.free()
	_end()


## However the gun is equipped, swapped or reloaded, a view model owns exactly one set of arms (a second set drawn
## beside the first was reported on charge_rifle's reload; render_reload counts the drawn sets on the real client).
func _one_arm_set() -> void:
	_begin("a view model holds exactly one arm set")
	var camera := Camera3D.new()
	add_child(camera)
	var view := AwViewModel.new()
	camera.add_child(view)
	var bad: Array[String] = []
	for id: StringName in [&"charge_rifle", &"lmg", &"rifle", &"charge_rifle"]:
		var art := AwWeaponVisual.make(id)
		AwArtDress.apply(art, AwWeaponArt.weapon_rows("")[id])
		view.equip(art)
		var sets := view.find_children("*", "AwViewArms", true, false).size()
		if sets != 1:
			bad.append("%s after equip: %d" % [id, sets])
		for f in 12:
			view.on_reload((f + 0.5) / 12.0)
			await get_tree().physics_frame
			view.advance(0.02)
			sets = view.find_children("*", "AwViewArms", true, false).size()
			if sets != 1:
				bad.append("%s reload %d/12: %d" % [id, f, sets])
		view.on_reload(0.0)
	_check("one AwViewArms through equip, swaps and a reload sweep: %s" % ", ".join(bad), bad.is_empty())
	view.queue_free()
	camera.queue_free()
	_end()


## 32 shooters (bots) each fire; counts the nodes the effects cost and the time per shot.
## The "BENCH" lines are the before/after record in the commit message.
func _shot_fx_pool() -> void:
	_begin("shot fx pool: 32 shooters, 100 shots")
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 0.4, 400.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -1.8, 0.0)
	add_child(floor_body)
	await get_tree().process_frame
	var base := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var holder := Node3D.new()
	add_child(holder)
	var fxs: Array[AwShotFx] = []
	for i in 32:
		var fx := AwShotFx.new()
		fx.name = "ShotFx%d" % i
		holder.add_child(fx)
		fxs.append(fx)
	for _i in 3:
		await get_tree().process_frame
	var built := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - base
	var peak := built
	var spent := 0
	var voices_max := 0
	var lights_max := 0
	for s in 100:
		var i := s % 32
		var angle := float(i) / 32.0 * TAU
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * (4.0 + float(i) * 2.0)
		var muzzle := Transform3D(Basis.looking_at(Vector3(0.0, -0.5, -1.0)), spot)
		var t0 := Time.get_ticks_usec()
		fxs[i].play_remote(AwWeaponNet.KIND_SHOT, muzzle, Vector3(0.0, -0.5, -1.0), &"rifle")
		spent += Time.get_ticks_usec() - t0
		if s % 4 == 3:
			await get_tree().process_frame
			peak = maxi(peak, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - base)
	var in_flight := 0
	for fx in fxs:
		voices_max = maxi(voices_max, int(fx.describe()["voices"]))
		lights_max = maxi(lights_max, fx.lights_built())
		in_flight += fx.live_count()
	for _i in 90:
		await get_tree().process_frame
	var after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - base
	print("BENCH shotfx: 32 shooters build %d nodes; 100 shots peak %d, settled %d; %.4f ms/shot; max voices/shooter %d, max lights/shooter %d; effects alive after the burst %d" % [
		built, peak, after, float(spent) / 100.0 / 1000.0, voices_max, lights_max, in_flight])
	_check("a burst of 100 shots from 32 shooters leaves the effects settling back", after <= peak)
	_check("every shooter keeps its effects bounded", in_flight <= 32 * AwShotFx.MAX_LIVE)
	for fx in fxs:
		fx.advance(5.0)
	var warm := 0
	for s in 100:
		var spot := Vector3(float(s % 32) + 4.0, 0.0, -6.0)
		var t1 := Time.get_ticks_usec()
		fxs[s % 32].play_remote(AwWeaponNet.KIND_SHOT, Transform3D(Basis.looking_at(Vector3(0.0, -0.5, -1.0)), spot), Vector3(0.0, -0.5, -1.0), &"rifle")
		warm += Time.get_ticks_usec() - t1
	print("BENCH shotfx: warm second burst %.4f ms/shot" % (float(warm) / 100.0 / 1000.0))
	for fx in fxs:
		fx.advance(5.0)

	_shot_fx_limits(holder)
	holder.queue_free()
	camera.queue_free()
	floor_body.queue_free()
	_end()


## The cvar limits half of [method _shot_fx_pool]: what a far, a mid-range and the local gun draw, under [param holder].
func _shot_fx_limits(holder: Node3D) -> void:
	# A far shooter draws nothing, a mid-range one draws no light, the local gun is never limited.
	var rules := AwShotFx.rules
	var lone := AwShotFx.new()
	lone.binbun_flash = false
	holder.add_child(lone)
	var near_at := Transform3D(Basis.looking_at(Vector3(0.0, -0.5, -1.0)), Vector3(0.0, 0.0, -10.0))
	var mid_at := Transform3D(near_at.basis, Vector3(0.0, 0.0, -60.0))
	var far_at := Transform3D(near_at.basis, Vector3(0.0, 0.0, -300.0))
	var aim := Vector3(0.0, -0.5, -1.0)
	DotFxLightBudget.reset()
	lone.play_remote(AwWeaponNet.KIND_SHOT, far_at, aim, &"rifle")
	_check("a shot farther than cl_shotfx_fx_distance draws nothing", lone.live_count() == 0 and rules.fx_distance < 300.0)
	lone.play_remote(AwWeaponNet.KIND_SHOT, mid_at, aim, &"rifle")
	_check("a shot beyond cl_shotfx_light_distance still draws but carries no light", lone.live_count() > 0 and lone._lights_live() == 0)
	lone.advance(5.0)
	DotFxLightBudget.reset()
	lone.play_remote(AwWeaponNet.KIND_SHOT, near_at, aim, &"rifle")
	_check("a near shot carries one light, and never more than cl_shotfx_remote_lights", lone._lights_live() == 1)
	lone.advance(5.0)
	var mine := AwShotFx.new()
	mine.first_person = true
	mine.binbun_flash = false
	holder.add_child(mine)
	DotFxLightBudget.reset()
	mine.play_remote(AwWeaponNet.KIND_SHOT, mid_at, aim, &"rifle")
	_check("the local gun keeps its light at the same distance", mine.live_count() > 0 and mine._lights_live() == 1)
	for _i in 12:
		lone.play_remote(AwWeaponNet.KIND_SHOT, near_at, aim, &"rifle")
		mine.play_remote(AwWeaponNet.KIND_SHOT, near_at, aim, &"rifle")
	_check("another shooter holds at most cl_shotfx_remote_voices voices", int(lone.describe()["voices"]) <= rules.remote_voices)
	_check("another shooter keeps at most cl_shotfx_remote_live effects", lone.live_count() <= rules.remote_live)
	_check("the local gun holds more than that (%d voices, %d effects)" % [int(mine.describe()["voices"]), mine.live_count()], mine.live_count() > rules.remote_live)
	var deaf := AwShotFx.new()
	holder.add_child(deaf)
	deaf.play_remote(AwWeaponNet.KIND_SHOT, far_at, aim, &"rifle")
	_check("a report beyond cl_shotfx_voice_distance makes no voice", int(deaf.describe()["voices"]) == 0)
	_shot_fx_sky(holder)
	_shot_fx_rounds(holder)


## A shot on the sky draws nothing where it lands, a shot on a wall a mark: sky by group or by hull_kind meta.
func _shot_fx_sky(holder: Node3D) -> void:
	var wall := StaticBody3D.new()
	var tagged := StaticBody3D.new()
	tagged.set_meta(&"hull_kind", "sky")
	var grouped := StaticBody3D.new()
	grouped.add_to_group(AwShotFx.NO_IMPACT_GROUP)
	for body in [wall, tagged, grouped]:
		holder.add_child(body)
	_check("the sky (meta or group) draws no impact, a wall and a ray with no collider do",
		not AwShotFx.draws_impact(tagged) and not AwShotFx.draws_impact(grouped)
		and AwShotFx.draws_impact(wall) and AwShotFx.draws_impact(null))
	var fx := AwShotFx.new()
	holder.add_child(fx)
	var at := Vector3(0.0, 0.0, -10.0)
	fx.play_impact(at, Vector3.BACK, tagged)
	fx.play_impact(at, Vector3.BACK, grouped)
	_check("a shot landing on the sky leaves no mark and no effect (%d, %d)" % [fx.mark_count(), fx.live_count()],
		fx.mark_count() == 0 and fx.live_count() == 0)
	fx.play_impact(at, Vector3.BACK, wall)
	_check("the same shot on a wall leaves a mark and an effect (%d, %d)" % [fx.mark_count(), fx.live_count()],
		fx.mark_count() == 1 and fx.live_count() > 0)
	fx.advance(5.0)


## Each gun's round has its own tracer and impact, its impact sounds like what it hit, and handling carries less far than a report.
func _shot_fx_rounds(holder: Node3D) -> void:
	var pistol := float(AwShotFx.round_profile(AwWeaponSound.LIGHT)["width"])
	var sniper := float(AwShotFx.round_profile(AwWeaponSound.SNIPER)["width"])
	var pellet := float(AwShotFx.round_profile(AwWeaponSound.SHOTGUN)["width"])
	_check("a sniper's tracer is wider than a pistol's, a pellet's the thinnest, an unknown class the rifle's",
		sniper > pistol and pellet < pistol
		and AwShotFx.round_profile(&"nonsense") == AwShotFx.round_profile(AwWeaponSound.RIFLE))
	var fx := AwShotFx.new()
	fx.first_person = true
	holder.add_child(fx)
	fx.play_remote(AwWeaponNet.KIND_SHOT, Transform3D(Basis(), Vector3(0.0, 0.0, 40.0)), Vector3.FORWARD, &"sniper")
	var widths: Array[float] = []
	for live: Dictionary in fx._live:
		if live.get("kind", &"") == &"tracer":
			widths.append(float(live["width"]))
	_check("a sniper shot's tracer is drawn at the sniper's width (%s)" % [widths], widths.size() == 1 and is_equal_approx(widths[0], sniper))
	var metal := StaticBody3D.new()
	metal.set_meta(&"surface", "steel")
	holder.add_child(metal)
	var linked := DotWeaponSound.count(&"impact_metal") > 0 and DotWeaponSound.count(&"impact_flesh") > 0
	var on_metal := AwShotFx.impact_stream(AwShotFx.IMPACT_WORLD, metal)
	var on_body := AwShotFx.impact_stream(AwShotFx.IMPACT_BODY)
	_check("a shot on steel sounds of metal and one on a body of flesh, with dot-audio linked",
		not linked or (on_metal.resource_path.contains("impact_metal") and on_body.resource_path.contains("impact_flesh")))
	var reloader := AwShotFx.new()
	var shooter := AwShotFx.new()
	for one: AwShotFx in [reloader, shooter]:
		one.first_person = true
		one.layered_shots = false
		holder.add_child(one)
	reloader.play_reload(AwWeaponSound.RELOAD_OUT, Vector3.ZERO, &"rifle")
	shooter.play_remote(AwWeaponNet.KIND_SHOT, Transform3D(), Vector3.FORWARD, &"rifle")
	var handling_size := -1.0
	var report_size := -1.0
	for voice in reloader._voices:
		if voice.stream != null:
			handling_size = voice.unit_size
	for voice in shooter._voices:
		if voice.stream != null:
			report_size = voice.unit_size
	_check("a reload carries less far than a report (unit size %.1f vs %.1f)" % [handling_size, report_size],
		handling_size > 0.0 and handling_size < report_size)
	fx.advance(5.0)



## The highest vertex in the rear half of the gun's length, as tools/measure_sights.py finds the rear sight.
func _rear_top(n: Node, parent: Transform3D, muzzle: float, best_y: float, best: Vector3) -> Vector3:
	var t := parent * (n as Node3D).transform if n is Node3D else parent
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		for surf in mesh.get_surface_count():
			for v: Vector3 in mesh.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX]:
				var w := t * v
				if w.z > -muzzle * 0.5 and w.y > best_y:
					best_y = w.y
					best = w
	for c in n.get_children():
		best = _rear_top(c, t, muzzle, best.y if best != Vector3.ZERO else -INF, best)
	return best


func _aabb(n: Node, parent: Transform3D) -> AABB:
	var t := parent
	var out := AABB()
	var first := true
	if n is Node3D:
		t = parent * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = t * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size == Vector3.ZERO and b.position == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out


## The menu pictures: warm() draws them a frame each through one viewport (a viewport apiece headless, which has no pixels to read back), and a
## cached id costs nothing after. Pressing B used to make 27 MSAA viewports at once.
func _previews() -> void:
	_begin("weapon previews, warmed through one viewport")
	# Six of the pack's own models, registered as art the way a game does.
	var ids: Array = []
	var arts: Array[AwWeaponVisual] = []
	var rows := AwWeaponArt.weapon_rows("")
	for role: StringName in rows:
		if ids.size() < 6 and load(str((rows[role] as Dictionary)["model"])) is PackedScene:
			var art := AwWeaponVisual.new()
			art.id = StringName("preview_" + str(role))
			art.model_path = str((rows[role] as Dictionary)["model"])
			arts.append(art)
			ids.append(art.id)
	AwWeaponArtTable.add_source(&"aw_selftest_previews", func() -> Array[AwWeaponVisual]: return arts)
	var previews := AwWeaponPreview.new()
	add_child(previews)
	var done := [0]
	var _c := previews.warmed.connect(func() -> void: done[0] += 1)
	previews.warm(ids)
	_check("the warm-up is spread over frames, not done in the call (%d ids)" % ids.size(), previews.is_warming() and previews.cached_count() == 0)
	var frames := 0
	while done[0] == 0 and frames < 600:
		await get_tree().process_frame
		frames += 1
	var headless := DisplayServer.get_name() == "headless"
	_check("every id has a picture after %d frames" % frames, previews.cached_count() == ids.size() and not previews.is_warming())
	var drawn := true
	for id: Variant in ids:
		drawn = drawn and previews.texture(StringName(id)) != null
	_check("and each is a texture", drawn)
	_check("one viewport for all of them on a display, one each headless (%d made)" % previews.ports_made(), previews.ports_made() == (ids.size() if headless else 1))
	var made := previews.ports_made()
	previews.warm(ids)
	_check("warming the same ids again does nothing", done[0] == 2 and previews.ports_made() == made and not previews.is_warming())
	await get_tree().process_frame
	var again := 0
	for child in previews.get_children():
		again += 1 if child is SubViewport else 0
	_check("the shared viewport is gone once done (%d left)" % again, again == (ids.size() if headless else 0))
	previews.queue_free()
	AwWeaponArtTable.remove_source(&"aw_selftest_previews")
	_end()


## The glove fit reads each gun texture back once: a second fit of the same art gives the same
## colours from the cache, and turning the cache off still reads them.
func _glove_cache() -> void:
	_begin("glove contrast texture cache")
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.6, 1.0))
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	var was := AwViewArms.albedo_cache
	AwViewArms.albedo_cache = true
	var first := AwViewArms.surface_albedos(mi)
	img.fill(Color(1, 1, 1, 1))
	tex.set_image(img)
	var again := AwViewArms.surface_albedos(mi)
	_check("a second fit of the same texture comes from the cache",
		first.size() == 1 and again.size() == 1 and first[0].is_equal_approx(again[0]) and absf(first[0].g - 0.4) < 0.02)
	AwViewArms.albedo_cache = false
	var img2 := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img2.fill(Color(0.8, 0.4, 0.2, 1.0))
	var tex2 := ImageTexture.create_from_image(img2)
	mat.albedo_texture = tex2
	var fresh := AwViewArms.surface_albedos(mi)
	_check("with the cache off the texture is read and not remembered",
		fresh.size() == 1 and absf(fresh[0].r - 0.8) < 0.02 and not AwViewArms._means.has(tex2.get_instance_id()))
	AwViewArms.albedo_cache = was
	mi.free()
	_end()


## The rig tells a host whether a tick would take the idle path.
func _would_idle() -> void:
	_begin("rig would_idle")
	var rig := AwWeaponRig.new()
	var cmd := DotWeaponCommand.new()
	_check("a rig not set up never idles", not rig.would_idle(cmd))
	rig.free()
	var r2 := AwWeaponRig.new()
	var cat := DotWeaponCatalogue.new()
	for def in AwWeaponPack.weapons(AwWeaponDamage.table(), ""):
		cat.add(def)
	r2.catalogue = cat
	add_child(r2)
	var ok := r2.setup().ok
	_check("the rig sets up", ok)
	var idles := false
	if ok:
		r2.give_everything()
		# A gun whose spread follows the carrier needs a context; the rig's own idle posture stands in for it.
		for slot in r2.arsenal._slots.keys():
			r2.arsenal.equip(slot)
			if r2.would_idle(cmd):
				idles = true
				break
	_check("a set-up rig with nothing pressed idles on a weapon that needs no context", idles)
	cmd.buttons = DotWeaponCommand.BUTTON_ATTACK
	_check("a pressed attack does not", ok and idles and not r2.would_idle(cmd))
	r2.queue_free()
	_end()


## Effects with nothing to show stop their per-frame work and pick it up again on the next shot, draw or showing.
func _idle_sleep() -> void:
	_begin("idle effects sleep")
	var holder := Node3D.new()
	add_child(holder)
	var wall := StaticBody3D.new()
	holder.add_child(wall)
	var shots := AwShotFx.new()
	shots.sounds = false
	holder.add_child(shots)
	shots._process(0.1)
	_check("a shooter with nothing showing stops processing", not shots.is_processing() and shots.is_idle())
	shots.play_impact(Vector3(0.0, 0.0, -10.0), Vector3.BACK, wall)
	_check("an impact wakes it (%d marks, %d live)" % [shots.mark_count(), shots.live_count()],
		shots.is_processing() and not shots.is_idle())
	shots._process(AwShotFx.MARK_LIFE + 1.0)
	_check("once the mark has faded it sleeps again", not shots.is_processing() and shots.is_idle())

	var charge := preload("res://addons/arena_weapons/view/aw_charge_fx.gd").new()
	holder.add_child(charge)
	charge._process(0.1)
	_check("a hidden charge ball stops processing", not charge.is_processing())
	charge.note_fired()
	charge._process(0.1)
	_check("a shot keeps it counting through the fizzle window", charge.is_processing())
	charge._process(0.2)
	_check("past the window it sleeps again", not charge.is_processing())
	charge.set_charge(0.5)
	_check("a draw wakes it", charge.is_processing() and charge.visible)

	var held := AwWorldModel.new()
	holder.add_child(held)
	held.visible = false
	held._process(0.1)
	held._process(0.25)
	_check("a hidden held gun banks its time (%.2f)" % held._hidden_for, is_equal_approx(held._hidden_for, 0.25))
	held.visible = true
	held._process(0.1)
	_check("and spends it when it shows", held._hidden_for < 0.0)
	holder.free()
	_end()


## A person's gun-arm carry, as dot-player-char API 22 draws it: what a held gun told it.
class FakeCarry extends RefCounted:
	var kinds: Array = []
	var fires := 0
	var raised := false
	var reloading := false
	var switching := false

	func set_class(kind: Variant) -> void:
		kinds.append(kind)

	func fired() -> void:
		fires += 1


## A person the held gun finds by its swing and set_hold, carrying [member carry].
class FakePerson extends Node3D:
	var carry: Variant = FakeCarry.new()

	func swing(_which: StringName) -> void:
		pass

	func set_hold(_kind: int) -> void:
		pass


## [param id]'s art as a pack's stand-in builds it: the base gun of its slot, dressed from the pack's own rows.
func _dressed(id: StringName) -> AwWeaponVisual:
	var art: AwWeaponVisual
	match id:
		&"knife":
			art = AwWeaponArtTable.knife()
		&"pistol":
			art = AwWeaponArtTable.pistol()
		&"minigun", &"launcher":
			art = AwWeaponArtTable.launcher()
		_:
			art = AwWeaponArtTable.rifle()
	art.id = id
	AwArtDress.apply(art, AwWeaponArt.weapon_rows("").get(id, {}))
	return art


## A held gun on a person with a carry hands it the class, the shot, the reload and the switch, and draws no kick
## or reload dip of its own; on a person without one it still does.
func _person_carry() -> void:
	_begin("a held gun hands its kick and reload to the person's carry")
	var person := FakePerson.new()
	add_child(person)
	var held := AwWorldModel.new()
	person.add_child(held)
	var carry: FakeCarry = person.carry
	held.equip(_dressed(&"shotgun"))
	held.advance(0.02)
	_check("the shotgun sets the shotgun carry (%s)" % [carry.kinds], carry.kinds == [&"shotgun"])
	held.advance(0.02)
	_check("once, not every frame", carry.kinds.size() == 1)
	held.on_fired(Vector2(1.0, 0.1))
	_check("a shot is the carry's, with no kick of the model's own (%.3f)" % held._kick, carry.fires == 1 and held._kick == 0.0)
	held.on_reloading(true)
	held.advance(0.4)
	_check("a reload is the carry's, with no dip of the model's own", carry.reloading
		and held._holder.position.is_equal_approx(held._rest().origin))
	held.on_reloading(false)
	held.on_switching(true)
	held.on_aiming(true)
	_check("the switch and the aim reach it", carry.switching and carry.raised and not carry.reloading)
	held.on_switching(false)
	held.equip(_dressed(&"knife"))
	held.advance(0.02)
	_check("a knife clears the class (%s)" % [carry.kinds], carry.kinds.size() == 2 and carry.kinds[1] == null)
	var classes := {}
	AwWeaponSound.set_class(&"aw_drum_shotgun", &"autoshot")
	for id: StringName in [&"pistol", &"sniper", &"marksman", &"smg", &"lmg", &"minigun", &"launcher", &"rifle", &"aw_drum_shotgun"]:
		classes[id] = AwWorldModel.carry_class(_dressed(id))
	AwWeaponSound.set_class(&"aw_drum_shotgun", &"")
	_check("guns read as the carry's classes, a prefixed id by its host's sound class (%s)" % [classes], classes == {
		&"pistol": &"pistol", &"sniper": &"sniper", &"marksman": &"sniper", &"smg": &"smg", &"lmg": &"rifle",
		&"minigun": &"heavy", &"launcher": &"heavy", &"rifle": &"rifle", &"aw_drum_shotgun": &"shotgun"})
	person.free()

	var bare := Node3D.new()
	add_child(bare)
	var alone := AwWorldModel.new()
	bare.add_child(alone)
	alone.equip(_dressed(&"rifle"))
	alone.on_fired(Vector2(1.0, 0.1))
	_check("without a carry a shot still kicks the model (%.3f)" % alone._kick, alone._kick > 0.0)
	alone.on_reloading(true)
	alone.advance(0.4)
	_check("and a reload still dips it", alone._holder.position.y < alone._rest().origin.y - 0.01)
	bare.free()
	_end()


func _charge_fizzle() -> void:
	_begin("charge ball fizzle")
	var fx := preload("res://addons/arena_weapons/view/aw_charge_fx.gd").new()
	fx.set_charge(0.6)
	fx.advance(0.5)
	fx.set_charge(0.0)
	_check("an early release is a fizzle that ends in under 8 frames at 60 Hz",
		fx.is_fizzling() and fx.collapse_time() < 8.0 / 60.0)
	for i in 8:
		fx.advance(1.0 / 60.0)
	_check("the fizzle is gone after 8 frames", not fx.visible and fx.shown() == 0.0)
	fx.free()
	_end()


## A hand's first shot and charge take what [AwFxPool] parked under the cover: nothing is built when they happen.
func _fx_pool() -> void:
	_begin("fx pool: parked effects are taken, not built")
	var pool := AwFxPool.new()
	add_child(pool)
	var full := false
	for _i in 400:
		if pool.fill(3, 2, 0.5):
			full = true
			break
	_check("fill parks what was asked for, a slice at a time", full and pool.spare_shots() == 3 and pool.spare_charges() == 2)
	for _i in 3:
		await get_tree().process_frame
	var hand := Node3D.new()
	add_child(hand)
	var before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var fx := AwFxPool.take_shot_fx()
	_check("a parked effects node comes out of the tree", fx != null and fx.get_parent() == null)
	# A game hands every remote hand one shared layered player; alone, the first shot would build its own.
	fx.layered_shots = false
	hand.add_child(fx)
	var kids := fx.get_child_count()
	fx.play_remote(AwWeaponNet.KIND_SHOT, Transform3D.IDENTITY, Vector3.FORWARD, &"rifle")
	var made := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - before
	_check("taking it and firing once creates no node (%d made, %d under it)" % [made, fx.get_child_count() - kids], made == 0)
	_check("it came with its voices and quads", (fx.get("_voices") as Array).size() >= 1
		and (fx.get_node("Meshes") as DotFxMeshPool).built() >= pool.shot_meshes)
	_check("it ticks again once in a hand", fx.can_process())
	var ball := AwFxPool.take_charge_fx()
	hand.add_child(ball)
	ball.call("set_charge", 0.5)
	_check("a parked charge ball shows on the first charge and creates no node", ball.visible
		and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == before)
	_check("the pool counts what it handed out", pool.handed == 2 and pool.spare_shots() == 2 and pool.spare_charges() == 1)
	var _a := AwFxPool.take_shot_fx()
	var _b := AwFxPool.take_shot_fx()
	_check("an empty pool answers null and counts the miss", AwFxPool.take_shot_fx() == null and pool.missed == 1)
	hand.add_child(_a)
	hand.add_child(_b)
	_a.first_person = false
	_a.layered_shots = true
	_check("a remote shooter takes the layered shot the pool built instead of its own",
		not AwShotLayers.available() or (_a.prewarm_layers() and _a.get("_layers") == AwFxPool.shared_layers(self, pool.layers_bus)))
	pool.free()
	_check("with no pool in the tree there is nothing to take",
		AwFxPool.current() == null and AwFxPool.take_shot_fx() == null and AwFxPool.take_charge_fx() == null)
	hand.free()
	_end()


func _shared_catalogue() -> void:
	_begin("shared weapon catalogue")
	var a := AwWeaponCatalogue.shared()
	var ids := AwWeaponCatalogue.weapons().map(func(d: DotWeaponDef) -> StringName: return d.id)
	_check("the shared catalogue is built once and holds every weapon",
		a != null and a == AwWeaponCatalogue.shared() and ids.all(func(id: StringName) -> bool: return a.get_def(id) != null))
	AwWeaponCatalogue.remove_source(&"lag16_probe")
	_check("adding or removing a source builds it again", AwWeaponCatalogue.shared() != a)
	_end()


func _mag_carve() -> void:
	_begin("a magazine carved out of a welded mesh")
	var carve: Script = load("res://addons/arena_weapons/view/aw_mag_carve.gd")
	# One mesh: a body (triangles near y=0) and a magazine (triangles near y=-1) in a single surface.
	var verts := PackedVector3Array()
	for y in [0.0, -1.0]:
		for k in 20:
			var x := float(k) * 0.1
			verts.append_array(PackedVector3Array([Vector3(x, y, 0), Vector3(x + 0.05, y, 0), Vector3(x, y, 0.05)]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var whole := ArrayMesh.new()
	whole.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var holder := Node3D.new()
	var weapon := Node3D.new()
	holder.add_child(weapon)
	var mi := MeshInstance3D.new()
	mi.mesh = whole
	weapon.add_child(mi)
	add_child(holder)
	var mag: Node3D = carve.call(&"carve", weapon, holder, Transform3D.IDENTITY, AABB(Vector3(-1, -1.5, -1), Vector3(4, 1, 2)), "selftest")
	_check("the magazine becomes a node of the weapon", mag != null and mag.get_parent() == mi.get_parent() and mag.name == "Magazine")
	_check("the magazine holds its 20 triangles", mag != null and (mag as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 60)
	_check("the gun keeps the other 20", mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 60)
	_check("nothing is left in the carve box on the gun", mi.mesh.get_aabb().position.y > -0.5)
	var again: Node3D = carve.call(&"carve", weapon, holder, Transform3D.IDENTITY, AABB(Vector3(-1, 5, -1), Vector3(1, 1, 1)), "selftest-empty")
	_check("a box with nothing in it carves nothing", again == null)
	carve.call(&"merge_back", mag)
	_check("merging back leaves one mesh with every triangle", mi.mesh == whole and weapon.get_child_count() == 1)
	holder.queue_free()
	_check("the carve box is remembered per model", (carve.call(&"recall", "x") as AABB).size == Vector3.ZERO)
	_end()


## A build without the models (the web shell) draws them from a mounted pack listed with add_fallback_root.
## The pack is built here with PCKPacker: one box scene, under a synthetic dot-cloud mount; no CDN.
func _assets_pack() -> void:
	_begin("models come from a mounted pack when the build lacks them")
	const ROOT := "res://dot_cloud/aw_synth/1/arena_weapons/assets"
	var path := AwModelCache.ASSETS_BASE + "models/selftest_pack_gun.tscn"
	var outside := "res://aw_selftest_elsewhere/models/selftest_pack_gun.tscn"
	AwModelCache.clear()
	_check("the build does not carry the pack's model", not AwModelCache.scene(path).ok and not AwModelCache.exists(path))
	_check("a missing model measures as an empty box", AwModelCache.bounds(path).size == Vector3.ZERO)
	var made := _synth_assets_pack(ROOT + "/models/selftest_pack_gun.tscn")
	_check("synthetic assets pack mounts", made != "" and ProjectSettings.load_resource_pack(made, false))
	_check("mounted but not listed, the model is still missing", not AwModelCache.scene(path).ok)
	AwModelCache.add_fallback_root(ROOT + "/")
	_check("listed, the model loads from the pack", AwModelCache.scene(path).ok and AwModelCache.exists(path))
	var model := AwModelCache.instantiate(path)
	_check("and instantiates", model != null)
	if model != null:
		model.free()
	_check("the empty box measured before is dropped and the model measured", is_equal_approx(AwModelCache.bounds(path).size.x, 0.2))
	_check("a path outside the addon's assets is not redirected", not AwModelCache.exists(outside))
	AwModelCache.remove_fallback_root(ROOT)
	_check("unlisted again, the model is gone and the list empty", not AwModelCache.exists(path) and AwModelCache.fallback_roots().is_empty())
	AwModelCache.clear()
	_end()


## Writes a pck holding a 0.2 m box scene at [param inside]; the pck's path, or "" if it could not.
func _synth_assets_pack(inside: String) -> String:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.1, 0.4)
	mesh.mesh = box
	root.add_child(mesh)
	mesh.owner = root
	var packed := PackedScene.new()
	var packed_ok := packed.pack(root) == OK
	root.free()
	var scene_file := ProjectSettings.globalize_path("user://aw_selftest_pack_gun.tscn")
	if not packed_ok or ResourceSaver.save(packed, scene_file) != OK:
		return ""
	var out := ProjectSettings.globalize_path("user://aw_selftest_assets.pck")
	var packer := PCKPacker.new()
	if packer.pck_start(out) != OK or packer.add_file(inside, scene_file) != OK or packer.flush() != OK:
		return ""
	return out


func _finish() -> void:
	print("")
	print("%d sections entered, %d finished, %d checks, %d failed" % [_entered, _finished, _checks, _failures])
	var passed := _failures == 0 and _entered == _finished and _checks == CHECKS
	if _checks != CHECKS:
		print("!! %d checks ran, %d expected. A section aborted part-way." % [_checks, CHECKS])
	print("RESULT: %s" % ("PASS" if passed else "FAIL"))
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if passed else 1)
