@tool
extends "aw_view_model_materials.gd"

## Build, hands, belt and teardown half of AwViewModel, split out for file size.

const ReloadProps := preload("aw_reload_props.gd")
const MagCarve := preload("aw_mag_carve.gd")

const CHANNEL := "aw.view"

@export_group("Wiring")

## The arms. Left null, the view model builds its own on first use.
## A [DotNodeRef], not a path: the host decides per instance.
@export var arms_ref: DotNodeRef = null

const BeltFeed := preload("aw_belt_feed.gd")

var _belt: Node3D = null

@export_group("Behaviour")

## Whether to build and show hands at all.
## A real configuration (non-humanoid characters, a gun with no holder), not a debug switch.
## Turned off after the model is built (a game mounting its own arms once this is in the tree), the built hands go too.
@export var show_arms: bool = true:
	set(value):
		show_arms = value
		if not _built:
			return
		if not value and _arms != null:
			if _arms.get_parent() == _animated:
				_animated.remove_child(_arms)
				_arms.queue_free()
			else:
				_arms.visible = false
			_arms = null
		elif value and _arms == null:
			_build_arms()
			if _art != null and _arms != null:
				_arms.set_pose(_art.pose)
				_reach_for(_art)

## Which skin the hands wear. Passed to [AwViewArms] when this builds its own.
@export_file("*.png", "*.jpg", "*.webp") var arm_skin: String = ""

@export_group("Wall")

## Draws the view model again in a pass with no world in it while it is pressed against one, so a wall cannot hide the gun. Costs a second render of the view layer only while active.
## Never built on the web (see [method AwViewOverlay.supported]): there a wall can still clip the gun.
@export var wall_overlay: bool = true

@export_group("Light")

## The energy of the view model's own key light, which turns with the camera and lights only the view model. 0 builds none.
## The world's sun is fixed, so turning round leaves the gun lit by ambient alone; a key light keeps its side lit the same way.
@export_range(0.0, 4.0, 0.05) var view_light_energy: float = 0.3

## Where that light comes from, as Euler degrees of the light's own rotation in the camera's
## space: above, behind and to the left, so it rakes across the right side the hold shows.
@export var view_light_rotation: Vector3 = Vector3(-38.0, -32.0, 0.0)

## Sets [member hands_fov] from a horizontal field of view measured on a 4:3 frame, the
## convention a game's `field_of_view` setting already uses, so the two are comparable.
func set_hands_fov_at_4_3(horizontal: float) -> void:
	hands_fov = vertical_from_horizontal_4_3(horizontal)


## The vertical field of view that is [param horizontal] degrees across a 4:3 frame.
static func vertical_from_horizontal_4_3(horizontal: float) -> float:
	return DotViewLens.vertical_from_horizontal_4_3(horizontal)


func _init() -> void:
	add_to_group(&"dot_view_model")


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_build_structure()
	if wall_overlay and view_layer > 0 and AwViewOverlay.supported():
		_overlay = AwViewOverlay.new()
		add_child(_overlay)
		_overlay.setup(self, view_layer)


# --- Building ---------------------------------------------------------------


func _build_structure() -> void:
	if _built:
		return

	_animated = Node3D.new()
	_animated.name = "Animated"
	add_child(_animated)

	# Aim is a node of its own because the aim hold is turned as well as moved: the hip hold is canted,
	# the aim hold is straight down the sight, and moving only the position brought a canted gun end-on to the middle.
	_aim_node = Node3D.new()
	_aim_node.name = "Aim"
	_animated.add_child(_aim_node)

	_holder = Node3D.new()
	_holder.name = "Holder"
	_aim_node.add_child(_holder)
	_hands_frame = Node3D.new()
	_hands_frame.name = "HandsFrame"
	add_child(_hands_frame)

	if show_arms:
		_build_arms()

	_build_light()
	_built = true


