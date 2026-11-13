"""Coloured exports of the assembled body (GLB, OBJ+MTL, multi-part 3MF).

STL cannot carry colour, so the painted model is written separately. Each
printed part gets its factory colour; on the body shell the details that are
painted rather than separate parts (door handles, window frames and pillars,
glass rubbers) are coloured per triangle.
"""

from __future__ import annotations

import json
import os
import struct
import zipfile

import numpy as np
from shapely.ops import unary_union

from . import geom as g

# name: (sRGB colour, alpha, metallic, roughness)
MATERIALS = {
    "body_white": ((0.94, 0.94, 0.92), 1.0, 0.0, 0.45),
    "trim_black": ((0.075, 0.075, 0.08), 1.0, 0.0, 0.75),
    "chrome": ((0.80, 0.82, 0.84), 1.0, 0.9, 0.25),
    "grille_black": ((0.04, 0.04, 0.045), 1.0, 0.0, 0.8),
    "lens_clear": ((0.76, 0.83, 0.89), 1.0, 0.3, 0.15),
    "lens_red": ((0.74, 0.05, 0.07), 1.0, 0.1, 0.25),
    "glass": ((0.13, 0.17, 0.20), 0.62, 0.0, 0.1),
    "tire_black": ((0.05, 0.05, 0.055), 1.0, 0.0, 0.9),
    "wheel_silver": ((0.72, 0.74, 0.77), 1.0, 0.6, 0.4),
}
PART_MATERIAL = [  # first matching prefix wins
    ("glass_", "glass"), ("grille", "grille_black"), ("headlight_", "lens_clear"), ("taillight_", "lens_red"),
    ("tailgate_garnish", "chrome"), ("spare_tire", "tire_black"), ("spare_wheel", "wheel_silver"),
    ("flare_", "trim_black"), ("bumper_", "trim_black"), ("side_step_", "trim_black"), ("mirror_", "trim_black"),
    ("spare_carrier", "trim_black"),
]


def _mat_for(name):
    for prefix, mat in PART_MATERIAL:
        if name.startswith(prefix):
            return mat
    return "body_white"


def _mesh(solid):
    solid = solid.simplify(0.004)
    V, F = g.mesh_arrays(solid)
    return V, F


def _split_shell(model):
    """Cut the shell into its white body and the black-painted details.

    The cut follows real boundaries - the glass rubbers, the band of door
    frames and pillars along the side glass, the door-handle scoops - so the
    colour edges are exact and the black trim is a printable volume of its own.
    """
    P, B, k = model.P, model.B, model.k
    R = P.R
    band = 1.3 * k + P.groove_w / 2

    def ring(shape):
        return shape.buffer(band, quad_segs=6).difference(shape.buffer(-0.5))

    frames = unary_union(list(model.window_shapes().values())).buffer(band, quad_segs=6).convex_hull
    scoops = unary_union([g.rrect(R(x0), R(1126.0), R(x0 + 205.0), R(1176.0), R(14.0)) for x0 in (1445.0, 2455.0)])
    prisms = [model.across(frames), model.across(scoops), model.ws_prism(ring(model.windscreen_shape()))]
    rw, _ = model.rear_window_shapes()
    prisms += [model._rw_prism(ring(shp)) for shp in rw.values()]
    cutter = g.union(prisms)
    return model.shell - cutter, model.shell ^ cutter


def _paint_grille(model, V, F):
    """Chrome surround / bars / badge, black mesh and backing."""
    B, k = model.B, model.k
    c = V[F].mean(1)
    depth = c[:, 0] - B.face_x(c[:, 1], c[:, 2])  # negative = proud of the nose panel
    return np.where(depth < -0.3 * k, "chrome", "grille_black").astype(object)


def _paint_taillight(model, V, F):
    R = model.P.R
    z = V[F].mean(1)[:, 2]
    return np.where((z > R(985.0)) & (z < R(1105.0)), "lens_clear", "lens_red").astype(object)


