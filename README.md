# arena-weapons

Arena's whole weapon set: its own weapon definitions (stats, ammunition, reloads, view and aim holds) and the models they wear, from [Styloo's Guns Asset Pack](https://styloo.itch.io/guns-asset-pack), Polyy's two low-poly gun packs and a CC0 knife, all CC0, baked to the family's model contract (origin at the grip, muzzle toward -Z, metres). On `zees-games`; dot-cloud pack id `gamemann/arena-weapons`.

**game-arena requires it**: it registers this pack under plain ids (`rifle`, not `aw_rifle`) and drops zee-dot-weapons' built-in weapons. A host that mixes packs (game-zombie-zone, game-playground) reads `weapon_defs()`, `art_rows()` and `spawn_entries()` and gets `aw_`-prefixed ids; `role_art()` still dresses a host's own weapons by role. Every stat is tunable per weapon in `cfg/addons/arena_weapons/weapon/<id>.yml` (dot-weapon's `DotWeaponProfiles`).

| Slot | Weapons (id: model) |
| --- | --- |
| 1 melee | `knife` |
| 2 sidearm | `pistol`, `revolver`, `machine_pistol`, `derringer` |
| 3 primary | `smg`, `carbine`, `rifle`, `bullpup`, `battle_rifle`, `burst_rifle`, `shotgun` (`pump_shotgun`), `drum_shotgun`, `marksman`, `lmg` |
| 4 heavy | `sniper` (`sniper_rifle`), `minigun`, `launcher` (`rocket_launcher`), `quad_launcher`, `grenade_launcher`, `beamer` (`plasma_rifle`), `charge_rifle` (`rail_rifle`) |
| 5 thrown | `frag` (`frag_grenade`), `sticky` (`frag_grenade_alt`) |

Equipment models shipped for a host's pickups and effects, with no weapon behind them yet: `flash_grenade`, `smoke_grenade`, `incendiary_grenade`, `ammo_box`, `rocket_launcher_alt` and four rounds.

The models use flat emission-style colour (the pack's own advice: not a metallic-roughness workflow), so they ignore scene lighting. The "emission version" is the one shipped.

## Layout

`addons/arena_weapons/`: `aw_weapon_pack.gd` (`AwWeaponPack`, the weapon definitions), `aw_weapon_art.gd` (`AwWeaponArt`, the only file with a model name), `spawn_provider.gd` (`AwSpawnProvider`, the host contract), `assets/models/*.glb`. `tools/bake_models.py` (Blender) makes the models from the source packs' folders, `tools/measure_sights.py` measures the muzzle, sight point and aim hold that go in the table. `examples/aw_selftest.tscn` is the headless suite (`./game.sh test`).

## Credits

See [CREDITS.md](CREDITS.md). The models are CC0 1.0; the code in this repository is MIT.

## Utility grenade glue (API level 5)

`AwUtilityZones` is the server side of flash, smoke and incendiary grenades, driven by the host: call `detonate(grenade, def)` when one goes off and `tick(delta)` once per game tick. The game plugs its combat in through callables (`victims`, `los` built with `AwUtilityZones.los_from_ray`, `damage`), so friendly fire and armour stay the game's rules. It runs the fire zones, keeps `AwBlindLedger` (one capped end time per victim) and emits `effect({fx, position, radius, seconds, victim})`. On the client `AwGrenadeFx.add_defs(catalogue)` registers the dot-fx smoke, fire and blind defs and `AwGrenadeFx.show(fx, tree, info, own_id)` plays an effect; the cloud scenes `fx/smoke_cloud.tscn` and `fx/fire_cloud.tscn` ship in the addon (plain scenes with generated soft-sprite gradients, no art files, so nothing in the content pack changes); pass a folder as `fx_dir` only to override them. `AwBlindLedger.strength(victim)` and the `strength` of a blind event (0 to 1, distance and facing scaled) say how hard a flash hit, and `AwGrenadeFx.show` makes the screen flash that strong. Needs dot-fx linked.
