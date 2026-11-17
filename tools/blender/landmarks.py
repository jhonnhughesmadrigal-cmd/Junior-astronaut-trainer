# Mision Perseo - puntos de interes 'L' del exterior (Blender 4.x / 5.x, en segundo plano).
#
#   blender --background --factory-startup --python tools/blender/landmarks.py -- <carpeta_salida> [carpeta_previews]
#
# Genera <carpeta_salida>/landmark_{apollo,rover,plaque,wreck}.glb (normalmente art/3d/ext/). Los carga
# ext_art.gd (view3d._make_landmark): a escala real (metros), origen en el suelo, sin normalizar.
#   apollo  etapa de descenso de un modulo lunar (lo que queda en los sitios Apolo), con lamina dorada,
#           patas con platos y escalerilla. Sin banderas ni logotipos.
#   rover   rover generico de 6 ruedas con mastil y antena (no reproduce ninguna mision concreta ni marcas).
#   plaque  placa conmemorativa sobre pedestal, con piloto ambar tenue (antes: esfera cian brillante).
#   wreck   restos del carguero de reabastecimiento (ficcion del juego): casco partido, tanque y panel.
#   airlock (art/3d/ext/airlock_ext.glb) esclusa vista desde fuera: vestibulo, marco, puerta con ojo de buey,
#           franjas de aviso mate, marquesina y postes. Origen = centro de la pared sur de la base a la altura
#           del suelo (view3d: ax, 0, az); mismas medidas que el modelo por codigo. El LED animado y las
#           balizas del camino siguen por codigo.
# Una sola pieza por material (merge_tree): pocas llamadas de dibujo.

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
import bpy  # noqa: E402

from bkit import (G, cylinder, export_glb, finish, material, merge_tree, node,  # noqa: E402
                  preview_setup, rbox, reset, shot, stats, torus, tube)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.abspath("art/3d/ext")
PREVIEW_DIR = os.path.abspath(argv[1]) if len(argv) > 1 else ""
PI = math.pi


def mats():
    return {
        "gold": material("foil_gold", (0.86, 0.66, 0.26), 0.85, 0.38),
        "foil_d": material("foil_dark", (0.3, 0.27, 0.22), 0.7, 0.45),
        "metal": material("metal", (0.68, 0.69, 0.7), 0.8, 0.35),
        "white": material("paint_white", (0.84, 0.84, 0.82), 0.1, 0.55),
        "graph": material("graphite", (0.2, 0.21, 0.23), 0.4, 0.6),
        "rubber": material("rubber", (0.13, 0.13, 0.14), 0.0, 0.85),
        "stone": material("stone", (0.42, 0.42, 0.44), 0.0, 0.9),
        "plate": material("bronze", (0.55, 0.43, 0.28), 0.8, 0.4),
        "burnt": material("burnt", (0.24, 0.2, 0.17), 0.4, 0.7),
        "lamp": material("lamp_amber", (0.95, 0.68, 0.32), 0.0, 0.4, 1.2),
        "solar": material("solar_cell", (0.1, 0.14, 0.24), 0.6, 0.3),
        "amber": material("paint_amber", (0.8, 0.62, 0.24), 0.1, 0.6),
        "door": material("door", (0.2, 0.23, 0.29), 0.5, 0.45),
        "glass_d": material("glass_dark", (0.12, 0.18, 0.24), 0.2, 0.12),
        "lamp_w": material("lamp_warm", (1.0, 0.9, 0.72), 0.0, 0.4, 0.8),
    }


def flat_all(root):
    for ob in root.children_recursive:
        if ob.type == "MESH":
            for p in ob.data.polygons:
                p.use_smooth = False


def strut(name, root, a, b, r, mat):
    return tube(name, root, [a, b], r, mat, res=6)


# ---------------- etapa de descenso (sitios Apolo) ----------------

