class_name AwAttachmentSockets
extends RefCounted

## Where each gun model takes its attachments: model name -> mount -> position in the model's space (origin at the grip, muzzle
## toward -Z), measured by tools/measure_sockets.gd. A mount a gun lacks is left out: a built-in sight or scope has no optic
## mount, a pump or a tube no underbarrel, a launcher none at all. `mag` names the model's magazine, which the magazine socket rides on.
const SOCKETS := {
	&"pistol_ph": {"muzzle": Vector3(0.0, 0.050, -0.151), "optic": Vector3(0.0, 0.060, -0.048), "side": Vector3(0.010, 0.050, -0.098), "magazine": Vector3(0.0, -0.042, -0.003), "mag": "magazine"},
	&"revolver": {"optic": Vector3(0.0, 0.132, -0.045), "side": Vector3(0.018, 0.106, -0.135)},
	&"machine_pistol": {"muzzle": Vector3(0.0, 0.128, -0.274), "optic": Vector3(0.0, 0.196, -0.023), "side": Vector3(0.032, 0.128, -0.144)},
	&"derringer": {"side": Vector3(0.016, 0.030, -0.072)},
	&"smg": {"muzzle": Vector3(0.0, -0.003, -0.143), "optic": Vector3(0.0, 0.033, 0.014), "underbarrel": Vector3(0.0, -0.022, -0.072), "side": Vector3(0.016, -0.003, -0.062), "magazine": Vector3(0.0, -0.204, 0.025), "mag": "mac10magazine_low"},
	&"carbine": {"muzzle": Vector3(0.0, 0.031, -0.548), "optic": Vector3(0.0, 0.079, -0.186), "underbarrel": Vector3(0.0, 0.021, -0.386), "side": Vector3(0.007, 0.031, -0.361), "magazine": Vector3(0.0, -0.179, -0.188), "mag": "akmagazine_low_001"},
	&"rifle": {"muzzle": Vector3(0.0, 0.029, -0.573), "optic": Vector3(0.0, 0.077, -0.077), "underbarrel": Vector3(0.0, 0.003, -0.350), "side": Vector3(0.017, 0.029, -0.316), "magazine": Vector3(0.0, -0.170, -0.190), "mag": "magazine"},
	&"bullpup": {"muzzle": Vector3(0.0, 0.093, -0.451), "underbarrel": Vector3(0.0, 0.024, -0.256), "side": Vector3(0.048, 0.093, -0.226)},
	&"battle_rifle": {"muzzle": Vector3(0.0, 0.071, -0.702), "optic": Vector3(0.0, 0.120, -0.121), "underbarrel": Vector3(0.0, 0.010, -0.442), "side": Vector3(0.034, 0.071, -0.402)},
	&"burst_rifle": {"muzzle": Vector3(0.003, 0.132, -0.498), "underbarrel": Vector3(0.003, -0.079, -0.289), "side": Vector3(0.043, 0.132, -0.257)},
	&"pump_shotgun": {"muzzle": Vector3(0.0, 0.059, -0.444), "optic": Vector3(0.0, 0.127, 0.071), "side": Vector3(0.017, 0.059, -0.178)},
	&"drum_shotgun": {"muzzle": Vector3(0.0, 0.172, -0.384), "optic": Vector3(0.0, 0.279, 0.111), "underbarrel": Vector3(0.0, 0.070, -0.162), "side": Vector3(0.081, 0.172, -0.128)},
	&"marksman": {"muzzle": Vector3(0.0, 0.090, -0.882), "underbarrel": Vector3(0.0, 0.040, -0.595), "side": Vector3(0.121, 0.090, -0.551)},
	&"lmg": {"muzzle": Vector3(0.0, 0.161, -0.795), "optic": Vector3(0.0, 0.240, -0.181), "underbarrel": Vector3(0.0, 0.120, -0.520), "side": Vector3(0.172, 0.161, -0.477)},
	&"sniper_ph": {"muzzle": Vector3(0.0, 0.078, -0.804), "underbarrel": Vector3(0.0, 0.060, -0.532), "side": Vector3(0.013, 0.078, -0.490)},
	&"grenade_launcher": {"side": Vector3(0.132, 0.101, -0.281)},
	&"plasma_rifle": {"underbarrel": Vector3(0.0, -0.052, -0.375), "side": Vector3(0.081, 0.074, -0.341)},
	&"rail_rifle": {"underbarrel": Vector3(0.0, 0.0, -0.601), "side": Vector3(0.034, 0.096, -0.566)},
}

const MOUNTS: Array[StringName] = [&"optic", &"muzzle", &"underbarrel", &"side", &"magazine"]


## The model name a model path or a model's scene file names: `res://…/carbine.glb` -> `carbine`.
static func model_key(path: String) -> StringName:
	return StringName(path.get_file().get_basename())


## The mounts [param model_path]'s gun has, in [constant MOUNTS] order; empty for a model with none.
static func mounts_of(model_path: String) -> Array[StringName]:
	var row: Dictionary = SOCKETS.get(model_key(model_path), {})
	var out: Array[StringName] = []
	for mount in MOUNTS:
		if row.has(String(mount)):
			out.append(mount)
	return out


## Adds the `socket_<mount>` nodes [param weapon] lacks, from its scene file's row; a model that ships its own sockets keeps them.
static func ensure(weapon: Node3D) -> void:
	if weapon == null:
		return
	var row: Dictionary = SOCKETS.get(model_key(weapon.scene_file_path), {})
	for mount in MOUNTS:
		if not row.has(String(mount)):
			continue
		var name := String(AwAttachmentArt.socket_name(mount))
		if weapon.find_child(name, true, false) != null:
			continue
		var socket := Node3D.new()
		socket.name = name
		var at := Transform3D(Basis.IDENTITY, row[String(mount)])
		var parent: Node3D = weapon
		if mount == DotWeaponAttachment.MOUNT_MAGAZINE:
			# On the magazine itself, so a reload hides and carries the extension with it.
			var mag := weapon.find_child(str(row.get("mag", "")), true, false) as Node3D
			if mag != null:
				parent = mag
				at = _to_weapon(mag, weapon).affine_inverse() * at
		parent.add_child(socket)
		socket.transform = at


static func _to_weapon(node: Node3D, weapon: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var up: Node = node
	while up != null and up != weapon:
		if up is Node3D:
			xf = (up as Node3D).transform * xf
		up = up.get_parent()
	return xf
