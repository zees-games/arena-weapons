# fc-weapons

Arena's whole weapon set (the game players know as Zee's Fatal Contact): its own weapon definitions (stats, ammunition, reloads, view and aim holds) and the models they wear, from [Styloo's Guns Asset Pack](https://styloo.itch.io/guns-asset-pack), Polyy's two low-poly gun packs and a CC0 knife, all CC0, baked to the family's model contract (origin at the grip, muzzle toward -Z, metres). On `zees-games`; dot-cloud pack id `gamemann/fc-weapons` (published as `gamemann/arena-weapons` up to v1.3.x; the addon directory stays `addons/arena_weapons` and its classes keep the `Aw` prefix, since every game loads it by that path).

**game-fatal-contact requires it**: it registers this pack under plain ids (`rifle`, not `aw_rifle`) and runs them on this pack's own runtime (`Aw*`: rig, view model, world model, net, shot effects, art registry, ADS rules); it links no other weapon addon. A host that mixes packs (game-zombie-zone, game-playlot) reads `weapon_defs()`, `art_rows()` and `spawn_entries()` and gets `aw_`-prefixed ids; `role_art()` still dresses a host's own weapons by role. Every stat is tunable per weapon in `cfg/addons/arena_weapons/weapon/<id>.yml` (dot-weapon's `DotWeaponProfiles`).

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

`addons/arena_weapons/`: `aw_weapon_pack.gd` (`AwWeaponPack`, the weapon definitions), `aw_weapon_art.gd` (`AwWeaponArt`, the only file with a model name), `spawn_provider.gd` (`AwSpawnProvider`, the host contract), `assets/models/*.glb`. `tools/bake_models.py` (Blender) makes the models from the source packs' folders, `tools/measure_sights.py` measures the muzzle, sight point and aim hold that go in the table. `examples/aw_selftest.tscn` is the headless suite (`./game.sh test`); `examples/aw_selftest_ads.tscn` checks the motion down the sights and through a scope.

A build that leaves `addons/arena_weapons/assets/` out (the web shell, to stay small) can draw the models from a mounted pack laid out the same way: `AwModelCache.add_fallback_root("res://dot_cloud/<id>/<version>/addons/arena_weapons/assets")` after the mount, `remove_fallback_root` when leaving. Until then each weapon still fires and is drawn invisible (one WARN per model).

## Fire modes

Every automatic gun also fires semi, and the submachine guns, carbines and rifles burst as well, declared in `fire_modes` (first entry is the starting mode) and tunable per weapon in the profile. The host binds `DotWeaponCommand.BUTTON_FIRE_MODE`; a game plays the click (zee-dot-weapons ships three).

## Credits

See [CREDITS.md](CREDITS.md). The models are CC0 1.0; the code in this repository is MIT.

## Utility grenade glue (API level 5)

`AwUtilityZones` is the server side of flash, smoke and incendiary grenades, driven by the host: call `detonate(grenade, def)` when one goes off and `tick(delta)` once per game tick. The game plugs its combat in through callables (`victims`, `los` built with `AwUtilityZones.los_from_ray`, `damage`), so friendly fire and armour stay the game's rules. It runs the fire zones, keeps `AwBlindLedger` (one capped end time per victim) and emits `effect({fx, position, radius, seconds, victim})`. On the client `AwGrenadeFx.add_defs(catalogue)` registers the dot-fx smoke, fire and blind defs and `AwGrenadeFx.show(fx, tree, info, own_id)` plays an effect; the cloud scenes `fx/smoke_cloud.tscn` and `fx/fire_cloud.tscn` ship in the addon (plain scenes with generated soft-sprite gradients, no art files, so nothing in the content pack changes); pass a folder as `fx_dir` only to override them. `AwBlindLedger.strength(victim)` and the `strength` of a blind event (0 to 1, distance and facing scaled) say how hard a flash hit, and `AwGrenadeFx.show` makes the screen flash that strong. Needs dot-fx linked.

## Sounds (API level 7)

The pack ships no audio. Guns play dot-audio's CC0 weapon stock by sound class (sources, authors and licences in dot-audio's `stock/CREDITS.md`). `AwSpawnProvider.sound_classes()` gives each gun's class as plain data (`lmg`, the battle and burst rifles, marksman, carbine, derringer, machine pistol, drum shotgun, grenade launcher and charge rifle each have a recording of their own; prefixed ids included); the host feeds each pair to its weapon-sound table (`AwWeaponSound.set_class`). Reload, dry click and equip follow the class too. The authors and licences of every sound (KuraiWolf, Tabasco, Michel Baradari, cyklon698, celestialghost8, TAD, Zane Little Music, jc-sounds; all CC0 or CC-BY) are in dot-audio's `stock/CREDITS.md`, and are repeated in [CREDITS.md](CREDITS.md).

## Effects pool (API level 9)

Another player's hand used to build its effects on its first shot or charge, inside the tick. `AwFxPool` builds them ahead: add one to the tree under your loading cover, call `fill(shots, charges)` each frame until it answers true and `fill_flashes()` once, and wait for `flashes_ready()`. From then on `AwWorldModel` takes its `AwShotFx` and charge ball from the pool and every remote shot draws one of a few shared muzzle flashes. An empty or missing pool is not an error: the world model builds its own as before. Hands freed with a map take their effects with them, so fill again under the next cover. First-person effects and everything a shot decides are untouched.

## Layered shot sound ahead of time (API level 15)

The first shot of a gun with a layered sound (the knife among them) built dot-audio's layer manager, room and player inside the tick: 61 ms on a GPU box. `AwShotFx.prewarm_layers()` builds them now; call it on the local hand's shot effects under your loading cover. It answers true when layered shots are on and ready, false when they are off or dot-audio is missing, and is safe to call again. A game that never calls it gets the old first-shot build.

Somebody else's gun shares one layered shot: `AwFxPool.fill` builds it on the pool's `layers_bus` (empty builds none) after the parked effects, and each remote `AwShotFx` takes it (`AwFxPool.shared_layers`) instead of building its own on its first shot. It follows the viewport's camera for the room.

The first equip of a gun in play no longer measures its sight or reads its textures: the sight line is cached per model and placement, and a prewarm on an armless view still reads the gun's texture means the glove fit asks for.

## Download groups (API level 14)

`groups.json` at the pack root puts each weapon's model, its textures and their imported outputs in one group, `weapon-<id>` (`AwWeaponGroups.group_of`). The knife and pistol, the default loadout, and the shared props stay ungrouped, so a client that asks for no groups still draws them. A web shell sets `DotCloudAddonSet.groups` to `AwWeaponGroups.groups_for(ids)` of the weapons a game's loadout can hand out; with no groups set dot-cloud's default `"*"` fetches every weapon. A deferred group cannot be topped up at runtime (the overlay is built once), so a game must list every weapon it can give a player.

## Attachments (API level 19)

Ten attachments, each its own item (`att_<id>`) with its own model (own work, `tools/make_attachments.gd`): red dot, holographic, 3x prism, 6x scope, suppressor, compensator, vertical and angled grips, laser, extended magazine. Each gun's `def.mounts` lists the mounts its model has (`AwAttachmentSockets`, measured by `tools/measure_sockets.gd`); a gun with a built-in sight has no optic mount, a launcher none. The host builds `AwSpawnProvider.attachment_defs()` once (it also draws them), checks a requested fitting with `validate_fitting` on the server, applies it to the gun's def, and replicates it with `encode`/`decode`; `AwSpawnProvider.sound_class_for(def, class)` gives a suppressed gun its quiet report. A fitted optic sets the aimed zoom and sight line in the view model (`AwViewModel.set_fitting`).

## Inspect and holster (API level 21)

`AwViewModel.inspect()` plays a 2.6 s look-over of the gun in hand (`AwWeaponPose` inspect keys, `inspect_fraction()` 0 to 1); fire, aim, reload, a recoil kick or a switch cut it short in 0.2 s (`cancel_inspect()`). It moves the view only; the rig, the shot and the net never see it. The holster has its own keys (`HOLSTER_KEYS`), a slightly front-loaded drop instead of the draw played backwards, so a 0.1 s holster does not carry its whole move in one frame.