def build_apollo(m):
    root = node("landmark_apollo", None, (0, 0, 0))
    h0 = 1.1  # altura de la base del cuerpo
    # cuerpo octogonal con lamina dorada y bandas oscuras
    cylinder("body", root, (0, h0 + 0.6, 0), 1.25, 1.2, m["gold"], seg=8)
    cylinder("band_t", root, (0, h0 + 1.24, 0), 1.27, 0.08, m["foil_d"], seg=8)
    cylinder("band_b", root, (0, h0 - 0.02, 0), 1.2, 0.06, m["foil_d"], seg=8)
    cylinder("deck", root, (0, h0 + 1.32, 0), 1.0, 0.08, m["metal"], seg=8)
    # tobera del motor de descenso
    cylinder("nozzle", root, (0, h0 - 0.3, 0), 0.32, 0.5, m["graph"], seg=12, r2=0.2)
    # cuatro patas: puntal principal + dos riostras + plato
    for i in range(4):
        a = PI / 4 + i * PI / 2
        dx, dz = math.cos(a), math.sin(a)
        top = (dx * 1.05, h0 + 0.9, dz * 1.05)
        foot = (dx * 2.0, 0.12, dz * 2.0)
        strut("leg%d" % i, root, top, foot, 0.06, m["metal"])
        for s in (-1, 1):
            b = a + s * 0.5
            strut("brace%d%d" % (i, s), root, (math.cos(b) * 1.2, h0 + 0.05, math.sin(b) * 1.2),
                  (dx * 1.62, 0.55, dz * 1.62), 0.03, m["metal"])
        cylinder("pad%d" % i, root, (foot[0], 0.05, foot[2]), 0.36, 0.1, m["metal"], seg=12, r2=0.3)
    # escalerilla en la pata del frente (+Z, hacia la camara habitual)
    a = PI / 4
    a = PI / 2 - 0.0
    lx, lz = 0.0, 1.0
    for k in range(7):
        y = 0.35 + k * 0.22
        t = (y - 0.12) / (h0 + 0.9 - 0.12)
        r = 2.0 + (1.05 - 2.0) * t
        rbox("rung%d" % k, root, (0, y, r * lz + 0.0), (0.46, 0.03, 0.04), m["metal"], round_=0.0, subsurf=0)
    for sx in (-0.23, 0.23):
        strut("rail%d" % int(sx * 10), root, (sx, 0.2, 1.95), (sx, h0 + 0.85, 1.2), 0.025, m["metal"])
    flat_all(root)
    return root


# ---------------- rover generico ----------------

def build_rover(m):
    root = node("landmark_rover", None, (0, 0, 0))
    # chasis y caja de electronica (blanco mate con paneles oscuros)
    rbox("box", root, (0, 1.05, 0), (1.9, 0.5, 1.2), m["white"], round_=0.08, subsurf=0, seg=1)
    rbox("deck", root, (0, 1.33, 0), (2.0, 0.06, 1.3), m["graph"], round_=0.0, subsurf=0)
    rbox("rtg", root, (-1.15, 1.2, 0), (0.5, 0.36, 0.5), m["graph"], round_=0.0, subsurf=0, rot=(0, 0, 0.35))
    # ruedas (6) con balancines
    for sx in (-0.8, 0.0, 0.8):
        for sz in (-0.78, 0.78):
            cylinder("wheel", root, (sx, 0.34, sz), 0.34, 0.26, m["rubber"], seg=14, rot=(PI / 2, 0, 0))
            cylinder("hub", root, (sx, 0.34, sz * 1.18), 0.12, 0.04, m["metal"], seg=8, rot=(PI / 2, 0, 0))
    for sz in (-0.7, 0.7):
        strut("rocker", root, (-0.8, 0.5, sz), (0.0, 0.85, sz), 0.04, m["metal"])
        strut("rocker2", root, (0.0, 0.85, sz), (0.8, 0.5, sz), 0.04, m["metal"])
    # mastil con cabeza de camaras y antena de alta ganancia
    cylinder("mast", root, (0.65, 1.95, -0.35), 0.05, 1.3, m["metal"], seg=8)
    rbox("head", root, (0.65, 2.68, -0.35), (0.5, 0.22, 0.28), m["white"], round_=0.0, subsurf=0)
    rbox("lens", root, (0.65, 2.68, -0.5), (0.36, 0.08, 0.02), m["graph"], round_=0.0, subsurf=0)
    cylinder("hga", root, (-0.4, 1.55, 0.35), 0.28, 0.05, m["metal"], seg=14, rot=(0.5, 0, 0.3))
    # brazo robotico plegado al frente
    strut("arm1", root, (0.95, 1.0, 0.3), (1.35, 0.75, 0.3), 0.04, m["metal"])
    strut("arm2", root, (1.35, 0.75, 0.3), (1.3, 0.45, -0.1), 0.04, m["metal"])
    rbox("turret", root, (1.3, 0.4, -0.12), (0.22, 0.18, 0.22), m["graph"], round_=0.0, subsurf=0)
    flat_all(root)
    return root


