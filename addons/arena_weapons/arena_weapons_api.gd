extends RefCounted

## arena-weapons' API level. The rule for bumping it is on [DotAddonApi].
##
## LEVEL rises by one for anything a game could call that did not exist before. OLDEST is
## raised to LEVEL when something a game could have called is removed or changes meaning.

# 1: role skins (role_art, art_rows, spawn_entries, credits) and the aw_* weapon clones.
# 2: AwWeaponPack owns 24 weapon definitions with plain ids (set_id_prefix, weapon_defs), 14 new
#    models, cfg/addons/arena_weapons/weapon/<id>.yml tuning, aims that keep the stock clear of the eye.
# 3: flash, smoke and incendiary weapons; AwGrenade (flight, bounce, stick, fuse), AwGrenadeBlast (falloff, blind, smoke,
#    fire events) and AwGrenadeRules (sv_grenade_* cvars).
# 4: AwUtilityZones (victims/line-of-sight adapter, fire-zone ticker, blast events to effects), AwBlindLedger (per-victim
#    capped blind clock) and AwGrenadeFx (dot-fx smoke, fire and blind defs and visuals). Nothing removed, OLDEST stays.
# 5: the smoke and fire cloud scenes ship in fx/ and AwGrenadeFx finds them itself (fx_dir optional); AwBlindLedger.strength
#    and the effect/blind-event "strength" (0..1, distance and facing scaled) so a screen can be as white as the flash was.
# 6: sound_classes(prefix) (id -> weapon-sound class) so a host's sound table classes lmg, the launchers and prefixed ids.
# 7: sound_classes() names nine new classes (lmg, battle, marksman, carbine, derringer, mpistol, autoshot, grenade, rail),
#    each a recording of its own in dot-audio's stock; a host that fed the old classes to set_class need change nothing.
# 8: the view runtime is the pack's own: AwWeaponCatalogue, AwWeaponArtTable, AwWeaponVisual, AwViewModel, AwWorldModel,
#    AwWeaponRig, AwWeaponNet, AwShotFx, AwWeaponSound, AwAdsRules (hip_zero 20 m) and the rest, a host needs no other weapon pack.
# 9: AwFxPool (fill, fill_flashes, take_shot_fx, take_charge_fx, shared_flash): a world model's shot effects, charge ball
#    and muzzle flashes built under a loading cover and taken on first use instead of being built in the tick.
# 10: AwWeaponRig.phase_timers, phase_us, phase_calls, PHASES: opt-in sub-phase timings of simulate_tick for a profiler.
# 11: AwShotFx.NO_IMPACT_GROUP and draws_impact: a shot on the sky (that group, or meta hull_kind "sky") draws no impact.
# 12: AwShotFx.round_profile, ROUNDS (tracer width, length and impact size per sound class), impact_stream and surface_of
#     (impact sound per surface and flesh), play_impact(at, normal, collider, weapon_class, shape).
# 13: AwModelCache.add_fallback_root / remove_fallback_root / fallback_roots / exists: a build without the addon's models (the web shell) draws them
#     from a mounted pack laid out like addons/arena_weapons/assets/.
const LEVEL := 13
const OLDEST := 1
