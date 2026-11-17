# Mision Perseo - estaciones del interior de la base para Godot (Blender 4.x / 5.x, en segundo plano).
#
#   blender --background --factory-startup --python tools/blender/stations.py -- <carpeta_salida> [carpeta_previews]
#
# Genera <carpeta_salida>/station_X.glb para O S G W R C B T A D (normalmente art/3d/base/).
# Mismo tamano, posicion y orientacion que los modelos por codigo (station_art.gd / view3d.gd), para que
# las mejoras de nivel y los andamios sigan encajando. Frentes: O, S, W, R miran a +Z; C, A, D, T a -Z;
# B tiene la cabecera en +Z.
#
# Convenciones que lee station_art.gd:
#   nodos  anim_needle_N (aguja, gira en Z) · anim_solar (gira en Y con la hora) · anim_dish (antena, Y)
#          anim_coil (bobina del escudo) · anim_leaf_l / anim_leaf_r (hojas de la esclusa, se deslizan en X)
#          anim_fan (gira en su eje Y) · anim_sway_N (plantas, se mecen) · anim_twist (manivela, gira en Z)
#   materiales  screen_* (pantallas que brillan y reaccionan) · core (nucleo que late) · led_* (pilotos
#          que parpadean) · shield_band (banda que se pone roja con la brecha) · glass · water · solar_cell
# Las piezas fijas que comparten material se fusionan (merge_tree): menos llamadas de dibujo en moviles.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

from bkit import (G, cylinder, ellipsoid, export_glb, lathe, material, merge_tree, node,  # noqa: E402
                  preview_setup, rbox, reset, shot, stats, torus, tube)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.abspath("base")
PREVIEW_DIR = os.path.abspath(argv[1]) if len(argv) > 1 else ""
PI = math.pi


def mats():
    return {
        "grey": material("grey", (0.6, 0.59, 0.56), 0.55, 0.42),
        "greyd": material("greyd", (0.42, 0.42, 0.41), 0.55, 0.45),
        "graph": material("graph", (0.22, 0.22, 0.24), 0.4, 0.55),
        "rust": material("rust", (0.72, 0.42, 0.22), 0.3, 0.6),
        "amber": material("amber", (0.8, 0.58, 0.24), 0.3, 0.55),
        "copper": material("copper", (0.7, 0.44, 0.26), 0.85, 0.32),
        "wood": material("wood", (0.55, 0.38, 0.22), 0.1, 0.65),
        "wood_d": material("wood_d", (0.45, 0.31, 0.18), 0.1, 0.65),
        "beige": material("beige", (0.6, 0.56, 0.49), 0.0, 0.85),
        "beige_d": material("beige_d", (0.52, 0.48, 0.42), 0.0, 0.85),
        "white": material("white", (0.84, 0.83, 0.8), 0.3, 0.45),
        "rubber": material("rubber", (0.12, 0.12, 0.13), 0.1, 0.8),
        "red": material("red", (0.75, 0.22, 0.18), 0.2, 0.5),
        "steel": material("steel", (0.75, 0.77, 0.8), 0.9, 0.25),
        "face": material("face", (0.88, 0.86, 0.8), 0.0, 0.5),
        "screen_blue": material("screen_blue", (0.38, 0.68, 0.8), 0.0, 0.4, 1.0),
        "screen_amber": material("screen_amber", (0.85, 0.55, 0.25), 0.0, 0.4, 1.0),
        "screen_green": material("screen_green", (0.35, 0.8, 0.5), 0.0, 0.4, 1.0),
        "core": material("core", (0.95, 0.72, 0.42), 0.0, 0.4, 1.5),
        "shield_band": material("shield_band", (0.5, 0.36, 0.3), 0.6, 0.35),
        "led_green": material("led_green", (0.35, 0.85, 0.45), 0.0, 0.3, 2.0),
        "led_amber": material("led_amber", (0.9, 0.6, 0.2), 0.0, 0.3, 2.0),
        "led_red": material("led_red", (0.75, 0.22, 0.18), 0.0, 0.3, 2.0),
        "led_blue": material("led_blue", (0.3, 0.75, 1.0), 0.0, 0.3, 2.0),
        "lamp": material("lamp", (1.0, 0.92, 0.72), 0.0, 0.4, 3.0),
        "glass": material("glass", (0.7, 0.92, 0.9), 0.3, 0.05, 0.0, 0.25),
        "water": material("water", (0.18, 0.5, 0.95), 0.1, 0.1, 0.4, 0.8),
        "solar_cell": material("solar_cell", (0.18, 0.24, 0.48), 0.6, 0.25),
        "soil": material("soil", (0.3, 0.2, 0.15), 0.0, 0.95),
        "stem": material("stem", (0.2, 0.5, 0.2), 0.0, 0.6),
        "leaf": material("leaf", (0.28, 0.72, 0.3), 0.0, 0.5),
        "leaf2": material("leaf2", (0.2, 0.6, 0.26), 0.0, 0.5),
        "fruit": material("fruit", (0.9, 0.25, 0.2), 0.0, 0.4),
        "sheet": material("sheet", (0.3, 0.45, 0.8), 0.0, 0.85),
        "mattress": material("mattress", (0.86, 0.88, 0.95), 0.0, 0.9),
        "pillow": material("pillow", (0.95, 0.95, 1.0), 0.0, 0.9),
        "pcb": material("pcb", (0.15, 0.45, 0.25), 0.2, 0.5),
    }


