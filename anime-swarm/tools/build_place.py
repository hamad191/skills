"""Builds AnimeSwarm.rbxlx: the whole game plus a baseplate and spawn, ready to open in Roblox Studio.

Usage: python3 tools/build_place.py   (run from the anime-swarm folder)
"""

import os
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "AnimeSwarm.rbxlx")

_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:04d}"


def item(cls, name, props="", children=()):
    body = f'<string name="Name">{name}</string>{props}'
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{body}</Properties>{"".join(children)}</Item>'


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


def cframe(x, y, z):
    rot = "".join(f"<R{i}{j}>{1 if i == j else 0}</R{i}{j}>" for i in range(3) for j in range(3))
    return f'<CoordinateFrame name="CFrame"><X>{x}</X><Y>{y}</Y><Z>{z}</Z>{rot}</CoordinateFrame>'


def part_props(size, pos, rgb, material=256):
    color = 0xFF000000 | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]
    return (
        '<bool name="Anchored">true</bool><bool name="Locked">true</bool>'
        f'<Vector3 name="size"><X>{size[0]}</X><Y>{size[1]}</Y><Z>{size[2]}</Z></Vector3>'
        f"{cframe(*pos)}"
        f'<Color3uint8 name="Color3uint8">{color}</Color3uint8>'
        f'<token name="Material">{material}</token>'
    )


def build():
    workspace = item(
        "Workspace",
        "Workspace",
        children=[
            item("Part", "Baseplate", part_props((1000, 2, 1000), (0, -1, 0), (70, 90, 70), material=512)),
            item(
                "SpawnLocation",
                "SpawnLocation",
                part_props((12, 1, 12), (0, 0.5, 0), (90, 60, 160)) + '<bool name="Neutral">true</bool>'
                '<int name="Duration">3</int>',
            ),
        ],
    )
    replicated = item("ReplicatedStorage", "ReplicatedStorage", children=[folder("Shared", "src/shared")])
    server = item("ServerScriptService", "ServerScriptService", children=[folder("Server", "src/server")])
    starter = item(
        "StarterPlayer",
        "StarterPlayer",
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
