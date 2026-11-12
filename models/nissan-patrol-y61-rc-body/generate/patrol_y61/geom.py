"""Geometry helpers: lofts, miter offsets, extrusions and 2D utilities.

Everything here works in model millimetres. Solids are manifold3d ``Manifold``
objects, which guarantees that every boolean result is watertight and
2-manifold.
"""

from __future__ import annotations

import numpy as np
import manifold3d as m3
from manifold3d import CrossSection, Manifold, Mesh
import shapely.geometry as sg
from shapely.geometry.polygon import orient

m3.set_min_circular_angle(6.0)
m3.set_min_circular_edge_length(0.25)


# ----------------------------------------------------------------------------
# mesh <-> manifold
# ----------------------------------------------------------------------------
def to_manifold(V: np.ndarray, F: np.ndarray) -> Manifold:
    mesh = Mesh(
        vert_properties=np.ascontiguousarray(V, dtype=np.float32),
        tri_verts=np.ascontiguousarray(F, dtype=np.uint32),
    )
    man = Manifold(mesh)
    if man.status() != m3.Error.NoError:
        raise RuntimeError(f"invalid mesh: {man.status()}")
    if man.volume() < 0:
        raise RuntimeError("mesh is inside-out")
    return man


def mesh_arrays(man: Manifold) -> tuple[np.ndarray, np.ndarray]:
    mesh = man.to_mesh()
    V = np.asarray(mesh.vert_properties, dtype=np.float64)[:, :3]
    F = np.asarray(mesh.tri_verts, dtype=np.int64)
    return V, F


# ----------------------------------------------------------------------------
# lofting
# ----------------------------------------------------------------------------
def _cap(ring2d: np.ndarray) -> np.ndarray:
    """Triangulate a simple polygon given CCW; returns (n,3) indices."""
    tris = np.asarray(m3.triangulate([np.asarray(ring2d, dtype=np.float64)]), dtype=np.int64)
    return tris


def loft(rings: np.ndarray, plane: tuple[int, int], caps: str = "fan", caps2d=None) -> tuple[np.ndarray, np.ndarray]:
    """Loft a stack of closed rings.

    rings: (S, N, 3). Every ring must be counter-clockwise in the 2D frame
    ``plane`` = (i, j), where axis_i x axis_j is the loft direction. The first
    and last rings are capped, either with a fan to a centre vertex ("fan",
    for convex rings - keeps every rim vertex on a real cap triangle so the
    solid can be offset) or by ear clipping ("earclip", any simple ring).
    ``caps2d`` optionally gives the 2D coordinates used for ear clipping.
    """
    S, N, _ = rings.shape
    V = rings.reshape(-1, 3)
    idx = np.arange(S * N).reshape(S, N)
    a = idx[:-1]
    b = np.roll(idx[:-1], -1, axis=1)
    c = idx[1:]
    d = np.roll(idx[1:], -1, axis=1)
    F = [np.stack([a, b, d], -1).reshape(-1, 3), np.stack([a, d, c], -1).reshape(-1, 3)]
    if caps == "fan":
        c0, c1 = S * N, S * N + 1
        V = np.concatenate([V, rings[0].mean(0)[None], rings[-1].mean(0)[None]])
        r0, r1 = idx[0], idx[-1]
        F.append(np.stack([np.roll(r0, -1), r0, np.full(N, c0)], -1))
        F.append(np.stack([r1, np.roll(r1, -1), np.full(N, c1)], -1))
    else:
        i, j = plane
        p0 = rings[0][:, [i, j]] if caps2d is None else caps2d[0]
        p1 = rings[-1][:, [i, j]] if caps2d is None else caps2d[1]
        F.append(_cap(p0)[:, ::-1] + idx[0, 0])
        F.append(_cap(p1) + idx[-1, 0])
    return V, np.concatenate(F)


def offset_mesh(V: np.ndarray, F: np.ndarray, delta: float, mu: float = 0.05) -> np.ndarray:
    """Offset every vertex so adjacent faces move by ``delta`` along their normals.

    This is a miter offset (crease vertices move further than ``delta`` so
    the wall thickness measured normal to each face stays constant). delta > 0
    grows the solid, delta < 0 shrinks it.
    """
    tri = V[F]
    fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    a2 = np.linalg.norm(fn, axis=1)
    ok = a2 > 1e-12
    n = np.zeros_like(fn)
    n[ok] = fn[ok] / a2[ok, None]
    nv = len(V)
    A = np.zeros((nv, 3, 3))
    b = np.zeros((nv, 3))
    wsum = np.zeros(nv)
    for k in range(3):
        p = tri[:, k]
        e1 = tri[:, (k + 1) % 3] - p
        e2 = tri[:, (k + 2) % 3] - p
        l1 = np.linalg.norm(e1, axis=1)
        l2 = np.linalg.norm(e2, axis=1)
        cosang = np.einsum("ij,ij->i", e1, e2) / np.maximum(l1 * l2, 1e-30)
        w = np.arccos(np.clip(cosang, -1, 1)) * ok
        np.add.at(A, F[:, k], w[:, None, None] * n[:, :, None] * n[:, None, :])
        np.add.at(b, F[:, k], w[:, None] * n)
        np.add.at(wsum, F[:, k], w)
    wsum = np.maximum(wsum, 1e-12)
    nlen = np.linalg.norm(b, axis=1)
    nbar = b / np.maximum(nlen, 1e-12)[:, None]
    c = np.clip(wsum / np.maximum(nlen, 1e-12), 1.0, 3.0)
    d0 = nbar * c[:, None]
    lam = mu * wsum
    M = A + lam[:, None, None] * np.eye(3)[None]
    rhs = b + lam[:, None] * d0
    d = np.linalg.solve(M, rhs[:, :, None])[:, :, 0]
    dl = np.linalg.norm(d, axis=1)
    over = dl > 3.0
    d[over] *= (3.0 / dl[over])[:, None]
    return V + delta * _untangle(V, F, d, delta)


