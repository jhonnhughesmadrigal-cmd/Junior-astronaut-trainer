# Mision Perseo - utilidades comunes para los scripts de Blender (astronaut.py, stations.py).
# Las medidas se escriben en ejes de Godot (Y arriba, -Z adelante); G() las pasa a Blender (Z arriba).
# El exportador glTF las devuelve a ejes de Godot.

import math
import os

import bmesh
import bpy
from mathutils import Vector

TAU = math.tau


def G(x, y, z):
    return Vector((x, -z, y))


def lin(c):
    # color sRGB (como en Godot) -> lineal (Blender)
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def col():
    return bpy.context.scene.collection


# ---------- materiales ----------

def material(name, color, metal=0.0, rough=0.6, emit=0.0, alpha=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes.get("Principled BSDF")
    rgba = lin(color) + (1.0,)
    b.inputs["Base Color"].default_value = rgba
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = rgba
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(m, attr, val)
                break
            except Exception:
                continue
    m.diffuse_color = lin(color) + (alpha,)
    return m


# ---------- nodos y mallas ----------

def node(name, parent, gpos, grot=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.06
    col().objects.link(e)
    e.parent = parent
    e.location = G(*gpos)
    if grot:
        e.rotation_euler = grot
    return e


def finish(name, bm, parent, gpos, mat, smooth=True, sharp_deg=0.0, rot=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth and sharp_deg > 0.0 and hasattr(me, "set_sharp_from_angle"):
        me.set_sharp_from_angle(angle=math.radians(sharp_deg))
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    col().objects.link(ob)
    ob.parent = parent
    ob.location = G(*gpos)
    if rot:
        ob.rotation_euler = rot
    return ob


def rbox(name, parent, gpos, size, mat, taper_bottom=1.0, taper_top=1.0, round_=0.35, subsurf=1, rot=None, seg=2):
    # caja de bordes redondeados. size = (ancho, alto, fondo) en ejes de Godot
    w, h, d = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        x, y, z = v.co
        t = taper_bottom if z < 0 else taper_top
        v.co.x = x * w * t
        v.co.y = y * d * t
        v.co.z = z * h
    ob = finish(name, bm, parent, gpos, mat, sharp_deg=0.0 if subsurf else 0.0, rot=rot)
    if round_ > 0.0:
        bev = ob.modifiers.new("bevel", "BEVEL")
        bev.width = min(w, h, d) * round_ * 0.5
        bev.segments = seg
        bev.limit_method = "NONE"
        if hasattr(bev, "harden_normals"):
            bev.harden_normals = subsurf == 0
    if subsurf:
        ss = ob.modifiers.new("subsurf", "SUBSURF")
        ss.levels = subsurf
        ss.render_levels = subsurf
    elif round_ <= 0.0:
        for p in ob.data.polygons:
            p.use_smooth = False
    return ob


def ellipsoid(name, parent, gpos, rx, ry, rz, mat, seg=12, rings=8, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * rx, v.co.y * rz, v.co.z * ry))
    return finish(name, bm, parent, gpos, mat, rot=rot)


def cylinder(name, parent, gpos, r, h, mat, seg=16, r2=None, rot=None, axis="y"):
    # cilindro a lo largo del eje de Godot indicado (y vertical por defecto)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
                          radius2=r if r2 is None else r2, depth=h)
    if rot is None:
        rot = {"y": None, "x": (0, math.pi / 2, 0), "z": (math.pi / 2, 0, 0)}[axis]
    return finish(name, bm, parent, gpos, mat, sharp_deg=50.0, rot=rot)


def torus(name, parent, gpos, R, r, mat, seg=18, ring=6, sx=1.0, sz=1.0, rot=None, axis="y"):
    # anillo alrededor del eje de Godot indicado (y: anillo horizontal)
    bm = bmesh.new()
    grid = []
    for i in range(seg):
        a = TAU * i / seg
        row = []
        for j in range(ring):
            b = TAU * j / ring
            rr = R + r * math.cos(b)
            row.append(bm.verts.new((rr * math.cos(a) * sx, rr * math.sin(a) * sz, r * math.sin(b))))
        grid.append(row)
    for i in range(seg):
        for j in range(ring):
            bm.faces.new((grid[i][j], grid[(i + 1) % seg][j], grid[(i + 1) % seg][(j + 1) % ring],
                          grid[i][(j + 1) % ring]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if rot is None:
        rot = {"y": None, "x": (0, math.pi / 2, 0), "z": (math.pi / 2, 0, 0)}[axis]
    return finish(name, bm, parent, gpos, mat, rot=rot)


def lathe(name, parent, gpos, prof, mat, seg=16, sx=1.0, sz=1.0, sharp_deg=0.0, rot=None, caps=True):
    # solido de revolucion alrededor del eje vertical. prof = [(radio, altura), ...] de arriba abajo;
    # radio 0 cierra la pieza en el eje
    bm = bmesh.new()
    rings = []
    for r, y in prof:
        if r <= 1e-5:
            rings.append([bm.verts.new((0.0, 0.0, y))])
        else:
            rings.append([bm.verts.new((r * math.cos(TAU * i / seg) * sx, r * math.sin(TAU * i / seg) * sz, y))
                          for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        if len(a) > 1 and len(b) > 1:
            for i in range(seg):
                bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
        elif len(a) == 1 and len(b) > 1:
            for i in range(seg):
                bm.faces.new((a[0], b[(i + 1) % seg], b[i]))
        elif len(b) == 1 and len(a) > 1:
            for i in range(seg):
                bm.faces.new((a[i], a[(i + 1) % seg], b[0]))
    for rg in (rings[0], rings[-1]):
        if caps and len(rg) > 1:
            bm.faces.new(rg)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return finish(name, bm, parent, gpos, mat, sharp_deg=sharp_deg, rot=rot)


def tube(name, parent, gpoints, radius, mat, res=5):
    # manguera o cable: curva suave convertida en malla
    cu = bpy.data.curves.new(name + "_c", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 1
    cu.resolution_u = res
    sp = cu.splines.new("NURBS")
    sp.points.add(len(gpoints) - 1)
    for i, p in enumerate(gpoints):
        sp.points[i].co = tuple(G(*p)) + (1.0,)
    sp.use_endpoint_u = True
    sp.order_u = 3
    tmp = bpy.data.objects.new(name + "_tmp", cu)
    col().objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    for p in me.polygons:
        p.use_smooth = True
    me.materials.clear()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    col().objects.link(ob)
    ob.parent = parent
    return ob


# ---------- fusion por material (menos llamadas de dibujo en Godot) ----------

def merge_tree(root):
    # Bajo cada nodo, une en una sola malla las piezas hijas que comparten material.
    # Los nodos (vacios) se conservan: son los que se animan.
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    nodes = [root] + [o for o in root.children_recursive if o.type == "EMPTY"]
    for nd in nodes:
        groups = {}
        for ch in list(nd.children):
            if ch.type == "MESH" and ch.data.materials:
                groups.setdefault(ch.data.materials[0].name, []).append(ch)
        for mname, obs in groups.items():
            if len(obs) < 2:
                continue
            bm = bmesh.new()
            for ob in obs:
                me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
                me2.transform(ob.matrix_local)
                bm.from_mesh(me2)
                bpy.data.meshes.remove(me2)
            me = bpy.data.meshes.new(nd.name + "_" + mname)
            bm.to_mesh(me)
            bm.free()
            me.materials.clear()
            me.materials.append(bpy.data.materials[mname])
            for ob in obs:
                bpy.data.objects.remove(ob)
            ob = bpy.data.objects.new(nd.name + "_" + mname, me)
            col().objects.link(ob)
            ob.parent = nd
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()


def stats():
    dg = bpy.context.evaluated_depsgraph_get()
    tris = 0
    meshes = 0
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            meshes += 1
            me = ob.evaluated_get(dg).to_mesh()
            me.calc_loop_triangles()
            tris += len(me.loop_triangles)
            ob.evaluated_get(dg).to_mesh_clear()
    return tris, meshes


def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                              export_extras=False, export_animations=False)


# ---------- vistas previas ----------

def preview_setup(ground=True, bg=(0.08, 0.09, 0.13)):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
        try:
            sc.render.engine = eng
            break
        except Exception:
            continue
    if sc.render.engine == "CYCLES":
        sc.cycles.samples = 48
    sc.render.resolution_x = 1600
    sc.render.resolution_y = 900
    try:
        sc.view_settings.view_transform = "AgX"
    except Exception:
        pass
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = lin(bg) + (1.0,)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = world
    if ground:
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
        finish("ground", bm, None, (0, 0.0, 0), material("ground", (0.4, 0.4, 0.42), 0.0, 0.9), smooth=False)

    def light(name, kind, gpos, energy, color=(1, 1, 1), size=1.0):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = color
        if hasattr(ld, "size"):
            ld.size = size
        lo = bpy.data.objects.new(name, ld)
        col().objects.link(lo)
        lo.location = G(*gpos)
        d = (G(0, 1.0, 0) - lo.location).normalized()
        lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

    light("sun", "SUN", (3, 6, -4), 3.5, (1.0, 0.97, 0.92))
    light("fill", "AREA", (-6, 4, -4), 600, (0.6, 0.7, 1.0), 5.0)
    light("rim", "AREA", (3, 4, 6), 700, (1.0, 0.85, 0.7), 4.0)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    col().objects.link(cam)
    sc.camera = cam
    return cam


def shot(path, gpos, gtarget, lens=40):
    sc = bpy.context.scene
    cam = sc.camera
    cam.data.lens = lens
    cam.location = G(*gpos)
    d = (G(*gtarget) - cam.location).normalized()
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("PREVIEW:", path)
