"""Prints each gun model's muzzle distance and sight point (the highest vertex behind the barrel's front half, lowered 0.025), in the baked frame (origin at the grip, muzzle toward -Z). Run: python3 -I tools/measure_sights.py addons/arena_weapons/assets/models"""
import glob, os, sys
import numpy as np
import trimesh

GUNS = ["pistol", "smg", "rifle", "carbine", "sniper_rifle", "pump_shotgun", "rocket_launcher", "rocket_launcher_alt", "quad_rocket_launcher"]
for name in GUNS:
    scene = trimesh.load(os.path.join(sys.argv[1], name + ".glb"))
    verts = np.vstack([g.vertices for g in scene.dump()]) if hasattr(scene, "dump") else scene.vertices
    muzzle = -verts[:, 2].min()
    behind = verts[verts[:, 2] > -muzzle * 0.5]
    top = behind[behind[:, 1].argmax()]
    print(f"{name}: muzzle {muzzle:.3f} sight ({top[0]:.3f}, {top[1] - 0.025:.3f}, {top[2]:.3f}) size {np.ptp(verts, axis=0).round(3).tolist()}")
