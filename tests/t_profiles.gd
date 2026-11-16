extends SceneTree
# v35 — Prueba de perfiles: primera pantalla, invitado (sin conservar), personal (guardado propio),
# educativa estudiante (unirse a clase con codigo) y docente (pendiente), codigos de clase y filtro.
# Uso: cp tests/t_profiles.gd . && xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_profiles.gd
# OJO: borra user://profiles.cfg y los guardados de perfiles de este equipo de pruebas.

const Profiles = preload("res://profiles.gd")
var main: Node = null
var frame: int = 0
var ok_n: int = 0
var fail_n: int = 0


func _check(c: bool, what: String) -> void:
	if c:
		ok_n += 1
		print("OK: ", what)
	else:
		fail_n += 1
		print("FALLO: ", what)


func _initialize() -> void:
	Lang.code = "es"
	# estado limpio: sin perfiles
	for f in ["user://profiles.cfg", "user://save_guest.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	var d := DirAccess.open("user://")
	if d != null:
		for f in d.get_files():
			if f.begins_with("save_") and f.ends_with(".json"):
				d.remove(f)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame != 8:
		return false
	var prof: Node = main.get_node("Profiles")
	var pui: Control = main.get_node("ProfileUI")
	# 1) primera vez: se pide elegir perfil
	_check(pui.visible, "sin perfil, al abrir se muestra «¿Quién juega?»")
	# 2) codigos de clase: ida y vuelta para todas las combinaciones de misiones
	var all_ok: bool = true
	for mask in range(1, 512):
		var ms: Array = []
		for i in 9:
			if mask & (1 << i):
				ms.append(i)
		var code: String = Profiles.make_code(ms)
		if Profiles.read_code(code) != ms or Profiles.read_code(code.to_lower().replace("-", " ")) != ms:
			all_ok = false
	_check(all_ok, "los 511 codigos de clase se leen igual que se crearon")
	_check(Profiles.read_code("PER-ZZZZ").is_empty() and Profiles.read_code("hola").is_empty(), "codigos invalidos se rechazan")
	var c1: String = Profiles.make_code([0, 4])
	var typo: String = c1.substr(0, 6) + ("2" if c1[6] != "2" else "3") + c1.substr(7)
	_check(Profiles.read_code(typo).is_empty() or Profiles.read_code(typo) != [0, 4], "un error de tecleo no da la misma clase")
	# 3) correos
	_check(Profiles.valid_email("ana.perez@escuela.edu.co") and not Profiles.valid_email("ana@") and not Profiles.valid_email("sin arroba"), "validacion basica de correo")
	# 4) invitado: su partida no se conserva
	prof.call("create", "guest", "")
	_check(str(main.get("SAVE_PATH")) == "user://save_guest.json", "invitado usa su propio archivo")
	var f := FileAccess.open("user://save_guest.json", FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	prof.call("setup", main)   # simula volver a abrir el juego
	_check(not FileAccess.file_exists("user://save_guest.json"), "al volver a abrir, la partida de invitado se borra")
	_check((prof.get("current") as Dictionary).is_empty(), "el invitado no queda como perfil recordado")
	# 5) personal: guardado propio y recordado
	var pp: Dictionary = prof.call("create", "personal", "Ana@Gmail.com")
	_check(str(main.get("SAVE_PATH")).begins_with("user://save_") and str(main.get("SAVE_PATH")) != "user://save_guest.json", "perfil personal con guardado propio")
	_check(str(pp["email"]) == "ana@gmail.com", "el correo se guarda en minusculas")
	prof.call("setup", main)
	_check(str((prof.get("current") as Dictionary).get("id", "")) == str(pp["id"]), "el perfil personal se recuerda al volver a abrir")
	# 6) educativa estudiante: unirse a una clase
	prof.call("create", "edu", "alumno@escuela.edu", "student")
	_check(bool(prof.call("is_student")), "cuenta educativa como estudiante")
	_check(not bool(prof.call("join_class", "PER-XXXX")), "no se une con un codigo invalido")
	var code: String = Profiles.make_code([1, 5, 8])
	_check(bool(prof.call("join_class", code)), "se une con un codigo valido")
	_check(((prof.get("current") as Dictionary)["classes"] as Array).has(code), "la clase queda en «Mis clases»")
	# 7) filtro de misiones por clase en el menu
	var ui = main.get("ui")
	ui.set("lesson_filter", {"topic": "", "loc": "", "class": code})
	ui.call("show_page", "lessons")
	var box: VBoxContainer = ui.get("lessons_box")
	var grid: Array = box.find_children("*", "GridContainer", true, false)
	var n_cards: int = 0
	for g in grid:
		n_cards += (g as GridContainer).get_child_count()
	_check(n_cards == 3, "con la clase elegida se ven solo sus 3 misiones (%d)" % n_cards)
	# 8) docente: queda pendiente y puede crear un codigo
	prof.call("create", "edu", "profe@escuela.edu", "teacher", {"name": "Prof", "school": "Escuela"})
	_check(bool(prof.call("is_teacher")) and str((prof.get("current") as Dictionary)["teacher_status"]) == "pending", "docente queda «pendiente de verificación»")
	# 9) cambiar de perfil cambia la ruta de guardado
	var ids: Array = (prof.get("list") as Dictionary).keys()
	_check(ids.size() == 3, "tres perfiles con cuenta en el dispositivo (sin el invitado)")
	prof.call("activate", str(pp["id"]))
	_check(str(main.get("SAVE_PATH")) == str(pp["save"]), "al cambiar de perfil se usa su guardado")
	print("PERFILES: %d OK, %d fallos" % [ok_n, fail_n])
	return true
