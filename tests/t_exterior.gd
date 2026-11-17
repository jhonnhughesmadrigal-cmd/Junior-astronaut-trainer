extends SceneTree
# v40 — Exterior: recolectables, puntos de interes y esclusa de Blender; piezas fijas fusionadas;
# deteccion del tipo de imagen de nasa_data (ERR_PARSE_ERROR de Godot 4.7).
# Uso (copiar a la raiz):  [LOC=Marte] godot --path . --rendering-driver opengl3 --script res://t_exterior.gd
# No guarda ajustes: activa la vista 3D solo en memoria.

const CollectGlb = preload("res://collect_glb.gd")
const NasaData = preload("res://nasa_data.gd")

var main: Node = null
var frame: int = 0
var ok: int = 0
var total: int = 0
var loc: String = "Luna"


func _initialize() -> void:
	Lang.code = "es"
	if OS.get_environment("LOC") != "":
		loc = OS.get_environment("LOC")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
		print("  OK   ", what)
	else:
		print("  FALLA ", what)


func _glb_tris(path: String) -> int:
	var t: int = 0
	var n: Node = (load(path) as PackedScene).instantiate()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var idx = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			t += (idx as PackedInt32Array).size() / 3 if idx != null else 0
	n.free()
	return t


func _xf_of(cm, i: int) -> Transform3D:
	var mmi: MultiMeshInstance3D = cm.chunks[cm.chunk_of[i]]
	return mmi.multimesh.get_instance_transform(cm.local_i[i])


func _tiles(ch: String) -> Array:
	var out: Array = []
	var rows: Array = main.get("ext_rows")
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == ch:
				out.append(Vector2i(x, y))
	return out


func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		var pui: Control = main.get_node_or_null("ProfileUI")
		if pui != null:
			pui.visible = false
		main.set("show_tutorial", false)
		main.set("view3d_on", true)     # solo en memoria (no llama a _save_settings)
		main.set("cam_mode", 0)
		main.call("_new_game", loc)
	if frame == 30:
		print("EXTERIOR v40 (", loc, ")")
		var v: Node3D = main.get("view3d")
		var ext: Node3D = v.get("exterior")
		# 1) archivos y presupuesto de triangulos de los recolectables (salen cientos)
		for k in ["material_scrap", "material_crate", "material_ice"]:
			var p: String = "res://art/3d/%s.glb" % k
			check(ResourceLoader.exists(p), "existe " + p)
			if ResourceLoader.exists(p):
				var t: int = _glb_tris(p)
				check(t > 0 and t < 800, "%s: %d triangulos (< 800)" % [k, t])
		for k in ["landmark_apollo", "landmark_rover", "landmark_plaque", "landmark_wreck", "airlock_ext"]:
			check(ResourceLoader.exists("res://art/3d/ext/%s.glb" % k), "existe art/3d/ext/%s.glb" % k)
		# 2) recolectables: partes en ChunkMM (refresh_nodes las oculta sin error) y destellos del hielo
		var nd: Array = v.get("node_data")
		var bad: int = 0
		for e in nd:
			for part in e["parts"]:
				if part[0] is MultiMeshInstance3D or not (part[0] as Object).has_method("set_xf"):
					bad += 1
		check(nd.size() > 0 and bad == 0, "%d recolectables con sus piezas en ChunkMM (malas: %d)" % [nd.size(), bad])
		var n_tiles: int = _tiles("m").size() + _tiles("i").size() + _tiles("c").size()
		check(nd.size() == n_tiles, "un recolectable por casilla m/i/c (%d / %d)" % [nd.size(), n_tiles])
		check((v.get("ice_pts") as PackedVector3Array).size() > 0, "hay puntos de destello del hielo (%d)" % (v.get("ice_pts") as PackedVector3Array).size())
		# 3) recoger y reaparecer: se oculta (HIDDEN) y vuelve a su sitio
		if nd.size() > 0:
			var e0: Dictionary = nd[0]
			var key: String = main.call("_node_key", int(e0["x"]), int(e0["y"]))
			var dep: Dictionary = main.get("depleted")
			dep[key] = int(main.get("day"))
			v.call("refresh_nodes")
			var p0: Array = e0["parts"][0]
			check(_xf_of(p0[0], p0[1]).origin.y < -100.0, "al recogerlo se oculta (refresh_nodes sin error)")
			dep.erase(key)
			v.call("refresh_nodes")
			check(_xf_of(p0[0], p0[1]).origin.distance_to((p0[2] as Transform3D).origin) < 0.01, "al reaparecer vuelve a su sitio")
		# 4) tinte de zona en la chatarra (material rock_tint)
		var tinted: int = 0
		for mmi in ext.find_children("*", "MultiMeshInstance3D", true, false):
			var mat: BaseMaterial3D = (mmi as MultiMeshInstance3D).material_override as BaseMaterial3D
			if mat != null and mat.resource_name.begins_with("rock_tint") and mat.vertex_color_use_as_albedo:
				tinted += 1
		check(tinted > 0, "la chatarra usa el color de la zona (rock_tint) en %d bloques" % tinted)
		# 5) puntos de interes y esclusa de Blender
		var lms: Array = []
		for c in ext.get_children():
			if c.has_meta("v40_landmark"):
				lms.append(c)
		check(lms.size() == _tiles("L").size() and lms.size() > 0, "puntos de interes de Blender: %d / %d" % [lms.size(), _tiles("L").size()])
		check(ext.find_child("AirlockExt", false, false) != null, "esclusa exterior de Blender")
		check((v.get("led_mats") as Array).size() > 0, "los LED animados siguen (por codigo)")
		# 6) piezas fijas fusionadas: pocas MeshInstance3D sueltas (v39: 164)
		var loose: int = 0
		for c in ext.get_children():
			if c is MeshInstance3D:
				loose += 1
		check(loose < 60, "piezas sueltas del exterior: %d (v39: 164)" % loose)
		# 7) sin modelo: place() devuelve false y view3d usa el modelo por codigo
		var g := RandomNumberGenerator.new()
		check(not CollectGlb.place(v, "material_no_existe", 1.0, [Vector2i(1, 1)], g, Callable()), "sin .glb devuelve false (modelo por codigo)")
		# 8) nasa_data: tipo de imagen por la firma (sin probar JPEG sobre un PNG)
		check(NasaData.image_kind(PackedByteArray([0xFF, 0xD8, 0xFF, 0xE0])) == "jpg", "firma JPEG")
		check(NasaData.image_kind(PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) == "png", "firma PNG")
		check(NasaData.image_kind(PackedByteArray([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50])) == "webp", "firma WebP")
		check(NasaData.image_kind("<html>".to_ascii_buffer()) == "", "HTML no se intenta cargar como imagen")
		print("RESULTADO: %d/%d" % [ok, total])
		quit(0 if ok == total else 1)
	return false
