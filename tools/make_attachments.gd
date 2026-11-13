extends SceneTree
## Builds the attachment models (own work, primitives only) into addons/arena_weapons/assets/attachments/<id>.tscn.
## Each is drawn on its gun's `socket_<mount>` with no offset: a muzzle part runs toward -Z from its origin, an optic sits on +Y,
## an underbarrel part hangs toward -Y, a side part sits toward +X, a magazine extension hangs below the magazine.
## An optic's `<id>_glass` mesh is what the sight line runs through (aw_attachment_dress.gd).
## godot --headless --path . --script res://tools/make_attachments.gd

const OUT := "res://addons/arena_weapons/assets/attachments/"

## id -> parts: [name, "box"|"tube", size (box: x y z; tube: radius, length along Z, unused), position, material].
const PARTS := {
	"red_dot": [
		["base", "box", Vector3(0.024, 0.008, 0.046), Vector3(0, 0.004, 0), "metal"],
		["hood", "box", Vector3(0.030, 0.030, 0.006), Vector3(0, 0.024, -0.018), "metal"],
		["post", "box", Vector3(0.006, 0.018, 0.020), Vector3(0.012, 0.017, -0.006), "metal"],
		["red_dot_glass", "box", Vector3(0.022, 0.020, 0.002), Vector3(0, 0.025, -0.016), "glass"],
	],
	"holo": [
		["base", "box", Vector3(0.030, 0.010, 0.070), Vector3(0, 0.005, 0), "metal"],
		["frame_l", "box", Vector3(0.004, 0.034, 0.050), Vector3(-0.017, 0.027, -0.006), "metal"],
		["frame_r", "box", Vector3(0.004, 0.034, 0.050), Vector3(0.017, 0.027, -0.006), "metal"],
		["frame_top", "box", Vector3(0.038, 0.004, 0.050), Vector3(0, 0.046, -0.006), "metal"],
		["holo_glass", "box", Vector3(0.030, 0.030, 0.002), Vector3(0, 0.027, -0.028), "glass"],
	],
	"prism_3x": [
		["base", "box", Vector3(0.030, 0.010, 0.060), Vector3(0, 0.005, 0), "metal"],
		["body", "box", Vector3(0.040, 0.040, 0.070), Vector3(0, 0.032, -0.004), "metal"],
		["prism_3x_glass", "box", Vector3(0.030, 0.026, 0.074), Vector3(0, 0.034, -0.004), "glass"],
	],
	"scope_6x": [
		["ring_rear", "box", Vector3(0.026, 0.040, 0.014), Vector3(0, 0.020, 0.030), "metal"],
		["ring_front", "box", Vector3(0.026, 0.040, 0.014), Vector3(0, 0.020, -0.050), "metal"],
		["tube", "tube", Vector3(0.016, 0.200, 0), Vector3(0, 0.046, -0.010), "metal"],
		["bell", "tube", Vector3(0.022, 0.050, 0), Vector3(0, 0.046, -0.120), "metal"],
		["eyepiece", "tube", Vector3(0.019, 0.040, 0), Vector3(0, 0.046, 0.100), "metal"],
		["scope_6x_glass", "tube", Vector3(0.014, 0.260, 0), Vector3(0, 0.046, -0.010), "glass"],
	],
	"suppressor": [
		["can", "tube", Vector3(0.017, 0.150, 0), Vector3(0, 0, -0.080), "metal"],
		["collar", "tube", Vector3(0.012, 0.012, 0), Vector3(0, 0, -0.004), "metal"],
	],
	"compensator": [
		["body", "tube", Vector3(0.012, 0.050, 0), Vector3(0, 0, -0.025), "metal"],
		["port_l", "box", Vector3(0.026, 0.006, 0.008), Vector3(0, 0.008, -0.020), "dark"],
		["port_r", "box", Vector3(0.026, 0.006, 0.008), Vector3(0, 0.008, -0.036), "dark"],
	],
	"vertical_grip": [
		["clamp", "box", Vector3(0.022, 0.012, 0.040), Vector3(0, -0.006, 0), "metal"],
		["grip", "tube", Vector3(0.014, 0.095, 0), Vector3(0, -0.058, 0), "polymer", Vector3(90, 0, 0)],
	],
	"angled_grip": [
		["clamp", "box", Vector3(0.022, 0.012, 0.070), Vector3(0, -0.006, 0), "metal"],
		["ramp", "box", Vector3(0.020, 0.030, 0.064), Vector3(0, -0.022, 0.004), "polymer", Vector3(-28, 0, 0)],
	],
	"laser": [
		["clamp", "box", Vector3(0.008, 0.020, 0.030), Vector3(0.004, 0, 0), "metal"],
		["box", "box", Vector3(0.020, 0.024, 0.056), Vector3(0.018, 0, -0.008), "polymer"],
		["emitter", "tube", Vector3(0.005, 0.004, 0), Vector3(0.018, 0.004, -0.037), "laser"],
	],
	"extended_mag": [
		["extension", "box", Vector3(0.030, 0.050, 0.034), Vector3(0, -0.025, 0), "polymer"],
		["plate", "box", Vector3(0.034, 0.006, 0.040), Vector3(0, -0.053, 0), "metal"],
	],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made := 0
	for id: String in PARTS:
		var root := Node3D.new()
		root.name = id
		for part: Array in PARTS[id]:
			var mi := MeshInstance3D.new()
			mi.name = part[0]
			mi.mesh = _mesh(part[1], part[2])
			mi.material_override = _material(part[4])
			mi.position = part[3]
			if part.size() > 5:
				var turn: Vector3 = part[5]
				mi.rotation_degrees = turn
			root.add_child(mi)
			mi.owner = root
		var scene := PackedScene.new()
		scene.pack(root)
		var err := ResourceSaver.save(scene, OUT + id + ".tscn")
		root.free()
		if err != OK:
			printerr("make_attachments: %s failed (%d)" % [id, err])
			quit(1)
			return
		made += 1
	print("make_attachments: %d models" % made)
	quit()


static func _mesh(kind: String, size: Vector3) -> Mesh:
	if kind == "tube":
		var c := CylinderMesh.new()
		c.top_radius = size.x
		c.bottom_radius = size.x
		c.height = size.y
		c.radial_segments = 12
		c.rings = 1
		# A cylinder stands on Y; bake a turn so the tube runs along Z.
		var arrays := c.get_mesh_arrays()
		var turn := Basis(Vector3.RIGHT, PI / 2.0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			verts[i] = turn * verts[i]
			normals[i] = turn * normals[i]
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return out
	var b := BoxMesh.new()
	b.size = size
	return b


static var _materials: Dictionary = {}


static func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"metal":
			m.albedo_color = Color(0.11, 0.11, 0.12)
			m.metallic = 0.7
			m.roughness = 0.4
		"dark":
			m.albedo_color = Color(0.02, 0.02, 0.02)
			m.roughness = 0.8
		"polymer":
			m.albedo_color = Color(0.16, 0.15, 0.13)
			m.roughness = 0.75
		"glass":
			m.albedo_color = Color(0.35, 0.55, 0.6, 0.18)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic_specular = 1.0
			m.roughness = 0.05
		"laser":
			m.albedo_color = Color(1.0, 0.1, 0.05)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.1, 0.05)
			m.emission_energy_multiplier = 4.0
	_materials[kind] = m
	return m
