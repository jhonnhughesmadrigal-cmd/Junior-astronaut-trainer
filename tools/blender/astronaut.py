# Mision Perseo - astronauta por piezas para Godot (Blender 4.x / 5.x, en segundo plano).
#
#   blender --background --factory-startup --python tools/blender/astronaut.py -- <salida.glb> [carpeta_previews]
#
# v39b: proporciones mas humanas (casco menor, torso rigido tipo traje EVA, brazos y piernas mas
# delgados y con forma, guantes con dedos, botas con cana). Cada pieza cuelga de un nodo con el MISMO
# nombre y punto de giro que usa view3d.gd (_make_astronaut / _anim_astronaut): rig, body, head, pack,
# ant, arm_l, elb_l, arm_r, elb_r, leg_l, kn_l, leg_r, kn_r. Asi las poses por codigo siguen igual.
# Materiales con nombres fijos (suit, shell, visor, accent, dark, metal, glove, bearing...): crew_model.gd
# los sustituye por los del juego, asi el color de rol se aplica por codigo.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

from bkit import (G, cylinder, ellipsoid, export_glb, lathe, material, merge_tree, node,  # noqa: E402
                  preview_setup, rbox, reset, shot, stats, torus, tube)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_GLB = os.path.abspath(argv[0]) if argv else os.path.abspath("astronaut.glb")
PREVIEW_DIR = os.path.abspath(argv[1]) if len(argv) > 1 else ""


def base_mats(accent=(0.93, 0.52, 0.18), sfx=""):
    return {
        "suit": material("suit" + sfx, (0.93, 0.93, 0.92), 0.0, 0.82),
        "shell": material("shell" + sfx, (0.95, 0.95, 0.94), 0.0, 0.24),
        "visor": material("visor" + sfx, (0.62, 0.44, 0.16), 0.92, 0.08),
        "accent": material("accent" + sfx, accent, 0.1, 0.5),
        "dark": material("dark" + sfx, (0.22, 0.24, 0.3), 0.3, 0.55),
        "metal": material("metal" + sfx, (0.7, 0.72, 0.8), 0.85, 0.3),
        "glove": material("glove" + sfx, (0.82, 0.84, 0.9), 0.0, 0.75),
        "bearing": material("bearing" + sfx, (0.56, 0.58, 0.62), 0.8, 0.32),
        "sole": material("sole" + sfx, (0.12, 0.13, 0.16), 0.0, 0.9),
        "light_green": material("light_green" + sfx, (0.3, 1.0, 0.45), 0.0, 0.3, 3.0),
        "light_amber": material("light_amber" + sfx, (1.0, 0.8, 0.2), 0.0, 0.3, 3.0),
        "light_red": material("light_red" + sfx, (1.0, 0.3, 0.3), 0.0, 0.3, 3.0),
        "lamp": material("lamp" + sfx, (1.0, 0.97, 0.8), 0.0, 0.3, 4.0),
    }


