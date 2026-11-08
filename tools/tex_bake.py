"""Blender half of the weapon texture pipeline (tools/tex_pipeline.sh): fresh uniform-density UVs plus the bakes the PBR generator needs.
Run: blender -b -P tools/tex_bake.py -- <model.glb> <out dir> <size> <samples>
Writes <out dir>/{albedo_src,ao_big,ao_small,edge,pid,cover}.png (all in the new UV layout) and mesh.npz (per mesh node: pos, nrm, uv, idx in glTF
space and node-local, vertices split on the new UV seams). Sight meshes (material sight_metal) are left alone and only occlude."""
import bpy, sys, os, math, numpy as np
from mathutils import Matrix

src, out, SIZE, SAMPLES = sys.argv[sys.argv.index('--') + 1:][:4]
SIZE, SAMPLES = int(SIZE), int(SAMPLES)
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = False
sc.render.bake.margin = 24
sc.render.bake.margin_type = 'EXTEND'
sc.render.bake.use_clear = True
world = bpy.data.worlds.new('w')
world.use_nodes = False
sc.world = world

targets = []
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    mats = [m.name for m in o.data.materials if m]
    if mats and all(n == 'sight_metal' for n in mats):
        continue
    targets.append(o)
targets.sort(key=lambda o: o.name)
print('TARGETS', [o.name for o in targets])

# World-space copies of the node meshes: the unwrap then packs in real metres, so every island has the same texel density.
inv = {}
for i, o in enumerate(targets):
    o.data = o.data.copy()
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    inv[o.name] = o.matrix_world.copy().inverted()
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    for m in o.data.polygons:
        m.use_smooth = m.use_smooth
    o.pass_index = i + 1
bpy.ops.object.select_all(action='DESELECT')
for o in targets:
    o.select_set(True)
