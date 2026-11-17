extends SceneTree
# Capturas de pantalla de la UI y del mundo 3D (renderizador por software, xvfb).
# Uso (desde la raiz del proyecto, tras copiar este archivo a la raiz):
#   RES=1280x720 SHOTS=menu SHOT_DIR=/tmp/shots godot --path . --rendering-driver opengl3 --script res://t_ui.gd
# Estados: menu new opts credits howto endings end_win end_lose hud_moon hud_mars
#          out_moon out_mars out_moon_low out_mars_low night_moon storm_mars pack bench map pause diag
#          v40: lm_apollo lm_plaque lm_wreck (Luna) lm_rover (Marte): puntos de interes 'L' de cerca;
#               base_moon base_mars: exterior de la base visto desde el sureste
# Solo PREPARA el estado y toma la captura: no cambia la logica del juego.
# (Version escrita en v28: la copia original citada en CLAUDE.md no estaba en el repositorio.)

var main: Node = null
var frame: int = 0
var state: String = ""
var out_dir: String = "/tmp/shots"
var res_txt: String = "1280x720"
var wait_frames: int = 70


func _initialize() -> void:
	state = OS.get_environment("SHOTS")
	if state == "":
		state = "menu"
	if OS.get_environment("SHOT_DIR") != "":
		out_dir = OS.get_environment("SHOT_DIR")
	if OS.get_environment("RES") != "":
		res_txt = OS.get_environment("RES")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var lc: String = OS.get_environment("LANG_CODE")
	Lang.code = lc if lc == "en" else "es"
	var p: PackedStringArray = res_txt.split("x")
	var sz := Vector2i(int(p[0]), int(p[1]))
	root.size = sz
	DisplayServer.window_set_size(sz)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _prepare() -> void:
	var lc: String = OS.get_environment("LANG_CODE")
	Lang.code = lc if lc == "en" else "es"
	main.set("difficulty", 1)
	main.set("cam_mode", 0)
	# v40: vista 3D solo en memoria (no se guarda): las capturas no dependen de view3d=false guardado
	if OS.get_environment("VIEW3D") != "0":
		main.set("view3d_on", true)
	main.set("show_tutorial", false)
	if OS.get_environment("TOUCH") == "1":
		main.get_node("TouchUI").set("setting", 1)   # controles tactiles visibles (sin guardar el ajuste)
	if OS.get_environment("UI_SCALE") != "":
		# simula el factor de movil de ui_fit.gd (p. ej. 1.35 = movil pequeno en horizontal)
		main.get_node("UiFit").set("force_k", float(OS.get_environment("UI_SCALE")))
	main.set("auto_quality", false)
	main.call("_set_quality", 0 if state.ends_with("_low") else 2)
	var pui: Control = main.get_node_or_null("ProfileUI")
	if pui != null and not state.begins_with("prof_"):
		pui.visible = false   # v35: las demas capturas no muestran la pantalla de perfil
	if state.begins_with("prof_"):
		var prof: Node = main.get_node("Profiles")
		match state:
			"prof_choose":
				pui.call("show_choose")
			"prof_email":
				pui.call("_ask_email", "edu")
			"prof_login":
				pui.call("_ask_email", "personal", true)
			"prof_verify":
				pui.set("pending_email", "profe%d@escuela.edu" % (randi() % 100000))
				pui.set("pending_password", "clave123")
				pui.call("_register", "edu", "teacher", {"name": "Prof", "school": "Escuela"})
			"prof_cloud":
				pui.set("pending_email", "alumno%d@escuela.edu" % (randi() % 100000))
				pui.set("pending_password", "clave123")
				await pui.call("_register", "edu", "student")
				pui.call("show_account")
			"prof_role":
				pui.set("pending_email", "alumno@escuela.edu")
				pui.call("_ask_role")
			"prof_teacher":
				pui.set("pending_email", "profe@escuela.edu")
				pui.call("_teacher_form")
			"prof_student":
				prof.call("create", "edu", "alumno@escuela.edu", "student")
				prof.call("join_class", "PER-" + "3")
				prof.call("join_class", (load("res://profiles.gd") as GDScript).call("make_code", [0, 4, 8]))
				pui.call("show_account")
			"prof_newclass":
				prof.call("create", "edu", "profe@escuela.edu", "teacher", {"name": "Prof", "school": "Escuela"})
				pui.call("show_new_class")
			"prof_lessons":
				prof.call("create", "edu", "alumno@escuela.edu", "student")
				var code: String = (load("res://profiles.gd") as GDScript).call("make_code", [0, 4, 8])
				prof.call("join_class", code)
				pui.visible = false
				main.get("ui").set("lesson_filter", {"topic": "", "loc": "", "class": code})
				main.get("ui").call("show_page", "lessons")
		return
	if state.begins_with("les_"):
		# v29: misiones de clase (les_goto, les_jump, les_quiz, les_done)
		var lid: String = {"les_goto": "moon_apollo", "les_jump": "mars_jump", "les_quiz": "mars_jezero", "les_done": "moon_ice"}[state]
		main.get("lesson").call("start", lid)
		return
	match state:
		"menu":
			pass
		"new", "credits", "howto", "endings", "lessons":
			main.get("ui").call("show_page", state)
		"opts":
			main.get("ui").call("open_options")
		"hud_moon", "out_moon", "out_moon_low", "night_moon", "end_win", "end_lose", "far_moon", "crew_moon", "ach", "hud_lv3", "lm_apollo", "lm_plaque", "lm_wreck", "base_moon":
			_start("Luna")
		_:
			_start("Marte")


