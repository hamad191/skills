"""Builds AnimeSwarm.rbxlx: all scripts plus the map (spawn island and the 20 adventure arenas).

Usage: python3 tools/build_place.py   (run from the anime-swarm folder)
"""

import html
import math
import os
import random
import re
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
    "concrete": 816, "brick": 848, "cobble": 880, "metal": 1088, "grass": 1280, "sand": 1296, "fabric": 1312,
    "ice": 1536, "glass": 1568,
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


def hut(name, x, z, w, d, h, wall, roof, sign=None, y=GRASS_TOP, yaw=None, query=True):
    P = Placer(x, y, z, face_spawn(x, z) if yaw is None else yaw, query)
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


def npc_spots():
    """(x, z) of every island NPC, read from Config.NPCS so bushes keep clear of them."""
    with open(os.path.join(ROOT, "src/shared/Config.lua"), encoding="utf-8") as f:
        text = f.read()
    block = text[text.index("Config.NPCS = {"):text.index("Config.MASTERY")]
    return [(float(x), float(z)) for x, z in re.findall(r"position = Vector3\.new\((-?[\d.]+), 0, (-?[\d.]+)\)", block)]


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
    BLOCKED.extend((x, z, 8) for x, z in npc_spots())  # the island NPCs (server/Npcs.lua) stand here

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
# One arena per map in Config.Maps, dressed by its theme. Decorations use CanQuery = false
# so enemy spawns and effects treat the floor as the ground.

MAP_SPACING = 1200  # keep in sync with Config.MAP_SPACING
DENSITY = 1.5  # scales every theme's decoration counts


def read_maps():
    """(key, name, theme) for every map, in order, straight from Config.lua."""
    with open(os.path.join(ROOT, "src/shared/Config.lua"), encoding="utf-8") as f:
        text = f.read()
    maps = re.findall(r'\{ key = "(\w+)", name = "([^"]+)", theme = "(\w+)"', text)
    assert len(maps) == 20, f"expected 20 maps in Config.lua, found {len(maps)}"
    return maps


