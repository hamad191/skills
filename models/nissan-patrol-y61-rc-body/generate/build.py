#!/usr/bin/env python3
"""Generate the Nissan Patrol Y61 GL RC body shell STL set.

    python3 build.py                      # true 1:18 (165 mm wheelbase)
    python3 build.py --wheelbase 155      # match a specific chassis
    python3 build.py --scale 10           # 1:10 class (313 mm wheelbase, M3 hardware)

Every part is checked (single watertight 2-manifold body) before it is written.
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import time

import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patrol_y61 import color as col  # noqa: E402
from patrol_y61 import geom as g  # noqa: E402
from patrol_y61.model import Model  # noqa: E402
from patrol_y61.params import Params  # noqa: E402
from patrol_y61.render import Scene, contact_sheet  # noqa: E402

DENSITY = 1.25  # g/cm3, PLA / PETG


# ----------------------------------------------------------------------------- orientation
def rot_to_down(down):
    """Rotation matrix taking the car-space vector ``down`` to print -Z."""
    a = np.asarray(down, float)
    a /= np.linalg.norm(a)
    b = np.array([0.0, 0.0, -1.0])
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3) if c > 0 else np.diag([1.0, -1.0, -1.0])
    K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + K + K @ K / (1 + c)


def flat_normal(man, hint):
    """Area-weighted normal of the faces pointing roughly along ``hint``."""
    V, F = g.mesh_arrays(man)
    t = V[F]
    n = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    h = np.asarray(hint, float)
    h /= np.linalg.norm(h)
    area = np.linalg.norm(n, axis=1)
    sel = (n @ h) > 0.94 * area
    if not sel.any():
        return h
    m = n[sel].sum(0)
    return m / np.linalg.norm(m)


def print_oriented(man, down):
    if isinstance(down, tuple) and down and down[0] == "flat":
        down = flat_normal(man, down[1])
    Rm = rot_to_down(down)
    M = np.column_stack([Rm, np.zeros(3)])
    out = man.transform(M.tolist())
    bb = out.bounding_box()
    return out.translate([-(bb[0] + bb[3]) / 2, -(bb[1] + bb[4]) / 2, -bb[2]])


# ----------------------------------------------------------------------------- io / checks
def clean_mesh(man):
    """Weld coincident vertices and drop zero-area triangles.

    Booleans can leave needle triangles whose corners coincide at STL (float32)
    precision. Removing them changes no geometry, and leaves a mesh where every
    edge is shared by exactly two triangles even after a slicer welds it.
    """
    V, F = g.mesh_arrays(man)
    Vr = np.round(V.astype(np.float32).astype(np.float64), 5)
    U, inv = np.unique(Vr, axis=0, return_inverse=True)
    F = inv.reshape(-1)[F]
    F = F[(F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])]
    return U, F


def edge_report(F):
    """(edges not shared by exactly two faces, edges with inconsistent winding)."""
    d = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    und = np.sort(d, axis=1)
    _, idx, cnt = np.unique(und, axis=0, return_inverse=True, return_counts=True)
    sign = np.where(d[:, 0] < d[:, 1], 1, -1)
    bal = np.zeros(len(cnt), int)
    np.add.at(bal, idx.reshape(-1), sign)
    return int(np.sum(cnt != 2)), int(np.sum(bal != 0))


def write_stl(path, man):
    V, F = clean_mesh(man)
    tri = V[F].astype(np.float32)
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    n = (n / np.where(ln == 0, 1, ln)).astype(np.float32)
    rec = np.zeros(len(tri), dtype=[("n", "<f4", 3), ("v", "<f4", (3, 3)), ("a", "<u2")])
    rec["n"], rec["v"] = n, tri
    with open(path, "wb") as f:
        f.write(b"Nissan Patrol Y61 GL RC body - binary STL, units mm".ljust(80, b" "))
        f.write(struct.pack("<I", len(tri)))
        f.write(rec.tobytes())
    return len(tri)


def check(path):
    """Re-read a written STL and verify it the way a slicer would see it."""
    with open(path, "rb") as f:
        f.seek(80)
        n = struct.unpack("<I", f.read(4))[0]
        rec = np.frombuffer(f.read(), dtype=[("n", "<f4", 3), ("v", "<f4", (3, 3)), ("a", "<u2")], count=n)
    P3 = rec["v"].reshape(-1, 3).astype(np.float64)
    U, inv = np.unique(P3, axis=0, return_inverse=True)  # weld exactly as a slicer does
    F = inv.reshape(-1, 3)
    open_edges, flipped = edge_report(F)
    tm = trimesh.Trimesh(U, F, process=False)
    return dict(
        non_manifold_edges=open_edges,
        winding_errors=flipped,
        watertight=bool(open_edges == 0 and flipped == 0),
        bodies=int(tm.body_count),
        positive_volume=bool(tm.volume > 0),
    )


def wall_stats(man, n=150000):
    """Wall thickness sampled by casting rays through the material."""
    V, F = g.mesh_arrays(man)
    tm = trimesh.Trimesh(V, F, process=False)
    pts, fi = trimesh.sample.sample_surface(tm, n, seed=7)
    nn = tm.face_normals[fi]
    inter = trimesh.ray.ray_pyembree.RayMeshIntersector(tm)
    o = pts - nn * 1e-3
    loc, ri, _ = inter.intersects_location(o, -nn, multiple_hits=False)
    d = np.linalg.norm(loc - o[ri], axis=1)
    return dict(median=round(float(np.median(d)), 2), p5=round(float(np.percentile(d, 5)), 2), p1=round(float(np.percentile(d, 1)), 2))


# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--scale", type=float, default=18.0, help="scale denominator; picks defaults for that class (default 18)")
    ap.add_argument("--wheelbase", type=float, help="chassis wheelbase in mm (overrides the scale)")
    ap.add_argument("--tire-od", type=float, help="largest tyre diameter the arches must clear, mm")
    ap.add_argument("--lift", type=float, help="body lift above scale ride height, mm")
    ap.add_argument("--wall", type=float, help="wall thickness, mm")
    ap.add_argument("--width-scale", type=float, help="lateral stretch for wide axles (1.0 = true scale)")
    ap.add_argument("--post-d", type=float, help="body post diameter, mm")
    ap.add_argument("--post-spacing-front", type=float, help="exact front post spacing, mm (default: universal hole pattern)")
    ap.add_argument("--post-spacing-rear", type=float, help="exact rear post spacing, mm")
    ap.add_argument("--frame-notch-width", type=float, help="chassis frame slot in nose/tail panels, mm (0 = none)")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."), help="output folder")
    ap.add_argument("--no-preview", action="store_true")
    a = ap.parse_args()

    P = Params.for_scale(
        a.scale, wheelbase=a.wheelbase, tire_od=a.tire_od, lift=a.lift, wall=a.wall, width_scale=a.width_scale,
        post_d=a.post_d, post_spacing_front=a.post_spacing_front, post_spacing_rear=a.post_spacing_rear,
        frame_notch_width=a.frame_notch_width,
    )
    out = os.path.abspath(a.out)
    t0 = time.time()
    print(f"Nissan Patrol Y61 GL body, scale {P.scale_label}, wheelbase {P.wheelbase:.1f} mm, wall {P.wall} mm")

    kit = Model(P).build()
    fused = Model(P, fused=True).build()
    body = fused.complete_body()
    tol = 0.004
    notes = list(dict.fromkeys(kit.notes + fused.notes))
    folds = {k: v for k, v in kit.B.folds.items() if v and abs(k[0]) <= P.wall + 1e-6}
    if folds:
        notes.append(f"offset surface folds within the wall: {folds}")

    # ---- what gets written: (folder, name, solid, print-down vector, colour, note)
    items = [("", "body_complete", body, (0, 0, -1), "white", "the whole body in one piece (needs a 270 mm bed)")]
    ends = {"front": (-1, 0, 0), "1_front": (-1, 0, 0), "rear": (1, 0, 0), "4_rear": (1, 0, 0)}
    for lab, pc in fused.split(body):
        items.append(("", f"body_complete_{lab}", pc, ends.get(lab, (1, 0, 0)), "white", "body split at the print seam"))
    acc = ("mirror_", "spare_", "glass_", "body_mount_")
    for name, p in kit.parts.items():
        folder = "accessories" if name.startswith(acc) else "multicolor_kit"
        items.append((folder, name, p["solid"], p["down"], p["color"], p["note"]))
    items.append(("multicolor_kit", "body_shell", kit.shell, (0, 0, -1), "white", "bare shell for separately printed trim"))
    for lab, pc in kit.split(kit.shell):
        items.append(("multicolor_kit", f"body_shell_{lab}", pc, ends.get(lab, (1, 0, 0)), "white", "bare shell split at the print seam"))

    manifest = dict(
        model="Nissan Patrol Y61 GL (2007) RC body shell", scale=P.scale_label, wheelbase_mm=round(P.wheelbase, 2),
        params={k: v for k, v in P.__dict__.items()}, parts=[], notes=notes,
    )
    ok_all = True
    for folder, name, solid, down, color, note in items:
        solid, dropped = g.keep_main(solid.simplify(tol))
        po = print_oriented(solid, down)
        d = os.path.join(out, "stl", folder)
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, name + ".stl")
        ntri = write_stl(path, po)
        c = check(path)
        bb = po.bounding_box()
        ok = c["watertight"] and c["bodies"] == 1 and c["positive_volume"] and dropped == 0
        ok_all &= ok
        vol = po.volume() / 1000.0
        manifest["parts"].append(dict(
            file=os.path.join("stl", folder, name + ".stl").replace("\\", "/"), color=color, note=note,
            size_mm=[round(bb[3] - bb[0], 1), round(bb[4] - bb[1], 1), round(bb[5] - bb[2], 1)],
            volume_cm3=round(vol, 2), solid_mass_g=round(vol * DENSITY, 1), triangles=ntri, **c,
        ))
        print(f"  {'OK ' if ok else 'BAD'} {folder + '/' if folder else ''}{name:<28} {bb[3]-bb[0]:6.1f} x {bb[4]-bb[1]:5.1f} x {bb[5]-bb[2]:5.1f} mm"
              f"  {vol:6.2f} cm3  {ntri:6d} tris")

    manifest["wall_thickness_mm"] = dict(nominal=P.wall, body_shell=wall_stats(kit.shell), body_complete=wall_stats(body))
    B = kit.B
    fa, ra = kit.arch(kit.xc_f), kit.arch(kit.xc_r)
    z0, z1 = kit.rail_z
    bbb = body.bounding_box()
    manifest["fitment"] = dict(
        wheelbase_mm=round(P.wheelbase, 1),
        body_length_mm=round(bbb[3] - bbb[0], 1), body_width_over_steps_mm=round(bbb[4] - bbb[1], 1),
        body_width_over_flares_mm=round(2 * (kit.W + P.Ry(45.0)), 1), body_width_sheet_metal_mm=round(2 * kit.W, 1),
        body_height_mm=round(bbb[5] - bbb[2], 1),
        front_overhang_mm=round(-bbb[0], 1), rear_overhang_mm=round(bbb[3] - P.wheelbase, 1),
        inner_width_at_sills_mm=round(2 * (float(B.side_y(P.wheelbase / 2, B.z_sill)) - P.wall), 1),
        max_tire_od_mm=P.tire_od, arch_opening_width_mm=round(2 * fa["a_in"], 1),
        arch_top_above_axle_mm=round(fa["top_in"] - P.z_axle, 1),
        sill_height_above_ground_mm=round(B.z_sill + P.lift, 1), roof_height_above_ground_mm=round(bbb[5] + P.lift, 1),
        recommended_track_outer_mm=round(2 * (kit.W + P.Ry(45.0)), 1),
        post_crossbar_underside_above_ground_mm=round(z0 - max(2.4, 4.0 * P.k) + P.lift, 1),
        crossbar_front_x_range_mm=[round(v, 1) for v in (kit.rail_holes["front"][0][0], kit.rail_holes["front"][-1][0])],
        crossbar_rear_x_range_mm=[round(v, 1) for v in (kit.rail_holes["rear"][0][0], kit.rail_holes["rear"][-1][0])],
        seams_x_mm=[round(s, 1) for s in kit.seams],
    )
    with open(os.path.join(out, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    # ---- coloured model (STL has no colour): GLB / OBJ for viewing, multi-part 3MF for slicers
    painted = col.colored_parts(kit, fused)
    cdir = os.path.join(out, "color")
    os.makedirs(cdir, exist_ok=True)
    col.write_glb(os.path.join(cdir, "patrol_y61_colored.glb"), painted)
    col.write_obj(os.path.join(cdir, "patrol_y61_colored.obj"), painted)
    col.write_3mf(os.path.join(cdir, "patrol_y61_colored.3mf"), painted)
    print(f"  coloured model: {len(painted)} parts, {sum(len(F) for _, _, F, _ in painted)} triangles -> color/")

    if not a.no_preview:
        previews(kit, fused, body, P, os.path.join(out, "preview"), painted)
    for n in notes:
        print("  note:", n)
    print(f"wall thickness (ray-sampled): {manifest['wall_thickness_mm']['body_shell']}  nominal {P.wall}")
    print(f"{'ALL PARTS VALID' if ok_all else 'SOME PARTS FAILED VALIDATION'}  ({time.time() - t0:.0f} s) -> {out}")
    return 0 if ok_all else 1


def previews(kit, fused, body, P, folder, painted):
    os.makedirs(folder, exist_ok=True)
    L = P.wheelbase
    cx, h = L / 2, P.R(1000.0)
    gz = -P.lift  # ground plane in body coordinates

    def cams(size):
        return [
            ((cx - 2.5 * L, -2.1 * L, h + 0.75 * L), (cx, 0, h * 0.85)),
            ((cx, -4.7 * L, h * 1.05), (cx, 0, h * 0.85)),
            ((cx + 2.6 * L, -2.0 * L, h + 0.8 * L), (cx, 0, h * 0.85)),
            ((cx - 2.3 * L, 2.3 * L, h + 1.6 * L), (cx, 0, h * 0.8)),
        ]

    # the painted model, on preview wheels
    def painted_scene(wheels):
        sc = Scene()
        for _, V, F, mats in painted:
            sc.add_mesh(V, F, col.face_colors(mats))
        if wheels:
            for s_, c in kit.preview_wheels():
                sc.add(s_, c)
        return sc.build()

    sc = painted_scene(True)
    size = (1100, 700)
    contact_sheet([sc.render(e, t, fov=24, size=size, ground_z=gz) for e, t in cams(size)], cols=2).save(os.path.join(folder, "assembled.png"))

    # the one-piece body exactly as exported
    sc = Scene().add(body, "white").build()
    views = cams(size)[:3] + [((cx, -0.6 * L, -3.6 * L), (cx, 0, h * 0.9))]
    contact_sheet([sc.render(e, t, fov=24, size=size) for e, t in views], cols=2).save(os.path.join(folder, "body_complete.png"))

    # detail close-ups
    sc = painted_scene(False)
    xr = kit.B.x_rear
    shots = [
        sc.render((kit.B.x_face - 1.5 * L, -0.55 * L, h + 0.45 * L), (kit.B.x_face + 0.15 * L, 0, h * 0.95), fov=24, size=size),
        sc.render((xr + 1.5 * L, -0.6 * L, h + 0.5 * L), (xr - 0.1 * L, 0, h * 1.0), fov=24, size=size),
    ]
    contact_sheet(shots, cols=2).save(os.path.join(folder, "details.png"))

    # inside: seam ribs, mounting rails and crossbars
    sc = Scene().add(kit.shell, "white")
    z0, _ = kit.rail_z
    for which in ("front", "rear"):
        bar = kit.parts[f"body_mount_crossbar_{which}"]["solid"]
        hx = kit.rail_holes[which]
        xm = hx[len(hx) // 2][0]
        sc.add(bar.translate([xm, 0, z0 - max(2.4, 4.0 * P.k)]), "orange")
    sc.build()
    shots = [
        sc.render((cx - 1.2 * L, -1.3 * L, -2.6 * L), (cx, 0, h), fov=30, size=size),
        sc.render((cx + 1.6 * L, -0.9 * L, -2.2 * L), (cx, 0, h), fov=30, size=size),
    ]
    contact_sheet(shots, cols=2).save(os.path.join(folder, "underside_mounting.png"))


if __name__ == "__main__":
    sys.exit(main())
