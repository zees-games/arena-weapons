"""Bakes ambient occlusion and an edge mask onto each gun's existing UVs (Cycles, CPU), for tools/finish_models.py.
Run: blender -b --factory-startup -P tools/bake_wear.py -- <models dir> <out dir> <name>...
Writes <out>/<name>_ao.png and <name>_edge.png at the albedo's size; objects without UVs or a texture are skipped."""
import bpy, sys, os
args = sys.argv[sys.argv.index('--') + 1:]
src, out, names = args[0], args[1], args[2:]
os.makedirs(out, exist_ok=True)


def base_image(mat):
    # The unlit Styloo models carry their albedo in the emission socket.
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image:
            return n.image
    return None


def emission_material(kind, scale):
    m = bpy.data.materials.new('bake_' + kind)
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    o = t.nodes.new('ShaderNodeOutputMaterial')
    e = t.nodes.new('ShaderNodeEmission')
    t.links.new(e.outputs[0], o.inputs[0])
    if kind == 'edge':
        bv = t.nodes.new('ShaderNodeBevel')
        bv.inputs['Radius'].default_value = 0.006 / scale
        bv.samples = 8
        g = t.nodes.new('ShaderNodeNewGeometry')
        d = t.nodes.new('ShaderNodeVectorMath')
        d.operation = 'DOT_PRODUCT'
        t.links.new(bv.outputs['Normal'], d.inputs[0])
        t.links.new(g.outputs['Normal'], d.inputs[1])
        inv = t.nodes.new('ShaderNodeMath')
        inv.operation = 'SUBTRACT'
        inv.inputs[0].default_value = 1.0
        t.links.new(d.outputs['Value'], inv.inputs[1])
        mul = t.nodes.new('ShaderNodeMath')
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = 6.0
        t.links.new(inv.outputs[0], mul.inputs[0])
        t.links.new(mul.outputs[0], e.inputs['Color'])
    return m


for name in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, name + '.glb'))
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 24
    sc.cycles.use_denoising = False
    sc.cycles.bake_type = 'AO'
    objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.data.uv_layers and o.material_slots and o.material_slots[0].material and base_image(o.material_slots[0].material)]
    if not objs:
        print('NOUV', name)
        continue
    size = base_image(objs[0].material_slots[0].material).size[0]
    for o in objs:
        o.data.materials[0].use_nodes = True
    for kind in ('ao', 'edge'):
        img = bpy.data.images.new(name + kind, size, size, float_buffer=False)
        img.colorspace_settings.name = 'sRGB' if kind == 'edge' else 'Non-Color'
        saved = {}
        for o in objs:
            saved[o] = o.data.materials[0]
            m = emission_material(kind, 1.0) if kind == 'edge' else saved[o].copy()
            o.data.materials[0] = m
            nt = m.node_tree
            tn = nt.nodes.new('ShaderNodeTexImage')
            tn.image = img
            nt.nodes.active = tn
            tn.select = True
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.bake(type='AO' if kind == 'ao' else 'EMIT', margin=6, use_clear=True)
        img.filepath_raw = os.path.join(out, '%s_%s.png' % (name, kind))
        img.file_format = 'PNG'
        img.save()
        for o in objs:
            o.data.materials[0] = saved[o]
    print('WEAR', name, size)
