extends Node

## Headless suite for the weapon's motion while aimed: the strafe trail, the walk bob and the
## kick each keep their mp_vm_ads_* share at full aim, the hip is untouched by them, and a scope's
## lens shifts with a strafe and shakes with the walk and a shot. Run: godot --headless --path . res://examples/aw_selftest_ads.tscn

const STEP := 1.0 / 144.0

var _checks := 0
var _failures := 0


## Stands in for an [AwViewModel] at full scope, for [method AwScopeOverlay.follow].
class ScopedView:
	extends RefCounted
	var offset := Vector2.ZERO
	func scope_fraction() -> float: return 1.0
	func scope_lens_scale() -> float: return 1.0
	func aim_fov_scale() -> float: return 0.25
	func scope_style() -> Dictionary: return {}
	func scope_offset() -> Vector2: return offset


func _ready() -> void:
	print("fc-weapons aimed-motion self-test")
	_cvars()
	_strafe()
	_bob()
	_kick()
	_scope()
	_cost()
	print("")
	print("%d checks, %d failed" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  %s %s%s" % ["ok  " if ok else "FAIL", label, "" if detail == "" else " (%s)" % detail])


func _pose(aim: float, feel: AwViewFeel = null) -> AwWeaponPose:
	var pose := AwWeaponPose.make()
	if feel != null:
		pose.rules = feel
	pose.set_aim(aim)
	return pose


## Runs [param pose] for [param seconds] at a ground speed and sideways speed; returns the lowest and highest drawn x and y.
func _run(pose: AwWeaponPose, seconds: float, speed: float, strafe: float) -> Rect2:
	var low := Vector2(INF, INF)
	var high := -low
	for i in int(seconds / STEP):
		pose.advance(STEP, Vector2.ZERO, speed, true, false, strafe)
		var at := pose.offset().origin
		low = low.min(Vector2(at.x, at.y))
		high = high.max(Vector2(at.x, at.y))
	return Rect2(low, high - low)


func _cvars() -> void:
	var feel := AwViewFeel.new()
	_check("aimed shares default to kick 0.8, strafe 0.4, bob 0.5", is_equal_approx(feel.ads_kick, 0.8) and is_equal_approx(feel.ads_strafe, 0.4) and is_equal_approx(feel.ads_bob, 0.5))
	var names := feel.cvar_specs().map(func(s: Dictionary) -> String: return s["name"])
	_check("the aimed and scope cvars are registered", ["mp_vm_ads_kick", "mp_vm_ads_strafe", "mp_vm_ads_bob", "mp_vm_scope_sway", "mp_vm_scope_shake"].all(func(n: String) -> bool: return n in names))
	var set_all := feel.set_cvar("mp_vm_ads_kick", "0.5") and feel.set_cvar("mp_vm_ads_strafe", "0.2") and feel.set_cvar("mp_vm_ads_bob", "0") \
		and feel.set_cvar("mp_vm_scope_sway", "2") and feel.set_cvar("mp_vm_scope_shake", "0.5")
	_check("set_cvar applies each", set_all and feel.ads_kick == 0.5 and feel.ads_strafe == 0.2 and feel.ads_bob == 0.0 and feel.scope_sway == 2.0 and feel.scope_shake == 0.5)
	_check("a share above 1 is refused", not feel.set_cvar("mp_vm_ads_strafe", "1.5") and feel.ads_strafe == 0.2)


func _strafe() -> void:
	var hip_run := _run(_pose(0.0), 1.5, 0.0, 6.0)
	var hip := hip_run.end.x
	var trail := _run(_pose(1.0), 1.5, 0.0, 6.0).position.x
	_check("aimed, a strafe right still shifts the gun left", trail < -0.002, "%.4f m" % trail)
	_check("by the mp_vm_ads_strafe share of the hip trail", hip_run.position.x < 0.0 and absf(trail / hip_run.position.x - 0.4) < 0.05,
		"%.4f against %.4f" % [trail, hip_run.position.x])
	var still := AwViewFeel.new()
	still.ads_strafe = 0.0
	_check("mp_vm_ads_strafe 0 holds the aimed gun still sideways", absf(_run(_pose(1.0, still), 1.5, 0.0, 6.0).position.x) < 0.0005)
	_check("at the hip the aimed shares change nothing", is_equal_approx(_run(_pose(0.0, still), 1.5, 0.0, 6.0).end.x, hip))


func _bob() -> void:
	var hip := _run(_pose(0.0), 3.0, 5.0, 0.0).size.y
	var aimed := _run(_pose(1.0), 3.0, 5.0, 0.0).size.y
	_check("aimed, walking still bobs the gun", aimed > 0.002, "%.4f m" % aimed)
	_check("by about the mp_vm_ads_bob share of the hip bob", hip > 0.0 and absf(aimed / hip - 0.5) < 0.08, "%.4f against %.4f" % [aimed, hip])


func _kick() -> void:
	var climbs: Array[float] = []
	for aim: float in [0.0, 1.0]:
		var pose := _pose(aim)
		pose.punch(Vector2(2.0, 0.0))
		var peak := 0.0
		for i in 30:
			pose.advance(STEP, Vector2.ZERO, 0.0, true)
			peak = maxf(peak, absf(pose.offset().basis.get_euler().x))
		climbs.append(peak)
	_check("aimed, the drawn kick keeps about the mp_vm_ads_kick share", climbs[0] > 0.0 and absf(climbs[1] / climbs[0] - 0.8) < 0.08, "%.4f against %.4f rad" % [climbs[1], climbs[0]])


func _scope() -> void:
	var rest := _pose(1.0)
	_check("a scope at rest sits centred", rest.scope_offset() == Vector2.ZERO)
	var strafing := _pose(1.0)
	var _r := _run(strafing, 1.5, 0.0, 6.0)
	var side := strafing.scope_offset()
	_check("a strafe right shifts the scope left", side.x < -0.03 and side.x > -0.1, "%.3f radii" % side.x)
	var walking := _pose(1.0)
	var low := INF
	var high := -INF
	for i in int(2.0 / STEP):
		walking.advance(STEP, Vector2.ZERO, 5.0, true)
		low = minf(low, walking.scope_offset().y)
		high = maxf(high, walking.scope_offset().y)
	_check("walking shakes it a little up and down", high - low > 0.005 and high - low < 0.08, "%.3f radii" % (high - low))
	var shot := _pose(1.0)
	shot.punch(Vector2(2.0, 0.0))
	shot.advance(STEP * 4.0, Vector2.ZERO, 0.0, true)
	_check("a shot lifts it", shot.scope_offset().y < -0.005, "%.3f radii" % shot.scope_offset().y)
	var held := AwViewFeel.new()
	held.scope_sway = 0.0
	held.scope_shake = 0.0
	var calm := _pose(1.0, held)
	_r = _run(calm, 1.5, 5.0, 6.0)
	calm.punch(Vector2(2.0, 0.0))
	calm.advance(STEP, Vector2.ZERO, 5.0, true, false, 6.0)
	_check("mp_vm_scope_sway and mp_vm_scope_shake 0 hold it centred", calm.scope_offset().is_zero_approx())

	var overlay := AwScopeOverlay.new()
	var view := ScopedView.new()
	view.offset = Vector2(-0.05, 0.02)
	overlay.follow(view)
	_check("the overlay takes the view's scope offset", overlay.motion == view.offset)
	overlay.free()


## Everything aimed motion adds is a few sums a frame: a pose frame stays far under 0.3 ms.
func _cost() -> void:
	var pose := _pose(1.0)
	var frames := 2000
	var started := Time.get_ticks_usec()
	for i in frames:
		pose.advance(STEP, Vector2(0.3, 0.1), 5.0, true, false, 4.0)
		var _o := pose.offset()
		var _s := pose.scope_offset()
	var each := float(Time.get_ticks_usec() - started) / float(frames)
	_check("a pose frame with the scope offset costs under 0.3 ms", each < 300.0, "%.1f us" % each)
