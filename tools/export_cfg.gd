extends SceneTree
## Writes cfg/addons/arena_weapons/weapon/<id>.yml from AwWeaponPack's builders: every stat of every weapon, for an
## operator to copy into a game's cfg/ and tune. `godot --headless --path . --script res://tools/export_cfg.gd`


func _initialize() -> void:
	var dir := "res://cfg/addons/%s/weapon" % AwWeaponPack.ADDON
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var n := 0

	for def in AwWeaponPack.weapons({}, "", false):
		var f := FileAccess.open("%s/%s.yml" % [dir, def.id], FileAccess.WRITE)
		if f == null:
			printerr("cannot write %s" % def.id)
			quit(1)
			return
		f.store_string(DotWeaponProfiles.to_yaml(def, "Arena Weapons"))
		n += 1

	print("wrote %d weapon profiles" % n)
	quit(0)
