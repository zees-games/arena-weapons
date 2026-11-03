class_name AwWeaponArtTable
extends "aw_weapon_art_table_paths.gd"

const Listing := preload("aw_art_listing.gd")

## The view runtime's art: every registered pack's [AwWeaponVisual], the per-pose tables, and the five base rows
## ([method knife], [method pistol], [method rifle], [method launcher], [method frag]) a pack's weapon is dressed over
## ([method AwPackSource.stand_in_art]). The base rows' attachment files are under the host's `res://assets/`.

# No CHANNEL: a table of filenames. validate() returns a DotResult for the caller to log,
# and the one runtime that can fail against the disk, AwModelCache, logs its own misses.


## Where a weapon of each pose sits relative to the camera.
##
## [b]Lower and further out than a real weapon would be, and smaller than one.[/b] These
## numbers are not anatomical, and the arithmetic says why. The camera runs at a
## 90-degree vertical field of view, so at 0.5 m the visible world is a metre tall — and
## a 0.7 m rifle held there at life size fills two thirds of the screen. Every game in
## this genre answers that by drawing the view model at a much narrower field of view
## than the world; a single camera cannot do that, so the equivalent is done here by
## shrinking the weapon, which produces the same angular size.
##
## See [method pose_scale] for the other half of the same decision.
static func pose_offset(pose: StringName) -> Vector3:
	match pose:
		POSE_PISTOL:
			return Vector3(0.15, -0.20, -0.34)
		POSE_HEAVY:
			return Vector3(0.21, -0.27, -0.42)
		POSE_MELEE:
			return Vector3(0.22, -0.25, -0.40)
		POSE_THROWN:
			return Vector3(0.17, -0.19, -0.36)
		_:
			return Vector3(0.21, -0.26, -0.40)


## How a blaster of each pose is turned at the hip, in degrees (pitch, yaw, roll) in the
## model's own space (a blaster's is the view's: it points -Z): yaw positive brings the muzzle
## in toward the crosshair, roll positive cants the weapon's right side up toward the eye.
##
## [b]Canted and turned, because pointed straight down the view it is drawn end-on.[/b] A
## weapon below and right of the eye, pointing where the eye points, shows the camera its
## back face and a sliver of its left side: a stub in the corner, which is what this pack
## drew until the contact sheet put it beside a production shooter's. Perspective already
## carries a straight barrel toward the screen's centre; the yaw adds to that, and the cant
## is what turns the right side (the side with the detail) toward the eye. At this distance a
## right side needs about thirty degrees of cant before it faces the camera at all.
static func pose_rotation(pose: StringName) -> Vector3:
	match pose:
		POSE_PISTOL:
			return Vector3(0.0, 8.0, 22.0)
		POSE_HEAVY:
			return Vector3(0.0, 10.0, 26.0)
		_:
			return Vector3(0.0, 10.0, 30.0)


## How much bigger than life a weapon is drawn in a person's hand, by pose, as a share of the figure's own hand scale
## (`DotHumanoidFigure.held_scale`, which makes a pistol visible in a fist): a pistol needs all of it, a long gun would be a plank.
static func pose_world_factor(pose: StringName) -> float:
	match pose:
		POSE_PISTOL:
			return 1.0
		POSE_HEAVY:
			return 0.62
		POSE_MELEE, POSE_THROWN:
			return 1.0
		_:
			return 0.7


## Whether a pose is held with two hands in third person (before [member AwWeaponVisual.hands]).
static func pose_two_handed(pose: StringName) -> bool:
	return pose == POSE_RIFLE or pose == POSE_HEAVY


