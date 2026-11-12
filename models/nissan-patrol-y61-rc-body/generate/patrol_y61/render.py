"""Small ray-cast renderer used for previews and for checking the model."""

from __future__ import annotations

import numpy as np
import trimesh
from PIL import Image

from .geom import mesh_arrays

COLORS = {
    "white": (238, 238, 236),
    "black": (38, 38, 40),
    "silver": (176, 180, 186),
    "red": (176, 30, 34),
    "clear": (150, 176, 190),
    "lens": (200, 214, 226),
    "tire": (30, 30, 32),
    "grey": (120, 124, 130),
    "orange": (230, 140, 40),
}


class Scene:
    def __init__(self):
        self.V = []
        self.F = []
        self.C = []
        self.n = 0

    def add(self, man, color="white"):
        if man is None or man.is_empty():
            return self
        V, F = mesh_arrays(man)
        self.V.append(V)
        self.F.append(F + self.n)
        col = np.array(COLORS[color] if isinstance(color, str) else color, float)
        self.C.append(np.tile(col, (len(F), 1)))
        self.n += len(V)
        return self

    def build(self):
        V = np.concatenate(self.V)
        F = np.concatenate(self.F)
        self.mesh = trimesh.Trimesh(V, F, process=False)
        self.col = np.concatenate(self.C)
        self.inter = trimesh.ray.ray_pyembree.RayMeshIntersector(self.mesh)
        self.fn = self.mesh.face_normals
        return self

    def render(self, eye, target, fov=28.0, size=(1200, 800), ss=2, bg=(92, 95, 102), ground_z=None):
        W, H = size[0] * ss, size[1] * ss
        eye = np.asarray(eye, float)
        target = np.asarray(target, float)
        fwd = target - eye
        fwd /= np.linalg.norm(fwd)
        up = np.array([0, 0, 1.0]) if abs(fwd[2]) < 0.95 else np.array([0, 1.0, 0])
        right = np.cross(fwd, up)
        right /= np.linalg.norm(right)
        upv = np.cross(right, fwd)
        f = 1.0 / np.tan(np.radians(fov) / 2)
        xs = (np.arange(W) + 0.5) / W * 2 - 1
        ys = 1 - (np.arange(H) + 0.5) / H * 2
        gx, gy = np.meshgrid(xs * (W / H), ys)
        dirs = fwd[None, None] * f + right[None, None] * gx[..., None] + upv[None, None] * gy[..., None]
        dirs /= np.linalg.norm(dirs, axis=-1, keepdims=True)
        dirs = dirs.reshape(-1, 3)
        orig = np.tile(eye, (len(dirs), 1))
        tri = self.inter.intersects_first(orig, dirs)
        img = np.tile(np.array(bg, float), (len(dirs), 1))
        hit = tri >= 0
        if ground_z is not None:
            # simple ground plane with a soft contact shadow
            t = (ground_z - eye[2]) / np.where(np.abs(dirs[:, 2]) < 1e-9, -1e-9, dirs[:, 2])
            g = (~hit) & (t > 0) & (dirs[:, 2] < 0)
            gp = orig[g] + dirs[g] * t[g, None]
            sh = self.inter.intersects_any(gp + np.array([0, 0, 0.05]), np.tile(np.array([0.15, 0.1, 1.0]), (len(gp), 1)))
            base = np.array(bg, float) * 1.08
            img[g] = np.where(sh[:, None], base * 0.62, base)
        n = self.fn[tri[hit]]
        d = dirs[hit]
        n = np.where((np.einsum("ij,ij->i", n, d) > 0)[:, None], -n, n)
        key = np.array([-0.45, -0.5, 0.74])
        key /= np.linalg.norm(key)
        fill = np.array([0.6, 0.55, 0.3])
        fill /= np.linalg.norm(fill)
        head = -d
        lam = (
            0.30
            + 0.55 * np.clip(n @ key, 0, 1)
            + 0.18 * np.clip(n @ fill, 0, 1)
            + 0.15 * np.clip(np.einsum("ij,ij->i", n, head), 0, 1)
        )
        img[hit] = self.col[tri[hit]] * np.clip(lam, 0, 1.15)[:, None]
        img = np.clip(img, 0, 255).reshape(H, W, 3).astype(np.uint8)
        im = Image.fromarray(img)
        if ss > 1:
            im = im.resize(size, Image.LANCZOS)
        return im


def contact_sheet(images, cols=2, pad=6, bg=(60, 62, 68)):
    w, h = images[0].size
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad), bg)
    for i, im in enumerate(images):
        sheet.paste(im, (pad + (i % cols) * (w + pad), pad + (i // cols) * (h + pad)))
    return sheet


def standard_views(scene: Scene, center, length, size=(1000, 640), ground_z=None, which=None):
    cx, cy, cz = center
    D = length * 1.75
    views = {
        "front34": ((cx - D * 0.72, cy - D * 0.62, cz + D * 0.18), 26),
        "side": ((cx, cy - D * 1.05, cz + D * 0.02), 26),
        "rear34": ((cx + D * 0.72, cy - D * 0.6, cz + D * 0.2), 26),
        "top": ((cx, cy, cz + D * 1.1), 26),
        "front": ((cx - D * 1.0, cy, cz + D * 0.05), 22),
        "rear": ((cx + D * 1.0, cy, cz + D * 0.05), 22),
        "under": ((cx, cy, cz - D * 1.1), 26),
        "right34": ((cx - D * 0.72, cy + D * 0.62, cz + D * 0.3), 26),
    }
    names = which or ["front34", "side", "rear34", "top"]
    out = []
    for nme in names:
        eye, fov = views[nme]
        out.append(scene.render(eye, center, fov=fov, size=size, ground_z=ground_z))
    return out
