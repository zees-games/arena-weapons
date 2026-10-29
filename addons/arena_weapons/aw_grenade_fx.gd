class_name AwGrenadeFx
extends RefCounted

## Client visuals of the utility grenades through dot-fx: smoke and fire clouds, and the blind flash the player's flash settings cap.
## The cloud scenes are the game's art, so [method add_defs] takes the folder that holds them.

const SMOKE_ID := &"smoke_cloud"
const FIRE_ID := &"fire_cloud"
const BLIND_ID := &"blind_flash"
const BLIND_MIN_MS := 250
const BLIND_MAX_MS := 10000


## The three defs; [param fx_dir] holds `smoke_cloud.tscn` and `fire_cloud.tscn`.
static func defs(fx_dir: String) -> Array[DotFxDef]:
	var out: Array[DotFxDef] = []
	for id: StringName in [SMOKE_ID, FIRE_ID]:
		var cloud := DotFxDef.new()
		cloud.id = id
		cloud.scene_path = "%s/%s.tscn" % [fx_dir, id]
		cloud.lifetime_ms = 30000
		cloud.cost = 10
		cloud.priority = 80
		cloud.max_distance = 120.0
		out.append(cloud)

	var blind := DotFxDef.new()
	blind.id = BLIND_ID
	blind.kind = DotFxDef.Kind.SCREEN
	blind.flash_peak = 1.0
	blind.flash_decay_ms = 2500
	out.append(blind)
	return out


static func add_defs(catalogue: DotFxCatalogue, fx_dir: String) -> void:
	for def in defs(fx_dir):
		catalogue.add(def)


## How long the white takes to fade for a blind of [param seconds].
static func flash_decay_ms(seconds: float) -> int:
	return clampi(int(seconds * 1000.0), BLIND_MIN_MS, BLIND_MAX_MS)


## Shows an [signal AwUtilityZones.effect] on [param fx]; a blind only for [param own_id]. Returns the cloud, or null.
static func show(fx: DotFxManager, tree: SceneTree, info: Dictionary, own_id: int) -> Node:
	if fx == null or fx.catalogue == null:
		return null

	var seconds := float(info["seconds"])
	match int(info["fx"]):
		AwUtilityZones.Fx.BLIND:
			var def := fx.catalogue.find(BLIND_ID)
			if int(info["victim"]) == own_id and def != null:
				# The decay is set per flash: it is how long this blind lasts.
				def.flash_decay_ms = flash_decay_ms(seconds)
				var _shown := fx.flash(BLIND_ID)
		AwUtilityZones.Fx.SMOKE, AwUtilityZones.Fx.FIRE:
			var id := SMOKE_ID if int(info["fx"]) == AwUtilityZones.Fx.SMOKE else FIRE_ID
			var scale := Vector3.ONE * float(info["radius"]) * 0.5
			var cloud := fx.spawn(id, Transform3D(Basis.IDENTITY.scaled(scale), info["position"]))
			if cloud != null and tree != null:
				tree.create_timer(seconds).timeout.connect(func() -> void:
					if is_instance_valid(cloud):
						cloud.queue_free())
			return cloud
	return null
