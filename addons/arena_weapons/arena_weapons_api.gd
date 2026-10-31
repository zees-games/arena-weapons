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
const LEVEL := 6
const OLDEST := 1