def colored_parts(kit, fused):
    """[(name, V, F, per-face material names)] for the assembled, painted body."""
    out = []
    white, black = _split_shell(fused)
    for name, solid, mat in (("body_shell", white, "body_white"), ("body_black_trim", black, "trim_black")):
        V, F = _mesh(solid)
        out.append((name, V, F, np.full(len(F), mat, dtype=object)))
    for name, p in fused.parts.items():
        if not name.startswith(fused.FUSE):
            continue
        V, F = _mesh(p["solid"])
        if name == "grille":
            m = _paint_grille(fused, V, F)
        elif name.startswith("taillight_"):
            m = _paint_taillight(fused, V, F)
        else:
            m = np.full(len(F), _mat_for(name), dtype=object)
        out.append((name, V, F, m))
    for name, p in kit.parts.items():
        if name.startswith(("mirror_", "spare_", "glass_")):
            V, F = _mesh(p["solid"])
            out.append((name, V, F, np.full(len(F), _mat_for(name), dtype=object)))
    return out


def _srgb_to_linear(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


# ----------------------------------------------------------------------------- OBJ
def write_obj(path, parts):
    base = os.path.splitext(os.path.basename(path))[0]
    with open(os.path.splitext(path)[0] + ".mtl", "w") as f:
        for name, (rgb, a, metal, rough) in MATERIALS.items():
            f.write(f"newmtl {name}\nKd {rgb[0]:.4f} {rgb[1]:.4f} {rgb[2]:.4f}\nKa 0 0 0\n")
            f.write(f"Ks {0.6 if metal > 0.5 else 0.15:.2f} {0.6 if metal > 0.5 else 0.15:.2f} {0.6 if metal > 0.5 else 0.15:.2f}\n")
            f.write(f"Ns {int(400 * (1 - rough)) + 10}\nd {a:.2f}\nillum 2\n\n")
    with open(path, "w") as f:
        f.write(f"# Nissan Patrol Y61 GL RC body, coloured. Units mm, Z up, X rearward.\nmtllib {base}.mtl\n")
        off = 1
        for name, V, F, mats in parts:
            f.write(f"o {name}\n")
            f.write("".join(f"v {a:.4f} {b:.4f} {c:.4f}\n" for a, b, c in V))
            for m in sorted(set(mats)):
                f.write(f"usemtl {m}\n")
                f.write("".join(f"f {a} {b} {c}\n" for a, b, c in F[mats == m] + off))
            off += len(V)


# ----------------------------------------------------------------------------- GLB
def write_glb(path, parts):
    """Binary glTF 2.0: one primitive per material, metres, Y up."""
    names = list(MATERIALS)
    chunks, views, accessors, prims = [], [], [], []
    offset = 0

    def push(data, target):
        nonlocal offset
        pad = (-len(data)) % 4
        chunks.append(data + b"\x00" * pad)
        views.append(dict(buffer=0, byteOffset=offset, byteLength=len(data), target=target))
        offset += len(data) + pad
        return len(views) - 1

    for mi, mname in enumerate(names):
        vs, fs, n = [], [], 0
        for _, V, F, mats in parts:
            sel = F[mats == mname]
            if len(sel) == 0:
                continue
            used, inv = np.unique(sel, return_inverse=True)
            vs.append(V[used])
            fs.append(inv.reshape(-1, 3) + n)
            n += len(used)
        if not vs:
            continue
        Vm = np.concatenate(vs).astype(np.float32)
        Fm = np.concatenate(fs).astype(np.uint32)
        pv = push(Vm.tobytes(), 34962)
        accessors.append(dict(bufferView=pv, componentType=5126, count=len(Vm), type="VEC3",
                              min=Vm.min(0).tolist(), max=Vm.max(0).tolist()))
        iv = push(Fm.tobytes(), 34963)
        accessors.append(dict(bufferView=iv, componentType=5125, count=int(Fm.size), type="SCALAR"))
        prims.append(dict(attributes=dict(POSITION=len(accessors) - 2), indices=len(accessors) - 1, material=mi, mode=4))

    materials = []
    for mname in names:
        rgb, a, metal, rough = MATERIALS[mname]
        m = dict(name=mname, doubleSided=True,
                 pbrMetallicRoughness=dict(baseColorFactor=[*_srgb_to_linear(rgb).round(5).tolist(), a], metallicFactor=metal, roughnessFactor=rough))
        if a < 1.0:
            m["alphaMode"] = "BLEND"
        materials.append(m)
    q = 0.7071068
    doc = dict(
        asset=dict(version="2.0", generator="patrol_y61"),
        scene=0, scenes=[dict(nodes=[0])],
        # car frame (mm, Z up) -> glTF (m, Y up)
        nodes=[dict(name="Nissan Patrol Y61 GL body", mesh=0, rotation=[-q, 0.0, 0.0, q], scale=[0.001, 0.001, 0.001])],
        meshes=[dict(name="body", primitives=prims)], materials=materials,
        buffers=[dict(byteLength=offset)], bufferViews=views, accessors=accessors,
    )
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    binary = b"".join(chunks)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(binary)))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(binary), b"BIN\x00") + binary)


