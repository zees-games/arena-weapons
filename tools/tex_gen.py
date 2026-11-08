"""Numpy half of the weapon texture pipeline: classifies every texel (blued steel, brass, polymer, wood) from the painted colour, builds
albedo with wear / dirt / scratches, a packed ORM (occlusion, roughness, metal) and a tangent-space normal map from baked edge / AO / seeded
noise, then rewrites the GLB (new UV layout from tex_bake.py, three new images). Deterministic: a rerun gives the same bytes.
Run: python3 -I tools/tex_gen.py <model.glb> <bake dir> <out.glb> [--size N]"""
import sys, os, json, struct, io
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter

src, bake, dst = sys.argv[1:4]
KW = dict(a.lstrip('-').split('=') if '=' in a else (a.lstrip('-'), '1') for a in sys.argv[4:])
ALB_Q, ORM_Q = 88, 90


def read_glb(p):
    b = open(p, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n])
    off = 20 + n
    m = struct.unpack('<I', b[off:off + 4])[0]
    return j, bytearray(b[off + 8:off + 8 + m])


def write_glb(p, j, binb):
    while len(binb) % 4:
        binb.append(0)
    j['buffers'] = [{'byteLength': len(binb)}]
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(binb)
    open(p, 'wb').write(b'glTF' + struct.pack('<II', 2, total) + struct.pack('<I', len(js)) + b'JSON' + js + struct.pack('<I', len(binb)) + b'BIN\0' + bytes(binb))


# ---------------------------------------------------------------- image helpers
def blur(a, r):
    if r <= 0:
        return a
    return gaussian_filter(a.astype(np.float32), r, mode='wrap')


def up(n, size):
    return np.asarray(Image.fromarray(n.astype(np.float32), 'F').resize((size, size), Image.BICUBIC), dtype=np.float32)


