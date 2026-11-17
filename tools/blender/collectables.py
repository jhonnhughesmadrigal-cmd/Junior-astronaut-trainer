# Mision Perseo - recolectables del exterior (Blender 4.x / 5.x, en segundo plano).
#
#   blender --background --factory-startup --python tools/blender/collectables.py -- <carpeta_salida> [carpeta_previews]
#
# Genera <carpeta_salida>/material_scrap.glb, material_crate.glb y material_ice.glb (normalmente art/3d/).
# El juego (collect_glb.gd) los normaliza: base en y=0, centrados y con la dimension MAYOR = 1,3 / 1,35 / 1,7 m.
# Salen cientos en el mapa (MultiMesh por material y por trozo del mapa), asi que:
#   - menos de ~800 triangulos cada uno y 2-3 materiales (cada material = un MultiMesh mas por trozo);
#   - sin transparencias (el hielo es opaco: ordenar cientos de instancias transparentes es caro);
#   - el material  rock_tint  recibe el color de la zona por instancia (como las rocas por codigo).
# Convencion que lee collect_glb.gd: material  rock_tint  (tinte por zona) · led (piloto que late)
#   · ice (posicion de los destellos: centro de su caja).

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from bkit import (G, cylinder, export_glb, finish, material, merge_tree, node,  # noqa: E402
                  preview_setup, rbox, reset, shot, stats)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.abspath("art/3d")
PREVIEW_DIR = os.path.abspath(argv[1]) if len(argv) > 1 else ""
PI = math.pi


def mats():
    return {
        # metal gastado (aluminio sin pintar) y panel pintado oscuro: sin neon, poco brillo
        "metal": material("metal", (0.66, 0.66, 0.64), 0.75, 0.42),
        "panel": material("panel", (0.32, 0.33, 0.35), 0.45, 0.55),
        # blanco: se multiplica por el color de la zona en Godot
        "rock_tint": material("rock_tint", (0.86, 0.86, 0.86), 0.0, 0.95),
        "crate": material("crate", (0.5, 0.54, 0.43), 0.2, 0.6),
        # franja de aviso ambar mate (se ve de lejos sin brillar: sin neon)
        "amber": material("amber", (0.8, 0.6, 0.22), 0.1, 0.6),
        "trim": material("trim", (0.24, 0.24, 0.25), 0.55, 0.45),
        "led": material("led", (0.95, 0.42, 0.22), 0.0, 0.4, 1.6),
        "ice": material("ice", (0.74, 0.88, 0.96), 0.0, 0.14),
        "frost": material("frost", (0.9, 0.94, 0.97), 0.0, 0.7),
    }


# v40: materiales que solo cambian de color -> un material compartido con color por vertice.
# Cada material del .glb es un MultiMesh mas en cada bloque del mapa, asi que esto reduce llamadas de dibujo.
# rock_tint (tinte de zona por instancia) y led (emisivo) quedan aparte.
VC_GROUPS = {
    "metal": "metal_vc", "panel": "metal_vc",
    "crate": "crate_vc", "amber": "crate_vc", "trim": "crate_vc",
    "ice": "ice_vc", "frost": "ice_vc",
}
VC_PARAMS = {"metal_vc": (0.65, 0.48), "crate_vc": (0.3, 0.55), "ice_vc": (0.0, 0.22)}


def vc_material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    metal, rough = VC_PARAMS[name]
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    ca = nt.nodes.new("ShaderNodeVertexColor")
    ca.layer_name = "Col"
    nt.links.new(ca.outputs["Color"], b.inputs["Base Color"])
    return m


def to_vertex_colors(root):
    for ob in [o for o in root.children_recursive if o.type == "MESH"]:
        src = ob.data.materials[0] if ob.data.materials else None
        if src is None or src.name not in VC_GROUPS:
            continue
        c = src.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
        me = ob.data
        at = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for d in at.data:
            d.color = (c[0], c[1], c[2], 1.0)
        me.color_attributes.active_color = at
        me.materials.clear()
        me.materials.append(vc_material(VC_GROUPS[src.name]))


