"""Layers real CC0 ambientCG detail (Metal038 scratched steel, Metal027 powder-coat paint) onto each gun's baked maps, in the shipped GLB, in place.
Run: python3 -I tools/detail_models.py <models dir> <name>...    (detail sources are tools/detail/, 512 px, tiled TILE times over the gun's UV)
Steel areas (the ORM metal channel) take Metal038's normal, roughness and brightness; the rest takes Metal027's. A gun already done carries
extras.aw_detail on its material and is skipped, so a rerun changes nothing. The base maps come from tools/finish_models.py."""
import sys, os, json, struct, io
import numpy as np
from PIL import Image

TILE = 2
NORMAL_SIZE = 1024  # the normal map carries the visible detail, so it goes back to full size
here = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'detail')
models, names = sys.argv[1], sys.argv[2:]


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


def compact(j, binb):
    """Drops buffer views nothing references any more (the maps this run replaced), so the GLB does not carry both."""
    def textures_of(m):
        for v in list(m.values()) + list(m.get('pbrMetallicRoughness', {}).values()):
            if isinstance(v, dict) and 'index' in v:
                yield v
    tex = sorted({t['index'] for m in j['materials'] for t in textures_of(m)})
    img = sorted({j['textures'][t]['source'] for t in tex})
    tmap, imap = {t: k for k, t in enumerate(tex)}, {i: k for k, i in enumerate(img)}
    j['textures'] = [dict(j['textures'][t], source=imap[j['textures'][t]['source']]) for t in tex]
    j['images'] = [j['images'][i] for i in img]
    for m in j['materials']:
        for t in textures_of(m):
            t['index'] = tmap[t['index']]
    used = {a['bufferView'] for a in j['accessors'] if 'bufferView' in a}
    used |= {i['bufferView'] for i in j['images'] if 'bufferView' in i}
    for a in j['accessors']:
        for k in ('sparse',):
            if k in a:
                used |= {a[k]['indices']['bufferView'], a[k]['values']['bufferView']}
    out, remap = bytearray(), {}
    views = []
    for i, v in enumerate(j['bufferViews']):
        if i not in used:
            continue
        while len(out) % 4:
            out.append(0)
        o = v.get('byteOffset', 0)
        nv = dict(v)
        nv['byteOffset'] = len(out)
        out += binb[o:o + v['byteLength']]
        remap[i] = len(views)
        views.append(nv)
    j['bufferViews'] = views
    for a in j['accessors']:
        if 'bufferView' in a:
            a['bufferView'] = remap[a['bufferView']]
    for i in j['images']:
        if 'bufferView' in i:
            i['bufferView'] = remap[i['bufferView']]
    return out


def img_bytes(j, binb, tex):
    iv = j['bufferViews'][j['images'][j['textures'][tex]['source']]['bufferView']]
    o = iv.get('byteOffset', 0)
    return bytes(binb[o:o + iv['byteLength']])


def load(name, mode, size):
    im = Image.open(os.path.join(here, name)).convert(mode)
    a = np.asarray(im, dtype=np.float32) / 255
    a = np.tile(a, (TILE, TILE, 1) if a.ndim == 3 else (TILE, TILE))
    return np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC), dtype=np.float32) / 255


def enc(a, fmt, **kw):
    bio = io.BytesIO()
    Image.fromarray(a).save(bio, fmt, **kw)
    return bio.getvalue()


def add_image(j, binb, data, mime, like):
    while len(binb) % 4:
        binb.append(0)
    j['bufferViews'].append({'buffer': 0, 'byteOffset': len(binb), 'byteLength': len(data)})
    binb += data
    j['images'].append({'bufferView': len(j['bufferViews']) - 1, 'mimeType': mime})
    t = {'source': len(j['images']) - 1}
    if 'sampler' in like:
        t['sampler'] = like['sampler']
    j['textures'].append(t)
    return len(j['textures']) - 1


