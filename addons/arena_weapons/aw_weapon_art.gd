class_name AwWeaponArt
extends RefCounted

## The one file with a filename in it: which model each of [AwWeaponPack]'s weapons wears and how it is held.
## A model's origin is at the grip, its muzzle toward -Z, in metres (tools/bake_models.py makes them so).

const MODEL_DIR := "res://addons/arena_weapons/assets/models"
const ID_PREFIX := "aw_"

const _SIDEARM := {"hold": Vector3(0.14, -0.13, -0.32), "rot": Vector3(0, 8, 22), "scale": 1.0, "zoom": 0.9}
const _LONG := {"hold": Vector3(0.16, -0.16, -0.38), "rot": Vector3(0, 10, 30), "scale": 0.7, "zoom": 0.8}
const _HEAVY := {"hold": Vector3(0.19, -0.21, -0.42), "rot": Vector3(0, 10, 26), "scale": 0.55, "zoom": 0.8}

## weapon id -> {model, muzzle, motion, tier, view}. `aim` is tools/measure_sights.py's: the sight 0.32 ahead of the eye,
## further out when the stock would otherwise fill the screen. `view` without hold/rot/scale/zoom takes its tier's.
const WEAPONS := {
	&"knife": {"model": "knife", "muzzle": 0.0, "motion": "melee", "tier": "melee", "view": {}},
	&"pistol": {"model": "pistol", "muzzle": 0.076, "tier": "sidearm", "view": {"aim": Vector3(0.000, -0.065, -0.411)}},
	&"revolver": {"model": "revolver", "muzzle": 0.231, "tier": "sidearm", "view": {"scale": 0.8, "aim": Vector3(0.011, -0.132, -0.306)}},
	&"machine_pistol": {"model": "machine_pistol", "muzzle": 0.274, "tier": "sidearm", "view": {"scale": 0.8, "aim": Vector3(0.007, -0.168, -0.309)}},
	&"derringer": {"model": "derringer", "muzzle": 0.120, "tier": "sidearm", "view": {"aim": Vector3(0.000, -0.061, -0.305)}},
	&"smg": {"model": "smg", "muzzle": 0.143, "tier": "primary", "view": {"aim": Vector3(-0.007, -0.036, -0.431), "scale": 0.9, "zoom": 0.85}},
	&"carbine": {"model": "carbine", "muzzle": 0.548, "tier": "primary", "view": {"aim": Vector3(-0.007, -0.079, -0.227), "scale": 0.75}},
	&"rifle": {"model": "rifle", "muzzle": 0.548, "tier": "primary", "view": {"aim": Vector3(-0.007, -0.079, -0.456)}},
	&"bullpup": {"model": "bullpup", "muzzle": 0.451, "tier": "primary", "view": {"sight": "red_dot", "aim": Vector3(0.000, -0.278, -0.451)}},
	&"battle_rifle": {"model": "battle_rifle", "muzzle": 0.702, "tier": "primary", "view": {"aim": Vector3(0.015, -0.140, -0.450)}},
	&"burst_rifle": {"model": "burst_rifle", "muzzle": 0.498, "tier": "primary", "view": {"sight": "red_dot", "aim": Vector3(-0.002, -0.278, -0.456)}},
	&"shotgun": {"model": "pump_shotgun", "muzzle": 0.444, "tier": "primary", "view": {"aim": Vector3(0.010, -0.091, -0.594), "scale": 0.75}},
	&"drum_shotgun": {"model": "drum_shotgun", "muzzle": 0.384, "tier": "primary", "view": {"aim": Vector3(0.020, -0.284, -0.619), "scale": 0.45}},
	&"marksman": {"model": "marksman", "muzzle": 0.882, "tier": "primary", "view": {"aim": Vector3(0.013, -0.254, -0.372), "zoom": 0.45, "scoped": true}},
	&"lmg": {"model": "lmg", "muzzle": 0.790, "tier": "primary", "view": {"aim": Vector3(0.000, -0.352, -0.414)}},
	&"sniper": {"model": "sniper_rifle", "muzzle": 0.784, "tier": "heavy", "view": {"hold": Vector3(0.17, -0.17, -0.42), "aim": Vector3(0.007, -0.142, -0.491), "rot": Vector3(0, 8, 24), "scale": 0.6, "zoom": 0.3, "scoped": true}},
	&"minigun": {"model": "minigun", "muzzle": 0.766, "tier": "heavy", "view": {"aim": Vector3(0.000, -0.273, -0.342)}},
	&"launcher": {"model": "rocket_launcher", "muzzle": 0.756, "tier": "heavy", "view": {"aim": Vector3(-0.005, -0.142, -0.577)}},
	&"quad_launcher": {"model": "quad_rocket_launcher", "muzzle": 0.422, "tier": "heavy", "view": {"hold": Vector3(0.19, -0.2, -0.42), "aim": Vector3(0.009, -0.185, -0.581), "scale": 0.35}},
	&"grenade_launcher": {"model": "grenade_launcher", "muzzle": 0.522, "tier": "heavy", "view": {"sight": "red_dot", "aim": Vector3(0.000, -0.330, -0.431)}},
	&"beamer": {"model": "plasma_rifle", "muzzle": 0.597, "tier": "heavy", "view": {"sight": "red_dot", "aim": Vector3(0.000, -0.274, -0.407)}},
	&"charge_rifle": {"model": "rail_rifle", "muzzle": 0.830, "tier": "heavy", "view": {"aim": Vector3(0.016, -0.296, -0.474), "zoom": 0.4, "scoped": true}},
	&"frag": {"model": "frag_grenade", "muzzle": 0.0, "motion": "throw", "tier": "thrown", "view": {}},
	&"sticky": {"model": "frag_grenade_alt", "muzzle": 0.0, "motion": "throw", "tier": "thrown", "view": {}},
	&"flash": {"model": "flash_grenade", "muzzle": 0.0, "motion": "throw", "tier": "thrown", "view": {}},
	&"smoke": {"model": "smoke_grenade", "muzzle": 0.0, "motion": "throw", "tier": "thrown", "view": {}},
	&"incendiary": {"model": "incendiary_grenade", "muzzle": 0.0, "motion": "throw", "tier": "thrown", "view": {}},
}

