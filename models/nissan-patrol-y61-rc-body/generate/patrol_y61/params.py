"""Design parameters.

All vehicle dimensions in the generator are written as full-size Nissan Patrol
Y61 (GU) long-wheelbase wagon measurements in millimetres and converted to
model millimetres with ``Params.R``. The model scale follows the RC chassis
wheelbase, so the wheel arches always land on the axles.
"""

from __future__ import annotations

from dataclasses import dataclass

REAL_WHEELBASE = 2970.0  # mm, Y61 5-door wagon
REAL_TIRE_OD = 777.0  # 265/70R16
REAL_TIRE_WIDTH = 265.0


@dataclass
class Params:
    # --- RC chassis fitment -------------------------------------------------
    wheelbase: float = 165.0  # chassis wheelbase (mm); 165 mm = true 1:18
    tire_od: float = 57.0  # largest tyre the arches are cut for (mm)
    tire_width: float = 22.0  # only used for the preview render
    lift: float = 4.0  # body lift above scale ride height (mm)
    width_scale: float = 1.0  # lateral stretch for wide axles (1.0 = true scale)
    arch_clear_side: float = 3.0  # tyre-to-arch gap fore/aft (mm)
    arch_clear_top: float = 4.0  # tyre-to-arch gap above the tyre at ride height (mm)

    # --- shell --------------------------------------------------------------
    wall: float = 1.2  # body wall thickness (mm)
    groove_w: float = 0.4  # engraved panel line width (mm)
    groove_d: float = 0.3  # engraved panel line depth (mm)
    pocket_d: float = 0.6  # lamp / grille pocket depth (mm)
    glass_flange: float = 0.8  # thickness of the glazing glue flange (mm)
    fit: float = 0.15  # clearance per side between mating printed parts (mm)

    # --- body mounting ------------------------------------------------------
    post_d: float = 4.0  # RC body post diameter (mm)
    post_spacing_front: float | None = None  # exact post spacing; None = universal hole pattern
    post_spacing_rear: float | None = None
    rail_depth: float = 7.0  # mounting rail reach from the inner wall (mm)
    rail_height: float = 4.0  # mounting rail thickness (mm)
    screw: float = 2.0  # assembly screw size (M2 or M3)
    frame_notch_width: float = 46.0  # clearance slot for the chassis frame in nose/tail panels (0 = none)
    frame_notch_top: float = 700.0  # top of that slot, full-size mm above scale ground

    # --- print splitting ----------------------------------------------------
    flange_depth: float = 4.0  # joint flange reach inside the shell (mm)
    flange_t: float = 1.6  # joint flange thickness each side of a seam (mm)

    @classmethod
    def for_scale(cls, denominator: float, **overrides) -> "Params":
        """Sensible defaults for a scale class (1:18 mini crawlers or 1:10 trail trucks)."""
        base: dict = dict(wheelbase=REAL_WHEELBASE / denominator)
        if denominator < 14:  # 1:10 class - 1.9 in tyres, 6 mm posts, M3 hardware
            base.update(
                tire_od=100.0, tire_width=38.0, lift=6.0, arch_clear_side=4.0, arch_clear_top=6.0,
                wall=2.0, groove_w=0.5, groove_d=0.4, pocket_d=1.0, glass_flange=1.2,
                post_d=6.0, rail_depth=11.0, rail_height=6.0, screw=3.0, frame_notch_width=84.0,
                flange_depth=6.0, flange_t=2.4,
            )
            if abs(denominator - 10.0) < 0.6:
                base["wheelbase"] = 313.0  # the de-facto 1:10 trail chassis wheelbase
        base.update({k: v for k, v in overrides.items() if v is not None})
        return cls(**base)

    @property
    def s(self) -> float:
        return self.wheelbase / REAL_WHEELBASE

    @property
    def k(self) -> float:
        """Detail factor for printed features: 1.0 for 1:10 class, 0.6 for 1:18 and smaller."""
        return float(min(1.0, max(0.6, self.s / 0.1054)))

    def R(self, v):
        """Full-size mm -> model mm (longitudinal / vertical)."""
        return v * self.s

    def Ry(self, v):
        """Full-size mm -> model mm (lateral)."""
        return v * self.s * self.width_scale

    @property
    def scale_label(self) -> str:
        return f"1:{1 / self.s:.2f}".rstrip("0").rstrip(".")

    @property
    def z_axle(self) -> float:
        """Axle centre height in body coordinates (z = 0 is scale ground)."""
        return self.tire_od / 2 - self.lift

    @property
    def r_clear(self) -> float:
        """Clearance hole radius for the assembly screws."""
        return self.screw / 2 + 0.15

    @property
    def r_pilot(self) -> float:
        """Self-tapping pilot hole radius for the assembly screws."""
        return self.screw * 0.42