def map_center(index):
    """Same formula as Config.lua: a 5-wide grid of arenas south of the island."""
    return ((index % 5) - 2) * MAP_SPACING, -MAP_SPACING * (1 + index // 5)


def scatter(cx, cz, count, min_r=80, max_r=480):
    for _ in range(count):
        while True:
            x, z = rng.uniform(-max_r, max_r), rng.uniform(-max_r, max_r)
            if math.hypot(x, z) > min_r:
                yield cx + x, cz + z
                break


def deco(name, size, x, y, z, rgb, material="plastic", shape="block", rot=IDENTITY, **kw):
    kw.setdefault("query", False)
    return part(name, size, (x, y, z), rgb, material, shape, rot, **kw)


def placer(x, z):
    return Placer(x, 0, z, rng.uniform(0, 360), query=False)


# decoration builders: (name, x, z) -> place-file item
def p_palm(n, x, z):
    return palm(n, x, z, 0, rng.uniform(13, 18), query=False)


def p_rock(n, x, z, rgb=STONE):
    return rock(n, x, z, 0, (rng.uniform(3, 8), rng.uniform(2, 5), rng.uniform(3, 7)), query=False, rgb=rgb)


def p_bush(n, x, z):
    d = rng.uniform(3, 5)
    return deco(n, (d, d, d), x, d * 0.35, z, (rng.randint(50, 80), rng.randint(120, 160), 60), "grass", "ball")


def p_cactus(n, x, z):
    h, P, g = rng.uniform(7, 12), placer(x, z), (70, 140, 60)
    return model(n, [
        P("Trunk", (h, 2, 2), (0, h / 2, 0), g, "grass", "cylinder", UPRIGHT),
        P("ArmL", (3, 1.2, 1.2), (-1.8, h * 0.5, 0), g, "grass", "cylinder"),
        P("ArmLUp", (3, 1.2, 1.2), (-3, h * 0.5 + 1.4, 0), g, "grass", "cylinder", UPRIGHT),
        P("ArmR", (2.6, 1.2, 1.2), (1.6, h * 0.65, 0), g, "grass", "cylinder"),
        P("ArmRUp", (2.4, 1.2, 1.2), (2.6, h * 0.65 + 1.2, 0), g, "grass", "cylinder", UPRIGHT),
    ])


def p_ruin(n, x, z, rgb=(215, 185, 125)):
    h, P = rng.uniform(8, 18), placer(x, z)
    return model(n, [
        P("Pillar", (3, h, 3), (0, h / 2, 0), rgb, "slate"),
        P("Top", (4, 1, 4), (0, h + 0.5, 0), rgb, "slate"),
        P("Fallen", (3, 3, 10), (5, 1.5, 2), rgb, "slate", rot=rot_y(rng.uniform(0, 90))),
    ])


def p_gold_ruin(n, x, z):
    return p_ruin(n, x, z, (235, 200, 90))


def p_lava(n, x, z):
    return deco(n, (1.5, 0.1, rng.uniform(20, 60)), x, 0.05, z, (255, 90, 20), "neon", rot=rot_y(rng.uniform(0, 180)), collide=False)


def p_magma(n, x, z):
    d = rng.uniform(10, 18)
    return deco(n, (0.1, d, d), x, 0.05, z, (255, 120, 30), "neon", "cylinder", UPRIGHT, collide=False)


def p_spike(n, x, z, rgb=(35, 30, 35), material="slate"):
    h = rng.uniform(8, 20)
    rot = mul(rot_y(rng.uniform(0, 360)), rot_x(rng.uniform(-20, 20)))
    return deco(n, (rng.uniform(3, 6), h, rng.uniform(3, 6)), x, h * 0.4, z, rgb, material, rot=rot)


def p_ice(n, x, z):
    return p_spike(n, x, z, (170, 215, 245), "ice")


def p_pine(n, x, z):
    P, h = placer(x, z), rng.uniform(12, 18)
    pieces = [P("Trunk", (h * 0.4, 1.4, 1.4), (0, h * 0.2, 0), (100, 70, 45), "wood", "cylinder", UPRIGHT)]
    for i in range(3):
        w = 9 - i * 2.5
        y = h * 0.35 + i * h * 0.22
        pieces.append(P(f"Leaves{i}", (w, h * 0.25, w), (0, y, 0), (40, 100, 60), "grass", rot=rot_y(45 * i)))
        pieces.append(P(f"Snow{i}", (w * 0.8, 0.4, w * 0.8), (0, y + h * 0.13, 0), (250, 250, 255), "sand", rot=rot_y(45 * i)))
    return model(n, pieces)


def p_big_tree(n, x, z):
    P, h = placer(x, z), rng.uniform(16, 24)
    pieces = [P("Trunk", (h, 3, 3), (0, h / 2, 0), (90, 60, 35), "wood", "cylinder", UPRIGHT)]
    for i in range(3):
        a = math.radians(i * 120)
        d = rng.uniform(8, 11)
        pieces.append(P(f"Leaves{i}", (d, d, d), (math.cos(a) * 3, h + rng.uniform(-1, 2), math.sin(a) * 3), (30, rng.randint(100, 130), 45), "grass", "ball"))
    return model(n, pieces)


def p_house(n, x, z):
    wall = rng.choice([(205, 170, 120), (190, 160, 125), (215, 185, 140), (230, 220, 200)])
    roof = rng.choice([(150, 60, 45), (60, 90, 150), (110, 45, 35), (70, 120, 80)])
    return hut(n, x, z, rng.uniform(10, 14), rng.uniform(8, 11), rng.uniform(8, 10), wall, roof, y=0, yaw=rng.uniform(0, 360), query=False)


def p_crate(n, x, z):
    s = rng.uniform(2, 3.5)
    return deco(n, (s, s, s), x, s / 2, z, (165, 125, 75), "planks", rot=rot_y(rng.uniform(0, 90)))


def p_barrel(n, x, z):
    return model(n, [
        deco("Body", (3, 2.2, 2.2), x, 1.5, z, (125, 82, 45), "wood", "cylinder", UPRIGHT),
        deco("Rim", (0.3, 2.35, 2.35), x, 2.5, z, (60, 60, 65), "metal", "cylinder", UPRIGHT),
    ])


def p_lamp(n, x, z):
    return model(n, [
        deco("Post", (0.5, 7, 0.5), x, 3.5, z, (40, 40, 45), "metal"),
        deco("Lamp", (1.2, 1.2, 1.2), x, 7.4, z, (255, 220, 140), "neon", collide=False),
    ])


def p_wall(n, x, z, rgb=(170, 172, 180), material="concrete"):
    return deco(n, (rng.uniform(12, 20), 5, 2), x, 2.5, z, rgb, material, rot=rot_y(rng.choice([0, 90]) + rng.uniform(-5, 5)))


def p_brick_wall(n, x, z):
    return p_wall(n, x, z, (150, 80, 60), "brick")


def p_cannon(n, x, z):
    P = placer(x, z)
    return model(n, [
        P("Base", (3, 1.5, 4), (0, 0.75, 0), (110, 75, 45), "wood"),
        P("Barrel", (5, 1.4, 1.4), (0, 2, -1), (40, 40, 45), "metal", "cylinder", rot_y(90)),
    ])


def p_marine_flag(n, x, z):
    return model(n, [
        deco("Pole", (16, 0.6, 0.6), x, 8, z, (170, 170, 175), "metal", "cylinder", UPRIGHT),
        deco("Flag", (6, 4, 0.2), x + 3.2, 13.5, z, (245, 245, 250), "fabric"),
        deco("Stripe", (6, 0.8, 0.22), x + 3.2, 13.5, z, (40, 80, 170), "fabric"),
    ])


def p_mast(n, x, z):
    return model(n, [
        deco("Mast", (24, 1.4, 1.4), x, 12, z, (110, 75, 45), "wood", "cylinder", UPRIGHT),
        deco("Sail", (12, 10, 0.3), x, 15, z, (245, 240, 225), "fabric", rot=rot_y(rng.uniform(0, 180))),
    ])


def p_rail(n, x, z):
    return deco(n, (rng.uniform(10, 16), 1.2, 0.6), x, 0.6, z, (110, 75, 45), "wood", rot=rot_y(rng.uniform(0, 180)))


def p_umbrella(n, x, z):
    color = rng.choice([(230, 60, 60), (60, 120, 220), (250, 200, 40)])
    return model(n, [
        deco("Pole", (6, 0.3, 0.3), x, 3, z, (230, 230, 230), "metal", "cylinder", UPRIGHT),
        deco("Shade", (0.4, 7, 7), x, 6, z, color, "fabric", "cylinder", UPRIGHT),
    ])


def p_cloud(n, x, z):
    pieces = []
    for i in range(4):
        d = rng.uniform(4, 8)
        pieces.append(deco(f"Puff{i}", (d, d, d), x + rng.uniform(-4, 4), d * 0.25, z + rng.uniform(-4, 4), (250, 250, 255), "smooth", "ball", collide=False))
    return model(n, pieces)


def p_dead_tree(n, x, z):
    P, h = placer(x, z), rng.uniform(10, 16)
    bark = (60, 45, 40)
    return model(n, [
        P("Trunk", (h, 1.4, 1.4), (0, h / 2, 0), bark, "wood", "cylinder", UPRIGHT),
        P("BranchA", (5, 0.6, 0.6), (1.8, h * 0.7, 0), bark, "wood", "cylinder", rot_z(35)),
        P("BranchB", (4, 0.5, 0.5), (-1.5, h * 0.8, 0.5), bark, "wood", "cylinder", rot_z(150)),
    ])


def p_grave(n, x, z):
    P = placer(x, z)
    return model(n, [
        P("Stone", (2.2, 3, 0.6), (0, 1.5, 0), (120, 120, 130), "slate"),
        P("Mound", (3, 0.6, 4), (0, 0.3, 2), (70, 60, 50), "grass"),
    ])


def p_pumpkin(n, x, z):
    d = rng.uniform(1.6, 2.6)
    return deco(n, (d, d, d), x, d * 0.4, z, (240, 120, 30), "smooth", "ball")


def p_wisp(n, x, z):
    return deco(n, (1, 1, 1), x, rng.uniform(3, 7), z, (120, 255, 150), "neon", "ball", collide=False)


def p_root(n, x, z):
    P = placer(x, z)
    bark = (120, 95, 60)
    return model(n, [
        P("RootA", (16, 3, 3), (-4, 3, 0), bark, "wood", "cylinder", rot_z(40)),
        P("RootB", (16, 3, 3), (4, 3, 0), bark, "wood", "cylinder", rot_z(140)),
        P("Trunk", (26, 4, 4), (0, 14, 0), bark, "wood", "cylinder", UPRIGHT),
    ])


def p_bubble(n, x, z):
    d = rng.uniform(2, 6)
    return deco(n, (d, d, d), x, rng.uniform(3, 12), z, (200, 230, 255), "glass", "ball", transparency=0.5, collide=False)


def p_bars(n, x, z):
    P = placer(x, z)
    pieces = [P("Top", (12, 0.6, 0.6), (0, 8, 0), (60, 60, 65), "metal"), P("Bottom", (12, 0.6, 0.6), (0, 0.3, 0), (60, 60, 65), "metal")]
    for i in range(7):
        pieces.append(P(f"Bar{i}", (8, 0.4, 0.4), (-5.4 + i * 1.8, 4, 0), (80, 80, 90), "metal", "cylinder", UPRIGHT))
    return model(n, pieces)


def p_block(n, x, z):
    s = rng.uniform(3, 6)
    return deco(n, (s, s, s), x, s / 2, z, (75, 70, 85), "slate", rot=rot_y(rng.uniform(0, 90)))


def p_torch_post(n, x, z):
    return model(n, [
        deco("Post", (0.6, 6, 0.6), x, 3, z, (50, 40, 35), "wood"),
        deco("Flame", (1, 1.4, 1), x, 6.5, z, (255, 140, 40), "neon", collide=False),
    ])


def p_coral(n, x, z):
    pieces = []
    for i in range(4):
        h = rng.uniform(2, 6)
        color = rng.choice([(255, 110, 120), (255, 170, 60), (180, 90, 220), (90, 220, 200)])
        pieces.append(deco(f"Branch{i}", (h, 0.8, 0.8), x + rng.uniform(-2, 2), h / 2, z + rng.uniform(-2, 2), color, "smooth", "cylinder", UPRIGHT))
        pieces.append(deco(f"Tip{i}", (1.4, 1.4, 1.4), x + rng.uniform(-2, 2), h, z + rng.uniform(-2, 2), color, "smooth", "ball"))
    return model(n, pieces)


def p_seaweed(n, x, z):
    h = rng.uniform(6, 12)
    return deco(n, (h, 0.6, 0.6), x, h / 2, z, (40, 150, 80), "grass", "cylinder", mul(UPRIGHT, rot_x(rng.uniform(-10, 10))), collide=False)


def p_cherry(n, x, z):
    P, h = placer(x, z), rng.uniform(9, 13)
    pieces = [P("Trunk", (h, 1.4, 1.4), (0, h / 2, 0), (90, 55, 40), "wood", "cylinder", UPRIGHT)]
    for i in range(4):
        a = math.radians(i * 90 + 45)
        d = rng.uniform(5, 7)
        pieces.append(P(f"Blossom{i}", (d, d, d), (math.cos(a) * 2.5, h + rng.uniform(-1, 1.5), math.sin(a) * 2.5), (255, rng.randint(160, 190), 210), "grass", "ball"))
    return model(n, pieces)


def p_lantern(n, x, z):
    return model(n, [
        deco("Post", (0.5, 5, 0.5), x, 2.5, z, (50, 40, 35), "wood"),
        deco("Lantern", (1.4, 1.8, 1.4), x, 5.6, z, (240, 60, 50), "neon", collide=False),
    ])


def p_torii(n, x, z):
    P = placer(x, z)
    red = (210, 40, 40)
    return model(n, [
        P("PostL", (12, 1.2, 1.2), (-5, 6, 0), red, "smooth", "cylinder", UPRIGHT),
        P("PostR", (12, 1.2, 1.2), (5, 6, 0), red, "smooth", "cylinder", UPRIGHT),
        P("Top", (14, 1, 1.6), (0, 12.3, 0), (30, 30, 30), "smooth"),
        P("Beam", (12, 0.8, 1), (0, 10, 0), red, "smooth"),
    ])


def p_flower(n, x, z):
    color = rng.choice([(255, 90, 120), (255, 220, 70), (250, 250, 250), (180, 120, 255), (255, 150, 60)])
    return model(n, [
        deco("Stem", (1.2, 0.2, 0.2), x, 0.6, z, (60, 140, 60), "grass", "cylinder", UPRIGHT, collide=False),
        deco("Bloom", (0.9, 0.9, 0.9), x, 1.3, z, color, "smooth", "ball", collide=False),
    ])


# --- arena details: ground patches, paths, borders and landmarks -------------------

def jitter(rgb, amount):
    shift = rng.randint(-amount, amount)
    return tuple(max(0, min(255, c + shift)) for c in rgb)


def ground_patches(cx, cz, floor_rgb, material, count=50):
    """Flat discs of slightly different color so the floor isn't one flat color."""
    return [
        deco(f"Patch{i}", (0.1, d, d), x, 0.03, z, jitter(floor_rgb, 18), material, "cylinder", UPRIGHT, collide=False)
        for i, (x, z, d) in enumerate((x, z, rng.uniform(15, 60)) for x, z in scatter(cx, cz, count, 40))
    ]


def paths(cx, cz, rgb, material):
    """A cross of paths through the middle (towns, bases, prisons, Wano)."""
    return [
        deco("PathNS", (24, 0.1, 1000), cx, 0.06, cz, rgb, material, collide=False),
        deco("PathEW", (1000, 0.1, 24), cx, 0.07, cz, rgb, material, collide=False),
    ]


# Each theme's border pieces: (size, color, material, shape) lining the arena edge.
BORDERS = {
    "grass": ((30, 7, 5), (60, 120, 50), "grass", "block"),
    "marine": ((30, 10, 3), (175, 178, 188), "concrete", "block"),
    "town": ((30, 8, 3), (150, 80, 60), "brick", "block"),
    "beach": ((24, 5, 8), (120, 118, 125), "slate", "block"),
    "ship": ((30, 3, 1.5), (110, 75, 45), "wood", "block"),
    "deepsea": ((18, 18, 18), (190, 90, 120), "slate", "ball"),
    "snow": ((26, 12, 6), (180, 215, 245), "ice", "block"),
    "desert": ((28, 14, 10), (205, 165, 105), "slate", "block"),
    "jungle": ((20, 20, 20), (40, 105, 45), "grass", "ball"),
    "sky": ((22, 22, 22), (250, 250, 255), "smooth", "ball"),
    "spooky": ((30, 9, 1), (50, 45, 55), "metal", "block"),
    "mangrove": ((20, 20, 20), (120, 95, 60), "wood", "ball"),
    "prison": ((30, 16, 4), (80, 76, 90), "slate", "block"),
    "volcano": ((26, 16, 12), (40, 34, 38), "slate", "block"),
    "wano": ((30, 6, 2), (180, 40, 40), "wood", "block"),
}


def border(cx, cz, theme):
    """Themed pieces along all four edges, plus invisible walls so nobody walks off the map."""
    size, rgb, material, shape = BORDERS[theme]
    step = size[0] * (0.75 if shape == "ball" else 1)
    rough = theme in ("beach", "desert", "volcano", "snow", "deepsea", "jungle", "sky", "mangrove")
    pieces = []
    for side in range(4):
        t = -500 + step / 2
        while t < 500:
            h = size[1] * (rng.uniform(0.7, 1.3) if rough else 1)
            if side < 2:  # north / south edges run along X
                x, z, yaw = cx + t, cz + (498 if side == 0 else -498), 0
            else:
                x, z, yaw = cx + (498 if side == 2 else -498), cz + t, 90
            if rough:
                yaw += rng.uniform(-15, 15)
            piece_size = (size[0], h, size[2]) if shape == "block" else (h, h, h)
            pieces.append(deco("Edge", piece_size, x, h * (0.3 if shape == "ball" else 0.5), z, jitter(rgb, 10), material, shape, rot_y(yaw)))
            t += step
    for name, size_, pos in (("WallN", (1000, 60, 4), (cx, 30, cz + 502)), ("WallS", (1000, 60, 4), (cx, 30, cz - 502)),
                             ("WallE", (4, 60, 1000), (cx + 502, 30, cz)), ("WallW", (4, 60, 1000), (cx - 502, 30, cz))):
        pieces.append(deco(name, size_, *pos, (255, 255, 255), transparency=1))
    return model("Border", pieces)


# Landmarks: big set pieces, two per arena. All collide but are skipped by spawn raycasts.
def lm_windmill(x, z):
    P = placer(x, z)
    pieces = [
        P("Tower", (22, 9, 9), (0, 11, 0), (235, 225, 205), "smooth", "cylinder", UPRIGHT),
        P("Cap", (6, 10, 10), (0, 24, 0), (150, 60, 45), "slate", "ball"),
        P("Hub", (2, 2, 2), (0, 20, -5), (90, 60, 35), "wood", "ball"),
    ]
    for i in range(4):
        pieces.append(P(f"Blade{i}", (1.2, 14, 0.4), (0, 20, -5.4), (240, 240, 240), "fabric", rot=rot_z(i * 90 + 20)))
    return pieces


def lm_watchtower(x, z):
    P = placer(x, z)
    pieces = [P(f"Leg{i}", (1.2, 20, 1.2), (sx * 4, 10, sz * 4), (90, 90, 95), "metal") for i, (sx, sz) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1)))]
    pieces += [
        P("Deck", (11, 1, 11), (0, 20.5, 0), (120, 90, 60), "planks"),
        P("Roof", (12, 1, 12), (0, 26, 0), (40, 70, 140), "slate"),
        P("Post", (5, 0.6, 0.6), (5, 23.5, 5), (90, 90, 95), "metal"),
        P("Pole", (8, 0.5, 0.5), (0, 30, 0), (170, 170, 175), "metal", "cylinder", UPRIGHT),
        P("Flag", (5, 3, 0.2), (2.6, 32.5, 0), (245, 245, 250), "fabric"),
    ]
    return pieces


