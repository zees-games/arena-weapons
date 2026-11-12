extends Node

## Grenade and utility sections of the self-test, with the counters and `_begin` / `_end` / `_check` every section uses; split out of aw_selftest.gd for file size.

var _entered := 0
var _finished := 0
var _checks := 0
var _failures := 0


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


func _utility() -> void:
	_begin("utility grenade glue")
	var defs := AwSpawnProvider.weapon_defs()
	var ids := AwUtilityZones.utility_ids(defs)
	_check("utility ids are the flash, smoke and incendiary, not the frags", ids.size() == 3 and ids.has(&"aw_flash") and not ids.has(&"aw_frag"))

	var z := AwUtilityZones.new()
	var people: Array = [
		AwUtilityZones.victim(2, Vector3(1, 0, 0), Vector3(1, 1.6, 0), Vector3.LEFT),
		AwUtilityZones.victim(3, Vector3(30, 0, 0), Vector3(30, 1.6, 0), Vector3.LEFT),
		AwUtilityZones.victim(4, Vector3(1, 5, 0), Vector3(1, 6.6, 0), Vector3.LEFT),
	]
	var hits: Array[Dictionary] = []
	z.victims = func() -> Array: return people
	z.los = AwUtilityZones.los_from_ray(func(_f: Vector3, _d: Vector3, _n: float) -> bool: return false)
	z.damage = func(attacker: int, victim: int, amount: float, type: Variant, _w: StringName) -> void:
		hits.append({"a": attacker, "v": victim, "n": amount, "t": type})
	var seen: Array[Dictionary] = []
	z.effect.connect(func(i: Dictionary) -> void: seen.append(i))

	var blocked := AwUtilityZones.los_from_ray(func(_f: Vector3, _d: Vector3, _n: float) -> bool: return true)
	_check("the ray adapter says clear when nothing is hit and blocked when something is", z.los.call(Vector3.ZERO, Vector3.ONE) and not blocked.call(Vector3.ZERO, Vector3.ONE) and z.los.call(Vector3.ONE, Vector3.ONE) and blocked.call(Vector3.ONE, Vector3.ONE))

	var inc := AwGrenade.from_spawn(DotWeaponSpawn.make(&"aw_incendiary", Vector3.ZERO, Vector3.ZERO, 7), _def(defs, &"aw_incendiary"), z.rules)
	inc.owner_entity = 9
	var _ev := z.detonate(inc, _def(defs, &"aw_incendiary"))
	_check("an incendiary opens one fire zone and tells the host", z.active_fires() == 1 and seen.size() == 1 and int(seen[0]["fx"]) == AwUtilityZones.Fx.FIRE)
	for i in 10:
		z.tick(0.1)
	var burned := hits.filter(func(h: Dictionary) -> bool: return h["v"] == 2)
	_check("the fire pulses damage as the thrower, twice a second", burned.size() == 2 and burned[0]["a"] == 9 and burned[0]["t"] == AwUtilityZones.FIRE_TYPE)
	_check("fire spares who stands far off or a floor above", not hits.any(func(h: Dictionary) -> bool: return h["v"] == 3 or h["v"] == 4))
	for i in int(z.rules.fire_seconds * 10.0) + 10:
		z.tick(0.1)
	_check("a fire zone burns out", z.active_fires() == 0)

	var smoke := AwGrenade.from_spawn(DotWeaponSpawn.make(&"aw_smoke", Vector3.ZERO, Vector3.ZERO, 7), _def(defs, &"aw_smoke"), z.rules)
	var _sev := z.detonate(smoke, _def(defs, &"aw_smoke"))
	_check("smoke is a cloud that expires", z.active_smokes() == 1 and int(seen[-1]["fx"]) == AwUtilityZones.Fx.SMOKE)
	z.tick(z.rules.smoke_seconds + 1.0)
	_check("smoke is gone after its seconds", z.active_smokes() == 0)

	var flash := AwGrenade.from_spawn(DotWeaponSpawn.make(&"aw_flash", Vector3.ZERO, Vector3.ZERO, 7), _def(defs, &"aw_flash"), z.rules)
	var _fev := z.detonate(flash, _def(defs, &"aw_flash"))
	var blinds := seen.filter(func(i: Dictionary) -> bool: return int(i["fx"]) == AwUtilityZones.Fx.BLIND)
	_check("a flash blinds the one facing it and the ledger holds the blind", blinds.any(func(i: Dictionary) -> bool: return int(i["victim"]) == 2) and z.ledger.is_blind(2) and not z.ledger.is_blind(3))
	var before := z.ledger.remaining(2)
	z.tick(1.0)
	_check("the blind ticks down with the clock", is_equal_approx(z.ledger.remaining(2), before - 1.0))
	z.tick(60.0)
	_check("and ends", not z.ledger.is_blind(2) and z.ledger.count() == 0)

	var l := AwBlindLedger.new()
	var _a := l.blind(1, 3.0)
	var _b := l.blind(1, 1.0)
	_check("a shorter flash never shortens a blind", is_equal_approx(l.remaining(1), 3.0))
	var _c := l.blind(1, 5.0)
	_check("a longer one extends it", is_equal_approx(l.remaining(1), 5.0))
	var _d := l.blind(2, 999.0)
	_check("no blind passes the cap", is_equal_approx(l.remaining(2), l.max_seconds))
	l.clear_victim(2)
	_check("a victim's blind can be lifted", not l.is_blind(2) and l.is_blind(1))

	z.apply_blast_damage = true
	hits.clear()
	var frag := AwGrenade.from_spawn(DotWeaponSpawn.make(&"aw_frag", Vector3.ZERO, Vector3.ZERO, 7), _def(defs, &"aw_frag"), z.rules)
	var _gev := z.detonate(frag, _def(defs, &"aw_frag"))
	_check("blast damage goes through the host's callable when asked", hits.any(func(h: Dictionary) -> bool: return h["v"] == 2))

	var _w := l.blind(5, 2.0, 0.4)
	var _w2 := l.blind(5, 1.0, 0.9)
	var _w3 := l.blind(5, 1.0, 0.2)
	_check("the ledger keeps the strongest strength of a stretch", is_equal_approx(l.strength(5), 0.9) and is_equal_approx(l.strength(1), 1.0))
	l.tick(99.0)
	_check("strength is 0 once the blind ends, and a new blind starts fresh", l.strength(5) == 0.0 and is_equal_approx((l.blind(5, 1.0, 0.3) * 0.0) + l.strength(5), 0.3))
	_check("a blind event carries strength, and a flash at the edge or side is weaker",
		blinds.any(func(i: Dictionary) -> bool: return int(i["victim"]) == 2 and float(i["strength"]) > 0.0 and float(i["strength"]) <= 1.0))
	_utility_fx()
	_end()