## The sprint carry in first person, [offset m, rotation deg] over the hip hold: lowered and turned so
## the barrel points left of the body; every pose stays in the lower half of the screen.
static func sprint_view(pose: StringName) -> Array:
	match pose:
		POSE_PISTOL:
			return [Vector3(-0.04, -0.02, 0.05), Vector3(28.0, 18.0, -14.0)]
		POSE_MELEE:
			return [Vector3(0.0, -0.17, 0.03), Vector3(-18.0, 0.0, 20.0)]
		POSE_THROWN:
			return [Vector3(0.0, -0.14, 0.02), Vector3(-10.0, 0.0, 10.0)]
		POSE_HEAVY:
			return [Vector3(-0.1, -0.18, 0.17), Vector3(-18.0, 36.0, -28.0)]
		_:
			return [Vector3(-0.1, -0.16, 0.16), Vector3(-14.0, 38.0, -24.0)]


## The sprint stride in first person, [bob multiplier, roll degrees]: a long gun swings heavier than a pistol or a blade.
static func sprint_bob(pose: StringName) -> Vector2:
	match pose:
		POSE_PISTOL:
			return Vector2(2.2, 3.0)
		POSE_MELEE, POSE_THROWN:
			return Vector2(1.8, 2.0)
		POSE_HEAVY:
			return Vector2(2.6, 5.0)
		_:
			return Vector2(2.6, 4.0)


## The sprint carry in a person's hand (third person), same units, in the hand's frame (-Z the way the person faces).
static func sprint_world(pose: StringName) -> Array:
	match pose:
		POSE_PISTOL:
			return [Vector3.ZERO, Vector3(30.0, 15.0, 0.0)]
		POSE_MELEE, POSE_THROWN:
			return [Vector3.ZERO, Vector3(-15.0, 0.0, 0.0)]
		_:
			return [Vector3.ZERO, Vector3(0.0, 50.0, 0.0)]


## How much a weapon of each pose is shrunk to stand in for a narrower field of view.
##
## [b]Roughly half, and it is not an arbitrary taste.[/b] A weapon drawn at life size
## half a metre from a 90-degree camera spans most of the screen; a watcher reads that as
## the gun being enormous rather than as the camera being wide. Halving it puts a rifle
## at about a third of the screen height, which is where this genre has settled. A heavy
## weapon is shrunk a little further because it is longer to begin with.
static func pose_scale(pose: StringName) -> float:
	match pose:
		POSE_PISTOL:
			return 0.72
		POSE_HEAVY:
			return 0.72
		# [b]Melee is not shrunk the way the blasters are.[/b] A knife is 35 cm long against
		# a rifle's 71, so the correction that puts a rifle at a third of the screen puts a
		# knife at a sixth — behind the hand holding it, which is where the first render
		# had it. Held slightly above life size is what a first-person blade looks like in
		# every game that ships one.
		POSE_MELEE:
			return 1.20
		POSE_THROWN:
			return 0.9
		_:
			return 0.80


## The reload keys a weapon of each pose uses unless its art names its own. Melee and
## throwables do not reload, so they have none.
static func reload_keys(pose: StringName) -> Array:
	match pose:
		POSE_PISTOL:
			return AwWeaponPose.RELOAD_KEYS_PISTOL
		POSE_HEAVY:
			return AwWeaponPose.RELOAD_KEYS_HEAVY
		POSE_MELEE, POSE_THROWN:
			return []
		_:
			return AwWeaponPose.RELOAD_KEYS_RIFLE


## A reload key set by class name ("rifle", "smg", "tube"...), for a profile's `art: reload_class`. Empty if unknown.
static func named_reload_keys(name: String) -> Array:
	var table: Variant = null
	var pose: Script = AwWeaponPose
	while pose != null and table == null:
		table = pose.get_script_constant_map().get("RELOAD_KEYS_" + name.to_upper())
		pose = pose.get_base_script()
	return table if table is Array else []


## The keys a reload plays: the art's own, else its pose's class keys. Empty only for melee and thrown.
static func effective_reload_keys(art: AwWeaponVisual) -> Array:
	if art == null:
		return []
	return art.reload_keys if not art.reload_keys.is_empty() else reload_keys(art.pose)


