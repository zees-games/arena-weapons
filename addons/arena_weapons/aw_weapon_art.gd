class_name AwWeaponArt
extends RefCounted

## The one file with a filename in it: which model each of [AwWeaponPack]'s weapons wears and how it is held.
## A model's origin is at the grip, its muzzle toward -Z, in metres (tools/bake_models.py makes them so).

const MODEL_DIR := "res://addons/arena_weapons/assets/models"
const ID_PREFIX := "aw_"

const _SIDEARM := {"hold": Vector3(0.14, -0.13, -0.32), "rot": Vector3(0, 8, 22), "scale": 1.0, "zoom": 0.9}
const _LONG := {"hold": Vector3(0.16, -0.16, -0.38), "rot": Vector3(0, 10, 30), "scale": 0.7, "zoom": 0.8}
const _HEAVY := {"hold": Vector3(0.19, -0.21, -0.42), "rot": Vector3(0, 10, 26), "scale": 0.55, "zoom": 0.8}

## weapon id -> {model, muzzle, motion, tier, reload, view}; `reload` is the view model's reload phases (style and parts). `aim` is tools/measure_sights.py's: the sight 0.32 ahead of the eye,
## further out when the stock would otherwise fill the screen. `view` without hold/rot/scale/zoom takes its tier's.
const WEAPONS := {
	&"knife": {"model": "knife", "muzzle": 0.0, "motion": "melee", "tier": "melee", "view": {}},
	&"pistol": {"model": "pistol", "muzzle": 0.076, "tier": "sidearm", "reload": {"style": "pistol"}, "support_grip": Vector3(-0.03, -0.06, 0.02), "hand_scale": 0.4, "forearm_scale": 0.85, "view": {"hold": Vector3(0.12, -0.10, -0.36), "scale": 0.8, "aim": Vector3(0.000, -0.079, -0.405)}},
	&"revolver": {"model": "revolver", "muzzle": 0.231, "tier": "sidearm", "reload": {"style": "revolver"}, "view": {"scale": 0.8, "aim": Vector3(0.000, -0.150, -0.350)}},
	&"machine_pistol": {"model": "machine_pistol", "muzzle": 0.274, "tier": "sidearm", "reload": {"style": "pistol"}, "support_grip": Vector3(-0.03, -0.06, 0.05), "hand_scale": 0.4, "view": {"scale": 0.8, "aim": Vector3(0.000, -0.184, -0.309)}},
	&"derringer": {"model": "derringer", "muzzle": 0.120, "tier": "sidearm", "reload": {"style": "launcher", "round": "round", "case": "casing"}, "view": {"aim": Vector3(0.000, -0.074, -0.330)}},
	&"smg": {"model": "smg", "muzzle": 0.143, "tier": "primary", "reload": {"style": "magazine", "anchors": {"below": [0.0, -0.11, -0.06], "pouch": [-0.07, -0.17, -0.16]}}, "view": {"aim": Vector3(0.000, -0.048, -0.400), "scale": 0.9, "zoom": 0.85}},
	&"carbine": {"model": "carbine", "muzzle": 0.548, "tier": "primary", "reload": {"style": "magazine", "anchors": {"below": [0.0, -0.12, -0.12], "pouch": [-0.07, -0.2, -0.2]}}, "view": {"aim": Vector3(-0.007, -0.079, -0.227), "scale": 0.75}},
	&"rifle": {"model": "rifle", "muzzle": 0.548, "tier": "primary", "reload": {"style": "magazine", "anchors": {"below": [0.0, -0.12, -0.12], "pouch": [-0.07, -0.2, -0.2]}}, "view": {"aim": Vector3(-0.007, -0.079, -0.456)}},
	&"bullpup": {"model": "bullpup", "muzzle": 0.451, "tier": "primary", "reload": {"style": "magazine", "anchors": {"below": [0.0, -0.11, -0.06], "pouch": [-0.07, -0.17, -0.16]}}, "view": {"sight": "red_dot", "aim": Vector3(0.000, -0.278, -0.451)}},
	&"battle_rifle": {"model": "battle_rifle", "muzzle": 0.702, "fore_along": 0.45, "tier": "primary", "reload": {"style": "magazine", "anchors": {"below": [0.0, -0.11, -0.06], "pouch": [-0.07, -0.17, -0.16]}}, "view": {"aim": Vector3(0.000, -0.162, -0.450)}},
	&"burst_rifle": {"model": "burst_rifle", "muzzle": 0.498, "tier": "primary", "reload": {"style": "magazine", "anchors": {"below": [0.0, -0.11, -0.06], "pouch": [-0.07, -0.17, -0.16]}}, "view": {"sight": "red_dot", "aim": Vector3(-0.002, -0.278, -0.456)}},
	&"shotgun": {"model": "pump_shotgun", "muzzle": 0.444, "tier": "primary", "reload": {"style": "tube", "anchors": {"pouch": [-0.05, -0.15, -0.20], "near": [-0.02, -0.08, -0.16]}}, "view": {"aim": Vector3(0.000, -0.111, -0.594), "scale": 0.75}},
	&"drum_shotgun": {"model": "drum_shotgun", "muzzle": 0.384, "fore_along": 0.32, "tier": "primary", "reload": {"style": "magazine", "anchors": {"below": [0.0, -0.11, -0.06], "pouch": [-0.07, -0.17, -0.16]}}, "view": {"aim": Vector3(0.020, -0.284, -0.619), "scale": 0.45}},
	&"marksman": {"model": "marksman", "muzzle": 0.882, "fore_along": 0.53, "tier": "primary", "reload": {"style": "magazine", "anchors": {"below": [0.0, -0.2, -0.1], "pouch": [-0.1, -0.28, -0.2]}}, "view": {"aim": Vector3(0.013, -0.254, -0.372), "zoom": 0.45, "scoped": true}},
	&"lmg": {"model": "lmg", "muzzle": 0.790, "fore_along": 0.42, "belt_feed": true, "tier": "primary", "reload": {"style": "belt"}, "view": {"aim": Vector3(0.000, -0.384, -0.414), "scale": 0.36}},
	&"sniper": {"model": "sniper_rifle", "muzzle": 0.784, "fore_along": 0.42, "tier": "heavy", "reload": {"style": "bolt", "anchors": {"pouch": [-0.04, -0.14, -0.20], "near": [-0.02, -0.08, -0.14]}}, "view": {"hold": Vector3(0.17, -0.17, -0.42), "aim": Vector3(0.007, -0.142, -0.491), "rot": Vector3(0, 8, 24), "scale": 0.6, "zoom": 0.3, "scoped": true}},
	&"minigun": {"model": "minigun", "muzzle": 0.766, "fore_along": 0.32, "belt_feed": true, "tier": "heavy", "reload": {"style": "belt"}, "view": {"aim": Vector3(0.000, -0.273, -0.342)}},
	&"launcher": {"model": "rocket_launcher", "muzzle": 0.756, "fore_along": 0.32, "tier": "heavy", "reload": {"style": "launcher", "round": "rocket", "eject": "none", "anchors": {"breech": [0.0, 0.08, 0.3], "pouch": [-0.08, -0.28, 0.15], "near": [-0.04, -0.15, 0.2]}}, "view": {"aim": Vector3(-0.005, -0.142, -0.577)}},
	&"quad_launcher": {"model": "quad_rocket_launcher", "muzzle": 0.422, "fore_along": 0.47, "tier": "heavy", "reload": {"style": "launcher", "round": "rocket", "eject": "none", "anchors": {"breech": [0.0, 0.1, 0.25], "pouch": [-0.1, -0.35, 0.15], "near": [-0.05, -0.2, 0.2]}}, "view": {"hold": Vector3(0.19, -0.2, -0.42), "aim": Vector3(0.000, -0.209, -0.600), "scale": 0.35}},
	&"grenade_launcher": {"model": "grenade_launcher", "muzzle": 0.522, "fore_along": 0.31, "fore_up": 0.3, "tier": "heavy", "reload": {"style": "launcher", "anchors": {"breech": [0.0, 0.1, -0.05], "pouch": [-0.08, -0.25, 0.0], "near": [-0.04, -0.15, 0.0]}}, "view": {"sight": "red_dot", "rot": Vector3(0, 4, 2), "hold": Vector3(0.17, -0.22, -0.5), "scale": 0.42, "aim": Vector3(0.000, -0.330, -0.431)}},
	&"beamer": {"model": "plasma_rifle", "muzzle": 0.597, "fore_along": 0.32, "tier": "heavy", "reload": {"style": "cell"}, "view": {"sight": "red_dot", "aim": Vector3(0.000, -0.274, -0.407)}},
	&"charge_rifle": {"model": "rail_rifle", "muzzle": 0.830, "fore_along": 0.34, "wall": {"wall_max": 0.65}, "tier": "heavy", "reload": {"style": "cell", "anchors": {"well": [0.0, 0.0, -0.1], "below": [0.0, -0.2, -0.1], "pouch": [-0.08, -0.25, -0.2]}}, "view": {"aim": Vector3(0.016, -0.296, -0.474), "zoom": 0.4, "scale": 0.8, "scoped": true}},
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

## The view rig's wall response per tier (zee `wall_*` keys, into each def's `params.ads`): a long gun needs a deeper retreat than a pistol to clear a wall.
const WALL_BY_TIER := {
	"melee": {"wall_reach": 0.6},
	"primary": {"wall_max": 0.7, "wall_push": 1.2},
	"heavy": {"wall_max": 0.8, "wall_push": 1.3},
}


## The wall keys for [param id]'s tier, over-ridden by the row's own `wall`; empty for the sidearm, whose defaults suit it.
static func wall_row(id: StringName) -> Dictionary:
	if not WEAPONS.has(id):
		return {}
	var out: Dictionary = (WALL_BY_TIER.get(str(WEAPONS[id]["tier"]), {}) as Dictionary).duplicate()
	out.merge(WEAPONS[id].get("wall", {}) as Dictionary, true)
	return out


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
		# The models are baked with the origin at the grip, so the palm goes there rather than at a guess from the bounds.
		out["grip_socket"] = Vector3.ZERO
		if src["tier"] == "sidearm" and not out.has("hand_scale"):
			out["hand_scale"] = 0.36
		if src["tier"] == "sidearm" and not out.has("forearm_scale"):
			out["forearm_scale"] = 0.85

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