def clean_colors(root):
    # tras merge_tree puede quedar mas de un atributo de color (el exportador escribiria COLOR_0 y COLOR_1
    # y Godot solo usa COLOR_0): se deja solo "Col".
    for ob in [o for o in root.children_recursive if o.type == "MESH"]:
        me = ob.data
        if "Col" not in me.color_attributes:
            continue
        for a in [a for a in me.color_attributes if a.name != "Col"]:
            me.color_attributes.remove(a)
        me.color_attributes.active_color = me.color_attributes["Col"]
        try:
            me.color_attributes.render_color_index = me.color_attributes.active_color_index
        except Exception:
            pass


def flat(ob):
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def mound(name, parent, gpos, rx, ry, rz, mat, seed, seg=9, rings=4):
    # monticulo de regolito: media elipsoide aplastada y algo irregular (low poly, sombreado plano)
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings * 2, radius=1.0)
    kill = [v for v in bm.verts if v.co.z < -0.05]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    for v in bm.verts:
        j = 1.0 + rnd.uniform(-0.14, 0.14) if v.co.z > 0.05 else 1.0
        v.co = Vector((v.co.x * rx * j, v.co.y * rz * j, max(v.co.z, 0.0) * ry * j - 0.04))
    return flat(finish(name, bm, parent, gpos, mat, smooth=False))