## How much a weapon of each pose sways, before its own [member AwWeaponVisual.weight].
static func pose_weight(pose: StringName) -> float:
	match pose:
		POSE_PISTOL:
			return 0.8
		POSE_HEAVY:
			return 1.5
		POSE_MELEE:
			return 0.7
		POSE_THROWN:
			return 0.6
		_:
			return 1.0


# --- The table --------------------------------------------------------------

## Every registered weapon's art, keyed by id. Cached and shared (games read it per figure per frame), so a caller
## that edits an art duplicates it first; [method add_source], [method remove_source] and dressers drop the cache.
static func table() -> Dictionary:
	if not _table.is_empty():
		return _table

	var out: Dictionary = {}

	for art in all():
		out[art.id] = art

	for name: StringName in _dressers:
		var dresser: Callable = _dressers[name]

		if dresser.is_valid():
			dresser.call(out)

	_table = out
	return out


static var _table: Dictionary = {}


## Forgets the cached table.
static func drop_cache() -> void:
	_table = {}


## Every registered source's art, built fresh; the first source to bring an id keeps it.
static func all() -> Array[AwWeaponVisual]:
	var out: Array[AwWeaponVisual] = []
	var taken := {}

	for name: StringName in _sources:
		var source: Callable = _sources[name]

		if not source.is_valid():
			continue

		for art: AwWeaponVisual in source.call():
			if art != null and not taken.has(art.id):
				taken[art.id] = true
				out.append(art)

	return out


## name -> Callable(table: Dictionary) that edits the freshly built table in place.
static var _dressers: Dictionary = {}


## Registers [param dresser] to run on every rebuild of [method table], so a game's re-skin survives [method add_source], [method remove_source] and
## [method drop_cache] instead of being lost with the cache. A static method's Callable, never a lambda (as [method add_source]).
static func add_dresser(name: StringName, dresser: Callable) -> void:
	_dressers[name] = dresser
	_table = {}


static func remove_dresser(name: StringName) -> void:
	_dressers.erase(name)
	_table = {}


## name -> Callable() -> Array[AwWeaponVisual].
static var _sources: Dictionary = {}


## Adds another pack's art under [param name], beside its weapons
## ([method AwWeaponCatalogue.add_source], whose rule applies: a static method's Callable, never
## a lambda, or the process aborts at exit).
static func add_source(name: StringName, source: Callable) -> void:
	_sources[name] = source
	_table = {}


static func remove_source(name: StringName) -> void:
	_sources.erase(name)
	_table = {}


## One weapon's art, or null.
static func get_art(id: StringName) -> AwWeaponVisual:
	return table().get(id, null)


# --- Melee ------------------------------------------------------------------
#
# [b]Every melee model points along +Y, not +Z.[/b] Kenney's tools stand upright on
# their handle with the origin at the butt, which is exactly where a hand grips them —
# so the grip needs no offset at all, and `model_forward` does the rest. Getting this
# wrong would point the blade at the player's own face, which is the kind of thing that
# is obvious in a picture and invisible in every assertion.

static func knife() -> AwWeaponVisual:
	return _melee(AwWeaponIds.KNIFE, MELEE + "knife_sharp.glb")


# --- Sidearms ---------------------------------------------------------------

static func pistol() -> AwWeaponVisual:
	var art := _gun(AwWeaponIds.PISTOL, "pistol", POSE_PISTOL).with_magazine(
		GUNS + "pistol_magazine.glb", Vector3(0.0, -0.0504, 0.1522)
	)
	art.ejects = false  # the foam sidearm throws no brass
	return art


# --- Primaries --------------------------------------------------------------

static func rifle() -> AwWeaponVisual:
	var art := _gun(AwWeaponIds.RIFLE, "rifle", POSE_RIFLE).with_magazine(
		GUNS + "rifle_magazine.glb", Vector3(0.0, -0.078, 0.011)
	)
	art.fore_along = 0.56
	art.fore_up = 0.32
	return art