func _build_arms() -> void:
	if arms_ref != null:
		var found := arms_ref.resolve(self)
		if found.ok and found.value is AwViewArms:
			_arms = found.value
			_arms.build()
			return

	_arms = AwViewArms.new()
	_arms.view_layer = view_layer
	_arms.name = "Arms"
	_arms.skin = arm_skin
	# Under Animated so the hands move with the gun (a reload would otherwise slide it out of them).
	# Not under Aim: carried rigidly to the sight, the shoulders went with the gun; they reach for the aimed hands each frame (_place_hands).
	_animated.add_child(_arms)

	var res := _arms.build()

	if not res.ok:
		# Not fatal, and not even an error: a rig with no hands still draws the weapon,
		# which is what a great many games in this genre ship anyway.
		DotLog.info(
			CHANNEL, "no first-person hands; drawing the weapon alone",
			{"why": res.error.message}
		)


## The view model's own key light. See [member view_light_energy].
func _build_light() -> void:
	if view_light_energy <= 0.0 or view_layer <= 0:
		return

	_light = DirectionalLight3D.new()
	_light.name = "ViewLight"
	_light.light_energy = view_light_energy
	_light.light_cull_mask = 1 << (view_layer - 1)
	# A light for one object a metre from the eye casts nothing worth a shadow map, and it
	# must not draw a second sun in the sky.
	_light.shadow_enabled = false
	_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_light.rotation_degrees = view_light_rotation
	add_child(_light)


# --- Weapons ----------------------------------------------------------------


## Puts the hands on this weapon, measured from the weapon itself in the holder's space: a blaster's right hand round its grip,
## the left on the fore-end at 62%, a melee hand round its handle, a grenade's round its middle, each with the held axis.
func _reach_for(art: AwWeaponVisual) -> void:
	var to_aim := _holder.transform
	var r := HandReach.measure(art, _weapon, _holder)
	var grip: Vector3 = r.grip
	var fore: Vector3 = r.fore
	var grip_axis: Vector3 = r.grip_axis
	var fore_axis: Vector3 = r.fore_axis
	var radius: float = r.radius

	if _arms != null:
		_arms.fit_glove_to(_weapon)
	_has_well = art.has_magazine() and _weapon != null
	_well = to_aim * art.magazine_transform().origin
	# A round fed by hand from somewhere (the top, the muzzle): where its push in starts, and
	# the bolt the hand works first, all in the same space as the well.
	_feeds = _has_well and art.magazine_loose and art.load_from.length_squared() > 0.000001
	_entry = to_aim * (art.magazine_offset + art.load_from)
	_bolted = _feeds and art.bolt_pull.length_squared() > 0.000001
	_bolt = to_aim * art.bolt_at
	_bolt_back = to_aim * (art.bolt_at + art.bolt_pull)

	_grip_at = to_aim * grip
	_fore_at = to_aim * fore
	# After the fore-end: the keys start and end on it.
	_feed_keys = _build_feed_keys(art) if _feeds else []
	_grip_axis = (to_aim.basis * grip_axis).normalized()
	_fore_axis = (to_aim.basis * fore_axis).normalized()
	if _weapon == null:
		# Bare fists, raised: closed round nothing, knuckles forward, leaning in a little.
		_grip_axis = Vector3(-0.35, 1.0, -0.25).normalized()
		_fore_axis = Vector3(0.35, 1.0, -0.25).normalized()
	# In the view's metres: the holder's scale is the art's view_scale.
	_grip_radius = radius * art.view_scale
	_place_hands()


## Removes whatever is in hand.
func clear() -> void:
	_clear_models()
	_art = null
	_id = &""
	_muzzle = Vector3.ZERO


## The multiple of the default speed this weapon's cases leave at ([member AwWeaponVisual.eject_speed]).
func eject_speed() -> float:
	return _art.eject_speed if _art != null else 1.0


## The moving belt of a belt-fed gun, or null.
func belt_feed() -> Node3D:
	return _belt


func _build_belt(art: AwWeaponVisual) -> void:
	_belt = null
	if not art.belt_feed or _weapon == null:
		return
	var box := HandReach.bounds_in(_weapon, _weapon)
	if box.size == Vector3.ZERO:
		return
	var tray := Vector3(box.position.x * 0.8, box.position.y + box.size.y * 0.62, box.position.z + box.size.z * 0.5) + art.belt_offset
	_belt = BeltFeed.new()
	_belt.name = "BeltFeed"
	_weapon.add_child(_belt)
	_belt.build(tray + Vector3(-0.07, -0.10, 0.0), tray)


## True when the weapon in hand throws a spent case ([member AwWeaponVisual.ejects]).
func ejects() -> bool:
	return _art != null and _art.ejects and _weapon != null