for name in names:
    gp = os.path.join(models, name + '.glb')
    j, binb = read_glb(gp)
    mat = next((m for m in j['materials'] if 'normalTexture' in m and 'metallicRoughnessTexture' in m.get('pbrMetallicRoughness', {})), None)
    if mat is None or mat.get('extras', {}).get('aw_detail'):
        print('SKIP', name)
        continue
    pbr = mat['pbrMetallicRoughness']
    ti, to, tn = pbr['baseColorTexture']['index'], pbr['metallicRoughnessTexture']['index'], mat['normalTexture']['index']
    alb = Image.open(io.BytesIO(img_bytes(j, binb, ti)))
    has_a = alb.mode in ('RGBA', 'LA', 'P')
    alb = alb.convert('RGBA')
    size = alb.size[0]
    a = np.asarray(alb, dtype=np.float32)[..., :3] / 255
    alpha = np.asarray(alb)[..., 3]
    orm = Image.open(io.BytesIO(img_bytes(j, binb, to))).convert('RGB')
    half = orm.size[0]
    orm = np.asarray(orm.resize((size, size), Image.BICUBIC), dtype=np.float32) / 255
    nrm = Image.open(io.BytesIO(img_bytes(j, binb, tn))).convert('RGB')
    nrm = np.asarray(nrm.resize((NORMAL_SIZE, NORMAL_SIZE), Image.BICUBIC), dtype=np.float32) / 255 * 2 - 1
    metal = orm[..., 2]
    m_n = np.asarray(Image.fromarray((metal * 255).astype(np.uint8)).resize((NORMAL_SIZE, NORMAL_SIZE), Image.BILINEAR), dtype=np.float32)[..., None] / 255
    sn = load('Metal038_NormalGL.jpg', 'RGB', NORMAL_SIZE) * 2 - 1
    pn = load('Metal027_NormalGL.jpg', 'RGB', NORMAL_SIZE) * 2 - 1
    d = sn * m_n + pn * (1 - m_n)
    w = 1.0 + 0.5 * m_n
    n = np.dstack([nrm[..., 0] + d[..., 0] * w[..., 0], nrm[..., 1] + d[..., 1] * w[..., 0], nrm[..., 2]])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    nbytes = enc(((n * 0.5 + 0.5) * 255).astype(np.uint8), 'PNG', optimize=True)
    # Roughness: the sets' own breakup around their mean, scaled up so it shows under the baked values.
    sr, pr = load('Metal038_Roughness.jpg', 'L', size), load('Metal027_Roughness.jpg', 'L', size)
    dr = (sr - sr.mean()) * metal + (pr - pr.mean()) * (1 - metal)
    orm[..., 1] = np.clip(orm[..., 1] + dr * 5.0, 0.12, 0.95)
    # Albedo: brightness breakup (scratches, micro-wear) from the sets, hue untouched.
    sc, pc = load('Metal038_Color.jpg', 'L', size), load('Metal027_Color.jpg', 'L', size)
    f = (sc / sc.mean() - 1) * metal + (pc / pc.mean() - 1) * (1 - metal)
    a = np.clip(a * (1 + f[..., None] * 4.0), 0, 1)
    rgb8 = (a * 255).astype(np.uint8)
    if has_a and alpha.min() < 255:
        abytes, amime = enc(np.dstack([rgb8, alpha]), 'PNG', optimize=True), 'image/png'
    else:
        abytes, amime = enc(rgb8, 'JPEG', quality=90), 'image/jpeg'
    obytes = enc((np.asarray(Image.fromarray((orm * 255).astype(np.uint8)).resize((half, half), Image.LANCZOS))), 'JPEG', quality=92)
    like = j['textures'][ti]
    ni = add_image(j, binb, abytes, amime, like)
    oi = add_image(j, binb, obytes, 'image/jpeg', like)
    nn = add_image(j, binb, nbytes, 'image/png', like)
    pbr['baseColorTexture']['index'] = ni
    pbr['metallicRoughnessTexture']['index'] = oi
    mat['occlusionTexture']['index'] = oi
    mat['normalTexture']['index'] = nn
    mat.setdefault('extras', {})['aw_detail'] = 'ambientCG Metal038+Metal027 CC0'
    binb = compact(j, binb)
    write_glb(gp, j, binb)
    print('DETAIL', name, size, os.path.getsize(gp))
