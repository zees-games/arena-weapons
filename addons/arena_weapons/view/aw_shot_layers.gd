class_name AwShotLayers
extends Node

## dot-audio's layered, room-aware shot (DotShotPlayer) for AwShotFx. Duck-typed by script path so a project without dot-audio, or a class with no stock shot, falls back to AwShotFx's single sound.

const CHANNEL := "aw.shot_layers"
const ROOT := "res://addons/dot_audio/"
const PLAYER := ROOT + "runtime/dot_shot_player.gd"
const MANAGER := ROOT + "runtime/dot_audio_manager.gd"
const ENCLOSURE := ROOT + "runtime/dot_audio_enclosure.gd"
const CATALOGUE := ROOT + "core/dot_audio_catalogue.gd"
const SHOT_STOCK := ROOT + "core/dot_audio_shot_stock.gd"

## Weapon classes with a stock shot; the suppressed class plays the light set, suppressed.
const STOCK_CLASSES: Array[StringName] = [&"light", &"magnum", &"smg", &"rifle", &"heavy", &"sniper", &"shotgun", &"launcher", &"minigun", &"beam", &"charge", &"swing", &"throw"]

## Each gun's own layers (tools/make_fire_sounds.py): attack, body, open-air tail and far, two variants each.
const GUN_SOUNDS := "res://addons/arena_weapons/assets/sounds/"
const GUN_LAYERS: Array[StringName] = [&"attack", &"body", &"tail_outdoor", &"far"]
const GUN_PREFIX := "aw_gun_"

## Whose stock room tails and suppressed set a gun class without a stock shot borrows.
const ROOM_FROM := {&"mpistol": &"smg", &"derringer": &"light", &"carbine": &"rifle", &"battle": &"heavy",
	&"marksman": &"heavy", &"lmg": &"rifle", &"autoshot": &"shotgun", &"grenade": &"launcher", &"rail": &"charge"}

## Steps the room probe itself from the viewport's camera, for one shared by many shooters ([AwFxPool]); off, the owner calls [method probe].
var follow_camera: bool = false

var player: Node = null
var enclosure: Node = null
var manager: Node = null

var _stock: GDScript = null
var _ready_ok := false
## Gun names (unprefixed) whose own shot registered.
var _guns: Dictionary = {}


## True when dot-audio's shot player and stock are linked in this project.
static func available() -> bool:
	for path in [PLAYER, MANAGER, ENCLOSURE, CATALOGUE, SHOT_STOCK]:
		if not ResourceLoader.exists(path):
			return false
	return true


## The stock shot class for a AwWeaponSound class, or empty for a class with none.
static func shot_class(weapon_class: StringName) -> StringName:
	if weapon_class == AwWeaponSound.SUPPRESSED:
		return &"light"
	return weapon_class if STOCK_CLASSES.has(weapon_class) else &""


## The pack gun [param weapon_id] names, a host's prefix stripped (the longest name it ends in), or empty.
static func gun_of(weapon_id: StringName) -> StringName:
	if AwWeaponPack.SOUND_CLASSES.has(weapon_id):
		return weapon_id
	var best := &""
	for gun: StringName in AwWeaponPack.SOUND_CLASSES:
		if String(weapon_id).ends_with("_" + String(gun)) and String(gun).length() > String(best).length():
			best = gun
	return best


## True when [param weapon_id]'s gun ships its own layered shot.
static func has_gun_sound(weapon_id: StringName) -> bool:
	var gun := gun_of(weapon_id)
	return gun != &"" and ResourceLoader.exists(GUN_SOUNDS + String(gun) + "/attack_0.ogg")


func is_ready() -> bool:
	return _ready_ok


## Builds the manager, player and enclosure once. False when dot-audio is missing or a stock shot fails to register.
func setup(send_bus: StringName) -> bool:
	if _ready_ok:
		return true
	if not available():
		return false
	_stock = load(SHOT_STOCK)
	manager = (load(MANAGER) as GDScript).new()
	manager.set(&"catalogue", (load(CATALOGUE) as GDScript).new())
	manager.set(&"register_as_service", false)
	manager.set(&"apply_mixer_to_buses", false)
	manager.set(&"limit_master", false)
	add_child(manager)
	var made: DotResult = manager.call(&"setup")
	if not made.ok:
		DotLog.warn(CHANNEL, "the audio manager did not start", {"cause": str(made)})
		return false
	enclosure = (load(ENCLOSURE) as GDScript).new()
	enclosure.set(&"send_bus", send_bus)
	add_child(enclosure)
	player = (load(PLAYER) as GDScript).new()
	player.set(&"manager", manager)
	player.set(&"enclosure", enclosure)
	add_child(player)
	for weapon_class in STOCK_CLASSES:
		var res: DotResult = player.call(&"register", _stock.call(&"shot", weapon_class))
		if not res.ok:
			DotLog.warn(CHANNEL, "a stock shot did not register", {"class": weapon_class, "cause": str(res)})
			return false
	for gun: StringName in AwWeaponPack.SOUND_CLASSES:
		_register_gun(gun)
	_ready_ok = true
	return true


## The stock shot of the gun's class (room tails, suppressed set, gain) with the gun's own layers over it.
func _register_gun(gun: StringName) -> void:
	if not has_gun_sound(gun):
		return
	var weapon_class: StringName = AwWeaponPack.SOUND_CLASSES[gun]
	var base: Resource = _stock.call(&"shot", ROOM_FROM.get(weapon_class, shot_class(weapon_class)))
	if base == null:
		return
	var def := base.duplicate()
	def.set(&"id", StringName(GUN_PREFIX + String(gun)))
	for layer in GUN_LAYERS:
		var paths := PackedStringArray()
		while ResourceLoader.exists("%s%s/%s_%d.ogg" % [GUN_SOUNDS, gun, layer, paths.size()]):
			paths.append("%s%s/%s_%d.ogg" % [GUN_SOUNDS, gun, layer, paths.size()])
		if not paths.is_empty():
			def.set(layer, paths)
	var res: DotResult = player.call(&"register", def)
	if res.ok:
		_guns[gun] = true
	else:
		DotLog.warn(CHANNEL, "a gun's own shot did not register", {"gun": gun, "cause": str(res)})


## True when [param weapon_id]'s own shot is registered here.
func plays_gun(weapon_id: StringName) -> bool:
	return _guns.has(gun_of(weapon_id))


## Plays a shot of [param weapon_class] at [param at], heard from [param listener]: [param weapon_id]'s own when it has
## one, else the class's stock. False when it could not, and the caller plays its single sound.
func fire(weapon_class: StringName, at: Vector3, listener: Vector3, weapon_id: StringName = &"") -> bool:
	var stock_class := shot_class(weapon_class)
	var own := plays_gun(weapon_id)
	if (stock_class == &"" and not own) or not _ready_ok:
		return false
	manager.set(&"listener_position", listener)
	var id: StringName = StringName(GUN_PREFIX + String(gun_of(weapon_id))) if own else _stock.call(&"id_of", stock_class)
	var res: DotResult = player.call(&"fire", id, at, weapon_class == AwWeaponSound.SUPPRESSED)
	return res.ok and int(res.value_or(0)) > 0


func _process(delta: float) -> void:
	if not follow_camera or not _ready_ok:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		probe(delta, camera.global_position, camera.get_world_3d().direct_space_state)


## Measures the room around [param listener] for the tail; call every frame.
func probe(delta: float, listener: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	if _ready_ok:
		enclosure.call(&"step", delta, listener, space)
