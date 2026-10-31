class_name AwSpawnProvider
extends RefCounted

## What a host reads from this pack (loaded by path, called by name: game-arena's roles, game-zombie-zone's zz_packs.gd).
## The weapons are this pack's own ([AwWeaponPack]); ids are `aw_<id>` in a host that mixes packs, plain in one that
## takes this pack as its whole set ([method set_id_prefix] with ""). Every row is plain data; no other weapon pack is named.

const CATEGORY := "Weapons"
const DEFAULT_PREFIX := "aw_"

static var id_prefix: String = DEFAULT_PREFIX


## A host whose whole gun set this pack is passes "", so its ids are `rifle`, not `aw_rifle`. Call before [method weapon_defs].
static func set_id_prefix(prefix: String) -> void:
	id_prefix = prefix


## Every weapon of the pack, fresh each call; `types` is the host's damage table (kind -> DotDamageType).
static func weapon_defs(types: Dictionary = {}) -> Array[DotWeaponDef]:
	return AwWeaponPack.weapons(types, id_prefix)


## id -> {model, muzzle, motion, view} for [method weapon_defs]'s weapons.
static func art_rows() -> Dictionary:
	return AwWeaponArt.weapon_rows(id_prefix)


## weapon id -> sound class for [method weapon_defs]'s guns; a host passes each pair to its weapon-sound table.
static func sound_classes() -> Dictionary:
	return AwWeaponPack.sound_classes(id_prefix)


## role -> row, for a host that dresses its own weapons by role. Empty while the pack owns the plain ids: nothing else to dress.
static func role_art() -> Dictionary:
	return AwWeaponArt.role_rows() if id_prefix != "" else {}


static func spawn_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names := {}

	for def in AwWeaponPack.weapons({}, "", false):
		names[def.id] = def.display_name

	for id: StringName in AwWeaponPack.IDS:
		var full := id_prefix + String(id)
		out.append({
			"category": CATEGORY, "id": full, "name": str(names.get(id, String(id).capitalize())),
			"icon": "", "kind": "weapon", "spawn": {"weapon": full}, "cfg_hint": "cfg/addons/arena_weapons/weapon/%s.yml" % id,
		})

	return out


## Who made the models: rows {id, model, author, licence, url}.
static func credits() -> Array[Dictionary]:
	return AwWeaponArt.CREDITS