bpy.context.view_layer.objects.active = targets[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

orig_uv = {}
for o in targets:
    orig_uv[o.name] = o.data.uv_layers[0].name if o.data.uv_layers else None
    o.data.uv_layers.new(name='aw_uv')
    o.data.uv_layers.active = o.data.uv_layers['aw_uv']
MODE = os.environ.get('AW_MODE', 'smart')
ANG = float(os.environ.get('AW_ANGLE', '66'))
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
if MODE == 'smart':
    bpy.ops.uv.smart_project(angle_limit=math.radians(ANG), island_margin=0.0, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
elif MODE == 'orig':
    # keep the artist's islands: copy the original layer over, then only rescale and repack
    bpy.ops.object.mode_set(mode='OBJECT')
    for o in targets:
        a, b = o.data.uv_layers[orig_uv[o.name]], o.data.uv_layers['aw_uv']
        buf = np.zeros(len(a.uv) * 2, np.float32)
        a.uv.foreach_get('vector', buf)
        b.uv.foreach_set('vector', buf)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
else:
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.mesh.edges_select_sharp(sharpness=math.radians(ANG))
    bpy.ops.mesh.mark_seam(clear=False)
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.unwrap(method='CONFORMAL', margin=0.0)
bpy.ops.uv.select_all(action='SELECT')
bpy.ops.uv.average_islands_scale()
bpy.ops.uv.pack_islands(rotate=True, margin=0.0035)
bpy.ops.object.mode_set(mode='OBJECT')


def new_image(name, srgb=False):
    im = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    im.colorspace_settings.name = 'sRGB' if srgb else 'Non-Color'
    return im


def save(im, name):
    im.filepath_raw = os.path.join(out, name + '.png')
    im.file_format = 'PNG'
    im.save()


def emission_mat(name, build):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial')
    e = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(e.outputs[0], o.inputs[0])
    build(nt, e)
    return m


def bake_pass(name, mat_for, btype='EMIT', srgb=False, **kw):
    im = new_image(name, srgb)
    mats = {}
    for o in targets:
        mat = mat_for(o)
        o.data.materials.clear()
        o.data.materials.append(mat)
        for p in o.data.polygons:
            p.material_index = 0
        mats[mat.name] = mat
    for mat in mats.values():
        nt = mat.node_tree
        n = nt.nodes.new('ShaderNodeTexImage')
        n.image = im
        nt.nodes.active = n
        n.select = True
    bpy.ops.object.select_all(action='DESELECT')
    for o in targets:
        o.select_set(True)
        o.data.uv_layers.active = o.data.uv_layers['aw_uv']
    bpy.context.view_layer.objects.active = targets[0]
    bpy.ops.object.bake(type=btype, **kw)
    save(im, name)
    print('BAKED', name)


# 1. the original painted colour, resampled into the new layout (emission of whatever drives Base Color, so metallic factors do not darken it)
orig_mats = {}
for o in targets:
    orig_mats[o.name] = list(o.data.materials)
done = {}
for o in targets:
    for m in o.data.materials:
        if m is None or m.name in done:
            continue
        done[m.name] = 1
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        out_n = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
        for n in list(nt.nodes):
            if n.type == 'TEX_IMAGE' and not n.inputs['Vector'].is_linked and orig_uv[o.name]:
                uvn = nt.nodes.new('ShaderNodeUVMap')
                uvn.uv_map = orig_uv[o.name]
                nt.links.new(uvn.outputs[0], n.inputs['Vector'])
        em = nt.nodes.new('ShaderNodeEmission')
        bc = bsdf.inputs['Base Color']
        if bc.is_linked:
            nt.links.new(bc.links[0].from_socket, em.inputs['Color'])
        else:
            em.inputs['Color'].default_value = bc.default_value
        nt.links.new(em.outputs[0], out_n.inputs['Surface'])
bake_keep = {o.name: o.data.materials[0] if o.data.materials else None for o in targets}
bake_pass('albedo_src', lambda o: bake_keep[o.name], srgb=True)


def ao_world(dist):
    world.light_settings.distance = dist


# 2. everything below is geometry only (replaces the materials)
def solid(color):
    def b(nt, e):
        e.inputs['Color'].default_value = (*color, 1)
    return lambda: emission_mat('solid', b)


white = emission_mat('white', lambda nt, e: setattr(e.inputs['Color'], 'default_value', (1, 1, 1, 1)))
sc.render.bake.margin = 0
bake_pass('cover', lambda o: white)
sc.render.bake.margin = 24


def edge_build(nt, e):
    bev = nt.nodes.new('ShaderNodeBevel')
    bev.inputs['Radius'].default_value = 0.0035
    bev.samples = 12
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    dot = nt.nodes.new('ShaderNodeVectorMath')
    dot.operation = 'DOT_PRODUCT'
    nt.links.new(bev.outputs[0], dot.inputs[0])
    nt.links.new(geo.outputs['Normal'], dot.inputs[1])
    inv_ = nt.nodes.new('ShaderNodeMath')
    inv_.operation = 'SUBTRACT'
    inv_.inputs[0].default_value = 1.0
    nt.links.new(dot.outputs['Value'], inv_.inputs[1])
    mul = nt.nodes.new('ShaderNodeMath')
    mul.operation = 'MULTIPLY'
    mul.use_clamp = True
    mul.inputs[1].default_value = 6.0
    nt.links.new(inv_.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], e.inputs['Color'])


edge = emission_mat('edge', edge_build)
bake_pass('edge', lambda o: edge)

pid = {}


def pid_mat(o):
    def b(nt, e):
        e.inputs['Color'].default_value = (o.pass_index / 32.0,) * 3 + (1,)
    return emission_mat('pid%d' % o.pass_index, b)


bake_pass('pid', pid_mat)

for name, d in (('ao_big', 0.12), ('ao_small', 0.012)):
    ao_world(d)
    bake_pass(name, lambda o: white, btype='AO')

# 3. geometry back to node-local glTF space
res = {}
for o in targets:
    me = o.data
    me.calc_loop_triangles()
    nl = len(me.loops)
    vi = np.zeros(nl, np.int32)
    me.loops.foreach_get('vertex_index', vi)
    co = np.zeros(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get('co', co)
    co = co.reshape(-1, 3)
    uv = np.zeros(nl * 2, np.float32)
    me.uv_layers['aw_uv'].uv.foreach_get('vector', uv)
    uv = uv.reshape(-1, 2)
    nrm = np.zeros(nl * 3, np.float32)
    me.corner_normals.foreach_get('vector', nrm)
    nrm = nrm.reshape(-1, 3)
    tri = np.zeros(len(me.loop_triangles) * 3, np.int32)
    me.loop_triangles.foreach_get('loops', tri)
    M = inv[o.name]
    M3 = M.to_3x3().inverted().transposed()
    P = np.array(M.to_4x4() if hasattr(M, 'to_4x4') else M, dtype=np.float64)
    p = co[vi].astype(np.float64)
    p = p @ P[:3, :3].T + P[:3, 3]
    N = np.array(M3, dtype=np.float64)
    n = nrm.astype(np.float64) @ N.T
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    # Blender (x, y, z) Z-up -> glTF (x, z, -y) Y-up
    gp = np.stack([p[:, 0], p[:, 2], -p[:, 1]], 1).astype(np.float32)
    gn = np.stack([n[:, 0], n[:, 2], -n[:, 1]], 1).astype(np.float32)
    guv = np.stack([uv[:, 0], 1.0 - uv[:, 1]], 1).astype(np.float32)
    key = np.concatenate([np.round(gp * 1e5), np.round(gn * 1e3), np.round(guv * 1e5)], 1)
    _, first, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inverse = inverse.reshape(-1)
    remap = inverse[tri]
    # winding stays as Blender's (CCW seen from the front), same as glTF
    res[o.name + '__pos'] = gp[first]
    res[o.name + '__nrm'] = gn[first]
    res[o.name + '__uv'] = guv[first]
    res[o.name + '__idx'] = remap.astype(np.uint32)
    print('MESH', o.name, len(first), 'verts', len(remap) // 3, 'tris')
np.savez(os.path.join(out, 'mesh.npz'), **res)

# texel density report: uv area vs world area
tot_a = tot_u = 0.0
for o in targets:
    me = o.data
    uv = me.uv_layers['aw_uv'].uv
    for pl in me.polygons:
        tot_a += pl.area
        pts = [uv[l].vector for l in pl.loop_indices]
        a = 0.0
        for k in range(len(pts)):
            x1, y1 = pts[k]
            x2, y2 = pts[(k + 1) % len(pts)]
            a += x1 * y2 - x2 * y1
        tot_u += abs(a) * 0.5
print('DENSITY px_per_mm', math.sqrt(tot_u / tot_a) * SIZE / 1000.0, 'coverage', tot_u)
