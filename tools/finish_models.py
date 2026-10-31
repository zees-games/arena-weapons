"""Gives each gun real surface detail: edge wear, baked AO, a normal map and a packed ORM, patched into the shipped GLB in place.
Run: python3 -I tools/finish_models.py <models dir> <wear dir from bake_wear.py> <normal-source dir or ''> <name>...
Metal, wood and polymer are told apart from the painted albedo; bevelled edges (the baked edge mask) go bare steel; fine brushed grain
and pitting come from seeded noise, so a rerun gives the same bytes. Textures stay 1K: albedo JPEG, normal and ORM PNG."""
import sys, os, json, struct, io, colorsys
import numpy as np
from PIL import Image, ImageFilter

models, wear, nsrc = sys.argv[1], sys.argv[2], sys.argv[3]
names = sys.argv[4:]


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


def image_bytes(j, binb, idx):
    iv = j['bufferViews'][j['images'][idx]['bufferView']]
    return bytes(binb[iv.get('byteOffset', 0):iv.get('byteOffset', 0) + iv['byteLength']])


def blur(a, r):
    return np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), dtype=np.float32) / 255


def noise(size, rng, scale):
    s = max(2, size // scale)
    n = rng.random((s, s)).astype(np.float32)
    return np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC), dtype=np.float32) / 255


def classify(rgb):
    """Per texel: metal and wood weights from the painted colour."""
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    warm = (r > g) & (g > b)
    wood = np.clip((sat - 0.35) * 3.0, 0, 1) * warm * (mx > 0.18)
    dark = np.clip((0.12 - mx) * 12, 0, 1)
    metal = np.clip(1 - wood - dark * 0.8, 0, 1) * np.clip((0.55 - sat) * 4, 0, 1)
    return metal, wood


