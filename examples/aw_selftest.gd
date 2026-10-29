extends Node

## Headless suite: models load with the muzzle where the table says and the stock clear of the eye at the sights,
## the provider's contract, the pack's own weapon definitions, and a zee art dressed by role.
## What it cannot see is how they look: tools/screenshot.sh in game-arena renders the hands.

const CHECKS := 175

var _entered := 0
var _finished := 0
var _checks := 0
var _failures := 0


func _ready() -> void:
	print("arena-weapons self-test")
	_models()
	_provider()
	_defs()
	_dress()
	_grenades()
	await _finish()


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


func _provider() -> void:
	_begin("provider contract")
	var rows := AwSpawnProvider.art_rows()
	var entries := AwSpawnProvider.spawn_entries()
	_check("one art row per weapon this pack defines", rows.size() == AwWeaponPack.IDS.size() and AwWeaponArt.WEAPONS.size() == AwWeaponPack.IDS.size())
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
	_check("one weapon per slot at least", [1, 2, 3, 4, 5].all(func(s: int) -> bool: return defs.any(func(d: DotWeaponDef) -> bool: return d.slot == s)))
	# As a host's registered source: it must not recurse through the host's own weapons().
	ZeeWeaponPack.add_source(&"aw_selftest", Callable(AwSpawnProvider, &"weapon_defs"))
	var hosted := ZeeWeaponPack.weapons()
	ZeeWeaponPack.remove_source(&"aw_selftest")
	var found := 0
	for d in hosted:
		found += 1 if String(d.id).begins_with("aw_") else 0
	_check("registered as a zee source, every weapon joins the catalogue once", found == defs.size())
	_check("and the catalogue is the host's plus the pack's", hosted.size() == ZeeWeaponPack.weapons().size() + defs.size())
	_end()


func _dress() -> void:
	_begin("dressing a zee art by role")
	ZeeWeaponArtTable.drop_cache()
	var before := ZeeWeaponArtTable.table()[ZeeWeaponIds.RIFLE] as ZeeWeaponArt
	var rows := AwSpawnProvider.role_art()
	var art := ZeeWeaponArt.make(&"rifle")
	ZeeArtDress.apply(art, rows[&"rifle"])
	_check("the model is this pack's", art.model_path == AwWeaponArt.model_path("rifle"))
	_check("the muzzle is the table's", is_equal_approx(art.muzzle_distance, 0.548))
	_check("the zee art itself is untouched until a game applies it", before.model_path != art.model_path)
	_check("a grenade dressed keeps the throw carry", _thrown())
	_end()


