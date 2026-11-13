"""Body surface of the Nissan Patrol Y61 (GU) 5-door wagon.

The outer skin is the union of two lofted solids:

* the *lower body* - lofted front to rear through cross-sections that carry
  the plan taper, barrel-shaped flanks, fender/bonnet shoulder, bonnet crown
  and the rounded nose and tail, and
* the *greenhouse* - lofted bottom to top through plan outlines that carry the
  windscreen rake and bow, tumblehome, tailgate lean, pillar radii and the
  roof edge radius, then warped to the roofline and roof crown.

Coordinates: X rearward (0 = front axle), Y to the car's right, Z up
(0 = ground at scale ride height). Dimensions are full-size millimetres run
through ``Params.R`` / ``Params.Ry``.
"""

from __future__ import annotations

import numpy as np
from scipy.interpolate import PchipInterpolator as Pchip

from .geom import fillet, flipped_faces, loft, offset_mesh, smoothstep, to_manifold
from .params import Params

# tessellation
NS, NF, NT = 22, 7, 20  # lower body: side / shoulder fillet / top samples per half
G_FRONT, G_SIDE, G_REAR, G_CORNER = 25, 72, 21, 8  # greenhouse outline samples


class Body:
    def __init__(self, P: Params):
        self.P = P
        R, Ry = P.R, P.Ry
        self.t = P.wall

        # --- key stations --------------------------------------------------
        self.x_face = R(-780.0)  # grille plane (centreline)
        self.x_rear = R(3800.0)  # tailgate skin below the belt
        self.x_cowl = R(520.0)  # windscreen base at the centreline
        self.z_belt = R(1270.0)
        self.z_sill = R(495.0)
        self.z_floor = R(300.0)  # construction floor, trimmed away later
        self.z_top0 = R(1800.0)  # roof edge height before the roofline warp

        # --- lower body ----------------------------------------------------
        self.r_nose = R(170.0)
        self.r_tail = R(125.0)
        self.r_min = self.t + P.glass_flange + 0.4  # smallest convex radius that survives every inward offset
        self.r_hood = max(R(36.0), self.r_min)
        self.r_end = self.r_min  # tail top / floor edge radius
        self.k_low = Ry(30.0)  # flank tuck-under at the sill
        self.k_up = Ry(18.0)  # flank tuck-in at the belt
        self.z_mid = R(900.0)  # widest point of the flank
        self.ledge = Ry(22.0)  # belt shoulder between door skin and glass
        self.nose_bow = R(30.0)
        self.nose_lean = np.tan(np.radians(3.0))
        self._zsh = Pchip(
            R(np.array([-900.0, -780, -600, 0, 400, 600, 700, 4300])),
            R(np.array([1110.0, 1120, 1136, 1190, 1247, 1270, 1270, 1270])),
        )
        self._wpl = Pchip(
            R(np.array([-900.0, -780, -400, 0, 600, 3000, 3400, 3800, 4300])),
            Ry(np.array([855.0, 862, 888, 903, 920, 920, 915, 898, 875])),
        )
        self._crown = Pchip(
            R(np.array([-900.0, -780, 0, 450, 600, 700, 4300])),
            R(np.array([30.0, 30, 34, 28, 15, 0, 0])),
        )
        self._ycr = Pchip(R(np.array([-900.0, -780, 520, 4300])), Ry(np.array([410.0, 420, 640, 640])))
        self.bulge_h = R(10.0)
        self.bulge_blend = Ry(70.0)

        # --- greenhouse ----------------------------------------------------
        self.tau = np.radians(14.0)  # tumblehome
        self.lean_f = np.radians(90.0 - 47.0)  # windscreen, from vertical
        self.lean_r = np.radians(14.0)  # tailgate glass, from vertical
        self.rs, self.rf, self.rr = (max(R(v), self.r_min + 1.0) for v in (70.0, 80.0, 60.0))  # roof edge radii
        self.rc_f, self.rc_r = R(95.0), R(100.0)  # A / D pillar plan radii
        self.bow_f = R(80.0)  # windscreen plan bow
        self.gh_inset_rear = 0.5 * P.k
        self.gh_embed = max(4.0 * self.t + 2.0, 12.0 * P.k)
        self._roof = Pchip(
            R(np.array([-900.0, 900, 1050, 1500, 2000, 3000, 3700, 4300])),
            R(np.array([1762.0, 1762, 1770, 1812, 1826, 1826, 1812, 1806])),
        )
        self.roof_crown = R(30.0)
        self.roof_halfw = Ry(700.0)

        self.step = 3.0 * max(P.k, 0.55)  # loft station pitch
        self._meshes = None
        self._cache = {}
        self.folds = {}  # offset -> number of faces turned inside-out (should be 0)

    # ------------------------------------------------------------------
    # analytic surface description
    # ------------------------------------------------------------------
    def zsh(self, x):
        """Fender top / belt line height (the bonnet shoulder)."""
        return self._zsh(x)

    def w_plan(self, x):
        return self._wpl(x)

    def w_eff(self, x):
        """Plan half-width including the rounded nose and tail corners."""
        x = np.asarray(x, float)
        w = self._wpl(x)
        u = np.clip((x - self.x_face) / self.r_nose, 0.0, 1.0)
        w = w - self.r_nose * (1 - np.sqrt(np.clip(1 - (1 - u) ** 2, 0, 1)))
        u = np.clip((self.x_rear - x) / self.r_tail, 0.0, 1.0)
        w = w - self.r_tail * (1 - np.sqrt(np.clip(1 - (1 - u) ** 2, 0, 1)))
        return w

    def barrel(self, z):
        z = np.asarray(z, float)
        lo = self.k_low * (np.clip((self.z_mid - z) / (self.z_mid - self.z_sill), 0, 1.25)) ** 2
        up = self.k_up * (np.clip((z - self.z_mid) / (self.z_belt - self.z_mid), 0, 1.0)) ** 2
        return lo + up

    def dbarrel(self, z):
        if z < self.z_mid:
            return -2 * self.k_low * (self.z_mid - z) / (self.z_mid - self.z_sill) ** 2
        return 2 * self.k_up * (z - self.z_mid) / (self.z_belt - self.z_mid) ** 2

    def side_y(self, x, z):
        """Half-width of the lower body flank at (x, z) - used to seat add-on parts."""
        return self.w_eff(x) - self.barrel(z)

    def face_x(self, y, z):
        """X of the (bowed, leaning) grille face at lateral position y, height z."""
        wref = self._wpl(self.x_face)
        return self.x_face + self.nose_bow * (y / wref) ** 2 + self.nose_lean * np.clip(z - self.P.R(880.0), 0, None)

    def zsh_eff(self, x):
        return self._zsh(x) - self._end_round(x)

    def r_shoulder(self, x):
        a = max(self.P.R(40.0), self.r_min)
        b = self.r_min
        return a + (b - a) * smoothstep((x - self.P.R(450.0)) / self.P.R(200.0))

    def bulge(self, x, y):
        h = self.bulge_h * (1 - smoothstep((x - self.P.R(380.0)) / self.P.R(140.0)))
        return h * smoothstep((self._ycr(x) + self.bulge_blend / 2 - np.abs(y)) / self.bulge_blend)

    def roof_f(self, x):
        """Vertical scale factor of the greenhouse at x (roofline warp)."""
        return (self._roof(x) - self.z_belt) / (self.z_top0 - self.z_belt)

    def gz(self, z_pre, x):
        """Map a design height (straight 1800 mm roof edge) to the warped roofline."""
        z_pre = np.asarray(z_pre, float)
        return np.where(z_pre > self.z_belt, self.z_belt + (z_pre - self.z_belt) * self.roof_f(x), z_pre)

    def gh_halfw(self, x, z_pre):
        """Greenhouse flank half-width at design height z_pre (straight wall zone)."""
        return self._wpl(x) - self.k_up - self.ledge - (z_pre - self.z_belt) * np.tan(self.tau)

    def ws_x(self, z_pre, y=0.0):
        """Windscreen surface X at design height z_pre and lateral position y."""
        wF = self._wpl(self.x_cowl + self.bow_f) - self.k_up - self.ledge
        return self.x_cowl + (z_pre - self.z_belt) * np.tan(self.lean_f) + self.bow_f * (y / wF) ** 2

    def rear_x(self, z_pre):
        """Tailgate glass X at design height z_pre."""
        return self.x_rear - self.gh_inset_rear - (z_pre - self.z_belt) * np.tan(self.lean_r)

    # ------------------------------------------------------------------
    # lower body
    # ------------------------------------------------------------------
    def _stations(self):
        """Loft stations: even arc steps round the nose / tail edge radii, then
        spacing that grows smoothly to 3 mm.

        Neighbouring facets on every rounded edge stay similar in length, so
        none of them collapses and folds when the wall offset shrinks them.
        """
        def lead(r):
            phi = np.linspace(0, np.pi / 2, 13)[1:]
            xs = list(r * (1 - np.cos(phi)))
            dx = xs[-1] - xs[-2]
            while dx * 1.3 < self.step:
                dx *= 1.3
                xs.append(xs[-1] + dx)
            return np.array(xs)

        a = self.x_face + lead(self.r_hood)
        b = self.x_rear - lead(self.r_end)[::-1]
        n = max(2, int(round((b[0] - a[-1]) / self.step)))
        mid = np.linspace(a[-1], b[0], n + 1)[1:-1]
        return np.concatenate([[self.x_face], a, mid, b, [self.x_rear]])

    def _end_round(self, x):
        """Quarter-round drop applied to the roof-side and floor edges at nose and tail."""
        def q(u, r):
            u = np.clip(u / r, 0.0, 1.0)
            return r * (1 - np.sqrt(np.clip(1 - (1 - u) ** 2, 0, 1)))

        return q(x - self.x_face, self.r_hood) + q(self.x_rear - x, self.r_end)

    def _lower_half(self, x):
        w = float(self.w_eff(x))
        zsh = float(self.zsh_eff(x))
        zf = self.z_floor + float(self._end_round(x))
        r = float(self.r_shoulder(x))
        yc = w - float(self.barrel(zsh))
        cr = float(self._crown(x))
        arc, _ = fillet((yc, zsh), (-self.dbarrel(zsh), 1.0), (-1.0, 2 * cr / yc), r, NF)
        T1, T2 = arc[0], arc[-1]
        zs = np.linspace(zf, T1[1], NS)
        ys = w - self.barrel(zs)
        ys[-1] = T1[0]
        yt = T2[0] * (1 - np.linspace(0, 1, NT + 1)[1:])
        zt = zsh + cr * (1 - (yt / yc) ** 2) + self.bulge(x, yt)
        zt += (T2[1] - (zsh + cr * (1 - (T2[0] / yc) ** 2))) * (yt / T2[0]) ** 4
        half = np.concatenate([[[0.0, zf]], np.stack([ys, zs], -1), arc[1:], np.stack([yt, zt], -1)])
        return half

    def _lower_mesh(self):
        xs = self._stations()
        rings = []
        for x in xs:
            h = self._lower_half(x)
            left = h[1:-1][::-1] * np.array([-1.0, 1.0])
            yz = np.concatenate([h, left])
            rings.append(np.column_stack([np.full(len(yz), x), yz]))
        first = rings[0]
        c = first.mean(0)
        pre = [c + (first - c) * k for k in (0.2, 0.4, 0.6, 0.8)]
        rings = np.stack(pre + rings)
        nh = 1 + NS + (NF - 1) + NT
        bottom = np.zeros(rings.shape[1], bool)
        bottom[[0, 1]] = True
        bottom[rings.shape[1] - 1] = True  # mirrored bottom corner
        # nose shaping: slight plan bow and rearward lean of the grille face
        x = rings[..., 0]
        y = rings[..., 1]
        z = rings[..., 2]
        fade = 1 - smoothstep((x - self.x_face) / self.P.R(150.0))
        wref = self._wpl(self.x_face)
        rings[..., 0] = x + fade * (self.nose_bow * (y / wref) ** 2 + self.nose_lean * np.clip(z - self.P.R(880.0), 0, None))
        V, F = loft(rings, (1, 2))
        bottom_idx = np.nonzero(np.tile(bottom, len(xs)))[0] + 4 * rings.shape[1]
        assert nh * 2 - 2 == rings.shape[1]
        return V, F, bottom_idx

    # ------------------------------------------------------------------
    # greenhouse
    # ------------------------------------------------------------------
    @staticmethod
    def _lean_arc(z, z0, z_top, lam, r):
        zw = z_top - r * (1 - np.sin(lam))
        if z <= z0:
            return 0.0
        if z <= zw:
            return (z - z0) * np.tan(lam)
        sphi = min(np.sin(lam) + (z - zw) / r, 1.0)
        return (zw - z0) * np.tan(lam) + r * (np.cos(lam) - np.sqrt(max(1 - sphi * sphi, 0.0)))

    def _gh_level(self, z):
        zb, zt = self.z_belt, self.z_top0
        # the part buried in the lower body tapers inward so it can never
        # graze the lower body's skin
        e = 1.2 * self.P.k * np.clip((zb - z) / self.gh_embed, 0.0, 1.0)
        dW = self._lean_arc(z, zb, zt, self.tau, self.rs) + e
        xf = self.x_cowl + self._lean_arc(z, zb, zt, self.lean_f, self.rf) + e
        xr = self.x_rear - self.gh_inset_rear - self._lean_arc(z, zb, zt, self.lean_r, self.rr) - e
        return xf, xr, dW

    def _gh_outline(self, xf, xr, dW):
        inset = self.k_up + self.ledge + dW

        def wl(x):
            return self._wpl(x) - inset

        def dwl(x):
            return float(self._wpl.derivative()(x))

        bow = self.bow_f
        xF = xf + bow
        wF, wR = float(wl(xF)), float(wl(xr))
        kf = 2 * bow / wF
        aFL, _ = fillet((xF, -wF), (kf, -1.0), (1.0, -dwl(xF)), self.rc_f, G_CORNER)
        aRL, _ = fillet((xr, -wR), (1.0, -dwl(xr)), (0.0, 1.0), self.rc_r, G_CORNER)
        xs = np.linspace(aFL[-1][0], aRL[0][0], G_SIDE + 2)[1:-1]
        left = np.stack([xs, -wl(xs)], -1)
        ysr = np.linspace(aRL[-1][1], -aRL[-1][1], G_REAR + 2)[1:-1]
        rear = np.stack([np.full_like(ysr, xr), ysr], -1)
        mir = np.array([1.0, -1.0])
        aRR = aRL[::-1] * mir
        right = left[::-1] * mir
        aFR = aFL[::-1] * mir
        ysf = np.linspace(aFR[-1][1], -aFR[-1][1], G_FRONT + 2)[1:-1]
        front = np.stack([xf + bow * (ysf / wF) ** 2, ysf], -1)
        return np.concatenate([aFL, left, aRL, rear, aRR, right, aFR, front])

    def gh_levels(self):
        """Loft levels: even steps up the walls, then even arc steps round the roof edge."""
        zb, zt = self.z_belt, self.z_top0
        zw = zt - self.rs * (1 - np.sin(self.tau))
        phi = np.linspace(self.tau, np.pi / 2, 11)
        arc = zw + self.rs * (np.sin(phi) - np.sin(self.tau))
        zs = np.concatenate([[zb - self.gh_embed], np.linspace(zb, zw, 7)[:-1], arc])
        zs[-1] = zt
        return zs

    def warp_gh(self, V):
        V = V.copy()
        x, y, z = V[:, 0], V[:, 1], V[:, 2]
        zw = self.z_top0 - self.rs * (1 - np.sin(self.tau))
        g = smoothstep((z - zw) / (self.z_top0 - zw))
        znew = np.where(z > self.z_belt, self.z_belt + (z - self.z_belt) * self.roof_f(x), z)
        znew = znew + self.roof_crown * np.clip(1 - (y / self.roof_halfw) ** 2, 0, None) * g
        V[:, 2] = znew
        return V

    def _gh_mesh(self):
        rings = []
        for z in self.gh_levels():
            xf, xr, dW = self._gh_level(z)
            o = self._gh_outline(xf, xr, dW)
            rings.append(np.column_stack([o, np.full(len(o), z)]))
        top = rings[-1]
        c = np.array([(top[:, 0].min() + top[:, 0].max()) / 2, 0.0, 0.0])
        for k in (0.86, 0.72, 0.58, 0.44, 0.30, 0.16):
            ring = top.copy()
            ring[:, :2] = c[:2] + (top[:, :2] - c[:2]) * k
            rings.append(ring)
        V, F = loft(np.stack(rings), (0, 1))
        return self.warp_gh(V), F

    # ------------------------------------------------------------------
    # solids
    # ------------------------------------------------------------------
    def meshes(self):
        if self._meshes is None:
            Vl, Fl, bottom = self._lower_mesh()
            Vg, Fg = self._gh_mesh()
            self._meshes = (Vl, Fl, bottom, Vg, Fg)
        return self._meshes

    def lower(self):
        Vl, Fl, _, _, _ = self.meshes()
        return to_manifold(Vl, Fl)

    def greenhouse(self):
        _, _, _, Vg, Fg = self.meshes()
        return to_manifold(Vg, Fg)

    def solid(self, delta=0.0, open_bottom=False):
        """The body skin offset by ``delta`` (negative = inward) as a solid.

        ``open_bottom`` pushes the floor of the offset solid below the outer
        floor so subtracting it leaves the shell open underneath.
        """
        key = (round(delta, 4), open_bottom)
        if key not in self._cache:
            Vl, Fl, bottom, Vg, Fg = self.meshes()
            if delta != 0.0:
                Vl2 = offset_mesh(Vl, Fl, delta)
                Vg2 = offset_mesh(Vg, Fg, delta)
                self.folds[key] = len(flipped_faces(Vl, Vl2, Fl)) + len(flipped_faces(Vg, Vg2, Fg))
                if delta < 0:
                    # the rings packed against the flat nose / tail caps would
                    # fold over the offset cap; pin them to the offset planes
                    Vl2[:, 0] = np.minimum(Vl2[:, 0], self.x_rear + delta)
                    Vl2[:, 0] = np.maximum(Vl2[:, 0], self.face_x(Vl2[:, 1], Vl2[:, 2]) - delta)
            else:
                Vl2, Vg2 = Vl.copy(), Vg
            if open_bottom:
                Vl2[bottom, 2] = self.z_floor - 10.0
            self._cache[key] = to_manifold(Vl2, Fl) + to_manifold(Vg2, Fg)
        return self._cache[key]

    def outer(self):
        return self.solid(0.0)

    def inner(self):
        return self.solid(-self.t, open_bottom=True)

    def core(self, depth):
        """Body skin moved inward by ``depth`` (for grooves, pockets, inserts)."""
        return self.solid(-depth)

    def grown(self, d):
        return self.solid(d)
