extends SceneTree
# Prueba de regresion de la LOGICA del juego (escrita en v28).
# Simula partidas con semilla fija (Luna y Marte, varias dificultades) y escribe una huella
# (recursos, dia, reloj, inventario, emergencias) por hora de juego. Si la logica no cambia,
# la huella debe ser identica antes y despues de un cambio grafico.
# Uso: cp tests/t_logic.gd . && xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_logic.gd
# Salida: LOGIC_OUT (por defecto /tmp/logic_trace.txt) y la linea "HUELLA: <md5>".
# NO sustituye a tests/t_emg.gd (94 pruebas), que no esta en el repositorio.

var main: Node = null
var frame: int = 0
var out: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	Lang.code = "es"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _snap(tag: String) -> void:
	var r: Dictionary = main.get("res")
	var line: String = "%s d=%d c=%d " % [tag, int(main.get("day")), int(main.get("clock"))]
	for k in ["oxygen", "energy", "food", "water", "shield", "morale"]:
		line += "%s=%.3f " % [k, float(r[k])]
	line += JSON.stringify(main.get("inv")) + " " + JSON.stringify(main.get("tools"))
	line += " storm=%d ill=%d breach=%s playing=%s" % [int(main.get("storm_left")), int(main.get("ill_days")), str(main.get("breach")), str(main.get("playing"))]
	line += " emg=" + JSON.stringify(main.get("emg").call("serialize"))
	out.append(line)


func _run(loc: String, diff: int, days: int, assist: bool) -> void:
	Lang.code = "es"   # los ajustes guardados pueden haber cambiado el idioma: se fija para comparar
	main.set("show_tutorial", false)
	main.set("difficulty", diff)
	(main.get("rng") as RandomNumberGenerator).seed = 20261115 + diff
	(main.get("rng") as RandomNumberGenerator).state = 0
	main.call("_new_game", loc)
	(main.get("rng") as RandomNumberGenerator).seed = 4242 + diff
	(main.get("rng") as RandomNumberGenerator).state = 0
	var tag: String = "%s/%d/%s" % [loc, diff, "asist" if assist else "solo"]
	_snap(tag + " inicio")
	for h in days * 24:
		if not bool(main.get("playing")):
			break
		main.set("mode", 0)
		var dl = main.get("dlg")
		if dl != null:
			dl.visible = false
		main.call("_advance_time", 60)
		_snap(tag + " h%d" % h)
		if assist:
			# repone recursos (como haria un jugador) para recorrer mas dias de eventos
			var r: Dictionary = main.get("res")
			for k in r:
				if float(r[k]) < 35.0:
					r[k] = 60.0


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		for loc in ["Luna", "Marte"]:
			for diff in [0, 1, 2, 3]:
				_run(loc, diff, 8, false)
				_run(loc, diff, 8, true)
		var txt: String = "\n".join(out)
		var fn: String = OS.get_environment("LOGIC_OUT")
		if fn == "":
			fn = "/tmp/logic_trace.txt"
		var f := FileAccess.open(fn, FileAccess.WRITE)
		f.store_string(txt)
		f.close()
		print("LINEAS: ", out.size())
		print("HUELLA: ", txt.md5_text())
		return true
	return false
