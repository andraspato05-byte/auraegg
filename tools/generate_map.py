"""Generates the static map for Steal the Aura Egg as Rojo model files.

    python3 tools/generate_map.py

Writes map/Map.model.json (world, belt, machine, gyms, decorations) and
map/Plots.model.json (the 8 bases). Rojo puts both into Workspace, so the
map is visible and editable in Roblox Studio before pressing Play.

The server scripts find things by name, so keep these names if you edit the
map in Studio: Workspace.Map.ConveyorBelt, Workspace.Map.AuraEggMachine,
Workspace.Map.TitleAnchor, Workspace.Plots.Plot1..Plot8 (each with Origin,
LockBarrier, SignAnchor, Pedestal1..10, PedestalRim1..10, CashPad1..10, LockPad,
UpgradeTerminal, Eggs) and
Treadmill models (attribute Tier, child Belt).
"""

import json
import math
import pathlib
import random

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "map"

MATERIAL = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528,
    "Marble": 784, "Slate": 800, "Concrete": 816, "Granite": 832, "Pavement": 836,
    "Brick": 848, "Cobblestone": 880, "Rock": 896, "Metal": 1088, "DiamondPlate": 1056,
    "Grass": 1280, "LeafyGrass": 1284, "Fabric": 1312, "Glass": 1568, "ForceField": 1584,
    "Carpet": 2305, "CeramicTiles": 2306, "Rubber": 2311,
}
SHAPE = {"Ball": 0, "Block": 1, "Cylinder": 2}
MESH_SPHERE = 3

# Must match src/shared/Config.luau
PLOT_COLORS = [
    (255, 170, 170), (255, 205, 140), (255, 240, 150), (170, 240, 170),
    (150, 220, 255), (175, 170, 255), (240, 170, 255), (170, 255, 230),
]
TIER_COLORS = [(90, 230, 110), (70, 160, 255), (185, 90, 255), (255, 195, 40)]

PLOT_HALF = 28
PLOT_X = [-112.5, -37.5, 37.5, 112.5]
PLOT_Z = 50
BELT_LENGTH = 430
BELT_WIDTH = 12


# --- tiny CFrame math -------------------------------------------------------

