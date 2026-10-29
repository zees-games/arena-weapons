extends Node

## Headless suite: models load with the muzzle where the table says and the stock clear of the eye at the sights,
## the provider's contract, the pack's own weapon definitions, and a zee art dressed by role.
## What it cannot see is how they look: tools/screenshot.sh in game-arena renders the hands.

const CHECKS := 139

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
		node.free()
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
