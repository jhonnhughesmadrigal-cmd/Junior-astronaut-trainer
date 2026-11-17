extends RefCounted
# v40 — Recolectables modelados en Blender (art/3d/material_scrap.glb, material_crate.glb, material_ice.glb;
# los genera tools/blender/collectables.py). Sustituye a view3d._place_glb_nodes, que:
#   - usaba un MultiMesh unico para todo el mapa (sin descarte por bloques) y
#   - guardaba MultiMeshInstance3D en node_data, mientras refresh_nodes() espera ChunkMM (error al recoger).
# Aqui cada superficie (material) del modelo es un ChunkMM: mismos bloques que los modelos por codigo.
# Materiales con nombre especial (ver cabecera de collectables.py); los *_vc llevan color por vertice:
#   rock_tint -> se multiplica por el color de la zona (color por instancia, como las rocas)
#   led       -> sin sombra
#   ice       -> genera los puntos de destello del hielo (view3d.ice_pts) para world_fx.gd
# Si falta el .glb devuelve false y view3d usa el modelo por codigo.

static var _mat_cache: Dictionary = {}


static func _surface_parts(v: Node3D, kind: String, size: float) -> Array:
	# [{mesh: ArrayMesh de 1 superficie, mat: Material, name: String, xf: Transform3D}]
	var out: Array = []
	for pt in v.call("_glb_parts", kind, size):
		var m: Mesh = pt["mesh"]
		for s in m.get_surface_count():
			var arrs: Array = m.surface_get_arrays(s)
			# El color por vertice del glTF es lineal, pero con el renderizador del juego (Compatibilidad)
			# se veia oscurecido dos veces (comprobado con capturas A/B en v40): se pasa a sRGB al cargar.
			if arrs[Mesh.ARRAY_COLOR] != null:
				var cs: PackedColorArray = arrs[Mesh.ARRAY_COLOR]
				for ci in cs.size():
					cs[ci] = cs[ci].linear_to_srgb()
				arrs[Mesh.ARRAY_COLOR] = cs
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(m.surface_get_primitive_type(s), arrs)
			var mat: Material = m.surface_get_material(s)
			var nm: String = ""
			if mat != null:
				nm = mat.resource_name
			var vc: bool = m.surface_get_arrays(s)[Mesh.ARRAY_COLOR] != null
			out.append({"mesh": am, "mat": _prep_mat(kind, nm, mat, vc), "name": nm, "xf": pt["xf"]})
	return out


static func _prep_mat(kind: String, nm: String, mat: Material, vcol: bool) -> Material:
	var key: String = kind + "/" + nm
	if _mat_cache.has(key):
		return _mat_cache[key]
	var res: Material = mat
	if mat is BaseMaterial3D:
		var b: BaseMaterial3D = (mat as BaseMaterial3D).duplicate()
		if nm.begins_with("rock_tint") or vcol:
			# rock_tint: el color de la instancia (zona) tine el material.
			# *_vc: color por vertice (varias piezas de distinto color en un solo material = menos llamadas)
			b.vertex_color_use_as_albedo = true
		res = b
	elif mat == null:
		res = StandardMaterial3D.new()
	_mat_cache[key] = res
	return res


# Coloca el modelo en cada casilla. tint: Callable(Vector2i) -> Color (color de la zona) o Callable() vacio.
static func place(v: Node3D, kind: String, size: float, tiles: Array, g: RandomNumberGenerator, tint: Callable) -> bool:
	if tiles.is_empty():
		return false
	var parts: Array = _surface_parts(v, kind, size)
	if parts.is_empty():
		return false
	var parent: Node3D = v.get("exterior")
	var cms: Array = []
	for pt in parts:
		var led: bool = String(pt["name"]).begins_with("led")
		cms.append(v.call("_make_mm_c", parent, pt["mesh"], pt["mat"], tiles, 1, not led))
	var nd: Array = v.get("node_data")
	for i in tiles.size():
		var p: Vector2i = tiles[i]
		var gy: float = v.call("ground_y", float(p.x) + 0.5, float(p.y) + 0.5)
		var base: Transform3D = v.call("_xf", v.call("_tp", p.x, p.y, gy), g.randf() * TAU, Vector3.ONE)
		var zc: Color = tint.call(p) if tint.is_valid() else Color.WHITE
		var plist: Array = []
		for k in parts.size():
			var xf: Transform3D = base * (parts[k]["xf"] as Transform3D)
			var cm = cms[k]
			cm.set_xf(i, xf)
			cm.set_col(i, zc if String(parts[k]["name"]).begins_with("rock_tint") else Color.WHITE)
			plist.append([cm, i, xf])
		if kind == "material_ice":
			# destellos: dos puntos a media altura del grupo de cristales
			var ip: PackedVector3Array = v.get("ice_pts")
			ip.append(base.origin + Vector3(0, size * 0.45, 0))
			ip.append(base.origin + base.basis * Vector3(0.25, size * 0.3, 0.1))
			v.set("ice_pts", ip)
		nd.append({"x": p.x, "y": p.y, "hidden": false, "parts": plist})
	return true
