import bpy, sys, math
a = sys.argv[sys.argv.index('--') + 1:]
src, dst = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
n0 = n1 = 0
for o in list(bpy.context.scene.objects):
    if o.type != 'MESH':
        continue
    n0 += len(o.data.polygons)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new('bev', 'BEVEL')
    m.limit_method = 'ANGLE'; m.angle_limit = math.radians(35); m.width = 0.0022; m.segments = 2; m.harden_normals = False
    w = o.modifiers.new('wn', 'WEIGHTED_NORMAL'); w.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier='bev')
    bpy.ops.object.modifier_apply(modifier='wn')
    n1 += len(o.data.polygons)
print('POLYS', n0, n1)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_apply=False)