def led(name, parent, gpos, M, kind, facing="z"):
    # piloto: casquillo oscuro + bombilla
    cylinder(name + "_base", parent, gpos, 0.035, 0.02, M["graph"], seg=10, axis="z")
    off = {"z": (0, 0, 0.012), "-z": (0, 0, -0.012)}[facing if facing in ("z", "-z") else "z"]
    p = (gpos[0] + off[0], gpos[1] + off[1], gpos[2] + off[2])
    ellipsoid(name, parent, p, 0.026, 0.026, 0.014, M["led_" + kind], seg=10, rings=6)


def bolts(name, parent, M, pts, r=0.022, axis="z"):
    for i, p in enumerate(pts):
        cylinder("%s_%d" % (name, i), parent, p, r, 0.02, M["steel"], seg=8, axis=axis)


# ---------------- O: soporte vital (dos tanques + consola), frente +Z ----------------
def st_O(M, root):
    rbox("plinth", root, (0, 0.06, 0), (1.9, 0.12, 1.2), M["graph"], round_=0.15, subsurf=0)
    for i, x in enumerate((-0.62, -0.16)):
        lathe("tank_%d" % i, root, (x, 0, -0.15),
              [(0.0, 1.98), (0.09, 1.965), (0.16, 1.92), (0.2, 1.85), (0.212, 1.75), (0.212, 0.3),
               (0.2, 0.2), (0.0, 0.19)], M["white"], seg=24)
        cylinder("tank_band_%d" % i, root, (x, 0.45, -0.15), 0.216, 0.1, M["rust"], seg=24)
        cylinder("tank_band2_%d" % i, root, (x, 1.25, -0.15), 0.216, 0.06, M["graph"], seg=24)
        cylinder("tank_strap_%d" % i, root, (x, 1.55, -0.15), 0.218, 0.04, M["steel"], seg=24)
        cylinder("valve_%d" % i, root, (x, 2.03, -0.15), 0.045, 0.12, M["graph"], seg=10)
        torus("wheel_%d" % i, root, (x, 2.1, -0.15), 0.07, 0.012, M["red"], seg=14, ring=5)
        cylinder("wheel_hub_%d" % i, root, (x, 2.1, -0.15), 0.018, 0.03, M["red"], seg=8)
    # colector: tuberia que une los tanques y baja a la consola
    tube("manifold", root, [(-0.62, 2.0, -0.15), (-0.62, 2.18, -0.15), (-0.4, 2.2, -0.15), (-0.16, 2.2, -0.15),
                            (0.3, 2.2, -0.15), (0.5, 2.1, -0.15), (0.5, 1.6, -0.15), (0.5, 1.3, -0.1)], 0.03, M["greyd"], res=6)
    tube("branch", root, [(-0.16, 2.0, -0.15), (-0.16, 2.2, -0.15)], 0.03, M["greyd"])
    # consola
    rbox("console", root, (0.5, 0.68, 0.0), (0.78, 1.12, 0.62), M["grey"], round_=0.08, subsurf=0)
    rbox("console_top", root, (0.5, 1.26, 0.0), (0.82, 0.06, 0.66), M["graph"], round_=0.4, subsurf=0)
    rbox("console_kick", root, (0.5, 0.06, 0.0), (0.8, 0.12, 0.64), M["graph"], round_=0.2, subsurf=0)
    rbox("bezel", root, (0.5, 1.02, 0.31), (0.56, 0.34, 0.04), M["graph"], round_=0.3, subsurf=0)
    rbox("screen", root, (0.5, 1.02, 0.332), (0.48, 0.26, 0.01), M["screen_blue"], round_=0.0, subsurf=0)
    for i, gx in enumerate((0.36, 0.64)):
        cylinder("gauge_%d" % i, root, (gx, 0.66, 0.32), 0.09, 0.04, M["graph"], seg=18, axis="z")
        cylinder("gauge_face_%d" % i, root, (gx, 0.66, 0.341), 0.072, 0.008, M["face"], seg=18, axis="z")
        nd = node("anim_needle_%d" % i, root, (gx, 0.66, 0.348))
        rbox("needle_%d" % i, nd, (0, 0.028, 0), (0.01, 0.06, 0.005), M["red"], round_=0.0, subsurf=0)
        cylinder("needle_hub_%d" % i, nd, (0, 0, 0.002), 0.012, 0.008, M["graph"], seg=8, axis="z")
    led("led_g", root, (0.3, 0.34, 0.312), M, "green")
    led("led_a", root, (0.42, 0.34, 0.312), M, "amber")
    rbox("button", root, (0.62, 0.34, 0.32), (0.1, 0.06, 0.03), M["red"], round_=0.4, subsurf=0)
    bolts("console_bolt", root, M, [(0.16, 1.16, 0.312), (0.84, 1.16, 0.312), (0.16, 0.2, 0.312), (0.84, 0.2, 0.312)], 0.015)
    tube("hose", root, [(0.89, 0.5, 0.1), (1.05, 0.45, 0.15), (1.02, 0.12, 0.35), (0.8, 0.04, 0.45)], 0.035, M["rubber"])