def lm_fountain(x, z):
    P = placer(x, z)
    return [
        P("Basin", (2, 20, 20), (0, 1, 0), (190, 190, 200), "concrete", "cylinder", UPRIGHT),
        P("Water", (0.3, 18, 18), (0, 2, 0), (90, 170, 230), "glass", "cylinder", UPRIGHT, transparency=0.3, collide=False),
        P("Pillar", (6, 2, 2), (0, 4, 0), (200, 200, 210), "concrete", "cylinder", UPRIGHT),
        P("Bowl", (1, 7, 7), (0, 7.5, 0), (200, 200, 210), "concrete", "cylinder", UPRIGHT),
        P("Spout", (1.6, 1.6, 1.6), (0, 8.6, 0), (120, 200, 255), "neon", "ball", collide=False),
    ]


def lm_shipwreck(x, z):
    P = placer(x, z)
    return [
        P("Hull", (16, 8, 44), (0, 2, 0), (90, 60, 35), "wood", rot=rot_z(25)),
        P("Deck", (14, 0.5, 40), (1.5, 6, 0), (140, 100, 60), "planks", rot=rot_z(25)),
        P("Mast", (24, 1.4, 1.4), (-2, 14, -4), (110, 75, 45), "wood", "cylinder", mul(UPRIGHT, rot_x(20))),
        P("Sail", (10, 8, 0.3), (-4, 16, -4), (210, 200, 180), "fabric", rot=rot_z(30)),
    ]


