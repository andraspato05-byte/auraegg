"""Builds the 7 Aura animals in Blender and exports them for Roblox.

Needs Blender's Python module:  pip install bpy==5.2.3   (Python 3.13)

    python tools/generate_pets.py            # FBX + preview renders + Luau data
    python tools/generate_pets.py --no-render

Outputs
  models/pets/<Shape>.fbx        import these with Studio's 3D Importer
  models/previews/<Shape>.png    preview renders
  src/server/PetShapes.luau      the same shapes as simple parts (used in-game
                                 until the real meshes are imported)

Every model is made of up to five mesh objects. The game recolours them by name:
  Body   -> the egg's colour        Accent -> the egg's aura colour
  Eyes   -> black                   Shine  -> white
  Detail -> nose / beak / horns colour
Coordinates below are Blender's: Z is up, the animal faces -Y, feet at Z = 0.
"""

import math
import pathlib
import sys

import bpy
import mathutils

ROOT = pathlib.Path(__file__).resolve().parent.parent
FBX_DIR = ROOT / "models" / "pets"
PREVIEW_DIR = ROOT / "models" / "previews"
LUAU_OUT = ROOT / "src" / "server" / "PetShapes.luau"

GROUPS = ["Body", "Accent", "Eyes", "Shine", "Detail"]


def E(group, pos, radius, rot=(0, 0, 0)):
    """Ellipsoid piece."""
    return {"group": group, "type": "ellipsoid", "pos": pos, "radius": radius, "rot": rot}


def C(group, pos, radius, depth, rot=(0, 0, 0)):
    """Cone piece: base radius `radius`, length `depth` along its local +Z (tip end)."""
    return {"group": group, "type": "cone", "pos": pos, "radius": (radius, radius, depth / 2), "depth": depth,
            "rot": rot}


def P(fn, group, pos, *args, rot=(0, 0, 0), flip=()):
    """Mirrored pair helper: pos is the right-side (+X) position. flip lists rotation axes to negate on the left."""
    out = []
    for side in (1, -1):
        p = (pos[0] * side, pos[1], pos[2])
        r = tuple((-v if (i in flip and side < 0) else v) for i, v in enumerate(rot))
        out.append(fn(group, p, *args, rot=r))
    return out


SHAPES = {}

SHAPES["Bunny"] = {
    "detail": (255, 140, 170),
    "pieces": [
        E("Body", (0, 0.15, 0.85), (0.72, 0.9, 0.72)),
        E("Body", (0, -0.7, 1.55), (0.58, 0.55, 0.55)),
        *P(E, "Body", (0.22, -0.62, 2.45), (0.13, 0.08, 0.55), rot=(0, 12, 0), flip=(1,)),
        *P(E, "Body", (0.28, -0.62, 0.22), (0.17, 0.22, 0.17)),
        *P(E, "Body", (0.42, 0.5, 0.17), (0.22, 0.4, 0.16)),
        *P(E, "Body", (0.45, 0.45, 0.55), (0.3, 0.42, 0.38)),
        *P(E, "Accent", (0.22, -0.69, 2.45), (0.08, 0.04, 0.42), rot=(0, 12, 0), flip=(1,)),
        E("Accent", (0, 1.05, 0.95), (0.26, 0.26, 0.26)),
        E("Accent", (0, -0.42, 0.8), (0.45, 0.32, 0.5)),
        *P(E, "Eyes", (0.24, -1.17, 1.68), (0.11, 0.08, 0.13)),
        *P(E, "Shine", (0.21, -1.25, 1.76), (0.035, 0.02, 0.035)),
        E("Detail", (0, -1.25, 1.52), (0.08, 0.05, 0.06)),
    ],
}

SHAPES["Bear"] = {
    "detail": (60, 40, 35),
    "pieces": [
        E("Body", (0, 0.1, 0.95), (0.85, 1.0, 0.8)),
        E("Body", (0, -0.85, 1.75), (0.62, 0.58, 0.58)),
        *P(E, "Body", (0.42, -0.78, 2.27), (0.2, 0.12, 0.2)),
        *P(E, "Body", (0.45, -0.45, 0.38), (0.26, 0.26, 0.4)),
        *P(E, "Body", (0.45, 0.68, 0.38), (0.26, 0.28, 0.4)),
        E("Body", (0, 1.08, 1.0), (0.16, 0.16, 0.16)),
        *P(E, "Accent", (0.42, -0.88, 2.28), (0.11, 0.05, 0.11)),
        E("Accent", (0, -1.35, 1.6), (0.3, 0.2, 0.22)),
        E("Accent", (0, -0.5, 0.9), (0.52, 0.32, 0.55)),
        *P(E, "Eyes", (0.25, -1.33, 1.9), (0.1, 0.07, 0.11)),
        *P(E, "Shine", (0.22, -1.4, 1.97), (0.035, 0.02, 0.035)),
        E("Detail", (0, -1.55, 1.7), (0.1, 0.06, 0.07)),
    ],
}

