extends Node

## Smoke check: instantiate the viewer, select every weapon, play fire, draw and reload to the end. Exit 1 on any failure.
##   godot --headless --path . res://tools/weapon_viewer_check.tscn
## With -- <out dir> <id> it renders that weapon mid-reload to a PNG instead (needs a display).


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewer := (load("res://tools/weapon_viewer.tscn") as PackedScene).instantiate() as AwWeaponViewer
	add_child(viewer)
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var bad := 0
	if viewer.ids.size() < 20 or viewer.view == null:
		print("FAIL no weapons listed: %d" % viewer.ids.size())
		get_tree().quit(1)
		return
	if args.size() >= 2:
		viewer.select(viewer.ids.find(StringName(args[1])))
		viewer.play(&"reload")
		for i in 28:
			viewer.step(0.05)
		await get_tree().process_frame
		await get_tree().process_frame
		DirAccess.make_dir_recursive_absolute(args[0])
		get_viewport().get_texture().get_image().save_png("%s/%s_reload.png" % [args[0], args[1]])
		get_tree().quit(0)
		return
	for i in viewer.ids.size():
		viewer.select(i)
		if viewer.view.equipped() != viewer.ids[i]:
			bad += 1
			print("FAIL equip %s" % viewer.ids[i])
		viewer.play(&"fire")
		viewer.play(&"draw")
		viewer.play(&"reload")
		var n := 0
		while viewer.is_playing() and n < 400:
			viewer.step(0.05)
			n += 1
		if viewer.is_playing():
			bad += 1
			print("FAIL reload never ended %s" % viewer.ids[i])
		await get_tree().process_frame
	print("CHECK weapons=%d failed=%d" % [viewer.ids.size(), bad])
	get_tree().quit(1 if bad > 0 else 0)
