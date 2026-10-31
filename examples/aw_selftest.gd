extends Node

## Headless suite: models load with the muzzle where the table says and the stock clear of the eye at the sights,
## the provider's contract, the pack's own weapon definitions, and a zee art dressed by role.
## What it cannot see is how they look: tools/screenshot.sh in game-arena renders the hands.

const CHECKS := 219
## Guns whose model shows its own notch, aperture or post (the rest aim at their row's written aim).
const OWN_SIGHTED := 9

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
	_own_sights()
	_grenades()
	_utility()
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


func _provider() -> void:
	_begin("provider contract")
	var rows := AwSpawnProvider.art_rows()
	var entries := AwSpawnProvider.spawn_entries()
	_check("one art row per weapon this pack defines", rows.size() == AwWeaponPack.IDS.size() and AwWeaponArt.WEAPONS.size() == AwWeaponPack.IDS.size())
	var pistol := AwWeaponArt.row_of(&"pistol")
	_check("the pistol row keeps its own hand scale, not the tier's 0.36", is_equal_approx(float(pistol["hand_scale"]), 0.25))
	_check("the pistol row slims its forearm so it does not fill the lower right", float(pistol.get("forearm_scale", 1.0)) < 1.0)
	_check("the pistol row names a support grip", (pistol["support_grip"] as Vector3).is_finite())
	_check("the grenade launcher is drawn smaller than a long gun", float(AwWeaponArt.row_of(&"grenade_launcher")["view"]["scale"]) < 0.5)
	_check("a pistol keeps zee's wall defaults", AwWeaponArt.wall_row(&"pistol").is_empty())
	_check("a rifle retreats deeper from a wall than the 0.34 m default", float(AwWeaponArt.wall_row(&"rifle")["wall_max"]) > 0.34)
	_check("a launcher retreats deeper than a rifle", float(AwWeaponArt.wall_row(&"launcher")["wall_max"]) > float(AwWeaponArt.wall_row(&"rifle")["wall_max"]))
	_check("a knife shortens its wall reach", float(AwWeaponArt.wall_row(&"knife")["wall_reach"]) < 1.0)
	var rifle_def := AwWeaponPack.weapons({}, "", false).filter(func(d: DotWeaponDef) -> bool: return d.id == &"rifle")[0] as DotWeaponDef
	_check("the rifle def carries its wall row in params.ads", (rifle_def.params["ads"] as Dictionary).has("wall_max"))
	var rules := ZeeAdsRules.new()
	rules.set_def_row(&"rifle", rifle_def.params["ads"])
	_check("zee accepts the rifle's wall row whole", float(rules.wall_for(&"rifle")["max"]) == float((rifle_def.params["ads"] as Dictionary)["wall_max"]))
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
	var rifle_modes := _def(defs, &"aw_rifle").allowed_fire_modes()
	_check("the rifle's selector offers semi, burst and auto", rifle_modes.size() == 3 and rifle_modes.has(DotWeaponDef.Fire.AUTO) and rifle_modes.has(DotWeaponDef.Fire.SEMI))
	_check("the pistol's selector has no auto it cannot fire", not _def(defs, &"aw_pistol").allowed_fire_modes().has(DotWeaponDef.Fire.AUTO))
	_check("the smg's selector offers more than one mode", _def(defs, &"aw_smg").allowed_fire_modes().size() > 1)
	_check("every selector starts on a mode its gun allows", defs.all(func(d: DotWeaponDef) -> bool: return d.allowed_fire_modes().has(d.fire_mode)))
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
	_check("every gun row names its own reload style: %s" % ", ".join(_unstyled()), _unstyled().is_empty())
	_end()


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


func _own_sights() -> void:
	_begin("aimed down each model's own sight")
	var view := ZeeViewModel.new()
	view.show_arms = false
	add_child(view)
	var own := 0
	var built: Array[StringName] = []
	var blocked: Array[StringName] = []
	var worst := 0.0
	var rows := AwWeaponArt.weapon_rows("")
	for role: StringName in rows:
		var row: Dictionary = rows[role]
		if row["motion"] != "gun" or (row["view"] as Dictionary).get("scoped", false):
			continue
		var art := ZeeWeaponArt.make(role)
		ZeeArtDress.apply(art, row)
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
		for p: Vector3 in [points.rear, points.front]:
			worst = maxf(worst, Vector2(p.x, p.y).length())
	view.queue_free()
	_check("no gun has a sight built over its own (%s)" % str(built), built.is_empty())
	_check("%d guns aim down a notch, aperture or post of their own" % own, own >= OWN_SIGHTED)
	_check("each own sight line runs through the screen's centre (worst %.4f m)" % worst, worst < 0.002)
	_check("no gun has any of its model inside the see-through cone round the aim line (%s)" % str(blocked), blocked.is_empty())
	_end()


## Rays from the aimed eye inside the sight cone, as far as the front post, hit nothing of the gun.
func _aim_clear(view: ZeeViewModel, role: StringName, blocked: Array[StringName]) -> void:
	var roots: Array = [view._weapon]
	var cone: Dictionary = ZeeViewModel.SightFit.cone_for(view._art, view.ads_rules, roots, view._holder, view._aim_target(), view._sight_line)
	if cone.is_empty() or ZeeViewModel.SightFit.Cut.occluders(view._weapon, view._holder, cone) > 0:
		blocked.append(role)


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
	var own_dir := AwGrenadeFx.own_dir()
	var own_defs := AwGrenadeFx.defs()
	_check("with no folder the clouds load from the addon's own fx/", own_defs[0].scene_path == own_dir + "/smoke_cloud.tscn" and ResourceLoader.exists(own_defs[0].scene_path) and ResourceLoader.exists(own_defs[1].scene_path))
	_check("both shipped cloud scenes instance", (load(own_defs[0].scene_path) as PackedScene).instantiate() != null and (load(own_defs[1].scene_path) as PackedScene).instantiate() != null)
	_check("API level 5", preload("res://addons/arena_weapons/arena_weapons_api.gd").LEVEL == 5)

	var fx_defs := AwGrenadeFx.defs("res://fx")
	_check("three fx defs: two clouds from the game's folder and a screen flash", fx_defs.size() == 3 and fx_defs[0].scene_path == "res://fx/smoke_cloud.tscn" and fx_defs[2].kind == DotFxDef.Kind.SCREEN)
	_check("the flash decay follows the blind, clamped", AwGrenadeFx.flash_decay_ms(0.01) == AwGrenadeFx.BLIND_MIN_MS and AwGrenadeFx.flash_decay_ms(3.0) == 3000 and AwGrenadeFx.flash_decay_ms(99.0) == AwGrenadeFx.BLIND_MAX_MS)
	_check("showing with no fx host is a no-op", AwGrenadeFx.show(null, null, {"fx": AwUtilityZones.Fx.SMOKE, "seconds": 1.0, "radius": 1.0, "position": Vector3.ZERO, "victim": 0}, 0) == null)
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