func _start(loc: String) -> void:
	main.call("_new_game", loc)


func _after_start() -> void:
	# segundo paso: con la partida ya creada
	var tut = main.get("tut")
	if tut != null and tut.has_method("skip_silent"):
		tut.call("skip_silent")
	main.set("clock", 10 * 60)
	var dl = main.get("dlg")
	if dl != null:
		dl.visible = false
	main.set("mode", 0)
	match state:
		"out_moon", "out_mars", "out_moon_low", "out_mars_low", "night_moon", "storm_mars", "far_moon", "far_mars":
			main.set("outside", true)
			main.call("_set_player_tile", main.get("ext_spawn"), Vector2i(0, 1))
			if state.begins_with("far_"):
				# lejos de la base, mirando hacia una zona con relieve
				main.call("_set_player_tile", Vector2i(70, 40) if state == "far_moon" else Vector2i(50, 42), Vector2i(0, -1))
				main.set("clock", 8 * 60 + 30)
			if state == "night_moon":
				main.set("clock", 22 * 60)
			if state == "storm_mars":
				main.set("storm_left", 2)
			main.get("view3d").call("snap_camera")
		"lm_apollo", "lm_plaque", "lm_wreck", "lm_rover", "base_moon", "base_mars":
			# v40: 3 casillas al sur del punto de interes (o de la base), mirando al norte
			var target := Vector2i(-1, -1)
			if state.begins_with("base_"):
				target = Vector2i(int(main.BASE_X0) + 6, int(main.BASE_Y0) + 5)
			else:
				var lm: String = state.substr(3)
				for z in main.call("_zones"):
					if str(z["lm"]) == lm and int(z["lx"]) >= 0:
						target = Vector2i(int(z["lx"]), int(z["ly"]) + 3)
						break
			main.set("outside", true)
			main.call("_set_player_tile", target, Vector2i(0, -1))
			main.get("view3d").call("snap_camera")
		"crew_moon", "crew_mars":
			# primer plano de la tripulacion (zoom de camara)
			main.get("view3d").set("zoom", 0.5)
			main.call("_set_player_tile", main.get("player"), Vector2i(0, 1))   # de frente a la camara
		"hud_lv3":
			# v33: estaciones al nivel maximo (las mejoras se ven sobre los modelos nuevos)
			var lv: Dictionary = main.get("st_lvl")
			for k in lv:
				lv[k] = 3
			for k in lv:
				main.get("view3d").call("refresh_station", k)
		"pack_full":
			# v34: mochila y HUD con materiales y herramientas (para ver los iconos)
			(main.get("inv") as Dictionary).merge({"scrap": 4, "polymer": 3, "circuits": 2}, true)
			(main.get("tools") as Dictionary).merge({"patch": 1, "medkit": 1, "repair": 1, "filter": 1, "map": 1}, true)
			main.call("_open_pack")
		"hud_full":
			(main.get("inv") as Dictionary).merge({"scrap": 4, "polymer": 3, "circuits": 2}, true)
			(main.get("tools") as Dictionary).merge({"patch": 1, "medkit": 1, "repair": 1, "filter": 1, "map": 1}, true)
		"pack":
			main.call("_open_pack")
		"bench":
			main.call("_open_craft")
		"map":
			var t: Dictionary = main.get("tools")
			t["map"] = 1
			main.call("_open_world_map")
		"st_O", "st_S", "st_R", "st_C", "st_T", "st_A", "st_D", "st_G", "st_W":
			# v33: primer plano de una estacion (el jugador se coloca a 2 casillas, del lado de su frente)
			var ch: String = state.substr(3, 1)
			var tp: Vector2i = main.call("_map_find", ch)
			var off: Vector2i = Vector2i(0, 2)
			if ch in ["C", "A", "D"]:
				off = Vector2i(0, -2)
			main.call("_set_player_tile", tp + off, Vector2i(-off.x, -signi(off.y)))
			main.get("view3d").set("zoom", 0.55)
			if ch in ["C", "A", "D"]:
				main.set("cam_mode", 2)   # camara detras del personaje, mirando hacia la estacion
			main.get("view3d").call("snap_camera")
		"mg_patch", "mg_filter", "mg_map":
			# v32: minijuegos del banco
			(main.get("inv") as Dictionary).merge({"scrap": 9, "polymer": 9, "circuits": 9}, true)
			main.call("_craft", {"mg_patch": 0, "mg_filter": 3, "mg_map": 4}[state])
		"pause":
			main.call("_open_pause", true)
		"ach":
			var ad: Dictionary = main.get("ach_done")
			ad.erase("survivor10")
			main.get("tut").call("unlock", "survivor10")
		"diag":
			main.call("_open_diag")
		"end_win":
			main.call("_finish", true, "heroes")
		"end_lose":
			main.call("_finish", false, "fail_oxygen")
	main.call("_refresh")


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		_prepare()
	if frame == 12 and state not in ["menu", "new", "opts", "credits", "howto", "endings", "lessons"] and not state.begins_with("les_") and not state.begins_with("prof_"):
		_after_start()
	if frame == 20 and state == "les_quiz":
		main.get("lesson").call("_open_quiz")
	if frame == 20 and state == "les_done":
		main.get("lesson").set("t_total", 214.0)
		main.get("lesson").set("first_try_ok", 1)
		main.get("lesson").call("_open_quiz")
		main.get("lesson").call("_show_summary")
	if state.begins_with("stc_") and frame >= 20:
		# v33: camara fija delante de una estacion (vista de 3/4), sin la camara del juego
		var v3: Node3D = main.get("view3d")
		if frame == 20:
			v3.set_process(false)
		var ch2: String = state.substr(4, 1)
		var tp2: Vector2i = main.call("_map_find", ch2)
		var pos := Vector3((float(tp2.x) + 0.5) * 2.0, 0.0, (float(tp2.y) + 0.5) * 2.0)
		var front := Vector3(0, 0, 1) if not (ch2 in ["C", "A", "D"]) else Vector3(0, 0, -1)
		var cam: Camera3D = v3.get("cam")
		cam.fov = 50.0
		cam.position = pos + front * 3.6 + Vector3(1.2, 2.0, 0.0)
		cam.look_at(pos + Vector3(0, 1.1, 0), Vector3.UP)
		var vp: SubViewport = main.get("vp3d")
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if frame == wait_frames - 3 and state == "ach":
		main.get("tut").set("toast_t", 3.6)   # el render por software es lento: se fija el momento del aviso
	if frame == wait_frames:
		var img: Image = root.get_texture().get_image()
		var fn: String = "%s/%s_%s.png" % [out_dir, state, res_txt]
		img.save_png(fn)
		print("captura: ", fn)
		return true
	return false