def lm_cabin(x, z):
    return [hut("Cabin", x, z, 18, 14, 10, (150, 105, 65), (90, 40, 30), y=0, yaw=rng.uniform(0, 360), query=False),
            deco("Mast", (34, 2, 2), x + 14, 17, z, (110, 75, 45), "wood", "cylinder", UPRIGHT),
            deco("Sail", (16, 14, 0.4), x + 14, 22, z - 1.2, (245, 240, 225), "fabric")]


def lm_dome(x, z):
    P = placer(x, z)
    pieces = [P("Dome", (34, 34, 34), (0, 4, 0), (150, 220, 255), "glass", "ball", transparency=0.55),
              P("Base", (2, 36, 36), (0, 1, 0), (240, 220, 160), "smooth", "cylinder", UPRIGHT)]
    for i in range(6):
        a = math.radians(i * 60)
        pieces.append(P(f"Pillar{i}", (14, 2, 2), (math.cos(a) * 15, 7, math.sin(a) * 15), (250, 240, 210), "smooth", "cylinder", UPRIGHT))
    return pieces


def lm_castle(x, z):
    P = placer(x, z)
    white = (235, 240, 250)
    pieces = [P("Keep", (16, 20, 16), (0, 10, 0), white, "concrete")]
    for i, (sx, sz) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        pieces.append(P(f"Tower{i}", (28, 7, 7), (sx * 11, 14, sz * 11), white, "concrete", "cylinder", UPRIGHT))
        pieces.append(P(f"Roof{i}", (6, 6, 6), (sx * 11, 30, sz * 11), (60, 90, 170), "slate", "ball"))
    return pieces


