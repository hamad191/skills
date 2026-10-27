"""Builds AnimeSwarm.rbxlx: all scripts plus the map (spawn island and the three adventure arenas).

Usage: python3 tools/build_place.py   (run from the anime-swarm folder)
"""

import html
import math
import os
import random
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "AnimeSwarm.rbxlx")

# Keep in sync with src/shared/Config.lua (ISLAND_CENTER and each adventure's center).
ISLAND_Z = 1400
GRASS_TOP, BEACH_TOP = 1.25, 0.5
GRASS_R, BEACH_R = 130, 160
PLAZA = (0, ISLAND_Z + 84, 48)  # x, z, radius: the portals stand here (positions come from Config)

MATERIAL = {
    "plastic": 256, "smooth": 272, "neon": 288, "wood": 512, "planks": 528, "slate": 800,
    "cobble": 880, "metal": 1088, "grass": 1280, "sand": 1296, "fabric": 1312, "glass": 1568,
}
SHAPE = {"ball": 0, "block": 1, "cylinder": 2}

_ref = 0
rng = random.Random(7)  # fixed seed: the same map every build


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:05d}"


def item(cls, name, props="", children=()):
    body = f'<string name="Name">{html.escape(name)}</string>{props}'
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{body}</Properties>{"".join(children)}</Item>'


def model(name, children):
    return item("Model", name, children=children)


# --- scripts ----------------------------------------------------------------


