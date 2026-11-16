extends SceneTree
# v36 — Prueba de extremo a extremo de los perfiles con Firebase (EMULADOR local) usando el juego real:
# docente se registra desde la interfaz → verifica el correo → envía la solicitud → el administrador
# la aprueba; estudiante guarda la partida y la recupera en «otro dispositivo».
# Requiere los emuladores (ver tests/t_firebase.gd).
# Uso: cp tests/t_fbflow.gd . && FIREBASE_EMULATOR=127.0.0.1 xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_fbflow.gd

const PROJ: String = "demo-mision-perseo"
var main: Node = null
var ok_n: int = 0
var fail_n: int = 0


func _check(c: bool, what: String) -> void:
	if c:
		ok_n += 1
		print("OK: ", what)
	else:
		fail_n += 1
		print("FALLO: ", what)


func _http(url: String, method: int, body: String = "", headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var h := HTTPRequest.new()
	root.add_child(h)
	h.request(url, headers, method, body)
	var r: Array = await h.request_completed
	h.queue_free()
	var txt: String = (r[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(r[1]), "data": JSON.parse_string(txt) if txt != "" else null}


func _click_verify(mail: String) -> void:
	var r: Dictionary = await _http("http://127.0.0.1:9099/emulator/v1/projects/%s/oobCodes" % PROJ, HTTPClient.METHOD_GET)
	for c in (r["data"] as Dictionary).get("oobCodes", []):
		if str(c["email"]) == mail and str(c["requestType"]) == "VERIFY_EMAIL":
			await _http(str(c["oobLink"]), HTTPClient.METHOD_GET)


func _btn(ui: Node, text: String) -> Button:
	for b in ui.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			return b
	return null


func _press(ui: Node, text: String) -> bool:
	var b: Button = _btn(ui, text)
	if b == null:
		print("   (no encuentro el botón «%s»)" % text)
		return false
	b.emit_signal("pressed")
	return true


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	Lang.code = "es"
	for f in ["user://profiles.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _http("http://127.0.0.1:9099/emulator/v1/projects/%s/accounts" % PROJ, HTTPClient.METHOD_DELETE)
	await _http("http://127.0.0.1:8080/emulator/v1/projects/%s/databases/(default)/documents" % PROJ, HTTPClient.METHOD_DELETE)
	await _wait(0.5)
	var prof: Node = main.get_node("Profiles")
	var ui: Node = main.get_node("ProfileUI")
	_check(bool(prof.call("cloud_ready")), "el juego detecta la nube (emulador)")
	# --- docente desde la interfaz ---
	ui.call("_ask_email", "edu")
	(ui.find_child("Email", true, false) as LineEdit).text = "profe@escuela.edu"
	(ui.find_child("Password", true, false) as LineEdit).text = "clave123"
	_press(ui, "Continuar")
	await _wait(0.3)
	_check(_btn(ui, "Volver") != null and ui.find_children("*", "Button", true, false).size() >= 3, "aparece «¿Eres estudiante o docente?»")
	ui.call("_teacher_form")
	var edits: Array = ui.find_children("*", "LineEdit", true, false)
	(edits[0] as LineEdit).text = "Profe Ana"
	(edits[1] as LineEdit).text = "Escuela Perseo"
	_press(ui, "Enviar solicitud")
	await _wait(2.5)
	_check(bool(prof.call("is_cloud")) and bool(prof.call("is_teacher")), "cuenta de docente creada en la nube")
	_check(_btn(ui, "Ya lo verifiqué") != null, "pide verificar el correo")
	_press(ui, "Ya lo verifiqué")
	await _wait(1.5)
	_check(_btn(ui, "Ya lo verifiqué") != null, "sin abrir el enlace todavía no avanza")
	await _click_verify("profe@escuela.edu")
	_press(ui, "Ya lo verifiqué")
	await _wait(3.0)
	_check(bool((prof.get("current") as Dictionary).get("request_sent", false)), "con el correo verificado se envía la solicitud")
	var teacher_uid: String = str((prof.get("current") as Dictionary)["uid"])
	# --- estudiante: partida en la nube y en «otro dispositivo» ---
	prof.call("sign_out")
	ui.call("_ask_email", "edu")
	(ui.find_child("Email", true, false) as LineEdit).text = "alumno@escuela.edu"
	(ui.find_child("Password", true, false) as LineEdit).text = "clave456"
	_press(ui, "Continuar")
	await _wait(0.3)
	ui.call("_student")
	await _wait(2.5)
	_check(bool(prof.call("is_student")) and bool(prof.call("is_cloud")), "cuenta de estudiante creada en la nube")
	main.set("show_tutorial", false)
	main.call("_new_game", "Marte")
	main.set("day", 4)
	main.call("_save_game")
	await _wait(2.5)
	_check(str(prof.get("cloud_note")) == "Partida guardada en la nube.", "la partida se sube a la nube al guardar")
	var saved: String = FileAccess.get_file_as_string(str(main.get("SAVE_PATH")))
	# otro dispositivo: sin perfiles ni partida local
	var old_path: String = str(main.get("SAVE_PATH"))
	DirAccess.remove_absolute(old_path)
	DirAccess.remove_absolute("user://profiles.cfg")
	prof.call("setup", main)
	var err: String = await prof.call("cloud_login", "alumno@escuela.edu", "clave456")
	_check(err == "", "inicia sesión en «otro dispositivo»")
	var got: String = FileAccess.get_file_as_string(str(main.get("SAVE_PATH")))
	_check(got == saved and got.length() > 100, "la partida se recupera desde la nube")
	_check(await prof.call("cloud_login", "alumno@escuela.edu", "mala") != "", "contraseña incorrecta: mensaje de error")
	# --- administrador ---
	var fb: Node = prof.get("fb")
	await fb.call("sign_up", "admin@ejemplo.com", "admin123")
	var auid: String = str(fb.get("uid"))
	await _http("http://127.0.0.1:8080/v1/projects/%s/databases/(default)/documents/admins/%s" % [PROJ, auid], HTTPClient.METHOD_PATCH, JSON.stringify({"fields": {"n": {"stringValue": "admin"}}}), PackedStringArray(["Content-Type: application/json", "Authorization: Bearer owner"]))
	await prof.call("cloud_login", "admin@ejemplo.com", "admin123")
	_check(bool(await prof.call("is_admin")), "el administrador se reconoce en el juego")
	ui.call("show_admin")
	await _wait(2.5)
	_check(_btn(ui, "Aprobar") != null, "el panel de administración muestra la solicitud")
	_press(ui, "Aprobar")
	await _wait(2.5)
	# el docente ve su cuenta verificada
	await prof.call("cloud_login", "profe@escuela.edu", "clave123")
	_check(str((prof.get("current") as Dictionary).get("teacher_status", "")) == "verified", "el docente aparece verificado tras la aprobación (uid %s)" % teacher_uid.left(6))
	print("FLUJO FIREBASE: %d OK, %d fallos" % [ok_n, fail_n])
	quit()