def lm_pyramid(x, z):
    P = placer(x, z)
    return [P(f"Step{i}", (40 - i * 6, 5, 40 - i * 6), (0, 2.5 + i * 5, 0), (215, 180, 110), "slate") for i in range(6)]


def lm_giant_tree(x, z):
    P = placer(x, z)
    pieces = [P("Trunk", (40, 8, 8), (0, 20, 0), (85, 55, 30), "wood", "cylinder", UPRIGHT)]
    for i in range(5):
        a = math.radians(i * 72)
        pieces.append(P(f"Canopy{i}", (22, 22, 22), (math.cos(a) * 8, 40 + rng.uniform(-3, 3), math.sin(a) * 8), (35, 115, 45), "grass", "ball"))
    return pieces


def lm_bell(x, z):
    P = placer(x, z)
    gold = (235, 200, 80)
    return [
        P("PillarL", (20, 2.5, 2.5), (-7, 10, 0), gold, "metal", "cylinder", UPRIGHT),
        P("PillarR", (20, 2.5, 2.5), (7, 10, 0), gold, "metal", "cylinder", UPRIGHT),
        P("Beam", (17, 2, 2.5), (0, 20.5, 0), gold, "metal"),
        P("Bell", (6, 6, 6), (0, 15, 0), (255, 215, 90), "metal", "ball"),
        P("Rim", (1, 7.5, 7.5), (0, 13, 0), (255, 215, 90), "metal", "cylinder", UPRIGHT),
    ]