# --- Heavies ----------------------------------------------------------------

## A shoulder-fired recoilless tube (art-src/guns): loaded at the muzzle, so nothing in the mesh
## stands in the bore that the round being carried in would have to pass through.
static func launcher() -> AwWeaponVisual:
	var art := _gun(AwWeaponIds.LAUNCHER, "launcher", POSE_HEAVY)
	art.weight = 1.6
	# Broken open: the muzzle drops, a grenade goes into the breech from above and behind, and it
	# snaps shut (AwWeaponPose.RELOAD_KEYS_BREAK).
	art = _fed(_loose(art, ROUND_ROCKET, Vector3(0.0, 0.09, 0.0)), Vector3(0.10, 0.16, 0.06), 1, 1.2)
	art.magazine_rotation = Vector3(90.0, 0.0, 0.0)
	art.reload_keys = AwWeaponPose.RELOAD_KEYS_MUZZLE
	return art


# --- Thrown -----------------------------------------------------------------
#
# The grenades stand on their base with the origin at the bottom, the same as the melee
# tools, so they take the same forward axis.

static func frag() -> AwWeaponVisual:
	return _thrown(AwWeaponIds.FRAG, BLASTERS + "grenade-a.glb")


# --- Builders ---------------------------------------------------------------

## A blaster: points along -Z, Godot's own forward, sits at its pose's offset, measures its
## own muzzle.
##
## [b]-Z, and for years the table said +Z.[/b] Seventeen of the eighteen meshes have
## symmetric bounds along their length, so the rack's muzzle pip (the far end of the bounds
## along model_forward) sat at whichever end it was told to, and every blaster was drawn
## stock-first in both views, with its tracers leaving the stock. A side render with a
## marker on +Z settled it: the marker is on the stock of all eighteen (docs/history.md).
## A gun fed by hand: [param path] is the round the support hand carries in, delivered at
## [param offset] (model space). Nothing drops out and nothing shows at rest.
static func _loose(art: AwWeaponVisual, path: String, offset: Vector3) -> AwWeaponVisual:
	var _with := art.with_magazine(path, offset)
	art.magazine_loose = true
	return art


## A gun fed by hand from somewhere in sight: [param from] (model space, from the seat) is where
## each round's push starts, [param count] rounds, drawn at [param scale] (a real round at half
## size is a few pixels in a fist).
static func _fed(art: AwWeaponVisual, from: Vector3, count: int, scale: float) -> AwWeaponVisual:
	art.load_from = from
	art.load_count = count
	art.magazine_scale = scale
	return art


## A pump gun: three shells pushed up one at a time into the port under the body, the gun held
## rolled over to show it (AwWeaponPose.RELOAD_KEYS_TUBE).
##
## [b]Fed, not loose.[/b] Loose, a single dart rode the hand once from below the screen and the
## contact sheet showed a yellow fleck in one frame of the whole reload: the play test's "no
## proper reload animations" for exactly the guns that reload most often.
static func _tube(art: AwWeaponVisual) -> AwWeaponVisual:
	art = _fed(_loose(art, ROUND_SHELL, Vector3(0.0, -0.05, -0.04)), Vector3(0.0, -0.12, 0.03), 3, 1.6)
	art.reload_keys = AwWeaponPose.RELOAD_KEYS_TUBE
	return art


## A real-world gun from [constant GUNS]: placed like a blaster (the same poses, the same -Z muzzle).
static func _gun(id: StringName, model: String, pose: StringName) -> AwWeaponVisual:
	var art := _blaster(id, "", pose)
	art.model_path = GUNS + model + ".glb"
	art.ejects = true
	return art