## Where the ejection port is right now, in world space: the receiver's right side, 45% from stock to muzzle, measured from the mesh bounds.
## The basis is the weapon's, unscaled (+X out of the right side, +Y up, -Z to the muzzle). Effects only.
func eject_transform() -> Transform3D:
	if _weapon == null:
		return global_transform

	var box := HandReach.bounds_in(_weapon, _weapon)
	if box.size == Vector3.ZERO:
		return _weapon.global_transform

	var f := _art.eject_port if _art != null and _art.eject_port != Vector3.ZERO else Vector3(0.9, 0.72, 0.55)
	var local := Vector3(box.end.x * f.x, box.position.y + box.size.y * f.y, box.position.z + box.size.z * f.z)
	var world := _weapon.global_transform
	return Transform3D(world.basis.orthonormalized(), world * local)


# --- Being told what happened -----------------------------------------------


var _props: ReloadProps = null

## The magazine split out of a one-mesh model (MagCarve), a node of the weapon; null when the model has its own or none.
var _carved: Node3D = null


## Makes the magazine of a gun whose model draws it welded into the body a node of its own, from the triangles in the
## magazine well's box (the row's `reload.mag_box`, six numbers in Aim space, or one measured from the well).
## Where the magazine sits in each welded model, in the holder's space: x0, y0, z0, x1, y1, z1. Read off rendered side views
## (tools/render_reload.gd --probe). An empty array means the mesh holds no magazine to take out.
const MAG_BOXES := {
	"machine_pistol.glb": [-0.12, -0.175, -0.067, 0.12, -0.012, 0.031],
	"burst_rifle.glb": [-0.12, -0.16, -0.19, 0.12, 0.02, -0.07],
	"drum_shotgun.glb": [-0.12, -0.11, 0.20, 0.12, 0.05, 0.37],
	"marksman.glb": [-0.12, -0.03, -0.245, 0.12, 0.03, -0.14],
	"sniper_ph.glb": [-0.12, -0.01, -0.17, 0.12, 0.04, -0.095],
	"lmg.glb": [-0.2, -0.125, -0.31, 0.2, 0.10, -0.155],
	"bullpup.glb": [],
	"battle_rifle.glb": [],
}

func _carve_magazine(art: AwWeaponVisual) -> void:
	_carved = null
	if art.hide_during_reload != &"" or art.has_magazine() or _weapon == null or feel_rules.reload_detail <= 0.0:
		return
	var style := ReloadSequence.style_of(art)
	if style not in [&"magazine", &"pistol", &"cell", &"belt"]:
		return
	var to_aim := _holder.transform
	var well: Variant = _well if _has_well and art.reload.is_empty() else null
	var anchors := ReloadSequence.anchors_for(_grip_at, _fore_at, to_aim * (_weapon.transform * _muzzle), well, art.reload.get("anchors", {}), to_aim)
	var seq := ReloadSequence.new()
	seq.compose(art, anchors, 30, 15)
	var ps: float = seq.prop_scale
	var box := AABB()
	var held: Variant = MAG_BOXES.get(art.model_path.get_file(), null)
	if held is Array and (held as Array).is_empty():
		return
	if style == &"belt" and held == null and art.reload.get("mag_box", null) == null:
		return
	var given: Variant = art.reload.get("mag_box", null)
	if held is Array and given == null:
		var h: Array = held
		box = AABB(Vector3(h[0], h[1], h[2]), Vector3(h[3] - h[0], h[4] - h[1], h[5] - h[2]))
		MagCarve.remember(art.model_path, box)
		_carved = MagCarve.carve(_weapon, _holder, Transform3D.IDENTITY, box, "%s|%s" % [art.model_path, box])
		if _carved != null:
			_set_on_top(_carved)
		return
	if given is Array and (given as Array).size() == 6:
		var g: Array = given
		box = AABB(Vector3(g[0], g[1], g[2]), Vector3(g[3] - g[0], g[4] - g[1], g[5] - g[2]))
	else:
		var w: Vector3 = anchors[&"well"]
		var half := Vector3(0.03, 0.0, 0.045) * ps
		box = AABB(w - Vector3(half.x, 0.17 * ps, half.z), Vector3(half.x * 2.0, 0.18 * ps, half.z * 2.0))
	# In the holder's space, where the watcher's model of the gun finds it too.
	box = to_aim.affine_inverse() * box
	MagCarve.remember(art.model_path, box)
	_carved = MagCarve.carve(_weapon, _holder, Transform3D.IDENTITY, box, "%s|%s" % [art.model_path, box])
	if _carved != null:
		_set_on_top(_carved)

