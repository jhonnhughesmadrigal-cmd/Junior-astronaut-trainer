# Mision Perseo - modelos para eventos y finales (Blender 4.x / 5.x, en segundo plano).
#
#   blender --background --factory-startup --python tools/blender/fx_assets.py -- <carpeta_salida> [carpeta_previews]
#
# Genera (normalmente en art/3d/fx/):
#   meteor.glb        roca irregular con grietas incandescentes (material "core": brilla); ~1 m de diametro.
#                     La usa cinema.gd en la cinematica del meteoro (con estela y humo por codigo).
#   rescue_ship.glb   nave de rescate de diseno propio (capsula conica, modulo de servicio, radiadores, 4 patas,
#                     tobera). Origen en el suelo (bajo las patas), ~7 m de alto. Nodo "anim_engine" en la tobera
#                     (ending_cine.gd le pone llama y polvo). Sin logotipos ni marcas.

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from bkit import (G, cylinder, export_glb, finish, lathe, material, merge_tree, node,  # noqa: E402
                  preview_setup, rbox, reset, shot, stats, tube)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.abspath("art/3d/fx")
PREVIEW_DIR = os.path.abspath(argv[1]) if len(argv) > 1 else ""
PI = math.pi


def flat_all(root):
    for ob in root.children_recursive:
        if ob.type == "MESH":
            for p in ob.data.polygons:
                p.use_smooth = False


def build_meteor():
    rock = material("rock_dark", (0.2, 0.18, 0.17), 0.1, 0.9)
    core = material("core", (1.0, 0.45, 0.12), 0.0, 0.5, 4.0)
    root = node("meteor", None, (0, 0, 0))
    rnd = random.Random(3)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.5)
    for v in bm.verts:
        n = v.co.normalized()
        v.co = n * 0.5 * rnd.uniform(0.78, 1.18)
    bm.faces.ensure_lookup_table()
    # caras "grieta": se separan con material incandescente (un poco hundidas)
    ob = finish("meteor_rock", bm, root, (0, 0, 0), rock, smooth=False)
    me = ob.data
    me.materials.append(core)
    for p in me.polygons:
        if rnd.random() < 0.22:
            p.material_index = 1
    return root


def build_ship():
    hull = material("ship_white", (0.86, 0.86, 0.84), 0.2, 0.5)
    dark = material("ship_dark", (0.16, 0.17, 0.2), 0.5, 0.45)
    metal = material("ship_metal", (0.62, 0.63, 0.66), 0.85, 0.35)
    amber = material("ship_amber", (0.82, 0.62, 0.24), 0.2, 0.55)
    glass = material("ship_glass", (0.12, 0.2, 0.28), 0.3, 0.1)
    rad = material("ship_radiator", (0.75, 0.77, 0.8), 0.6, 0.3)
    root = node("rescue_ship", None, (0, 0, 0))
    legs_h = 1.6
    # modulo de servicio (cilindro) con franja ambar
    cylinder("service", root, (0, legs_h + 1.2, 0), 1.55, 2.4, hull, seg=24)
    cylinder("band", root, (0, legs_h + 2.25, 0), 1.57, 0.22, amber, seg=24)
    cylinder("skirt", root, (0, legs_h - 0.05, 0), 1.6, 0.18, dark, seg=24)
    # capsula conica encima
    lathe("capsule", root, (0, legs_h + 2.4, 0), [(1.5, 0.0), (1.42, 0.25), (0.85, 1.75), (0.55, 2.05), (0.0, 2.15)],
          hull, seg=24)
    cylinder("heat_ring", root, (0, legs_h + 2.42, 0), 1.52, 0.1, dark, seg=24)
    # ventanas de la capsula (4) y escotilla
    for i in range(4):
        a = PI / 4 + i * PI / 2
        r = 1.12
        p = (math.cos(a) * r, legs_h + 3.25, math.sin(a) * r)
        # la cara fina (eje Z de Godot = -Y de Blender) mira hacia fuera: giro en Z de Blender (vertical)
        rbox("win%d" % i, root, p, (0.34, 0.28, 0.06), glass, round_=0.0, subsurf=0,
             rot=(0.0, -0.55, a + PI / 2))
    rbox("hatch", root, (0, legs_h + 3.0, 1.25), (0.62, 0.7, 0.06), dark, round_=0.0, subsurf=0, rot=(0.55, 0, 0))
    # radiadores laterales
    for sx in (-1, 1):
        rbox("radiator", root, (sx * 1.95, legs_h + 1.3, 0), (0.7, 1.7, 0.05), rad, round_=0.0, subsurf=0)
        rbox("rad_arm", root, (sx * 1.62, legs_h + 1.3, 0), (0.12, 0.12, 0.12), metal, round_=0.0, subsurf=0)
    # propulsores de maniobra (4 cajas)
    for i in range(4):
        a = i * PI / 2
        rbox("rcs%d" % i, root, (math.cos(a) * 1.6, legs_h + 2.0, math.sin(a) * 1.6), (0.22, 0.26, 0.22), dark,
             round_=0.0, subsurf=0)
    # tobera principal y nodo para la llama
    lathe("nozzle", root, (0, legs_h - 0.95, 0), [(0.75, 0.0), (0.6, 0.35), (0.38, 0.8), (0.42, 0.95)], metal,
          seg=20, caps=False)
    node("anim_engine", root, (0, legs_h - 0.95, 0))
    # 4 patas con platos
    for i in range(4):
        a = PI / 4 + i * PI / 2
        dx, dz = math.cos(a), math.sin(a)
        top = (dx * 1.45, legs_h + 0.4, dz * 1.45)
        foot = (dx * 2.5, 0.12, dz * 2.5)
        tube("leg%d" % i, root, [top, foot], 0.08, metal, res=6)
        tube("strut%d" % i, root, [(dx * 1.5, legs_h - 0.05, dz * 1.5), (dx * 2.2, 0.5, dz * 2.2)], 0.045, metal, res=6)
        cylinder("pad%d" % i, root, (foot[0], 0.05, foot[2]), 0.4, 0.1, metal, seg=12, r2=0.32)
    flat_all(root)
    return root


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for nm, build in (("meteor", build_meteor), ("rescue_ship", build_ship)):
        reset()
        root = build()
        merge_tree(root)
        t, n = stats()
        path = os.path.join(OUT_DIR, nm + ".glb")
        export_glb(path)
        print("GLB:", path, "tris", t, "meshes", n)
    if not PREVIEW_DIR:
        return
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    reset()
    preview_setup(bg=(0.03, 0.03, 0.05))
    s = build_ship()
    merge_tree(s)
    m = build_meteor()
    m.location = G(-5, 3, 0)
    m.scale = (2, 2, 2)
    shot(os.path.join(PREVIEW_DIR, "fx_ship.png"), (9, 5, 12), (-1, 3.2, 0), lens=32)


main()
