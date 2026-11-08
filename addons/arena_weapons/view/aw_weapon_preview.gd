class_name AwWeaponPreview
extends Node

## A weapon's model rendered once into a smooth texture (MSAA, transparent) for a menu card, cached per id. Add it to
## the tree; a weapon with no model returns null so the caller keeps its sprite.
##
## [method texture] on an id nobody warmed builds that id its own viewport (fine for the odd one; 27 of them at once is
## 144 MB of MSAA render targets and a long first frame the first time B is pressed). [method warm] is the way to do many:
## ONE viewport, one model a frame, each picture read back into a plain [ImageTexture] and the viewport freed at the end.

## Emitted when [method warm] has resolved every id it was given.
signal warmed()

## Texture size in pixels; set before the first [method texture] call.
@export var size := Vector2i(512, 256)
@export var msaa: Viewport.MSAA = Viewport.MSAA_4X

var _textures: Dictionary = {}
var _queue: Array = []
var _port: SubViewport = null
var _camera: Camera3D = null
var _model: Node3D = null
var _rendering: StringName = &""
var _ports_made := 0
var _warm_usec := 0


## The cached picture of [param id]'s model, or null when it has no art.
func texture(id: StringName) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var art := AwWeaponArtTable.get_art(id)
	var made: Texture2D = null
	if art != null and art.model_path != "":
		made = _build(art)
	_textures[id] = made
	return made


## How many ids have been resolved, null results included.
func cached_count() -> int:
	return _textures.size()


## How many viewports this has made in all (one per [method texture] on a cold id, one per [method warm] run).
func ports_made() -> int:
	return _ports_made


## CPU milliseconds [method warm] has spent in its frame ticks (the readback included, the GPU's draw not).
func warm_msec() -> float:
	return _warm_usec / 1000.0


## Whether [method warm] still has ids to resolve.
func is_warming() -> bool:
	return not _queue.is_empty() or _rendering != &""


## Resolves [param ids] (every weapon with art when empty) one a frame through a single shared viewport, so the first
## [method texture] of each is a cache hit. Without a display (headless draws nothing to read back) each id gets the
## viewport [method texture] makes instead, a frame at a time. Emits [signal warmed] at the end.
func warm(ids: Array = []) -> void:
	var list: Array = ids if not ids.is_empty() else AwWeaponArtTable.table().keys()
	for id: Variant in list:
		var key := StringName(id)
		if not _textures.has(key) and not _queue.has(key):
			_queue.append(key)
	if _queue.is_empty() and _rendering == &"":
		warmed.emit()
		return
	if not get_tree().process_frame.is_connected(_tick):
		get_tree().process_frame.connect(_tick)


func _tick() -> void:
	var began := Time.get_ticks_usec()
	_tick_once()
	_warm_usec += Time.get_ticks_usec() - began


func _tick_once() -> void:
	if _rendering != &"":
		_harvest()
	while not _queue.is_empty():
		var id: StringName = _queue.pop_front()
		if _textures.has(id):
			continue
		var art := AwWeaponArtTable.get_art(id)
		if art == null or art.model_path == "":
			_textures[id] = null
			continue
		if DisplayServer.get_name() == "headless":
			var _t := texture(id)
			break
		if _start(id, art):
			break
		_textures[id] = null
	if _queue.is_empty() and _rendering == &"":
		_finish()


## Puts [param art]'s model on the shared stage and asks for one draw of it. False when it has no model.
func _start(id: StringName, art: AwWeaponVisual) -> bool:
	var model := AwModelCache.instantiate(art.model_path)
	if model == null:
		return false
	if _port == null:
		_port = _new_port()
		_ports_made += 1
		add_child(_port)
		_camera = Camera3D.new()
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.position = Vector3(0, 0, 10)
		_port.add_child(_camera)
		_camera.current = true
	_model = model
	_port.add_child(model)
	_frame(art, model, _camera)
	_port.render_target_update_mode = SubViewport.UPDATE_ONCE
	_rendering = id
	return true


## Reads the finished picture of the model the last tick put on the stage, and clears the stage for the next.
func _harvest() -> void:
	var image := _port.get_texture().get_image() if _port != null else null
	if not _textures.has(_rendering):
		_textures[_rendering] = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	if _model != null:
		_port.remove_child(_model)
		_model.queue_free()
		_model = null
	_rendering = &""


func _finish() -> void:
	if get_tree().process_frame.is_connected(_tick):
		get_tree().process_frame.disconnect(_tick)
	if _port != null:
		_port.queue_free()
		_port = null
		_camera = null
	warmed.emit()


func _new_port() -> SubViewport:
	var port := SubViewport.new()
	port.size = size
	port.transparent_bg = true
	port.own_world_3d = true
	port.msaa_3d = msaa
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	var we := WorldEnvironment.new()
	we.environment = env
	port.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	port.add_child(sun)
	return port


## Turns [param model] to face the camera, centres it and sizes the orthographic [param camera] to it.
func _frame(art: AwWeaponVisual, model: Node3D, camera: Camera3D) -> void:
	var forward := art.model_forward.normalized()
	if forward.is_equal_approx(Vector3.LEFT):
		model.basis = Basis(Vector3.UP, PI)
	elif not forward.is_equal_approx(Vector3.RIGHT):
		model.basis = Basis(Quaternion(forward, Vector3.RIGHT))
	var box := Transform3D(model.basis, Vector3.ZERO) * AwModelCache.bounds(art.model_path)
	model.position = -box.get_center()
	camera.size = maxf(box.size.x, box.size.y * float(size.x) / float(size.y)) * 1.08


func _build(art: AwWeaponVisual) -> Texture2D:
	var model := AwModelCache.instantiate(art.model_path)
	if model == null:
		return null
	var port := _new_port()
	_ports_made += 1
	add_child(port)
	port.add_child(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.position = Vector3(0, 0, 10)
	port.add_child(camera)
	_frame(art, model, camera)
	camera.current = true
	return port.get_texture()
