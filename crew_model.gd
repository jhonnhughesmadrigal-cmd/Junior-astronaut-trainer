extends RefCounted
# v39 — Astronauta modelado en Blender (art/3d/astronaut.glb, generado con tools/blender/astronaut.py).
# El modelo trae las piezas colgadas de nodos con los mismos nombres y puntos de giro que el modelo por
# codigo de view3d.gd, asi _anim_astronaut lo anima igual (sin esqueleto). Los materiales del .glb se
# sustituyen por nombre por los del juego: asi el color de rol (franjas, parche) sigue saliendo de CrewLook.
# Si el .glb no existe o le falta alguna pieza, build() devuelve null y view3d usa el modelo por codigo.

const JOINTS: Array = ["rig", "body", "head", "pack", "ant", "arm_l", "elb_l", "arm_r", "elb_r",
	"leg_l", "kn_l", "leg_r", "kn_r"]
const SMALL: float = 0.14   # piezas menores que esto (metros) no proyectan sombra: menos coste en moviles


static func build(ps: PackedScene, mats: Dictionary) -> Node3D:
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	if n == null:
		return null
	var parts: Dictionary = {}
	for nm in JOINTS:
		var j: Node3D = n.find_child(nm, true, false) as Node3D
		if j == null:
			push_warning("astronaut.glb: falta el nodo '%s'; se usa el modelo por codigo" % nm)
			n.free()
			return null
		parts[nm] = j
	_apply(n, mats)
	n.set_meta("parts", parts)
	return n


static func _apply(node: Node, mats: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(i)
				if m != null and mats.has(m.resource_name):
					mi.set_surface_override_material(i, mats[m.resource_name])
			var s: Vector3 = mi.mesh.get_aabb().size
			if maxf(s.x, maxf(s.y, s.z)) < SMALL:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_apply(c, mats)


static func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


# Dra. Yarisbel (medica): cruz blanca sobre el parche de rol del pecho
static func add_cross(body: Node3D, white: Material) -> void:
	_box(body, Vector3(0.062, 0.018, 0.016), white, Vector3(-0.15, 1.4, -0.224))
	_box(body, Vector3(0.018, 0.062, 0.016), white, Vector3(-0.15, 1.4, -0.224))


# Ing. Enoc: martillo en la mano derecha (oculto hasta que trabaja); igual que en el modelo por codigo
static func add_hammer(elbow_r: Node3D) -> Node3D:
	var hm := Node3D.new()
	elbow_r.add_child(hm)
	_box(hm, Vector3(0.05, 0.05, 0.55), _mat(Color(0.6, 0.4, 0.2), 0.0, 0.8), Vector3(0, -0.36, -0.22))
	_box(hm, Vector3(0.12, 0.13, 0.2), _mat(Color(0.75, 0.77, 0.85), 0.9, 0.3), Vector3(0, -0.36, -0.5))
	hm.visible = false
	return hm