def lm_mansion(x, z):
    yaw = rng.uniform(0, 360)
    return [hut("Mansion", x, z, 26, 18, 14, (70, 60, 80), (40, 30, 45), y=0, yaw=yaw, query=False),
            deco("Tower", (30, 8, 8), x + 15, 15, z + 6, (60, 50, 70), "slate", "cylinder", UPRIGHT),
            deco("Spire", (7, 7, 7), x + 15, 31, z + 6, (40, 30, 45), "slate", "ball"),
            deco("Glow", (2, 2, 2), x + 15, 24, z + 1.8, (120, 255, 150), "neon", "ball", collide=False)]


def lm_bubble(x, z):
    return [deco("GiantBubble", (30, 30, 30), x, 22, z, (210, 235, 255), "glass", "ball", transparency=0.6, collide=False),
            p_root("Root", x, z)]


def lm_prison_tower(x, z):
    P = placer(x, z)
    pieces = [P("Tower", (40, 16, 16), (0, 20, 0), (80, 76, 90), "slate", "cylinder", UPRIGHT),
              P("Top", (3, 20, 20), (0, 41.5, 0), (60, 56, 70), "slate", "cylinder", UPRIGHT)]
    for i in range(8):
        a = math.radians(i * 45)
        pieces.append(P(f"Window{i}", (2, 3, 0.4), (math.cos(a) * 8.1, 30, math.sin(a) * 8.1), (255, 150, 60), "neon", rot=rot_y(-i * 45 + 90), collide=False))
    return pieces


