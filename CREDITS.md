# Credits

| What | Author | Licence | Where |
| --- | --- | --- | --- |
| `pistol`, `smg`, `carbine` (and the `rifle` until it was replaced, see below), `sniper_rifle`, `pump_shotgun`, the rocket launchers, the grenades, `ammo_box`, the rounds (renamed by type, re-oriented, rescaled; the meshes and textures are unchanged) | Styloo | Creative Commons Zero v1.0 Universal | https://styloo.itch.io/guns-asset-pack (the free "GLTF FBX V1.1" zip) |
| `revolver`, `machine_pistol`, `derringer`, `bullpup`, `battle_rifle`, `burst_rifle`, `drum_shotgun`, `marksman` (low-poly edition, re-oriented, rescaled, origin moved to the grip) | Polyy | CC0 1.0 | https://polyyai.itch.io/3d-low-poly-guns-pack |
| `minigun`, `lmg`, `grenade_launcher`, `plasma_rifle`, `rail_rifle` (the same treatment) | Polyy | CC0 1.0 | https://polyyai.itch.io/3d-low-poly-guns-pack-2 |
| `knife` (OBJ converted to GLB, rescaled) | Vinrax | CC0 1.0 | https://opengameart.org/content/knife-low-poly |
| `pistol`, `sniper` (the Styloo models they replaced stay in the pack unused: `pistol`, `sniper_rifle`) | Mateusz Sadek | CC0 1.0 (Poly Haven) | https://polyhaven.com/a/service_pistol, https://polyhaven.com/a/bolt_action_rifle_7_62 (2K textures untouched, one weapon state kept, re-oriented and rescaled by `tools/bake_polyhaven.py`) |
| `rifle` (replaces Styloo's `ak47`, which is no longer drawn: subdivided once, decimated to 20k triangles, split into body, furniture, magazine and bolt nodes, origin at the grip by `tools/build_own_ak.py`; textured by `tools/tex_pipeline.sh`) | Lamoot | CC0 1.0 (OpenGameArt) | https://opengameart.org/content/high-poly-ak-47 (`highpoly_ak47.blend`, posted 2010-11-14; the page lists CC0 as the only licence) |
| `frag` (stick grenade) | singaii | CC0 1.0 (Poly Haven) | https://polyhaven.com/a/stick_grenade (maps 1K, mesh decimated, by `tools/bake_polyhaven_small.py`) |
| `knife` (fish knife; replaces Vinrax's, which stays in the pack unused) | Mateusz Sadek | CC0 1.0 (Poly Haven) | https://polyhaven.com/a/fish_knife (same bake) |

The page's Asset license statement is CC0 1.0 and says no generative AI was used; the zip carries a Read Me about materials and no licence file, so the page is the record. CC0 asks for no credit; it is given anyway. The paid zip with the blend files and paint layers is not used.

Source file to model: `pew` pistol, `mac10` SMG, `ak47` rifle, `ak47variant` carbine, `shotgun` pump shotgun, `awp` sniper rifle, `rocketlaucher` and its variant rocket launchers, `quadrocket` quad launcher, `nade_low` and `nadevariant_low` frag grenades, `flashbang_low`, `smoke_low`, `incendiary_low`, `ammobox_low`, four rounds. The pack's `board` (a presentation sheet) is not used. A few models carry lettering from the source (a fire-selector legend on the SMG, a marking on the pistol slide).

Polyy's packs carry a CC0 1.0 LICENSE.txt in the zip and say the models were generated with their tool; they ask, not as a condition, that the pack is not resold unmodified. Source file to model: `six_shot_revolver_low` revolver, `machine_pistol_low`, `pocket_derringer_low` derringer, `bullpup_rifle_low` bullpup, `semi_auto_service_rifle_low` battle rifle, `modern_tactical_carbine_low` burst rifle, `bullpup_box_shotgun_low` drum shotgun, `bolt_action_sniper_rifle_low` marksman, `handheld_minigun_low` minigun, `belt_fed_light_machine_gun_low` LMG, `revolving_grenade_launcher_low` grenade launcher, `plasma_rifle_low` plasma rifle, `railgun_sniper_low` rail rifle. The rail rifle is further modified: the stock, pistol grip and trigger guard are cut off (`tools/trim_rail_rifle.py`) so it reads as a railgun.

## Sounds

Each gun's own layered report (attack, body, outdoor tail, distant; two takes each) is in `assets/sounds/<gun>/`, cut by `tools/make_fire_sounds.py` from one recording per gun of the CC0 library below, plus a generated low thump on the heavy guns. Other sounds come from dot-audio's stock, which cites each file; the recordings below are credited here too, because CC-BY asks for it:

| What | Author | Licence | Where |
| --- | --- | --- | --- |
| `assets/sounds/` per-gun reports (sniper: Tikka; marksman: Arisaka; battle_rifle: 1917; rifle: AK-47; bullpup: AR-15; carbine: Savage 10 .300 BLK; burst_rifle: SKS; lmg: Mosin Nagant; shotgun: Nova; drum_shotgun: Mossberg; pistol: PPQ; machine_pistol: Bersa; derringer: Single Six; revolver: 642; smg: M45; minigun: PPSh) | Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney (The Free Firearm Sound Library) | CC0 1.0 | https://opengameart.org/content/the-free-firearm-sound-library |
| `lmg` report | KuraiWolf (layered with Tabasco) | CC-BY 4.0 | https://opengameart.org/content/light-machine-gun |
| `battle_rifle`, `burst_rifle`, `marksman` reports and the sniper bolt | Tabasco (bundled text by Vincent Sevedge) | CC-BY 3.0 | https://opengameart.org/content/gunshot-sounds |
| `carbine`, `derringer`, `machine_pistol`, `drum_shotgun` reports | Michel Baradari (apollo-music.de) | CC-BY 3.0 | http://apollo-music.de (hosted on opengameart.org) |
| `charge_rifle` and the energy dry clicks | jc-sounds | CC-BY 4.0 | https://opengameart.org/content/jc-sounds-sci-fi-pack-vol-1 |
| `beamer` | cyklon698, celestialghost8, Zane Little Music | CC0 | https://opengameart.org/content/alien-blaster, https://opengameart.org/content/laser-weapon-burst-fire, https://opengameart.org/content/theremin-laser-sfx |
| `charge_rifle` core | TAD | CC0 | https://opengameart.org/content/doomsday-laser-cannon-sound-effect |

## Surface finish

Every gun, grenade and the ammo box was re-finished (`tools/bake_wear.py`, `tools/finish_models.py`) from the CC0 sources above: the unlit colour map became a lit base colour, with a baked ambient-occlusion and bevel-edge pass turned into an occlusion, roughness and metallic map and a normal map, all generated from the models themselves, so no further source or licence applies.

## Surface detail

`tools/detail_models.py` layers two CC0 PBR sets from ambientCG into every gun's normal and roughness maps and the albedo grain: Metal038 (https://ambientcg.com/view?id=Metal038) and Metal027 (https://ambientcg.com/view?id=Metal027). CC0 was confirmed on each page; ambientCG names no individual author. The detail is baked into the existing per-gun maps, so the pack grows by no new file.
