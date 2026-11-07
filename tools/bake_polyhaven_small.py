"""Bakes the small Poly Haven props (stick grenade, fish knife, machete; CC0) into this pack's frame at the shipped 1K size.
Blender 4.x, headless (numpy needed by the glTF importer):
  blender -b -P tools/bake_polyhaven_small.py -- <dir holding <asset>/<asset>_2k.gltf> <out dir> [name ...]
Frame: origin at the grip, metres. Melee blades and the grenade stand upright along +Y (the pack's melee models do: the view turns +Y onto the line of sight);
the grenade head is up. `forward` would lay a blade along -Z instead. Maps go to 1K JPEG (embedded), meshes are decimated to 50 %, node names are the asset's own parts.
Sources: https://polyhaven.com/a/stick_grenade (singaii), /fish_knife (Mateusz Sadek), /machete (Ulan Cabanilla); all CC0."""
import bpy, sys, math, os
from mathutils import Matrix, Vector

# out name -> (asset, tip-forward, scale, grip height in the source Y-up frame before the scale, roll about the long axis in degrees)
M = {
    "stick_grenade": ("stick_grenade", False, 1.0, -0.075, 0.0),
    "knife_ph": ("fish_knife", False, 1.5, -0.045, 0.0),
    "machete_ph": ("machete", False, 0.55, -0.11, 0.0),
}
argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
only = argv[2:] or list(M)
for name in only:
    asset, forward, sc, grip, roll = M[name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath="%s/%s/%s_2k.gltf" % (src, asset, asset))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(False)
    # Blender is Z-up: the source's long Y axis is Blender Z. Rotating -90 degrees about X sends the tip (+Z) to the pack's -Z
    fix = Matrix.Scale(sc, 4)
    if forward:
        fix = fix @ Matrix.Rotation(math.radians(-90), 4, "X") @ Matrix.Rotation(math.radians(roll), 4, "Z")
    fix = fix @ Matrix.Translation(Vector((0, 0, -grip)))
    # BAKE_ROT="rx,ry,rz" (degrees, in the source's Y-up frame, about the grip) tilts the model in its hold: the melee carry is shared,
    # so the blade's lean in the hand is set here.
    rx, ry, rz = [math.radians(float(v)) for v in os.environ.get("BAKE_ROT", "0,0,0").split(",")]
    fix = Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(-rz, 4, "Y") @ Matrix.Rotation(ry, 4, "Z") @ fix
    for o in meshes:
        o.parent = None
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
        o.data.transform(fix)
        bpy.context.view_layer.objects.active = o
        m = o.modifiers.new("d", "DECIMATE")
        m.ratio = 0.5
        bpy.ops.object.modifier_apply(modifier=m.name)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    for im in bpy.data.images:
        if im.size[0] > 1024:
            im.scale(1024, 1024)
    out = "%s/%s.glb" % (dst, name)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=82,
                              export_yup=True, use_selection=False)
    print("BAKED", out, sum(len(o.data.polygons) for o in meshes), "polys")