func _animate_sequence(f: float) -> void:
	var out: bool = _seq.own_magazine_out(f)
	if _magazine != null:
		_magazine.visible = not _art.magazine_loose and not out
		_magazine.transform = _art.magazine_transform()
	if _props == null and _art.hide_during_reload != &"" and _weapon != null:
		var own := _weapon.find_child(String(_art.hide_during_reload), true, false) as Node3D
		if own != null:
			own.visible = not out
	if _props != null:
		var scale := maxf(_holder.transform.basis.get_scale().x, 0.0001)
		_props.show_at(_seq, f if f > 0.0 and f < 1.0 else -1.0, _holder.transform.affine_inverse(), float(_seq.prop_scale) / scale)
	_set_bolt(_seq.bolt_back(f) if f > 0.0 and f < 1.0 else 0.0)


## Draws the art's [member AwWeaponVisual.bolt_node] [param back] (0 rest, 1 fully charged)
## of [member AwWeaponVisual.bolt_travel] toward the stock. The rest position is kept on the
## node the first time it moves, so a sequence cut short puts it back where it was.
func _set_bolt(back: float) -> void:
	if _art == null or _art.bolt_node == &"" or _art.bolt_travel <= 0.0 or not is_instance_valid(_weapon):
		return
	var bolt := _weapon.find_child(String(_art.bolt_node), true, false) as Node3D
	if bolt == null:
		return
	if not bolt.has_meta(&"aw_bolt_rest"):
		bolt.set_meta(&"aw_bolt_rest", bolt.position)
	bolt.position = (bolt.get_meta(&"aw_bolt_rest") as Vector3) + Vector3(0.0, 0.0, _art.bolt_travel * clampf(back, 0.0, 1.0))


## The scale that draws the hands at [member hands_fov]. See there.
func _apply_hands_lens() -> void:
	# Only under a camera: the scale is in the camera's own space, and a view model hung
	# anywhere else is in some other space where this would be a distortion, not a lens.
	DotViewLens.apply(self, get_parent() as Camera3D, hands_fov, hands_depth_comp)


## How much X and Y are scaled to draw at [param hands] degrees under a [param camera]-degree
## lens. 1 when either is not a usable field of view.
static func lens_scale(camera: float, hands: float) -> float:
	return DotViewLens.lens_scale(camera, hands)


# --- Aiming -----------------------------------------------------------------


## Smoothstep, so the weapon leaves the hip and arrives at the eye gently.
static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Whether the carrier is sprinting: the weapon lowers and swings to the side, blended over [constant SPRINT_SECONDS].
func set_sprinting(on: bool) -> void:
	_sprinting = on


## Where the sprint carry is, 0 (hip) to 1.
func sprint_fraction() -> float:
	return _sprint


## Tells the rig how the holder is moving and looking this frame.
## [param look] is absolute yaw and pitch in degrees (the rig takes the difference itself, so sway is computed once);
## [param strafe] is sideways ground speed in m/s, positive right; left out, measured from this node's own movement.
func drive(look: Vector2, speed: float, on_floor: bool, crouched: bool = false, strafe: float = NAN) -> void:
	_strafe_given = strafe
	_look = look
	_speed = speed
	_on_floor = on_floor
	_crouched = crouched


