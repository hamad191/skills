"""Turns the body skin into printable parts.

Two flavours are built from the same geometry:

* the *kit* - bare shell plus separate bumpers, flares, steps, lamps, grille
  (clearances between parts, screw holes, pockets), for multi-colour printing;
* the *complete body* (``fused=True``) - the same parts with zero clearance,
  fused into the shell so the whole body prints as one piece.
"""

from __future__ import annotations

import numpy as np
import shapely.geometry as sg
from shapely import affinity
from shapely.ops import unary_union
import manifold3d as m3
from manifold3d import Manifold

from . import geom as g
from .body import Body
from .params import Params, REAL_TIRE_OD, REAL_TIRE_WIDTH

BIG = 400.0
OV = 0.06  # overlap used instead of clearance when parts are fused


def resample(poly: np.ndarray, n: int) -> np.ndarray:
    seg = np.linalg.norm(np.diff(poly, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    u = np.linspace(0, s[-1], n)
    return np.stack([np.interp(u, s, poly[:, 0]), np.interp(u, s, poly[:, 1])], -1)


def outline(shape, grow, width):
    """Closed line following ``shape`` at distance ``grow``, thickened to ``width``."""
    polys = list(shape.geoms) if hasattr(shape, "geoms") else [shape]
    return unary_union([p.buffer(grow, quad_segs=6).exterior.buffer(width / 2) for p in polys])


class Model:
    def __init__(self, P: Params, fused: bool = False):
        self.P = P
        self.B = Body(P)
        self.fused = fused
        self.k = P.k
        self.fit = 0.0 if fused else P.fit
        self.parts: dict[str, dict] = {}
        self.notes: list[str] = []
        B, R = self.B, P.R
        self.W = float(B.w_plan(R(1500.0)))  # max body half-width
        self.xc_f, self.xc_r = 0.0, P.wheelbase
        length = B.x_rear - B.x_face
        # print seams: bonnet rear edge, B pillar, C pillar (small bodies only need the B pillar)
        self.seams = [R(465.0), R(1724.0), R(2690.0)] if length > 320.0 else [R(1724.0)]
        self._arch = {}
        self._ws_setup()

    # ------------------------------------------------------------------ utils
    def add(self, name, solid, color, qty=1, note="", down=(0, 0, -1)):
        solid, dropped = g.keep_main(solid)
        self.parts[name] = dict(solid=solid, color=color, qty=qty, note=note, dropped=dropped, down=down)
        return solid

    def pts(self, real_xz):
        a = np.asarray(real_xz, float)
        return np.stack([self.P.R(a[:, 0]), self.P.R(a[:, 1])], -1)

    def gh_pts(self, real_xz, step=40.0):
        """Full-size greenhouse side-view points (design roof) -> model, following the roofline."""
        a = np.asarray(real_xz, float)
        out = []
        n = len(a)
        for i in range(n):
            p, q = a[i], a[(i + 1) % n]
            kk = max(1, int(np.ceil(np.linalg.norm(q - p) / step)))
            for j in range(kk):
                out.append(p + (q - p) * j / kk)
        a = np.array(out)
        x = self.P.R(a[:, 0])
        z = self.B.gz(self.P.R(a[:, 1]), x)
        return np.stack([x, z], -1)

    def across(self, shape_xz, side=0):
        """Prism through the body along Y. side: 0 both flanks, +1 right, -1 left."""
        y0, y1 = (-BIG, BIG) if side == 0 else ((0.0, BIG) if side > 0 else (-BIG, 0.0))
        return g.extrude_y(shape_xz, y0, y1)

    def skin_cut(self, prism: Manifold, depth: float) -> Manifold:
        """The part of ``prism`` lying in the outer ``depth`` mm of the body skin."""
        return prism - self.B.core(depth)

    def hug(self) -> Manifold:
        """What an add-on part is trimmed against so it seats on the body."""
        return self.B.core(OV) if self.fused else self.B.grown(0.1)

    def inset(self, shape):
        """Insert outline: a hair small for the kit, a hair big when fused."""
        return shape.buffer(OV / 2 if self.fused else -0.02, quad_segs=6)

    # ------------------------------------------------------------------ windscreen frame
    def _ws_setup(self):
        """Local frame of the windscreen so its opening is cut square to the glass."""
        B, R = self.B, self.P.R

        def cl(zp):
            x = float(B.ws_x(zp))
            return np.array([x, 0.0, float(B.gz(zp, x))])

        a, b = cl(R(1320.0)), cl(R(1745.0))
        t = (b - a) / np.linalg.norm(b - a)
        self.ws_O = np.array([B.x_cowl, 0.0, B.z_belt])
        self.ws_t = t
        self.ws_n = np.array([t[2], 0.0, -t[0]])  # into the cabin

    def ws_uv(self, y, zp):
        """Windscreen point (lateral y, design height zp) -> glass-plane (y, v)."""
        B = self.B
        x = float(B.ws_x(zp, y))
        p = np.array([x, y, float(B.gz(zp, x))])
        return (y, float(np.dot(p - self.ws_O, self.ws_t)))

    def ws_prism(self, shape):
        out, into = 8.0 * self.k, self.B.bow_f * 0.75 + 8.0 * self.k
        m = Manifold.extrude(g.cs(shape), out + into).translate([0, 0, -out])
        M = np.column_stack([[0.0, 1.0, 0.0], self.ws_t, self.ws_n, self.ws_O])
        return m.transform(M.tolist())

    # ------------------------------------------------------------------ arches
    def arch(self, xc):
        """Wheel arch opening and flare outline (side view polylines, front to rear)."""
        if xc in self._arch:
            return self._arch[xc]
        P, B, R, k = self.P, self.B, self.P.R, self.k
        zax, tr = P.z_axle, P.tire_od / 2
        a_in = max(R(500.0), tr + P.arch_clear_side)
        top_in = max(R(888.0), zax + tr + P.arch_clear_top)
        a_out = max(R(625.0), a_in + 7.5 * k)
        top_out = max(R(1085.0), top_in + 8.0 * k)
        limit = float(B.zsh(xc)) - 3.5 * k
        if top_out > limit:
            self.notes.append(
                f"arch at x={xc:.0f}: a {P.tire_od:.0f} mm tyre with {P.lift:.0f} mm lift leaves no fender above "
                "the flare; flare height was capped - use a smaller tyre or more lift"
            )
            top_out = limit
            top_in = min(top_in, top_out - 6.0 * k)
        z_end = R(470.0)

        def curve(a, top, n):
            b = top - zax
            th = np.linspace(0, np.pi, 241)
            c, s_ = np.cos(th), np.sin(th)
            x = xc - a * np.sign(c) * np.abs(c) ** (2 / n)
            z = zax + b * s_ ** (2 / n)
            pts = np.stack([x, z], -1)
            if zax > z_end:  # straight legs down to the lower edge
                pts = np.concatenate([[[xc - a, z_end]], pts, [[xc + a, z_end]]])
            else:
                keep = pts[:, 1] >= z_end
                i0, i1 = np.argmax(keep), len(keep) - 1 - np.argmax(keep[::-1])

                def cross(i, j):
                    p, q = pts[i], pts[j]
                    return p + (q - p) * (z_end - p[1]) / (q[1] - p[1])

                pts = np.concatenate([[cross(i0 - 1, i0)], pts[i0 : i1 + 1], [cross(i1 + 1, i1)]])
            return resample(pts, 97)

        res = dict(inner=curve(a_in, top_in, 2.4), outer=curve(a_out, top_out, 3.2), a_in=a_in, a_out=a_out,
                   top_in=top_in, top_out=top_out, z_end=z_end)
        self._arch[xc] = res
        return res

    def arch_shape(self, xc, which="inner", grow=0.0):
        c = self.arch(xc)[which]
        poly = sg.Polygon(np.concatenate([[[c[0][0], -60.0]], c, [[c[-1][0], -60.0]]]))
        return poly.buffer(grow, quad_segs=6) if grow else poly

    def flare(self, xc):
        """Wheel arch flare (right-hand side), swept along the arch."""
        P, B, k = self.P, self.B, self.k
        a = self.arch(xc)
        cin, cout = a["inner"], a["outer"]
        t = P.wall
        p = P.Ry(58.0)  # flare stand-out from the flank
        e, lip = 0.8 * k, 1.2 * k
        face = 0.74  # share of the band that is flat face before the edge rolls off
        gap = -OV if self.fused else P.fit
        back = -OV if self.fused else 0.0
        deep = -(t + 0.6 * k)
        phi = np.radians(np.linspace(0, 90, 7)[1:])
        rings, caps = [], []
        for i in range(len(cin)):
            d = cout[i] - cin[i]
            band = float(np.linalg.norm(d))
            er = d / band
            prof = [(-lip, deep), (-lip, p - k), (-lip + 0.3 * k, p - 0.3 * k), (-lip + k, p), (face * band, p)]
            prof += [((face + (1 - face) * np.sin(f)) * band, e + (p - e) * np.cos(f)) for f in phi]
            prof += [(band, back), (0.75 * band, back), (0.5 * band, back), (0.25 * band, back), (-gap, back), (-gap, deep)]
            prof = np.array(prof)
            xz = cin[i][None] + prof[:, :1] * er[None]
            y = B.side_y(xz[:, 0], xz[:, 1]) + prof[:, 1]
            rings.append(np.column_stack([xz[:, 0], y, xz[:, 1]]))
            caps.append(prof * np.array([-1.0, 1.0]))
        V, F = g.loft(np.stack(rings), (0, 1), caps="earclip", caps2d=(caps[0], caps[-1]))
        return g.to_manifold(V, F)

    def flare_screws(self, xc):
        """(x, y, z) on the right flank for the flare screws (1:10 class only)."""
        if self.fused or self.P.screw < 3.0:
            return []  # small-scale flares are glued; their lip locates them on the arch
        a = self.arch(xc)
        out = []
        for i in (10, 48, 86):
            pnt = a["inner"][i] + 0.42 * (a["outer"][i] - a["inner"][i])
            out.append((pnt[0], float(self.B.side_y(pnt[0], pnt[1])), pnt[1]))
        return out

    # ------------------------------------------------------------------ windows
    def window_shapes(self):
        """Side-view glass outlines (model xz), keyed by name."""
        r = self.P.R
        front = g.rpoly(self.pts([(850, 1305), (1680, 1305), (1680, 1753), (1130, 1753), (850, 1455)]), r(45))
        rear_a = g.rpoly(self.pts([(1806, 1305), (2300, 1305), (2300, 1753), (1806, 1753)]), r(40))
        rear_b = g.rpoly(self.pts([(2336, 1305), (2640, 1305), (2640, 1753), (2336, 1753)]), r(40))
        quarter = g.rpoly(self.pts([(2740, 1305), (3600, 1305), (3545, 1753), (2740, 1753)]), r(70))
        return {"front_door": front, "rear_door": unary_union([rear_a, rear_b]), "quarter": quarter}

    def windscreen_shape(self):
        """Windscreen opening in glass-plane coordinates (y, v)."""
        P, B = self.P, self.B
        z0, z1 = P.R(1320.0), P.R(1745.0)
        xs = B.x_cowl + B.bow_f
        yb = float(B.gh_halfw(xs, z0)) - P.Ry(88.0)
        yt = float(B.gh_halfw(xs, z1)) - P.Ry(78.0)
        ys = np.linspace(-yb, yb, 15)
        bottom = [self.ws_uv(y, z0 + P.R(40.0) * (1 - (y / yb) ** 2)) for y in ys]
        top = [self.ws_uv(yt, z1), self.ws_uv(-yt, z1)]
        return g.rpoly(bottom + top, P.R(55.0))

    def rear_window_shapes(self):
        P, B = self.P, self.B
        z0, z1 = P.R(1320.0), P.R(1740.0)
        xr = P.R(3700.0)
        ys = P.Ry(-184.0)  # barn door split (the left door is the narrow one)
        bar = P.Ry(62.0)
        hb = float(B.gh_halfw(xr, z0)) - P.Ry(88.0)
        ht = float(B.gh_halfw(xr, z1)) - P.Ry(80.0)
        zf0 = float(B.gz(z0, B.rear_x(z0)))
        zf1 = float(B.gz(z1, B.rear_x(z1)))
        left = g.rpoly([(-hb, zf0), (ys - bar, zf0), (ys - bar, zf1), (-ht, zf1)], P.R(42.0))
        right = g.rpoly([(ys + bar, zf0), (hb, zf0), (ht, zf1), (ys + bar, zf1)], P.R(42.0))
        return {"rear_left": left, "rear_right": right}, ys

    def glazing(self, prism_of, shape, name, hint):
        """A glazing insert: a plug filling the opening plus a glue flange inside."""
        P, B, k = self.P, self.B, self.k
        t = P.wall
        flange = prism_of(shape.buffer(2.4 * k, quad_segs=6)) ^ (B.core(t) - B.core(t + P.glass_flange))
        plug = prism_of(shape.buffer(-P.fit, quad_segs=6)) ^ (B.core(0.35 * k) - B.core(t + 0.05))
        return self.add(name, flange + plug, "clear", note="clear PETG/resin, glued in from inside", down=("flat", hint))

    # ------------------------------------------------------------------ shell
    def build_shell(self):
        P, B, R, Ry, k = self.P, self.B, self.P.R, self.P.Ry, self.k
        outer, inner = B.outer(), B.inner()
        shell = outer - inner

        # internal structure first, so every later cut also trims it
        shell = shell + self.joint_flanges() + self.mount_rails()

        # ---- lower edge and wheel arches
        zs, zf, zr = B.z_sill, R(560.0), R(560.0)
        under = sg.Polygon(
            [(-200, -80), (600, -80), (600, zr), (self.xc_r, zr), (self.xc_r, zs), (self.xc_f, zs), (self.xc_f, zf), (-200, zf)]
        )
        cut = [self.across(under)]
        nw, nz = P.frame_notch_width / 2, R(P.frame_notch_top)
        if nw > 0:  # frame-horn clearance in the nose and tail panels, hidden by the bumpers
            cut.append(g.box(B.x_face - 4.0, -nw, 0.0, B.x_face + 10.0 * k, nw, nz))
            cut.append(g.box(B.x_rear - 10.0 * k, -nw, 0.0, B.x_rear + 4.0, nw, nz))
        for xc in (self.xc_f, self.xc_r):
            cut.append(self.across(self.arch_shape(xc, "inner")))

        # ---- glass openings
        win = self.window_shapes()
        for shp in win.values():
            cut.append(self.across(shp))
        ws = self.windscreen_shape()
        cut.append(self.ws_prism(ws))
        rw, y_split = self.rear_window_shapes()
        self._rw_prism = lambda s: g.extrude_x(s, B.x_rear - R(400.0), B.x_rear + 6.0)
        for shp in rw.values():
            cut.append(self._rw_prism(shp))
        shell = shell - g.union(cut)

        # ---- engraved panel lines
        gw = P.groove_w
        rub = 1.3 * k
        grooves = []
        lines = [
            self.pts([(581, 532), (581, 1277)]),  # front door leading edge
            self.pts([(581, 532), (2350, 532)]),  # door bottoms
            self.pts([(1724, 532), (1724, 1755)]),  # B pillar shut line
            self.pts([(2690, 1070), (2690, 1755)]),  # rear door trailing edge
        ]
        for ln in lines:
            grooves.append(self.across(g.stroke(ln, gw)))
        for shp in win.values():  # window rubbers
            grooves.append(self.across(outline(shp, rub, gw)))
        # fuel filler flap, right-hand rear quarter
        grooves.append(self.across(outline(g.rrect(R(3335.0), R(1120.0), R(3500.0), R(1252.0), R(22.0)), 0.0, gw), side=+1))
        # bonnet shut line
        xs = np.linspace(B.x_face + R(62.0), R(465.0), 40)
        yh = B.w_eff(xs) - B.barrel(B.zsh(xs)) - Ry(82.0)
        loop = np.concatenate([np.stack([xs, yh], -1), np.stack([xs[::-1], -yh[::-1]], -1)])
        grooves.append(g.extrude_z(g.stroke(loop, gw, closed=True), R(950.0), R(1450.0)))
        # roof drip channels
        for sgn in (-1, 1):
            grooves.append(g.extrude_z(g.stroke([(R(1090.0), sgn * Ry(640.0)), (R(3540.0), sgn * Ry(628.0))], 1.4 * gw), R(1700.0), R(1950.0)))
        # tailgate: barn door split, door bottoms, number plate recess
        rear = lambda s: g.extrude_x(s, B.x_rear - R(400.0), B.x_rear + 6.0)
        ztop = float(B.gz(R(1790.0), B.rear_x(R(1790.0))))
        grooves.append(rear(g.stroke([(y_split, R(842.0)), (y_split, ztop)], gw)))
        grooves.append(rear(g.stroke([(-Ry(735.0), R(842.0)), (Ry(735.0), R(842.0))], gw)))
        grooves.append(rear(outline(g.rrect(Ry(-655.0), R(905.0), Ry(-285.0), R(1105.0), R(20.0)), 0.0, gw)))
        # windscreen and tailgate glass rubbers
        grooves.append(self.ws_prism(outline(ws, rub, gw)))
        for shp in rw.values():
            grooves.append(self._rw_prism(outline(shp, rub, gw)))
        shell = shell - self.skin_cut(g.union(grooves), P.groove_d)

        # ---- door handles: recessed scoop with a raised pull
        scoops, pulls = [], []
        for x0 in (1445.0, 2455.0):
            scoops.append(g.rrect(R(x0), R(1126.0), R(x0 + 205.0), R(1176.0), R(14.0)))
            pulls.append(g.rrect(R(x0 + 8.0), R(1150.0), R(x0 + 197.0), R(1172.0), R(8.0)))
        shell = shell - self.skin_cut(self.across(unary_union(scoops)), 0.6 * k)
        shell = shell + (self.across(unary_union(pulls)) ^ (B.grown(0.35 * k) - B.core(0.7 * k)))

        # ---- pockets and holes for the add-on parts
        shell = self.front_details(shell)
        shell = self.rear_details(shell)
        shell = shell - self.body_holes()

        self.shell, dropped = g.keep_main(shell)
        if dropped:
            self.notes.append(f"body shell: removed {dropped} loose fragment(s) left by cuts")

        # ---- glazing inserts
        tl = np.tan(B.tau)
        for sgn, tag in ((1, "R"), (-1, "L")):
            side = lambda s, sgn=sgn: self.across(s, sgn)
            hint = (0.0, -sgn * 1.0, -tl)
            self.glazing(side, win["front_door"], f"glass_front_door_{tag}", hint)
            self.glazing(side, win["rear_door"], f"glass_rear_door_{tag}", hint)
            self.glazing(side, win["quarter"], f"glass_quarter_{tag}", hint)
        self.glazing(self.ws_prism, ws, "glass_windscreen", tuple(self.ws_n))
        self.glazing(self._rw_prism, rw["rear_left"], "glass_tailgate_L", (-1.0, 0.0, -np.tan(B.lean_r)))
        self.glazing(self._rw_prism, rw["rear_right"], "glass_tailgate_R", (-1.0, 0.0, -np.tan(B.lean_r)))
        return self.shell

    # ------------------------------------------------------------------ front
    def front_shapes(self):
        R, Ry = self.P.R, self.P.Ry
        grille = g.rrect(-Ry(418.0), R(894.0), Ry(418.0), R(1110.0), R(16.0))
        lamp = g.rrect(Ry(438.0), R(902.0), self.W + 8.0, R(1108.0), R(30.0))
        return grille, lamp

    def front_details(self, shell):
        P, B, R, Ry, k = self.P, self.B, self.P.R, self.P.Ry, self.k
        grille, lamp = self.front_shapes()
        fr = lambda s, depth=R(240.0): g.extrude_x(s, B.x_face - 8.0, B.x_face + depth)
        pd = P.pocket_d
        lamps = unary_union([lamp, affinity.scale(lamp, -1, 1, origin=(0, 0))])
        pockets = fr(grille.buffer(self.fit), R(60.0)) + fr(lamps.buffer(self.fit))
        shell = shell - self.skin_cut(pockets, pd)
        floor = B.core(pd + OV if self.fused else pd - 0.05)

        # grille insert: recessed floor, raised mesh, proud surround / wing bars / badge
        gi = self.inset(grille)
        base = fr(gi, R(60.0)) ^ (B.core(0.2 * k) - floor)
        inner = grille.buffer(-R(17.0))
        y0, z0, y1, z1 = inner.bounds
        zc = (z0 + z1) / 2
        bar = Ry(46.0)
        bars = []
        for sgn in (-1, 1):
            bars.append(sg.Polygon([(sgn * Ry(196.0), z0 - 1), (sgn * (Ry(196.0) + bar), z0 - 1), (sgn * (Ry(262.0) + bar), z1 + 1), (sgn * Ry(262.0), z1 + 1)]))
        disc = sg.Point(0, zc).buffer(R(56.0), quad_segs=12)
        ring = disc.difference(sg.Point(0, zc).buffer(R(38.0), quad_segs=12))
        logo = unary_union([ring, g.rrect(-R(72.0), zc - R(14.0), R(72.0), zc + R(14.0), R(4.0))])
        proud = unary_union([grille.difference(inner), *bars, logo]).intersection(gi)
        pitch = R(46.0)
        lw = max(0.22, 0.38 * k)
        mesh_lines = []
        for i in np.arange(-40, 41):
            for sl in (-1, 1):
                mesh_lines.append(sg.LineString([(i * pitch - 60, zc - 60 * sl), (i * pitch + 60, zc + 60 * sl)]).buffer(lw, cap_style="flat"))
        mesh = unary_union(mesh_lines).intersection(inner)
        grille_part = (
            base
            + (fr(mesh, R(60.0)) ^ (B.grown(0.15 * k) - floor))
            + (fr(proud, R(60.0)) ^ (B.grown(0.55 * k) - floor))
        )
        self.add("grille", grille_part, "silver", note="paint the mesh black; surround, bars and badge chrome", down=(1, 0, 0))

        # headlight lenses with LED sockets behind them
        lens = fr(self.inset(lamp)) ^ (B.grown(0.4 * k) - floor)
        yc, zc2 = Ry(560.0), R(1005.0)
        mw = max(0.2, 0.3 * k)
        marks = unary_union([
            sg.Point(yc, zc2).buffer(R(78.0), quad_segs=14).exterior.buffer(mw),
            sg.LineString([(Ry(690.0), R(902.0)), (Ry(690.0), R(1108.0))]).buffer(mw),
            sg.Point(Ry(790.0), R(940.0)).buffer(R(40.0), quad_segs=10).exterior.buffer(mw),
        ]).intersection(lamp.buffer(-0.6 * k))
        lens = lens - (fr(marks) - B.grown(0.08 * k))
        c = sg.Point(yc, zc2)
        dish = c.buffer(R(70.0), quad_segs=14).difference(c.buffer(R(24.0), quad_segs=10))
        lens = lens - (fr(dish) - B.core(0.1 * k))  # reflector bowl around the bulb
        self.add("headlight_R", lens, "lens", note="clear/natural filament; LED socket behind", down=(1, 0, 0))
        self.add("headlight_L", lens.mirror([0, 1, 0]), "lens", down=(1, 0, 0))
        r_led = 2.6 if P.screw >= 3.0 else 1.6  # 5 mm or 3 mm LED
        for sgn in (-1, 1):
            # kit: open hole behind the separate lens; fused: blind socket that stops at the lens
            x0 = B.x_face + pd + 2 * OV if self.fused else B.x_face - 3.0
            shell = shell - g.cyl((x0, sgn * yc, zc2), (B.x_face + 8.0, sgn * yc, zc2), r_led)
        return shell

    # ------------------------------------------------------------------ rear
    def rear_details(self, shell):
        P, B, R, Ry, k = self.P, self.B, self.P.R, self.P.Ry, self.k
        pd = P.pocket_d
        rear = lambda s, depth=R(235.0): g.extrude_x(s, B.x_rear - depth, B.x_rear + 8.0)
        lamp = g.rrect(Ry(735.0), R(838.0), self.W + 8.0, R(1268.0), R(26.0))
        lamps = unary_union([lamp, affinity.scale(lamp, -1, 1, origin=(0, 0))])
        garnish = g.rrect(Ry(-705.0), R(1142.0), Ry(-212.0), R(1206.0), R(14.0))
        gd = 0.6 * k
        shell = shell - self.skin_cut(rear(lamps.buffer(self.fit)), pd)
        shell = shell - self.skin_cut(rear(garnish.buffer(self.fit), 12.0 * k), gd)
        floor = B.core(pd + OV if self.fused else pd - 0.05)

        lens = rear(self.inset(lamp)) ^ (B.grown(0.4 * k) - floor)
        mw = max(0.2, 0.3 * k)
        marks = unary_union([
            sg.LineString([(Ry(735.0), R(z)), (self.W + 8.0, R(z))]).buffer(mw) for z in (988.0, 1120.0)
        ]).intersection(lamp.buffer(-0.6 * k))
        lens = lens - (rear(marks) - B.grown(0.08 * k))
        self.add("taillight_R", lens, "red", note="translucent red; LED holes behind", down=(-1, 0, 0))
        self.add("taillight_L", lens.mirror([0, 1, 0]), "red", down=(-1, 0, 0))
        r_led = 1.6 if P.screw >= 3.0 else 1.05
        for sgn in (-1, 1):
            for z in (912.0, 1195.0):
                xt = float(B.tail_x(R(z)))
                x0 = xt - pd - 2 * OV if self.fused else xt + 3.0
                shell = shell - g.cyl((x0, sgn * Ry(800.0), R(z)), (xt - 9.0, sgn * Ry(800.0), R(z)), r_led)

        # tailgate garnish with the pull handle at its inboard end
        gar = rear(self.inset(garnish), 12.0 * k) ^ (B.grown(0.9 * k) - B.core(gd + OV if self.fused else gd - 0.05))
        pull = g.rrect(Ry(-330.0), R(1150.0), Ry(-222.0), R(1198.0), R(8.0))
        gar = gar + (rear(pull, 12.0 * k) ^ (B.grown(1.5 * k) - B.core(0.0)))
        self.add("tailgate_garnish", gar, "silver", note="chrome strip above the number plate", down=(-1, 0, 0))
        return shell

    # ------------------------------------------------------------------ holes
    def spare_center(self):
        return self.P.Ry(338.0), self.P.R(1130.0)

    def mirror_mount(self):
        x = self.P.R(800.0)
        zp = self.P.R(1348.0)
        return x, zp, float(self.B.gh_halfw(x, zp))

    def bumper_screws(self):
        R, Ry = self.P.R, self.P.Ry
        return [(sgn * Ry(y), R(770.0)) for y in (480.0, 690.0) for sgn in (-1, 1)]

    def step_screw_x(self):
        return np.linspace(self.P.R(900.0), self.P.R(2100.0), 4)

    def r_peg(self):
        return max(0.95, 1.45 * self.k)

    def body_holes(self):
        P, B, R, Ry = self.P, self.B, self.P.R, self.P.Ry
        t = P.wall
        rc = P.r_clear
        holes = []
        for xc in (self.xc_f, self.xc_r):
            for x, y, z in self.flare_screws(xc):
                for sgn in (-1, 1):
                    holes.append(g.cyl((x, sgn * (y - t - 2.0), z), (x, sgn * (y + 1.0), z), 1.15))
        if not self.fused:
            for y, z in self.bumper_screws():  # bumper screws through the nose and tail panels
                xf = float(B.face_x(y, z))
                holes.append(g.cyl((xf - 1.0, y, z), (xf + t + 2.0, y, z), rc))
                holes.append(g.cyl((B.x_rear + 1.0, y, R(700.0)), (B.x_rear - t - 2.0, y, R(700.0)), rc))
            for x in self.step_screw_x():  # side step screws through the sill
                for sgn in (-1, 1):
                    holes.append(g.cyl((x, sgn * (self.W - 12.0 * self.k), R(545.0)), (x, sgn * (self.W + 3.0), R(545.0)), rc))
        ys, zs = self.spare_center()  # spare wheel carrier
        for dz in (-R(85.0), R(85.0)):
            xt = float(B.tail_x(zs + dz))
            holes.append(g.cyl((xt + 1.0, ys, zs + dz), (xt - t - 2.0, ys, zs + dz), rc))
        xm, zm, ym = self.mirror_mount()  # mirror pegs
        for sgn in (-1, 1):
            holes.append(g.cyl((xm, sgn * (ym - t - 2.0), zm), (xm, sgn * (ym + 2.0), zm), self.r_peg() + 0.1))
        return g.union(holes) + self.structure_holes()

    # ------------------------------------------------------------------ structure
    def joint_flanges(self):
        """Inward ribs either side of each print seam, bolted / glued together.

        The ribs taper at 45 degrees away from the seam so a section printed
        standing on end needs no support under them.
        """
        P, B = self.P, self.B
        d, ft, st = P.flange_depth, P.flange_t, 0.6
        outer, inner = B.outer(), B.inner()
        solids, clear = [], []
        self.flange_holes = []
        for xc in self.seams:
            So = g.slice_x(outer, xc).offset(-0.3 * P.wall)
            Si = g.slice_x(inner, xc)
            solids.append(g.extrude_x(So - Si.offset(-d), xc - ft, xc + ft))
            clear.append(g.extrude_x(So - Si.offset(-d - 0.3), xc - ft - 0.3, xc + ft + 0.3))
            n = int(round(d / st))
            for j in range(1, n):
                ring = So - Si.offset(-(d - j * st))
                a, b = ft + (j - 1) * st, ft + j * st
                solids.append(g.extrude_x(ring, xc + a, xc + b))
                solids.append(g.extrude_x(ring, xc - b, xc - a))
                ringc = So - Si.offset(-(d - j * st) - 0.3)
                clear.append(g.extrude_x(ringc, xc + a, xc + b + 0.3))
                clear.append(g.extrude_x(ringc, xc - b - 0.3, xc - a))
            # bolt positions on the rib centreline
            mid = g.to_shapely(Si.offset(-d / 2))
            bnd = mid.boundary
            zlo, zhi = mid.bounds[1], mid.bounds[3]
            ymax = mid.bounds[2]
            pts = []
            for y in (0.0, -0.5 * ymax, 0.5 * ymax):
                hit = bnd.intersection(sg.LineString([(y, zlo - 5), (y, zhi + 5)]))
                zs = [q.y for q in getattr(hit, "geoms", [hit]) if not q.is_empty]
                if zs:
                    pts.append((y, max(zs)))
            for z in (P.R(720.0), P.R(1090.0), 0.5 * (B.z_belt + zhi)):
                if z >= zhi - 4 * self.k:
                    continue
                hit = bnd.intersection(sg.LineString([(-BIG, z), (BIG, z)]))
                ys = [q.x for q in getattr(hit, "geoms", [hit]) if not q.is_empty]
                if ys:
                    pts += [(max(ys), z), (min(ys), z)]
            for y, z in pts:
                p2 = sg.Point(xc, z)
                if any(self.arch_shape(c, "outer", 2.5).contains(p2) for c in (self.xc_f, self.xc_r)):
                    continue  # no wall here - the wheel arch has it
                if z < B.z_sill + 6 * self.k:
                    continue
                self.flange_holes.append((xc, y, z))
        self.flange_clear = g.union(clear)
        return g.union(solids) ^ outer

    def rail_zone(self):
        """Z range of the mounting rails: just above the wheel arch openings."""
        top = max(self.arch(self.xc_f)["top_in"], self.arch(self.xc_r)["top_in"])
        z0 = top + 4.0 * self.k
        return z0, z0 + self.P.rail_height

    def rail_spans(self):
        P = self.P
        m = P.flange_t + P.flange_depth + 1.0
        xa, xb = -P.R(560.0), P.R(330.0)
        xc, xd = self.xc_r - P.R(330.0), self.xc_r + P.R(640.0)
        for s in self.seams:  # keep clear of the seam ribs
            if xa < s < xb + m:
                xb = min(xb, s - m)
            if xc - m < s < xd:
                xc = max(xc, s + m)
        return (xa, xb), (xc, xd)

    def mount_rails(self):
        """Reinforced rails inside the fenders that carry the body-post crossbars."""
        P, B = self.P, self.B
        z0, z1 = self.rail_zone()
        zm = 0.5 * (z0 + z1)
        S = B.inner().slice(zm)
        slab = g.extrude_z(S - S.offset(-P.rail_depth), z0, z1)
        front, rear = self.rail_spans()
        rails = []
        self.rail_holes = {"front": [], "rear": []}
        c45 = 0.7071068
        pitch = 8.0 * self.k if P.screw >= 3.0 else 6.0
        for name, (xa, xb) in (("front", front), ("rear", rear)):
            r = slab ^ g.box(xa, -BIG, z0 - 1, xb, BIG, z1 + 1)
            # chamfer both ends so the rail prints without support either way up
            for sgn in (-1, 1):
                ywa = float(B.side_y(xa, zm)) - P.wall
                ywb = float(B.side_y(xb, zm)) - P.wall
                r = r.trim_by_plane([c45, c45 * sgn, 0.0], (xa + ywa) * c45)
                r = r.trim_by_plane([-c45, c45 * sgn, 0.0], (-xb + ywb) * c45)
            rails.append(r)
            for x in np.arange(xa + P.rail_depth + 2.0, xb - P.rail_depth - 1.0, pitch):
                yw = float(B.side_y(x, zm)) - P.wall
                self.rail_holes[name].append((float(x), yw - 0.55 * P.rail_depth))
        self.rail_z = (z0, z1)
        return g.union(rails) ^ B.outer()

    def structure_holes(self):
        P = self.P
        holes = []
        ft, d = P.flange_t, P.flange_depth
        for x, y, z in self.flange_holes:  # screw clearance through both ribs
            holes.append(g.cyl((x - ft - d, y, z), (x + ft + d, y, z), P.r_clear))
        z0, z1 = self.rail_z
        for name in ("front", "rear"):  # self-tapping pilots, from below
            for x, y in self.rail_holes[name]:
                for sgn in (-1, 1):
                    holes.append(g.cyl((x, sgn * y, z0 - 1.0), (x, sgn * y, z1 + 1.0), P.r_pilot + 0.05))
        return g.union(holes)

    def crossbar(self, which):
        """Bolt-on crossbar with the body post holes; hangs under the rails."""
        P, B, k = self.P, self.B, self.k
        zm = 0.5 * sum(self.rail_z)
        holes = self.rail_holes[which]
        (xa, xb) = self.rail_spans()[0 if which == "front" else 1]
        xs = np.linspace(xa, xb, 30)
        half = float(np.min(B.side_y(xs, zm))) - P.wall - 0.8
        y_in = min(y for _, y in holes) - 2.5 * k
        pd_ = P.post_d
        w = 4.0 * pd_
        sx = w / 2 - 0.7 * pd_
        sw = P.r_clear + 0.05
        cuts = []
        for x in (-sx, sx):  # open fork slots for the rail screws
            cuts.append(g.rrect(x - sw, y_in, x + sw, half + 3.0, sw - 0.05))
            cuts.append(g.rrect(x - sw, -half - 3.0, x + sw, -y_in, sw - 0.05))
        rp = (pd_ + 0.4) / 2
        spacing = P.post_spacing_front if which == "front" else P.post_spacing_rear
        if spacing:
            for sgn in (-1, 1):
                cuts.append(sg.Point(0.0, sgn * spacing / 2).buffer(rp, quad_segs=12))
        else:  # universal pattern: two staggered rows
            y_max = y_in - rp - 1.5
            for row, x in enumerate((-0.92 * pd_, 0.92 * pd_)):
                y = (3.0 + 0.75 * row) * pd_
                while y <= y_max:
                    for sgn in (-1, 1):
                        cuts.append(sg.Point(x, sgn * y).buffer(rp, quad_segs=12))
                    y += 1.5 * pd_
        shape = g.rrect(-w / 2, -half, w / 2, half, 2.5 * k).difference(unary_union(cuts))
        return g.extrude_z(shape, 0.0, max(2.4, 4.0 * k)), half

    # ------------------------------------------------------------------ flares
    def build_flares(self):
        for tag, xc in (("front", self.xc_f), ("rear", self.xc_r)):
            f = self.flare(xc)
            for x, y, z in self.flare_screws(xc):  # blind pilots from the back
                f = f - g.cyl((x, y - 1.0, z), (x, y + 2.6, z), 0.85)
            self.add(f"flare_{tag}_R", f, "black", note="glue; the lip locates it on the arch edge", down=(0, -1, 0))
            self.add(f"flare_{tag}_L", f.mirror([0, 1, 0]), "black", down=(0, 1, 0))

    # ------------------------------------------------------------------ bumpers
    def _bumper(self, front: bool):
        P, B, R, Ry, k = self.P, self.B, self.P.R, self.P.Ry, self.k
        t = P.wall
        p = Ry(30.0)
        if front:
            zt, zb, D = R(880.0), R(450.0), R(112.0)
            xe = B.x_face - D
            prof = [(xe + R(18), zt), (xe, zt - R(60)), (xe, R(610)), (xe + R(50), zb), (B.x_face + R(140), R(470)), (-R(250), R(560)), (-R(250), zt)]
            shift = -(D - p)
            xc = self.xc_f
            end = g.cs(sg.box(-BIG, -BIG, xc - R(380.0), BIG))
        else:
            zt, zb, D = R(822.0), R(445.0), R(165.0)
            xe = B.x_rear + D
            prof = [(xe - R(25), zt), (xe, zt - R(45)), (xe, R(600)), (xe - R(70), zb), (B.x_rear - R(150), R(470)), (self.xc_r + R(250), R(560)), (self.xc_r + R(250), zt)]
            shift = D - p
            xc = self.xc_r
            end = g.cs(sg.box(xc + R(380.0), -BIG, 3 * BIG, BIG))
        S = B.outer().slice(0.5 * (zt + zb))
        Sp = S.offset(p, m3.JoinType.Round) ^ end
        plan = m3.CrossSection.batch_hull([Sp, Sp.translate((shift, 0.0))])
        hw = self.W + p + 1.0
        x0, x1 = (xe, xe + R(1500.0)) if front else (xe - R(1500.0), xe)
        plan = plan ^ g.cs(g.rrect(x0, -hw, x1, hw, R(300.0), res=16))  # round the outer corners in plan
        rim = plan - S.offset(-(t + 2.5 * k))
        solid = g.extrude_z(rim, zb - 2.0, zt + 2.0) ^ self.across(g.rpoly(prof, R(22.0)))
        # lower outer corners are cut back, as on the car
        cut = Ry(120.0)
        front_view = sg.Polygon([(-hw, zt + 5), (hw, zt + 5), (hw, R(570.0)), (hw - cut, zb - 5), (-hw + cut, zb - 5), (-hw, R(570.0))])
        solid = solid ^ g.extrude_x(front_view, -BIG, 2 * BIG)
        solid = solid - self.hug() - self.across(self.arch_shape(xc, "outer", -OV if self.fused else P.fit))
        return solid, xe, zt, zb

    def build_bumpers(self):
        P, B, R, Ry, k = self.P, self.B, self.P.R, self.P.Ry, self.k
        nw, nz = P.frame_notch_width / 2, R(P.frame_notch_top)
        # ---- front
        fb, xe, zt, zb = self._bumper(True)
        intake = g.rrect(-Ry(470.0), R(500.0), Ry(470.0), R(765.0), R(24.0))
        keep = [g.rrect(-Ry(175.0), R(592.0), Ry(175.0), R(745.0), R(8.0))]  # number plate plinth
        keep += [sg.box(-Ry(480.0), R(z), Ry(480.0), R(z + 22.0)) for z in (575.0, 655.0)]  # slats
        fb = fb - g.extrude_x(intake.difference(unary_union(keep)), xe - 6.0, xe + R(24.0))
        for sgn in (-1, 1):  # blanked fog-lamp recesses of the GL
            c = sg.Point(sgn * Ry(655.0), R(650.0))
            ring = c.buffer(R(58.0), quad_segs=14).difference(c.buffer(R(40.0), quad_segs=14))
            fb = fb - g.extrude_x(ring, xe - 6.0, xe + R(16.0))
        if not self.fused:
            for y, z in self.bumper_screws():
                xf = float(B.face_x(y, z))
                fb = fb - g.cyl((xf - 7.5 * k, y, z), (xf + 1.0, y, z), P.r_pilot)
        if nw > 0:  # room for the chassis frame horns behind the beam
            fb = fb - g.box(B.x_face, -nw, 0.0, B.x_face + 14.0, nw, nz + 0.5)
        self.add("bumper_front", fb, "black", note="screwed from inside the nose panel (or glued)", down=(0, 0, 1))
        # ---- rear
        rb, xe, zt, zb = self._bumper(False)
        tread = [sg.box(xe - R(150.0) + i * R(26.0), -Ry(520.0), xe - R(150.0) + i * R(26.0) + R(9.0), Ry(520.0)) for i in range(5)]
        rb = rb - g.extrude_z(unary_union(tread), zt - 0.5 * k, zt + 3.0)
        for sgn in (-1, 1):  # reflector recesses
            rb = rb - g.extrude_x(g.rrect(sgn * Ry(600.0) - R(75.0), R(560.0), sgn * Ry(600.0) + R(75.0), R(610.0), R(8.0)), xe - R(40.0), xe + 6.0)
        if not self.fused:
            for y, z in self.bumper_screws():
                rb = rb - g.cyl((B.x_rear + 7.5 * k, y, R(700.0)), (B.x_rear - 1.0, y, R(700.0)), P.r_pilot)
        if nw > 0:
            rb = rb - g.box(B.x_rear - 14.0, -nw, 0.0, B.x_rear, nw, nz + 0.5)
        self.add("bumper_rear", rb, "black", note="screwed from inside the tail panel (or glued)", down=(0, 0, 1))

    # ------------------------------------------------------------------ side steps
    def build_side_steps(self):
        P, B, R, Ry, k = self.P, self.B, self.P.R, self.P.Ry, self.k
        x0 = self.xc_f + self.arch(self.xc_f)["a_out"] + (0.0 if self.fused else 1.2 * k)
        x1 = self.xc_r - self.arch(self.xc_r)["a_out"] - (0.0 if self.fused else 1.2 * k)
        zt, zbt = R(432.0), R(392.0)
        board = g.extrude_z(g.rrect(x0, self.W - 13.0 * k, x1, self.W + Ry(78.0), 4.0 * k), zbt, zt)
        ribs = [sg.box(x0 + 6.0 * k, self.W + (1.5 + i * 2.6) * k, x1 - 6.0 * k, self.W + (2.4 + i * 2.6) * k) for i in range(3)]
        board = board - g.extrude_z(unary_union(ribs), zt - 0.4 * k, zt + 1.0)
        c0 = P.wall - OV if self.fused else P.wall + P.fit
        fin = g.box(x0 + 4.0 * k, 0.0, zbt, x1 - 4.0 * k, BIG, R(590.0)) ^ (B.core(c0) - B.core(c0 + max(1.2, 2.0 * k)))
        step = board + fin
        if not self.fused:
            for x in self.step_screw_x():
                step = step - g.cyl((x, self.W - 12.0 * k, R(545.0)), (x, self.W + 3.0, R(545.0)), P.r_pilot)
        self.add("side_step_R", step, "black", note="screws through the sill, or glue", down=(0, 0, 1))
        self.add("side_step_L", step.mirror([0, 1, 0]), "black", down=(0, 0, 1))

    # ------------------------------------------------------------------ mirrors
    def build_mirrors(self):
        P, B, R, Ry, k = self.P, self.B, self.P.R, self.P.Ry, self.k
        xm, zm, ym = self.mirror_mount()
        hx0, hx1 = xm - R(35.0), xm + R(62.0)  # glass faces rearward (+X)
        hy0, hy1 = ym + R(52.0), ym + R(52.0) + Ry(215.0)
        hz0, hz1 = zm - R(40.0), zm + R(128.0)
        head = g.extrude_x(g.rrect(hy0, hz0, hy1, hz1, R(32.0)), hx0, hx1)
        nose = g.extrude_y(g.rpoly([(hx0, hz0 + R(30)), (hx0 + R(30), hz0), (hx1, hz0), (hx1, hz1), (hx0 + R(30), hz1), (hx0, hz1 - R(30))], R(10.0)), hy0 - 1, hy1 + 1)
        head = head ^ nose
        e = 1.4 * k
        head = head - g.extrude_x(g.rrect(hy0 + e, hz0 + e, hy1 - e, hz1 - e, R(22.0)), hx1 - 0.5 * k, hx1 + 1.0)
        arm = g.extrude_y(g.rrect(xm - R(28.0), zm - R(32.0), xm + R(40.0), zm + R(30.0), R(14.0)), ym - 3.0 * k, hy0 + 2.0 * k)
        mirror = (head + arm) - B.grown(0.05)
        mirror = mirror + g.cyl((xm, ym - P.wall - 1.6 * k, zm), (xm, ym + 3.0 * k, zm), self.r_peg())
        self.add("mirror_R", mirror, "black", note="peg into the door; glue", down=(1, 0, 0))
        self.add("mirror_L", mirror.mirror([0, 1, 0]), "black", down=(1, 0, 0))

    # ------------------------------------------------------------------ wheels
    def tire(self, od, width, bore_d):
        """Tyre with a simple all-terrain tread; axis along Z, centred."""
        ro, hw = od / 2, width / 2
        sec = g.rrect(bore_d / 2, -hw, ro, hw, min(0.2 * width, 0.18 * od))
        sec = unary_union([sec, sg.box(bore_d / 2, -hw + 0.04 * width, bore_d / 2 + 0.1 * width, hw - 0.04 * width)])
        t = Manifold.revolve(g.cs(sec), 96)
        gd = max(0.6, 0.012 * od)
        cuts = []
        for a in (-0.22 * width, 0.0, 0.22 * width):
            cuts.append(Manifold.revolve(g.cs(sg.box(ro - gd, a - 0.055 * width, ro + 1.0, a + 0.055 * width)), 96))
        n = 30
        for i in range(n):
            ang = 360.0 * i / n
            cuts.append(g.box(ro - gd, -0.03 * od, 0.30 * width, ro + 1.0, 0.03 * od, hw + 1.0).rotate([0, 0, ang]))
            cuts.append(g.box(ro - gd, -0.03 * od, -hw - 1.0, ro + 1.0, 0.03 * od, -0.30 * width).rotate([0, 0, ang + 180.0 / n]))
        return t - g.union(cuts)

    def steel_wheel(self, bead_d, width, face_offset, spigot_r=0.0):
        """Y61 16 inch steel wheel: 6 studs, ring of round vents. Axis Z, face at +Z."""
        P, R, k = self.P, self.P.R, self.k
        q = bead_d / R(406.4)  # wheel details follow the rim size
        rb = bead_d / 2 - P.fit
        hw = width / 2
        zf = hw - face_offset  # disc plane
        wb, wd = max(1.2, 1.8 * k), max(1.4, 2.2 * k)
        sec = unary_union([
            sg.box(rb - wb, -hw, rb, hw),  # barrel
            sg.box(rb - wb, hw - max(1.0, 1.4 * k), rb + max(1.2, 2.0 * k), hw),  # outer rim flange
            sg.box(0.0, zf - wd, rb - 0.5 * wb, zf),  # disc
            sg.Polygon([(0, zf), (q * R(118.0), zf), (q * R(96.0), zf + q * R(26.0)), (0, zf + q * R(26.0))]),  # hub pressing
            sg.Polygon([(rb - wb, zf - wd), (rb - wb, zf + q * R(34.0)), (rb - wb - q * R(30.0), zf)]),  # dish blend
        ])
        w = Manifold.revolve(g.cs(sec), 96)
        cuts, adds = [], []
        for i in range(10):  # vent holes
            a = 2 * np.pi * (i + 0.5) / 10
            c = (q * R(150.0) * np.cos(a), q * R(150.0) * np.sin(a))
            cuts.append(g.cyl((c[0], c[1], zf - wd - 2.0), (c[0], c[1], zf + 6.0), q * R(21.0)))
        for i in range(6):  # wheel nuts
            a = 2 * np.pi * i / 6
            c = (q * R(69.85) * np.cos(a), q * R(69.85) * np.sin(a))
            adds.append(Manifold.cylinder(q * R(26.0) + 0.6 * k, q * R(15.0), q * R(12.0), 6).translate([c[0], c[1], zf + q * R(26.0) - 0.3 * k]))
        w = w + g.union(adds)
        if spigot_r > 0:  # spare: located on the carrier spigot
            cuts.append(g.cyl((0, 0, zf - wd - 4.0), (0, 0, hw + 6.0), spigot_r + 0.12))
        return w - g.union(cuts)

    def build_spare(self):
        P, B, R, Ry, k = self.P, self.B, self.P.R, self.P.Ry, self.k
        od, wd, bead = R(REAL_TIRE_OD), R(REAL_TIRE_WIDTH), R(406.4)
        ys, zs = self.spare_center()
        gap = R(30.0)
        xs = float(B.tail_x(zs + R(135.0)))  # door skin at the top of the carrier plate
        xcen = float(B.tail_x(zs - 0.35 * od)) + gap + wd / 2
        to_car = lambda m: m.rotate([0, 90, 0]).translate([xcen, ys, zs])  # wheel face (+Z) -> rearward (+X)
        rs = max(1.9, 2.95 * k)
        ww = wd - 2.0 * k
        self.add("spare_tire", to_car(self.tire(od, wd, bead)), "tire", note="solid ring: 5-10 % infill, or TPU", down=(-1, 0, 0))
        self.add("spare_wheel", to_car(self.steel_wheel(bead, ww, R(50.0), spigot_r=rs)), "silver", note="press / glue into the tyre", down=(1, 0, 0))
        # carrier: plate on the door, post through the wheel, spigot in the wheel centre
        zf = ww / 2 - R(50.0)
        x_disc = xcen + zf - max(1.4, 2.2 * k)
        pt = max(1.6, 2.4 * k)
        xb = float(B.tail_x(zs - R(135.0)))  # door skin at the bottom of the plate (furthest back)
        plate = g.extrude_x(g.rrect(ys - R(75.0), zs - R(135.0), ys + R(75.0), zs + R(135.0), R(30.0)), xs - 1.0, xb + pt)
        post = g.cyl((xs - 1.0, ys, zs), (x_disc, ys, zs), R(62.0))
        web = g.extrude_x(g.rrect(ys - 0.8 - 0.8 * k, zs - R(125.0), ys + 0.8 + 0.8 * k, zs + R(125.0), 0.6), xs - 1.0, xcen - wd / 2 - 0.4)
        spig = g.cyl((x_disc - 1.0, ys, zs), (xcen + zf + R(30.0), ys, zs), rs)
        car = (plate + post + web + spig) - B.grown(0.05)  # seat it on the leaning door skin
        for dz in (-R(85.0), R(85.0)):
            xt = float(B.tail_x(zs + dz))
            car = car - g.cyl((xt - 1.0, ys, zs + dz), (xt + 7.0 * k, ys, zs + dz), P.r_pilot)
        self.add("spare_carrier", car, "black", note="two screws from inside the tailgate; wheel glues onto the spigot", down=(-1, 0, 0))

    def build_crossbars(self):
        for which in ("front", "rear"):
            bar, half = self.crossbar(which)
            self.add(f"body_mount_crossbar_{which}", bar, "grey",
                     note=f"{2 * half:.1f} mm long; screws up into the fender rails, body posts through the holes")

    def preview_wheels(self):
        """Chassis wheels for renders only (the RC chassis supplies the real ones)."""
        P = self.P
        bead = 0.47 * P.tire_od
        tire = self.tire(P.tire_od, P.tire_width, bead)
        wheel = self.steel_wheel(bead, P.tire_width - 3.0 * self.k, face_offset=0.22 * P.tire_width)
        y_out = self.W + P.Ry(58.0) - 0.4  # tyre sidewall just inside the flare face
        out = []
        for xc in (self.xc_f, self.xc_r):
            for sgn in (-1, 1):
                rot = [-90, 0, 0] if sgn > 0 else [90, 0, 0]  # wheel face (+Z) outward
                pos = [xc, sgn * (y_out - P.tire_width / 2), P.z_axle]
                out.append((tire.rotate(rot).translate(pos), "tire"))
                out.append((wheel.rotate(rot).translate(pos), "silver"))
        return out

    # ------------------------------------------------------------------ everything
    def build(self):
        self.build_shell()
        self.build_flares()
        self.build_bumpers()
        self.build_side_steps()
        self.build_mirrors()
        self.build_spare()
        self.build_crossbars()
        for name in list(self.parts):  # glazing must clear the seam ribs that cross the pillars
            if name.startswith("glass_"):
                p = self.parts[name]
                p["solid"], _ = g.keep_main(p["solid"] - self.flange_clear)
        return self

    FUSE = ("grille", "headlight_", "taillight_", "tailgate_garnish", "flare_", "bumper_", "side_step_")

    def complete_body(self) -> Manifold:
        """Fused builds only: shell + bumpers + flares + steps + lamps + grille as one solid."""
        assert self.fused
        solids = [self.shell] + [p["solid"] for n, p in self.parts.items() if n.startswith(self.FUSE)]
        body, dropped = g.keep_main(g.union(solids))
        if dropped:
            self.notes.append(f"complete body: {dropped} part(s) did not fuse with the shell")
        return body

    def split(self, solid: Manifold):
        """Cut a body at the print seams; returns [(label, piece), ...] front to rear."""
        labels = ["front", "rear"] if len(self.seams) == 1 else ["1_front", "2_front_doors", "3_rear_doors", "4_rear"]
        rest, out = solid, []
        for xc in self.seams:
            rest, piece = rest.split_by_plane([1.0, 0.0, 0.0], xc)
            out.append(piece)
        out.append(rest)
        return list(zip(labels, out))
