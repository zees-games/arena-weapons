class_name AwGrenadeRules
extends DotWeaponCvarRules

## Server cvars for thrown grenades (`sv_grenade_*`); the defaults are the shipped feel.

var bounce: float = 0.45
var friction: float = 0.7
var flash_seconds: float = 4.0
var smoke_seconds: float = 14.0
var fire_seconds: float = 6.0
var fire_dps: float = 12.0


func fields() -> Dictionary:
	return {
		&"bounce": [0.45, 0.0, 0.95, "Speed kept along the normal after a bounce"],
		&"friction": [0.7, 0.0, 1.0, "Speed kept along the surface after a bounce"],
		&"flash_seconds": [4.0, 0.0, 20.0, "Longest blind from a flash, looking straight at it"],
		&"smoke_seconds": [14.0, 1.0, 120.0, "How long a smoke cloud lasts"],
		&"fire_seconds": [6.0, 1.0, 60.0, "How long an incendiary burns"],
		&"fire_dps": [12.0, 0.0, 500.0, "Damage per second standing in the fire"],
	}


func prefix() -> String:
	return "sv_grenade"
