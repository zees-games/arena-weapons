class_name AwWeaponPack
extends RefCounted

## Arena's whole gun set as [DotWeaponDef]s: this pack's own numbers, built from dot-weapon alone, so a host needs no other weapon pack.
## Durations are ticks at [constant TICK_RATE]; every number can be overridden per weapon in `cfg/addons/arena_weapons/weapon/<id>.yml`.

const TICK_RATE := 64
const ADDON := "arena_weapons"

const HITSCAN := "res://addons/dot_weapon/behaviour/dot_weapon_hitscan.gd"
const PROJECTILE := "res://addons/dot_weapon/behaviour/dot_weapon_projectile.gd"
const THROWN := "res://addons/dot_weapon/behaviour/dot_weapon_thrown.gd"
const BEAM := "res://addons/dot_weapon/behaviour/dot_weapon_beam.gd"
const MELEE := "res://addons/dot_weapon/behaviour/dot_weapon_melee.gd"
## Optional: a host with a view rig gets its kick numbers into each gun's params, so a profile can tune them.
const POSE_SCRIPT := "res://addons/zee_weapons/view/zee_weapon_pose.gd"

const SLOT_MELEE := 1
const SLOT_SIDEARM := 2
const SLOT_PRIMARY := 3
const SLOT_HEAVY := 4
const SLOT_THROWN := 5

const AMMO_LIGHT := &"darts_light"
const AMMO_HEAVY := &"darts_heavy"
const AMMO_SHELL := &"shells"
const AMMO_BELT := &"belt"
const AMMO_CELL := &"cells"
const AMMO_ORDNANCE := &"ordnance"
const AMMO_GRENADE := &"grenades"

const DART := &"dart"
const BLAST := &"blast"
const STRIKE := &"strike"
const ENERGY := &"energy"

const DEATH_REACTION := &"death_reaction"
const DEATH_POWER := &"death_power"

## Every weapon id, in wire order for a host that numbers them; append only.
const IDS: Array[StringName] = [
	&"knife",
	&"pistol", &"revolver", &"machine_pistol", &"derringer",
	&"smg", &"carbine", &"rifle", &"bullpup", &"battle_rifle", &"burst_rifle",
	&"shotgun", &"drum_shotgun", &"marksman", &"lmg",
	&"sniper", &"minigun", &"launcher", &"quad_launcher", &"grenade_launcher", &"beamer", &"charge_rifle",
	&"frag", &"sticky", &"flash", &"smoke", &"incendiary",
]

## Carry weight in kg.
const WEIGHTS := {
	&"knife": 0.4, &"pistol": 1.0, &"revolver": 1.2, &"machine_pistol": 1.4, &"derringer": 0.5,
	&"smg": 2.8, &"carbine": 3.4, &"rifle": 3.8, &"bullpup": 4.2, &"battle_rifle": 4.4, &"burst_rifle": 3.6,
	&"shotgun": 3.6, &"drum_shotgun": 4.6, &"marksman": 5.0, &"lmg": 7.0,
	&"sniper": 6.0, &"minigun": 9.0, &"launcher": 6.5, &"quad_launcher": 8.0, &"grenade_launcher": 5.5,
	&"beamer": 6.0, &"charge_rifle": 6.0, &"frag": 0.4, &"sticky": 0.4, &"flash": 0.3, &"smoke": 0.3, &"incendiary": 0.4,
}

## The host's game id for the game tier (`cfg/game/<game>/weapon`); empty skips it.
static var game: String = ""
## A mounted pack's `cfg` root, the weakest root.
static var pack_cfg_root: String = ""
## Roots under [member pack_cfg_root]; empty means the profile set's defaults. Tests set it.
static var base_roots: PackedStringArray = PackedStringArray()
## Profiles that failed to load in the last [method weapons].
static var errors: PackedStringArray = PackedStringArray()
static var _kick: Dictionary = {}
static var _kick_read := false


