# arena-weapons

Styloo's CC0 guns as a swappable weapon-model pack for game-arena (and usable from game-zombie-zone). Read the family [CLAUDE.md](../../CLAUDE.md) first. [README.md](README.md) says what is in it.

## Rules

- **The pack is optional for every game.** Nothing in a game may name it; a game finds it by scanning `addons/*/spawn_provider.gd`. A game lists it in its `.gitignore` as `/addons/arena_weapons` under a `# bootstrap-optional` line, so bootstrap links it, `--min` leaves it out and `game.sh` does not require it.
- **The contract is plain data**: `role_art()` (role -> `{model, muzzle, motion, view}`), `art_rows()`, `weapon_defs()`, `spawn_entries()`, `credits()`. No zee class appears in a signature or at parse time; `weapon_defs()` loads zee-dot-weapons by path and returns nothing without it.
- A model's origin is at the grip, its muzzle toward -Z, in metres. A new model goes through `tools/bake_models.py`, then `tools/measure_sights.py` for the muzzle and aim numbers in `AwWeaponArt.ROLES`.
- Models are Styloo's, CC0, from the zip's emission folder; names are by type, never the source's. Anything else needs CC0 or CC-BY and a CREDITS.md row.
- Update `CHECKS` in `examples/aw_selftest.gd` with a new check. The hold and aim numbers are placement: look at them with game-arena's `tools/render_weapons.sh`.
- No other game or engine is named in anything public here.
