class_name AwWeaponGroups
extends RefCounted

## The download group of each weapon, for a web client that fetches only the weapons it needs
## (dot-cloud's DotCloudAddonSet.groups). groups.json at the pack's root holds one group per weapon, "weapon-<id>",
## with the model and its textures. The knife and the pistol, the default loadout, stay in no group, so a client
## that asks for none still draws them. A game that knows its loadout asks for [method groups_for] its ids; a
## client that sets no groups gets every weapon (dot-cloud's default is "*").

const PREFIX := "weapon-"
## Weapons whose model ships ungrouped, because every loadout starts with them.
const CORE: Array[StringName] = [&"knife", &"pistol"]


## The group that holds this weapon's model, or "" for a core weapon (always shipped).
static func group_of(id: StringName) -> String:
	return "" if CORE.has(id) or not AwWeaponArt.WEAPONS.has(id) else PREFIX + String(id)


## The groups a client needs to draw these weapons: no duplicates, no core weapons, an unknown id skipped.
static func groups_for(ids: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		var g := group_of(StringName(id))
		if g != "" and not out.has(g):
			out.append(g)
	return out


## Every group this pack defines, for a client that wants all the weapons.
static func all_groups() -> PackedStringArray:
	return groups_for(AwWeaponArt.WEAPONS.keys())