## Every weapon, ids prefixed with [param prefix] (a host mixing packs passes `aw_`), tuned by the profiles.
static func weapons(types: Dictionary = {}, prefix: String = "", profiled: bool = true) -> Array[DotWeaponDef]:
	var out: Array[DotWeaponDef] = []

	for id in IDS:
		var def: DotWeaponDef = Callable(AwWeaponPack, id).call(types)
		def.weight = float(WEIGHTS.get(id, def.weight))
		out.append(def)

	if profiled:
		var set := DotWeaponProfiles.overlay_set(ADDON, game, pack_cfg_root, base_roots)
		errors = DotWeaponProfiles.tune(out, set)

	if prefix != "":
		for def in out:
			def.id = StringName(prefix + String(def.id))

	return out


static func rpm_ticks(rpm: float) -> int:
	return maxi(1, int(round(60.0 / rpm * float(TICK_RATE))))


static func sec_ticks(seconds: float) -> int:
	return maxi(0, int(round(seconds * float(TICK_RATE))))


static func knife(t: Dictionary = {}) -> DotWeaponDef:
	var def := _melee(t, &"knife", "Knife", 45.0, 1.9, rpm_ticks(150.0), 24.0, 3)
	def.deploy_ticks = sec_ticks(0.15)
	def.holster_ticks = sec_ticks(0.1)
	return def


static func pistol(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"pistol", "Pistol", SLOT_SIDEARM, DotWeaponDef.Fire.SEMI, rpm_ticks(380.0), [&"sidearm"], AMMO_LIGHT, 15, 60, 1.6)
	def.deploy_ticks = sec_ticks(0.22)
	def.holster_ticks = sec_ticks(0.16)
	var b := _ballistics(t, 20.0)
	_spread(b, 0.35, 1.5, 4.0, 0.5)
	_bloom(b, 0.3, 2.6)
	_recoil(b, 0.5, 0.15)
	b.max_range = 120.0
	def.tuning = b
	return def


static func revolver(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"revolver", "Revolver", SLOT_SIDEARM, DotWeaponDef.Fire.SEMI, rpm_ticks(150.0), [&"sidearm"], AMMO_LIGHT, 6, 36, 2.4)
	def.deploy_ticks = sec_ticks(0.3)
	def.holster_ticks = sec_ticks(0.2)
	_art(def, "revolver")
	var b := _ballistics(t, 45.0)
	_spread(b, 0.2, 2.0, 5.0, 0.3)
	_bloom(b, 1.2, 4.0)
	_recoil(b, 2.2, 0.3)
	b.max_range = 140.0
	def.tuning = b
	def.params[DEATH_POWER] = 0.5
	return def


static func machine_pistol(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"machine_pistol", "Machine Pistol", SLOT_SIDEARM, DotWeaponDef.Fire.AUTO, rpm_ticks(900.0), [&"sidearm", &"automatic"], AMMO_LIGHT, 25, 100, 1.9)
	def.deploy_ticks = sec_ticks(0.25)
	def.holster_ticks = sec_ticks(0.18)
	_art(def, "smg")
	var b := _ballistics(t, 13.0)
	_spread(b, 0.9, 3.2, 6.0, 0.7)
	_bloom(b, 0.32, 5.5, 10.0)
	_recoil(b, 0.3, 0.18)
	b.max_range = 70.0
	def.tuning = b
	return def


static func derringer(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"derringer", "Derringer", SLOT_SIDEARM, DotWeaponDef.Fire.SEMI, rpm_ticks(90.0), [&"sidearm"], AMMO_LIGHT, 2, 12, 2.0)
	def.deploy_ticks = sec_ticks(0.18)
	def.holster_ticks = sec_ticks(0.12)
	_art(def, "break")
	var b := _ballistics(t, 62.0)
	_spread(b, 2.2, 5.0, 6.0, 2.0)
	_recoil(b, 3.2, 0.2)
	b.max_range = 18.0
	def.tuning = b
	return def


