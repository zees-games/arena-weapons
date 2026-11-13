class_name AwAttachmentPack
extends RefCounted

## The pack's attachments: each is its own item (`att_<id>`), drawn by its own model on a gun's `socket_<mount>`
## ([AwAttachmentSockets] says which guns have which mount). A host builds [method catalogue] once, validates a fitting
## against it on the server and applies it to the gun's def; the view reads [method art_of] through [AwAttachmentArt].

const SOURCE := &"arena_weapons"
const MODEL_DIR := "res://addons/arena_weapons/assets/attachments/"
const ITEM_PREFIX := "att_"

## id -> {name, mount, scale (def or tuning field -> multiplier), params, excludes, aim, zoom}. `zoom` is the field-of-view
## multiplier at full aim (0.33 is a 3x sight); a sidearm takes no magnified optic.
const ROWS := {
	&"red_dot": {"name": "Red Dot", "mount": &"optic", "aim": &"glass", "zoom": 0.83},
	&"holo": {"name": "Holographic Sight", "mount": &"optic", "aim": &"glass", "zoom": 0.75},
	&"prism_3x": {"name": "3x Prism", "mount": &"optic", "aim": &"glass", "zoom": 0.33, "excludes": [&"sidearm"]},
	&"scope_6x": {"name": "6x Scope", "mount": &"optic", "aim": &"scoped", "zoom": 0.17, "excludes": [&"sidearm"]},
	&"suppressor": {"name": "Suppressor", "mount": &"muzzle", "scale": {"damage": 0.92, "recoil_pitch": 0.9}, "params": {"suppressed": true}},
	&"compensator": {"name": "Compensator", "mount": &"muzzle", "scale": {"recoil_pitch": 0.75, "recoil_yaw": 0.8}},
	&"vertical_grip": {"name": "Vertical Grip", "mount": &"underbarrel", "scale": {"recoil_pitch": 0.8}},
	&"angled_grip": {"name": "Angled Grip", "mount": &"underbarrel", "scale": {"recoil_yaw": 0.7, "spread_moving": 0.85}},
	&"laser": {"name": "Laser Sight", "mount": &"side", "scale": {"spread": 0.8, "spread_moving": 0.85}},
	&"extended_mag": {"name": "Extended Magazine", "mount": &"magazine", "scale": {"magazine": 1.5, "reload_ticks": 1.15}},
}

## Who made the models: rows as [method AwSpawnProvider.credits] returns.
const CREDITS: Array[Dictionary] = [
	{"id": "arena-weapons-attachments", "model": "attachments (red_dot, holo, prism_3x, scope_6x, suppressor, compensator, grips, laser, extended_mag)", "author": "Arena Weapons (own work, tools/make_attachments.gd)", "licence": "CC0-1.0", "url": "https://github.com/zees-games/fc-weapons/blob/main/tools/make_attachments.gd"},
]


## Every attachment, fresh each call.
static func attachments() -> Array[DotWeaponAttachment]:
	var out: Array[DotWeaponAttachment] = []
	for id: StringName in ROWS:
		var row: Dictionary = ROWS[id]
		var a := DotWeaponAttachment.new()
		a.id = id
		a.display_name = str(row["name"])
		a.mount = row["mount"]
		a.item_id = StringName(ITEM_PREFIX + String(id))
		a.model = MODEL_DIR + String(id) + ".tscn"
		a.scale = (row.get("scale", {}) as Dictionary).duplicate()
		a.params_set = (row.get("params", {}) as Dictionary).duplicate()
		if row.has("zoom"):
			a.params_set[DotWeaponAttachment.PARAM_ZOOM] = row["zoom"]
		a.excludes_tags.assign(row.get("excludes", []))
		out.append(a)
	return out


## The attachments as a catalogue a host validates and applies fittings with.
static func catalogue() -> DotWeaponAttachments:
	var out := DotWeaponAttachments.new()
	for a in attachments():
		out.add(a)
	return out


## [AwAttachmentArt]'s entry for [param id]: `{path, hides, aim, zoom}`, empty for an id this pack does not draw.
static func art_of(id: StringName) -> Dictionary:
	if not ROWS.has(id):
		return {}
	var row: Dictionary = ROWS[id]
	return {"path": MODEL_DIR + String(id) + ".tscn", "hides": [], "aim": row.get("aim", &""), "zoom": float(row.get("zoom", 0.0))}


## Draws the pack's attachments; idempotent.
static func register_art() -> void:
	AwAttachmentArt.add_source(SOURCE, Callable(AwAttachmentPack, &"art_of"))


## The sound class a fitted gun fires with: [constant AwWeaponSound.SUPPRESSED] when its def says so, else [param base].
static func sound_class_for(def: DotWeaponDef, base: StringName) -> StringName:
	return AwWeaponSound.SUPPRESSED if def != null and bool(def.params.get(DotWeaponAttachment.PARAM_SUPPRESSED, false)) else base
