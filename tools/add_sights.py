"""Gives a baked gun model a visible rear aperture, a front post with ears and the `sight_rear` / `sight_front` marks zee's iron sight reads (the aimed line then runs through the ring's centre and the post's tip, above everything between).
Run: blender -b -P tools/add_sights.py -- <addons/arena_weapons/assets/models> [name ...]
A model that already has a `sight_rear` mark is skipped. Stations are metres in the baked frame (origin at the grip, muzzle toward -Z, Y up)."""
import bpy, bmesh, sys, os, math

# name -> (rear z, front z, ring outer radius, half width of the strip the tops are measured on)
GUNS = {
    'revolver': (0.03, -0.20, 0.012, 0.012),
    'pump_shotgun': (0.08, -0.42, 0.016, 0.012),
    'pistol': (0.085, -0.065, 0.010, 0.010),
    'machine_pistol': (-0.03, -0.25, 0.012, 0.012),
    'derringer': (0.01, -0.10, 0.009, 0.010),
    'battle_rifle': (-0.06, -0.69, 0.018, 0.012),
    'quad_rocket_launcher': (0.28, -0.40, 0.020, 0.03),
    'smg': (0.08, -0.12, 0.011, 0.010),
}
args = sys.argv[sys.argv.index('--') + 1:]
dst, names = args[0], args[1:] or list(GUNS)


def tops(verts, z, half, strip):
    for w, h in ((strip, half), (strip * 2, half * 2), (strip * 4, half * 4), (1.0, 0.1)):
        ys = [v[1] for v in verts if abs(v[0]) <= w and abs(v[2] - z) <= h]
        if ys:
            return max(ys)
    return -9.0


def material():
    m = bpy.data.materials.new('sight_metal')
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (0.03, 0.03, 0.035, 1)
    b.inputs['Roughness'].default_value = 0.55
    b.inputs['Metallic'].default_value = 0.6
    return m


def make(name, verts, faces, mat):
    # glTF (x, y, z) is Blender (x, -z, y), a proper rotation, so winding survives.
    me = bpy.data.meshes.new(name)
    me.from_pydata([(x, -z, y) for x, y, z in verts], [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def box(name, cx, y0, y1, cz, sx, sz, mat):
    x0, x1, z0, z1 = cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    f = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (3, 2, 6, 7), (0, 3, 7, 4), (1, 5, 6, 2)]
    return make(name, v, f, mat)


def ring(name, cy, cz, ro, ri, depth, mat, seg=24):
    v, f = [], []
    for zz in (cz - depth / 2, cz + depth / 2):
        for r in (ro, ri):
            for i in range(seg):
                a = 2 * math.pi * i / seg
                v.append((r * math.cos(a), cy + r * math.sin(a), zz))
    n = seg
    # layout: [back outer, back inner, front outer, front inner]
    for i in range(seg):
        j = (i + 1) % seg
        f += [(i, j, 2 * n + j, 2 * n + i), (n + i, 3 * n + i, 3 * n + j, n + j), (i, n + i, n + j, j), (2 * n + i, 2 * n + j, 3 * n + j, 3 * n + i)]
    return make(name, v, f, mat)


def empty(name, x, y, z):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = 'PLAIN_AXES'
    o.empty_display_size = 0.01
    o.location = (x, -z, y)
    bpy.context.scene.collection.objects.link(o)


for name in names:
    rz, fz, ro, strip = GUNS[name]
    path = os.path.join(dst, name + '.glb')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    if 'sight_rear' in bpy.data.objects:
        print('SKIP', name)
        continue
    verts = []
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for v in o.data.vertices:
                p = o.matrix_world @ v.co
                verts.append((p.x, p.z, -p.y))
    rear_top = tops(verts, rz, 0.015, strip)
    front_top = tops(verts, fz, 0.015, strip)
    span = max(tops(verts, rz + (fz - rz) * i / 20.0, 0.012, strip) for i in range(21))
    base = max(span, rear_top, front_top)
    ri = ro * 0.5
    yc = base + ro + 0.004
    mat = material()
    k = ro / 0.016
    box('rear_stem', 0.0, rear_top - 0.002, yc - ro + 0.002, rz, 0.012 * k, 0.008 * k, mat)
    ring('rear_ring', yc, rz, ro, ri, 0.008 * k, mat)
    pw = 0.0042 * k
    box('front_post', 0.0, front_top - 0.002, yc, fz, pw, 0.006 * k, mat)
    for s in (-1, 1):
        box('front_ear' + str(s), s * (pw / 2 + 0.0035 * k), front_top - 0.002, yc, fz, 0.003 * k, 0.006 * k, mat)
    empty('sight_rear', 0.0, yc, rz)
    empty('sight_front', 0.0, yc, fz)
    for o in bpy.data.objects:
        o.select_set(False)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_apply=False, export_yup=True)
    print('SIGHTED', name, 'line y %.3f rear_top %.3f front_top %.3f' % (yc, rear_top, front_top))