static func smg(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"smg", "SMG", SLOT_PRIMARY, DotWeaponDef.Fire.AUTO, rpm_ticks(820.0), [&"primary", &"automatic"], AMMO_LIGHT, 30, 120, 1.8)
	def.deploy_ticks = sec_ticks(0.26)
	def.holster_ticks = sec_ticks(0.2)
	_art(def, "smg")
	var b := _ballistics(t, 16.0)
	_spread(b, 0.7, 2.4, 5.0, 0.6)
	_bloom(b, 0.26, 4.5, 9.0)
	_recoil(b, 0.26, 0.14)
	b.max_range = 80.0
	def.tuning = b
	return def


static func carbine(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"carbine", "Carbine", SLOT_PRIMARY, DotWeaponDef.Fire.AUTO, rpm_ticks(660.0), [&"primary", &"automatic"], AMMO_HEAVY, 24, 96, 2.0)
	def.deploy_ticks = sec_ticks(0.3)
	def.holster_ticks = sec_ticks(0.22)
	var b := _ballistics(t, 21.0)
	_spread(b, 0.5, 2.1, 4.5, 0.55)
	_bloom(b, 0.28, 4.2, 9.0)
	_recoil(b, 0.34, 0.14)
	b.max_range = 140.0
	def.tuning = b
	return def


static func rifle(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"rifle", "Assault Rifle", SLOT_PRIMARY, DotWeaponDef.Fire.AUTO, rpm_ticks(600.0), [&"primary", &"automatic"], AMMO_HEAVY, 30, 120, 2.2)
	def.deploy_ticks = sec_ticks(0.32)
	def.holster_ticks = sec_ticks(0.24)
	var b := _ballistics(t, 23.0)
	_spread(b, 0.45, 2.2, 4.8, 0.5)
	_bloom(b, 0.27, 4.6, 8.5)
	_recoil(b, 0.36, 0.15)
	b.max_range = 180.0
	def.tuning = b
	return def


static func bullpup(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"bullpup", "Bullpup", SLOT_PRIMARY, DotWeaponDef.Fire.AUTO, rpm_ticks(700.0), [&"primary", &"automatic"], AMMO_HEAVY, 32, 128, 2.4)
	def.deploy_ticks = sec_ticks(0.34)
	def.holster_ticks = sec_ticks(0.26)
	var b := _ballistics(t, 20.0)
	_spread(b, 0.5, 1.0, 3.4, 0.45)
	_bloom(b, 0.3, 4.0)
	_recoil(b, 0.32, 0.2)
	b.max_range = 150.0
	def.tuning = b
	return def


static func battle_rifle(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"battle_rifle", "Battle Rifle", SLOT_PRIMARY, DotWeaponDef.Fire.SEMI, rpm_ticks(300.0), [&"primary"], AMMO_HEAVY, 20, 80, 2.3)
	def.deploy_ticks = sec_ticks(0.36)
	def.holster_ticks = sec_ticks(0.26)
	var b := _ballistics(t, 36.0)
	_spread(b, 0.25, 2.6, 5.0, 0.4)
	_bloom(b, 0.7, 4.0)
	_recoil(b, 1.1, 0.2)
	b.max_range = 200.0
	def.tuning = b
	return def


static func burst_rifle(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"burst_rifle", "Burst Rifle", SLOT_PRIMARY, DotWeaponDef.Fire.BURST, rpm_ticks(240.0), [&"primary"], AMMO_HEAVY, 30, 90, 2.1)
	def.burst_count = 3
	def.burst_interval_ticks = 3
	def.deploy_ticks = sec_ticks(0.3)
	def.holster_ticks = sec_ticks(0.22)
	var b := _ballistics(t, 24.0)
	_spread(b, 0.3, 1.8, 4.5, 0.3)
	_bloom(b, 0.2, 2.0)
	_recoil(b, 0.55, 0.12)
	b.max_range = 160.0
	def.tuning = b
	return def


