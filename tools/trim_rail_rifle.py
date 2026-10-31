"""Takes the rifle furniture off the baked rail_rifle (stock, pistol grip, trigger guard) so it reads as a railgun: receiver, twin coil rails, scope.
Run after bake_models.py: blender -b -P tools/trim_rail_rifle.py -- <addons/arena_weapons/assets/models>
Cuts are by face centre in the baked frame (origin at the grip, muzzle toward -Z, glTF); a second run finds nothing left to cut."""
import bpy, bmesh, sys, os

dst = sys.argv[sys.argv.index('--') + 1]
path = os.path.join(dst, 'rail_rifle.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
ob = next(o for o in bpy.data.objects if o.type == 'MESH')
# Blender (x, y, z) here is the glTF frame rotated: Y is along the gun, muzzle at +Y.
STOCK_Y = -0.08
REAR = -0.05
GRIP = (-0.12, 0.065, -0.2, 0.02)  # y0, y1, z0, z1 of the pistol grip and trigger guard
bm = bmesh.new()
bm.from_mesh(ob.data)
cut = []
for f in bm.faces:
    c = ob.matrix_world @ f.calc_center_median()
    if min((ob.matrix_world @ v.co).y for v in f.verts) < STOCK_Y or (GRIP[0] <= c.y <= GRIP[1] and GRIP[2] <= c.z <= GRIP[3]):
        cut.append(f)
bmesh.ops.delete(bm, geom=cut, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
# Flatten the ragged cut edge into a clean rear plane
for v in bm.verts:
    w = ob.matrix_world @ v.co
    if w.y < REAR:
        w.y = REAR
        v.co = ob.matrix_world.inverted() @ w
# Close the rear with a cap shaped like the receiver section; its UVs sample a body-coloured face of the receiver
mw_inv = ob.matrix_world.inverted()
def wc(f): return ob.matrix_world @ f.calc_center_median()
img = next(n.image for n in ob.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE')
W, H = img.size
px = list(img.pixels)
def texel(f, uvl):
    u = sum(l[uvl].uv.x for l in f.loops) / len(f.loops)
    v = sum(l[uvl].uv.y for l in f.loops) / len(f.loops)
    i = (int(v * H) % H * W + int(u * W) % W) * 4
    return px[i:i + 3]
uv_layer = bm.loops.layers.uv.active
src = max((f for f in bm.faces if 0.0 < wc(f).y < 0.4 and f.calc_area() > 2e-4 and texel(f, uv_layer)[2] < 0.35), key=lambda f: (lambda t: t[2] - t[0])(texel(f, uv_layer)))
uvc = sum((l[uv_layer].uv for l in src.loops), type(src.loops[0][uv_layer].uv)((0, 0))) / len(src.loops)
SECTION = ((-0.019, 0.02), (0.019, 0.02), (0.024, 0.031), (0.035, 0.056), (0.043, 0.162), (0.023, 0.17), (-0.023, 0.17), (-0.043, 0.162), (-0.035, 0.056), (-0.024, 0.031))
ys = REAR - 0.0005
vs = [bm.verts.new(mw_inv @ type(ob.location)((x, ys, z))) for x, z in SECTION]
f = bm.faces.new(vs)
f.material_index = src.material_index
f.normal_update()
if (ob.matrix_world.to_3x3() @ f.normal).y > 0:
    f.normal_flip()
for l in f.loops:
    l[uv_layer].uv = uvc
bm.to_mesh(ob.data)
bm.free()
bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_apply=False, export_yup=True)