# ----------------------------------------------------------------------------- 3MF
def write_3mf(path, parts):
    """Multi-part 3MF: every printed part is its own volume with its colour.

    Slicers load it as one object made of parts, so a filament can be assigned
    to each. Painted details on the shell are stored as per-triangle colours.
    """
    names = list(MATERIALS)
    idx = {n: i for i, n in enumerate(names)}

    def hexc(n):
        rgb, a, _, _ = MATERIALS[n]
        return "#" + "".join(f"{int(round(v * 255)):02X}" for v in (*rgb, a))

    x = ['<?xml version="1.0" encoding="UTF-8"?>\n',
         '<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">\n',
         ' <metadata name="Title">Nissan Patrol Y61 GL RC body</metadata>\n <resources>\n  <basematerials id="1">\n']
    x += [f'   <base name="{n}" displaycolor="{hexc(n)}"/>\n' for n in names]
    x.append("  </basematerials>\n")
    for i, (name, V, F, mats) in enumerate(parts):
        vals, counts = np.unique(mats, return_counts=True)
        main = vals[np.argmax(counts)]
        x.append(f'  <object id="{i + 2}" name="{name}" type="model" pid="1" pindex="{idx[main]}">\n   <mesh>\n    <vertices>\n')
        x.append("".join(f'     <vertex x="{a:.4f}" y="{b:.4f}" z="{c:.4f}"/>\n' for a, b, c in V))
        x.append("    </vertices>\n    <triangles>\n")
        pi = np.array([idx[m] for m in mats])
        x.append("".join(
            (f'     <triangle v1="{a}" v2="{b}" v3="{c}"/>\n' if p == idx[main] else f'     <triangle v1="{a}" v2="{b}" v3="{c}" pid="1" p1="{p}"/>\n')
            for (a, b, c), p in zip(F, pi)))
        x.append("    </triangles>\n   </mesh>\n  </object>\n")
    top = len(parts) + 2
    x.append(f'  <object id="{top}" name="patrol_y61_body" type="model">\n   <components>\n')
    x += [f'    <component objectid="{i + 2}"/>\n' for i in range(len(parts))]
    x.append(f'   </components>\n  </object>\n </resources>\n <build>\n  <item objectid="{top}"/>\n </build>\n</model>\n')
    types = ('<?xml version="1.0" encoding="UTF-8"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
             '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
             '<Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>')
    rels = ('<?xml version="1.0" encoding="UTF-8"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>')
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        zf.writestr("[Content_Types].xml", types)
        zf.writestr("_rels/.rels", rels)
        zf.writestr("3D/3dmodel.model", "".join(x))


def face_colors(mats):
    """Per-face 0-255 RGB for the preview renderer."""
    lut = {n: np.array(MATERIALS[n][0]) * 255 for n in MATERIALS}
    return np.array([lut[m] for m in mats])
