@tool
extends "aw_view_model_hands.gd"

## Wall-retract layer of AwViewModel, split out for file size.

## Physics layers the wall probe stops on (the world and bodies; the carrier is skipped). The rig copies its shot effects' mask.
@export_flags_3d_physics var wall_mask: int = 0xFFFFFFFF

## When on, the probe passes through character bodies: a person crossing the muzzle is not a wall and must not slam the weapon.
@export var wall_ignore_characters: bool = true

var _strafe_now: float = 0.0

var _overlay: AwViewOverlay = null

## Seconds the wall-free pass stays on after the drawn gun last reached into the world, so it does not flicker at the edge of contact.
const CLIP_HOLD := 0.25

var _clip_left: float = 0.0


## The wall-free pass goes off the moment this view model stops being drawn or run. Its CanvasLayer ignores a hidden
## Node3D parent and a stopped process, and its camera shares the world: left on, it went on drawing the whole view
## layer (the player's own gun) from where it last stood, a small dark copy of the gun hanging in the world for every
## parked killcam hand and hidden spare (owner video: four, switching and reloading with the player's).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_DISABLED, NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE, NOTIFICATION_PARENTED, NOTIFICATION_UNPARENTED:
			if not _drawn_live():
				_clip_left = 0.0
				if _overlay != null:
					_overlay.update(false, null)


## Drawn and run, under a camera: the only state in which the wall-free pass may be on.
func _drawn_live() -> bool:
	return is_inside_tree() and is_visible_in_tree() and can_process() and get_parent() is Camera3D

## Whether the gun as it is drawn reaches into the world, held for [constant CLIP_HOLD] after the last contact.
## The lens draws the gun larger and farther from the eye than its real size, and [method _advance_wall] probes the real size, so looking steeply down puts the drawn barrel through a floor the probe never reaches (and a wall or crate likewise).
## The wall-free pass hides that, so it must run whenever the drawn gun is in the world, not only while the wall response is pulling the gun back.
func _drawn_gun_in_world(delta: float) -> bool:
	if _animated != null and _animated.visible and is_inside_tree() and get_world_3d() != null and _drawn_gun_touches_world():
		_clip_left = CLIP_HOLD
	else:
		_clip_left = maxf(_clip_left - delta, 0.0)
	return _clip_left > 0.0


## A ray from the eye to each corner of the box round the drawn gun's meshes, and to the muzzle, stopped short of the point: a hit means the world is in front of part of the gun.
func _drawn_gun_touches_world() -> bool:
	var camera := get_parent() as Node3D
	if camera == null:
		return false
	var box := AABB()
	var first := true
	for mesh in _drawn_meshes(_animated):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var bounds := mesh.global_transform * mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
	if first:
		return false
	var space := get_world_3d().direct_space_state
	var eye := camera.global_position
	var points: Array[Vector3] = [muzzle_transform().origin]
	var reach := 0.0
	for corner in 8:
		points.append(box.get_endpoint(corner))
	for point in points:
		reach = maxf(reach, eye.distance_to(point))
	# In the open nothing is within the gun's reach of the eye: one sphere query answers for the nine rays.
	if not _world_near(space, eye, reach):
		return false
	for point in points:
		var gap := point - eye
		var length := gap.length()
		if length < 0.05:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, point - gap / length * 0.02, wall_mask, _wall_exclude().duplicate())
		query.collide_with_areas = false
		for _hop in 4:
			var found := space.intersect_ray(query)
			if found.is_empty():
				break
			if wall_ignore_characters and found["collider"] is CharacterBody3D:
				query.exclude.append(found["rid"])
				continue
			return true
	return false

var _near_query: PhysicsShapeQueryParameters3D = null

## Frames a walked mesh list is kept before the tree under it is walked again. Equipping clears it at once; a part
## added mid-weapon (a fresh magazine) is picked up within this many frames, a freed one is dropped the frame it goes.
const MESH_WALK_FRAMES := 30

## Root instance id -> [frame walked, meshes]: the wall and near-clip probes walked the whole drawn tree twice a
## frame, allocating an array per node (about 0.1 ms of the view model's 0.37 ms a frame).
var _mesh_walks: Dictionary = {}


