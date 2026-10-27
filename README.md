# arena-weapons

Arena's weapon models: [Styloo's Guns Asset Pack](https://styloo.itch.io/guns-asset-pack) (CC0, low-poly), renamed by type and baked to the family's model contract (origin at the grip, muzzle toward -Z, metres). On `zees-games`; dot-cloud pack id `gamemann/arena-weapons`.

**Optional and swappable.** A game that loads weapons by role (game-arena) asks every installed pack's `addons/<name>/spawn_provider.gd` for `role_art()` and dresses its own weapons with the model of the same role; with this pack absent, or another pack in its place, nothing in the game changes but the models. A host that lists pack weapons (game-zombie-zone, game-playground) reads `weapon_defs()`, `art_rows()` and `spawn_entries()`: this pack offers `aw_pistol`, `aw_smg`, `aw_carbine`, `aw_rifle`, `aw_shotgun`, `aw_sniper`, `aw_launcher`, `aw_quad_launcher` and `aw_frag`, cloned from the host's own weapon of that role so the numbers are the host's.

| Role | Model | Length |
| --- | --- | --- |
| pistol | `pistol.glb` | 0.19 m |
| smg | `smg.glb` | 0.27 m |
| carbine / rifle | `carbine.glb` / `rifle.glb` | 0.63 / 0.85 m |
| shotgun | `pump_shotgun.glb` | 0.89 m |
| sniper | `sniper_rifle.glb` | 1.13 m |
| launcher / quad_launcher | `rocket_launcher.glb` / `quad_rocket_launcher.glb` | 1.18 / 0.85 m |
| frag | `frag_grenade.glb` | 0.11 m |

Also shipped, with no weapon yet: `rocket_launcher_alt`, `frag_grenade_alt`, `flash_grenade`, `smoke_grenade`, `incendiary_grenade`, `ammo_box`, `round_pistol`, `round_rifle`, `round_shell`, `round_sniper`. Not covered, and left to other packs: revolver, LMG, double-barrel, melee.

The models use flat emission-style colour (the pack's own advice: not a metallic-roughness workflow), so they ignore scene lighting. The "emission version" is the one shipped.

## Layout

`addons/arena_weapons/`: `aw_weapon_art.gd` (`AwWeaponArt`, the only file with a model name), `spawn_provider.gd` (`AwSpawnProvider`, the host contract), `assets/models/*.glb`. `tools/bake_models.py` (Blender) makes the models from the pack's GLB folder, `tools/measure_sights.py` measures the muzzle and sight point that go in the table. `examples/aw_selftest.tscn` is the headless suite (`./game.sh test`).

## Credits

See [CREDITS.md](CREDITS.md). The models are CC0 1.0 (the page states Creative Commons Zero v1.0 Universal; no generative AI); the code in this repository is MIT.
