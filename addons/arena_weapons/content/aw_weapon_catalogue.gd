class_name AwWeaponCatalogue
extends RefCounted

## The weapons a host's rigs, world models and loot tables see: every registered source's, in the order added.
## Arena registers this pack ([AwSpawnProvider]) under plain ids and any other pack after it; the first source to bring an id keeps it.

const CHANNEL := "aw.pack"
## The tick rate durations are authored at, for a def that does not say ([member DotWeaponDef.authored_tick_rate]).
const TICK_RATE := AwWeaponPack.TICK_RATE
const ADDON := "arena_weapons"

## name -> Callable(types: Dictionary) -> Array[DotWeaponDef], in the order added.
static var _sources: Dictionary = {}


static func catalogue(damage: Dictionary = {}) -> DotWeaponCatalogue:
	var out := DotWeaponCatalogue.new()

	for def in weapons(damage):
		out.add(def)

	return out


static func weapons(types: Dictionary = {}) -> Array[DotWeaponDef]:
	var t := types if not types.is_empty() else AwWeaponDamage.table()
	var out: Array[DotWeaponDef] = []
	var taken := {}

	for name: StringName in _sources:
		var source: Callable = _sources[name]

		if not source.is_valid():
			continue

		for def: DotWeaponDef in source.call(t):
			if def == null:
				continue

			if taken.has(def.id):
				DotLog.warn(CHANNEL, "a weapon pack brought an id that is already taken", {"pack": String(name), "id": String(def.id)})
				continue

			taken[def.id] = true
			out.append(def)

	return out


## Weapons by id.
static func table(types: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}

	for def in weapons(types):
		out[def.id] = def

	return out


## Adds a pack's weapons under [param name]; the same name again replaces it. A static method's Callable, never a lambda:
## a lambda held in this static outlives its script and the process aborts on exit.
static func add_source(name: StringName, source: Callable) -> void:
	_sources[name] = source


static func remove_source(name: StringName) -> void:
	_sources.erase(name)


static func source_names() -> PackedStringArray:
	var out := PackedStringArray()

	for name: StringName in _sources:
		out.append(String(name))

	return out


static func describe_lines(types: Dictionary = {}) -> PackedStringArray:
	var built := weapons(types)
	var out := PackedStringArray(["weapon catalogue: %d weapons from %s" % [built.size(), ", ".join(source_names())]])

	for def in built:
		out.append("  %-16s slot %d  mag %d" % [String(def.id), def.slot, def.magazine])

	return out
