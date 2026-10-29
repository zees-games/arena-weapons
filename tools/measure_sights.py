"""Prints each gun model's muzzle distance, sight point and rear (how far the stock reaches behind the grip) (the highest vertex behind the barrel's front half, raised 0.005 so the eye clears it), in the baked frame (origin at the grip, muzzle toward -Z). Run: python3 -I tools/measure_sights.py addons/arena_weapons/assets/models"""
import glob, os, sys
import numpy as np
import trimesh

GUNS = ["pistol", "revolver", "machine_pistol", "derringer", "smg", "rifle", "carbine", "bullpup", "battle_rifle", "burst_rifle", "sniper_rifle", "marksman", "pump_shotgun",
        "drum_shotgun", "lmg", "minigun", "rocket_launcher", "rocket_launcher_alt", "quad_rocket_launcher", "grenade_launcher", "plasma_rifle", "rail_rifle"]
for name in GUNS:
    if not os.path.exists(os.path.join(sys.argv[1], name + ".glb")):
        print(f"{name}: not baked")
        continue
    scene = trimesh.load(os.path.join(sys.argv[1], name + ".glb"))
    verts = np.vstack([g.vertices for g in scene.dump()]) if hasattr(scene, "dump") else scene.vertices
    muzzle = -verts[:, 2].min()
    behind = verts[verts[:, 2] > -muzzle * 0.5]
    top = behind[behind[:, 1].argmax()]
    rear = verts[:, 2].max()
    # Aim hold: the sight 0.32 ahead of the eye, or further when the stock would reach within 0.15 of it (a wedge across the screen).
    aim = (-top[0], -(top[1] + 0.005), min(-0.32 - top[2], -(rear + 0.15)))
    print(f"{name}: aim ({aim[0]:.3f}, {aim[1]:.3f}, {aim[2]:.3f}) muzzle {muzzle:.3f} sight ({top[0]:.3f}, {top[1] + 0.005:.3f}, {top[2]:.3f}) rear {rear:.3f} size {np.ptp(verts, axis=0).round(3).tolist()}")