class CF:
    def __init__(self, p=(0.0, 0.0, 0.0), r=None):
        self.p = tuple(float(v) for v in p)
        self.r = r or [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]

    def __mul__(self, o):
        r1 = self.r
        p = tuple(self.p[i] + sum(r1[i][k] * o.p[k] for k in range(3)) for i in range(3))
        r = [[sum(r1[i][k] * o.r[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
        return CF(p, r)


def T(x, y, z):
    return CF((x, y, z))


def RY(a):
    c, s = math.cos(a), math.sin(a)
    return CF(r=[[c, 0, s], [0, 1, 0], [-s, 0, c]])


def RZ(a):
    c, s = math.cos(a), math.sin(a)
    return CF(r=[[c, -s, 0], [s, c, 0], [0, 0, 1]])


def clean(v):
    v = round(v, 5)
    return 0.0 if v == 0 else v


def cf_json(cf):
    return {"CFrame": {
        "position": [clean(v) for v in cf.p],
        "orientation": [[clean(v) for v in row] for row in cf.r],
    }}


# --- instance helpers -------------------------------------------------------

def color3(rgb):
    return {"Color3": [round(c / 255, 5) for c in rgb]}


def part(name, size, cf, rgb, material="SmoothPlastic", shape=None, collide=True,
         transparency=0.0, cls="Part", props=None, children=None, attributes=None,
         query=True, touch=True, shadow=True):
    p = {
        "Anchored": True,
        "Size": {"Vector3": [clean(v) for v in size]},
        "CFrame": cf_json(cf),
        "Color": color3(rgb),
        "Material": {"Enum": MATERIAL[material]},
        "TopSurface": {"Enum": 0},
        "BottomSurface": {"Enum": 0},
    }
    if shape:
        p["Shape"] = {"Enum": SHAPE[shape]}
    if not collide:
        p["CanCollide"] = False
    if not query:
        p["CanQuery"] = False
    if not touch:
        p["CanTouch"] = False
    if not shadow:
        p["CastShadow"] = False
    if transparency:
        p["Transparency"] = transparency
    if props:
        p.update(props)
    node = {"name": name, "className": cls, "properties": p}
    if children:
        node["children"] = children
    if attributes:
        node["attributes"] = attributes
    return node


def vcyl(name, height, diameter, cf, rgb, material="SmoothPlastic", **kw):
    """Vertical cylinder (Roblox cylinders point along X, so roll it 90 degrees)."""
    return part(name, (height, diameter, diameter), cf * RZ(math.pi / 2), rgb, material, shape="Cylinder", **kw)


def light(rng, brightness, rgb):
    return {"name": "Light", "className": "PointLight", "properties": {
        "Range": rng, "Brightness": brightness, "Color": color3(rgb), "Shadows": False}}


def sphere_mesh():
    return {"name": "Mesh", "className": "SpecialMesh", "properties": {"MeshType": {"Enum": MESH_SPHERE}}}


def invisible(name, cf):
    return part(name, (1, 1, 1), cf, (0, 0, 0), collide=False, transparency=1, query=False, touch=False, shadow=False)


def folder(name, children):
    return {"name": name, "className": "Folder", "children": children}


def model(name, children, attributes=None):
    node = {"name": name, "className": "Model", "children": children}
    if attributes:
        node["attributes"] = attributes
    return node


# --- world ------------------------------------------------------------------

def build_ground():
    items = [
        part("Ground", (620, 2, 440), T(0, -1, 0), (92, 170, 78), "Grass"),
        part("Walkway", (480, 0.2, 40), T(0, 0.1, 0), (175, 170, 165), "Cobblestone"),
    ]
    # Visible fence around the map + invisible walls so nobody walks off
    wood = (130, 90, 55)
    for z in (-205, 205):
        items.append(part("Fence", (590, 1, 0.6), T(0, 1.2, z), wood, "WoodPlanks"))
        items.append(part("Fence", (590, 1, 0.6), T(0, 2.8, z), wood, "WoodPlanks"))
    for x in (-295, 295):
        items.append(part("Fence", (0.6, 1, 410), T(x, 1.2, 0), wood, "WoodPlanks"))
        items.append(part("Fence", (0.6, 1, 410), T(x, 2.8, 0), wood, "WoodPlanks"))
    for x in range(-290, 291, 20):
        for z in (-205, 205):
            items.append(part("FencePost", (1, 4, 1), T(x, 2, z), wood, "Wood"))
    for z in range(-200, 201, 20):
        for x in (-295, 295):
            items.append(part("FencePost", (1, 4, 1), T(x, 2, z), wood, "Wood"))
    border = dict(transparency=1, query=False, shadow=False)
    items += [
        part("BorderN", (600, 80, 2), T(0, 40, 207), (0, 0, 0), **border),
        part("BorderS", (600, 80, 2), T(0, 40, -207), (0, 0, 0), **border),
        part("BorderE", (2, 80, 416), T(297, 40, 0), (0, 0, 0), **border),
        part("BorderW", (2, 80, 416), T(-297, 40, 0), (0, 0, 0), **border),
    ]
    # Rolling hills on the horizon
    rnd = random.Random(7)
    hills = []
    for i in range(22):
        angle = i / 22 * 2 * math.pi
        x = math.cos(angle) * 380
        z = math.sin(angle) * 290
        size = rnd.uniform(110, 170)
        mat, col = rnd.choice([("LeafyGrass", (80, 150, 70)), ("Grass", (95, 165, 80)), ("Rock", (120, 115, 110))])
        hills.append(part("Hill", (size, size, size), T(x, -size * 0.25, z), col, mat, shape="Ball", shadow=False))
    items.append(folder("Hills", hills))
    return items


def build_belt():
    items = [part("ConveyorBelt", (BELT_LENGTH, 1, BELT_WIDTH), T(0, 0.5, 0), (40, 40, 52), "DiamondPlate")]
    for side in (-1, 1):
        items.append(part("BeltRail", (BELT_LENGTH, 1.6, 1), T(0, 1, side * (BELT_WIDTH / 2 + 0.5)),
                          (160, 90, 255), "Neon"))
    for x in range(-200, 201, 16):
        items.append(part("BeltArrow", (0.6, 0.05, BELT_WIDTH - 4), T(x, 1.03, 0), (150, 100, 255), "Neon",
                          collide=False, query=False, touch=False, transparency=0.3, shadow=False))
    # Glowing arches over the runway
    arches = []
    for x in range(-172, 173, 43):
        arch = []
        for z in (-9, 9):
            arch.append(part("Pillar", (2, 19, 2), T(x, 9.5, z), (240, 238, 245), "Marble"))
            arch.append(part("PillarGlow", (2.3, 0.6, 2.3), T(x, 3, z), (180, 110, 255), "Neon"))
        arch.append(part("Beam", (2.4, 1.8, 20.4), T(x, 19.9, 0), (240, 238, 245), "Marble"))
        arch.append(part("BeamGlow", (2.6, 0.5, 18), T(x, 18.85, 0), (180, 110, 255), "Neon",
                         children=[light(18, 1.4, (190, 130, 255))]))
        arches.append(model("Arch", arch))
    items.append(folder("RunwayArches", arches))
    return items


def build_machine():
    x = -222
    purple = (120, 60, 200)
    glow = (210, 140, 255)
    items = [
        part("Plinth", (20, 3, 30), T(-225, 1.5, 0), (70, 65, 80), "Slate"),
        part("AuraEggMachine", (14, 18, 24), T(x, 12, 0), (70, 40, 120), "Metal"),
        part("MachineMouth", (0.4, 7, 12), T(-214.9, 4.5, 0), (15, 5, 30), "Neon"),
        part("MouthFrame", (0.8, 1, 14), T(-214.7, 8.5, 0), glow, "Neon"),
        part("MachineGlow", (14.4, 1, 24.4), T(x, 16, 0), glow, "Neon"),
        part("MachineGlowLow", (14.4, 1, 24.4), T(x, 8, 0), glow, "Neon"),
        part("Roof", (16, 1.5, 26), T(x, 21.75, 0), (50, 30, 90), "Metal"),
    ]
    for z in (-15, 15):
        items.append(vcyl("Tower", 26, 6, T(x, 13, z), purple, "Metal"))
        items.append(part("TowerOrb", (6.5, 6.5, 6.5), T(x, 27.5, z), glow, "Neon", shape="Ball",
                          children=[light(24, 2, glow)]))
    items.append(part("GiantEgg", (10, 13, 10), T(x, 29, 0), (220, 160, 255), "Neon", transparency=0.15,
                      children=[sphere_mesh(), light(40, 3, glow)]))
    items.append(part("GiantEggBand", (10.6, 1.4, 10.6), T(x, 28, 0), (255, 220, 120), "Neon",
                      children=[sphere_mesh()]))
    # Vault at the far end where unsold eggs disappear
    items += [
        part("VaultPlinth", (20, 3, 30), T(225, 1.5, 0), (70, 65, 80), "Slate"),
        part("EggVault", (14, 14, 24), T(222, 10, 0), (45, 30, 75), "Metal"),
        part("VaultMouth", (0.4, 7, 12), T(214.9, 4.5, 0), (15, 5, 30), "Neon"),
        part("VaultGlow", (14.4, 1, 24.4), T(222, 17.5, 0), glow, "Neon"),
    ]
    return items


def build_lamps():
    lamps = []
    for x in (-200, -150, -75, 75, 150, 200):
        for z in (-19, 19):
            lamps.append(model("LampPost", [
                vcyl("Pole", 12, 0.8, T(x, 6, z), (40, 40, 45), "Metal"),
                part("Lamp", (2.2, 2.2, 2.2), T(x, 12.6, z), (255, 230, 170), "Neon", shape="Ball",
                     children=[light(22, 1.3, (255, 225, 170))]),
            ]))
    return folder("LampPosts", lamps)


def build_trees():
    rnd = random.Random(42)
    trees = []

    def blocked(x, z):
        if abs(z) < 92 and abs(x) < 150:
            return True  # walkway + bases
        if abs(x) >= 150 and abs(z) < 95:
            return True  # gyms, fountains, machine, vault
        return False

    attempts = 0
    while len(trees) < 60 and attempts < 5000:
        attempts += 1
        x = rnd.uniform(-285, 285)
        z = rnd.uniform(-198, 198)
        if blocked(x, z):
            continue
        h = rnd.uniform(8, 13)
        crown = rnd.uniform(9, 13)
        green = rnd.choice([(70, 150, 60), (60, 135, 70), (95, 170, 70), (210, 120, 200)])
        trees.append(model("Tree", [
            vcyl("Trunk", h, 1.8, T(x, h / 2, z), (110, 75, 45), "Wood"),
            part("Leaves", (crown, crown, crown), T(x, h + crown * 0.3, z), green, "LeafyGrass",
                 shape="Ball", collide=False),
            part("Leaves2", (crown * 0.7,) * 3, T(x + crown * 0.3, h + crown * 0.65, z - crown * 0.2), green,
                 "LeafyGrass", shape="Ball", collide=False),
        ]))
    return folder("Trees", trees)


def build_fountain(cx, cz):
    water = (90, 200, 255)
    return model("AuraFountain", [
        vcyl("Plaza", 0.4, 44, T(cx, 0.2, cz), (200, 195, 185), "Pavement"),
        vcyl("Basin", 2.4, 22, T(cx, 1.4, cz), (235, 232, 240), "Marble"),
        vcyl("Water", 0.3, 20, T(cx, 2.5, cz), water, "Glass", transparency=0.25, collide=False),
        part("StatueBase", (4, 7, 4), T(cx, 3.5, cz), (235, 232, 240), "Marble"),
        part("StatueEgg", (4, 5.4, 4), T(cx, 9.7, cz), (255, 210, 90), "Neon",
             children=[sphere_mesh(), light(26, 2, (255, 210, 120))]),
    ])


def build_treadmill(tier, cf):
    color = TIER_COLORS[tier - 1]
    dark = (35, 35, 42)

    def L(x, y, z):
        return cf * T(x, y, z)

    children = [
        part("Deck", (7, 0.8, 16), L(0, 0.4, 0), (70, 70, 80), "Metal"),
        # The Belt's look direction is where the runner faces; it pushes the other way.
        part("Belt", (6, 0.3, 15), L(0, 0.95, 0), dark, "Rubber"),
        part("Console", (6, 2, 0.6), L(0, 4.5, -7.4), color, "Neon"),
    ]
    for sx in (-3.4, 3.4):
        children.append(part("Post", (0.4, 3.4, 0.4), L(sx, 2.5, -7), (60, 60, 70), "Metal"))
        children.append(part("Handrail", (0.4, 0.4, 6), L(sx, 4.0, -4.2), color, "Neon"))
    for i, z in enumerate((-6, -3, 0, 3, 6)):
        children.append(part("Stripe", (5.8, 0.06, 0.5), L(0, 1.13, z), color, "Neon", collide=False,
                             query=False, touch=False, transparency=0.35, shadow=False))
    return model("Treadmill", children, attributes={"Tier": tier})


def build_gym(cz, run_dir):
    """run_dir = +1 if runners face +Z, -1 if they face -Z (always away from the walkway)."""
    cx = 200
    children = [
        part("GymFloor", (70, 1, 50), T(cx, 0.5, cz), (65, 65, 78), "Rubber"),
        part("GymRoof", (72, 1.5, 52), T(cx, 18.75, cz), (55, 50, 70), "Metal"),
        part("RoofTrim", (72.6, 0.6, 52.6), T(cx, 17.8, cz), (120, 220, 255), "Neon"),
        invisible("GymSignAnchor", T(cx, 23, cz)),
    ]
    for dx in (-34, 34):
        for dz in (-24, 24):
            children.append(part("GymPillar", (2, 17.5, 2), T(cx + dx, 9.25, cz + dz), (230, 230, 240), "Marble"))
    children.append(part("GymLight", (1, 1, 1), T(cx, 17, cz), (255, 255, 255), "Neon", collide=False,
                         transparency=1, query=False, touch=False, children=[light(40, 1.5, (220, 240, 255))]))
    rotation = RY(math.pi) if run_dir > 0 else CF()  # identity looks toward -Z
    for i, x in enumerate((176, 192, 208, 224)):
        children.append(build_treadmill(i + 1, T(x, 1, cz + 2 * run_dir) * rotation))
    return model("TreadmillGym", children)


# --- bases ------------------------------------------------------------------

def build_plot(index, plot_cf):
    color = PLOT_COLORS[index - 1]
    wall = (228, 218, 205)
    stone = (95, 95, 108)

    def L(x, y, z):
        return plot_cf * T(x, y, z)

    c = [
        invisible("Origin", plot_cf),
        part("Foundation", (60, 0.8, 60), L(0, 0.4, 0), (110, 110, 122), "Slate"),
        part("Floor", (56, 1, 56), L(0, 0.5, 0), color, "CeramicTiles"),
        part("Carpet", (8, 0.1, 44), L(0, 1.05, -4), (190, 40, 60), "Carpet", collide=False),
        part("BackWall", (56, 12, 1), L(0, 7, 27.5), wall, "Brick"),
        part("LeftWall", (1, 12, 56), L(-27.5, 7, 0), wall, "Brick"),
        part("RightWall", (1, 12, 56), L(27.5, 7, 0), wall, "Brick"),
        part("FrontWallLeft", (20, 12, 1), L(-18, 7, -27.5), wall, "Brick"),
        part("FrontWallRight", (20, 12, 1), L(18, 7, -27.5), wall, "Brick"),
        part("TrimBack", (56, 0.6, 1.4), L(0, 13.3, 27.5), color, "Neon"),
        part("TrimLeft", (1.4, 0.6, 56), L(-27.5, 13.3, 0), color, "Neon"),
        part("TrimRight", (1.4, 0.6, 56), L(27.5, 13.3, 0), color, "Neon"),
        part("TrimFrontLeft", (20, 0.6, 1.4), L(-18, 13.3, -27.5), color, "Neon"),
        part("TrimFrontRight", (20, 0.6, 1.4), L(18, 13.3, -27.5), color, "Neon"),
        part("Banner", (14, 5, 0.3), L(0, 9.5, 26.85), color, "Fabric"),
        # Upgrade terminal just inside the gate (left side), screen facing into the base
        part("UpgradeTerminal", (6, 4, 1.4), L(-15, 3, -26.3), (55, 55, 70), "Metal"),
        part("UpgradeScreen", (5, 2.4, 0.2), L(-15, 3.4, -25.55), (255, 200, 60), "Neon", collide=False),
        # Gate
        part("GatePillarLeft", (3, 16, 3), L(-9.5, 8, -27.5), stone, "Slate"),
        part("GatePillarRight", (3, 16, 3), L(9.5, 8, -27.5), stone, "Slate"),
        part("GateArch", (22, 2.5, 3), L(0, 17.25, -27.5), stone, "Slate"),
        part("GateGlow", (16, 0.5, 3.2), L(0, 15.75, -27.5), color, "Neon", children=[light(16, 1.2, color)]),
        # The lock barrier fills the 16-stud gate; invisible and walk-through until locked
        part("LockBarrier", (16, 12, 1), L(0, 7, -27.5), (255, 50, 50), "ForceField", collide=False,
             transparency=1, touch=False, shadow=False),
        invisible("SignAnchor", L(0, 21, -27.5)),
        part("LockPad", (6, 0.3, 4), L(0, 1.15, 22), (255, 70, 70), "Neon", collide=False, touch=False),
        {"name": "Eggs", "className": "Folder"},
    ]
    for sx in (-27.5, 27.5):
        for sz in (-27.5, 27.5):
            c.append(part("Tower", (4, 17, 4), L(sx, 8.5, sz), stone, "Slate"))
            c.append(part("TowerCap", (4.6, 1.2, 4.6), L(sx, 17.6, sz), color, "Neon",
                          children=[light(18, 1.1, color)]))
    for slot in range(1, 11):
        column = -1 if slot <= 5 else 1
        row = (slot - 1) % 5
        x = 17 * column
        z = -16 + row * 9
        c.append(part(f"Pedestal{slot}", (6, 1.5, 6), L(x, 1.75, z), (245, 245, 250), "Marble"))
        c.append(part(f"PedestalRim{slot}", (6.4, 0.3, 6.4), L(x, 2.35, z), color, "Neon"))
        c.append(part(f"CashPad{slot}", (4, 0.3, 4), L(x - 5.5 * column, 1.15, z), (70, 230, 110), "Neon",
                      collide=False, touch=False))
    return model(f"Plot{index}", c, attributes={"PlotIndex": index, "OwnerUserId": 0, "OwnerName": ""})


def main():
    world = []
    world += build_ground()
    world += build_belt()
    world += build_machine()
    world.append(build_lamps())
    world.append(build_trees())
    world.append(invisible("TitleAnchor", T(0, 36, 0)))
    world.append(part("LobbySpawn", (8, 1, 8), T(0, 0.7, 16), (180, 120, 255), "Neon", cls="SpawnLocation",
                      props={"Neutral": True, "Duration": 0}))
    world.append(folder("Gyms", [build_gym(60, 1), build_gym(-60, -1)]))
    world.append(folder("Fountains", [build_fountain(-200, 60), build_fountain(-200, -60)]))

    plots = []
    for index in range(1, 9):
        column = (index - 1) % 4
        side = -1 if index <= 4 else 1
        rotation = RY(math.pi) if side == -1 else CF()  # every base's entrance (local -Z) faces the belt
        plots.append(build_plot(index, T(PLOT_X[column], 0, PLOT_Z * side) * rotation))

    OUT.mkdir(exist_ok=True)
    (OUT / "Map.model.json").write_text(json.dumps({"className": "Folder", "children": world}, indent=1))
    (OUT / "Plots.model.json").write_text(json.dumps({"className": "Folder", "children": plots}, indent=1))

    def count(node):
        return 1 + sum(count(ch) for ch in node.get("children", []))
    print("instances:", sum(count(n) for n in world) + sum(count(n) for n in plots))


if __name__ == "__main__":
    main()