## The meshes under [param root], walked again only every [constant MESH_WALK_FRAMES] frames or when one has been freed.
func _drawn_meshes(root: Node) -> Array[MeshInstance3D]:
	var key := root.get_instance_id()
	var frame := Engine.get_process_frames()
	var held: Array = _mesh_walks.get(key, [])
	if not held.is_empty() and frame - int(held[0]) < MESH_WALK_FRAMES:
		# Untyped loop: a freed mesh in a typed variable is an engine error before the validity check can run.
		var whole := true
		for mesh: Variant in held[1]:
			if not is_instance_valid(mesh) or not (mesh as Node).is_inside_tree():
				whole = false
				break
		if whole:
			return held[1]
	var walked := HandReach.meshes(root)
	if _mesh_walks.size() > 8:
		_mesh_walks.clear()
	_mesh_walks[key] = [frame, walked]
	return walked


## Forgets the walked mesh lists, so the next probe walks the drawn tree again (a new weapon, a re-dress).
func _forget_mesh_walks() -> void:
	_mesh_walks.clear()


## Whether anything the wall probe stops on lies within [param radius] of [param eye]; a ray from the eye no longer
## than that can hit nothing when this is false.
func _world_near(space: PhysicsDirectSpaceState3D, eye: Vector3, radius: float) -> bool:
	if _near_query == null:
		_near_query = PhysicsShapeQueryParameters3D.new()
		_near_query.shape = SphereShape3D.new()
		_near_query.collide_with_areas = false
	(_near_query.shape as SphereShape3D).radius = maxf(radius, 0.01)
	_near_query.transform = Transform3D(Basis.IDENTITY, eye)
	_near_query.collision_mask = wall_mask
	_near_query.exclude = _wall_exclude()
	return not space.intersect_shape(_near_query, 1).is_empty()


## Pulls the weapon back and up when its muzzle would be inside a wall. The probe is cast against the un-retracted pose, so the answer does not feed back into itself.
func _advance_wall(delta: float) -> void:
	var on := feel_rules.wall_retract > 0.0 and _weapon != null and is_inside_tree()
	var w := _wall_numbers()
	var target := 0.0
	if on:
		var muzzle := muzzle_transform().origin
		var cam: Node3D = (get_parent() as Node3D) if get_parent() is Node3D else self
		var to_muzzle := muzzle - cam.global_position
		var dist := to_muzzle.length()
		if dist > 0.01:
			var scale_now: float = ads_rules.view_scale_for(_art.id) if ads_rules != null and _art != null else 2.0
			var reach := AwWallSlam.reach_of(dist, scale_now, w["reach"])
			var hit := AwWallSlam.probe(self, reach, wall_mask, wall_ignore_characters, _wall_exclude(), to_muzzle / dist,
				w["margin"], w["max"], w["floor_look"], w["spread"] / maxf(scale_now, 0.1), w["cast"])
			target = hit["depth"]
			if target > 0.0:
				# Walking into the wall pushes the spring's rest point deeper: force decides how far the gun gives.
				target = minf(target + clampf(_speed * 0.012, 0.0, 0.1) * w["impulse"], w["max"])
			_wall.aim_at(hit["normal"], _speed, _strafe_now)
			_wall.set_lean(hit["sides"], _screen_offset(to_muzzle, cam), w["lean"])
	_wall.step(target, delta, w["stiffness"], w["damping"], w["lean_rate"])
	if _wall.amount > 0.0:
		var rest := _animated.global_position
		_animated.transform = _wall.offset(feel_rules.wall_retract, feel_rules.wall_tilt, w["push"], w["nudge"], aim_fraction(), w["impulse"]) * _animated.transform
		_keep_off_near_plane(rest)

## Slides the view model away from the eye until no part of the hands is nearer than the camera's near plane plus a margin, and
## no part of the weapon is cut by that plane where it shows: a hand or a shroud through the lens is sliced open and shows its
## inside as flat white or blue-grey faces. A stock that passes the plane outside the view is not seen and does not count.
## The weapon's share of the slide is capped at what the wall pulled it back toward the eye ([param rest] is where it was before),
## so the clamp only undoes retraction and never shoves the gun past its free pose; the overlay draws it over the wall.
## Ported from zee-dot-weapons (viewmodel-white-blue-1).
func _keep_off_near_plane(rest: Vector3 = Vector3.INF) -> void:
	var camera := get_parent() as Camera3D
	if camera == null:
		return
	var eye := camera.global_transform
	var clear := camera.near + NEAR_CLEAR
	var deficit := 0.0
	if _arms != null and _arms.has_method(&"nearest_hand_depth"):
		var hand: float = clear - _arms.nearest_hand_depth(eye)
		if hand < 1.0:
			deficit = hand
	if rest != Vector3.INF:
		var pulled := (eye.affine_inverse() * rest).z - (eye.affine_inverse() * _animated.global_position).z
		deficit = maxf(deficit, minf(weapon_cut_depth(camera, clear), -pulled))
	if deficit > 0.0:
		_animated.global_position -= camera.global_basis.z * deficit