static func _blaster(id: StringName, model: String, pose: StringName) -> AwWeaponVisual:
	var art := AwWeaponVisual.make(id, BLASTERS + model + ".glb")
	art.model_forward = Vector3.FORWARD
	art.pose = pose
	art.view_offset = pose_offset(pose)
	art.view_scale = pose_scale(pose)
	art.weight = pose_weight(pose)
	art.view_rotation = pose_rotation(pose)
	# The fallback aim place, used only when the view model cannot measure a sight line (no
	# mesh data) or the weapon is scoped: the view model measures each gun's iron sight and
	# puts its line through the eye instead (AwWeaponVisual.iron_sight).
	art.aim_offset = Vector3(0.0, -0.135, -0.46)
	return art


## A melee weapon or a tool: points along +Y with the grip on the origin.
static func _melee(id: StringName, model: String) -> AwWeaponVisual:
	var art := AwWeaponVisual.make(id, model)
	art.model_forward = Vector3.UP
	art.pose = POSE_MELEE
	art.view_offset = pose_offset(POSE_MELEE)
	art.view_scale = pose_scale(POSE_MELEE)
	art.weight = pose_weight(POSE_MELEE)
	# [b]Carried across the view, not pointed down it.[/b] `model_forward` turns the blade
	# onto Godot's forward, which for a gun is exactly right and for a knife means the
	# blade points directly away from the eye — so it draws as its own cross-section, a
	# small disc floating above the hands, which is what the first melee render was.
	# Pitching it up and yawing it inward puts its length across the screen where it can
	# be seen, and keeps it off the crosshair.
	# [b]Held in a fist, blade up and leaning in, its flat to the eye[/b] (model space: pitch
	# the blade up off the view axis, yaw spins the flat round to face the camera, roll leans
	# it toward the crosshair). It lay across the view between two planks before the hands
	# could close; a hand round the handle is what makes it read as held.
	art.view_rotation = Vector3(70.0, 80.0, 40.0)
	art.aim_enabled = false
	# [b]No world rotation, and the temptation to add one is the trap.[/b] These models
	# stand on their handle along +Y, so it is natural to write a -90 here to lay them
	# down — but `model_forward` has already turned +Y onto -Z by the time this is
	# applied, so a second rotation puts the blade through the floor. The rack render is
	# what caught it: six melee weapons drawn end-on as specks.
	return art


static func _thrown(id: StringName, model: String) -> AwWeaponVisual:
	var art := AwWeaponVisual.make(id, model)
	art.model_forward = Vector3.UP
	art.pose = POSE_THROWN
	art.view_offset = pose_offset(POSE_THROWN)
	art.view_scale = pose_scale(POSE_THROWN)
	art.weight = pose_weight(POSE_THROWN)
	# Stood on its base in an open palm: pitched down the view axis it was drawn as a disc beside the hand.
	art.view_rotation = Vector3(70.0, 0.0, 0.0)
	art.aim_enabled = false
	return art


# --- Validation -------------------------------------------------------------

## Checks every entry. Loads no mesh: file presence is [method validate_models]'s question.
static func validate() -> DotResult:
	for art: AwWeaponVisual in table().values():
		var res := art.validate()
		if not res.ok:
			return res

	return DotResult.success(null)


## Every model file the table names, once each, sorted: the weapon, its magazine and its attachments, from this pack and every registered source.
## This is the one list a game vendors: [method validate_models] checks it [param with_arms] adds the arms models.
static func model_paths(with_arms: bool = false) -> Array[String]:
	return Listing.model_paths(all(), with_arms)


## Checks that every named model resolves, through [method AwModelCache.resolve] so a game's asset root applies. Loads scenes, so it is not the boot check.
## A game's suite calls this one line; it reports every missing model, not the first.
static func validate_models(with_arms: bool = false) -> DotResult:
	return Listing.missing_result(model_paths(with_arms))


static func describe_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var built := all()
	out.append("weapon art: %d entries" % built.size())

	for art in built:
		out.append("  %-16s %-28s %-7s x%.2f  %d attachment(s)" % [
			String(art.id),
			art.model_path.get_file() if art.has_model() else "(none)",
			String(art.pose),
			art.view_scale,
			art.attachments.size(),
		])

	return out