## Drops the magazine out and slides a fresh one in, if there is one to animate.
func _animate_magazine(fraction: float) -> void:
	if _seq != null:
		_animate_sequence(clampf(fraction, 0.0, 1.0))
		return
	if _magazine == null or _art == null:
		return

	var f := clampf(fraction, 0.0, 1.0)
	var rest := _art.magazine_transform()

	# The gun's own magazine node is out of the gun from when the hand pulls it (0.20) to the seat.
	if _art.hide_during_reload != &"" and _weapon != null:
		var own := _weapon.find_child(String(_art.hide_during_reload), true, false) as Node3D
		if own != null:
			own.visible = not (f >= 0.20 and f < 0.58)

	# Timed to the reload keys (AwWeaponPose.RELOAD_KEYS_*) and `_support_hand`: out while the gun rolls onto its side (0.10-0.28),
	# in the hand from 0.36, seated with the jolt at 0.58. Visible throughout it reads as the gun shaking; rising from nothing, as a hand reaching for air.
	var shown := true
	var at := rest.origin
	var basis := rest.basis

	if _feeds:
		# Fetched, carried to where its push starts and pushed home (_build_feed_keys).
		var fed := _fed_round(f)
		shown = not fed.is_empty()
		if shown:
			at = fed.at
	elif _art.magazine_loose:
		# A round fed by hand: in sight only while it is carried in.
		shown = f >= 0.36 and f < 0.58
		if shown and _holder != null:
			# Held up between the fingertips, higher than a magazine: a round inside the fist
			# is a hand that fetched nothing.
			var carried := _holder.transform.affine_inverse() * (_support_hand() + Vector3(0.0, 0.065, 0.0))
			at = carried if carried.is_finite() else rest.origin
	elif f >= 0.10 and f < 0.28:
		var drop := (f - 0.10) / 0.18
		# Falls, faster as it goes, and tips forward off the hand's line.
		at = rest.origin + Vector3(0.0, -0.40 * drop * drop - 0.04 * drop, 0.02 * drop)
		basis = rest.basis * Basis(Vector3.RIGHT, deg_to_rad(-35.0 * drop))
	elif f >= 0.28 and f < 0.36:
		shown = false
	elif f >= 0.36 and f < 0.58 and _holder != null:
		# Where the support hand is, a little above the palm, in the holder's (model) space.
		var settle := clampf((f - 0.36) / 0.22, 0.0, 1.0)
		var carry := _art.magazine_carry.lerp(Vector3(0.0, 0.035, 0.0), settle * settle * settle)
		var hand := _support_hand() + carry
		var held := _holder.transform.affine_inverse() * hand
		at = held if held.is_finite() else rest.origin
		basis = rest.basis * Basis(Vector3.RIGHT, deg_to_rad(-20.0 * (1.0 - settle)))

	_magazine.visible = shown
	_magazine.transform = Transform3D(basis, at)


func _add_part(path: String, at: Transform3D) -> Node3D:
	if path == "":
		return null

	var part := AwModelCache.instantiate(path)

	if part == null:
		return null

	_holder.add_child(part)
	part.transform = at
	_set_on_top(part)
	return part


## The held weapon art's first-person hand size, 0 when it keeps the arms' own.
func art_hand_scale() -> float:
	return _art.hand_scale if _art != null else 0.0


## How the hands close on the held weapon: its `hand_grip` row plus `pose` and the world `forward` and `up` of the drawn gun.
func art_hand_grip() -> Dictionary:
	if _art == null or _weapon == null:
		return {}
	var out := _art.hand_grip.duplicate()
	var b := _weapon.global_transform.basis.orthonormalized()
	out["pose"] = _art.pose
	out["forward"] = (b * _art.model_forward).normalized()
	out["up"] = b.y if _art.pose != &"melee" else -b.z
	return out


func art_forearm_scale() -> float:
	return _art.forearm_scale if _art != null else 0.0


## The weapon's arm-lean cap, or below 0 for the arms' own.
func art_max_lean() -> float:
	return _art.max_lean if _art != null else -1.0


## Measures the muzzle, honouring an override on the art.
func _measure_muzzle(art: AwWeaponVisual) -> Vector3:
	if art.muzzle_socket.is_finite():
		return art.muzzle_socket

	var distance := art.muzzle_distance

	if distance <= 0.0:
		distance = AwModelCache.muzzle_distance(art.model_path, art.model_forward)

	distance = maxf(distance, float(_dressed.get("reach", 0.0)))
	return art.model_forward.normalized() * distance + art.muzzle_offset


func _clear_models() -> void:
	for node in [_weapon, _magazine, _sight]:
		if node != null:
			node.queue_free()
	_sight = null
	_sight_line = {}
	_dressed = {}
	_fitting = null

	for node in _attachments:
		node.queue_free()

	_weapon = null
	_belt = null
	_magazine = null
	_attachments.clear()
