extends "aw_shot_fx_audio.gd"

## Flash, pooled-effect and lifetime half of AwShotFx, split out for file size: the muzzle flash, its light,
## and the live-effect list every effect is added to. Behaviour lives in [AwShotFx], which extends this.

## Most effects alive at once, per carrier.
const MAX_LIVE := 48

## What each weapon class's flash and case are, by [AwWeaponSound] class: `size` scales the
## flash (1 is a rifle's, 12 cm across at the muzzle), `light` its light, `petals` how many
## crossed streaks leave the muzzle (a shotgun's is a fat four, a sniper's a long two), `length`
## stretches them, and `case` is the spent case's length in metres, `hull` true for a shotgun's
## fat red one, `delay` seconds before it leaves (a bolt or a pump cycles after the shot). A
## class not here is a rifle's. No `case` means nothing is ejected: a revolver keeps its
## cases, and a launcher has none.
const FLASH := {
	AwWeaponSound.LIGHT: {"size": 0.7, "light": 0.7, "petals": 2, "length": 0.9, "case": 0.024},
	AwWeaponSound.SUPPRESSED: {"size": 0.3, "light": 0.15, "petals": 1, "length": 0.6, "case": 0.024},
	AwWeaponSound.SMG: {"size": 0.75, "light": 0.75, "petals": 2, "length": 0.9, "case": 0.026},
	AwWeaponSound.MAGNUM: {"size": 1.15, "light": 1.1, "petals": 3, "length": 1.0},
	AwWeaponSound.RIFLE: {"size": 1.0, "light": 1.0, "petals": 2, "length": 1.0, "case": 0.038},
	AwWeaponSound.HEAVY: {"size": 1.25, "light": 1.25, "petals": 3, "length": 1.1, "case": 0.05},
	AwWeaponSound.SNIPER: {"size": 1.5, "light": 1.4, "petals": 2, "length": 2.0, "case": 0.065, "delay": 0.45},
	AwWeaponSound.SHOTGUN: {"size": 1.6, "light": 1.5, "petals": 4, "length": 0.9, "case": 0.055, "hull": true, "delay": 0.4},
	AwWeaponSound.MINIGUN: {"size": 1.1, "light": 0.9, "petals": 3, "length": 1.2, "case": 0.038},
	AwWeaponSound.LAUNCHER: {"size": 2.0, "light": 1.8, "petals": 4, "length": 1.4},
}

@export_group("Muzzle flash")

## Draw dot-fx's `DotMuzzleFlash` (sized by the profile's `extra.muzzle_flash`, else the weapon class) when dot-fx is linked; off, or without dot-fx, the procedural flash below is drawn.
@export var binbun_flash: bool = true

## Where a weapon's `extra.muzzle_flash` is read from; the rig sets it. Without it the class decides.
var catalogue: DotWeaponCatalogue = null

## Multiplier on every flash's size, on top of the weapon class's own ([constant FLASH]).
@export_range(0.0, 3.0, 0.05) var flash_scale: float = 1.0

## Size of a first-person flash on top of everything else; the rig sets it below 1 while the view is scoped, because the zoom magnifies the flash with the world.
var first_person_flash_scale: float = 1.0

## Multiplier on the flash's light. 0 draws no light at all.
@export_range(0.0, 3.0, 0.05) var flash_light_scale: float = 1.0

## Most flash lights alive at once, per carrier. A held minigun asks for one per shot and each
## lives 0.06 s, so without a cap it is a light per frame; past the cap the flash is drawn
## without its light.
@export_range(0, 8) var max_flash_lights: int = 2

## What each effect still alive is: {node, age, life, kind, ...}.
var _live: Array[Dictionary] = []

## Pooled dot-fx flashes by `category/size name/first person`.
var _pack_flashes: Dictionary = {}

## Reused flash lights and quads (dot-fx), so a shot builds and frees no node.
var _lights: DotFxLightPool = null
var _meshes: DotFxMeshPool = null

## How many flash lights are alive, against [member max_flash_lights].
func _lights_live() -> int:
	var count := 0
	for fx in _live:
		if fx.get("has_light", false):
			count += 1
	return count

func _flash(muzzle: Transform3D, size: float, weapon_class: StringName = AwWeaponSound.RIFLE,
		id: StringName = &"", first_person: bool = false) -> void:
	if binbun_flash and _pack_flash(muzzle, size, weapon_class, id, first_person):
		return
	var profile: Dictionary = FLASH.get(weapon_class, FLASH[AwWeaponSound.RIFLE])
	size *= float(profile["size"]) * flash_scale
	if size <= 0.0:
		return

	var node := _mesh(_quad_mesh(), _flash_mat())
	var forward := -muzzle.basis.z.normalized()
	node.global_position = muzzle.origin
	node.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	# Twelve centimetres, half a metre from the eye in first person: about a seventh of the screen.
	# Twice the first seven was a pale square over the gun; seven alone was the play test's
	# "almost no muzzle flash", a white dot lost against a pale barrel.
	var across := 0.12 * size * randf_range(0.85, 1.15)
	node.scale = Vector3.ONE * across

	# Crossed petals along the barrel's line, so the flash has a direction and a shape and
	# is read as fire leaving the muzzle rather than as a light on the gun. How many, and how
	# long, is the class's: a shotgun's is a fat star, a sniper's two long tongues.
	var petals: Array[MeshInstance3D] = []
	var count: int = int(profile["petals"])
	for i in count:
		var turn := PI * float(i) / float(count)
		var petal := _mesh(_quad_mesh(), _petal_mat())
		var length := 0.16 * size * float(profile["length"]) * randf_range(0.85, 1.2)
		var width := 0.05 * size
		var x := forward.cross(Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT).normalized()
		x = x.rotated(forward, turn)
		# The quad lies in its X/Y plane: Y along the barrel, X across it.
		petal.global_transform = Transform3D(Basis(x * width, forward * length, x.cross(forward)),
			muzzle.origin + forward * (length * 0.5))
		petals.append(petal)

	var fx := {"kind": &"flash", "life": 0.06, "size": across}
	var light := _flash_light(muzzle, size, profile, node)
	if light != null:
		fx["light"] = light
		fx["energy"] = light.light_energy
		fx["has_light"] = true

	_add(node, fx)
	for petal in petals:
		_add(petal, {"kind": &"petal", "life": 0.05})