def height_to_normal(h, strength):
    gx = np.gradient(h, axis=1) * strength
    gy = np.gradient(h, axis=0) * strength
    n = np.stack([-gx, gy, np.ones_like(h)], 2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def enc(a, fmt, **kw):
    bio = io.BytesIO()
    Image.fromarray(a).save(bio, fmt, **kw)
    return bio.getvalue()


for name in names:
    gp = os.path.join(models, name + '.glb')
    j, binb = read_glb(gp)
    # The unlit Styloo models hold the albedo as an emissive texture over a black base colour: every texel full bright, nothing to light.
    mat = next((m for m in j['materials'] if 'baseColorTexture' in m.get('pbrMetallicRoughness', {}) or 'emissiveTexture' in m), None)
    ep = os.path.join(wear, name + '_edge.png')
    if mat is None or not os.path.exists(ep):
        print('SKIP', name)
        continue
    pbr = mat['pbrMetallicRoughness']
    if 'baseColorTexture' not in pbr:
        pbr['baseColorTexture'] = mat.pop('emissiveTexture')
        mat.pop('emissiveFactor', None)
        pbr.pop('baseColorFactor', None)
    src = j['textures'][pbr['baseColorTexture']['index']]['source']
    alb = Image.open(io.BytesIO(image_bytes(j, binb, src))).convert('RGBA')
    size = alb.size[0]
    a = np.asarray(alb, dtype=np.float32)[..., :3] / 255
    alpha = np.asarray(alb)[..., 3]
    ao = np.asarray(Image.open(os.path.join(wear, name + '_ao.png')).convert('L').resize((size, size)), dtype=np.float32) / 255
    edge = np.asarray(Image.open(ep).convert('L').resize((size, size)), dtype=np.float32) / 255
    rng = np.random.default_rng(abs(hash(name)) % 2 ** 31 if False else sum(map(ord, name)))
    metal, wood = classify(a)
    grain = noise(size, rng, 2) * 0.5 + noise(size, rng, 8) * 0.5
    pit = noise(size, rng, 24)
    wornmask = np.clip(blur(edge, 1.2) * 1.6, 0, 1) * np.clip(0.35 + pit * 1.2, 0, 1)
    wornmask = np.clip(wornmask - 0.1, 0, 1)
    # Albedo: baked AO darkens crevices, worn edges show bare steel on metal and paler paint elsewhere.
    steel = np.array([0.62, 0.62, 0.64], dtype=np.float32)
    out = a * (0.55 + 0.45 * ao[..., None])
    w = (wornmask * (0.25 + 0.75 * metal))[..., None]
    out = out * (1 - w) + steel * w
    # Grease and wear streaks on metal, so it is not one tone.
    out = out * (1 + (grain[..., None] - 0.5) * 0.18 * (0.3 + metal[..., None]))
    out = np.clip(out, 0, 1)
    is_metal = np.clip(metal * 0.55 + wornmask * 0.6, 0, 1)
    rough = 0.7 - metal * 0.22 + (grain - 0.5) * 0.18 - wornmask * 0.2 + wood * 0.0
    rough = np.clip(rough, 0.18, 0.95)
    orm = np.stack([ao, rough, is_metal], 2)
    # Normal: bevelled edges from the edge mask, brushed grain on metal, pitting everywhere.
    h = blur(edge, 1.0) * 0.9 + grain * 0.05 * (0.3 + metal) + pit * 0.025
    n = height_to_normal(h * size / 256, 1.0)
    if nsrc:
        sp = os.path.join(nsrc, name + '.png')
        if os.path.exists(sp):
            sn = np.asarray(Image.open(sp).convert('RGB').resize((size, size)), dtype=np.float32) / 255 * 2 - 1
            n = sn + np.dstack([n[..., 0], n[..., 1], np.zeros_like(n[..., 0])]) * 0.6
            n /= np.linalg.norm(n, axis=2, keepdims=True)
    nrm = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
    rgb8 = (out * 255).astype(np.uint8)
    albbytes = enc(np.dstack([rgb8, alpha]) if alpha.min() < 255 else rgb8, 'PNG' if alpha.min() < 255 else 'JPEG', **({} if alpha.min() < 255 else {'quality': 90}))
    # ORM and normal carry only soft detail, so half size keeps the web pack to about 1.7 MB a gun.
    half = max(size // 2, 256)
    ormbytes = enc(np.asarray(Image.fromarray((orm * 255).astype(np.uint8)).resize((half, half), Image.LANCZOS)), 'JPEG', quality=92)
    nbytes = enc(np.asarray(Image.fromarray(nrm).resize((half, half), Image.LANCZOS)), 'PNG', optimize=True)
    for data, mime in ((albbytes, 'image/png' if alpha.min() < 255 else 'image/jpeg'), (ormbytes, 'image/jpeg'), (nbytes, 'image/png')):
        while len(binb) % 4:
            binb.append(0)
        j['bufferViews'].append({'buffer': 0, 'byteOffset': len(binb), 'byteLength': len(data)})
        binb += data
        j['images'].append({'bufferView': len(j['bufferViews']) - 1, 'mimeType': mime})
        j['textures'].append({'source': len(j['images']) - 1, 'sampler': j['textures'][0].get('sampler', 0)} if 'sampler' in j['textures'][0] else {'source': len(j['images']) - 1})
    t = len(j['textures'])
    pbr['baseColorTexture'] = {'index': t - 3, 'texCoord': pbr['baseColorTexture'].get('texCoord', 0)}
    pbr['metallicRoughnessTexture'] = {'index': t - 2, 'texCoord': pbr['baseColorTexture']['texCoord']}
    pbr['metallicFactor'] = 1.0
    pbr['roughnessFactor'] = 1.0
    mat['occlusionTexture'] = {'index': t - 2, 'texCoord': pbr['baseColorTexture']['texCoord'], 'strength': 0.8}
    mat['normalTexture'] = {'index': t - 1, 'texCoord': pbr['baseColorTexture']['texCoord'], 'scale': 1.0}
    write_glb(gp, j, binb)
    Image.fromarray(rgb8).save(os.path.join(wear, name + '_alb_out.png'))
    print('FINISHED', name, size, 'glb', os.path.getsize(gp))