func _utility_fx() -> void:
	var own_dir := AwGrenadeFx.own_dir()
	var own_defs := AwGrenadeFx.defs()
	_check("with no folder the clouds load from the addon's own fx/", own_defs[0].scene_path == own_dir + "/smoke_cloud.tscn" and ResourceLoader.exists(own_defs[0].scene_path) and ResourceLoader.exists(own_defs[1].scene_path))
	_check("both shipped cloud scenes instance", (load(own_defs[0].scene_path) as PackedScene).instantiate() != null and (load(own_defs[1].scene_path) as PackedScene).instantiate() != null)
	_check("API level 17", preload("res://addons/arena_weapons/arena_weapons_api.gd").LEVEL == 17)

	var fx_defs := AwGrenadeFx.defs("res://fx")
	_check("three fx defs: two clouds from the game's folder and a screen flash", fx_defs.size() == 3 and fx_defs[0].scene_path == "res://fx/smoke_cloud.tscn" and fx_defs[2].kind == DotFxDef.Kind.SCREEN)
	_check("the flash decay follows the blind, clamped", AwGrenadeFx.flash_decay_ms(0.01) == AwGrenadeFx.BLIND_MIN_MS and AwGrenadeFx.flash_decay_ms(3.0) == 3000 and AwGrenadeFx.flash_decay_ms(99.0) == AwGrenadeFx.BLIND_MAX_MS)
	_check("showing with no fx host is a no-op", AwGrenadeFx.show(null, null, {"fx": AwUtilityZones.Fx.SMOKE, "seconds": 1.0, "radius": 1.0, "position": Vector3.ZERO, "victim": 0}, 0) == null)


func _thrown() -> bool:
	var art := AwWeaponVisual.make(&"frag")
	art.model_forward = Vector3.UP
	AwArtDress.apply(art, AwSpawnProvider.role_art()[&"frag"])
	return art.model_path == AwWeaponArt.model_path("stick_grenade") and art.model_forward == Vector3.UP


func _def(defs: Array[DotWeaponDef], id: StringName) -> DotWeaponDef:
	for d in defs:
		if d.id == id:
			return d
	return DotWeaponDef.new()


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
