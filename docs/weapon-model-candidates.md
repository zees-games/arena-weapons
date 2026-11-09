# Weapon model candidates (arena-3d-weapon-models-1)

Why: the current weapon art is 1024 px upstream art (Styloo, Polyy); the texture-import quality change made no visible
difference, so the art is the limit. Wanted: free models with PBR maps at 2K or better. Only CC0, or CC-BY with credit,
may be committed. Researched 2026-11-07 from dev02 (web access works; poly.pizza answers 403 to curl).

| Candidate | URL | Licence (page statement) | What | Textures | Verdict |
| --- | --- | --- | --- | --- | --- |
| Poly Haven `service_pistol` (Mateusz Sadek) | https://polyhaven.com/a/service_pistol | CC0 (https://polyhaven.com/license: "CC0 means absolute freedom") | semi-auto pistol with slide, hammer, trigger, magazine, round; ~27.5k tris for both states | 2K diffuse, normal, ARM (JPEG), 4K available | USED (`pistol_ph`) |
| Poly Haven `bolt_action_rifle_7_62` (Mateusz Sadek) | https://polyhaven.com/a/bolt_action_rifle_7_62 | CC0 | scoped bolt-action rifle, moving bolt, sling wrap, round; ~20k tris | 2K, two sets (body, scope): diffuse, normal, ARM | USED (`sniper_ph`) |
| Poly Haven `stick_grenade` (singaii) | https://polyhaven.com/a/stick_grenade | CC0 | stick grenade, 6.2k tris | 2K | Candidate for the thrown slot; not wired (WW2 look beside modern guns) |
| Poly Haven `fish_knife` (Mateusz Sadek) | https://polyhaven.com/a/fish_knife | CC0 | fixed-blade knife, 2.7k tris | 2K | Candidate for `knife`; not wired |
| Poly Haven `machete` (Ulan Cabanilla) | https://polyhaven.com/a/machete | CC0 | machete, 3k tris | 2K | Candidate, melee variety; not wired |
| Poly Haven others (`ammo_box`, `old_military_crate`, medieval blades, axes) | https://polyhaven.com/models | CC0 | props and melee; no further firearms in the catalogue | 2K to 8K | Props only |
| Kenney Blaster Kit | https://kenney.nl/assets/blaster-kit | CC0 ("CC0 licensed!") | stylised blasters, flat colour | palette, no PBR | No texture gain; fits the old look only |
| Quaternius gun packs | https://quaternius.com/ (site says "CC0 License") | CC0 | low-poly guns, flat colour | palette | No PBR; pack page not found by curl (404), not downloaded |
| OpenGameArt CC0 gun listings (`hunting-rifle`, `high-poly-ak-47`, `cc0-flat-guns-east`, `flintlock`) | https://opengameart.org/content/hunting-rifle, .../high-poly-ak-47, .../cc0-flat-guns-east | listed under the CC0 filter; each page must be re-checked before use | mixed | varies | `high-poly-ak-47` USED as `rifle` (Lamoot, CC0 re-checked 2026-11-09, `tools/build_own_ak.py`); the others not evaluated in depth, leads for the revolver, LMG and shotgun gaps |
| Sketchfab CC0 "ArmsMuseum" scans (Vintorez sniper 36k faces, Mosin 1891 27k) | https://sketchfab.com/3d-models/special-sniper-rifle-vss-vintorez-4d5d8c1b7b79429abfa4816f18330089 | CC0 Public Domain (API) | museum scans, download needs a login | photoscan | Not downloaded: no Sketchfab token on this machine |
| Sketchfab CC0 "treehero" low-poly rifles (264 to 432 faces) | https://sketchfab.com/treehero | CC0 Public Domain (API) | tiny low-poly rifles | vertex colour | Too low-detail; not downloaded (login) |
| Styloo Guns Asset Pack, Polyy packs, Vinrax knife | see CREDITS.md | CC0 | the current set | 1024 px | In use; the limit this item is about |
| Sketchfab "Free Standard" packs from model-suggestions-1 | see that item | Free Standard (no redistribution) | references only | | NOT usable (licence) |

Nothing with an unclear licence was committed.

## What the branch does

`tools/bake_polyhaven.py` turns the two Poly Haven downloads into `pistol_ph.glb` and `sniper_ph.glb` in the pack's frame
(origin at the grip, muzzle toward -Z, metres): one weapon state is kept, the rest dropped, the frame change is baked into
the vertices (Godot's importer discards a lone root node's transform), and the 2K JPEGs are embedded untouched. The
`pistol` and `sniper` rows of `AwWeaponArt.WEAPONS` point at them. Run it with
`python3 -I tools/bake_polyhaven.py <dir with service_pistol/ and bolt_action_rifle_7_62/> addons/arena_weapons/assets/models`.

## Size pipeline

`tools/bake_polyhaven.py` writes the 2K glbs (opt-in, gitignored as `*_2k.glb`); `tools/shrink_glb.py` (Blender, headless; it needs
numpy for the glTF importer) scales the maps to 1K, re-encodes JPEG q82, merges the rifle's duplicate map and decimates to 50 %:
`blender -b -P tools/shrink_glb.py -- <baked>.glb addons/arena_weapons/assets/models/<name>.glb`. The shipped glbs embed their
maps (`gltf/embedded_image_handling=2`), so no extracted jpg tree is committed.

| glb | 2K baked | shipped 1K | polys |
| --- | --- | --- | --- |
| pistol_ph | 9.4 MB | 0.87 MB | 8.3k |
| sniper_ph | 24.9 MB | 3.4 MB | 9.1k |

The pack has no web size budget file and `ci/efficiency/size.tsv` gates code lines only, so no gate trips either way; 1K is the
default because the web download is the limit. For 2K, bake, copy the glb in as `<name>_2k.glb`, and point the row's `model` at it.

## Placement (three render rounds, frames in ~/wt/.3dm-shots/r2..r6)

Pistol: `hold (0.12, -0.06, -0.36)`, view `scale 1.4`, `support_grip` as the old row; the real 0.18 m gun read as a sliver
at 0.8 and hid behind the forearm at -0.10. Sniper: `hold (0.15, -0.14, -0.42)`, roll 14 (was 24), aim unchanged at `(0, -0.116, -0.392)`: the selftest's sight measurement
fails (2.3 degrees) with the scope-axis aim `(0.006, -0.094, ...)`. Caveat: the render harness's aim frame is captured before the ADS blend converges (the Styloo
frames behave the same), so the scope alignment is untuned beyond the selftest's sight check.

## Open

- No muzzle or sight marks on either gun; the rifle's magazine is internal (no `mag_node`).
- `headless_aim` fails its three hip-shot checks identically on the base commit ad70e8b (pre-existing, not this branch).
- Stick grenade, fish knife and machete are CC0 and small (2.7k to 6k tris) but not wired: each needs its own hold/aim rounds.
- `tools/render_weapons.sh` crashes on dev02 llvmpipe without `--rendering-method gl_compatibility --rendering-driver opengl3`.
- Weapons with no equivalent yet (SMG, carbine, shotgun, LMG, launchers) need other sources; see the OpenGameArt leads.