static func shotgun(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"shotgun", "Shotgun", SLOT_PRIMARY, DotWeaponDef.Fire.SEMI, rpm_ticks(75.0), [&"primary"], AMMO_SHELL, 8, 32, 0.42)
	def.reload_per_round = true
	def.reload_start_ticks = sec_ticks(0.3)
	def.deploy_ticks = sec_ticks(0.38)
	def.holster_ticks = sec_ticks(0.28)
	_art(def, "tube")
	var b := _ballistics(t, 12.0)
	b.pellets = 9
	b.fixed_pattern = true
	_spread(b, 4.2, 0.5, 4.2, 4.2)
	_recoil(b, 2.4, 0.2)
	b.max_range = 26.0
	def.tuning = b
	def.params[DEATH_POWER] = 0.6
	return def


static func drum_shotgun(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"drum_shotgun", "Drum Shotgun", SLOT_PRIMARY, DotWeaponDef.Fire.AUTO, rpm_ticks(190.0), [&"primary", &"automatic"], AMMO_SHELL, 20, 40, 4.0)
	def.deploy_ticks = sec_ticks(0.42)
	def.holster_ticks = sec_ticks(0.3)
	var b := _ballistics(t, 8.0)
	b.pellets = 7
	b.fixed_pattern = true
	_spread(b, 5.4, 1.2, 5.4, 5.4)
	_recoil(b, 1.1, 0.2)
	b.max_range = 20.0
	def.tuning = b
	def.params[DEATH_POWER] = 0.6
	return def


static func marksman(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"marksman", "Marksman Rifle", SLOT_PRIMARY, DotWeaponDef.Fire.SEMI, rpm_ticks(180.0), [&"primary", &"scoped"], AMMO_HEAVY, 10, 40, 2.6)
	def.deploy_ticks = sec_ticks(0.45)
	def.holster_ticks = sec_ticks(0.3)
	_art(def, "bolt")
	var b := _ballistics(t, 58.0)
	_spread(b, 0.08, 4.5, 8.0, 0.3)
	_bloom(b, 1.4, 6.0)
	_recoil(b, 2.0, 0.2)
	b.max_range = 400.0
	def.tuning = b
	return def


## Belt-fed and box-fed: a long magazine, a long reload, and a gun that is slow to bring round.
static func lmg(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"lmg", "Light Machine Gun", SLOT_PRIMARY, DotWeaponDef.Fire.AUTO, rpm_ticks(720.0), [&"primary", &"automatic"], AMMO_HEAVY, 100, 200, 4.6)
	def.deploy_ticks = sec_ticks(0.7)
	def.holster_ticks = sec_ticks(0.5)
	_art(def, "heavy")
	var b := _ballistics(t, 21.0)
	_spread(b, 0.9, 3.8, 6.5, 0.6)
	_bloom(b, 0.18, 3.6, 6.0)
	_recoil(b, 0.3, 0.2)
	b.max_range = 170.0
	def.tuning = b
	return def


static func sniper(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"sniper", "Sniper Rifle", SLOT_HEAVY, DotWeaponDef.Fire.SEMI, rpm_ticks(45.0), [&"heavy", &"scoped"], AMMO_HEAVY, 5, 25, 3.2)
	def.deploy_ticks = sec_ticks(0.7)
	def.holster_ticks = sec_ticks(0.5)
	_art(def, "bolt")
	var b := _ballistics(t, 118.0)
	_spread(b, 0.0, 8.0, 14.0, 0.0)
	_recoil(b, 4.0, 0.2)
	b.max_range = 1000.0
	def.tuning = b
	def.params[DEATH_REACTION] = &"power_launch"
	def.params[DEATH_POWER] = 1.0
	return def


## No magazine: dot-weapon reads zero as "feeds from the reserve", so it never reloads and simply runs dry.
static func minigun(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"minigun", "Minigun", SLOT_HEAVY, DotWeaponDef.Fire.AUTO, rpm_ticks(1100.0), [&"heavy", &"automatic"], AMMO_BELT, 0, 200, 0.0)
	def.reserve_max = 400
	def.auto_reload = false
	def.deploy_ticks = sec_ticks(1.1)
	def.holster_ticks = sec_ticks(0.8)
	var b := _ballistics(t, 11.0)
	_spread(b, 2.4, 4.5, 7.0, 2.0)
	_bloom(b, 0.08, 2.0, 4.0)
	_recoil(b, 0.12, 0.1)
	b.max_range = 110.0
	def.tuning = b
	return def


