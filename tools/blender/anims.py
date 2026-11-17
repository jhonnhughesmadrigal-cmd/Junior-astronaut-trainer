# Mision Perseo - animaciones del astronauta (Blender 4.x / 5.x, en segundo plano).
#
#   blender --background --factory-startup --python tools/blender/anims.py -- <carpeta_salida> [carpeta_previews]
#
# Genera <carpeta_salida>/astronaut_jump.glb y astronaut_collect.glb (normalmente art/3d/anim/).
# Cada archivo tiene UNA animacion de 1 s (24 fps) sobre vacios con los mismos nombres que las articulaciones
# del astronauta (rig, body, head, arm_l, elb_l, arm_r, elb_r, leg_l, kn_l, leg_r, kn_r). crew_anims.gd la
# muestrea y aplica los angulos a las articulaciones (las poses por codigo siguen para el resto de acciones):
#   jump     0.00 agacharse (anticipacion) · 0.12 impulso · 0.35 recogido en el aire · 0.65 abre brazos al bajar
#            · 0.85 toca el suelo · 1.00 amortigua (rodillas flexionadas). El juego recorre 0.12-0.85 en el aire
#            y 0.85-1.00 al aterrizar.
#   collect  0.00 mira al suelo · 0.20 rodilla al suelo · 0.40 alcanza · 0.55 agarra · 0.70 levanta y mira la
#            pieza · 0.85 la lleva a la mochila · 1.00 de pie. El juego la recorre con el avance de la tarea.
# Convencion de angulos (ejes de Godot): rotacion X de cada articulacion (adelante = positivo en brazos y
# piernas, igual que view3d._anim_astronaut); rotacion Z solo en hombros (abrir brazos); altura del rig en Y.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

from bkit import G, node, reset  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.abspath("art/3d/anim")
FPS = 24

JOINTS = {  # nombre: (padre, posicion de reposo en ejes de Godot)
    "rig": (None, (0, 0, 0)),
    "body": ("rig", (0, 0, 0)),
    "head": ("body", (0, 1.66, 0)),
    "arm_l": ("body", (-0.34, 1.48, 0)),
    "elb_l": ("arm_l", (0, -0.34, 0)),
    "arm_r": ("body", (0.34, 1.48, 0)),
    "elb_r": ("arm_r", (0, -0.34, 0)),
    "leg_l": ("rig", (-0.15, 0.68, 0)),
    "kn_l": ("leg_l", (0, -0.34, 0)),
    "leg_r": ("rig", (0.15, 0.68, 0)),
    "kn_r": ("leg_r", (0, -0.34, 0)),
}

# Claves de pose -> (articulacion, eje). Mismas claves que view3d._anim_astronaut (tg[...]).
KEYMAP = {
    "body_x": ("body", "x"), "head_x": ("head", "x"), "head_y": ("head", "y"),
    "al_x": ("arm_l", "x"), "ar_x": ("arm_r", "x"), "al_z": ("arm_l", "z"), "ar_z": ("arm_r", "z"),
    "el_x": ("elb_l", "x"), "er_x": ("elb_r", "x"),
    "ll_x": ("leg_l", "x"), "lr_x": ("leg_r", "x"), "kl_x": ("kn_l", "x"), "kr_x": ("kn_r", "x"),
}
NEUTRAL = {"rig_y": 0.0, "body_x": 0.0, "head_x": 0.0, "head_y": 0.0, "al_x": 0.0, "ar_x": 0.0, "al_z": 0.06,
           "ar_z": -0.06, "el_x": 0.12, "er_x": 0.12, "ll_x": 0.0, "lr_x": 0.0, "kl_x": 0.0, "kr_x": 0.0}

JUMP = [
    (0.00, {"rig_y": -0.2, "body_x": -0.35, "head_x": 0.2, "al_x": -0.7, "ar_x": -0.7, "el_x": 0.4, "er_x": 0.4,
            "ll_x": 0.85, "lr_x": 0.85, "kl_x": -1.5, "kr_x": -1.5}),
    (0.12, {"rig_y": 0.06, "body_x": 0.1, "head_x": -0.2, "al_x": 2.7, "ar_x": 2.7, "al_z": 0.25, "ar_z": -0.25,
            "el_x": 0.2, "er_x": 0.2, "ll_x": -0.15, "lr_x": -0.1, "kl_x": -0.1, "kr_x": -0.15}),
    (0.35, {"rig_y": 0.1, "body_x": -0.22, "head_x": -0.1, "al_x": 1.5, "ar_x": 1.6, "al_z": 0.3, "ar_z": -0.3,
            "el_x": 0.9, "er_x": 0.9, "ll_x": 1.0, "lr_x": 0.85, "kl_x": -1.6, "kr_x": -1.45}),
    (0.65, {"rig_y": 0.04, "body_x": -0.05, "head_x": 0.15, "al_x": 1.1, "ar_x": 1.1, "al_z": 0.95, "ar_z": -0.95,
            "el_x": 0.35, "er_x": 0.35, "ll_x": 0.35, "lr_x": 0.15, "kl_x": -0.5, "kr_x": -0.3}),
    (0.85, {"rig_y": 0.0, "body_x": -0.1, "head_x": 0.1, "al_x": 0.9, "ar_x": 0.9, "al_z": 0.7, "ar_z": -0.7,
            "el_x": 0.3, "er_x": 0.3, "ll_x": 0.25, "lr_x": 0.25, "kl_x": -0.25, "kr_x": -0.25}),
    (1.00, {"rig_y": -0.24, "body_x": -0.42, "head_x": 0.25, "al_x": 0.8, "ar_x": 0.8, "al_z": 0.35, "ar_z": -0.35,
            "el_x": 0.7, "er_x": 0.7, "ll_x": 0.95, "lr_x": 0.95, "kl_x": -1.6, "kr_x": -1.6}),
]

