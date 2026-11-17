extends SceneTree
# Mide (v28; v40 corregido): tiempo de crear la partida, primitivas/llamadas de dibujo por fotograma y
# recuento de la escena (superficies y triangulos de todo lo que cuelga del exterior o del interior).
# Uso: cp tests/t_perf.gd . && LOC=Luna Q=2 [INSIDE=1: dentro de la base] [EV=breach|storm (v41)] godot --path . --rendering-driver opengl3 --script res://t_perf.gd
# (en Linux sin pantalla: xvfb-run -a godot ...). Opcional: SNAP=/ruta.png guarda lo que ve la camara.
# Cifras RELATIVAS (equipo de desarrollo), no una medida de GPU real.
# v40: no depende de los ajustes guardados: activa la vista 3D y la camara fija solo en memoria (no guarda),
# oculta la pantalla de perfil y, con INSIDE=1, pone a Wilson en su casilla de inicio dentro de la base
# (antes quedaba en la casilla exterior ext_spawn y la camara solo veia una pared). Fuera mira a la base.
var main: Node = null
var frame: int = 0
var acc: Array = []


func _initialize() -> void:
	Lang.code = "es"
	root.size = Vector2i(1280, 720)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _tris(m: Mesh) -> int:
	var t: int = 0
	for s in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		else:
			t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


# Recuento de la escena (como en v39): MeshInstance3D = 1 superficie por superficie de malla;
# MultiMesh = 1 superficie por superficie de malla y triangulos x instancias.
func count_scene(n: Node, acc2: Dictionary) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		acc2["surf"] += m.get_surface_count()
		acc2["tris"] += _tris(m)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm.mesh != null and mm.instance_count > 0:
			var vis: int = mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
			acc2["surf"] += mm.mesh.get_surface_count()
			acc2["tris"] += _tris(mm.mesh) * vis
	for c in n.get_children():
		count_scene(c, acc2)


func _process(_d: float) -> bool:
	frame += 1
	var inside: bool = OS.get_environment("INSIDE") == "1"
	if frame == 5:
		var pui: Control = main.get_node_or_null("ProfileUI")
		if pui != null:
			pui.visible = false
		main.set("show_tutorial", false)
		main.set("auto_quality", false)
		main.set("view3d_on", true)   # solo en memoria (no llama a _save_settings)
		main.set("cam_mode", 0)       # camara fija: la medida no depende de la camara guardada
		main.call("_set_quality", int(OS.get_environment("Q")))
		var t0: int = Time.get_ticks_usec()
		main.call("_new_game", OS.get_environment("LOC"))
		print("crear_partida_ms: ", (Time.get_ticks_usec() - t0) / 1000)
	if frame == 8:
		var tut = main.get("tut")
		if tut != null and tut.has_method("skip_silent"):
			tut.call("skip_silent")
		main.get("dlg").visible = false
		main.set("mode", 0)
		main.set("outside", not inside)
		if inside:
			main.call("_set_player_tile", main.call("_find_start"), Vector2i(0, 1))
		else:
			main.call("_set_player_tile", main.get("ext_spawn"), Vector2i(0, -1))   # mirando a la base
		main.get("view3d").call("snap_camera")
		# v41: EV=breach (brecha: alarma, chispas, fuga) o EV=storm (tormenta) para medir el coste de los efectos
		match OS.get_environment("EV"):
			"breach":
				main.set("breach", true)
			"storm":
				main.set("storm_left", 2)
				main.get("view3d").get("efx").set("storm_k", 1.0)
	if frame > 40 and frame <= 60:
		var vp: Viewport = main.get("vp3d")
		var rid: RID = vp.get_viewport_rid()
		acc.append([RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)])
	if frame == 61:
		var a: Array = acc[acc.size() - 1]
		print("primitivas_visibles: ", a[0], " llamadas: ", a[1], " primitivas_sombra: ", a[2])
		var v: Node3D = main.get("view3d")
		var part: Node3D = v.get("interior") if inside else v.get("exterior")
		var sc := {"surf": 0, "tris": 0}
		if part != null:
			count_scene(part, sc)
		print("escena_", "interior" if inside else "exterior", ": superficies ", sc["surf"], " triangulos ", sc["tris"])
		if OS.get_environment("SNAP") != "":
			root.get_texture().get_image().save_png(OS.get_environment("SNAP"))
		return true
	return false