SHAPES["Frog"] = {
    "detail": (255, 150, 170),
    "pieces": [
        E("Body", (0, 0.05, 0.62), (0.95, 0.95, 0.6)),
        E("Body", (0, -0.55, 0.98), (0.8, 0.55, 0.48)),
        *P(E, "Body", (0.42, -0.72, 1.36), (0.28, 0.26, 0.26)),
        *P(E, "Body", (0.82, 0.3, 0.32), (0.3, 0.6, 0.25)),
        *P(E, "Body", (0.85, -0.2, 0.08), (0.3, 0.25, 0.08)),
        *P(E, "Body", (0.5, -0.85, 0.22), (0.14, 0.14, 0.26)),
        E("Accent", (0, -0.55, 0.45), (0.65, 0.45, 0.3)),
        E("Accent", (0.4, 0.3, 1.15), (0.18, 0.18, 0.08)),
        E("Accent", (-0.3, 0.55, 1.12), (0.14, 0.14, 0.07)),
        *P(E, "Eyes", (0.42, -0.94, 1.42), (0.15, 0.08, 0.15)),
        *P(E, "Shine", (0.38, -1.01, 1.5), (0.045, 0.02, 0.045)),
        *P(E, "Detail", (0.58, -0.95, 0.98), (0.12, 0.05, 0.09)),
    ],
}

SHAPES["Cat"] = {
    "detail": (255, 140, 170),
    "pieces": [
        E("Body", (0, 0.2, 0.92), (0.62, 1.0, 0.62)),
        E("Body", (0, -0.85, 1.55), (0.6, 0.55, 0.55)),
        *P(C, "Body", (0.33, -0.8, 2.1), 0.24, 0.55, rot=(0, 15, 0), flip=(1,)),
        *P(E, "Body", (0.3, -0.45, 0.35), (0.15, 0.15, 0.4)),
        *P(E, "Body", (0.3, 0.75, 0.35), (0.15, 0.15, 0.4)),
        E("Body", (0, 1.15, 1.0), (0.13, 0.2, 0.13)),
        E("Body", (0, 1.32, 1.32), (0.12, 0.12, 0.2)),
        E("Body", (0, 1.38, 1.72), (0.12, 0.12, 0.22)),
        *P(C, "Accent", (0.33, -0.87, 2.08), 0.14, 0.36, rot=(0, 15, 0), flip=(1,)),
        E("Accent", (0, 1.38, 2.0), (0.15, 0.15, 0.15)),
        E("Accent", (0, -0.5, 1.05), (0.38, 0.3, 0.42)),
        *P(E, "Eyes", (0.24, -1.3, 1.66), (0.11, 0.07, 0.13)),
        *P(E, "Shine", (0.21, -1.37, 1.74), (0.035, 0.02, 0.035)),
        E("Detail", (0, -1.4, 1.5), (0.07, 0.05, 0.05)),
    ],
}

SHAPES["Fox"] = {
    "detail": (40, 30, 30),
    "pieces": [
        E("Body", (0, 0.2, 0.9), (0.6, 0.98, 0.6)),
        E("Body", (0, -0.8, 1.5), (0.55, 0.55, 0.5)),
        E("Body", (0, -1.3, 1.38), (0.22, 0.38, 0.2)),
        *P(C, "Body", (0.3, -0.75, 2.05), 0.22, 0.65, rot=(0, 12, 0), flip=(1,)),
        *P(E, "Body", (0.3, -0.45, 0.35), (0.15, 0.15, 0.4)),
        *P(E, "Body", (0.3, 0.75, 0.35), (0.15, 0.15, 0.4)),
        E("Body", (0, 1.3, 1.05), (0.32, 0.7, 0.34), rot=(35, 0, 0)),
        *P(C, "Accent", (0.3, -0.81, 2.03), 0.13, 0.45, rot=(0, 12, 0), flip=(1,)),
        E("Accent", (0, 1.82, 1.42), (0.26, 0.32, 0.28), rot=(35, 0, 0)),
        E("Accent", (0, -0.55, 1.05), (0.4, 0.3, 0.45)),
        *P(E, "Eyes", (0.24, -1.2, 1.62), (0.1, 0.07, 0.12)),
        *P(E, "Shine", (0.21, -1.27, 1.7), (0.035, 0.02, 0.035)),
        E("Detail", (0, -1.68, 1.42), (0.08, 0.06, 0.07)),
    ],
}