# ---------------- S: panel solar en pie con bateria, frente +Z ----------------
def st_S(M, root):
    rbox("foot", root, (-0.15, 0.07, 0), (0.8, 0.14, 0.8), M["graph"], round_=0.2, subsurf=0)
    lathe("pillar", root, (-0.15, 0, 0), [(0.0, 1.08), (0.12, 1.08), (0.14, 1.0), (0.17, 0.2), (0.22, 0.14), (0.0, 0.14)],
          M["grey"], seg=16, sharp_deg=40)
    bolts("foot_bolt", root, M, [(-0.47, 0.14, 0.32), (0.17, 0.14, 0.32), (-0.47, 0.14, -0.32), (0.17, 0.14, -0.32)], 0.02, "y")
    mount = node("anim_solar", root, (-0.15, 1.15, 0))
    ellipsoid("pivot", mount, (0, 0, 0), 0.1, 0.1, 0.1, M["graph"])
    cylinder("axle", mount, (0, 0, 0), 0.04, 0.5, M["steel"], seg=10, axis="x")
    tilt = node("tilt", mount, (0, 0, 0), (-0.6, 0, 0))
    rbox("frame", tilt, (0, 0.1, 0), (1.5, 0.06, 1.13), M["white"], round_=0.3, subsurf=0)
    rbox("cells", tilt, (0, 0.135, 0), (1.42, 0.02, 1.05), M["solar_cell"], round_=0.0, subsurf=0)
    for k in range(1, 4):
        rbox("grid_x_%d" % k, tilt, (-0.71 + k * 0.355, 0.147, 0), (0.012, 0.006, 1.05), M["white"], round_=0.0, subsurf=0)
    for k in range(1, 3):
        rbox("grid_z_%d" % k, tilt, (0, 0.147, -0.525 + k * 0.35), (1.42, 0.006, 0.012), M["white"], round_=0.0, subsurf=0)
    rbox("rib", tilt, (0, 0.05, 0), (0.12, 0.06, 1.0), M["greyd"], round_=0.2, subsurf=0)
    # bateria con asa y cable
    rbox("battery", root, (0.6, 0.21, 0.25), (0.5, 0.42, 0.36), M["graph"], round_=0.12, subsurf=0)
    rbox("battery_lid", root, (0.6, 0.445, 0.25), (0.52, 0.05, 0.38), M["grey"], round_=0.3, subsurf=0)
    torus("handle", root, (0.6, 0.5, 0.25), 0.07, 0.012, M["grey"], seg=14, ring=5, axis="z")
    rbox("battery_label", root, (0.6, 0.22, 0.432), (0.3, 0.12, 0.01), M["amber"], round_=0.0, subsurf=0)
    led("led_g", root, (0.76, 0.34, 0.432), M, "green")
    tube("cable", root, [(0.35, 0.3, 0.25), (0.2, 0.08, 0.3), (-0.05, 0.03, 0.35), (-0.15, 0.2, 0.17)], 0.022, M["rubber"])


# ---------------- R: generador del escudo (bobina de cobre), panel en +Z ----------------
def st_R(M, root):
    cylinder("base", root, (0, 0.11, 0), 0.85, 0.22, M["graph"], seg=8, r2=0.95)
    lathe("body", root, (0, 0, 0), [(0.0, 1.3), (0.5, 1.3), (0.56, 1.26), (0.58, 1.18), (0.6, 0.32),
                                   (0.62, 0.24), (0.0, 0.22)], M["grey"], seg=28)
    cylinder("band", root, (0, 0.5, 0), 0.607, 0.12, M["shield_band"], seg=28)
    cylinder("ring_top", root, (0, 1.05, 0), 0.592, 0.06, M["rust"], seg=28)
    for i in range(8):
        a = TAU8 * i
        rbox("fin_%d" % i, root, (math.cos(a) * 0.6, 0.78, math.sin(a) * 0.6), (0.05, 0.4, 0.05), M["greyd"], round_=0.3, subsurf=0)
    coil = node("anim_coil", root, (0, 1.62, 0))
    for k in range(6):
        torus("turn_%d" % k, coil, (0, -0.28 + k * 0.11, 0), 0.43, 0.035, M["copper"], seg=28, ring=6)
    cylinder("core", coil, (0, 0, 0), 0.3, 0.66, M["core"], seg=20)
    cylinder("cap_top", coil, (0, 0.36, 0), 0.48, 0.05, M["graph"], seg=24)
    cylinder("cap_bot", coil, (0, -0.36, 0), 0.48, 0.05, M["graph"], seg=24)
    for i in range(4):
        a = PI / 4 + PI / 2 * i
        cylinder("post_%d" % i, coil, (math.cos(a) * 0.44, 0, math.sin(a) * 0.44), 0.025, 0.72, M["graph"], seg=8)
    for sx in (-1.0, 1.0):
        s = "l" if sx < 0 else "r"
        lathe("tank_" + s, root, (0.72 * sx, 0, -0.28), [(0.0, 1.0), (0.1, 0.98), (0.14, 0.9), (0.14, 0.2), (0.0, 0.18)],
              M["greyd"], seg=16)
        tube("pipe_" + s, root, [(0.72 * sx, 0.95, -0.28), (0.72 * sx, 1.05, -0.28), (0.5 * sx, 1.05, -0.2), (0.45 * sx, 0.9, -0.15)],
             0.028, M["graph"])
    rbox("panel", root, (0, 0.82, 0.6), (0.36, 0.3, 0.05), M["graph"], round_=0.3, subsurf=0)
    rbox("panel_screen", root, (0, 0.88, 0.627), (0.26, 0.1, 0.008), M["screen_amber"], round_=0.0, subsurf=0)
    led("led_g", root, (-0.08, 0.75, 0.625), M, "green")
    led("led_a", root, (0.08, 0.75, 0.625), M, "amber")


TAU8 = math.tau / 8


