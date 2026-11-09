class_name AwWeaponViewer
extends Node3D

## Interactive viewer for the pack's weapons: the real first-person view model (hands, magazine, reload parts) with an orbit camera.
## Keys: Left/Right or Q/E weapon, 1 fire, 2 reload, 3 draw, 4 aim, 5 swing/throw, H hands, mouse drag orbits, wheel zooms, R resets the camera.
## Run: godot --path . res://tools/weapon_viewer.tscn

signal weapon_changed(id: StringName)

const RELOAD_SECONDS := 2.6
const DRAW_SECONDS := 0.6

var view: AwViewModel = null
var ids: Array[StringName] = []
var index := -1
var yaw := 0.6
var pitch := 0.25
var distance := 0.9
var focus := Vector3(0.0, 0.0, -0.4)
## Seconds into the running reload or draw; negative when none runs.
var _reload_t := -1.0
var _draw_t := -1.0
var _camera: Camera3D = null
var _label: Label = null
var _picker: OptionButton = null
var _drag := false


func _ready() -> void:
	_build_world()
	_build_ui()
	view = AwViewModel.new()
	view.show_arms = true
	view.wall_overlay = false
	add_child(view)
	for id: StringName in AwWeaponArt.WEAPONS:
		ids.append(id)
	for id in ids:
		_picker.add_item(str(id))
	if not ids.is_empty():
		select(0)


## Equips weapon number [param i] (wrapping) and refits the camera on it.
func select(i: int) -> void:
	if ids.is_empty():
		return
	index = posmod(i, ids.size())
	_reload_t = -1.0
	_draw_t = -1.0
	view.on_reload(0.0)
	view.equip(art_of(ids[index]))
	view.advance(0.02)
	_picker.select(index)
	_refit()
	_update_label()
	weapon_changed.emit(ids[index])


## The pack's art for [param id], dressed with its table row the way a host's table is.
static func art_of(id: StringName) -> AwWeaponVisual:
	var art := AwWeaponVisual.make(id)
	AwArtDress.apply(art, AwWeaponArt.row_of(id))
	return art


func cycle(delta: int) -> void:
	select(index + delta)


## Starts animation [param what]: fire, reload, draw, aim, swing.
func play(what: StringName) -> void:
	if view == null or index < 0:
		return
	match what:
		&"fire":
			view.on_fired(Vector2(1.0, 0.2))
		&"reload":
			view.on_reload_begin(0, 30)
			_reload_t = 0.0
		&"draw":
			_draw_t = 0.0
			view.on_deploy(0.0)
		&"aim":
			view.aim(not view.is_aim_held())
		&"swing":
			view.on_swing()


func is_playing() -> bool:
	return _reload_t >= 0.0 or _draw_t >= 0.0


## Advances animations by [param delta]; _process calls it, the smoke check calls it with a fixed step.
func step(delta: float) -> void:
	if view == null:
		return
	if _reload_t >= 0.0:
		_reload_t += delta
		view.on_reload(minf(_reload_t / RELOAD_SECONDS, 1.0))
		if _reload_t >= RELOAD_SECONDS:
			view.on_reload(0.0)
			_reload_t = -1.0
	if _draw_t >= 0.0:
		_draw_t += delta
		view.on_deploy(minf(_draw_t / DRAW_SECONDS, 1.0))
		if _draw_t >= DRAW_SECONDS:
			_draw_t = -1.0
	view.advance(delta)
	_place_camera()


func _process(delta: float) -> void:
	step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(0.2, distance * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(4.0, distance / 0.9)
	elif event is InputEventMouseMotion and _drag:
		var rel := (event as InputEventMouseMotion).relative
		yaw -= rel.x * 0.008
		pitch = clampf(pitch + rel.y * 0.008, -1.4, 1.4)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_RIGHT, KEY_E: cycle(1)
			KEY_LEFT, KEY_Q: cycle(-1)
			KEY_1: play(&"fire")
			KEY_2: play(&"reload")
			KEY_3: play(&"draw")
			KEY_4: play(&"aim")
			KEY_5: play(&"swing")
			KEY_H: view.show_arms = not view.show_arms
			KEY_R: _refit()


## Camera on the equipped model's bounds.
func _refit() -> void:
	var box := _bounds(view)
	if box.size != Vector3.ZERO:
		focus = box.get_center()
		distance = clampf(box.size.length() * 1.4, 0.4, 3.0)
	_place_camera()


func _place_camera() -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_camera.position = focus + dir * distance
	_camera.look_at(focus)


static func _bounds(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _update_label() -> void:
	_label.text = "%d/%d  %s   [Q/E] weapon  [1] fire  [2] reload  [3] draw  [4] aim  [5] swing  [H] hands  [R] reset  drag: orbit" % [
		index + 1, ids.size(), ids[index]]


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.58)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.4
	add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.current = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 8)
	layer.add_child(bar)
	_picker = OptionButton.new()
	_picker.item_selected.connect(select)
	bar.add_child(_picker)
	for pair in [["Fire", &"fire"], ["Reload", &"reload"], ["Draw", &"draw"], ["Aim", &"aim"], ["Swing", &"swing"]]:
		var b := Button.new()
		b.text = pair[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(play.bind(pair[1]))
		bar.add_child(b)
	_label = Label.new()
	_label.position = Vector2(8, 44)
	layer.add_child(_label)