def bent_plate(name, parent, gpos, w, h, t, bend, mat, rot=None, cols=3):
    # placa de casco doblada (columnas de quads con el pliegue en el centro)
    bm = bmesh.new()
    vs = []
    for i in range(cols + 1):
        u = i / cols - 0.5
        k = abs(u) * 2.0
        dz = bend * k * k
        row = []
        for j in (0, 1):
            for s in (-1, 1):
                row.append(bm.verts.new(G(u * w, (j - 0.5) * h, dz + s * t * 0.5)))
        vs.append(row)
    for i in range(cols):
        a, b = vs[i], vs[i + 1]
        # caras: delante (s=+1), detras (s=-1), arriba, abajo
        bm.faces.new((a[1], b[1], b[3], a[3]))
        bm.faces.new((a[0], a[2], b[2], b[0]))
        bm.faces.new((a[2], a[3], b[3], b[2]))
        bm.faces.new((a[0], b[0], b[1], a[1]))
    bm.faces.new((vs[0][0], vs[0][1], vs[0][3], vs[0][2]))
    bm.faces.new((vs[-1][0], vs[-1][2], vs[-1][3], vs[-1][1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return flat(finish(name, bm, parent, gpos, mat, smooth=False, rot=rot))


def prism(name, parent, gpos, r, h, mat, sides=6, tip=0.35, rot=None, seed=0):
    # cristal: prisma de 6 caras con punta (sombreado plano, se leen bien las facetas)
    rnd = random.Random(seed)
    bm = bmesh.new()
    a0 = rnd.uniform(0, PI)
    bot, top = [], []
    for i in range(sides):
        a = a0 + 2 * PI * i / sides
        rr = r * rnd.uniform(0.88, 1.08)
        bot.append(bm.verts.new(G(math.cos(a) * rr, 0.0, math.sin(a) * rr)))
        top.append(bm.verts.new(G(math.cos(a) * rr * 0.92, h * (1 - tip), math.sin(a) * rr * 0.92)))
    apex = bm.verts.new(G(rnd.uniform(-0.15, 0.15) * r, h, rnd.uniform(-0.15, 0.15) * r))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
        bm.faces.new((top[i], top[j], apex))
    bm.faces.new(list(reversed(bot)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return flat(finish(name, bm, parent, gpos, mat, smooth=False, rot=rot))


# ---------------- chatarra ----------------

def build_scrap(m):
    # restos de un modulo: placa de casco de aluminio con franja pintada, tanque tumbado medio enterrado,
    # puntal partido y una escuadra; sobre un monticulo de regolito (tinte de la zona)
    root = node("material_scrap", None, (0, 0, 0))
    mound("mound", root, (0, 0, 0), 0.62, 0.17, 0.5, m["rock_tint"], 3)
    mound("mound2", root, (0.44, 0, 0.3), 0.24, 0.1, 0.2, m["rock_tint"], 7, seg=7, rings=3)
    # tanque tumbado (eje X de Godot), algo hundido y girado
    yaw = math.radians(28)
    cylinder("tank", root, (0.12, 0.22, -0.12), 0.26, 0.74, m["metal"], seg=10, rot=(0, PI / 2, yaw))
    for k in (-1, 1):  # aros de refuerzo pintados
        cylinder("hoop", root, (0.12 + k * 0.24 * math.cos(yaw), 0.22, -0.12 - k * 0.24 * math.sin(yaw)),
                 0.275, 0.06, m["panel"], seg=10, rot=(0, PI / 2, yaw))
    # placa doblada apoyada contra el tanque
    prot = (math.radians(-32), math.radians(6), math.radians(-14))
    bent_plate("plate", root, (-0.16, 0.42, 0.2), 0.84, 0.56, 0.035, 0.12, m["metal"], rot=prot)
    bent_plate("stripe", root, (-0.165, 0.43, 0.21), 0.86, 0.14, 0.04, 0.12, m["panel"], rot=prot)
    # puntal partido clavado en el suelo y escuadra
    cylinder("strut", root, (-0.42, 0.26, -0.24), 0.035, 0.6, m["metal"], seg=6,
             rot=(math.radians(28), math.radians(-18), 0))
    rbox("bracket", root, (0.36, 0.06, 0.24), (0.26, 0.08, 0.16), m["panel"], round_=0.0, subsurf=0,
         rot=(0, 0, math.radians(-40)))
    for ob in root.children_recursive:
        if ob.type == "MESH":
            flat(ob)
    return root


# ---------------- caja de cargamento ----------------

def build_crate(m):
    root = node("material_crate", None, (0, 0, 0))
    W, H = 1.2, 0.92
    rbox("body", root, (0, H / 2, 0), (W, H, W), m["crate"], round_=0.0, subsurf=0)
    # bandas y cantoneras oscuras
    rbox("band_b", root, (0, 0.07, 0), (W + 0.05, 0.14, W + 0.05), m["trim"], round_=0.08, subsurf=0, seg=1)
    # marco superior (4 listones; la tapa queda verde) y franja ambar a media altura
    for sx, sz, w, d in ((0, -1, W + 0.05, 0.1), (0, 1, W + 0.05, 0.1), (-1, 0, 0.1, W + 0.05), (1, 0, 0.1, W + 0.05)):
        rbox("rim", root, (sx * W / 2, H - 0.05, sz * W / 2), (w, 0.1, d), m["trim"], round_=0.0, subsurf=0)
    rbox("stripe", root, (0, H * 0.24, 0), (W + 0.02, 0.12, W + 0.02), m["amber"], round_=0.0, subsurf=0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            rbox("corner", root, (sx * W / 2, H / 2, sz * W / 2), (0.1, H - 0.06, 0.1), m["trim"],
                 round_=0.0, subsurf=0)
    # asas en dos caras y tapa con cierre
    for sx in (-1, 1):
        rbox("handle", root, (sx * (W / 2 + 0.03), H * 0.62, 0), (0.05, 0.07, 0.36), m["trim"],
             round_=0.0, subsurf=0)
    rbox("latch", root, (0, H * 0.78, -(W / 2 + 0.02)), (0.2, 0.12, 0.04), m["trim"], round_=0.0, subsurf=0)
    rbox("label", root, (0, H * 0.46, -(W / 2 + 0.006)), (0.46, 0.22, 0.01), m["trim"], round_=0.0, subsurf=0)
    # piloto (baliza) en la esquina de la tapa
    cylinder("led_base", root, (0.42, H + 0.03, 0.42), 0.07, 0.06, m["trim"], seg=8)
    cylinder("led", root, (0.42, H + 0.09, 0.42), 0.045, 0.07, m["led"], seg=8)
    for ob in root.children_recursive:
        if ob.type == "MESH":
            flat(ob)
    return root


# ---------------- hielo ----------------

def build_ice(m):
    root = node("material_ice", None, (0, 0, 0))
    mound("base", root, (0, 0, 0), 0.7, 0.16, 0.6, m["frost"], 11, seg=10, rings=3)
    rnd = random.Random(5)
    spec = [  # (x, z, radio, alto, inclinacion x, inclinacion z)
        (0.0, 0.0, 0.2, 1.62, 0, 0),
        (0.3, 0.12, 0.15, 1.05, 0, -16),
        (-0.26, 0.16, 0.14, 0.95, 12, 18),
        (0.08, -0.3, 0.13, 0.82, -20, 4),
        (-0.18, -0.2, 0.1, 0.6, -10, 24),
        (0.4, -0.22, 0.09, 0.5, -14, -24),
    ]
    for i, (x, z, r, h, tx, tz) in enumerate(spec):
        prism("crystal%d" % i, root, (x, 0.02, z), r, h, m["ice"],
              rot=(math.radians(tx + rnd.uniform(-3, 3)), 0, math.radians(tz)), seed=20 + i)
    return root


def export_one(build, m, name):
    for ob in list(bpy.data.objects):
        if ob.type in ("MESH", "EMPTY") and ob.name not in ("ground",):
            bpy.data.objects.remove(ob)
    root = build(m)
    to_vertex_colors(root)
    merge_tree(root)
    clean_colors(root)
    t, n = stats()
    path = os.path.join(OUT_DIR, name + ".glb")
    for ob in bpy.data.objects:
        ob.select_set(ob == root or root in ob.parent_recursive if hasattr(ob, "parent_recursive") else False)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for ob in root.children_recursive:
        ob.select_set(True)
    kw = dict(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
              export_extras=False, export_animations=False, use_selection=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("GLB:", path, "tris", t, "meshes", n)
    return root


def main():
    reset()
    os.makedirs(OUT_DIR, exist_ok=True)
    m = mats()
    for build, name in ((build_scrap, "material_scrap"), (build_crate, "material_crate"), (build_ice, "material_ice")):
        export_one(build, m, name)
    if not PREVIEW_DIR:
        return
    # vistas previas: las tres piezas juntas sobre suelo de regolito, y cada una de cerca
    reset()
    m = mats()
    preview_setup(bg=(0.05, 0.05, 0.07))
    bpy.data.materials["ground"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.19, 0.18, 1)
    bpy.data.materials["rock_tint"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.24, 0.22, 0.2, 1)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    roots = []
    for build, x in ((build_scrap, -1.9), (build_crate, 0.0), (build_ice, 1.9)):
        r = build(m)
        to_vertex_colors(r)
        merge_tree(r)
        r.location = G(x, 0, 0)
        roots.append(r)
    shot(os.path.join(PREVIEW_DIR, "collect_all.png"), (0.4, 2.6, -5.4), (0, 0.5, 0), lens=34)
    shot(os.path.join(PREVIEW_DIR, "collect_top.png"), (0.0, 9.0, -6.0), (0, 0.2, 0), lens=30)
    for r, x, nm in zip(roots, (-1.9, 0.0, 1.9), ("scrap", "crate", "ice")):
        shot(os.path.join(PREVIEW_DIR, "collect_%s.png" % nm), (x + 1.4, 1.6, -2.4), (x, 0.45, 0), lens=45)


main()
