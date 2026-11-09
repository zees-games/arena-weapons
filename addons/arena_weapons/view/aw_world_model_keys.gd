@tool
extends Node3D

## Authored motion keys of AwWorldModel, split out for file size.

# --- Authored motion ----------------------------------------------------------
#
# [b]A swing and a throw are keys here too, for the view model's reason[/b] ([AwWeaponPose]'s
# SWING_KEYS): a melee weapon has no recoil, so a watcher saw somebody's knife ride the arm's
# slash rigid in the hand, pointing where the held-gun pose points, and a grenade thrown from a
# hand that never moved. Each key is [t, position in metres, rotation in degrees (pitch up,
# yaw left, roll counter-clockwise)] in the hand's frame (-Z the way the person faces, +Y up),
# turned about the grip, on top of [method AwWeaponVisual.world_transform], read through
# [method AwWeaponPose.sample_keys]. [b]Not the view model's keys[/b]: those are in the camera's
# frame at the view model's scale, and the arm under this one already moves (the person's
# slash overlay), so these are the wrist's share only: cocked back as the arm comes up, cut
# through as it comes down, followed through and back.

## A melee swing, timed to the person's slash overlay (the arm is up at about 0.12 s and through
## by 0.3 s at the rate the family plays it).
const SWING_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.22, Vector3(0.0, 0.03, 0.04), Vector3(65.0, -15.0, -10.0)],
	[0.42, Vector3(0.0, 0.0, -0.05), Vector3(-35.0, 30.0, 20.0)],
	[0.58, Vector3(0.0, -0.02, -0.03), Vector3(-55.0, 38.0, 25.0)],
	[0.82, Vector3(0.0, 0.0, 0.0), Vector3(-15.0, 10.0, 6.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]

const SWING_SECONDS := 0.5

## A throw: the wrist cocked back as the arm swings forward, flicked through, and the weapon gone
## from [constant THROW_RELEASE] (the projectile is the game's, and a grenade still in the hand
## beside it is two grenades) until it is back in the hand at [constant THROW_BACK]. The arm is
## the person's: a thrown weapon is held with empty-handed arms, which have no throw of their
## own, so [method throw] asks the person it hangs from for the slash overlay (see
## [method _person]): up past the head and over, an overhand throw's path. Without an arm under
## it a grenade moved by keys alone floated away from a hand that stayed where it was, and the
## punch overlay punches with the other hand.
const THROW_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.20, Vector3(0.0, 0.03, 0.05), Vector3(55.0, 0.0, -8.0)],
	[0.36, Vector3(0.0, 0.02, -0.04), Vector3(-30.0, 0.0, 4.0)],
	[0.60, Vector3(0.0, 0.0, -0.03), Vector3(-40.0, 0.0, 0.0)],
	[0.85, Vector3(0.0, 0.0, 0.0), Vector3(-8.0, 0.0, 0.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]

const THROW_SECONDS := 0.55

## The fractions of a throw between which the thrown weapon is not in the hand.
const THROW_RELEASE := 0.36
const THROW_BACK := 0.9

## A watcher's reload, in the hand's frame like the swing: the gun dipped and rolled so its well faces the support
## hand, which goes from the fore-end to the well, down to the belt and back once per cycle (one reload, or one round).
const RELOAD_DIP := Vector3(0.0, -0.05, 0.03)
const RELOAD_TURN := Vector3(-18.0, 12.0, 38.0)
const RELOAD_SUPPORT_KEYS := [
	[0.0, Vector3(0.0, 0.0, 0.0), Vector3.ZERO],
	[0.25, Vector3(1.0, 0.0, 0.0), Vector3.ZERO],
	[0.5, Vector3(1.0, 1.0, 0.0), Vector3.ZERO],
	[0.75, Vector3(1.0, 0.0, 0.0), Vector3.ZERO],
	[0.9, Vector3(1.0, 0.0, 0.0), Vector3.ZERO],
	[1.0, Vector3(0.0, 0.0, 0.0), Vector3.ZERO],
]
