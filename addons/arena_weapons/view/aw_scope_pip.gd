class_name AwScopePip
extends Node3D

## A scope seen through, unaimed: a picture-in-picture lens on the scope of a scoped weapon held at the hip.
##
## A small [SubViewport] with its own camera looks down the barrel from the lens, a little magnified, and a disc
## on the lens shows it with a faint vignette and reticle. It fades out as the aim-in approaches, where the
## full-screen [AwScopeOverlay] takes over.
##
## [b]Cheap on purpose[/b], for a 16v16 arena that is already CPU-bound: a low-resolution target, redrawn at
## [member rate_hz] and not every frame, no MSAA or shadow atlas, the heavy post effects off, and not drawn at all
## while the lens is off screen, the weapon is lowered or sprinting, or the aim is nearly in. It is never built
## headless (a server, a test run).

## Game setting: off builds nothing and draws nothing.
static var enabled: bool = true

## How often the picture is redrawn, per second.
static var rate_hz: float = 15.0

## Side of the square render target, in pixels.
static var resolution: int = 192

## How much of the aim's zoom the lens shows at the hip: 0 none, 1 all of it.
const MAGNIFY := 0.6

## Aim fraction the lens has fully faded out by.
const FADE_END := 0.8

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform sampler2D view_tex : source_color, filter_linear;
uniform float amount = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 c = texture(view_tex, UV).rgb;
	c *= mix(0.3, 1.0, smoothstep(1.0, 0.3, r));
	float bar = (1.0 - smoothstep(0.012, 0.028, abs(p.x))) * step(abs(p.y), 0.72);
	bar = max(bar, (1.0 - smoothstep(0.012, 0.028, abs(p.y))) * step(abs(p.x), 0.72));
	c = mix(c, vec3(0.02), 0.4 * bar);
	float rim = smoothstep(0.86, 0.98, r);
	c = mix(c, vec3(0.02, 0.025, 0.03), rim);
	ALBEDO = c;
	ALPHA = amount * (1.0 - smoothstep(0.97, 1.0, r));
}
"""

static var _shader: Shader

var _viewport: SubViewport
var _camera: Camera3D
var _lens: MeshInstance3D
var _material: ShaderMaterial
var _zoom: float = 1.0
var _clock: float = 1000.0
var _env_done: bool = false
var _drawing: bool = false


## Whether this process can draw a picture-in-picture lens at all: a real display and the setting on.
static func available() -> bool:
	return enabled and DisplayServer.get_name() != "headless" and not Engine.is_editor_hint()


## Builds a lens for [param lens] (`{"pos": Vector3, "radius": float}` in the weapon's model space), or null when
## there is none to build or this process cannot draw one. [param layer] is the view model's render layer (1 to 20).
static func create(lens: Dictionary, layer: int, zoom: float) -> AwScopePip:
	if not available() or lens.is_empty() or not lens.has("pos"):
		return null
	var pip := AwScopePip.new()
	pip.name = "ScopePip"
	pip._build(lens, layer, zoom)
	return pip


func _build(lens: Dictionary, layer: int, zoom: float) -> void:
	_zoom = clampf(zoom, 0.1, 1.0)
	var side := clampi(resolution, 64, 512)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(side, side)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.positional_shadow_atlas_size = 0
	_viewport.mesh_lod_threshold = 6.0
	_viewport.audio_listener_enable_3d = false
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.near = 0.1
	_camera.far = 400.0
	# Everything the player's camera sees but the view model itself.
	_camera.cull_mask = 0xFFFFF if layer <= 0 else (0xFFFFF & ~(1 << (layer - 1)))
	_viewport.add_child(_camera)
	_camera.current = true

	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.render_priority = 8
	_material.set_shader_parameter("view_tex", _viewport.get_texture())

	var radius := float(lens.get("radius", 0.02))
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	_lens = MeshInstance3D.new()
	_lens.name = "Lens"
	_lens.mesh = quad
	_lens.material_override = _material
	_lens.position = lens["pos"]
	_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if layer > 0:
		_lens.layers = 1 << (layer - 1)
	_lens.visible = false
	add_child(_lens)


## Where the lens sits, in the parent's space (the weapon's model space).
func lens_position() -> Vector3:
	return _lens.position if _lens != null else Vector3.ZERO


## Whether the lens is drawn and its picture is being redrawn this frame.
func is_drawing() -> bool:
	return _drawing


## The render target, for a test.
func viewport() -> SubViewport:
	return _viewport


## Call every frame. [param wanted] is false while the weapon is lowered, sprinting or scoped in; [param aim] is
## the aim fraction (0 at the hip, 1 aimed), which fades the lens out; [param camera] is the player's camera.
func tick(delta: float, camera: Camera3D, wanted: bool, aim: float) -> void:
	if _lens == null:
		return
	var amount := 1.0 - smoothstep(0.35, FADE_END, aim)
	var on := enabled and wanted and amount > 0.02 and camera != null and is_inside_tree()
	if on:
		var at := _lens.global_position
		on = not camera.is_position_behind(at) and camera.is_position_in_frustum(at)
	_drawing = on
	_lens.visible = on
	if not on:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_clock = 1000.0
		return

	_material.set_shader_parameter("amount", amount)
	_clock += delta
	if _clock < 1.0 / maxf(rate_hz, 1.0):
		return
	_clock = 0.0
	if not _env_done:
		_env_done = true
		_camera.environment = _cheap_environment(camera)
	var basis := _lens.global_transform.basis.orthonormalized()
	_camera.global_transform = Transform3D(basis, _lens.global_position)
	_camera.fov = clampf(camera.fov * lerpf(1.0, _zoom, MAGNIFY), 5.0, 120.0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## The world's environment without the effects that cost a frame each: SSAO, SSIL, SSR, SDFGI, glow, volumetric fog.
func _cheap_environment(camera: Camera3D) -> Environment:
	var source := camera.environment
	if source == null and camera.get_world_3d() != null:
		source = camera.get_world_3d().environment
	if source == null:
		return null
	var env := source.duplicate() as Environment
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.glow_enabled = false
	env.volumetric_fog_enabled = false
	return env
