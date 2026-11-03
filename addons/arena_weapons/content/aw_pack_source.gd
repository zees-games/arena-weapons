class_name AwPackSource
extends RefCounted

## Joins another addon's weapons (a `spawn_provider.gd` with a static `weapon_defs()`) to the catalogue and art table.
## Games scan for providers and decide which to take; this is the part every game repeats, so it lives here once.

## Registers [param provider]'s weapons under [param source]. [param defs_source] is a static Callable taking the damage table and
## returning the defs (a game wraps `weapon_defs` to tag tiers); it is called on every rig, so it must return fresh defs.
static func register(source: StringName, provider: Script, defs_source: Callable) -> void:
	AwWeaponCatalogue.add_source(source, defs_source)
	AwWeaponArtTable.add_source(source, Callable(AwPackSource, &"art_of").bind(provider, defs_source))


static func unregister(source: StringName) -> void:
	AwWeaponCatalogue.remove_source(source)
	AwWeaponArtTable.remove_source(source)


## The pack's art: its `weapon_art()` when it has one, else stand-in art for each of [param defs_source]'s defs.
static func art_of(provider: Script, defs_source: Callable) -> Array[AwWeaponVisual]:
	if provider.has_method(&"weapon_art"):
		return provider.call(&"weapon_art")

	return stand_in_art(defs_source.call(AwWeaponDamage.table()), provider)


## A copy of the base gun of the same slot under each def's id, dressed from the provider's `art_rows()` so a pack that ships a model shows it.
## A tier tag decides, else the slot (a default slot of 1 is melee, so tags win where a game tiers its packs). Built fresh, never read from the table: this runs while the table is built.
static func stand_in_art(defs: Array, provider: Script) -> Array[AwWeaponVisual]:
	var out: Array[AwWeaponVisual] = []
	var rows: Dictionary = provider.call(&"art_rows") if provider.has_method(&"art_rows") else {}

	for def: DotWeaponDef in defs:
		var copy := _base_for(def)
		copy.id = def.id
		AwArtDress.apply(copy, rows.get(def.id, {}))
		out.append(copy)

	return out


static func _base_for(def: DotWeaponDef) -> AwWeaponVisual:
	if def.tags.has(&"sidearm"):
		return AwWeaponArtTable.pistol()
	if def.tags.has(&"heavy"):
		return AwWeaponArtTable.launcher()
	if def.tags.has(&"melee"):
		return AwWeaponArtTable.knife()
	if def.tags.has(&"thrown"):
		return AwWeaponArtTable.frag()
	if def.tags.has(&"primary"):
		return AwWeaponArtTable.rifle()

	match def.slot:
		AwWeaponIds.SLOT_SIDEARM:
			return AwWeaponArtTable.pistol()
		AwWeaponIds.SLOT_HEAVY:
			return AwWeaponArtTable.launcher()
		AwWeaponIds.SLOT_MELEE:
			return AwWeaponArtTable.knife()
		AwWeaponIds.SLOT_THROWN:
			return AwWeaponArtTable.frag()

	return AwWeaponArtTable.rifle()
