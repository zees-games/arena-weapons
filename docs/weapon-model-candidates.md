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
| OpenGameArt CC0 gun listings (`hunting-rifle`, `high-poly-ak-47`, `cc0-flat-guns-east`, `flintlock`) | https://opengameart.org/content/hunting-rifle, .../high-poly-ak-47, .../cc0-flat-guns-east | listed under the CC0 filter; each page must be re-checked before use | mixed | varies | Not evaluated in depth; leads for the revolver, LMG and shotgun gaps |
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

## Size impact

Pistol: 9.4 MB glb (three 2K maps plus about 1 MB of geometry) against 1.4 MB for the Styloo pistol. Sniper: 24.9 MB glb
(two 2K material sets, one JPEG embedded twice) against about 1.5 MB. Godot also extracts the embedded images beside the
glb (the pack's existing habit), so the working tree grows by about 66 MB for the two guns. Triangle count is not
reduced: roughly 14k tris for the pistol set kept and 18k for the rifle, against a few hundred to a few thousand now.
The pack has no web size budget file and `ci/efficiency/size.tsv` gates code lines only, so no gate trips; a web build
would need the maps recompressed (1K, or JPEG quality 80) and the meshes decimated first. If these go into the default
pack, ship the web-sized variant there.

## Open

- View and aim placement are not tuned for the new frames (the hold values are the old models'): in the render the pistol
  barely shows and the rifle sits high and right. The pistol also needs `measured_grip` or `support_grip` numbers.
- No muzzle or sight marks. The pistol's magazine is a node (`magazine`); the rifle's is internal, so the sniper row has no
  `mag_node`.
- The render harness (`tools/render_weapons.sh`) under `RENDER_ONLY` can draw the arm meshes as huge spikes when the
  weapon is the first one equipped; list `knife` first. This also happens with the unchanged Styloo sniper.
- Weapons with no equivalent yet (SMG, carbine, shotgun, LMG, launchers) need other sources; see the OpenGameArt leads.
