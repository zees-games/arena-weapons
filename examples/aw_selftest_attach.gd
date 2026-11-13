extends Node

## Attachment section of the self-test, with the counters and `_begin` / `_end` / `_check` every section uses.

const Dress := preload("res://addons/arena_weapons/view/aw_attachment_dress.gd")

var _entered := 0
var _finished := 0
var _checks := 0
var _failures := 0


func _attachments() -> void:
	_begin("attachments")
	var cat := AwSpawnProvider.attachment_defs()
	var defs := AwSpawnProvider.weapon_defs()
	var atts := AwAttachmentPack.attachments()
	_check("ten attachments, each valid and its own item", cat.ids().size() == 10 and atts.all(func(a: DotWeaponAttachment) -> bool: return a.validate().ok and String(a.item()).begins_with("att_")))
	_check("every attachment model loads; each optic has its glass", atts.all(_model_ok))

	var rifle := _def(defs, &"aw_rifle")
	var sniper := _def(defs, &"aw_sniper")
	var pistol := _def(defs, &"aw_pistol")
	_check("a rifle has all five mounts", rifle.mounts.size() == 5)
	_check("a launcher, the minigun and the knife have none", [&"aw_launcher", &"aw_quad_launcher", &"aw_minigun", &"aw_knife", &"aw_frag"].all(func(i: StringName) -> bool: return _def(defs, i).mounts.is_empty()))
	_check("a built-in scope leaves no optic mount", not sniper.mounts.has(DotWeaponAttachment.MOUNT_OPTIC) and sniper.mounts.has(DotWeaponAttachment.MOUNT_MUZZLE))
	var pistol_optics: Array = cat.choices_for(pistol).get(DotWeaponAttachment.MOUNT_OPTIC, [])
	_check("a sidearm takes a red dot but no magnified optic", pistol_optics.has(&"red_dot") and not pistol_optics.has(&"prism_3x") and not pistol_optics.has(&"scope_6x"))

	var applied := 0
	var offered := 0
	for def in defs:
		var choices := cat.choices_for(def)
		for mount: StringName in choices:
			for id: StringName in choices[mount]:
				offered += 1
				var fit := DotWeaponFitting.make(def.id)
				fit.fit(mount, id)
				if cat.apply(def, fit).ok:
					applied += 1
	_check("every offered attachment applies to its gun (%d of %d)" % [applied, offered], offered > 50 and applied == offered)

	var full := DotWeaponFitting.make(rifle.id)
	for pair: Array in [[&"optic", &"scope_6x"], [&"muzzle", &"suppressor"], [&"underbarrel", &"vertical_grip"], [&"side", &"laser"], [&"magazine", &"extended_mag"]]:
		full.fit(pair[0], pair[1])
	var res := cat.apply(rifle, full)
	var fitted: DotWeaponDef = res.value if res.ok else null
	_check("a fitted rifle holds more, kicks less and is suppressed", fitted != null and fitted.magazine > rifle.magazine
		and fitted.tuning.recoil_pitch < rifle.tuning.recoil_pitch and fitted.params.get(DotWeaponAttachment.PARAM_SUPPRESSED, false) == true)
	_check("the suppressor picks the suppressed report", fitted != null and AwSpawnProvider.sound_class_for(fitted, &"rifle") == AwWeaponSound.SUPPRESSED and AwSpawnProvider.sound_class_for(rifle, &"rifle") == &"rifle")
	_check("the base def is untouched", not rifle.params.has(DotWeaponAttachment.PARAM_SUPPRESSED))
	var bad := DotWeaponFitting.make(sniper.id)
	bad.fit(DotWeaponAttachment.MOUNT_OPTIC, &"red_dot")
	_check("the server refuses an optic on a gun with no optic mount", not cat.validate_fitting(sniper, bad).ok and cat.conform(sniper, bad).is_empty())
	_check("a fitting survives the wire", cat.decode(rifle, cat.encode(rifle, full)).key() == full.key())
	_check("art for an id the pack does not draw is empty", AwAttachmentArt.of(&"no_such").is_empty() and AwAttachmentArt.of(&"holo").get("zoom", 0.0) == 0.75)

	var art := AwWeaponVisual.new()
	AwArtDress.apply(art, AwWeaponArt.row_of(&"rifle"))
	var gun := AwModelCache.instantiate(art.model_path)
	var dressed := Dress.apply(gun, full, art.model_forward, {})
	_check("all five draw on the rifle's sockets", dressed.parts.size() == 5)
	var mag_socket := gun.find_child("socket_magazine", true, false)
	_check("the magazine extension rides on the magazine", mag_socket != null and mag_socket.get_parent().name == &"magazine")
	_check("the scope gives the sight picture: scoped, its zoom, a line through the glass", dressed.scoped and is_equal_approx(dressed.zoom, 0.17) and dressed.line.has("front"))
	var socket_z := absf((gun.find_child("socket_muzzle", true, false) as Node3D).position.z)
	_check("the suppressor moves the muzzle out (%.3f past %.3f)" % [dressed.reach, socket_z], dressed.reach > socket_z + 0.1)
	_check("the server measures the same reach", is_equal_approx(Dress.muzzle_reach(art, full), dressed.reach))
	var dot := DotWeaponFitting.make(rifle.id)
	dot.fit(DotWeaponAttachment.MOUNT_OPTIC, &"red_dot")
	dressed = Dress.apply(gun, dot, art.model_forward, dressed)
	_check("a red dot swaps in unscoped at its own zoom", dressed.parts.size() == 1 and not dressed.scoped and is_equal_approx(dressed.zoom, 0.83))
	gun.free()
	_end()


func _model_ok(a: DotWeaponAttachment) -> bool:
	var part := AwModelCache.instantiate(a.model)
	if part == null:
		return false
	var ok := a.mount != DotWeaponAttachment.MOUNT_OPTIC or part.find_child("*_glass", true, false) != null
	part.free()
	return ok


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