func _grenades() -> void:
	_begin("grenade gameplay")
	var defs := AwSpawnProvider.weapon_defs()
	var rules := AwGrenadeRules.new()
	var floor_y := func(_from: Vector3, to: Vector3) -> Dictionary:
		if to.y > 0.0:
			return {}
		return {"position": Vector3(to.x, 0.0, to.z), "normal": Vector3.UP}
	var make := func(id: StringName, vel: Vector3, fuse: int) -> AwGrenade:
		var s := DotWeaponSpawn.make(id, Vector3(0, 1, 0), vel, 7)
		s.fuse_ticks = fuse
		s.gravity_scale = 1.0
		return AwGrenade.from_spawn(s, _def(defs, id), rules)

	_check("flash, smoke and incendiary are weapons with their own kinds", [&"aw_flash", &"aw_smoke", &"aw_incendiary"].all(func(i: StringName) -> bool: return _def(defs, i).slot == 5 and _def(defs, i).params.has(&"kind")))
	_check("they wear the baked grenade models", [&"flash", &"smoke", &"incendiary"].all(func(i: StringName) -> bool: return ResourceLoader.exists(AwWeaponArt.row_of(i)["model"])))

	var g: AwGrenade = make.call(&"aw_frag", Vector3(4, 0, 0), 64)
	var ticks := 0
	while ticks < 200:
		var gone := g.step(floor_y, 64)
		ticks += 1
		if gone:
			break
	_check("a frag bounces off the floor and goes off when the fuse runs out (%d ticks)" % ticks, g.bounces > 0 and ticks == 64 and g.position.y >= 0.0)
	_check("a bounce loses speed", g.velocity.length() < 12.0)

	var st: AwGrenade = make.call(&"aw_sticky", Vector3(2, 0, 0), 500)
	for i in 100:
		var _gone := st.step(floor_y, 64)
	_check("a sticky stays where it landed", st.stuck and st.velocity == Vector3.ZERO)

	var inc: AwGrenade = make.call(&"aw_incendiary", Vector3(0, -3, 0), 500)
	var burst := false
	for i in 100:
		burst = inc.step(floor_y, 64)
		if burst:
			break
	_check("an incendiary bursts on first contact, fuse not spent", burst and inc.fuse > 300)

	var cooked: AwGrenade = make.call(&"aw_frag", Vector3.ZERO, 0)
	_check("a grenade cooked past its fuse goes off at once", cooked.step(floor_y, 64))

	g.position = Vector3.ZERO
	var victims: Array = [
		{"id": 7, "position": Vector3(0, 0, 0), "eye": Vector3(0, 1.6, 0), "forward": Vector3.FORWARD},
		{"id": 2, "position": Vector3(2.6, 0, 0), "eye": Vector3(2.6, 1.6, 0), "forward": Vector3.FORWARD},
		{"id": 3, "position": Vector3(9, 0, 0), "eye": Vector3(9, 1.6, 0), "forward": Vector3.FORWARD},
		{"id": 4, "position": Vector3(1, 0, 0), "eye": Vector3(1, 1.6, 0), "forward": Vector3.FORWARD},
	]
	var clear := func(_a: Vector3, b: Vector3) -> bool: return b.x != 1.0
	var hurt := {}
	for e in AwGrenadeBlast.detonate(g, _def(defs, &"aw_frag"), victims, clear):
		if e["event"] == "damage":
			hurt[e["victim"]] = e["damage"]
	_check("splash falls off with distance and the thrower is hurt", hurt.has(7) and hurt.has(2) and hurt[7] > hurt[2] and hurt[2] > 0.0)
	_check("outside the radius or behind cover takes nothing", not hurt.has(3) and not hurt.has(4))

	var flash := AwGrenade.from_spawn(DotWeaponSpawn.make(&"aw_flash", Vector3.ZERO, Vector3.ZERO, 7), _def(defs, &"aw_flash"), rules)
	var look: Array = [
		{"id": 2, "position": Vector3(0, 0, -4), "eye": Vector3(0, 1.6, -4), "forward": Vector3(0, 0, 1)},
		{"id": 3, "position": Vector3(0, 0, -4), "eye": Vector3(0, 1.6, -4), "forward": Vector3(0, 0, -1)},
	]
	var blind := {}
	for e in AwGrenadeBlast.detonate(flash, _def(defs, &"aw_flash"), look, func(_a: Vector3, _b: Vector3) -> bool: return true):
		if e["event"] == "blind":
			blind[e["victim"]] = e["seconds"]
	_check("a flash blinds who faces it and spares who looks away", blind.has(2) and not blind.has(3) and blind[2] <= rules.flash_seconds)

	var sm := AwGrenade.from_spawn(DotWeaponSpawn.make(&"aw_smoke", Vector3.ZERO, Vector3.ZERO, 7), _def(defs, &"aw_smoke"), rules)
	var sev := AwGrenadeBlast.detonate(sm, _def(defs, &"aw_smoke"), [], clear)
	_check("smoke leaves a cloud and no damage", sev.any(func(e: Dictionary) -> bool: return e["event"] == "smoke") and not sev.any(func(e: Dictionary) -> bool: return e["event"] == "damage"))

	var _set := rules.set_cvar("sv_grenade_bounce", "5")
	_check("cvars clamp to their range and have sane defaults", is_equal_approx(rules.bounce, 0.95) and is_equal_approx(AwGrenadeRules.new().friction, 0.7))
	_end()


func _thrown() -> bool:
	var art := ZeeWeaponArt.make(&"frag")
	art.model_forward = Vector3.UP
	ZeeArtDress.apply(art, AwSpawnProvider.role_art()[&"frag"])
	return art.model_path == AwWeaponArt.model_path("frag_grenade") and art.model_forward == Vector3.UP


func _def(defs: Array[DotWeaponDef], id: StringName) -> DotWeaponDef:
	for d in defs:
		if d.id == id:
			return d
	return DotWeaponDef.new()


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


func _begin(name: String) -> void:
	_entered += 1
	print("")
	print("-- %s" % name)


func _end() -> void:
	_finished += 1


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if passed:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _finish() -> void:
	print("")
	print("%d sections entered, %d finished, %d checks, %d failed" % [_entered, _finished, _checks, _failures])
	var passed := _failures == 0 and _entered == _finished and _checks == CHECKS
	if _checks != CHECKS:
		print("!! %d checks ran, %d expected. A section aborted part-way." % [_checks, CHECKS])
	print("RESULT: %s" % ("PASS" if passed else "FAIL"))
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if passed else 1)