SHAPES["Bird"] = {
    "detail": (255, 170, 40),
    "pieces": [
        E("Body", (0, 0.05, 1.0), (0.72, 0.85, 0.8)),
        E("Body", (0, -0.58, 1.75), (0.5, 0.48, 0.48)),
        *P(E, "Accent", (0.78, 0.15, 1.05), (0.12, 0.62, 0.45), rot=(15, 0, 10), flip=(2,)),
        E("Accent", (0, 0.95, 1.2), (0.35, 0.42, 0.07), rot=(30, 0, 0)),
        E("Accent", (0, -0.5, 2.3), (0.06, 0.22, 0.22), rot=(20, 0, 0)),
        *P(E, "Eyes", (0.26, -0.95, 1.85), (0.09, 0.06, 0.1)),
        *P(E, "Shine", (0.23, -1.01, 1.92), (0.03, 0.02, 0.03)),
        C("Detail", (0, -1.12, 1.68), 0.16, 0.42, rot=(90, 0, 0)),
        *P(E, "Detail", (0.25, 0.05, 0.25), (0.06, 0.06, 0.25)),
        *P(E, "Detail", (0.25, -0.12, 0.04), (0.12, 0.2, 0.04)),
    ],
}

SHAPES["Dragon"] = {
    "detail": (255, 215, 120),
    "pieces": [
        E("Body", (0, 0.2, 1.0), (0.75, 1.1, 0.72)),
        E("Body", (0, -0.6, 1.5), (0.4, 0.45, 0.5), rot=(-30, 0, 0)),
        E("Body", (0, -1.0, 1.95), (0.48, 0.6, 0.42)),
        E("Body", (0, -1.5, 1.85), (0.3, 0.35, 0.26)),
        *P(E, "Body", (0.45, -0.4, 0.38), (0.22, 0.22, 0.4)),
        *P(E, "Body", (0.45, 0.75, 0.38), (0.24, 0.26, 0.4)),
        E("Body", (0, 1.3, 0.82), (0.34, 0.5, 0.3)),
        E("Body", (0, 1.85, 0.62), (0.25, 0.45, 0.22)),
        E("Body", (0, 2.3, 0.48), (0.17, 0.35, 0.15)),
        *P(E, "Accent", (0.95, 0.25, 1.75), (0.07, 0.75, 0.6), rot=(20, 30, 0), flip=(1,)),
        E("Accent", (0, -0.3, 0.8), (0.5, 0.65, 0.42)),
        C("Accent", (0, 2.62, 0.42), 0.22, 0.4, rot=(-90, 0, 0)),
        *P(C, "Detail", (0.22, -0.82, 2.35), 0.09, 0.55, rot=(-35, 10, 0), flip=(1,)),
        C("Detail", (0, -0.2, 1.72), 0.12, 0.35, rot=(-20, 0, 0)),
        C("Detail", (0, 0.25, 1.72), 0.12, 0.35, rot=(-20, 0, 0)),
        C("Detail", (0, 0.7, 1.65), 0.12, 0.35, rot=(-20, 0, 0)),
        *P(E, "Eyes", (0.27, -1.45, 2.08), (0.09, 0.06, 0.1)),
        *P(E, "Shine", (0.24, -1.51, 2.15), (0.03, 0.02, 0.03)),
    ],
}

PREVIEW_COLORS = {
    "Body": (214, 200, 175), "Accent": (255, 225, 150), "Eyes": (20, 20, 25),
    "Shine": (255, 255, 255),
}
PREVIEW_BODY = {
    "Bunny": ((214, 200, 175), (255, 245, 220)), "Bear": ((150, 150, 155), (225, 225, 230)),
    "Frog": ((110, 190, 90), (180, 255, 160)), "Cat": ((140, 210, 255), (205, 240, 255)),
    "Fox": ((240, 110, 50), (255, 190, 90)), "Bird": ((255, 230, 70), (255, 255, 140)),
    "Dragon": ((170, 25, 25), (255, 90, 30)),
}


# --- Luau fallback data -------------------------------------------------------

def rot_matrix(rot_deg):
    return mathutils.Euler([math.radians(v) for v in rot_deg], "XYZ").to_matrix()