# ---------------- placa conmemorativa ----------------

def build_plaque(m):
    root = node("landmark_plaque", None, (0, 0, 0))
    rbox("base", root, (0, 0.1, 0), (1.3, 0.2, 0.9), m["stone"], round_=0.0, subsurf=0)
    rbox("step", root, (0, 0.26, 0), (1.0, 0.12, 0.66), m["stone"], round_=0.0, subsurf=0)
    rbox("stele", root, (0, 1.2, 0), (0.8, 1.8, 0.3), m["graph"], round_=0.06, subsurf=0, seg=1, taper_top=0.9)
    # placa de bronce inclinada en ambas caras (se lee desde cualquier lado)
    for sz in (-1, 1):
        rbox("plate", root, (0, 1.25, sz * 0.165), (0.56, 0.7, 0.02), m["plate"], round_=0.0, subsurf=0)
        for k in range(3):
            rbox("line", root, (0, 1.4 - k * 0.14, sz * 0.177), (0.4, 0.03, 0.01), m["graph"], round_=0.0, subsurf=0)
    # piloto ambar tenue en la cima (sustituye a la esfera cian)
    cylinder("lamp_base", root, (0, 2.13, 0), 0.09, 0.06, m["metal"], seg=10)
    cylinder("lamp", root, (0, 2.2, 0), 0.06, 0.08, m["lamp"], seg=10)
    flat_all(root)
    return root


# ---------------- restos del carguero ----------------

def build_wreck(m):
    root = node("landmark_wreck", None, (0, 0, 0))
    rnd = random.Random(9)
    # casco partido: dos medias carcasas cilindricas abiertas
    for i, (x, z, yaw, tilt) in enumerate(((-0.6, 0.1, 0.5, 0.25), (1.1, -0.5, -0.4, -0.3))):
        bm = bmesh.new()
        seg, L, R = 9, 1.5, 0.8
        verts = []
        for j in range(seg + 1):
            a = PI * j / seg
            row = []
            for k in (0, 1):
                row.append(bm.verts.new(G(math.cos(a) * R, math.sin(a) * R, (k - 0.5) * L + rnd.uniform(-0.12, 0.12))))
            verts.append(row)
        for j in range(seg):
            bm.faces.new((verts[j][0], verts[j + 1][0], verts[j + 1][1], verts[j][1]))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.05)
        finish("shell%d" % i, bm, root, (x, 0.05, z), m["white"] if i == 0 else m["burnt"], smooth=False,
               rot=(tilt, 0, yaw))
    # tanque esferico, puntales doblados y un panel solar roto
    cylinder("tank", root, (-0.9, 0.45, -0.95), 0.45, 1.6, m["metal"], seg=10, rot=(0, PI / 2, 0.7))
    strut("strut1", root, (0.3, 0.1, 0.6), (0.9, 1.1, 0.3), 0.04, m["metal"])
    strut("strut2", root, (0.9, 1.1, 0.3), (1.4, 0.9, 0.9), 0.04, m["metal"])
    rbox("panel", root, (1.6, 0.25, 0.8), (1.4, 0.04, 0.8), m["solar"], round_=0.0, subsurf=0, rot=(0.25, 0.4, 0.15))
    rbox("panel_f", root, (1.6, 0.22, 0.8), (1.44, 0.03, 0.84), m["metal"], round_=0.0, subsurf=0, rot=(0.25, 0.4, 0.15))
    flat_all(root)
    return root


