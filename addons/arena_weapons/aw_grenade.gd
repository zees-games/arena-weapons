class_name AwGrenade
extends RefCounted

## One thrown grenade, stepped by the server a tick at a time: gravity, bounce, stick, fuse.
## Pure data in, data out, so a host flies it in its own world through the [code]trace[/code] callable.

const FRAG := &"frag"
const FLASH := &"flash"
const SMOKE := &"smoke"
const FIRE := &"incendiary"

var kind: StringName = FRAG
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var fuse: int = 0
var owner_entity: int = 0
var spawn: DotWeaponSpawn = null
var stuck := false
var gravity: float = 9.8
var explode_on_impact := false
var sticks := false
var bounces := 0
var rules: AwGrenadeRules = null


## [param def] supplies the kind and flags; a spawn from DotWeaponThrown carries the fuse left after cooking.
static func from_spawn(s: DotWeaponSpawn, def: DotWeaponDef, p_rules: AwGrenadeRules = null) -> AwGrenade:
	var g := AwGrenade.new()
	g.spawn = s
	g.rules = p_rules if p_rules != null else AwGrenadeRules.new()
	g.kind = StringName(def.params.get(&"kind", FRAG))
	g.explode_on_impact = bool(def.params.get(&"explode_on_impact", false))
	g.sticks = bool(def.params.get(&"sticks", false))
	g.position = s.origin
	g.velocity = s.velocity
	g.fuse = s.fuse_ticks
	g.owner_entity = s.owner_entity
	g.gravity = 9.8 * s.gravity_scale
	return g


## True once it went off. [param trace] is `(from, to) -> {}` for clear air or `{position, normal}` for a hit.
func step(trace: Callable, tick_rate: int) -> bool:
	if fuse <= 0 and spawn.velocity == Vector3.ZERO:
		return true
	var dt := 1.0 / float(tick_rate)
	fuse -= 1

	if not stuck:
		velocity.y -= gravity * dt
		var to := position + velocity * dt
		var hit: Dictionary = trace.call(position, to)
		if hit.is_empty():
			position = to
		else:
			position = hit["position"]
			bounces += 1
			if explode_on_impact:
				return true
			if sticks:
				stuck = true
				velocity = Vector3.ZERO
			else:
				_bounce(hit["normal"])

	return fuse <= 0


func _bounce(normal: Vector3) -> void:
	var along := normal * velocity.dot(normal)
	velocity = (velocity - along) * rules.friction - along * rules.bounce
	position += normal * 0.02
	if velocity.length() < 0.5:
		velocity = Vector3.ZERO
