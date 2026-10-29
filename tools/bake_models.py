"""Bakes the source models into this pack: generic names, muzzle toward -Z, scaled to hand size, origin at the grip.
Run: blender -b -P tools/bake_models.py -- <source dir>... <addons/arena_weapons/assets/models>
Each source file is looked up by name in every source dir (Styloo's zEmission GLB folder, the Polyy packs' models, the knife's folder); a missing one is skipped."""
import bpy, sys, os, math, mathutils
args = sys.argv[sys.argv.index('--') + 1:]
srcs, dst = args[:-1], args[-1]
# name -> (source file, scale, quarter turns about up so the muzzle ends at -Z, grip point in the source's glTF frame or None to keep its origin)
M = {'pistol': ('pew.glb', 1.35, 1, None), 'smg': ('mac10.glb', 1.15, 1, None), 'rifle': ('ak47.glb', 1.15, 1, None), 'carbine': ('ak47variant.glb', 1.15, 1, None),
     'sniper_rifle': ('awp.glb', 1.0, 1, None), 'pump_shotgun': ('shotgun.glb', 1.4, 1, None), 'rocket_launcher': ('rocketlaucher.glb', 1.0, 1, None),
     'rocket_launcher_alt': ('rocketlaunchervariant.glb', 1.0, 1, None), 'quad_rocket_launcher': ('quadrocket.glb', 1.0, -1, None),
     'frag_grenade': ('nade_low.glb', 1.0, 0, None), 'frag_grenade_alt': ('nadevariant_low.glb', 1.0, 0, None), 'flash_grenade': ('flashbang_low.glb', 1.0, 0, None),
     'smoke_grenade': ('smoke_low.glb', 1.0, 0, None), 'incendiary_grenade': ('incendiary_low.glb', 1.0, 0, None), 'ammo_box': ('ammobox_low.glb', 1.0, 0, None),
     'round_pistol': ('bulletPEW.glb', 1.0, 0, None), 'round_rifle': ('bullet1.glb', 1.0, 0, None), 'round_shell': ('bulletshotgun.glb', 1.0, 0, None), 'round_sniper': ('bulletsniper.glb', 1.0, 0, None),
     # Polyy's packs: about one unit long, centred, so the scale is the gun's length in metres.
     'revolver': ('six_shot_revolver_low.glb', 0.32, 2, (0, -0.1, -0.22)), 'machine_pistol': ('machine_pistol_low.glb', 0.42, 2, (0, 0.0, -0.15)),
     'derringer': ('pocket_derringer_low.glb', 0.16, 1, (-0.25, 0.0, 0)), 'bullpup': ('bullpup_rifle_low.glb', 0.75, 2, (0, -0.1, -0.1)),
     'battle_rifle': ('semi_auto_service_rifle_low.glb', 1.0, 1, (-0.2, -0.03, 0)), 'burst_rifle': ('modern_tactical_carbine_low.glb', 0.8, 1, (-0.12, -0.08, 0)),
     'drum_shotgun': ('bullpup_box_shotgun_low.glb', 0.85, -1, (-0.05, -0.1, 0)), 'marksman': ('bolt_action_sniper_rifle_low.glb', 1.1, 1, (-0.3, -0.05, 0)),
     'minigun': ('handheld_minigun_low.glb', 0.95, 0, (0, -0.05, 0.3)), 'lmg': ('belt_fed_light_machine_gun_low.glb', 1.05, 1, (-0.25, -0.08, 0)),
     'grenade_launcher': ('revolving_grenade_launcher_low.glb', 0.8, 1, (-0.15, -0.12, 0)), 'plasma_rifle': ('plasma_rifle_low.glb', 0.85, 0, (0, -0.08, 0.2)),
     'rail_rifle': ('railgun_sniper_low.glb', 1.15, 1, (-0.22, -0.08, 0)),
     # Blade along +Y (a melee model's forward is up), origin in the handle already.
     'knife': ('Knife.obj', 0.85, 0, None)}


def find(name):
    for d in srcs:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    return None


for name, (s, sc, rot, grip) in M.items():
    path = find(s)
    if path is None:
        print('SKIP', name, s)
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if s.endswith('.obj'):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    for o in bpy.data.objects:
        # A node called "world" is trimesh's root frame: measure_sights.py would read the model untransformed.
        if o.name.lower() == 'world':
            o.name = name + '_world'
    top = [o for o in bpy.data.objects if o.parent is None]
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    for o in top:
        o.parent = root
    root.scale = (sc, sc, sc)
    root.rotation_euler = (0, 0, rot * math.pi / 2)
    if grip is not None:
        # glTF (x, y, z) is Blender (x, -z, y).
        g = mathutils.Vector((grip[0], -grip[2], grip[1])) * sc
        g.rotate(mathutils.Euler((0, 0, rot * math.pi / 2)))
        root.location = -g
    for o in bpy.data.objects:
        o.select_set(False)
    bpy.ops.export_scene.gltf(filepath=os.path.join(dst, name + '.glb'), export_format='GLB', export_apply=False, export_yup=True)
    print('BAKED', name)