def fbm(size, rng, cells_u, cells_v=None, octaves=4, gain=0.5):
    """Value-noise fbm, 0..1; cells_u across (columns), cells_v along (rows): unequal gives streaks."""
    cells_v = cells_v or cells_u
    acc = np.zeros((size, size), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        cu, cv = max(2, int(cells_u * 2 ** o)), max(2, int(cells_v * 2 ** o))
        n = rng.random((cv, cu)).astype(np.float32)
        acc += amp * np.asarray(Image.fromarray(n, 'F').resize((size, size), Image.BICUBIC), dtype=np.float32)
        tot += amp
        amp *= gain
    acc /= tot
    lo, hi = np.percentile(acc, 1), np.percentile(acc, 99)
    return np.clip((acc - lo) / max(hi - lo, 1e-6), 0, 1)


def sstep(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def scratches(size, rng, count, minlen, maxlen):
    im = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(im)
    for _ in range(count):
        x, y = rng.random() * size, rng.random() * size
        ang = rng.random() * np.pi
        ln = minlen + rng.random() ** 2 * (maxlen - minlen)
        d.line([(x, y), (x + np.cos(ang) * ln, y + np.sin(ang) * ln)], fill=int(90 + rng.random() * 165), width=1)
    return blur(np.asarray(im, np.float32) / 255, 0.6) * 1.8


def height_to_normal(h, strength):
    gx = np.gradient(h, axis=1) * strength
    gy = np.gradient(h, axis=0) * strength
    n = np.stack([-gx, gy, np.ones_like(h)], 2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def lerp(a, b, t):
    return a + (b - a) * t


def enc(a, fmt, **kw):
    bio = io.BytesIO()
    Image.fromarray(a).save(bio, fmt, **kw)
    return bio.getvalue()


def gray(name, size):
    im = Image.open(os.path.join(bake, name + '.png')).convert('L')
    if im.size[0] != size:
        im = im.resize((size, size), Image.BILINEAR)
    return np.asarray(im, np.float32) / 255


# ---------------------------------------------------------------- the surfaces
# classes: 0 metal, 1 polymer, 2 wood, 3 brass, 4 coat (painted / cerakote, keeps the artist's colour)
WOOD_MODELS = {'derringer', 'rifle', 'pump_shotgun', 'battle_rifle', 'revolver', 'pistol_ph', 'sniper_ph', 'knife', 'knife_ph', 'rocket_launcher', 'rocket_launcher_alt', 'carbine', 'smg'}


def classify(a, allow_wood=True):
    s0 = a.shape[0]
    af = np.stack([blur(a[..., i], 1.5 * s0 / 1024) for i in range(3)], 2)
    mx, mn = af.max(2), af.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    r, g, b = af[..., 0], af[..., 1], af[..., 2]
    d = np.maximum(mx - mn, 1e-4)
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
    warm = ((hue < 0.11) | (hue > 0.93))
    wood = warm & (sat > 0.33) & (mx > 0.16) & allow_wood
    brass = (hue >= 0.09) & (hue < 0.2) & (sat > 0.42) & (mx > 0.4) & ~wood & allow_wood
    bluish = (hue > 0.5) & (hue < 0.72)
    coat = (sat > 0.17) & (mx > 0.12) & ~wood & ~brass & ~bluish
    poly = (mx < 0.19) & ~wood & ~coat
    metal = ~(wood | brass | poly | coat)
    oh = np.stack([metal, poly, wood, brass, coat], 0).astype(np.float32)
    sm = np.stack([blur(o, 2.5 * s0 / 1024) for o in oh], 0)
    lab = sm.argmax(0)
    oh = np.stack([(lab == k) for k in range(5)], 0).astype(np.float32)
    w = np.stack([blur(o, 0.8 * s0 / 1024) for o in oh], 0)
    w /= np.maximum(w.sum(0, keepdims=True), 1e-4)
    return w


def voronoi_cells(size, rng, spacing):
    """Distance (px) to the nearest of randomly jittered points: pebble / stipple height."""
    from scipy.ndimage import distance_transform_edt
    pts = np.ones((size, size), bool)
    n = int((size / spacing) ** 2)
    ys, xs = rng.integers(0, size, n), rng.integers(0, size, n)
    pts[ys, xs] = False
    return distance_transform_edt(pts).astype(np.float32)


def lum(a):
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


# metal finishes: linear base colour, roughness, how much the wear reveals bare steel
#            blued              parkerized         satin steel        black anodised     gunmetal
FIN_ALB = np.array([[0.065, 0.075, 0.100], [0.165, 0.175, 0.160], [0.30, 0.305, 0.31], [0.050, 0.052, 0.058], [0.22, 0.225, 0.235]], np.float32)
FIN_ROU = np.array([0.40, 0.62, 0.42, 0.50, 0.46], np.float32)
FIN_WEAR = np.array([0.95, 0.80, 0.25, 0.75, 0.55], np.float32)
FIN_PICK = [0, 0, 0, 0, 1, 1, 1, 2, 3, 4]


def part_map(size):
    p = np.asarray(Image.open(os.path.join(bake, 'pid.png')).convert('L').resize((size, size), Image.NEAREST), np.float32) / 255
    return np.rint(p * 32).astype(np.int32)


def build(name, size, rng):
    a = np.asarray(Image.open(os.path.join(bake, 'albedo_src.png')).convert('RGB').resize((size, size), Image.LANCZOS), np.float32) / 255
    cover = gray('cover', size) > 0.5
    edge = blur(gray('edge', size), 1.0 * size / 1024)
    ao_big, ao_small = gray('ao_big', size), gray('ao_small', size)
    k = size / 1024.0
    W = classify(a, os.path.basename(name).replace('.glb', '') in WOOD_MODELS)
    wm, wp, ww, wb, wc = W
    L = lum(a)
    # fine detail the old painted albedo carried (magazine ribs, panel lines, grip checkering): high-pass -> height + cavity
    hp = blur(L, 0.9 * k) - blur(L, 4.5 * k)
    det = np.clip(hp / 0.12, -1, 1)
    groove = sstep(-hp, 0.02, 0.11)
    ridge = sstep(hp, 0.02, 0.11)
    # shared noise
    low = fbm(size, rng, 5, octaves=4)
    mid = fbm(size, rng, 22, octaves=4)
    fine = fbm(size, rng, size // 3, octaves=1)
    wn = fbm(size, rng, 14, octaves=5)
    pits = blur((rng.random((size, size)) > 0.9985).astype(np.float32), 1.1) * 18
    scr = np.clip(scratches(size, rng, int(320 * k * k), 6 * k, 46 * k) * 0.7, 0, 1)
    dirt = np.clip((1 - ao_small) * 1.5 + (1 - ao_big) * 0.6, 0, 1) * (0.5 + 0.5 * low)
    handling = sstep(low + (mid - 0.5) * 0.4, 0.72, 0.92) * (0.4 + 0.6 * ao_small)
    edgew = sstep(edge * 1.25 + (wn - 0.5) * 0.9, 0.55, 0.9)
    # ---- metal: a finish per part (blued / parkerized / satin / anodised / gunmetal), each with its own wear
    part = part_map(size)
    seed = sum(map(ord, name))
    fin_of = np.zeros(40, np.int32)
    Lm = blur(L, 2 * k)
    for i in range(40):
        sel = (part == i) & (wm > 0.5) & cover
        if sel.sum() < 50:
            continue
        ml = float(np.median(Lm[sel]))
        r = (i * 7 + seed * 3 + i // 3) % 10
        if ml < 0.16:
            fin_of[i] = [3, 0, 0, 3, 0, 0, 3, 0, 0, 3][r]
        elif ml < 0.30:
            fin_of[i] = [0, 1, 1, 4, 1, 0, 1, 4, 1, 1][r]
        else:
            fin_of[i] = [2, 4, 2, 1, 4, 2, 2, 4, 1, 2][r]
    fin = fin_of[np.clip(part, 0, 39)]
    base = FIN_ALB[fin]
    tone = (0.78 + 0.45 * low + (mid - 0.5) * 0.30)[..., None]
    plum = (low > 0.55)[..., None] * np.array([0.03, 0.0, -0.03], np.float32)  # thin-film shift on blued parts
    brush = fbm(size, rng, max(8, size // 2), 5, octaves=3)
    m_alb = (base + plum * (fin == 0)[..., None]) * tone * (0.9 + 0.2 * brush[..., None] * (fin == 2)[..., None] + 0.1 * (fine[..., None] - 0.5))
    wear_amt = FIN_WEAR[fin]
    bare = np.clip((edgew * 0.95 + handling * 0.5 + scr * 0.45 * (0.5 + low) + ridge * 0.25 + pits * 0.1) * wear_amt, 0, 1)
    steel = np.array([0.50, 0.505, 0.52], np.float32)[None, None, :] * (0.7 + 0.4 * mid[..., None])
    m_alb = lerp(m_alb, steel, bare[..., None])
    m_alb = m_alb * (1 - 0.55 * dirt[..., None]) * (1 - 0.35 * groove[..., None])
    m_rough = FIN_ROU[fin] + (mid - 0.5) * 0.22 + (fine - 0.5) * 0.08 + (low - 0.5) * 0.1
    m_rough = lerp(m_rough, 0.26 + 0.14 * mid, bare) + dirt * 0.18 + groove * 0.1
    m_met = np.clip(1.0 - dirt * 0.4 - groove * 0.2, 0, 1)
    m_h = (fine - 0.5) * 0.04 + (low - 0.5) * 0.15 - pits * 0.08 - scr * 0.15 + det * 0.22 - bare * 0.1 + (brush - 0.5) * 0.06 * (fin == 2)
    # ---- polymer: grey-black, pebble stipple, lighter where handled
    cell = voronoi_cells(size, rng, 4.2 * k)
    stip = 1 - sstep(cell, 0.6 * k, 2.1 * k)
    p_wear = np.clip(edgew * 0.7 + scr * 0.35 + handling * 0.6, 0, 1)
    p_alb = np.array([0.050, 0.052, 0.056], np.float32)[None, None, :] * (0.7 + 0.7 * low[..., None]) * (0.85 + 0.3 * stip[..., None])
    p_alb = lerp(p_alb, np.array([0.14, 0.14, 0.145], np.float32)[None, None, :], p_wear[..., None] * 0.75)
    p_alb = p_alb * (1 - 0.4 * dirt[..., None]) * (1 - 0.4 * groove[..., None])
    p_rough = np.clip(0.62 + 0.16 * (fine - 0.5) + 0.15 * (low - 0.5) - p_wear * 0.2 - stip * 0.08, 0, 1)
    p_h = stip * 0.30 + (fine - 0.5) * 0.06 + (low - 0.5) * 0.08 + det * 0.3 - scr * 0.15 - edgew * 0.15
    # ---- wood: warm figured grain (rings along V, pores, mid-tone from the old paint), satin lacquer, worn raw at edges
    warp = fbm(size, rng, 6, 3, octaves=3) * 5.0
    cols = np.arange(size, dtype=np.float32)[None, :]
    rings = 0.5 + 0.5 * np.sin(2 * np.pi * (cols / (9.0 * k) + warp))
    ring2 = 0.5 + 0.5 * np.sin(2 * np.pi * (cols / (3.3 * k) + warp * 1.7 + 0.3))
    streak = fbm(size, rng, int(size / 2.5), 5, octaves=3)
    pore = fbm(size, rng, int(size / 1.5), 12, octaves=2)
    g = np.clip(0.26 * rings ** 1.5 + 0.12 * ring2 + 0.62 * streak, 0, 1)
    dk = np.array([0.065, 0.024, 0.009], np.float32)
    lt = np.array([0.34, 0.185, 0.085], np.float32)
    tint = np.clip(blur(L, 6 * k) / 0.45, 0.55, 1.5)[..., None]
    w_alb = lerp(dk[None, None, :], lt[None, None, :], g[..., None]) * (0.78 + 0.45 * low[..., None]) * tint ** 0.8
    w_alb = w_alb * (1 - 0.35 * pore[..., None] * (g[..., None] < 0.5))
    wraw = np.clip(edgew * 0.9 + scr * 0.5, 0, 1)
    w_alb = lerp(w_alb, np.array([0.42, 0.25, 0.12], np.float32)[None, None, :] * (0.8 + 0.3 * streak[..., None]), wraw[..., None] * 0.65)
    w_alb = w_alb * (1 - 0.6 * dirt[..., None]) * (1 - 0.4 * groove[..., None])
    w_rough = np.clip(0.34 + 0.22 * (1 - g) + 0.12 * fine + wraw * 0.28 + dirt * 0.2, 0, 1)
    w_h = (g - 0.5) * 0.30 + (streak - 0.5) * 0.18 - pore * 0.1 - edgew * 0.2 - scr * 0.3 + det * 0.2
    # ---- brass
    b_alb = np.array([0.55, 0.33, 0.085], np.float32)[None, None, :] * (0.65 + 0.6 * low[..., None]) * (1 - 0.5 * dirt[..., None])
    b_rough = np.clip(0.26 + 0.25 * mid + dirt * 0.25, 0, 1)
    b_h = (fine - 0.5) * 0.06 - scr * 0.2 - edgew * 0.15 + det * 0.3
    # ---- coat (paint / cerakote): the artist's colour, matte, chipped to bare steel on edges and handled spots
    ca = np.clip(a, 0, 1) ** 2.2
    cl = lum(ca)[..., None]
    c_alb = lerp(cl, ca, 0.8) * np.clip(blur(ca, 3 * k) / np.maximum(cl, 1e-3), 0, 2) ** 0 * (0.75 + 0.5 * low[..., None]) * (0.92 + 0.16 * fine[..., None])
    c_alb = np.clip(c_alb * 0.9, 0, 1) * (1 - 0.45 * dirt[..., None]) * (1 - 0.35 * groove[..., None])
    chip = np.clip(edgew * 0.9 + scr * 0.4 + handling * 0.4, 0, 1)
    c_alb = lerp(c_alb, steel * 0.9, chip[..., None])
    c_rough = np.clip(0.55 + 0.2 * (mid - 0.5) + 0.1 * fine - chip * 0.25 + dirt * 0.1, 0, 1)
    c_met = chip * 0.95
    c_h = (fine - 0.5) * 0.15 + (low - 0.5) * 0.1 + det * 0.25 - chip * 0.15 - scr * 0.2
    # ---- blend by class weight
    wr = lambda w: w[..., None]
    alb = wr(wm) * m_alb + wr(wp) * p_alb + wr(ww) * w_alb + wr(wb) * b_alb + wr(wc) * c_alb
    alb = alb * (0.55 + 0.45 * ao_small[..., None]) * (0.8 + 0.2 * ao_big[..., None])
    rough = wm * m_rough + wp * p_rough + ww * w_rough + wb * b_rough + wc * c_rough
    metal = wm * m_met + wb * 1.0 + wc * c_met
    h = wm * m_h + wp * p_h + ww * w_h + wb * b_h + wc * c_h
    h = h - edge * 1.4 - groove * 0.25
    occl = np.clip(0.2 + 0.8 * (ao_small * 0.6 + ao_big * 0.4), 0, 1) * (1 - 0.35 * groove)
    return alb, rough, metal, occl, h, cover, W


def fill_outside(arr, cover, size):
    """The margin around islands already holds extended colour from the bake; keep it (mip bleed), only clamp."""
    return arr


def main():
    j, binb = read_glb(src)
    npz = np.load(os.path.join(bake, 'mesh.npz'))
    names = sorted({k.split('__')[0] for k in npz.files})
    size = Image.open(os.path.join(bake, 'albedo_src.png')).size[0]
    for a in sys.argv[4:]:
        if a.startswith('--size'):
            size = int(a.split('=')[1])
    rng = np.random.default_rng(sum(map(ord, os.path.basename(src))))
    alb, rough, metal, occl, h, cover, W = build(os.path.basename(src), size, rng)
    # normal: strength in "pixels of height" so the look is independent of the texture size
    n = height_to_normal(h * (size / 1024.0) * float(KW.get('nstr', 1.0)), 1.0)
    nrm = ((n * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)
    albu = (np.clip(alb, 0, 1) ** (1 / 2.2) * 255 + 0.5).astype(np.uint8)
    orm = (np.stack([occl, rough, metal], 2) * 255 + 0.5).astype(np.uint8)
    if '--debug' in sys.argv:
        Image.fromarray(albu).save(os.path.join(bake, 'out_alb.png'))
        Image.fromarray(orm).save(os.path.join(bake, 'out_orm.png'))
        Image.fromarray(nrm).save(os.path.join(bake, 'out_nrm.png'))
    # ---- the GLB: swap geometry of the baked nodes, then the three images
    node_of = {n_['name']: n_ for n_ in j['nodes'] if 'name' in n_ and 'mesh' in n_}
    mat_idx = set()
    new_chunks = []

    def add_view(data, target=None):
        while len(binb) % 4:
            binb.append(0)
        j['bufferViews'].append({'buffer': 0, 'byteOffset': len(binb), 'byteLength': len(data), **({'target': target} if target else {})})
        binb.extend(data)
        return len(j['bufferViews']) - 1

    def add_acc(view, ctype, count, typ, mn=None, mx=None):
        d = {'bufferView': view, 'componentType': ctype, 'count': count, 'type': typ}
        if mn is not None:
            d['min'], d['max'] = mn, mx
        j['accessors'].append(d)
        return len(j['accessors']) - 1

    for nm in names:
        if nm not in node_of:
            print('NO NODE', nm)
            continue
        mesh = j['meshes'][node_of[nm]['mesh']]
        glassy = [p for p in mesh['primitives'] if 'glass' in (j['materials'][p['material']].get('name', '') if 'material' in p else '')]
        solid_p = [p for p in mesh['primitives'] if p not in glassy]
        prim0 = solid_p[0]
        for p in solid_p:
            mat_idx.add(p.get('material'))
        pos, nr, uv, idx = (npz[nm + '__' + k] for k in ('pos', 'nrm', 'uv', 'idx'))
        vp = add_view(pos.astype('<f4').tobytes(), 34962)
        vn = add_view(nr.astype('<f4').tobytes(), 34962)
        vu = add_view(uv.astype('<f4').tobytes(), 34962)
        if len(pos) < 65535:
            vi = add_view(idx.astype('<u2').tobytes(), 34963)
            ia = add_acc(vi, 5123, len(idx), 'SCALAR')
        else:
            vi = add_view(idx.astype('<u4').tobytes(), 34963)
            ia = add_acc(vi, 5125, len(idx), 'SCALAR')
        prim0['attributes'] = {
            'POSITION': add_acc(vp, 5126, len(pos), 'VEC3', pos.min(0).tolist(), pos.max(0).tolist()),
            'NORMAL': add_acc(vn, 5126, len(pos), 'VEC3'),
            'TEXCOORD_0': add_acc(vu, 5126, len(pos), 'VEC2')}
        prim0['indices'] = ia
        mesh['primitives'] = [prim0] + glassy
    mat_idx.discard(None)
    keep_mat = min(mat_idx)
    for nm in names:
        if nm in node_of:
            for p in j['meshes'][node_of[nm]['mesh']]['primitives'][:1]:
                p['material'] = keep_mat
    mat = j['materials'][keep_mat]
    imgs = []
    for data, mime in ((enc(albu, 'JPEG', quality=ALB_Q, subsampling=0), 'image/jpeg'), (enc(orm, 'JPEG', quality=ORM_Q, subsampling=0), 'image/jpeg'), (enc(nrm, 'PNG', optimize=True), 'image/png')):
        v = add_view(data)
        j['images'].append({'bufferView': v, 'mimeType': mime})
        j['textures'].append({'source': len(j['images']) - 1, 'sampler': 0})
        imgs.append(len(j['textures']) - 1)
    j.setdefault('samplers', [{'magFilter': 9729, 'minFilter': 9987}])
    pbr = mat['pbrMetallicRoughness'] = {'baseColorTexture': {'index': imgs[0]}, 'metallicRoughnessTexture': {'index': imgs[1]}, 'metallicFactor': 1.0, 'roughnessFactor': 1.0}
    mat['occlusionTexture'] = {'index': imgs[1], 'strength': 1.0}
    mat['normalTexture'] = {'index': imgs[2], 'scale': 1.0}
    mat.pop('emissiveTexture', None)
    mat.pop('emissiveFactor', None)
    mat['extras'] = {'aw_detail': 'own procedural PBR (tools/tex_bake.py + tex_gen.py), CC0'}
    compact(j, binb)
    write_glb(dst, j, binb)
    print('DONE', os.path.basename(dst), size, 'bytes', os.path.getsize(dst), 'alb/orm/nrm', [len(x) for x in ()] or '')


def compact(j, binb):
    """Drop what nothing references any more (the old geometry and the old three images) and re-lay the buffer."""
    used_acc = set()
    for m in j['meshes']:
        for p in m['primitives']:
            used_acc.update(p['attributes'].values())
            if 'indices' in p:
                used_acc.add(p['indices'])
            for t in p.get('targets', []):
                used_acc.update(t.values())
    for a in j.get('animations', []):
        for s in a['samplers']:
            used_acc.update((s['input'], s['output']))
    for s in j.get('skins', []):
        if 'inverseBindMatrices' in s:
            used_acc.add(s['inverseBindMatrices'])
    used_tex = set()
    for m in j['materials']:
        def walk(o):
            if isinstance(o, dict):
                if 'index' in o and set(o) <= {'index', 'texCoord', 'scale', 'strength', 'extensions'}:
                    used_tex.add(o['index'])
                for v in o.values():
                    walk(v)
        walk(m)
    tmap = {t: i for i, t in enumerate(sorted(used_tex))}
    used_img = sorted({j['textures'][t]['source'] for t in used_tex})
    imap = {t: i for i, t in enumerate(used_img)}
    amap = {a: i for i, a in enumerate(sorted(used_acc))}
    views = []
    for a in sorted(used_acc):
        views.append(j['accessors'][a]['bufferView'])
    views += [j['images'][i]['bufferView'] for i in used_img]
    vorder = list(dict.fromkeys(views))
    vmap = {v: i for i, v in enumerate(vorder)}
    nb = bytearray()
    nviews = []
    for v in vorder:
        bv = j['bufferViews'][v]
        while len(nb) % 4:
            nb.append(0)
        off = bv.get('byteOffset', 0)
        d = {k: x for k, x in bv.items() if k != 'byteOffset'}
        d['buffer'] = 0
        d['byteOffset'] = len(nb)
        nb += binb[off:off + bv['byteLength']]
        nviews.append(d)
    accs = []
    for a in sorted(used_acc):
        d = dict(j['accessors'][a])
        d['bufferView'] = vmap[d['bufferView']]
        accs.append(d)
    for m in j['meshes']:
        for p in m['primitives']:
            p['attributes'] = {k: amap[v] for k, v in p['attributes'].items()}
            if 'indices' in p:
                p['indices'] = amap[p['indices']]
    for a in j.get('animations', []):
        for s in a['samplers']:
            s['input'], s['output'] = amap[s['input']], amap[s['output']]
    for s in j.get('skins', []):
        if 'inverseBindMatrices' in s:
            s['inverseBindMatrices'] = amap[s['inverseBindMatrices']]
    j['accessors'], j['bufferViews'] = accs, nviews
    j['images'] = [dict(j['images'][i], bufferView=vmap[j['images'][i]['bufferView']]) for i in used_img]
    j['textures'] = [dict(j['textures'][t], source=imap[j['textures'][t]['source']]) for t in sorted(used_tex)]

    def renum(o):
        if isinstance(o, dict):
            if 'index' in o and set(o) <= {'index', 'texCoord', 'scale', 'strength', 'extensions'}:
                o['index'] = tmap[o['index']]
            for v in o.values():
                renum(v)
    for m in j['materials']:
        renum(m)
    binb[:] = nb


main()