## Equipment and props with no weapon behind them yet: the pack's own, for a host's pickups and effects.
const PROPS: Array[String] = ["ammo_box", "round_pistol", "round_rifle", "round_shell", "round_sniper", "rocket_launcher_alt"]

## Who made each model ([method AwSpawnProvider.credits]); CREDITS.md says the same for people.
const CREDITS: Array[Dictionary] = [
	{"id": "styloo", "model": "pistol, smg, rifle, carbine, sniper_rifle, pump_shotgun, rocket launchers, grenades, ammo_box, rounds", "author": "Styloo", "licence": "CC0-1.0", "url": "https://styloo.itch.io/guns-asset-pack"},
	{"id": "polyy-1", "model": "revolver, machine_pistol, derringer, bullpup, battle_rifle, burst_rifle, drum_shotgun, marksman", "author": "Polyy", "licence": "CC0-1.0", "url": "https://polyyai.itch.io/3d-low-poly-guns-pack"},
	{"id": "polyy-2", "model": "minigun, lmg, grenade_launcher, plasma_rifle, rail_rifle", "author": "Polyy", "licence": "CC0-1.0", "url": "https://polyyai.itch.io/3d-low-poly-guns-pack-2"},
	{"id": "vinrax-knife", "model": "knife", "author": "Vinrax", "licence": "CC0-1.0", "url": "https://opengameart.org/content/knife-low-poly"},
]

## The zee role each tier dresses when a host skins its own weapons by role.
const ROLE_OF := [&"pistol", &"smg", &"carbine", &"rifle", &"shotgun", &"sniper", &"launcher", &"frag"]


static func model_path(file: String) -> String:
	return MODEL_DIR.path_join(file + ".glb")


## One row with its model path resolved and its tier's hold filled in.
static func row_of(id: StringName) -> Dictionary:
	var src: Dictionary = WEAPONS[id]
	var out := src.duplicate(true)
	out["model"] = model_path(str(src["model"]))
	out["motion"] = str(src.get("motion", "gun"))

	if out["motion"] == "gun":
		var tier: Dictionary = _SIDEARM if src["tier"] == "sidearm" else (_HEAVY if src["tier"] == "heavy" else _LONG)
		var view: Dictionary = tier.duplicate()
		view.merge(src["view"] as Dictionary, true)
		out["view"] = view

	return out


## role -> row, for a host that dresses its own weapons by role.
static func role_rows() -> Dictionary:
	var out := {}
	for role: StringName in ROLE_OF:
		out[role] = row_of(role)
	return out


## <prefix><id> -> row, for the weapons this pack defines ([method AwWeaponPack.weapons] with the same prefix).
static func weapon_rows(prefix: String = ID_PREFIX) -> Dictionary:
	var out := {}
	for id: StringName in WEAPONS:
		out[StringName(prefix + String(id))] = row_of(id)
	return out