# ---------------- C: zona de descanso (sofa, mesita, lampara), frente -Z ----------------
def st_C(M, root):
    rbox("frame", root, (0.15, 0.22, 0.05), (1.7, 0.18, 0.85), M["graph"], round_=0.2, subsurf=0)
    for sx in (-0.62, 0.92):
        for sz in (-0.3, 0.38):
            cylinder("leg_%d_%d" % (int(sx * 10), int(sz * 10)), root, (sx, 0.07, sz), 0.035, 0.14, M["steel"], seg=8, r2=0.025)
    for i, x in enumerate((-0.24, 0.54)):
        rbox("seat_%d" % i, root, (x, 0.42, -0.04), (0.78, 0.2, 0.7), M["beige"], round_=0.9, subsurf=1)
        rbox("back_%d" % i, root, (x, 0.76, 0.33), (0.76, 0.5, 0.2), M["beige_d"], round_=0.9, subsurf=1, rot=(0.15, 0, 0))
        rbox("button_%d" % i, root, (x, 0.82, 0.215), (0.04, 0.04, 0.02), M["beige"], round_=0.8, subsurf=0, rot=(0.15, 0, 0))
    for sx in (-0.7, 0.98):
        rbox("arm_%d" % int(sx * 10), root, (sx, 0.52, 0.05), (0.17, 0.44, 0.84), M["beige_d"], round_=0.8, subsurf=1)
    rbox("seam", root, (0.15, 0.31, -0.405), (1.6, 0.025, 0.015), M["rust"], round_=0.0, subsurf=0)
    rbox("throw", root, (0.62, 0.53, -0.05), (0.5, 0.04, 0.6), M["rust"], round_=0.6, subsurf=1)
    # mesita con cajones y taza
    rbox("table", root, (-1.08, 0.3, 0.0), (0.45, 0.6, 0.45), M["wood_d"], round_=0.1, subsurf=0)
    for k in range(2):
        rbox("drawer_%d" % k, root, (-1.08, 0.2 + k * 0.24, -0.228), (0.38, 0.19, 0.012), M["wood"], round_=0.2, subsurf=0)
        rbox("knob_%d" % k, root, (-1.08, 0.2 + k * 0.24, -0.24), (0.08, 0.02, 0.015), M["graph"], round_=0.3, subsurf=0)
    lathe("mug", root, (-1.0, 0.6, 0.05), [(0.0, 0.11), (0.045, 0.11), (0.045, 0.0), (0.0, 0.0)], M["red"], seg=12)
    torus("mug_handle", root, (-0.95, 0.655, 0.05), 0.025, 0.007, M["red"], seg=10, ring=4, axis="z")
    rbox("book", root, (-1.15, 0.615, -0.05), (0.18, 0.03, 0.24), M["sheet"], round_=0.2, subsurf=0)
    # lampara de pie
    cylinder("lamp_base", root, (1.2, 0.02, 0.25), 0.15, 0.04, M["graph"], seg=16, r2=0.13)
    cylinder("lamp_pole", root, (1.2, 0.62, 0.25), 0.018, 1.18, M["steel"], seg=8)
    lathe("lamp_shade", root, (1.2, 0, 0.25), [(0.12, 1.32), (0.09, 1.32), (0.15, 1.12), (0.18, 1.12)], M["face"], seg=18, caps=False)
    ellipsoid("lamp_bulb", root, (1.2, 1.2, 0.25), 0.05, 0.05, 0.05, M["lamp"], seg=10, rings=6)


