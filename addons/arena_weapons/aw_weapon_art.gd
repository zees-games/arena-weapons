class_name AwWeaponArt
extends RefCounted

## The one file with a filename in it: which Styloo model each weapon role wears and how it is held.
## A model's origin is at the grip, its muzzle toward -Z, in metres (tools/bake_models.py makes them so).

const MODEL_DIR := "res://addons/arena_weapons/assets/models"
const ID_PREFIX := "aw_"

## role (a zee-dot-weapons id, the role a game's loadout names) -> {model, muzzle, kind, view}. `aim` is
## `(-sight.x, -sight.y, -0.32 - sight.z)` of the measured sight point (tools/measure_sights.py).
## `kind` is the cloned weapon's tier tag for a host that tiers by tag; `view` is plain data a rig dresses a stand-in with.
const ROLES := {
	&"pistol": {
		"model": "pistol", "muzzle": 0.076, "motion": "gun", "tier": "sidearm",
		"view": {"hold": Vector3(0.14, -0.13, -0.32), "aim": Vector3(-0.003, -0.040, -0.411), "rot": Vector3(0, 8, 22), "scale": 1.0, "zoom": 0.9},
	},
	&"smg": {
		"model": "smg", "muzzle": 0.143, "motion": "gun", "tier": "primary",
		"view": {"hold": Vector3(0.15, -0.15, -0.34), "aim": Vector3(-0.007, -0.011, -0.431), "rot": Vector3(0, 10, 28), "scale": 0.9, "zoom": 0.85},
	},
	&"carbine": {
		"model": "carbine", "muzzle": 0.548, "motion": "gun", "tier": "primary",
		"view": {"hold": Vector3(0.16, -0.16, -0.38), "aim": Vector3(-0.007, -0.054, -0.102), "rot": Vector3(0, 10, 30), "scale": 0.75, "zoom": 0.8},
	},
	&"rifle": {
		"model": "rifle", "muzzle": 0.548, "motion": "gun", "tier": "primary",
		"view": {"hold": Vector3(0.16, -0.16, -0.38), "aim": Vector3(-0.007, -0.054, -0.102), "rot": Vector3(0, 10, 30), "scale": 0.7, "zoom": 0.8},
	},
	&"shotgun": {
		"model": "pump_shotgun", "muzzle": 0.444, "motion": "gun", "tier": "primary",
		"view": {"hold": Vector3(0.16, -0.16, -0.38), "aim": Vector3(0.010, -0.066, -0.406), "rot": Vector3(0, 10, 30), "scale": 0.75, "zoom": 0.8},
	},
	&"sniper": {
		"model": "sniper_rifle", "muzzle": 0.784, "motion": "gun", "tier": "heavy",
		"view": {"hold": Vector3(0.17, -0.17, -0.42), "aim": Vector3(0.007, -0.117, -0.300), "rot": Vector3(0, 8, 24), "scale": 0.6, "zoom": 0.3, "scoped": true},
	},
	&"launcher": {
		"model": "rocket_launcher", "muzzle": 0.756, "motion": "gun", "tier": "heavy",
		"view": {"hold": Vector3(0.19, -0.21, -0.42), "aim": Vector3(-0.005, -0.117, -0.282), "rot": Vector3(0, 10, 26), "scale": 0.55, "zoom": 0.8},
	},
	&"frag": {
		"model": "frag_grenade", "muzzle": 0.0, "motion": "throw", "tier": "thrown",
		"view": {},
	},
}

## Weapons that have no zee role to skin: id -> {clone: the role whose numbers it starts from, row}.
const EXTRAS := {
	&"quad_launcher": {
		"clone": &"launcher", "name": "Quad rocket launcher",
		"row": {
			"model": "quad_rocket_launcher", "muzzle": 0.422, "motion": "gun", "tier": "heavy",
			"view": {"hold": Vector3(0.19, -0.2, -0.42), "aim": Vector3(0.009, -0.160, -0.280), "rot": Vector3(0, 10, 26), "scale": 0.5, "zoom": 0.8},
		},
	},
}

## Models shipped with no weapon yet (grenade kinds, rounds, a crate): the pack's own, for a host's pickups and effects.
const PROPS: Array[String] = ["frag_grenade_alt", "flash_grenade", "smoke_grenade", "incendiary_grenade", "ammo_box", "round_pistol", "round_rifle", "round_shell", "round_sniper", "rocket_launcher_alt"]


static func model_path(file: String) -> String:
	return MODEL_DIR.path_join(file + ".glb")


## One row with its model path resolved.
static func row_of(role: StringName) -> Dictionary:
	var src: Dictionary = (ROLES[role] as Dictionary) if ROLES.has(role) else ((EXTRAS[role] as Dictionary)["row"] as Dictionary)
	var out := src.duplicate(true)
	out["model"] = model_path(str(src["model"]))
	return out


## role -> row, for a game that dresses its own weapons by role.
static func role_rows() -> Dictionary:
	var out := {}
	for role: StringName in ROLES:
		out[role] = row_of(role)
	return out


## aw_<role> -> row, for the weapons this pack defines itself.
static func weapon_rows() -> Dictionary:
	var out := {}
	for role: StringName in ROLES:
		out[StringName(ID_PREFIX + String(role))] = row_of(role)
	for role: StringName in EXTRAS:
		out[StringName(ID_PREFIX + String(role))] = row_of(role)
	return out
