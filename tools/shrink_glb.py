"""Shrinks a baked glb for the web: textures scaled down and re-encoded, meshes decimated. Blender 4.x, headless:
  blender -b -P tools/shrink_glb.py -- <in.glb> <out.glb> [--tex 1024] [--ratio 0.5] [--quality 82]
Node names and transforms survive (the weapon rows address nodes such as `slide`, `bolt`, `magazine`), identical images are
merged (the rifle embeds one map twice), and the glb is the only output: the extracted jpg tree is not committed.
tools/bake_polyhaven.py makes the 2K glbs (opt-in, kept out of git); this makes the shipped 1K ones."""
import bpy, sys

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
opt = {"--tex": 1024, "--ratio": 0.5, "--quality": 82}
for k in opt:
    if k in argv:
        opt[k] = type(opt[k])(argv[argv.index(k) + 1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

# Images with the same size and the same pixel sample become one, so the glb stores the map once.
seen = {}
for im in list(bpy.data.images):
    if im.size[0] == 0:
        continue
    px = im.pixels[:]
    key = (tuple(im.size), hash(px[::997]))
    if key in seen:
        for mat in bpy.data.materials:
            if mat.node_tree:
                for n in mat.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image == im:
                        n.image = seen[key]
        bpy.data.images.remove(im)
    else:
        seen[key] = im
for im in bpy.data.images:
    if im.size[0] > opt["--tex"]:
        im.scale(opt["--tex"], opt["--tex"])

if opt["--ratio"] < 1.0:
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            bpy.context.view_layer.objects.active = ob
            m = ob.modifiers.new("d", "DECIMATE")
            m.ratio = opt["--ratio"]
            bpy.ops.object.modifier_apply(modifier=m.name)

tris = sum(len(ob.data.polygons) for ob in bpy.data.objects if ob.type == "MESH")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=opt["--quality"],
                          export_yup=True, use_selection=False)
print("shrink:", src, "->", dst, "polys", tris)