COLLECT = [
    (0.00, {"head_x": 0.35, "body_x": -0.1}),
    (0.20, {"rig_y": -0.36, "body_x": -0.4, "head_x": 0.4, "ll_x": 1.45, "kl_x": -2.25, "lr_x": 0.25, "kr_x": -1.15,
            "al_x": 0.5, "ar_x": 0.9, "el_x": 0.6, "er_x": 0.5}),
    (0.40, {"rig_y": -0.38, "body_x": -0.62, "head_x": 0.45, "ll_x": 1.45, "kl_x": -2.25, "lr_x": 0.25, "kr_x": -1.15,
            "al_x": 1.2, "ar_x": 1.95, "el_x": 0.4, "er_x": 0.15}),
    (0.55, {"rig_y": -0.38, "body_x": -0.6, "head_x": 0.45, "ll_x": 1.45, "kl_x": -2.25, "lr_x": 0.25, "kr_x": -1.15,
            "al_x": 1.3, "ar_x": 1.9, "el_x": 0.5, "er_x": 0.55}),
    (0.70, {"rig_y": -0.12, "body_x": -0.15, "head_x": 0.15, "head_y": 0.3, "ll_x": 0.6, "kl_x": -0.9, "lr_x": 0.1,
            "kr_x": -0.4, "al_x": 0.9, "ar_x": 1.5, "el_x": 1.2, "er_x": 1.75}),
    (0.85, {"rig_y": -0.02, "body_x": -0.08, "head_x": 0.05, "head_y": -0.45, "al_x": 0.3, "ar_x": 2.9,
            "ar_z": -0.45, "el_x": 0.4, "er_x": 1.3}),
    (1.00, {}),
]


def build():
    reset()
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    sc.frame_end = FPS
    objs = {}
    for nm, (par, pos) in JOINTS.items():
        objs[nm] = node(nm, objs[par] if par else None, pos)
        objs[nm].rotation_mode = "XYZ"
    return objs


def key_pose(objs, frame, pose):
    p = dict(NEUTRAL)
    p.update(pose)
    rot = {nm: [0.0, 0.0, 0.0] for nm in JOINTS}
    for k, (j, ax) in KEYMAP.items():
        v = p.get(k, 0.0)
        # ejes de Godot -> Blender: X igual; Y de Godot = Z de Blender; Z de Godot = -Y de Blender
        if ax == "x":
            rot[j][0] = v
        elif ax == "y":
            rot[j][2] = v
        else:
            rot[j][1] = -v
    for nm, ob in objs.items():
        ob.rotation_euler = rot[nm]
        ob.keyframe_insert("rotation_euler", frame=frame)
    rig = objs["rig"]
    rig.location = G(0, p["rig_y"], 0)
    rig.keyframe_insert("location", frame=frame)


def export(objs, keys, path):
    for t, pose in keys:
        key_pose(objs, round(t * FPS), pose)
    for ob in objs.values():
        if ob.animation_data and ob.animation_data.action:
            act = ob.animation_data.action
            curves = getattr(act, "fcurves", None)
            if curves is None:
                continue
            for fc in curves:
                for kp in fc.keyframe_points:
                    kp.interpolation = "BEZIER"
                    kp.easing = "AUTO"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kw = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=True, export_extras=False)
    for extra in ({"export_animation_mode": "SCENE"}, {}):
        try:
            bpy.ops.export_scene.gltf(**kw, **extra)
            break
        except TypeError:
            continue
    print("GLB:", path)


def main():
    objs = build()
    export(objs, JUMP, os.path.join(OUT_DIR, "astronaut_jump.glb"))
    objs = build()
    export(objs, COLLECT, os.path.join(OUT_DIR, "astronaut_collect.glb"))


main()