def lm_volcano(x, z):
    P = placer(x, z)
    pieces = [P(f"Slope{i}", (6, 60 - i * 10, 60 - i * 10), (0, 3 + i * 6, 0), (50 + i * 6, 40, 42), "slate", "cylinder", UPRIGHT) for i in range(5)]
    pieces.append(P("Lava", (0.6, 12, 12), (0, 30.4, 0), (255, 100, 20), "neon", "cylinder", UPRIGHT, collide=False))
    return pieces


def lm_pagoda(x, z):
    P = placer(x, z)
    pieces = []
    for i in range(4):
        w = 18 - i * 3.5
        y = i * 7
        pieces.append(P(f"Floor{i}", (w - 4, 5, w - 4), (0, y + 2.5, 0), (190, 60, 50), "wood"))
        pieces.append(P(f"Roof{i}", (w + 3, 1.2, w + 3), (0, y + 5.6, 0), (40, 40, 45), "slate"))
    pieces.append(P("Spire", (6, 0.8, 0.8), (0, 31, 0), (230, 190, 70), "metal", "cylinder", UPRIGHT))
    return pieces


LANDMARKS = {
    "grass": lm_windmill, "marine": lm_watchtower, "town": lm_fountain, "beach": lm_shipwreck, "ship": lm_cabin,
    "deepsea": lm_dome, "snow": lm_castle, "desert": lm_pyramid, "jungle": lm_giant_tree, "sky": lm_bell,
    "spooky": lm_mansion, "mangrove": lm_bubble, "prison": lm_prison_tower, "volcano": lm_volcano, "wano": lm_pagoda,
}
PATH_THEMES = {"town": ((200, 185, 160), "cobble"), "marine": ((185, 188, 196), "concrete"),
               "prison": ((90, 85, 100), "slate"), "wano": ((200, 175, 130), "sand")}
FLOWER_THEMES = ("grass", "mangrove", "wano")


