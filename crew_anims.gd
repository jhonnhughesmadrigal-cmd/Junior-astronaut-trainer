extends RefCounted
# v41 — Animaciones del astronauta hechas en Blender (tools/blender/anims.py -> art/3d/anim/astronaut_<nombre>.glb).
# Se muestrean en un instante u (0-1) y devuelven objetivos con las mismas claves que view3d._anim_astronaut
# (rig_y, body_x, head_x, head_y, al_x, ar_x, al_z, ar_z, el_x, er_x, ll_x, lr_x, kl_x, kr_x). Asi la animacion
# de Blender sustituye a la pose por codigo sin cambiar el modelo ni sus articulaciones.
# Si falta el .glb, sample() devuelve {} y view3d usa la pose por codigo.

const DIR: String = "res://art/3d/anim/"
# articulacion -> [clave del eje X, clave del eje Y, clave del eje Z] ("" = no se usa)
const MAP: Dictionary = {
	"body": ["body_x", "", ""], "head": ["head_x", "head_y", ""],
	"arm_l": ["al_x", "", "al_z"], "arm_r": ["ar_x", "", "ar_z"],
	"elb_l": ["el_x", "", ""], "elb_r": ["er_x", "", ""],
	"leg_l": ["ll_x", "", ""], "leg_r": ["lr_x", "", ""],
	"kn_l": ["kl_x", "", ""], "kn_r": ["kr_x", "", ""],
}

static var _anims: Dictionary = {}   # nombre -> Array de [Animation, articulacion o ""] (vacio si no existe)


# El exportador glTF de Blender 5.3 escribe una animacion por objeto (nombre = articulacion), con pistas fijas
# para los demas nodos; otras versiones escriben una sola animacion. Se guarda cada animacion con la
# articulacion que le corresponde ("" = todas las pistas valen).
static func _load(nm: String) -> Array:
	if _anims.has(nm):
		return _anims[nm]
	var list: Array = []
	var path: String = DIR + "astronaut_" + nm + ".glb"
	if ResourceLoader.exists(path):
		var root: Node = (load(path) as PackedScene).instantiate()
		for c in root.find_children("*", "AnimationPlayer", true, false):
			var ap: AnimationPlayer = c
			var names: PackedStringArray = ap.get_animation_list()
			for an in names:
				var only: String = str(an) if names.size() > 1 and (MAP.has(str(an)) or str(an) == "rig") else ""
				list.append([ap.get_animation(an), only])
		root.free()
	_anims[nm] = list
	return list


static func get_anim(nm: String) -> Animation:
	var l: Array = _load(nm)
	return null if l.is_empty() else l[0][0]


static func has(nm: String) -> bool:
	return not _load(nm).is_empty()


# Objetivos de pose en el instante u (0-1) de la animacion nm. {} si no hay animacion.
static func sample(nm: String, u: float) -> Dictionary:
	var out: Dictionary = {}
	for pair in _load(nm):
		_sample_one(pair[0], str(pair[1]), u, out)
	return out


static func _sample_one(a: Animation, only: String, u: float, out: Dictionary) -> void:
	var t: float = clampf(u, 0.0, 1.0) * a.length
	for i in a.get_track_count():
		var np: NodePath = a.track_get_path(i)
		var jn: String = str(np.get_name(np.get_name_count() - 1))
		if only != "" and jn != only:
			continue
		match a.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				if not MAP.has(jn):
					continue
				var e: Vector3 = Basis(a.rotation_track_interpolate(i, t)).get_euler(EULER_ORDER_YZX)   # = orden XYZ de Blender visto en ejes de Godot (comprobado)
				var keys: Array = MAP[jn]
				for ax in 3:
					if str(keys[ax]) != "":
						out[keys[ax]] = e[ax]
			Animation.TYPE_POSITION_3D:
				if jn == "rig":
					out["rig_y"] = a.position_track_interpolate(i, t).y
