class_name AwSpawnProvider
extends RefCounted

## What a host reads from this pack (loaded by path, called by name: game-zombie-zone's zz_packs.gd and game-playground's spawn menu).
## `role_art()` is the extra a game that loads weapons by role uses (game-arena): role -> art row, so
## the game names "rifle" and never this pack. Every row is plain data; no class of another addon is named in a signature.

const CATEGORY := "Weapons"
const ZEE_PACK := "res://addons/zee_weapons/content/zee_weapon_pack.gd"
const ZEE_DAMAGE := "res://addons/zee_weapons/content/zee_weapon_damage.gd"


## Pack weapons, cloned from the host's catalogue by role so their numbers are the host's (a host without
## zee-dot-weapons gets none). Ids are `aw_<role>`; `types` is the host's damage table.
static func weapon_defs(types: Dictionary = {}) -> Array[DotWeaponDef]:
	var out: Array[DotWeaponDef] = []

	if not ResourceLoader.exists(ZEE_PACK):
		return out

	var zee: GDScript = load(ZEE_PACK)

	# Built role by role, never through the host's `weapons()`: that one calls every registered source, this pack's
	# included, and would recurse.
	if types.is_empty() and ResourceLoader.exists(ZEE_DAMAGE):
		types = (load(ZEE_DAMAGE) as GDScript).call(&"table")

	var rows := AwWeaponArt.weapon_rows()
	var by_id := {}

	for id: StringName in rows:
		var role := StringName(String(id).trim_prefix(AwWeaponArt.ID_PREFIX))
		var from := StringName(str((AwWeaponArt.EXTRAS[role] as Dictionary)["clone"])) if AwWeaponArt.EXTRAS.has(role) else role

		if not zee.has_method(from):
			continue

		if not by_id.has(from):
			by_id[from] = zee.call(from, types)

		var def := (by_id[from] as DotWeaponDef).duplicate(true) as DotWeaponDef
		def.id = id
		def.display_name = str((AwWeaponArt.EXTRAS[role] as Dictionary)["name"]) if AwWeaponArt.EXTRAS.has(role) else (by_id[from] as DotWeaponDef).name_or_id()

		var tier := StringName(str((rows[id] as Dictionary)["tier"]))

		for t: StringName in [&"sidearm", &"primary", &"heavy", &"melee", &"thrown"]:
			def.tags.erase(t)

		def.tags.append(tier)
		out.append(def)

	return out


## id -> {model, muzzle, motion, view} for [method weapon_defs]'s weapons.
static func art_rows() -> Dictionary:
	return AwWeaponArt.weapon_rows()


## role -> {model, muzzle, motion, view}: this pack's model for a game's own weapon of that role.
static func role_art() -> Dictionary:
	return AwWeaponArt.role_rows()


static func spawn_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	for id: StringName in AwWeaponArt.weapon_rows():
		out.append({
			"category": CATEGORY, "id": String(id), "name": String(id).trim_prefix(AwWeaponArt.ID_PREFIX).capitalize(),
			"icon": "", "kind": "weapon", "spawn": {"weapon": String(id)}, "cfg_hint": "",
		})

	return out


## Who made the models: rows {id, model, author, licence, url}.
static func credits() -> Array[Dictionary]:
	return [{
		"id": "arena_weapons", "model": "all", "author": "Styloo", "licence": "CC0 1.0",
		"url": "https://styloo.itch.io/guns-asset-pack",
	}]