def build(M, sfx=""):
    def N(s):
        return s + sfx

    root = node(N("astronaut"), None, (0, 0, 0))
    rig = node(N("rig"), root, (0, 0, 0))
    body = node(N("body"), rig, (0, 0, 0))

    # --- torso rigido (pecho ancho, se estrecha en la cintura), seccion eliptica ---
    lathe(N("torso"), body, (0, 0, 0),
          [(0.0, 1.53), (0.15, 1.525), (0.235, 1.49), (0.27, 1.41), (0.275, 1.3), (0.255, 1.16),
           (0.215, 1.03), (0.2, 0.97), (0.0, 0.95)], M["suit"], seg=22, sz=0.72)
    for i, y in enumerate((0.955, 0.905)):
        torus(N("waist_fold_%d" % i), body, (0, y, 0), 0.198, 0.026, M["suit"], seg=22, sz=0.76)
    torus(N("belt"), body, (0, 1.0, 0), 0.212, 0.022, M["accent"], seg=22, sz=0.76)
    cylinder(N("neck_ring"), body, (0, 1.52, 0), 0.165, 0.06, M["metal"], seg=22, r2=0.175)
    # unidad de control en el pecho (DCM) con luces
    rbox(N("chest_panel"), body, (0, 1.27, -0.215), (0.26, 0.14, 0.08), M["dark"], round_=0.4, subsurf=0)
    for i, (mn, x) in enumerate((("light_green", -0.07), ("light_amber", 0.0), ("light_red", 0.07))):
        ellipsoid(N("chest_light_%d" % i), body, (x, 1.295, -0.256), 0.02, 0.02, 0.01, M[mn], seg=8, rings=5)
    rbox(N("chest_dial"), body, (0, 1.24, -0.256), (0.16, 0.028, 0.01), M["metal"], round_=0.5, subsurf=0)
    # parche de rol (izquierda) y de mision (derecha)
    rbox(N("role_patch"), body, (-0.15, 1.4, -0.205), (0.085, 0.085, 0.03), M["accent"], round_=0.5, subsurf=0)
    cylinder(N("mission_patch"), body, (0.15, 1.4, -0.205), 0.045, 0.03, M["dark"], seg=14, axis="z")
    torus(N("mission_patch_rim"), body, (0.15, 1.4, -0.222), 0.045, 0.007, M["accent"], seg=14, ring=4, axis="z")
    for sd in (-1.0, 1.0):
        tube(N("hose_%s" % ("l" if sd < 0 else "r")), body,
             [(0.1 * sd, 1.22, -0.25), (0.26 * sd, 1.16, -0.19), (0.3 * sd, 1.26, 0.04), (0.2 * sd, 1.4, 0.24)],
             0.017, M["dark"])

    # --- mochila de soporte vital (PLSS) ---
    pack = node(N("pack"), body, (0, 1.6, 0.3))
    rbox(N("pack_shell"), pack, (0, -0.3, 0.0), (0.46, 0.62, 0.22), M["shell"], taper_bottom=0.94, round_=0.3)
    rbox(N("pack_lid"), pack, (0, -0.02, 0.0), (0.42, 0.05, 0.2), M["metal"], round_=0.5, subsurf=0)
    rbox(N("pack_vent"), pack, (0, -0.48, 0.115), (0.26, 0.12, 0.02), M["dark"], round_=0.3, subsurf=0)
    rbox(N("pack_stripe"), pack, (0, -0.12, 0.115), (0.3, 0.035, 0.02), M["accent"], round_=0.5, subsurf=0)
    for sd in (-1.0, 1.0):
        s = "l" if sd < 0 else "r"
        cylinder(N("pack_tank_" + s), pack, (0.25 * sd, -0.33, 0.04), 0.045, 0.46, M["metal"], seg=12)
        ellipsoid(N("pack_tank_cap_" + s), pack, (0.25 * sd, -0.1, 0.04), 0.045, 0.03, 0.045, M["metal"], seg=12, rings=5)

    ant = node(N("ant"), body, (0.18, 1.78, 0.32))
    cylinder(N("ant_rod"), ant, (0, 0, 0), 0.008, 0.3, M["metal"], seg=6)
    ellipsoid(N("ant_tip"), ant, (0, 0.155, 0), 0.018, 0.018, 0.018, M["light_red"], seg=8, rings=5)

    # --- casco: burbuja algo alargada, visor dorado grande, lamparas laterales ---
    head = node(N("head"), body, (0, 1.66, 0))
    ellipsoid(N("helmet"), head, (0, 0.05, 0), 0.228, 0.245, 0.24, M["shell"], seg=28, rings=16)
    ellipsoid(N("visor"), head, (0, 0.035, -0.09), 0.2, 0.17, 0.192, M["visor"], seg=24, rings=14)
    torus(N("visor_rim"), head, (0, 0.035, -0.158), 0.168, 0.014, M["bearing"], seg=26, sx=1.17, sz=0.98, axis="z")
    torus(N("helmet_stripe"), head, (0, 0.05, 0.0), 0.243, 0.013, M["accent"], seg=32, ring=5, axis="x")
    torus(N("neck_bearing"), head, (0, -0.14, 0), 0.178, 0.026, M["bearing"], seg=24)
    for sd in (-1.0, 1.0):
        s = "l" if sd < 0 else "r"
        rbox(N("lamp_housing_" + s), head, (0.215 * sd, 0.08, -0.06), (0.05, 0.06, 0.12), M["dark"], round_=0.5, subsurf=0)
        ellipsoid(N("lamp_" + s), head, (0.215 * sd, 0.08, -0.122), 0.02, 0.022, 0.008, M["lamp"], seg=8, rings=5)

    # --- brazos: hombro -> codo -> guante ---
    for sd, s in ((-1.0, "l"), (1.0, "r")):
        sh = node(N("arm_" + s), body, (0.34 * sd, 1.48, 0))
        ellipsoid(N("shoulder_" + s), sh, (-0.03 * sd, 0.0, 0), 0.115, 0.1, 0.11, M["suit"])
        torus(N("shoulder_bearing_" + s), sh, (0, -0.06, 0), 0.09, 0.018, M["bearing"], seg=16)
        lathe(N("upper_arm_" + s), sh, (0, 0, 0),
              [(0.0, -0.02), (0.08, -0.05), (0.088, -0.1), (0.083, -0.2), (0.074, -0.31), (0.0, -0.35)],
              M["suit"], seg=14)
        torus(N("arm_fold_" + s), sh, (0, -0.13, 0), 0.085, 0.012, M["suit"], seg=14, ring=5)
        torus(N("arm_band_" + s), sh, (0, -0.22, 0), 0.081, 0.013, M["accent"], seg=14, ring=5)
        el = node(N("elb_" + s), sh, (0, -0.34, 0))
        ellipsoid(N("elbow_" + s), el, (0, 0, 0), 0.074, 0.072, 0.074, M["suit"], seg=12, rings=8)
        lathe(N("forearm_" + s), el, (0, 0, 0),
              [(0.0, -0.01), (0.072, -0.04), (0.074, -0.1), (0.064, -0.22), (0.0, -0.25)], M["suit"], seg=14)
        torus(N("wrist_" + s), el, (0, -0.245, 0), 0.066, 0.018, M["bearing"], seg=16)
        # guante: palma, dedos algo cerrados y pulgar hacia delante
        rbox(N("palm_" + s), el, (0, -0.31, -0.005), (0.085, 0.1, 0.055), M["glove"], taper_bottom=0.92, round_=0.7, subsurf=0, seg=3)
        rbox(N("fingers_" + s), el, (0, -0.385, -0.018), (0.08, 0.07, 0.045), M["glove"], taper_bottom=0.85, round_=0.8, subsurf=0, seg=3,
             rot=(math.radians(14), 0, 0))
        ellipsoid(N("thumb_" + s), el, (-0.035 * sd, -0.32, -0.04), 0.018, 0.038, 0.018, M["glove"], seg=8, rings=5,
                  rot=(math.radians(-25), 0, math.radians(20 * sd)))

    # --- pelvis y piernas: cadera -> rodilla -> bota ---
    lathe(N("pelvis"), rig, (0, 0, 0),
          [(0.0, 0.96), (0.2, 0.95), (0.225, 0.86), (0.215, 0.74), (0.17, 0.66), (0.0, 0.63)], M["suit"], seg=20, sz=0.74)
    for sd, s in ((-1.0, "l"), (1.0, "r")):
        hp = node(N("leg_" + s), rig, (0.15 * sd, 0.68, 0))
        ellipsoid(N("hip_" + s), hp, (0, 0.0, 0), 0.105, 0.09, 0.105, M["suit"], seg=12, rings=8)
        lathe(N("thigh_" + s), hp, (0, 0, 0),
              [(0.0, 0.0), (0.1, -0.03), (0.104, -0.1), (0.094, -0.24), (0.084, -0.32), (0.0, -0.36)], M["suit"], seg=14)
        torus(N("leg_fold_" + s), hp, (0, -0.12, 0), 0.1, 0.013, M["suit"], seg=14, ring=5)
        torus(N("leg_band_" + s), hp, (0, -0.24, 0), 0.093, 0.014, M["accent"], seg=14, ring=5)
        kn = node(N("kn_" + s), hp, (0, -0.34, 0))
        ellipsoid(N("knee_" + s), kn, (0, 0, 0), 0.084, 0.08, 0.084, M["suit"], seg=12, rings=8)
        ellipsoid(N("knee_pad_" + s), kn, (0, 0.005, -0.07), 0.06, 0.07, 0.03, M["dark"], seg=10, rings=6)
        lathe(N("shin_" + s), kn, (0, 0, 0),
              [(0.0, -0.01), (0.082, -0.04), (0.084, -0.12), (0.074, -0.24), (0.0, -0.27)], M["suit"], seg=14)
        # bota: cana, empeine y suela
        lathe(N("boot_shaft_" + s), kn, (0, 0, 0),
              [(0.0, -0.22), (0.086, -0.23), (0.09, -0.3), (0.088, -0.36), (0.0, -0.37)], M["dark"], seg=14)
        rbox(N("boot_" + s), kn, (0, -0.355, -0.06), (0.15, 0.1, 0.27), M["dark"], taper_top=0.8, round_=0.6, subsurf=1)
        rbox(N("sole_" + s), kn, (0, -0.405, -0.045), (0.16, 0.035, 0.3), M["sole"], round_=0.4, subsurf=0)
    return root