# ---------------- esclusa (exterior) ----------------

def build_airlock(m):
    root = node("airlock_ext", None, (0, 0, 0))
    # vestibulo (sale 1,3 m de la pared) con canto biselado
    rbox("vest", root, (0, 1.55, 0.5), (3.0, 3.1, 1.3), m["graph"], round_=0.05, subsurf=0, seg=1)
    rbox("plinth", root, (0, 0.08, 0.55), (3.2, 0.16, 1.45), m["foil_d"], round_=0.0, subsurf=0)
    # marco de la puerta y puerta empotrada
    for sx in (-0.9, 0.9):
        rbox("jamb", root, (sx, 1.2, 1.17), (0.16, 2.4, 0.08), m["metal"], round_=0.0, subsurf=0)
    rbox("lintel", root, (0, 2.42, 1.17), (1.96, 0.16, 0.08), m["metal"], round_=0.0, subsurf=0)
    rbox("door", root, (0, 1.17, 1.14), (1.64, 2.3, 0.06), m["door"], round_=0.0, subsurf=0)
    rbox("seam", root, (0, 1.17, 1.175), (0.03, 2.2, 0.01), m["graph"], round_=0.0, subsurf=0)
    torus("port_ring", root, (0, 1.75, 1.18), 0.2, 0.035, m["metal"], seg=16, ring=6, axis="z")
    cylinder("port", root, (0, 1.75, 1.17), 0.19, 0.02, m["glass_d"], seg=16, axis="z")
    rbox("handle", root, (0.55, 1.15, 1.2), (0.06, 0.4, 0.05), m["metal"], round_=0.0, subsurf=0)
    # franjas de aviso (ambar mate, sin brillo) a los lados del marco
    for sx in (-1.25, 1.25):
        for k in range(5):
            rbox("hz", root, (sx, 0.35 + k * 0.42, 1.16), (0.36, 0.16, 0.03), m["amber"], round_=0.0, subsurf=0,
                 rot=(0, 0.0, 0.5 if sx < 0 else -0.5))
    # escalon
    rbox("step", root, (0, 0.1, 1.45), (1.9, 0.2, 0.5), m["metal"], round_=0.0, subsurf=0)
    # marquesina: losa con canto ambar, sobre dos postes
    rbox("canopy", root, (0, 3.2, 0.9), (3.8, 0.16, 2.0), m["amber"], round_=0.0, subsurf=0)
    rbox("canopy_edge", root, (0, 3.2, 1.91), (3.84, 0.2, 0.06), m["graph"], round_=0.0, subsurf=0)
    for sx in (-1.7, 1.7):
        cylinder("post", root, (sx, 1.55, 1.8), 0.07, 3.1, m["metal"], seg=10)
        cylinder("post_foot", root, (sx, 0.04, 1.8), 0.14, 0.08, m["metal"], seg=10)
    # apliques tenues bajo la marquesina
    for sx in (-1.15, 1.15):
        rbox("lamp", root, (sx, 2.95, 1.2), (0.3, 0.06, 0.16), m["lamp_w"], round_=0.0, subsurf=0)
    flat_all(root)
    return root


BUILDERS = (("apollo", build_apollo), ("rover", build_rover), ("plaque", build_plaque), ("wreck", build_wreck), ("airlock", build_airlock))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for nm, build in BUILDERS:
        reset()
        m = mats()
        root = build(m)
        merge_tree(root)
        t, n = stats()
        path = os.path.join(OUT_DIR, ("landmark_%s.glb" % nm) if nm != "airlock" else "airlock_ext.glb")
        export_glb(path)
        print("GLB:", path, "tris", t, "meshes", n)
    if not PREVIEW_DIR:
        return
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for nm, build in BUILDERS:
        reset()
        m = mats()
        preview_setup(bg=(0.05, 0.05, 0.07))
        root = build(m)
        merge_tree(root)
        shot(os.path.join(PREVIEW_DIR, "lm_%s.png" % nm), (3.6, 3.0, 5.4), (0, 1.1, 0), lens=35)


main()