## How far (metres) the weapon must move away from [param camera] so no drawn mesh's bounds cross the plane [param clear] in front of
## the eye inside the view (with a margin); 0 when none does.
func weapon_cut_depth(camera: Camera3D, clear: float) -> float:
	if _holder == null:
		return 0.0
	var half_h := clear * tan(deg_to_rad(camera.fov) * 0.5) * 1.25
	var size := camera.get_viewport().get_visible_rect().size if camera.get_viewport() != null else Vector2(16.0, 9.0)
	var half := Vector2(half_h * size.x / maxf(size.y, 1.0), half_h)
	var view_rect := PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	var inverse := camera.global_transform.affine_inverse()
	var worst := 0.0
	for mesh in _drawn_meshes(_holder):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var to_eye := inverse * mesh.global_transform
		var box := mesh.get_aabb()
		var corners: Array[Vector3] = []
		var nearest := INF
		for i in 8:
			corners.append(to_eye * box.get_endpoint(i))
			nearest = minf(nearest, -corners[i].z)
		if nearest < clear and _section_meets(corners, clear, view_rect):
			worst = maxf(worst, clear - nearest)
	return worst

## Whether the box with view-space [param corners] (AABB.get_endpoint order: bit 0 z, bit 1 y, bit 2 x) cuts the plane [param depth]
## in front of the eye in a section that overlaps [param view_rect] (x, y on that plane).
static func _section_meets(corners: Array[Vector3], depth: float, view_rect: PackedVector2Array) -> bool:
	var section := PackedVector2Array()
	for i in 8:
		for bit: int in [1, 2, 4]:
			var j: int = i | bit
			if j == i:
				continue
			var da := -corners[i].z - depth
			var db := -corners[j].z - depth
			if (da < 0.0) == (db < 0.0):
				continue
			var p := corners[i].lerp(corners[j], da / (da - db))
			section.append(Vector2(p.x, p.y))
	var hull := Geometry2D.convex_hull(section) if section.size() >= 3 else PackedVector2Array()
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	return hull.size() >= 3 and not Geometry2D.intersect_polygons(hull, view_rect).is_empty()

## Where the muzzle sits on the screen relative to the crosshair, as a view-space slope (x right, y up).
func _screen_offset(to_muzzle: Vector3, cam: Node3D) -> Vector2:
	var local := cam.global_basis.inverse() * to_muzzle
	var depth := maxf(-local.z, 0.05)
	return Vector2(local.x, local.y) / depth

## The wall response's numbers for the held weapon (the profile's, or the defaults).
func _wall_numbers() -> Dictionary:
	if ads_rules != null and _art != null:
		return ads_rules.wall_for(_art.id)
	var out := {}
	for key: String in ["reach", "margin", "stiffness", "damping", "push", "nudge", "max", "floor_look", "lean", "spread", "lean_rate", "cast", "impulse"]:
		out[key] = float(AwAdsRules.SPECS["wall_" + key]["default"])
	return out

## The carrier's own body, so the probe never stops on the player it hangs from.
func _wall_exclude() -> Array[RID]:
	if _wall_excluded.is_empty():
		var node: Node = get_parent()
		while node != null and not (node is CollisionObject3D):
			node = node.get_parent()
		if node != null:
			_wall_excluded.append((node as CollisionObject3D).get_rid())
	return _wall_excluded

## The retract and pitch the wall asks of the weapon now, for a suite and a tool.
func wall_amount() -> float:
	return _wall.amount

## The wall's eased lean for a suite and a tool: x positive turns the barrel left, y positive tips it up.
func wall_lean() -> Vector2:
	return _wall.lean