def flipped_faces(V0, V1, F):
    """Indices of faces whose orientation reverses between two vertex sets."""
    t0, t1 = V0[F], V1[F]
    n0 = np.cross(t0[:, 1] - t0[:, 0], t0[:, 2] - t0[:, 0])
    n1 = np.cross(t1[:, 1] - t1[:, 0], t1[:, 2] - t1[:, 0])
    big = np.linalg.norm(n0, axis=1) > 1e-7
    return np.nonzero((np.einsum("ij,ij->i", n0, n1) < 0) & big)[0]


def _untangle(V, F, d, delta, iters=200):
    """Relax the displacement field wherever the offset surface folds.

    Tight doubly-curved corners can shrink facets to nothing under an inward
    offset. Averaging the displacement of the affected vertices with their
    neighbours makes the patch move as one piece, which removes the fold at
    the cost of a slightly uneven wall in that small spot.
    """
    if delta >= 0:
        return d
    d = d.copy()
    E = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    nv = len(V)
    deg = np.bincount(E[:, 0], minlength=nv).astype(float)
    for _ in range(iters):
        bad = flipped_faces(V, V + delta * d, F)
        if len(bad) == 0:
            break
        mask = np.zeros(nv, bool)
        mask[F[bad].ravel()] = True
        mask[E[mask[E[:, 0]], 1]] = True  # one ring around the fold
        acc = np.zeros_like(d)
        np.add.at(acc, E[:, 0], d[E[:, 1]])
        avg = acc / np.maximum(deg, 1)[:, None]
        d[mask] = 0.5 * d[mask] + 0.5 * avg[mask]
    return d


# ----------------------------------------------------------------------------
# 2D helpers
# ----------------------------------------------------------------------------
def fillet(C, d_in, d_out, r, n):
    """Arc points rounding the corner C of a CCW polygon (left turn)."""
    C = np.asarray(C, float)
    d_in = np.asarray(d_in, float) / np.linalg.norm(d_in)
    d_out = np.asarray(d_out, float) / np.linalg.norm(d_out)
    phi = np.arctan2(d_in[0] * d_out[1] - d_in[1] * d_out[0], np.dot(d_in, d_out))
    tl = r * np.tan(phi / 2)
    T1 = C - d_in * tl
    O = T1 + np.array([-d_in[1], d_in[0]]) * r
    a1 = np.arctan2(T1[1] - O[1], T1[0] - O[0])
    ang = a1 + np.linspace(0, phi, n)
    pts = O[None] + r * np.stack([np.cos(ang), np.sin(ang)], -1)
    return pts, tl


def cs(geom) -> CrossSection:
    """shapely (Multi)Polygon -> manifold CrossSection."""
    if geom.is_empty:
        return CrossSection()
    geoms = list(geom.geoms) if hasattr(geom, "geoms") else [geom]
    contours = []
    for g in geoms:
        if g.geom_type != "Polygon" or g.is_empty:
            continue
        g = orient(g, 1.0)
        contours.append(np.asarray(g.exterior.coords)[:-1])
        for h in g.interiors:
            contours.append(np.asarray(h.coords)[:-1])
    return CrossSection(contours, m3.FillRule.Positive)


def to_shapely(c: CrossSection):
    polys = [np.asarray(p) for p in c.to_polygons()]
    if not polys:
        return sg.Polygon()
    shells = [p for p in polys if _area(p) > 0]
    holes = [p for p in polys if _area(p) <= 0]
    out = []
    for s in shells:
        sp = sg.Polygon(s)
        hs = [h for h in holes if sp.contains(sg.Point(h[0]))]
        out.append(sg.Polygon(s, hs))
    return sg.MultiPolygon(out) if len(out) != 1 else out[0]


def _area(p):
    x, y = p[:, 0], p[:, 1]
    return 0.5 * float(np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y))


def rrect(x0, y0, x1, y1, r, res=10):
    """Rounded rectangle."""
    r = min(r, (x1 - x0) / 2 - 1e-3, (y1 - y0) / 2 - 1e-3)
    if r <= 1e-6:
        return sg.box(x0, y0, x1, y1)
    return sg.box(x0 + r, y0 + r, x1 - r, y1 - r).buffer(r, quad_segs=res)


