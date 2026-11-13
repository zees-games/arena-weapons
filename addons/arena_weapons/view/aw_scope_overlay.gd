@tool
class_name AwScopeOverlay
extends "res://addons/dot_weapon/view/dot_weapon_scope_overlay.gd"

## What a player sees through a scope; the drawing and the exports live in dot-weapon's shared
## overlay (`view/dot_weapon_scope_overlay.gd`), which zee-dot-weapons' [ZeeScopeOverlay] also
## extends. A game puts one of these in its HUD and calls [method follow] with its [AwViewModel]
## each frame.

var _own_style: Dictionary = {}

## Where the lens and reticle sit off centre, in lens radii (x right, y down); [method follow] takes it from the view.
var motion := Vector2.ZERO

## Takes the view's state, then sets the lens camera so the glass magnifies: the shared overlay
## spreads the zoomed camera's whole frame over the lens, which on screen is barely bigger than the hip view.
func follow(view: Object) -> void:
	# A weapon's style keys go back to the overlay's own values first, so the next gun does not keep the last one's look.
	var style: Dictionary = view.scope_style()
	for key: Variant in style:
		if key is String and key in self and not _own_style.has(key):
			_own_style[key] = get(key)
	for key: String in _own_style:
		set(key, _own_style[key])
	super.follow(view)
	if is_instance_valid(_source) and size.y > 0.0:
		var share := minf(size.x, size.y) * lens_circle * lens_scale / size.y
		lens_zoom = lens_fov_share(_source.fov, view.aim_fov_scale(), share)
	var moved: Vector2 = view.scope_offset() if view.has_method(&"scope_offset") else Vector2.ZERO
	if not moved.is_equal_approx(motion):
		motion = moved
		queue_redraw()


## The shared drawing, shifted by [member motion]: lens, rim and reticle move as one, as a scope
## tube does in the hands. A full-screen scope's surround is widened so no edge shows through.
func _draw() -> void:
	var shift := motion * minf(size.x, size.y) * 0.5 * lens_scale * (lens_circle if mode == 1 else circle)
	if shift.is_zero_approx() or fraction <= 0.0 or clear >= 1.0:
		super._draw()
		return
	if mode == 2:
		var surround := Color(surround_colour, surround_colour.a * fraction * (1.0 - clear))
		draw_rect(Rect2(0.0 if shift.x > 0.0 else size.x + shift.x, 0.0, absf(shift.x), size.y), surround)
		draw_rect(Rect2(0.0, 0.0 if shift.y > 0.0 else size.y + shift.y, size.x, absf(shift.y)), surround)
	draw_set_transform(shift)
	super._draw()
	draw_set_transform(Vector2.ZERO)


## The share of the main camera's [param fov] (vertical degrees) the lens camera takes so a lens
## [param share] of the screen's height tall shows the world [param zoom] times the hip view's size.
static func lens_fov_share(fov: float, zoom: float, share: float) -> float:
	if fov <= 0.0 or fov >= 179.0:
		return zoom
	var half := tan(deg_to_rad(fov) * 0.5) * zoom * share
	return rad_to_deg(2.0 * atan(half)) / fov
