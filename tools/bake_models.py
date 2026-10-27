"""Bakes the Styloo Guns Asset Pack (zEmission version GLB folder) into this pack: generic names, muzzle toward -Z, scaled to hand size, origin kept at the grip. Run: blender -b -P tools/bake_models.py -- <GLB dir> addons/arena_weapons/assets/models"""
import bpy,sys,os,math
src,dst=sys.argv[-2],sys.argv[-1]
# name -> (source, scale, rotate_to_minus_z)
M={'pistol':('pew',1.35,1),'smg':('mac10',1.15,1),'rifle':('ak47',1.15,1),'carbine':('ak47variant',1.15,1),
'sniper_rifle':('awp',1.0,1),'pump_shotgun':('shotgun',1.4,1),'rocket_launcher':('rocketlaucher',1.0,1),
'rocket_launcher_alt':('rocketlaunchervariant',1.0,1),'quad_rocket_launcher':('quadrocket',1.0,-1),
'frag_grenade':('nade_low',1.0,0),'frag_grenade_alt':('nadevariant_low',1.0,0),'flash_grenade':('flashbang_low',1.0,0),
'smoke_grenade':('smoke_low',1.0,0),'incendiary_grenade':('incendiary_low',1.0,0),'ammo_box':('ammobox_low',1.0,0),
'round_pistol':('bulletPEW',1.0,0),'round_rifle':('bullet1',1.0,0),'round_shell':('bulletshotgun',1.0,0),'round_sniper':('bulletsniper',1.0,0)}
for name,(s,sc,rot) in M.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src,s+'.glb'))
    top=[o for o in bpy.data.objects if o.parent is None]
    root=bpy.data.objects.new(name,None); bpy.context.scene.collection.objects.link(root)
    for o in top: o.parent=root
    root.scale=(sc,sc,sc)
    if rot: root.rotation_euler=(0,0,rot*math.pi/2)
    for o in bpy.data.objects: o.select_set(False)
    bpy.ops.export_scene.gltf(filepath=os.path.join(dst,name+'.glb'),export_format='GLB',export_apply=False,export_yup=True)
