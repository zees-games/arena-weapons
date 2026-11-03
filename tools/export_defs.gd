extends SceneTree
## Writes weapons/<id>.tres and provides.json (the Workshop listing, dot-cloud docs/workshop.md) from AwWeaponPack.
## `godot --headless --path . --script res://tools/export_defs.gd`; the code table stays the source of truth.


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://weapons"))
	var defs := AwWeaponPack.weapons({}, "", false)

	for def in defs:
		var path := "res://weapons/%s.tres" % def.id
		if ResourceSaver.save(def, path) != OK:
			printerr("cannot save %s" % path)
			quit(1)
			return

	var doc := provides(defs)
	var f := FileAccess.open("res://provides.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t", false) + "\n")
	f.close()
	print("wrote %d weapon definitions and provides.json" % defs.size())
	quit(0)


const CATEGORIES: Array[Dictionary] = [
	{"slot": 1, "id": "melee", "name": "Melee"},
	{"slot": 2, "id": "sidearm", "name": "Sidearms"},
	{"slot": 3, "id": "primary", "name": "Primary"},
	{"slot": 4, "id": "heavy", "name": "Heavy"},
	{"slot": 5, "id": "thrown", "name": "Thrown"},
]


## The schema-1 `provides.json` document for [param defs].
static func provides(defs: Array[DotWeaponDef]) -> Dictionary:
	var cats: Array = []
	var by_slot := {}
	for c in CATEGORIES:
		cats.append({"id": c["id"], "name": c["name"]})
		by_slot[c["slot"]] = c["id"]

	var entries: Array = []
	for def in defs:
		entries.append({
			"kind": "weapon", "id": String(def.id), "name": def.name_or_id(), "def": "weapons/%s.tres" % String(def.id),
			"slot": def.slot, "category": by_slot.get(def.slot, ""),
			"tags": Array(def.tags).map(func(t: StringName) -> String: return String(t)), "meta": {"asset_root": "."},
		})

	return {"schema": 1, "title": "Arena Weapons", "kinds": ["weapon"], "games": "*", "categories": cats, "entries": entries}