static func launcher(t: Dictionary = {}) -> DotWeaponDef:
	var def := _rocket(t, &"launcher", "Rocket Launcher", rpm_ticks(70.0), 4, 12, 2.8)
	return def


## Four tubes fired as fast as the trigger: the whole load in a second, then a long reload.
static func quad_launcher(t: Dictionary = {}) -> DotWeaponDef:
	var def := _rocket(t, &"quad_launcher", "Quad Rocket Launcher", rpm_ticks(240.0), 4, 8, 4.2)
	var b := def.tuning as DotWeaponBallistics
	b.damage = 24.0
	b.splash_damage = 62.0
	b.splash_radius = 3.6
	b.spread = 1.2
	return def


## Lobbed shells that drop: thrown at a corner rather than at a person.
static func grenade_launcher(t: Dictionary = {}) -> DotWeaponDef:
	var def := _rocket(t, &"grenade_launcher", "Grenade Launcher", rpm_ticks(90.0), 6, 18, 3.4)
	_art(def, "revolver")
	var b := def.tuning as DotWeaponBallistics
	b.damage = 20.0
	b.speed = 28.0
	b.min_speed = 28.0
	b.gravity_scale = 1.0
	b.splash_radius = 4.0
	b.splash_damage = 95.0
	b.max_range = 120.0
	return def


## Damage while held on a target and nothing for a flick: it ramps from 45% to full over half a second.
static func beamer(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"beamer", "Plasma Beamer", SLOT_HEAVY, DotWeaponDef.Fire.HOLD, 4, [&"heavy", &"energy"], AMMO_CELL, 0, 260, 0.0)
	def.behaviour_path = BEAM
	def.reserve_max = 520
	def.auto_reload = false
	def.deploy_ticks = sec_ticks(0.4)
	def.holster_ticks = sec_ticks(0.3)
	def.params.merge({&"ramp_ticks": sec_ticks(0.5), &"ramp_from": 0.45})
	var b := _ballistics(t, 9.0, ENERGY)
	_spread(b, 0.0, 0.0, 0.0, 0.0)
	_recoil(b, 0.0, 0.0)
	b.max_range = 40.0
	def.tuning = b
	return def


## Hold to charge, release to fire; refuses to release below a third of a charge.
static func charge_rifle(t: Dictionary = {}) -> DotWeaponDef:
	var def := _gun(&"charge_rifle", "Rail Rifle", SLOT_HEAVY, DotWeaponDef.Fire.CHARGE, rpm_ticks(90.0), [&"heavy", &"energy", &"scoped"], AMMO_CELL, 4, 24, 2.6)
	def.charge_ticks = sec_ticks(1.1)
	def.charge_requires_min = true
	def.min_charge = 0.34
	def.deploy_ticks = sec_ticks(0.5)
	def.holster_ticks = sec_ticks(0.36)
	_art(def, "cell")
	var b := _ballistics(t, 105.0, ENERGY)
	b.min_charge_damage = 0.33
	_spread(b, 0.0, 3.0, 6.0, 0.0)
	_recoil(b, 2.6, 0.2)
	b.max_range = 500.0
	def.tuning = b
	def.params[DEATH_POWER] = 0.9
	return def


static func frag(t: Dictionary = {}) -> DotWeaponDef:
	var def := _thrown(t, &"frag", "Frag Grenade", 3.0)
	var b := def.tuning as DotWeaponBallistics
	b.splash_radius = 5.2
	b.splash_damage = 115.0
	b.speed = 19.0
	b.min_speed = 19.0
	b.gravity_scale = 1.0
	def.params[&"kind"] = &"frag"
	return def


