"""Packs Poly Haven's CC0 gltf models into this pack's frame (origin at the grip, muzzle toward -Z, metres) as one GLB.
No Blender needed: the node list is trimmed (one weapon state, the others dropped) and wrapped in a root node that carries
the rotation, scale and grip offset; the 2K textures are embedded untouched.
Run: python3 -I tools/bake_polyhaven.py <dir holding <asset>/<asset>_2k.gltf, its .bin and textures/> <out dir>
Sources (CC0, https://polyhaven.com/license): service_pistol and bolt_action_rifle_7_62 by Mateusz Sadek."""
import json, os, struct, sys

# name -> (asset, source node -> new node name, scale, grip in the source frame (x forward, y up) before the scale, shift of the magazine node)
M = {
    "pistol_ph": ("service_pistol", {"service_pistol_pistol_a": "frame", "service_pistol_slide_a": "slide", "service_pistol_hammer_a": "hammer",
                                     "service_pistol_trigger_a": "trigger", "service_pistol_magazine_loaded": "magazine"}, 0.8, (-0.015, 0.0, 0.0), (0.088, 0.0, 0.0)),
    "sniper_ph": ("bolt_action_rifle_7_62", {"bolt_action_rifle_7_62": "body", "bolt_action_rifle_7_62_scope": "scope", "bolt_action_rifle_7_62_wrap": "wrap",
                                             "bolt_action_rifle_7_62_bolt_a": "bolt", "bolt_action_rifle_7_62_trigger": "trigger"}, 0.85, (-0.35, -0.04, 0.0), None),
}


def _rot(q, v):
    """Rotates v by the unit quaternion q (x, y, z, w)."""
    x, y, z, w = q
    tx, ty, tz = (2 * (y * v[2] - z * v[1]), 2 * (z * v[0] - x * v[2]), 2 * (x * v[1] - y * v[0]))
    return [v[0] + w * tx + (y * tz - z * ty), v[1] + w * ty + (z * tx - x * tz), v[2] + w * tz + (x * ty - y * tx)]


src, dst = sys.argv[1], sys.argv[2]
for name, (asset, keep, sc, grip, mag_shift) in M.items():
    base = os.path.join(src, asset)
    g = json.load(open(os.path.join(base, asset + "_2k.gltf")))
    blob = bytearray(open(os.path.join(base, g["buffers"][0]["uri"]), "rb").read())
    views = g["bufferViews"]
    for im in g["images"]:
        while len(blob) % 4:
            blob.append(0)
        data = open(os.path.join(base, im.pop("uri")), "rb").read()
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        im["bufferView"] = len(views) - 1
        blob += data
    kept = []
    for n in g["nodes"]:
        if n["name"] in keep:
            n["name"] = keep[n["name"]]
            if n["name"] == "magazine" and mag_shift:
                n["translation"] = [n["translation"][i] + mag_shift[i] for i in range(3)]
            kept.append(n)
    # Godot's importer drops a lone root node's transform, so the frame change is baked into the vertices instead.
    gx, gy, gz = grip
    for n in kept:
        t = n.pop("translation", [0, 0, 0])
        q = n.pop("rotation", [0, 0, 0, 1])
        prim = g["meshes"][n["mesh"]]["primitives"][0]
        for attr, acc_i in prim["attributes"].items():
            if attr not in ("POSITION", "NORMAL"):
                continue
            acc = g["accessors"][acc_i]
            view = views[acc["bufferView"]]
            off = view["byteOffset"] + acc.get("byteOffset", 0)
            lo = [1e9] * 3
            hi = [-1e9] * 3
            for i in range(acc["count"]):
                v = list(struct.unpack_from("<3f", blob, off + 12 * i))
                v = _rot(q, v)
                if attr == "POSITION":
                    v = [v[k] + t[k] for k in range(3)]
                    v = [(v[0] - gx), (v[1] - gy), (v[2] - gz)]
                    # Source +X (muzzle) to -Z, Y stays up: (x, y, z) -> (z, y, -x), then the scale.
                    v = [v[2] * sc, v[1] * sc, -v[0] * sc]
                    lo = [min(lo[k], v[k]) for k in range(3)]
                    hi = [max(hi[k], v[k]) for k in range(3)]
                else:
                    v = [v[2], v[1], -v[0]]
                struct.pack_into("<3f", blob, off + 12 * i, *v)
            if attr == "POSITION":
                acc["min"], acc["max"] = lo, hi
    g["nodes"] = kept
    g["scenes"] = [{"name": "Scene", "nodes": list(range(len(kept)))}]
    g["scene"] = 0
    g["buffers"] = [{"byteLength": len(blob)}]
    js = json.dumps(g, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    while len(blob) % 4:
        blob.append(0)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    open(os.path.join(dst, name + ".glb"), "wb").write(out)
    print("BAKED", name, len(out))