def rpoly(points, r, res=10):
    """Polygon with all (convex and concave) corners rounded by radius r."""
    p = sg.Polygon(points)
    if r <= 1e-6:
        return p
    return p.buffer(-r, quad_segs=res).buffer(2 * r, quad_segs=res).buffer(-r, quad_segs=res)


def stroke(points, width, closed=False):
    """A polyline thickened to ``width`` (used for engraved panel lines)."""
    pts = list(points)
    line = sg.LinearRing(pts) if closed else sg.LineString(pts)
    return line.buffer(width / 2, cap_style="flat", join_style="mitre", mitre_limit=3.0)


# ----------------------------------------------------------------------------
# extrusions along the car axes (X rearward, Y right, Z up)
# ----------------------------------------------------------------------------
_PERM_YZ_TO_X = [[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0]]  # (y, z, x') -> car
_PERM_CAR_TO_YZX = [[0, 1, 0, 0], [0, 0, 1, 0], [1, 0, 0, 0]]  # car -> (y, z, x)


def _as_cs(shape) -> CrossSection:
    return shape if isinstance(shape, CrossSection) else cs(shape)


def extrude_z(shape_xy, z0, z1) -> Manifold:
    return Manifold.extrude(_as_cs(shape_xy), z1 - z0).translate([0, 0, z0])


def extrude_x(shape_yz, x0, x1) -> Manifold:
    return Manifold.extrude(_as_cs(shape_yz), x1 - x0).transform(_PERM_YZ_TO_X).translate([x0, 0, 0])


def extrude_y(shape_xz, y0, y1) -> Manifold:
    # extrude along +z', then rotate so z' -> -Y and y' -> Z
    return Manifold.extrude(_as_cs(shape_xz), y1 - y0).rotate([90, 0, 0]).translate([0, y1, 0])


def slice_x(man: Manifold, x: float) -> CrossSection:
    """Cross-section of a solid at car X = x, returned in (y, z)."""
    return man.transform(_PERM_CAR_TO_YZX).slice(x)


def cyl(p0, p1, r, segs=0) -> Manifold:
    """Cylinder between two points."""
    p0 = np.asarray(p0, float)
    p1 = np.asarray(p1, float)
    v = p1 - p0
    L = float(np.linalg.norm(v))
    c = Manifold.cylinder(L, r, r, segs)
    z = v / L
    ref = np.array([1.0, 0, 0]) if abs(z[0]) < 0.9 else np.array([0, 1.0, 0])
    x = np.cross(ref, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    M = np.column_stack([x, y, z, p0])
    return c.transform(M.tolist())


def box(x0, y0, z0, x1, y1, z1) -> Manifold:
    return Manifold.cube([x1 - x0, y1 - y0, z1 - z0]).translate([x0, y0, z0])


def union(parts) -> Manifold:
    parts = [p for p in parts if p is not None and not p.is_empty()]
    if not parts:
        return Manifold()
    if len(parts) == 1:
        return parts[0]
    return Manifold.batch_boolean(parts, m3.OpType.Add)


def keep_main(man: Manifold, min_vol: float = 0.2):
    """Keep the main body of a boolean result.

    Returns (solid, n) where n counts discarded pieces larger than ``min_vol``
    mm3 - loose fragments (positive volume) or sealed voids (negative). Dust
    below that size is an artefact of coincident faces and is dropped silently.
    """
    comps = man.decompose()
    if len(comps) <= 1:
        return man, 0
    comps.sort(key=lambda c: -c.volume())
    return comps[0], sum(1 for c in comps[1:] if abs(c.volume()) > min_vol)


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def corner_normals(V, F, crease_deg=38.0):
    """Per-corner shading normals: smooth across faces closer than ``crease_deg``, sharp otherwise.

    Returns (nf, 3, 3). Used for viewing only - the geometry is unchanged.
    """
    t = V[F]
    fn = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    area = np.linalg.norm(fn, axis=1)
    unit = fn / np.maximum(area, 1e-20)[:, None]
    nf = len(F)
    cv = F.reshape(-1)  # vertex of each corner
    cf = np.repeat(np.arange(nf), 3)  # face of each corner
    order = np.argsort(cv, kind="stable")
    sv, sf = cv[order], cf[order]
    start = np.concatenate([[0], np.nonzero(np.diff(sv))[0] + 1])
    size = np.diff(np.concatenate([start, [len(sv)]]))
    gstart = np.repeat(start, size)  # group start for every sorted corner
    gsize = np.repeat(size, size)
    i = np.repeat(np.arange(len(sv)), gsize)
    j = np.repeat(gstart, gsize) + (np.arange(len(i)) - np.repeat(np.cumsum(gsize) - gsize, gsize))
    fi, fj = sf[i], sf[j]
    ok = np.einsum("ij,ij->i", unit[fi], unit[fj]) > np.cos(np.radians(crease_deg))
    acc = np.zeros((len(sv), 3))
    np.add.at(acc, i[ok], fn[fj[ok]])
    acc /= np.maximum(np.linalg.norm(acc, axis=1), 1e-20)[:, None]
    out = np.zeros((nf * 3, 3))
    out[order] = acc
    return out.reshape(nf, 3, 3)