## Sticks where it lands, so it is thrown at a place; a shorter fuse because it cannot be kicked away.
static func sticky(t: Dictionary = {}) -> DotWeaponDef:
	var def := _thrown(t, &"sticky", "Sticky Grenade", 2.2)
	var b := def.tuning as DotWeaponBallistics
	b.splash_radius = 4.0
	b.splash_damage = 135.0
	b.speed = 22.0
	b.min_speed = 22.0
	b.gravity_scale = 0.8
	def.params[&"sticks"] = true
	def.params[&"kind"] = &"frag"
	return def


## Blinds whoever faces it, scaled by distance; no damage.
static func flash(t: Dictionary = {}) -> DotWeaponDef:
	var def := _thrown(t, &"flash", "Flashbang", 1.6)
	def.params[&"kind"] = &"flash"
	def.params[&"effect_radius"] = 12.0
	return def


## A cloud that blocks sight for a while; no damage.
static func smoke(t: Dictionary = {}) -> DotWeaponDef:
	var def := _thrown(t, &"smoke", "Smoke Grenade", 1.2)
	def.params[&"kind"] = &"smoke"
	def.params[&"effect_radius"] = 4.5
	return def


## Bursts on first contact and leaves a fire that burns whoever stands in it.
static func incendiary(t: Dictionary = {}) -> DotWeaponDef:
	var def := _thrown(t, &"incendiary", "Incendiary Grenade", 3.0)
	var b := def.tuning as DotWeaponBallistics
	b.splash_radius = 3.0
	b.splash_damage = 25.0
	b.speed = 18.0
	b.min_speed = 18.0
	def.params[&"kind"] = &"incendiary"
	def.params[&"explode_on_impact"] = true
	def.params[&"effect_radius"] = 3.5
	return def


static func _gun(id: StringName, name: String, slot: int, fire: DotWeaponDef.Fire, interval: int, tags: Array, ammo: StringName, magazine: int, reserve: int, reload_sec: float) -> DotWeaponDef:
	var def := DotWeaponDef.new()
	def.authored_tick_rate = TICK_RATE
	def.id = id
	def.display_name = name
	def.behaviour_path = HITSCAN
	def.slot = slot
	def.fire_mode = fire
	def.use_interval_ticks = interval
	def.cost_per_use = 1
	def.tags.assign(tags)
	def.ammo_type = ammo
	def.magazine = magazine
	def.reserve = reserve
	def.reserve_max = reserve * 2
	def.reload_ticks = sec_ticks(reload_sec)
	def.params = {&"bash_damage": 42.0, &"bash_reach": 1.9, &"bash_cooldown_ticks": sec_ticks(0.8)}
	def.params.merge(_kick_defaults())
	return def


static func _rocket(t: Dictionary, id: StringName, name: String, interval: int, magazine: int, reserve: int, reload_sec: float) -> DotWeaponDef:
	var def := _gun(id, name, SLOT_HEAVY, DotWeaponDef.Fire.SEMI, interval, [&"heavy", &"explosive"], AMMO_ORDNANCE, magazine, reserve, reload_sec)
	def.behaviour_path = PROJECTILE
	def.deploy_ticks = sec_ticks(0.5)
	def.holster_ticks = sec_ticks(0.34)
	var b := _ballistics(t, 32.0, BLAST)
	b.splash_type = _type(t, BLAST)
	b.speed = 44.0
	b.min_speed = 44.0
	b.min_charge_damage = 1.0
	b.gravity_scale = 0.25
	b.radius = 0.2
	b.life_ticks = sec_ticks(5.0)
	b.splash_radius = 4.5
	b.splash_damage = 88.0
	b.splash_hurts_owner = true
	_spread(b, 0.0, 0.0, 0.0, 0.0)
	_recoil(b, 3.0, 0.2)
	b.max_range = 260.0
	def.tuning = b
	def.params[DEATH_REACTION] = &"power_launch"
	def.params[DEATH_POWER] = 1.0
	return def


