extends SceneTree
# Capturas de pantalla de la UI y del mundo 3D (renderizador por software, xvfb).
# Uso (desde la raiz del proyecto, tras copiar este archivo a la raiz):
#   RES=1280x720 SHOTS=menu SHOT_DIR=/tmp/shots godot --path . --rendering-driver opengl3 --script res://t_ui.gd
# Estados: menu new opts credits howto endings end_win end_lose hud_moon hud_mars
#          out_moon out_mars out_moon_low out_mars_low night_moon storm_mars pack bench map pause diag
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
	main.set("show_tutorial", false)
	if OS.get_environment("TOUCH") == "1":
		main.get_node("TouchUI").set("setting", 1)   # controles tactiles visibles (sin guardar el ajuste)
	if OS.get_environment("UI_SCALE") != "":
		# simula el factor de movil de ui_fit.gd (p. ej. 1.35 = movil pequeno en horizontal)
		main.get_node("UiFit").set("force_k", float(OS.get_environment("UI_SCALE")))
	main.set("auto_quality", false)
	main.call("_set_quality", 0 if state.ends_with("_low") else 2)
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
		"hud_moon", "out_moon", "out_moon_low", "night_moon", "end_win", "end_lose", "far_moon", "crew_moon", "ach":
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
		"crew_moon", "crew_mars":
			# primer plano de la tripulacion (zoom de camara)
			main.get("view3d").set("zoom", 0.5)
			main.call("_set_player_tile", main.get("player"), Vector2i(0, 1))   # de frente a la camara
		"pack":
			main.call("_open_pack")
		"bench":
			main.call("_open_craft")
		"map":
			var t: Dictionary = main.get("tools")
			t["map"] = 1
			main.call("_open_world_map")
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
	if frame == 12 and state not in ["menu", "new", "opts", "credits", "howto", "endings", "lessons"] and not state.begins_with("les_"):
		_after_start()
	if frame == 20 and state == "les_quiz":
		main.get("lesson").call("_open_quiz")
	if frame == 20 and state == "les_done":
		main.get("lesson").set("t_total", 214.0)
		main.get("lesson").set("first_try_ok", 1)
		main.get("lesson").call("_open_quiz")
		main.get("lesson").call("_show_summary")
	if frame == wait_frames - 3 and state == "ach":
		main.get("tut").set("toast_t", 3.6)   # el render por software es lento: se fija el momento del aviso
	if frame == wait_frames:
		var img: Image = root.get_texture().get_image()
		var fn: String = "%s/%s_%s.png" % [out_dir, state, res_txt]
		img.save_png(fn)
		print("captura: ", fn)
		return true
	return false
