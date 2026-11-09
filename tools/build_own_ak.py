"""Builds the source GLB of the own rifle model (the `rifle` weapon) from the CC0 high-poly AK-47 by Lamoot
(https://opengameart.org/content/high-poly-ak-47, file highpoly_ak47.blend). The result goes through tools/tex_pipeline.sh like
every other own model: blender -b <highpoly_ak47.blend> -P tools/build_own_ak.py -- <out dir>/rifle.glb [subsurf level] [max tris]
Nodes (origins all at the model origin, so a node's mesh sits where it sits on the gun):
  body      receiver, barrel, gas block, sights, trigger group, mag catch: steel
  furniture stock, pistol grip, both handguard halves: wood
  magazine  the magazine with its feed lips and floor plate (the row's `mag_node`): steel
  bolt      the bolt carrier with its charging handle, on the right: steel
Frame: muzzle along +Y, up +Z, the trigger at y ~0.017, the sight tops at z 0.08, the overall length the old model's 0.854 m."""
import bpy, bmesh, sys, math
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index('--') + 1:]
OUT = args[0]
LEVEL = int(args[1]) if len(args) > 1 else 1
MAX_TRIS = int(args[2]) if len(args) > 2 else 40000

# Source frame: centre line x 2.445, the butt y -4.12, the muzzle y 4.66, the trigger centre y -1.05, the sight tops z 1.26.
S = 0.854 / 8.78
TO_GUN = Matrix.Translation((0.0, 0.017, 0.08)) @ Matrix.Scale(S, 4) @ Matrix.Translation((-2.445, 1.05, -1.26))
PARTS = {
	'furniture': {'Plane.010', 'Plane.003', 'Circle.010', 'Circle.007'},
	'magazine': {'clip', 'clip.001', 'Cube.006'},
	'bolt': {'Cube.016'},
}
COLOURS = {'steel': (0.30, 0.30, 0.31, 1.0), 'wood': (0.42, 0.17, 0.06, 1.0)}


def part_of(name):
	for part, names in PARTS.items():
		if name in names:
			return part
	return 'body'


def material(name):
	m = bpy.data.materials.new('own_ak_' + name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get('Principled BSDF')
	bsdf.inputs['Base Color'].default_value = COLOURS[name]
	bsdf.inputs['Roughness'].default_value = 0.5
	return m


sources = [o for o in bpy.data.objects if o.type == 'MESH']
for o in sources:
	for md in o.modifiers:
		if md.type == 'SUBSURF':
			md.levels = LEVEL
			md.render_levels = LEVEL
dg = bpy.context.evaluated_depsgraph_get()
joined = {}
for o in sources:
	ev = o.evaluated_get(dg)
	me = bpy.data.meshes.new_from_object(ev, depsgraph=dg)
	me.transform(TO_GUN @ o.matrix_world)
	joined.setdefault(part_of(o.name), []).append(me)

steel, wood = material('steel'), material('wood')
root = bpy.data.objects.new('rifle', None)
made = []
for part in sorted(joined):
	bm = bmesh.new()
	for me in joined[part]:
		bm.from_mesh(me)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.00005)
	me = bpy.data.meshes.new(part)
	bm.to_mesh(me)
	bm.free()
	me.uv_layers.new(name='UVMap')  # flat colour, but tools/tex_bake.py reads the colour through a source UV layer
	me.materials.clear()
	me.materials.append(wood if part == 'furniture' else steel)
	for p in me.polygons:
		p.material_index = 0
	ob = bpy.data.objects.new(part, me)
	ob.parent = root
	made.append(ob)

scene = bpy.context.scene
for o in sources:
	bpy.data.objects.remove(o, do_unlink=True)
for o in [o for o in bpy.data.objects if o.type != 'MESH' and o != root]:
	bpy.data.objects.remove(o, do_unlink=True)
scene.collection.objects.link(root)
for ob in made:
	scene.collection.objects.link(ob)
total = sum(len(ob.data.polygons) for ob in made)
ratio = min(1.0, MAX_TRIS / max(total, 1))
for ob in made:
	if ratio < 1.0:
		md = ob.modifiers.new('decimate', 'DECIMATE')
		md.ratio = ratio
		md.use_collapse_triangulate = True
	ob.data.shade_smooth()
	ob.data.set_sharp_from_angle(angle=math.radians(35))
dg = bpy.context.evaluated_depsgraph_get()
for ob in made:
	ev = ob.evaluated_get(dg)
	print('NODE', ob.name, 'tris', len(ev.data.polygons), 'bounds', [tuple(round(c, 3) for c in ev.matrix_world @ Vector(b)) for b in (ev.bound_box[0], ev.bound_box[6])])
print('SOURCE_TRIS', total, 'RATIO', round(ratio, 3))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_apply=True, use_active_scene=True, export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT')
print('WROTE', OUT)