reset()
r = build(base_mats())
merge_tree(r)
tris, meshes = stats()
print("TRIANGULOS:", tris, "MALLAS:", meshes)
export_glb(OUT_GLB)
print("EXPORTADO:", OUT_GLB)

if PREVIEW_DIR:
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    crew = [("wilson", (0.93, 0.52, 0.18)), ("yarisbel", (0.82, 0.22, 0.22)),
            ("enoc", (0.16, 0.52, 0.6)), ("pam", (0.9, 0.74, 0.24))]
    for i, (nm, c) in enumerate(crew):
        rr = build(base_mats(c, "_" + nm), "_" + nm)
        rr.location = G(-2.1 + i * 1.4, 0.08, 0)
        rr.rotation_euler = (0, 0, math.radians((-25, -8, 8, 25)[i]))
    # pose de prueba: Zadiel saluda; Enoc camina (comprueba los puntos de giro)
    bpy.data.objects["arm_r_wilson"].rotation_euler = (0, math.radians(-150), 0)
    bpy.data.objects["elb_r_wilson"].rotation_euler = (math.radians(25), 0, 0)
    bpy.data.objects["leg_l_enoc"].rotation_euler = (math.radians(-30), 0, 0)
    bpy.data.objects["kn_l_enoc"].rotation_euler = (math.radians(35), 0, 0)
    bpy.data.objects["leg_r_enoc"].rotation_euler = (math.radians(25), 0, 0)
    bpy.data.objects["arm_l_enoc"].rotation_euler = (math.radians(25), 0, 0)
    bpy.data.objects["arm_r_enoc"].rotation_euler = (math.radians(-25), 0, 0)
    preview_setup()
    shot(os.path.join(PREVIEW_DIR, "crew_front.png"), (0, 1.5, -7.2), (0, 0.95, 0), 40)
    shot(os.path.join(PREVIEW_DIR, "closeup_34.png"), (-2.9, 1.8, -2.3), (-2.1, 1.25, 0), 45)
    shot(os.path.join(PREVIEW_DIR, "back.png"), (0.6, 1.6, 5.5), (0, 1.0, 0), 40)
