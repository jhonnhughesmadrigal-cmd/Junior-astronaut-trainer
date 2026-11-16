extends SceneTree
# v29 — Prueba de las Misiones de clase: recorre TODAS las misiones de lesson_data.gd.
# Comprueba: el destino de cada paso existe en el mapa; cada tipo de paso se completa por la via
# normal del juego; el cuestionario y el resumen aparecen; el progreso se guarda; los recursos no
# cambian (tiempo detenido) y la partida guardada (user://savegame.json) no se modifica.
# Uso: cp tests/t_lessons.gd . && xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_lessons.gd

const LessonData = preload("res://lesson_data.gd")

var main: Node = null
var les: Node = null
var frame: int = 0
var ok_n: int = 0
var fail_n: int = 0
var queue: Array = []
var cur: Dictionary = {}
var state: String = "idle"
var wait: int = 0
var res0: Dictionary = {}
var save_md5: String = ""
var last_si: int = -1


func _initialize() -> void:
	Lang.code = "en" if OS.get_environment("LANG_CODE") == "en" else "es"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for m in LessonData.MISSIONS:
		queue.append(m)


func _check(cond: bool, what: String) -> void:
	if cond:
		ok_n += 1
	else:
		fail_n += 1
		print("FALLO: ", what)


func _file_md5(p: String) -> String:
	if not FileAccess.file_exists(p):
		return "(no existe)"
	return FileAccess.get_file_as_bytes(p).get_string_from_utf8().md5_text()


func _next_mission() -> void:
	if queue.is_empty():
		state = "end"
		return
	cur = queue.pop_front()
	print("MISION: ", cur["id"], " (frame ", frame, ")")
	Lang.code = "en" if OS.get_environment("LANG_CODE") == "en" else "es"   # los ajustes guardados pueden cambiarlo
	les = main.get("lesson")
	les.call("start", str(cur["id"]))
	res0 = (main.get("res") as Dictionary).duplicate()
	_check(bool(main.call("lesson_active")), "%s: la mision debe estar activa" % cur["id"])
	state = "step"
	wait = 0
	last_si = -1


func _do_step() -> void:
	var steps: Array = cur["steps"]
	var si: int = int(les.get("step_i"))
	if str(les.get("phase")) != "steps":
		state = "quiz"
		wait = 0
		return
	var st: Dictionary = steps[si]
	if si != last_si:
		last_si = si
		wait = 0
	var tg: Vector2 = les.get("target")
	main.set("mode", 0)
	var dl = main.get("dlg")
	if dl != null:
		dl.visible = false
	match str(st["kind"]):
		"goto", "observe":
			if wait == 0:
				_check(tg.x >= 0.0, "%s paso %d: destino encontrado (%s)" % [cur["id"], si, st.get("zone", "")])
				if tg.x >= 0.0:
					main.set("outside", true)
					main.call("_set_player_tile", Vector2i(int(tg.x), int(tg.y) + 1), Vector2i(0, -1))
		"jump":
			if not bool(main.get("airborne")) and wait % 20 == 0:
				main.call("_start_jump")
		"ice":
			if wait == 0:
				var p: Vector2i = _nearest_ice(main.get("pos_f"))
				_check(p.x >= 0, "%s: hay hielo cerca" % cur["id"])
				main.call("_set_player_tile", Vector2i(p.x, p.y + 1), Vector2i(0, -1))
				main.call("_interact")
		"exit":
			if wait == 0:
				main.call("_door_inside_do")
	wait += 1
	if int(les.get("step_i")) != si or str(les.get("phase")) != "steps":
		wait = 0
	elif wait > 900:
		_check(false, "%s paso %d (%s) no se completo" % [cur["id"], si, st["kind"]])
		les.call("stop")
		state = "next"


func _nearest_ice(pf: Vector2) -> Vector2i:
	var rows: Array = main.get("ext_rows")
	var best := Vector2i(-1, -1)
	var bd: float = 1e9
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "i":
				var d: float = Vector2(x, y).distance_to(pf)
				if d < bd and not bool(main.call("_is_depleted", x, y)):
					bd = d
					best = Vector2i(x, y)
	return best


func _do_quiz() -> void:
	var ov: Control = les.get("overlay")
	if str(les.get("phase")) == "done":
		_check(ov != null, "%s: resumen visible" % cur["id"])
		_check(les.call("progress").has(str(cur["id"])), "%s: progreso guardado" % cur["id"])
		var r: Dictionary = main.get("res")
		var same: bool = true
		for k in res0:
			if k == "water" and str(cur["id"]) == "moon_ice":
				continue   # recoger hielo da +10 de agua (mecanica normal del juego)
			if absf(float(r[k]) - float(res0[k])) > 0.001:
				same = false
		_check(same, "%s: recursos sin cambios (tiempo detenido)" % cur["id"])
		_check(_file_md5("user://savegame.json") == save_md5, "%s: partida guardada intacta" % cur["id"])
		_check(str(les.get("phase")) == "done" and int(main.get("mode")) == 15, "%s: modo de leccion en el resumen" % cur["id"])
		state = "next"
		return
	wait += 1
	if wait > 300:
		_check(false, "%s: el cuestionario no avanza (pregunta %d)" % [cur["id"], int(les.get("quiz_i"))])
		if ov != null:
			for b in ov.find_children("*", "Button", true, false):
				print("   boton: ", (b as Button).text)
		state = "next"
		return
	if ov == null:
		return
	var q: Dictionary = (cur["quiz"] as Array)[int(les.get("quiz_i"))]
	var want: String = Lang.t(str((q["a"] as Array)[int(q["ok"])]))
	for b in ov.find_children("*", "Button", true, false):
		var bt: Button = b
		if bt.text == want and not bt.disabled:
			bt.emit_signal("pressed")
			return
	for b in ov.find_children("*", "Button", true, false):
		var bt2: Button = b
		if bt2.visible and (bt2.text == Lang.t("Siguiente") or bt2.text == Lang.t("Ver lo que aprendí")):
			bt2.emit_signal("pressed")
			return


func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		save_md5 = _file_md5("user://savegame.json")
		_next_mission()
		return false
	if frame < 5:
		return false
	match state:
		"step":
			_do_step()
		"quiz":
			if frame % 3 == 0:
				_do_quiz()
		"next":
			les.call("stop")
			_check(not bool(main.call("lesson_active")), "%s: la mision termina al salir" % cur["id"])
			_next_mission()
		"end":
			print("MISIONES: %d comprobaciones OK, %d fallos" % [ok_n, fail_n])
			return true
	return false