# Blender (Z up, facing -Y) -> Roblox (Y up, facing -Z): a proper rotation.
P_MAT = mathutils.Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def write_luau():
    def num(v):
        v = round(v, 4)
        return "0" if v == 0 else repr(v)

    out = [
        "-- GENERATED by tools/generate_pets.py - do not edit by hand.",
        "-- The 7 Aura animal shapes as simple parts, used until the real",
        "-- meshes (models/pets/*.fbx) are imported into ReplicatedStorage.PetModels.",
        "-- Units: the animal is ~3 studs long, facing -Z, feet at Y = 0.",
        "",
        "return {",
    ]
    for shape, data in SHAPES.items():
        r, g, b = data["detail"]
        out.append(f"\t{shape} = {{")
        out.append(f"\t\tDetailColor = Color3.fromRGB({r}, {g}, {b}),")
        out.append("\t\tPieces = {")
        for piece in data["pieces"]:
            pos = P_MAT @ mathutils.Vector(piece["pos"])
            rb = P_MAT @ rot_matrix(piece["rot"]) @ P_MAT.inverted()
            rx, ry, rz = piece["radius"]
            size = (2 * rx, 2 * rz, 2 * ry)  # Blender local (x, y, z) -> Roblox local (x, z, y)
            m = [num(rb[i][j]) for i in range(3) for j in range(3)]
            out.append(
                f'\t\t\t{{ Group = "{piece["group"]}", '
                f"CFrame = CFrame.new({num(pos.x)}, {num(pos.y)}, {num(pos.z)}, {', '.join(m)}), "
                f"Size = Vector3.new({num(size[0])}, {num(size[1])}, {num(size[2])}) }},"
            )
        out.append("\t\t},")
        out.append("\t},")
    out.append("}")
    LUAU_OUT.write_text("\n".join(out) + "\n")
    print("wrote", LUAU_OUT)


# --- Blender models ---------------------------------------------------------------

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_piece(piece, organic):
    rx, ry, rz = piece["radius"]
    if piece["type"] == "ellipsoid":
        segments = 32 if organic else 12
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, radius=1)
        obj = bpy.context.active_object
        obj.scale = (rx, ry, rz)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=piece["radius"][0], radius2=0, depth=piece["depth"])
        obj = bpy.context.active_object
    obj.rotation_euler = [math.radians(v) for v in piece["rot"]]
    obj.location = piece["pos"]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    return obj


def apply_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def fuse_smooth(obj, voxel, decimate_ratio):
    """Melt overlapping pieces into one smooth organic surface."""
    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    smooth = obj.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.8
    smooth.iterations = 6
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = decimate_ratio
    apply_modifiers(obj)


def shade_smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


def material(name, rgb, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    color = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.45
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def build_shape(shape, data):
    clear_scene()
    objects = {}
    for group in GROUPS:
        pieces = [p for p in data["pieces"] if p["group"] == group]
        if not pieces:
            continue
        organic = group in ("Body", "Accent")
        parts = [make_piece(p, organic) for p in pieces]
        obj = join(parts, group)
        if group == "Body":
            fuse_smooth(obj, voxel=0.04, decimate_ratio=0.12)
        elif group == "Accent":
            fuse_smooth(obj, voxel=0.035, decimate_ratio=0.25)
        shade_smooth(obj)
        objects[group] = obj

    body, accent = PREVIEW_BODY[shape]
    colors = {"Body": body, "Accent": accent, "Eyes": (20, 20, 25), "Shine": (255, 255, 255),
              "Detail": data["detail"]}
    for group, obj in objects.items():
        obj.data.materials.clear()
        obj.data.materials.append(material(group, colors[group], emission=0.6 if group == "Shine" else 0))
    return objects


def triangle_count(objects):
    total = 0
    for obj in objects.values():
        for poly in obj.data.polygons:
            total += len(poly.vertices) - 2
    return total


def export_fbx(shape, objects):
    FBX_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects.values():
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=str(FBX_DIR / f"{shape}.fbx"),
        use_selection=True,
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=True,
        add_leaf_bones=False,
    )


def render_preview(shape):
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.render.film_transparent = False

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.6, 0.75, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scene.world = world

    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.data.materials.append(material("Floor", (225, 225, 235)))

    bpy.ops.object.light_add(type="SUN", location=(3, -4, 6))
    sun = bpy.context.active_object
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(-35))

    bpy.ops.object.camera_add(location=(4.6, -5.6, 3.4))
    cam = bpy.context.active_object
    direction = mathutils.Vector((0, 0.1, 1.15)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    scene.camera = cam

    scene.render.filepath = str(PREVIEW_DIR / f"{shape}.png")
    bpy.ops.render.render(write_still=True)


def main():
    render = "--no-render" not in sys.argv
    write_luau()
    for shape, data in SHAPES.items():
        objects = build_shape(shape, data)
        tris = triangle_count(objects)
        export_fbx(shape, objects)
        per_object = ", ".join(f"{name} {triangle_count({name: obj})}" for name, obj in objects.items())
        print(f"{shape}: {tris} triangles ({per_object})")
        if render:
            render_preview(shape)


if __name__ == "__main__":
    main()
