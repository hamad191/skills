"""Builds AnimeSwarm.rbxlx: the whole game plus the arena and spawn island, ready to open in Roblox Studio.

Usage: python3 tools/build_place.py   (run from the anime-swarm folder)
"""

import html
import math
import os
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "AnimeSwarm.rbxlx")

ISLAND_Z = 1000  # spawn island center: far enough from the arena that enemies never spawn on it
MATERIAL = {"plastic": 256, "smooth": 272, "wood": 512, "planks": 528, "slate": 800, "grass": 1280, "sand": 1296, "fabric": 1312}
SHAPE = {"ball": 0, "block": 1, "cylinder": 2}
IDENTITY = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
UPRIGHT = ((0, -1, 0), (1, 0, 0), (0, 0, 1))  # turns a cylinder's length (X axis) to point up

_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:04d}"


def item(cls, name, props="", children=()):
    body = f'<string name="Name">{html.escape(name)}</string>{props}'
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{body}</Properties>{"".join(children)}</Item>'


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


# --- parts ------------------------------------------------------------------


def rot_y(degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def cframe(pos, rot):
    r = "".join(f"<R{i}{j}>{rot[i][j]:.6g}</R{i}{j}>" for i in range(3) for j in range(3))
    return f'<CoordinateFrame name="CFrame"><X>{pos[0]}</X><Y>{pos[1]}</Y><Z>{pos[2]}</Z>{r}</CoordinateFrame>'


def part(name, size, pos, rgb, material="plastic", shape="block", rot=IDENTITY, cls="Part", extra="", children=(), transparency=0):
    color = 0xFF000000 | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]
    props = (
        '<bool name="Anchored">true</bool><bool name="Locked">true</bool>'
        f'<Vector3 name="size"><X>{size[0]}</X><Y>{size[1]}</Y><Z>{size[2]}</Z></Vector3>'
        f"{cframe(pos, rot)}"
        f'<Color3uint8 name="Color3uint8">{color}</Color3uint8>'
        f'<token name="Material">{MATERIAL[material]}</token>'
        f'<token name="shape">{SHAPE[shape]}</token>'
        f'<float name="Transparency">{transparency}</float>'
        f"{extra}"
    )
    return item(cls, name, props, children)


def sign_text(text):
    label = item(
        "TextLabel",
        "Text",
        '<float name="BackgroundTransparency">1</float>'
        f'<string name="Text">{html.escape(text)}</string>'
        '<bool name="TextScaled">true</bool>'
        '<Color3 name="TextColor3"><R>1</R><G>0.85</G><B>0.2</B></Color3>'
        '<token name="Font">4</token>'
        '<UDim2 name="Size"><XS>1</XS><XO>0</XO><YS>1</YS><YO>0</YO></UDim2>',
    )
    return item("SurfaceGui", "SurfaceGui", '<token name="Face">5</token>', [label])  # Front (-Z) face


# --- spawn island -----------------------------------------------------------


def palm(i, x, z):
    top = 14.5
    leaves = [part("Leaf", (11, 0.4, 2.4), (x, top, z), (60, 150, 60), "grass", rot=rot_y(a)) for a in (0, 45, 90, 135)]
    return item(
        "Model",
        f"PalmTree{i}",
        children=[
            part("Trunk", (14, 1.6, 1.6), (x, 7.5, z), (120, 85, 50), "wood", "cylinder", UPRIGHT),
            *leaves,
            part("Coconut", (1.3, 1.3, 1.3), (x + 0.9, top - 1, z), (90, 60, 30), shape="ball"),
        ],
    )


def ship(x, z):
    wood, dark = (95, 60, 35), (20, 20, 20)
    return item(
        "Model",
        "PirateShip",
        children=[
            part("Hull", (18, 8, 54), (x, 0, z), wood, "wood"),
            part("Bow", (12, 6, 8), (x, 1, z - 31), wood, "wood"),
            part("Deck", (16, 0.5, 50), (x, 4.25, z), (170, 125, 80), "planks"),
            part("Figurehead", (5, 5, 5), (x, 5, z - 36), (255, 210, 60), shape="ball"),
            part("Mast", (34, 1.6, 1.6), (x, 21.5, z), (110, 75, 45), "wood", "cylinder", UPRIGHT),
            part("Sail", (16, 14, 0.4), (x, 20, z - 1), (245, 240, 225), "fabric"),
            part("Emblem", (4, 4, 0.2), (x, 20, z - 1.3), dark),
            part("Skull", (2, 2, 2), (x, 20.5, z - 1.6), (250, 250, 250), shape="ball"),
            part("Flag", (5, 3, 0.2), (x + 2.6, 37, z), dark, "fabric"),
        ],
    )


def spawn_island():
    cz = ISLAND_Z
    sign_z = cz + 35
    palms = []
    for i, a in enumerate((30, 90, 150, 210, 330)):  # leave 270 (the dock side) open
        rad = math.radians(a)
        palms.append(palm(i + 1, round(70 * math.cos(rad), 2), round(cz + 70 * math.sin(rad), 2)))
    return item(
        "Model",
        "SpawnIsland",
        children=[
            part("Sea", (700, 1, 700), (0, -3, cz), (40, 120, 210), "smooth", transparency=0.15),
            part("Beach", (4, 160, 160), (0, -1.5, cz), (230, 210, 150), "sand", "cylinder", UPRIGHT),
            part("Grass", (1, 120, 120), (0, 0.75, cz), (90, 160, 70), "grass", "cylinder", UPRIGHT),
            part(
                "SpawnLocation",
                (12, 1, 12),
                (0, 1.75, cz),
                (200, 40, 40),
                cls="SpawnLocation",
                extra='<bool name="Neutral">true</bool><int name="Duration">0</int>',
            ),
            part("SignPostL", (1, 10, 1), (-9, 6, sign_z), (110, 75, 45), "wood"),
            part("SignPostR", (1, 10, 1), (9, 6, sign_z), (110, 75, 45), "wood"),
            part(
                "SignBoard",
                (20, 7, 0.6),
                (0, 9.5, sign_z),
                (90, 55, 30),
                "planks",
                children=[sign_text("ANIME SWARM\nPick your character, then the ship sets sail!")],
            ),
            part("Dock", (10, 1, 40), (0, 0, cz - 95), (130, 90, 50), "planks"),
            *palms,
            ship(20, cz - 100),
        ],
    )


# --- place ------------------------------------------------------------------


def build():
    workspace = item(
        "Workspace",
        "Workspace",
        children=[
            part("Arena", (1000, 2, 1000), (0, -1, 0), (70, 110, 60), "grass"),
            spawn_island(),
        ],
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
    xml = f'<roblox version="4">{workspace}{replicated}{server}{starter}</roblox>'
    ET.fromstring(xml)  # fail loudly if the XML is malformed
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    build()