## The dynamic muzzle light: short, shadowless, capped by [member max_flash_lights]. Null when off or at the cap.
func _flash_light(muzzle: Transform3D, size: float, profile: Dictionary, _parent: Node3D) -> OmniLight3D:
	var cap := max_flash_lights if first_person else mini(max_flash_lights, rules.remote_lights)
	if _lights == null or flash_light_scale <= 0.0 or _lights_live() >= cap \
			or _too_far(muzzle.origin, rules.light_distance):
		return null
	var energy := 2.2 * size * float(profile["light"]) / maxf(0.01, float(profile["size"])) * flash_light_scale
	var at := muzzle.origin - (-muzzle.basis.z.normalized()) * 0.05
	return _lights.flash(at, Color(1.0, 0.72, 0.38), energy, 4.5 * size, 0.06)


## Pack flashes draw no light of their own: ours is the one that is capped and cvar-controlled.
func _pack_flash_light(muzzle: Transform3D, size: float, weapon_class: StringName, flash: Node3D) -> void:
	for child in flash.get_children():
		if child.get("light_enable") == true:
			child.set("light_enable", false)
	var profile: Dictionary = FLASH.get(weapon_class, FLASH[AwWeaponSound.RIFLE])
	var light := _flash_light(muzzle, size * float(profile["size"]) * flash_scale, profile, self)
	if light != null:
		_add(light, {"kind": &"flashlight", "life": 0.05, "light": light,
			"energy": light.light_energy, "has_light": true})


## Weapon class to the dot-fx category `DotMuzzleFlash.size_for` sizes by.
const CLASS_CATEGORY := {
	AwWeaponSound.LIGHT: "pistol", AwWeaponSound.MAGNUM: "magnum", AwWeaponSound.SMG: "smg",
	AwWeaponSound.RIFLE: "rifle", AwWeaponSound.HEAVY: "dmr", AwWeaponSound.SNIPER: "sniper",
	AwWeaponSound.SHOTGUN: "shotgun", AwWeaponSound.MINIGUN: "lmg", AwWeaponSound.LAUNCHER: "shotgun",
	AwWeaponSound.CHARGE: "rifle",
}

## One pooled flash per size and view, moved to the muzzle for each shot. False only when dot-fx is not linked; size none, quality off and a headless server draw nothing and count as handled.
func _pack_flash(muzzle: Transform3D, size: float, weapon_class: StringName, id: StringName, first_person: bool) -> bool:
	if not ResourceLoader.exists(DotWeaponMuzzle.SCRIPT_PATH):
		return false
	var def: DotWeaponDef = catalogue.get_def(id) if catalogue != null and catalogue.has(id) else null
	var category: String = CLASS_CATEGORY.get(weapon_class, "rifle")
	var key := "%s/%s/%s" % [category, DotWeaponMuzzle.flash_name(def), first_person]
	if not _pack_flashes.has(key) or (_pack_flashes[key] != null and not is_instance_valid(_pack_flashes[key])):
		var made := DotWeaponMuzzle.attach(self, category, def, first_person, weapon_class == AwWeaponSound.SUPPRESSED)
		if made != null:
			made.top_level = true
		_pack_flashes[key] = made
	var flash: Node3D = _pack_flashes[key]
	if flash == null:
		return true
	flash.global_transform = muzzle
	flash.scale = Vector3.ONE * (first_person_flash_scale if first_person else 1.0)
	DotWeaponMuzzle.fire(flash)
	_pack_flash_light(muzzle, size, weapon_class, flash)
	return true

## Effects this shooter may keep alive at once.
func _live_cap() -> int:
	return MAX_LIVE if first_person else clampi(rules.remote_live, 2, MAX_LIVE)


func _add(node: Node3D, fx: Dictionary) -> void:
	if _live.size() >= _live_cap():
		var oldest: Dictionary = _live.pop_front()
		var old: Node3D = oldest["node"]
		if is_instance_valid(old):
			_dispose(old)

	fx["node"] = node
	fx["age"] = 0.0
	_live.append(fx)


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	if _meshes == null:
		var plain := MeshInstance3D.new()
		plain.mesh = mesh
		plain.material_override = material
		plain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plain.top_level = true
		add_child(plain)
		return plain
	var node := _meshes.acquire(mesh, Transform3D.IDENTITY, material)
	node.top_level = true
	node.transparency = 0.0
	return node


## Gives a finished effect node back: a pooled quad or light is reused, anything else is freed.
func _dispose(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is MeshInstance3D and node.get_parent() == _meshes:
		_meshes.release(node as MeshInstance3D)
	elif node is OmniLight3D and node.get_parent() == _lights:
		return  # the light pool's own timer takes it back
	else:
		node.queue_free()
