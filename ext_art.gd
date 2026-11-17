extends RefCounted
# v40 — Arte del exterior (solo dibujo):
#   - Esclusa vista desde fuera (art/3d/ext/airlock_ext.glb) y puntos de interes 'L' modelados en Blender (art/3d/ext/landmark_<tipo>.glb, de tools/blender/landmarks.py):
#     escala real en metros, origen en el suelo. Si falta el .glb, view3d usa el modelo por codigo.
#   - merge_static: fusiona por material las piezas fijas del exterior de la base (casco, ventanas,
#     plataforma, cables, equipo...). _m() de view3d comparte materiales por color, asi que ~160 piezas
#     sueltas quedan en unas pocas mallas: menos llamadas de dibujo. Los LED (material propio animado) y
#     los nodos con hijos no se tocan.

const InteriorLook = preload("res://interior_look.gd")
const EXT_DIR: String = "res://art/3d/ext/"

static var _scenes: Dictionary = {}


static func landmark(lm: String) -> Node3D:
	var path: String = EXT_DIR + "landmark_" + lm + ".glb"
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scenes[path]
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	n.name = "Landmark_" + lm
	n.set_meta("v40_landmark", lm)   # para las pruebas (Godot renombra los hermanos repetidos)
	return n


# Esclusa vista desde fuera (art/3d/ext/airlock_ext.glb). pos = centro de la pared sur a ras de suelo.
# Devuelve false si no hay modelo (view3d dibuja la esclusa por codigo).
static func airlock(parent: Node3D, pos: Vector3) -> bool:
	var path: String = EXT_DIR + "airlock_ext.glb"
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scenes[path]
	if ps == null:
		return false
	var n: Node3D = ps.instantiate()
	n.name = "AirlockExt"
	n.position = pos
	parent.add_child(n)
	return true


# Devuelve cuantas piezas desaparecen (piezas fusionadas - mallas nuevas).
static func merge_static(parent: Node3D) -> int:
	return InteriorLook.merge_static(parent)