def source(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        code = f.read().replace("]]>", "]]]]><![CDATA[>")
    return f'<ProtectedString name="Source"><![CDATA[{code}]]></ProtectedString>'


def script(path):
    base = os.path.basename(path)
    if base.endswith(".server.lua"):
        return item("Script", base[: -len(".server.lua")], source(path))
    if base.endswith(".client.lua"):
        return item("LocalScript", base[: -len(".client.lua")], source(path))
    return item("ModuleScript", base[: -len(".lua")], source(path))


def folder(name, directory):
    files = sorted(f for f in os.listdir(os.path.join(ROOT, directory)) if f.endswith(".lua"))
    return item("Folder", name, children=[script(f"{directory}/{f}") for f in files])


# --- math -------------------------------------------------------------------

IDENTITY = ((1, 0, 0), (0, 1, 0), (0, 0, 1))


def rot_x(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def rot_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def rot_z(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def apply(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


UPRIGHT = rot_z(90)  # stands a cylinder's length (X axis) upright


def face_spawn(x, z):
    """Yaw (degrees) that turns an object's front (-Z) toward the spawn point."""
    return math.degrees(math.atan2(x, z - ISLAND_Z))


# --- parts ------------------------------------------------------------------


def num(v):
    """Plain decimal text (never scientific notation) for the place file."""
    text = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if text in ("", "-0") else text


def cframe(pos, rot):
    r = "".join(f"<R{i}{j}>{num(rot[i][j])}</R{i}{j}>" for i in range(3) for j in range(3))
    return f'<CoordinateFrame name="CFrame"><X>{num(pos[0])}</X><Y>{num(pos[1])}</Y><Z>{num(pos[2])}</Z>{r}</CoordinateFrame>'


def part(name, size, pos, rgb, material="plastic", shape="block", rot=IDENTITY, cls="Part",
         extra="", children=(), transparency=0, collide=True, query=True):
    color = 0xFF000000 | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]
    props = (
        '<bool name="Anchored">true</bool><bool name="Locked">true</bool>'
        f'<Vector3 name="size"><X>{num(size[0])}</X><Y>{num(size[1])}</Y><Z>{num(size[2])}</Z></Vector3>'
        f"{cframe(pos, rot)}"
        f'<Color3uint8 name="Color3uint8">{color}</Color3uint8>'
        f'<token name="Material">{MATERIAL[material]}</token>'
        f'<token name="shape">{SHAPE[shape]}</token>'
        f'<float name="Transparency">{transparency}</float>'
        f'<bool name="CanCollide">{"true" if collide else "false"}</bool>'
        f'<bool name="CanQuery">{"true" if query else "false"}</bool>'
        f"{extra}"
    )
    return item(cls, name, props, children)


class Placer:
    """Places parts in an object's local space (position + yaw)."""

    def __init__(self, x, y, z, yaw=0, query=True):
        self.base, self.rot, self.query = (x, y, z), rot_y(yaw), query

    def __call__(self, name, size, offset, rgb, material="plastic", shape="block", rot=IDENTITY, **kw):
        local = apply(self.rot, offset)
        pos = tuple(self.base[i] + local[i] for i in range(3))
        kw.setdefault("query", self.query)
        return part(name, size, pos, rgb, material, shape, mul(self.rot, rot), **kw)


def fire():
    return item("Fire", "Fire")


def light(rgb, brightness=1.5, rng_=20):
    r, g, b = (c / 255 for c in rgb)
    return item(
        "PointLight",
        "Light",
        f'<float name="Brightness">{brightness}</float><float name="Range">{rng_}</float>'
        f'<Color3 name="Color"><R>{r:.3f}</R><G>{g:.3f}</G><B>{b:.3f}</B></Color3>',
    )


def sign_text(text, rgb=(255, 217, 51)):
    r, g, b = (c / 255 for c in rgb)
    label = item(
        "TextLabel",
        "Text",
        '<float name="BackgroundTransparency">1</float>'
        f'<string name="Text">{html.escape(text)}</string>'
        '<bool name="TextScaled">true</bool>'
        f'<Color3 name="TextColor3"><R>{r:.3f}</R><G>{g:.3f}</G><B>{b:.3f}</B></Color3>'
        '<token name="Font">4</token>'
        '<UDim2 name="Size"><XS>1</XS><XO>0</XO><YS>1</YS><YO>0</YO></UDim2>',
    )
    return item("SurfaceGui", "SurfaceGui", '<token name="Face">5</token>', [label])  # Front (-Z) face


# --- props ------------------------------------------------------------------

WOOD = (120, 85, 50)
DARK_WOOD = (80, 55, 30)
STONE = (110, 112, 120)
LEAF = (60, 150, 60)


def palm(name, x, z, y, height=15, query=True):
    P = Placer(x, y, z, rng.uniform(0, 360), query)
    top = height
    pieces = [P("Trunk", (height, 1.6, 1.6), (0, height / 2, 0), WOOD, "wood", "cylinder", UPRIGHT)]
    for a in range(0, 360, 60):
        leaf_at = apply(rot_y(a), (4.5, -0.6, 0))
        pieces.append(P("Leaf", (9.5, 0.4, 2.6), (leaf_at[0], top + leaf_at[1], leaf_at[2]), LEAF, "grass",
                        rot=mul(rot_y(a), rot_z(-15))))
    for i in range(3):
        a = math.radians(i * 120)
        pieces.append(P("Coconut", (1.3, 1.3, 1.3), (math.cos(a) * 0.9, top - 1, math.sin(a) * 0.9), (90, 60, 30), shape="ball"))
    return model(name, pieces)


def rock(name, x, z, y, size, query=True, rgb=STONE):
    rot = mul(rot_y(rng.uniform(0, 360)), rot_x(rng.uniform(-15, 15)))
    return part(name, size, (x, y + size[1] * 0.35, z), rgb, "slate", rot=rot, query=query)


def bush(name, x, z, y):
    pieces = []
    for i in range(3):
        d = rng.uniform(3, 4.5)
        pieces.append(part("Leaves", (d, d, d), (x + rng.uniform(-1.5, 1.5), y + d * 0.35, z + rng.uniform(-1.5, 1.5)),
                           (rng.randint(50, 80), rng.randint(130, 170), 60), "grass", "ball"))
    return model(name, pieces)


def barrel(name, x, z, y):
    P = Placer(x, y, z)
    return model(name, [
        P("Body", (3, 2.2, 2.2), (0, 1.5, 0), (125, 82, 45), "wood", "cylinder", UPRIGHT),
        P("RimTop", (0.3, 2.35, 2.35), (0, 2.5, 0), (60, 60, 65), "metal", "cylinder", UPRIGHT),
        P("RimBottom", (0.3, 2.35, 2.35), (0, 0.5, 0), (60, 60, 65), "metal", "cylinder", UPRIGHT),
    ])


def crate(name, x, z, y, s=2.5):
    return part(name, (s, s, s), (x, y + s / 2, z), (165, 125, 75), "planks", rot=rot_y(rng.uniform(0, 90)))


def torch(name, x, z, y):
    P = Placer(x, y, z)
    return model(name, [
        P("Post", (0.6, 6, 0.6), (0, 3, 0), DARK_WOOD, "wood"),
        P("Bowl", (1.4, 0.7, 1.4), (0, 6.2, 0), (60, 60, 65), "metal", children=[fire(), light((255, 160, 60), 1.5, 18)]),
    ])


def hut(name, x, z, w, d, h, wall, roof, sign=None):
    P = Placer(x, GRASS_TOP, z, face_spawn(x, z))
    top = 0.6 + h
    rise = (w / 4) * math.tan(math.radians(30))
    slope = (w / 2) / math.cos(math.radians(30)) + 1.2
    pieces = [
        P("Floor", (w + 1.5, 0.6, d + 1.5), (0, 0.3, 0), WOOD, "planks"),
        P("Walls", (w, h, d), (0, 0.6 + h / 2, 0), wall, "planks"),
        P("Door", (w * 0.22, h * 0.6, 0.3), (0, 0.6 + h * 0.3, -d / 2 - 0.1), DARK_WOOD, "wood"),
        P("WindowL", (w * 0.16, h * 0.22, 0.3), (-w * 0.3, 0.6 + h * 0.62, -d / 2 - 0.1), (255, 215, 130), "neon"),
        P("WindowR", (w * 0.16, h * 0.22, 0.3), (w * 0.3, 0.6 + h * 0.62, -d / 2 - 0.1), (255, 215, 130), "neon"),
        P("RoofL", (slope, 0.7, d + 2), (-w / 4, top + rise, 0), roof, "slate", rot=rot_z(30)),
        P("RoofR", (slope, 0.7, d + 2), (w / 4, top + rise, 0), roof, "slate", rot=rot_z(-30)),
        P("Ridge", (0.9, 0.9, d + 2.2), (0, top + 2 * rise + 0.25, 0), roof, "slate"),
    ]
    if sign:
        pieces.append(P("Sign", (w * 0.7, 2.4, 0.4), (0, 0.6 + h * 0.86, -d / 2 - 0.35), (90, 55, 30), "planks",
                        children=[sign_text(sign)]))
    return model(name, pieces)


def stall(name, x, z, cloth):
    P = Placer(x, GRASS_TOP, z, face_spawn(x, z))
    pieces = [P("Counter", (6, 2.5, 2.5), (0, 1.25, -1), WOOD, "planks")]
    for px in (-3, 3):
        for pz in (-1.8, 1.8):
            pieces.append(P("Post", (0.4, 6, 0.4), (px, 3, pz), DARK_WOOD, "wood"))
    for i in range(5):
        pieces.append(P("Awning", (1.5, 0.3, 5), (-3 + i * 1.5, 6.1, 0), cloth if i % 2 == 0 else (245, 240, 230), "fabric"))
    for i, rgb in enumerate(((230, 60, 50), (250, 200, 40), (120, 200, 60))):
        pieces.append(P("Fruit", (1, 1, 1), (-1.6 + i * 1.6, 3, -1), rgb, "smooth", "ball"))
    return model(name, pieces)


def campfire(name, x, z):
    y = GRASS_TOP
    P = Placer(x, y, z)
    pieces = []
    for i in range(8):
        a = math.radians(i * 45)
        pieces.append(P("Stone", (1.3, 1.3, 1.3), (math.cos(a) * 2.2, 0.4, math.sin(a) * 2.2), STONE, "slate", "ball"))
    pieces.append(P("LogA", (4, 0.8, 0.8), (0, 0.5, 0), DARK_WOOD, "wood", "cylinder", rot_y(45)))
    pieces.append(P("LogB", (4, 0.8, 0.8), (0, 0.5, 0), DARK_WOOD, "wood", "cylinder", rot_y(-45)))
    pieces.append(P("Flame", (1, 1, 1), (0, 1, 0), (255, 140, 40), transparency=1, collide=False,
                    children=[fire(), light((255, 150, 60), 2, 24)]))
    for i in range(4):
        a = i * 90 + 45
        at = apply(rot_y(a), (0, 0.6, -6))
        pieces.append(P("Bench", (6, 1.2, 1.2), at, WOOD, "wood", "cylinder", rot_y(a)))
    return model(name, pieces)


def lighthouse(name, x, z):
    y = BEACH_TOP
    P = Placer(x, y, z)
    pieces = [rock(f"Rock{i}", x + math.cos(i) * 7, z + math.sin(i) * 7, y, (6, 4, 5)) for i in range(7)]
    for i in range(5):
        color = (240, 240, 240) if i % 2 == 0 else (200, 40, 40)
        pieces.append(P(f"Tower{i}", (7, 9 - i * 0.6, 9 - i * 0.6), (0, 3.5 + i * 7, 0), color, "smooth", "cylinder", UPRIGHT))
    pieces += [
        P("Gallery", (1, 12, 12), (0, 35.5, 0), (60, 60, 65), "metal", "cylinder", UPRIGHT),
        P("LampRoom", (5, 6.5, 6.5), (0, 38.5, 0), (200, 230, 255), "glass", "cylinder", UPRIGHT, transparency=0.4),
        P("Lamp", (3, 3, 3), (0, 38.5, 0), (255, 230, 120), "neon", "ball", collide=False, children=[light((255, 230, 150), 3, 60)]),
        P("Cap", (1, 8, 8), (0, 41.5, 0), (200, 40, 40), "smooth", "cylinder", UPRIGHT),
        P("Dome", (4.5, 4.5, 4.5), (0, 42.5, 0), (200, 40, 40), "smooth", "ball"),
    ]
    return model(name, pieces)


def flagpole(name, x, z):
    P = Placer(x, GRASS_TOP, z, face_spawn(x, z))
    return model(name, [
        P("Base", (1, 3, 3), (0, 0.5, 0), STONE, "slate", "cylinder", UPRIGHT),
        P("Pole", (30, 0.8, 0.8), (0, 15, 0), (170, 170, 175), "metal", "cylinder", UPRIGHT),
        P("Flag", (7, 4.5, 0.2), (3.8, 27.5, 0), (20, 20, 20), "fabric"),
        P("Skull", (1.8, 1.8, 1.8), (3.8, 28, -0.2), (245, 245, 240), "smooth", "ball"),
        P("BoneA", (4, 0.5, 0.2), (3.8, 26.8, -0.15), (245, 245, 240), "smooth", rot=rot_z(35)),
        P("BoneB", (4, 0.5, 0.2), (3.8, 26.8, -0.15), (245, 245, 240), "smooth", rot=rot_z(-35)),
    ])


def chest(name, x, z):
    P = Placer(x, GRASS_TOP, z, face_spawn(x, z))
    gold = (255, 200, 50)
    return model(name, [
        P("Base", (4, 2, 2.6), (0, 1, 0), (110, 70, 35), "wood"),
        P("Lid", (4.1, 0.9, 2.7), (0, 2.45, 0.2), (110, 70, 35), "wood", rot=rot_x(-20)),
        P("BandL", (0.35, 2.1, 2.75), (-1.5, 1.05, 0), gold, "metal"),
        P("BandR", (0.35, 2.1, 2.75), (1.5, 1.05, 0), gold, "metal"),
        P("Gold", (2.4, 2.4, 2.4), (0, 2.1, 0), gold, "neon", "ball", collide=False, children=[light(gold, 1.5, 14)]),
    ])


def ship(x, z):
    wood, dark = (95, 60, 35), (20, 20, 20)
    P = Placer(x, 0, z)
    return model("PirateShip", [
        P("Hull", (18, 8, 54), (0, 0, 0), wood, "wood"),
        P("Bow", (12, 6, 8), (0, 1, -31), wood, "wood"),
        P("Deck", (16, 0.5, 50), (0, 4.25, 0), (170, 125, 80), "planks"),
        P("Railing", (17, 1.2, 0.5), (0, 5, 24.5), wood, "wood"),
        P("Figurehead", (5, 5, 5), (0, 5, -36), (255, 210, 60), "smooth", "ball"),
        P("Mane", (1, 6.5, 6.5), (0, 5, -35), (255, 140, 30), "smooth", "cylinder", rot_y(90)),
        P("Mast", (34, 1.6, 1.6), (0, 21.5, 0), (110, 75, 45), "wood", "cylinder", UPRIGHT),
        P("Sail", (16, 14, 0.4), (0, 20, -1), (245, 240, 225), "fabric"),
        P("Emblem", (4, 4, 0.2), (0, 20, -1.3), dark),
        P("Skull", (2, 2, 2), (0, 20.5, -1.6), (250, 250, 250), "smooth", "ball"),
        P("Flag", (5, 3, 0.2), (2.6, 37, 0), dark, "fabric"),
    ])


# --- spawn island -----------------------------------------------------------

BLOCKED = []  # (x, z, radius) areas bushes should avoid


def free(x, z):
    if abs(x) < 9 and ISLAND_Z < z < ISLAND_Z + 40:  # the path
        return False
    return all(math.hypot(x - bx, z - bz) > br for bx, bz, br in BLOCKED)


def spawn_island():
    cz = ISLAND_Z
    sea = (40, 120, 210)
    parts = [
        part("Sea", (900, 1, 900), (0, -3, cz), sea, "smooth", transparency=0.15),
        part("Beach", (4, BEACH_R * 2, BEACH_R * 2), (0, -1.5, cz), (232, 212, 155), "sand", "cylinder", UPRIGHT),
        part("Grass", (1, GRASS_R * 2, GRASS_R * 2), (0, 0.75, cz), (95, 165, 75), "grass", "cylinder", UPRIGHT),
        part("SpawnLocation", (14, 1, 14), (0, 1.75, cz), (200, 40, 40), cls="SpawnLocation",
             extra='<bool name="Neutral">true</bool><int name="Duration">0</int>'),
        part("SpawnRing", (0.2, 20, 20), (0, 1.3, cz), (255, 205, 60), "neon", "cylinder", UPRIGHT, transparency=0.3, collide=False),
        part("Path", (10, 0.3, 30), (0, 1.4, cz + 23), (175, 165, 145), "cobble"),
        part("PlazaRim", (0.4, PLAZA[2] * 2 + 4, PLAZA[2] * 2 + 4), (0, 1.45, PLAZA[1]), (80, 82, 95), "slate", "cylinder", UPRIGHT),
        part("Plaza", (0.6, PLAZA[2] * 2, PLAZA[2] * 2), (0, 1.55, PLAZA[1]), (150, 150, 160), "cobble", "cylinder", UPRIGHT),
    ]
    BLOCKED.extend([(0, cz, 14), (PLAZA[0], PLAZA[1], PLAZA[2] + 4)])

    # signs and landmarks around the spawn
    S = Placer(16, GRASS_TOP, cz + 16, 0)
    parts.append(model("WelcomeSign", [
        S("PostL", (1, 10, 1), (-9, 5, 0), WOOD, "wood"),
        S("PostR", (1, 10, 1), (9, 5, 0), WOOD, "wood"),
        S("Board", (20, 7, 0.6), (0, 8.5, 0), (90, 55, 30), "planks",
          children=[sign_text("WELCOME, PIRATE!\nPick your crew, then step into a portal")]),
    ]))
    parts.append(flagpole("JollyRoger", -14, cz - 6))
    parts.append(chest("TreasureChest", 13, cz - 9))
    BLOCKED.extend([(16, cz + 16, 12), (-14, cz - 6, 6), (13, cz - 9, 6)])

    # torches along the path and around the portal plaza
    for i, z in enumerate((cz + 12, cz + 24, cz + 36)):
        parts.append(torch(f"PathTorchL{i}", -7, z, GRASS_TOP))
        parts.append(torch(f"PathTorchR{i}", 7, z, GRASS_TOP))
    for i, a in enumerate((200, 340, 60, 120)):
        x, z = PLAZA[0] + math.cos(math.radians(a)) * (PLAZA[2] - 3), PLAZA[1] + math.sin(math.radians(a)) * (PLAZA[2] - 3)
        parts.append(torch(f"PlazaTorch{i}", x, z, 1.85))

    # village (west)
    village = [
        hut("HutA", -62, cz + 18, 12, 10, 9, (205, 170, 120), (150, 60, 45)),
        hut("HutB", -70, cz - 18, 12, 10, 9, (190, 160, 125), (60, 90, 150)),
        hut("HutC", -48, cz - 52, 10, 8, 8, (215, 185, 140), (150, 60, 45)),
        hut("Tavern", -92, cz + 50, 22, 16, 11, (170, 120, 80), (110, 45, 35), sign="PARTY'S BAR"),
    ]
    BLOCKED.extend([(-62, cz + 18, 12), (-70, cz - 18, 12), (-48, cz - 52, 10), (-92, cz + 50, 18)])
    for i, (x, z) in enumerate(((-80, cz + 36), (-83, cz + 33), (-74, cz + 62), (-55, cz + 30), (-58, cz - 30))):
        village.append(barrel(f"Barrel{i}", x, z, GRASS_TOP))
    for i, (x, z) in enumerate(((-78, cz + 40), (-60, cz - 34), (-40, cz - 60))):
        village.append(crate(f"Crate{i}", x, z, GRASS_TOP))
    parts.append(model("Village", village))

    # market (east)
    market = [
        stall("StallA", 55, cz + 14, (220, 60, 60)),
        stall("StallB", 64, cz - 12, (60, 120, 220)),
        stall("StallC", 54, cz - 38, (60, 170, 80)),
    ]
    BLOCKED.extend([(55, cz + 14, 8), (64, cz - 12, 8), (54, cz - 38, 8)])
    for i, (x, z) in enumerate(((68, cz + 26), (72, cz + 22), (75, cz - 26), (66, cz - 50))):
        market.append(crate(f"Crate{i}", x, z, GRASS_TOP, rng.uniform(2, 3)))
    for i, (x, z) in enumerate(((70, cz + 4), (78, cz - 2))):
        market.append(barrel(f"Barrel{i}", x, z, GRASS_TOP))
    parts.append(model("Market", market))

    parts.append(campfire("Campfire", -25, cz - 35))
    BLOCKED.append((-25, cz - 35, 9))

    # a little pond with a rocky rim
    pond_x, pond_z, pond_r = 45, cz - 82, 13
    pond = [part("Water", (0.3, pond_r * 2, pond_r * 2), (pond_x, GRASS_TOP + 0.05, pond_z), (60, 150, 220), "smooth",
                 "cylinder", UPRIGHT, transparency=0.2, collide=False)]
    for i in range(12):
        a = math.radians(i * 30 + rng.uniform(-8, 8))
        pond.append(rock(f"Rim{i}", pond_x + math.cos(a) * pond_r, pond_z + math.sin(a) * pond_r, GRASS_TOP,
                         (rng.uniform(2, 3.5), rng.uniform(1, 2), rng.uniform(2, 3.5))))
    for i in range(3):
        a = math.radians(rng.uniform(0, 360))
        pond.append(part(f"LilyPad{i}", (0.1, 2.5, 2.5), (pond_x + math.cos(a) * 6, GRASS_TOP + 0.25, pond_z + math.sin(a) * 6),
                         (70, 160, 70), "grass", "cylinder", UPRIGHT, collide=False))
    parts.append(model("Pond", pond))
    BLOCKED.append((pond_x, pond_z, pond_r + 5))
    lighthouse_at = (138, cz - 55)
    parts.append(lighthouse("Lighthouse", *lighthouse_at))

    # beach: palms and rocks in a ring, leaving room for the dock (south) and lighthouse
    dock_angle, lighthouse_angle = 270, math.degrees(math.atan2(lighthouse_at[1] - cz, lighthouse_at[0])) % 360
    palms, rocks = [], []
    for i, a in enumerate(range(0, 360, 20)):
        if min(abs(a - dock_angle), 360 - abs(a - dock_angle)) < 22 or min(abs(a - lighthouse_angle), 360 - abs(a - lighthouse_angle)) < 14:
            continue
        r = 146 + rng.uniform(-3, 3)
        palms.append(palm(f"Palm{i}", math.cos(math.radians(a)) * r, cz + math.sin(math.radians(a)) * r, BEACH_TOP, rng.uniform(13, 18)))
    for i in range(14):
        a = rng.uniform(0, 360)
        if min(abs(a - dock_angle), 360 - abs(a - dock_angle)) < 20:
            continue
        r = rng.uniform(150, 158)
        rocks.append(rock(f"Rock{i}", math.cos(math.radians(a)) * r, cz + math.sin(math.radians(a)) * r, BEACH_TOP,
                          (rng.uniform(3, 7), rng.uniform(2, 5), rng.uniform(3, 6))))
    parts.append(model("Palms", palms))
    parts.append(model("Rocks", rocks))

    # a few palms inland, then bushes scattered over the grass
    inland = []
    while len(inland) < 7:
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(30, 115)
        x, z = math.cos(a) * r, cz + math.sin(a) * r
        if free(x, z):
            inland.append(palm(f"InlandPalm{len(inland)}", x, z, GRASS_TOP, rng.uniform(12, 16)))
            BLOCKED.append((x, z, 8))
    parts.append(model("InlandPalms", inland))
    bushes = []
    while len(bushes) < 40:
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(25, 122)
        x, z = math.cos(a) * r, cz + math.sin(a) * r
        if free(x, z):
            bushes.append(bush(f"Bush{len(bushes)}", x, z, GRASS_TOP))
            BLOCKED.append((x, z, 5))
    parts.append(model("Bushes", bushes))

    # dock and the ship waiting to sail
    dock = [part("Planks", (12, 1, 54), (0, 0, cz - 180), (130, 90, 50), "planks")]
    for i, z in enumerate(range(cz - 202, cz - 156, 12)):
        for x in (-6, 6):
            dock.append(part(f"Post{i}", (6, 0.9, 0.9), (x, -2, z), DARK_WOOD, "wood", "cylinder", UPRIGHT))
    parts.append(model("Dock", dock))
    parts.append(ship(26, cz - 205))

    return model("SpawnIsland", parts)


# --- adventure arenas ---------------------------------------------------------
# Decorations use CanQuery = false so enemy spawns and effects treat the floor as the ground.


def scatter(cx, cz, count, min_r=80, max_r=480):
    for _ in range(count):
        while True:
            x, z = rng.uniform(-max_r, max_r), rng.uniform(-max_r, max_r)
            if math.hypot(x, z) > min_r:
                yield cx + x, cz + z
                break


def east_blue(cx, cz):
    props = [part("Floor", (1000, 2, 1000), (cx, -1, cz), (85, 150, 70), "grass")]
    for i, (x, z) in enumerate(scatter(cx, cz, 24, 200)):
        props.append(palm(f"Palm{i}", x, z, 0, rng.uniform(13, 18), query=False))
    for i, (x, z) in enumerate(scatter(cx, cz, 30)):
        props.append(rock(f"Rock{i}", x, z, 0, (rng.uniform(3, 8), rng.uniform(2, 5), rng.uniform(3, 7)), query=False))
    return model("EastBlueArena", props)


def grand_line(cx, cz):
    sandstone = (215, 185, 125)
    props = [part("Floor", (1000, 2, 1000), (cx, -1, cz), (226, 196, 135), "sand")]
    for i, (x, z) in enumerate(scatter(cx, cz, 30)):
        h = rng.uniform(7, 12)
        P = Placer(x, 0, z, rng.uniform(0, 360), query=False)
        props.append(model(f"Cactus{i}", [
            P("Trunk", (h, 2, 2), (0, h / 2, 0), (70, 140, 60), "grass", "cylinder", UPRIGHT),
            P("ArmL", (3, 1.2, 1.2), (-1.8, h * 0.5, 0), (70, 140, 60), "grass", "cylinder"),
            P("ArmLUp", (3, 1.2, 1.2), (-3, h * 0.5 + 1.4, 0), (70, 140, 60), "grass", "cylinder", UPRIGHT),
            P("ArmR", (2.6, 1.2, 1.2), (1.6, h * 0.65, 0), (70, 140, 60), "grass", "cylinder"),
            P("ArmRUp", (2.4, 1.2, 1.2), (2.6, h * 0.65 + 1.2, 0), (70, 140, 60), "grass", "cylinder", UPRIGHT),
        ]))
    for i, (x, z) in enumerate(scatter(cx, cz, 14, 150)):
        h = rng.uniform(8, 18)
        P = Placer(x, 0, z, rng.uniform(0, 360), query=False)
        props.append(model(f"Ruin{i}", [
            P("Pillar", (3, h, 3), (0, h / 2, 0), sandstone, "slate"),
            P("Top", (4, 1, 4), (0, h + 0.5, 0), sandstone, "slate"),
            P("Fallen", (3, 3, 10), (5, 1.5, 2), sandstone, "slate", rot=rot_y(rng.uniform(0, 90))),
        ]))
    return model("GrandLineArena", props)


def new_world(cx, cz):
    props = [part("Floor", (1000, 2, 1000), (cx, -1, cz), (55, 45, 50), "slate")]
    for i, (x, z) in enumerate(scatter(cx, cz, 45, 30)):
        props.append(part(f"LavaCrack{i}", (1.5, 0.1, rng.uniform(20, 60)), (x, 0.05, z), (255, 90, 20), "neon",
                          rot=rot_y(rng.uniform(0, 180)), collide=False, query=False))
    for i, (x, z) in enumerate(scatter(cx, cz, 8, 120)):
        d = rng.uniform(10, 18)
        props.append(part(f"MagmaPool{i}", (0.1, d, d), (x, 0.05, z), (255, 120, 30), "neon", "cylinder", UPRIGHT,
                          collide=False, query=False))
    for i, (x, z) in enumerate(scatter(cx, cz, 26, 200)):
        h = rng.uniform(8, 20)
        rot = mul(rot_y(rng.uniform(0, 360)), rot_x(rng.uniform(-20, 20)))
        props.append(part(f"Spike{i}", (rng.uniform(3, 6), h, rng.uniform(3, 6)), (x, h * 0.4, z), (35, 30, 35), "slate", rot=rot, query=False))
    return model("NewWorldArena", props)


# --- place ------------------------------------------------------------------


def lighting():
    return item(
        "Lighting",
        "Lighting",
        '<string name="TimeOfDay">14:30:00</string><float name="Brightness">2.5</float>',
        children=[
            item("Atmosphere", "Atmosphere", '<float name="Density">0.25</float><float name="Haze">1</float><float name="Glare">0.3</float>'),
            item("BloomEffect", "Bloom", '<float name="Intensity">0.6</float><float name="Size">24</float><float name="Threshold">1.3</float>'),
            item("SunRaysEffect", "SunRays", '<float name="Intensity">0.06</float><float name="Spread">0.7</float>'),
        ],
    )


def build():
    workspace = item(
        "Workspace",
        "Workspace",
        children=[spawn_island(), east_blue(0, 0), grand_line(-1600, 0), new_world(1600, 0)],
    )
    replicated = item("ReplicatedStorage", "ReplicatedStorage", children=[folder("Shared", "src/shared")])
    server = item("ServerScriptService", "ServerScriptService", children=[folder("Server", "src/server")])
    starter = item(
        "StarterPlayer",
        "StarterPlayer",
        '<token name="GameSettingsAvatar">1</token>',  # R15 avatars: the attack animations bend R15 joints
        children=[
            item("StarterPlayerScripts", "StarterPlayerScripts", children=[folder("Client", "src/client")]),
            item(
                "StarterCharacterScripts",
                "StarterCharacterScripts",
                children=[script("src/character/Health.server.lua")],
            ),
        ],
    )
    xml = f'<roblox version="4">{workspace}{lighting()}{replicated}{server}{starter}</roblox>'
    ET.fromstring(xml)  # fail loudly if the XML is malformed
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"Wrote {OUT} ({len(xml) // 1024} KB)")


if __name__ == "__main__":
    build()