def details(cx, cz, theme, floor_rgb, floor_material):
    items = ground_patches(cx, cz, floor_rgb, floor_material)
    if theme in PATH_THEMES:
        items += paths(cx, cz, *PATH_THEMES[theme])
    if theme in FLOWER_THEMES:
        items += [p_flower(f"Flower{i}", x, z) for i, (x, z) in enumerate(scatter(cx, cz, 60, 40))]
    items.append(border(cx, cz, theme))
    for i in range(2):
        a = rng.uniform(0, 2 * math.pi) + i * math.pi
        r = rng.uniform(250, 360)
        items.append(model(f"Landmark{i}", LANDMARKS[theme](cx + math.cos(a) * r, cz + math.sin(a) * r)))
    return items


# theme: floor color, floor material, [(builder, count, keep-clear radius around the arena center)]
THEMES = {
    "grass": ((85, 150, 70), "grass", [(p_palm, 20, 200), (p_rock, 30, 80), (p_bush, 30, 60)]),
    "marine": ((150, 150, 158), "concrete", [(p_wall, 24, 120), (p_cannon, 16, 100), (p_marine_flag, 10, 150), (p_crate, 24, 60)]),
    "town": ((175, 160, 135), "cobble", [(p_house, 22, 160), (p_barrel, 20, 60), (p_crate, 20, 60), (p_lamp, 20, 80)]),
    "beach": ((230, 210, 150), "sand", [(p_palm, 26, 150), (p_umbrella, 12, 100), (p_rock, 24, 80)]),
    "ship": ((150, 105, 65), "planks", [(p_mast, 14, 150), (p_barrel, 26, 60), (p_crate, 26, 60), (p_rail, 20, 100)]),
    "deepsea": ((40, 110, 150), "sand", [(p_coral, 30, 80), (p_seaweed, 40, 60), (p_bubble, 40, 30)]),
    "snow": ((240, 245, 252), "sand", [(p_pine, 30, 150), (p_ice, 20, 120), (p_rock, 16, 80)]),
    "desert": ((226, 196, 135), "sand", [(p_cactus, 30, 80), (p_ruin, 14, 150)]),
    "jungle": ((55, 110, 50), "grass", [(p_big_tree, 26, 180), (p_bush, 40, 60), (p_rock, 16, 80)]),
    "sky": ((232, 240, 255), "smooth", [(p_cloud, 40, 60), (p_gold_ruin, 16, 150)]),
    "spooky": ((60, 50, 65), "slate", [(p_dead_tree, 26, 150), (p_grave, 30, 80), (p_pumpkin, 20, 60), (p_wisp, 30, 40)]),
    "mangrove": ((120, 170, 90), "grass", [(p_root, 12, 200), (p_bubble, 50, 30), (p_bush, 20, 60)]),
    "prison": ((65, 60, 72), "slate", [(p_bars, 20, 150), (p_block, 24, 80), (p_torch_post, 24, 80)]),
    "volcano": ((55, 45, 50), "slate", [(p_lava, 45, 30), (p_magma, 8, 120), (p_spike, 26, 200)]),
    "wano": ((95, 150, 80), "grass", [(p_cherry, 26, 150), (p_lantern, 24, 80), (p_torii, 6, 180)]),
}


def arena(index, key, name, theme):
    cx, cz = map_center(index)
    floor_rgb, floor_material, decorations = THEMES[theme]
    items = [part("Floor", (1000, 2, 1000), (cx, -1, cz), floor_rgb, floor_material)]
    items += details(cx, cz, theme, floor_rgb, floor_material)
    for builder, count, clear in decorations:
        for i, (x, z) in enumerate(scatter(cx, cz, int(count * DENSITY), clear)):
            items.append(builder(f"{builder.__name__[2:].title()}{i}", x, z))
    return model(f"{index + 1:02d} {name}", items)


def arenas():
    return item("Folder", "Arenas", children=[arena(i, *m) for i, m in enumerate(read_maps())])


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
        children=[spawn_island(), arenas()],
    )
    replicated = item("ReplicatedStorage", "ReplicatedStorage", children=[folder("Shared", "src/shared")])
    server = item("ServerScriptService", "ServerScriptService", children=[folder("Server", "src/server")])
    starter = item(
        "StarterPlayer",
        "StarterPlayer",
        # R15 avatars (the attack animations bend R15 joints); Shift is dash, so no Shift-lock
        '<token name="GameSettingsAvatar">1</token><bool name="EnableMouseLockOption">false</bool>',
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