# ---------------- T: banco de trabajo, frente (cajones) -Z ----------------
def st_T(M, root):
    rbox("top", root, (0, 1.0, 0), (1.9, 0.08, 0.95), M["wood"], round_=0.25, subsurf=0)
    rbox("top_edge", root, (0, 0.945, 0), (1.94, 0.04, 0.99), M["graph"], round_=0.2, subsurf=0)
    for sx in (-0.88, 0.88):
        for sz in (-0.4, 0.4):
            rbox("leg_%d_%d" % (int(sx * 10), int(sz * 10)), root, (sx, 0.47, sz), (0.07, 0.94, 0.07), M["graph"], round_=0.2, subsurf=0)
    rbox("stretcher", root, (0, 0.2, 0.4), (1.75, 0.05, 0.05), M["graph"], round_=0.2, subsurf=0)
    rbox("shelf", root, (0.35, 0.18, 0.0), (1.0, 0.03, 0.8), M["greyd"], round_=0.2, subsurf=0)
    rbox("crate", root, (0.45, 0.3, 0.05), (0.42, 0.2, 0.32), M["amber"], round_=0.15, subsurf=0)
    rbox("cabinet", root, (-0.55, 0.52, 0), (0.62, 0.78, 0.82), M["greyd"], round_=0.06, subsurf=0)
    for k in range(3):
        y = 0.3 + k * 0.24
        rbox("drawer_%d" % k, root, (-0.55, y, -0.418), (0.54, 0.2, 0.015), M["grey"], round_=0.15, subsurf=0)
        rbox("pull_%d" % k, root, (-0.55, y + 0.04, -0.435), (0.2, 0.025, 0.02), M["steel"], round_=0.3, subsurf=0)
    # panel perforado con herramientas
    rbox("pegboard", root, (0, 1.6, 0.45), (1.8, 0.85, 0.05), M["graph"], round_=0.1, subsurf=0)
    for yy in range(4):
        for xx in range(12):
            cylinder("hole_%d_%d" % (yy, xx), root, (-0.8 + xx * 0.145, 1.3 + yy * 0.2, 0.423), 0.012, 0.006, M["rubber"], seg=6, axis="z")
    # llave inglesa, destornilladores, martillo, alicates
    rbox("wrench", root, (-0.7, 1.6, 0.41), (0.04, 0.36, 0.02), M["steel"], round_=0.3, subsurf=0)
    torus("wrench_head", root, (-0.7, 1.8, 0.41), 0.045, 0.014, M["steel"], seg=12, ring=4, axis="z")
    for i, (x, c) in enumerate(((-0.42, "red"), (-0.3, "amber"))):
        cylinder("driver_h_%d" % i, root, (x, 1.75, 0.405), 0.022, 0.12, M[c], seg=8)
        cylinder("driver_s_%d" % i, root, (x, 1.58, 0.405), 0.007, 0.22, M["steel"], seg=6)
    rbox("hammer_handle", root, (0.05, 1.58, 0.41), (0.035, 0.36, 0.025), M["wood_d"], round_=0.3, subsurf=0)
    rbox("hammer_head", root, (0.05, 1.79, 0.41), (0.16, 0.06, 0.04), M["steel"], round_=0.2, subsurf=0)
    for sd in (-1, 1):
        rbox("pliers_%d" % sd, root, (0.38 + 0.025 * sd, 1.6, 0.41), (0.025, 0.3, 0.02), M["red"], round_=0.3, subsurf=0,
             rot=(0, 0.12 * sd, 0))
    rbox("shelf_top", root, (0, 2.05, 0.38), (1.8, 0.03, 0.18), M["wood_d"], round_=0.2, subsurf=0)
    for i, (x, c) in enumerate(((-0.6, "red"), (-0.35, "amber"), (0.5, "white"))):
        lathe("can_%d" % i, root, (x, 2.065, 0.38), [(0.0, 0.16), (0.05, 0.16), (0.05, 0.0), (0.0, 0.0)], M[c], seg=10)
    # tornillo de banco con manivela que gira al fabricar
    rbox("vise_body", root, (0.65, 1.13, -0.28), (0.26, 0.16, 0.24), M["grey"], round_=0.2, subsurf=0)
    rbox("vise_jaw", root, (0.65, 1.15, -0.46), (0.26, 0.14, 0.06), M["grey"], round_=0.2, subsurf=0)
    cylinder("vise_screw", root, (0.65, 1.1, -0.56), 0.018, 0.3, M["steel"], seg=8, axis="z")
    tw = node("anim_twist", root, (0.65, 1.1, -0.72))
    cylinder("vise_bar", tw, (0, 0, 0), 0.014, 0.26, M["steel"], seg=6, axis="x")
    for sd in (-1, 1):
        ellipsoid("vise_knob_%d" % sd, tw, (0.13 * sd, 0, 0), 0.025, 0.025, 0.025, M["red"], seg=8, rings=5)
    # placa de circuito y piezas sobre la mesa
    rbox("pcb", root, (0.05, 1.05, -0.1), (0.3, 0.012, 0.22), M["pcb"], round_=0.0, subsurf=0)
    for i in range(4):
        rbox("chip_%d" % i, root, (-0.03 + (i % 2) * 0.14, 1.062, -0.15 + (i // 2) * 0.1), (0.05, 0.012, 0.04), M["graph"], round_=0.0, subsurf=0)
    # lampara de trabajo articulada
    cylinder("lamp_base", root, (-0.82, 1.06, 0.3), 0.07, 0.03, M["graph"], seg=12)
    tube("lamp_arm", root, [(-0.82, 1.07, 0.3), (-0.82, 1.4, 0.32), (-0.75, 1.55, 0.2), (-0.62, 1.5, 0.08)], 0.014, M["graph"])
    lathe("lamp_head", root, (-0.62, 0, 0.08), [(0.03, 1.55), (0.02, 1.55), (0.08, 1.45), (0.09, 1.45)], M["amber"], seg=14, caps=False)
    ellipsoid("lamp_bulb", root, (-0.62, 1.47, 0.08), 0.04, 0.03, 0.04, M["lamp"], seg=10, rings=6)


# ---------------- A: radio (consola + antena parabolica), frente -Z ----------------
def st_A(M, root):
    rbox("cabinet", root, (0, 0.4, 0.05), (1.2, 0.8, 0.7), M["grey"], round_=0.06, subsurf=0)
    rbox("cabinet_top", root, (0, 0.82, 0.05), (1.24, 0.06, 0.74), M["graph"], round_=0.4, subsurf=0)
    rbox("drawer", root, (0, 0.2, -0.305), (0.9, 0.2, 0.015), M["greyd"], round_=0.15, subsurf=0)
    rbox("pull", root, (0, 0.24, -0.318), (0.2, 0.025, 0.02), M["steel"], round_=0.3, subsurf=0)
    for i in range(6):
        rbox("vent_%d" % i, root, (0.35, 0.48 + i * 0.04, -0.305), (0.3, 0.012, 0.012), M["graph"], round_=0.0, subsurf=0)
    pnl = node("panel", root, (0, 0.98, -0.12), (-0.5, 0, 0))
    rbox("bezel", pnl, (0, 0, 0), (1.0, 0.36, 0.08), M["greyd"], round_=0.2, subsurf=0)
    rbox("screen", pnl, (-0.22, 0.03, -0.045), (0.36, 0.2, 0.01), M["screen_amber"], round_=0.0, subsurf=0)
    for i in range(3):
        cylinder("knob_%d" % i, pnl, (0.1 + i * 0.13, 0.07, -0.055), 0.04, 0.035, M["graph"], seg=12, axis="z")
        rbox("knob_mark_%d" % i, pnl, (0.1 + i * 0.13, 0.095, -0.075), (0.008, 0.025, 0.005), M["face"], round_=0.0, subsurf=0)
    for i, c in enumerate(("red", "leaf", "amber")):
        rbox("key_%d" % i, pnl, (0.1 + i * 0.13, -0.09, -0.05), (0.08, 0.05, 0.03), M[c], round_=0.3, subsurf=0)
    led("led_g", root, (-0.45, 0.68, -0.305), M, "green", "-z")
    led("led_a", root, (-0.32, 0.68, -0.305), M, "amber", "-z")
    # microfono de cuello flexible
    tube("mic_neck", root, [(0.45, 0.86, -0.02), (0.45, 1.05, -0.05), (0.43, 1.18, -0.14), (0.4, 1.22, -0.2)], 0.012, M["graph"])
    ellipsoid("mic", root, (0.4, 1.22, -0.22), 0.035, 0.035, 0.06, M["rubber"], seg=10, rings=6)
    # mastil y antena parabolica que barre
    lathe("mast", root, (-0.35, 0, 0.25), [(0.0, 1.8), (0.045, 1.8), (0.05, 1.2), (0.06, 0.85), (0.0, 0.85)], M["graph"], seg=10)
    hd = node("anim_dish", root, (-0.35, 1.85, 0.25))
    cylinder("yoke", hd, (0, 0, 0), 0.06, 0.08, M["graph"], seg=10)
    tilt = node("dish_tilt", hd, (0, 0.05, 0), (-1.0, 0, 0))
    lathe("dish", tilt, (0, 0, 0), [(0.0, 0.0), (0.16, 0.012), (0.31, 0.05), (0.45, 0.12), (0.47, 0.14),
                                     (0.45, 0.145), (0.3, 0.07), (0.15, 0.032), (0.0, 0.022)], M["white"], seg=24)
    for i in range(3):
        a = math.tau * i / 3
        tube("strut_%d" % i, tilt, [(math.cos(a) * 0.4, 0.12, math.sin(a) * 0.4), (math.cos(a) * 0.2, 0.25, math.sin(a) * 0.2),
                                    (0.0, 0.34, 0.0)], 0.008, M["graph"], res=3)
    ellipsoid("feed", tilt, (0, 0.36, 0), 0.04, 0.05, 0.04, M["red"], seg=10, rings=6)


# ---------------- D: esclusa (marco achaflanado + puerta corredera), frente -Z ----------------
def st_D(M, root):
    for sx in (-1.0, 1.0):
        rbox("jamb_%d" % int(sx), root, (1.0 * sx, 1.55, 0), (0.4, 2.6, 0.8), M["greyd"], round_=0.1, subsurf=0)
    rbox("lintel", root, (0, 3.06, 0), (2.4, 0.42, 0.8), M["greyd"], round_=0.1, subsurf=0)
    rbox("sill", root, (0, 0.15, 0), (2.4, 0.3, 0.8), M["greyd"], round_=0.1, subsurf=0)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            rbox("chamfer_%d_%d" % (int(sx), int(sy)), root, (0.78 * sx, 1.55 + 1.22 * sy, 0), (0.5, 0.5, 0.82), M["greyd"],
                 round_=0.1, subsurf=0, rot=(0, PI / 4, 0))
    rbox("recess", root, (0, 1.55, 0.06), (1.64, 2.5, 0.7), M["rubber"], round_=0.0, subsurf=0)
    # franjas de aviso en el dintel
    for k in range(7):
        rbox("hazard_%d" % k, root, (-0.9 + k * 0.3, 3.06, -0.405), (0.12, 0.34, 0.01), M["amber"], round_=0.0, subsurf=0, rot=(0, 0.6, 0))
    bolts("frame_bolt", root, M, [(sx * 1.0, y, -0.405) for sx in (-1, 1) for y in (0.6, 1.3, 2.0, 2.6)], 0.025)
    for sd, s in ((-1.0, "l"), (1.0, "r")):
        leaf = node("anim_leaf_" + s, root, (0, 0, 0))
        rbox("leaf_" + s, leaf, (0.41 * sd, 1.55, -0.3), (0.82, 2.4, 0.12), M["grey"], round_=0.1, subsurf=0)
        for k in range(3):
            rbox("stripe_%s_%d" % (s, k), leaf, ((0.16 + k * 0.22) * sd, 2.45, -0.365), (0.1, 0.42, 0.012), M["amber"],
                 round_=0.0, subsurf=0, rot=(0, 0.65 * sd, 0))
        rbox("seal_" + s, leaf, (0.02 * sd, 1.55, -0.365), (0.04, 2.3, 0.015), M["rubber"], round_=0.0, subsurf=0)
        for y in (2.12, 0.75):
            rbox("rib_%s_%d" % (s, int(y * 10)), leaf, (0.42 * sd, y, -0.37), (0.62, 0.035, 0.02), M["greyd"], round_=0.3, subsurf=0)
        torus("port_" + s, leaf, (0.42 * sd, 1.6, -0.37), 0.12, 0.022, M["graph"], seg=20, ring=6, axis="z")
        cylinder("port_glass_" + s, leaf, (0.42 * sd, 1.6, -0.36), 0.11, 0.01, M["glass"], seg=20, axis="z")
    torus("handle", bpy.data.objects["anim_leaf_r"], (0.16, 1.2, -0.39), 0.08, 0.016, M["graph"], seg=14, ring=5, axis="z")
    rbox("ctrl", root, (1.0, 1.55, -0.43), (0.26, 0.5, 0.06), M["graph"], round_=0.2, subsurf=0)
    led("led_g", root, (1.0, 1.7, -0.465), M, "green", "-z")
    led("led_a", root, (1.0, 1.55, -0.465), M, "amber", "-z")
    led("led_r", root, (1.0, 1.4, -0.465), M, "red", "-z")
    rbox("floor_plate", root, (0, 0.025, -0.1), (1.6, 0.05, 0.9), M["greyd"], round_=0.2, subsurf=0)
    for k in range(5):
        rbox("tread_%d" % k, root, (0, 0.052, -0.45 + k * 0.18), (1.5, 0.008, 0.05), M["graph"], round_=0.0, subsurf=0)


# ---------------- G: invernadero (jardinera + cupula de cristal), simetrico ----------------
def st_G(M, root):
    rbox("planter", root, (0, 0.2, 0), (1.7, 0.4, 1.7), M["grey"], round_=0.12, subsurf=0)
    rbox("planter_lip", root, (0, 0.41, 0), (1.76, 0.04, 1.76), M["graph"], round_=0.3, subsurf=0)
    rbox("soil", root, (0, 0.43, 0), (1.52, 0.04, 1.52), M["soil"], round_=0.0, subsurf=0)
    rbox("label", root, (0, 0.22, 0.852), (0.5, 0.14, 0.01), M["leaf2"], round_=0.0, subsurf=0)
    for i in range(6):
        a = math.tau * i / 6 + 0.3
        px, pz = math.cos(a) * 0.5, math.sin(a) * 0.5
        sw = node("anim_sway_%d" % i, root, (px, 0.45, pz))
        h = 0.55 + 0.12 * (i % 3)
        tube("stem_%d" % i, sw, [(0, 0, 0), (0.03, h * 0.5, 0.02), (-0.02, h, 0)], 0.016, M["stem"], res=4)
        for k in range(4):
            b = a + k * 2.2
            y = 0.18 + k * (h - 0.18) / 3.5
            ellipsoid("leaf_%d_%d" % (i, k), sw, (math.cos(b) * 0.1, y, math.sin(b) * 0.1), 0.13, 0.025, 0.07,
                      M["leaf" if k % 2 == 0 else "leaf2"], seg=10, rings=5, rot=(0.0, 0.0, -b))
        if i % 2 == 0:
            for k in range(2):
                ellipsoid("fruit_%d_%d" % (i, k), sw, (0.06 * (1 - 2 * k), h * 0.55 + k * 0.08, 0.05), 0.04, 0.04, 0.04, M["fruit"],
                          seg=10, rings=6)
    lathe("dome", root, (0, 0, 0), [(0.0, 1.43), (0.36, 1.38), (0.68, 1.18), (0.9, 0.86), (1.0, 0.44)], M["glass"], seg=32, caps=False)
    torus("dome_ring", root, (0, 0.44, 0), 1.0, 0.03, M["white"], seg=36, ring=6)
    for k in range(3):
        a = PI / 3 * k
        pts = []
        for j in range(9):
            t = PI * j / 8
            pts.append((math.cos(a) * math.cos(t) * 1.005, 0.44 + math.sin(t) * 0.99, math.sin(a) * math.cos(t) * 1.005))
        tube("rib_%d" % k, root, pts, 0.014, M["white"], res=3)
    cylinder("light_mount", root, (0, 1.43, 0), 0.08, 0.04, M["graph"], seg=12)
    ellipsoid("grow_light", root, (0, 1.39, 0), 0.07, 0.04, 0.07, M["lamp"], seg=12, rings=6)
    rbox("ctrl", root, (0.86, 0.25, 0.0), (0.02, 0.16, 0.24), M["graph"], round_=0.0, subsurf=0)
    led("led_g", root, (0.875, 0.25, 0.05), M, "green", "z")


# ---------------- W: reciclador de agua (tanque de cristal + bomba), frente +Z ----------------
def st_W(M, root):
    lathe("tank", root, (0, 0, 0), [(0.62, 1.82), (0.62, 0.12)], M["glass"], seg=32, caps=False)
    lathe("water", root, (0, 0, 0), [(0.0, 1.15), (0.57, 1.15), (0.57, 0.13), (0.0, 0.13)], M["water"], seg=28)
    for y in (0.06, 1.88):
        cylinder("ring_%d" % int(y * 10), root, (0, y, 0), 0.68, 0.12, M["steel"], seg=32)
    cylinder("lid", root, (0, 1.96, 0), 0.5, 0.05, M["grey"], seg=24)
    for k in range(4):
        a = math.tau * k / 4 + PI / 4
        cylinder("post_%d" % k, root, (math.cos(a) * 0.66, 0.97, math.sin(a) * 0.66), 0.035, 1.8, M["steel"], seg=10)
    for k in range(4):
        rbox("mark_%d" % k, root, (0, 0.4 + k * 0.35, 0.625), (0.22 if k % 2 else 0.32, 0.018, 0.01), M["white"], round_=0.0, subsurf=0)
    # filtro (columna) y bomba con ventilador
    lathe("filter", root, (-0.85, 0, -0.1), [(0.0, 1.3), (0.12, 1.3), (0.14, 1.22), (0.14, 0.12), (0.16, 0.05), (0.0, 0.05)],
          M["white"], seg=16)
    cylinder("filter_band", root, (-0.85, 0.8, -0.1), 0.145, 0.08, M["leaf2"], seg=16)
    tube("pipe_filter", root, [(-0.85, 1.3, -0.1), (-0.85, 1.5, -0.1), (-0.6, 1.6, -0.05), (-0.4, 1.75, 0.0)], 0.035, M["steel"])
    rbox("pump", root, (0.95, 0.24, 0.2), (0.5, 0.46, 0.42), M["graph"], round_=0.12, subsurf=0)
    cylinder("fan_ring", root, (0.95, 0.27, 0.415), 0.15, 0.03, M["greyd"], seg=20, axis="z")
    fan = node("anim_fan", root, (0.95, 0.27, 0.43), (PI / 2, 0, 0))
    cylinder("fan_hub", fan, (0, 0, 0), 0.035, 0.03, M["steel"], seg=10)
    for k in range(5):
        a = math.tau * k / 5
        rbox("blade_%d" % k, fan, (math.cos(a) * 0.075, 0, math.sin(a) * 0.075), (0.11, 0.008, 0.045), M["steel"], round_=0.0,
             subsurf=0, rot=(0.35, 0, -a))
    rbox("pump_screen", root, (0.95, 0.4, 0.416), (0.2, 0.06, 0.008), M["screen_blue"], round_=0.0, subsurf=0)
    tube("pipe_in", root, [(0.7, 0.3, 0.1), (0.62, 0.3, 0.05), (0.6, 0.3, 0.0)], 0.05, M["steel"])
    tube("pipe_up", root, [(0.95, 0.47, 0.2), (0.95, 0.8, 0.2), (0.8, 1.2, 0.1), (0.6, 1.5, 0.05)], 0.035, M["steel"])
    led("led_b", root, (1.12, 0.12, 0.416), M, "blue")
    cylinder("beacon_base", root, (0, 2.0, 0), 0.1, 0.04, M["graph"], seg=12)
    ellipsoid("beacon", root, (0, 2.08, 0), 0.08, 0.07, 0.08, M["led_blue"], seg=12, rings=6)


# ---------------- B: cama (cabecera en +Z) ----------------
def st_B(M, root):
    for sx in (-0.82, 0.82):
        for sz in (-1.15, 1.15):
            cylinder("foot_%d_%d" % (int(sx * 10), int(sz * 10)), root, (sx, 0.11, sz), 0.06, 0.22, M["steel"], seg=10, r2=0.07)
    rbox("frame", root, (0, 0.29, 0), (1.78, 0.14, 2.46), M["grey"], round_=0.2, subsurf=0)
    rbox("mattress", root, (0, 0.47, 0), (1.64, 0.24, 2.3), M["mattress"], round_=0.7, subsurf=1)
    rbox("blanket", root, (0, 0.61, -0.36), (1.7, 0.1, 1.5), M["sheet"], round_=0.6, subsurf=1)
    lathe("fold", root, (0, 0.63, 0.4), [(0.0, 0.84), (0.06, 0.84), (0.06, -0.84), (0.0, -0.84)], M["sheet"], seg=12, rot=(0, PI / 2, 0))
    rbox("blanket_stripe", root, (0, 0.665, -0.15), (1.72, 0.02, 0.1), M["amber"], round_=0.0, subsurf=0)
    rbox("pillow", root, (0, 0.66, 0.82), (1.05, 0.16, 0.42), M["pillow"], round_=0.9, subsurf=1)
    rbox("headboard", root, (0, 0.72, 1.27), (1.9, 0.95, 0.12), M["grey"], round_=0.15, subsurf=0)
    rbox("head_pad", root, (0, 0.85, 1.2), (1.6, 0.42, 0.06), M["beige_d"], round_=0.8, subsurf=1)
    rbox("head_panel", root, (0, 1.12, 1.205), (0.6, 0.16, 0.03), M["graph"], round_=0.2, subsurf=0)
    rbox("head_screen", root, (0, 1.12, 1.188), (0.5, 0.08, 0.006), M["screen_blue"], round_=0.0, subsurf=0)
    tube("lamp_arm", root, [(0.72, 1.18, 1.22), (0.72, 1.45, 1.2), (0.7, 1.55, 1.08)], 0.014, M["steel"])
    lathe("lamp_head", root, (0.7, 0, 1.06), [(0.03, 1.6), (0.02, 1.6), (0.07, 1.5), (0.08, 1.5)], M["graph"], seg=12, caps=False)
    ellipsoid("lamp_bulb", root, (0.7, 1.52, 1.06), 0.035, 0.025, 0.035, M["lamp"], seg=10, rings=5)
    rbox("footboard", root, (0, 0.42, -1.25), (1.78, 0.3, 0.08), M["grey"], round_=0.2, subsurf=0)
    led("led_b", root, (0.7, 0.45, -1.292), M, "blue", "-z")
    rbox("net", root, (-0.95, 0.6, 0.5), (0.02, 0.4, 0.6), M["graph"], round_=0.0, subsurf=0)


BUILDERS = {"O": st_O, "S": st_S, "R": st_R, "C": st_C, "T": st_T, "A": st_A, "D": st_D, "G": st_G, "W": st_W, "B": st_B}


def build(ch, gpos=(0, 0, 0)):
    M = mats()
    root = node("station_" + ch, None, gpos)
    BUILDERS[ch](M, root)
    merge_tree(root)
    return root


only = argv[2].split(",") if len(argv) > 2 else list(BUILDERS)
for ch in only:
    reset()
    build(ch)
    tris, meshes = stats()
    path = os.path.join(OUT_DIR, "station_%s.glb" % ch)
    export_glb(path)
    print("ESTACION %s: %d triangulos, %d mallas -> %s" % (ch, tris, meshes, path))

if PREVIEW_DIR:
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    reset()
    order = ["O", "S", "R", "W", "G", "C", "B", "T", "A", "D"]
    for i, ch in enumerate(order):
        row, colm = divmod(i, 5)
        r = build(ch, (-6.0 + colm * 3.0, 0, -row * 3.6))
        if ch in ("C", "A", "D", "T", "B"):
            r.rotation_euler = (0, 0, PI)   # que miren a la camara (en +Z)
    preview_setup()
    shot(os.path.join(PREVIEW_DIR, "stations_all.png"), (0, 7.5, 10.0), (0, 0.6, -1.8), 30)
    shot(os.path.join(PREVIEW_DIR, "stations_row1.png"), (0.0, 3.0, 7.5), (0.0, 1.0, 0), 34)
    shot(os.path.join(PREVIEW_DIR, "stations_row2.png"), (0.0, 3.4, 4.2), (0.0, 1.2, -3.6), 34)
