extends SceneTree
## Writes weapons/<id>.tres and provides.json (the Workshop listing, dot-cloud docs/workshop.md) from AwWeaponPack.
## `godot --headless --path . --script res://tools/export_defs.gd`; the code table stays the source of truth.
## The document comes from zee_weapons' ZeeDefExport (linked for tools and tests, never named by the pack).


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://weapons"))
	var defs := AwWeaponPack.weapons({}, "", false)

	for def in defs:
		var path := "res://weapons/%s.tres" % def.id
		if ResourceSaver.save(def, path) != OK:
			printerr("cannot save %s" % path)
			quit(1)
			return

	var doc: Dictionary = ZeeDefExport.provides(defs)
	doc["title"] = "Arena Weapons"
	var f := FileAccess.open("res://provides.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t", false) + "\n")
	f.close()
	print("wrote %d weapon definitions and provides.json" % defs.size())
	quit(0)
