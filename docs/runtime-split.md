# arena-weapons as its own runtime: the split from zee-dot-weapons

Today arena-weapons is definitions and art data (about 1,600 lines); everything that draws, animates, sounds and replicates a weapon in game-arena is zee-dot-weapons' runtime (about 12,000 lines), and game-arena names `Zee*` classes about 300 times in 35 files. The decision: arena-weapons runs on the family's own base (dot-weapon, dot-profile, and a shared view addon), with no zee-dot-weapons on disk; zee-dot-weapons stays the pack the smaller games use.

## The rule that decides each piece

Anything a second weapon pack would need goes into one shared addon, never into both packs. Anything that names a particular weapon, model file or damage type stays with the pack that owns it.

## What moves where

| Piece (zee file today) | Generic? | Goes to |
| --- | --- | --- |
| `runtime/zee_weapon_rig*.gd`, `zee_weapon_input.gd` (drives a `DotWeaponArsenal`, the bash, the snapshot) | yes; only `ZeeWeaponPack.catalogue()`, `ZeeWeaponIds.all()` and `ZeeWeaponArtTable.table()` tie it to zee | **dot-weapon-view**: `DotWeaponRig`, `DotWeaponInput`; catalogue, id list and art lookup handed in |
| `behaviour/zee_weapon_bash.gd` | yes (damage type handed in) | dot-weapon-view `DotWeaponBash` |
| `view/` view model, arms, rigged arm, glove, hand reach, hip hold, pose and pose keys, view feel, wall slam, finish, iron sight, own sight, sight fit, reload parts, scope overlay, attachment dress | yes; three calls into the art table's per-pose tables | dot-weapon-view; the per-pose tables (`sprint_view`, `sprint_bob`, `reload_keys`, `pose_world_factor`, `pose_two_handed`) move with them, a pack only names a pose |
| `view/zee_world_model.gd`, `net/zee_weapon_net.gd` | yes | dot-weapon-view `DotWeaponWorldModel`, `DotWeaponNet` |
| `view/zee_shot_fx*.gd`, `zee_weapon_sound.gd` | the engine yes; the id-to-sound-class table no | engine to dot-weapon-view; each pack's art row names its sound class (`sound: rifle`) |
| `art/zee_weapon_art.gd`, `zee_model_cache.gd`, `zee_art_dress.gd`, `zee_art_listing.gd`, `zee_attachment_art.gd`, the registry half of `zee_weapon_art_table.gd` (`add_source`, `table`, `get_art`) | yes | dot-weapon-view `DotWeaponArt`, `DotWeaponModelCache`, `DotWeaponArtRegistry`; the arms models (CC0) move with the arms |
| `content/zee_ads_rules.gd`, `zee_weapon_cards.gd`, `view/zee_weapon_preview.gd` | yes (read off the document and the art) | dot-weapon-view |
| `content/zee_pack_scan.gd`, `zee_pack_roles.gd`, `zee_pack_source.gd` (the `spawn_provider.gd` contract) | yes | dot-weapon-view |
| `ZeeWeaponPack` (27 builders), `ZeeWeaponIds`, `ZeeWeaponDamage`, the filename half of `ZeeWeaponArtTable`, `assets/`, `cfg/`, export tools | no | **stay in zee-dot-weapons**, which then sits on dot-weapon-view |
| Wire numbers (arena reuses zee's index), roles, damage types (`bullet`, `fall`, `world` plus the guns'), sound class and pose per weapon | arena's | **arena-weapons**: `AwWeaponIds` (append-only index, roles), `AwWeaponDamage`, rows in `AwWeaponArt` |
| `ArenaWeaponRoles` zee fallback, `ArenaWeaponSkins`, the vendored zee art in game-arena `assets/`, `game.sh` art sync | arena's | removed from game-arena; a missing arena-weapons is an error, not zee stand-ins |

## Steps, each green and pushed

1. **dot-weapon-view** (new official addon, `modcommunity/dot-weapon-view`, `addons/dot_weapon_view`): the generic files moved out of zee with `Dot` names and their selftest sections. In the same step zee's files become `class_name Zee* extends Dot*` shims and zee's rig builds zee subclasses, so no code exists twice and the eight zee consumers keep parsing. Checks: dot-weapon-view's suite, `zee_selftest`, one small game's suite.
2. **arena-weapons on dot-weapon-view**: `AwWeaponIds`, `AwWeaponDamage`, art rows registered with `DotWeaponArtRegistry`, sound class per row; zee unlinked; `aw_selftest` passes with no `addons/zee_weapons`.
3. **game-arena switched**: every `Zee*` name to `DotWeapon*` or `Aw*`; `requires.floor.json` drops `zee_weapons` and adds `dot_weapon_view`; `.gitignore` links; `game.sh` loses the zee art sync; dot-ci resolve-deps knows dot-weapon-view's owner; all suites green with zee-dot-weapons absent; `grep -ri zee` empty outside history. The wire index changes, so arena's protocol version is raised. The dev and prod arena packs are republished and `content.lock.json` re-pinned.
4. **The shims go**: each zee consumer (game-playground, game-zombie-zone, mg-deathrun, mg-prop-hunt, mg-smash-copter, mg-wipeout, zed-dot-weapons) renamed to the `Dot` classes, one builder per repo; dot-server-deploy's client shell links dot-weapon-view and the web shell is re-uploaded.

## Work in flight that this moves

New weapon-view code (sights, reload motion) lands in zee's `view/` until step 1 and moves with it; after step 1 it goes into dot-weapon-view, and per-weapon numbers go into the pack's art rows. Recoil and spread stay in dot-weapon, which is already the shared base.
