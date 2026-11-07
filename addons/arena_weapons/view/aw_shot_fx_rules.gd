class_name AwShotFxRules
extends DotWeaponCvarRules

## Client cvars (`cl_shotfx_*`) for what other people's shots cost: a bot's or another player's report, flash, tracer
## and impact. The local player's own gun is never limited by these. One shared instance: [member AwShotFx.rules].

## Most effects one other shooter keeps alive at once (the local gun keeps [constant AwShotFx.MAX_LIVE]).
var remote_live: int = 16
## Most flash lights one other shooter holds at once.
var remote_lights: int = 1
## Another shooter's flash carries no light when the camera is farther than this many metres; 0 never drops it.
var light_distance: float = 30.0
## Another shooter's flash, tracer and impacts are not drawn when the camera is farther than this many metres; 0 never culls.
var fx_distance: float = 120.0
## Most report voices one other shooter holds at once (a new report cuts its oldest).
var remote_voices: int = 2
## Another shooter's sounds are not played when the camera is farther than this many metres; 0 never culls.
var voice_distance: float = 200.0


func fields() -> Dictionary:
	return {
		&"remote_live": [16, 2, 48, "Most effects one other shooter keeps alive at once"],
		&"remote_lights": [1, 0, 4, "Most flash lights one other shooter holds at once"],
		&"light_distance": [30.0, 0.0, 500.0, "Another shooter's flash has no light beyond this many metres from the camera; 0 never"],
		&"fx_distance": [120.0, 0.0, 1000.0, "Another shooter's flash, tracer and impacts are not drawn beyond this many metres; 0 never"],
		&"remote_voices": [2, 1, 6, "Most report voices one other shooter holds at once"],
		&"voice_distance": [200.0, 0.0, 1000.0, "Another shooter's sounds are not played beyond this many metres; 0 never"],
	}


func prefix() -> String:
	return "cl_shotfx"