static func _melee(t: Dictionary, id: StringName, name: String, damage: float, reach: float, interval: int, arc: float, rays: int) -> DotWeaponDef:
	var def := DotWeaponDef.new()
	def.authored_tick_rate = TICK_RATE
	def.id = id
	def.display_name = name
	def.behaviour_path = MELEE
	def.slot = SLOT_MELEE
	def.fire_mode = DotWeaponDef.Fire.SEMI
	def.use_interval_ticks = interval
	def.tags = [&"melee"]
	def.ammo_type = &""
	def.magazine = 0
	def.cost_per_use = 0
	def.auto_reload = false
	def.reload_ticks = 0
	def.deploy_ticks = sec_ticks(0.25)
	def.holster_ticks = sec_ticks(0.18)
	def.params = {&"arc_degrees": arc, &"rays": rays}
	var b := _ballistics(t, damage, STRIKE)
	b.max_range = reach
	_spread(b, 0.0, 0.0, 0.0, 0.0)
	_recoil(b, 0.0, 0.0)
	def.tuning = b
	return def


## The fuse starts when the pin comes out, not on release: cooking past it kills the thrower.
static func _thrown(t: Dictionary, id: StringName, name: String, fuse_seconds: float) -> DotWeaponDef:
	var def := DotWeaponDef.new()
	def.authored_tick_rate = TICK_RATE
	def.id = id
	def.display_name = name
	def.behaviour_path = THROWN
	def.slot = SLOT_THROWN
	def.fire_mode = DotWeaponDef.Fire.CHARGE
	def.use_interval_ticks = sec_ticks(1.0)
	def.tags = [&"thrown", &"explosive"]
	def.ammo_type = AMMO_GRENADE
	def.magazine = 0
	def.reserve = 2
	def.reserve_max = 4
	def.cost_per_use = 1
	def.auto_reload = false
	def.reload_ticks = 0
	def.charge_ticks = sec_ticks(fuse_seconds)
	def.charge_requires_min = false
	def.deploy_ticks = sec_ticks(0.35)
	def.holster_ticks = sec_ticks(0.25)
	def.params = {&"fuse_ticks": sec_ticks(fuse_seconds), &"speed_scales_with_cook": false}
	var b := _ballistics(t, 0.0, BLAST)
	b.radius = 0.12
	b.life_ticks = sec_ticks(12.0)
	b.max_range = 100.0
	b.splash_hurts_owner = true
	def.tuning = b
	return def


static func _ballistics(t: Dictionary, damage: float, kind: StringName = DART) -> DotWeaponBallistics:
	var b := DotWeaponBallistics.new()
	b.damage = damage
	b.damage_type = _type(t, kind)
	return b


## The host's damage type of [param kind]; a bare one of that id when the host hands none.
static func _type(t: Dictionary, kind: StringName) -> DotDamageType:
	var found: Variant = t.get(kind)
	return found if found is DotDamageType else DotDamageType.make(kind, String(kind).capitalize())


static func _spread(b: DotWeaponBallistics, still: float, moving: float, airborne: float, crouched: float) -> void:
	b.spread = still
	b.spread_moving = moving
	b.spread_airborne = airborne
	b.spread_crouched = crouched


static func _bloom(b: DotWeaponBallistics, per_shot: float, most: float, recovery_per_sec: float = -1.0) -> void:
	b.bloom = per_shot
	b.bloom_max = most
	if recovery_per_sec >= 0.0:
		b.bloom_recovery = recovery_per_sec / float(TICK_RATE)


static func _recoil(b: DotWeaponBallistics, pitch: float, yaw: float) -> void:
	b.recoil_pitch = pitch
	b.recoil_yaw = yaw


## The reload animation class a view rig plays (`params.art.reload_class`).
static func _art(def: DotWeaponDef, reload_class: String) -> void:
	def.params[&"art"] = {"reload_class": reload_class}


static func _kick_defaults() -> Dictionary:
	if not _kick_read:
		_kick_read = true
		if ResourceLoader.exists(POSE_SCRIPT):
			var tunables: Variant = (load(POSE_SCRIPT) as GDScript).get_script_constant_map().get("Tunables")
			if tunables is GDScript and (tunables as GDScript).has_method(&"kick_defaults"):
				_kick = (tunables as GDScript).call(&"kick_defaults")
	return _kick.duplicate()
