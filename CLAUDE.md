# arena-weapons

Arena's own weapon set (definitions and CC0 models), required by game-arena, usable from game-zombie-zone. Read the family [CLAUDE.md](../../CLAUDE.md) first. [README.md](README.md) says what is in it.

## Rules

- **game-arena requires it** (a plain `.gitignore` link) and names it once, as `weapons.own` in its roles config; with it, zee's built-ins are dropped and this pack's ids are plain. Every other game finds it by scanning `addons/*/spawn_provider.gd` and gets `aw_` ids.
- **The contract is plain data**: `role_art()` (role -> `{model, muzzle, motion, view}`), `art_rows()`, `weapon_defs()`, `spawn_entries()`, `credits()`, `set_id_prefix()`. The definitions (`AwWeaponPack`) use dot-weapon only; no zee class appears in this pack. `IDS` is append-only.
- A model's origin is at the grip, its muzzle toward -Z, in metres. A new model goes through `tools/bake_models.py`, then `tools/measure_sights.py` for the muzzle and aim numbers in `AwWeaponArt.WEAPONS` (the aim puts the eye just above the gun's rear top and keeps the stock 0.15 m clear of it; zee scales a written aim with the ADS rules' `view_scale`). `tools/add_sights.py` (Blender) then adds a ring rear aperture, front post and `sight_rear`/`sight_front` marks; with marks the aim is `(0, -mark.y, ...)` and the selftest measures the mark.
- Models are CC0 (Styloo, Polyy, a knife); names are by type, never the source's. Anything new needs CC0, CC-BY or MIT, a CREDITS.md row, a `licence.json` row and an `AwWeaponArt.CREDITS` row.
- `arena_weapons_api.gd` holds the API level; raise `LEVEL` when a game could call something new.
- Grenades: `AwGrenade` steps flight and fuse on the server, `AwGrenadeBlast.detonate` returns events for the host to apply.
- Utility glue (level 5): `AwUtilityZones` (fire zones, victims, line of sight, damage through host callables), `AwBlindLedger` (seconds and strength), client `AwGrenadeFx` (needs dot-fx; its cloud scenes are in `addons/arena_weapons/fx/`). A game keeps only its adapters.
- Update `CHECKS` in `examples/aw_selftest.gd` with a new check. The hold and aim numbers are placement: look at them with game-arena's `tools/render_weapons.sh`.
- No other game or engine is named in anything public here.
