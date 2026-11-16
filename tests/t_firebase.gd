extends SceneTree
# v36 — Prueba del cliente de Firebase y de las reglas de seguridad contra el EMULADOR local.
# Requiere los emuladores en marcha (desde la carpeta firebase/):
#   npx firebase-tools emulators:start --only auth,firestore --project demo-mision-perseo
# Uso: cp tests/t_firebase.gd . && FIREBASE_EMULATOR=127.0.0.1 godot --headless --path . --script res://t_firebase.gd

const EMU_FS: String = "http://127.0.0.1:8080"
const PROJ: String = "demo-mision-perseo"
var ok_n: int = 0
var fail_n: int = 0


func _check(c: bool, what: String) -> void:
	if c:
		ok_n += 1
		print("OK: ", what)
	else:
		fail_n += 1
		print("FALLO: ", what)


func _fb() -> Node:
	var n := Node.new()
	n.set_script(load("res://firebase.gd"))
	root.add_child(n)
	return n


func _http(url: String, method: int, body: String = "", headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var h := HTTPRequest.new()
	root.add_child(h)
	h.request(url, headers, method, body)
	var r: Array = await h.request_completed
	h.queue_free()
	var txt: String = (r[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(r[1]), "data": JSON.parse_string(txt) if txt != "" else null}


# El emulador guarda los enlaces de verificación: se "abren" como si el usuario pulsara el correo.
func _click_verify_link(mail: String) -> bool:
	var r: Dictionary = await _http("http://127.0.0.1:9099/emulator/v1/projects/%s/oobCodes" % PROJ, HTTPClient.METHOD_GET)
	var link: String = ""
	for c in (r["data"] as Dictionary).get("oobCodes", []):
		if str(c["email"]) == mail and str(c["requestType"]) == "VERIFY_EMAIL":
			link = str(c["oobLink"])
	if link == "":
		return false
	var r2: Dictionary = await _http(link, HTTPClient.METHOD_GET)
	return int(r2["code"]) == 200


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# limpiar el emulador
	await _http("http://127.0.0.1:9099/emulator/v1/projects/%s/accounts" % PROJ, HTTPClient.METHOD_DELETE)
	await _http("%s/emulator/v1/projects/%s/databases/(default)/documents" % [EMU_FS, PROJ], HTTPClient.METHOD_DELETE)
	var t := _fb()
	_check(bool(t.call("configured")), "cliente configurado contra el emulador")
	# --- cuentas ---
	var r: Dictionary = await t.call("sign_up", "profe@escuela.edu", "secreto1")
	_check(bool(r["ok"]) and str(t.get("uid")) != "", "crear cuenta con correo y contraseña")
	var r2: Dictionary = await _fb().call("sign_up", "profe@escuela.edu", "otraclave")
	_check(not bool(r2["ok"]) and str(r2["error"]).begins_with("EMAIL_EXISTS"), "no se puede crear dos veces el mismo correo")
	var r3: Dictionary = await _fb().call("sign_up", "x@y.com", "123")
	_check(str(r3["error"]).begins_with("WEAK_PASSWORD"), "contraseña corta rechazada")
	var r4: Dictionary = await _fb().call("sign_in", "profe@escuela.edu", "mala")
	_check(not bool(r4["ok"]), "contraseña incorrecta rechazada")
	# --- perfil en Firestore y reglas ---
	var tuid: String = str(t.get("uid"))
	var w: Dictionary = await t.call("set_doc", "users/" + tuid, {"email": "profe@escuela.edu", "type": "edu", "role": "teacher", "teacher_status": "pending", "classes": []})
	_check(bool(w["ok"]), "el docente guarda su perfil (pendiente)")
	var w2: Dictionary = await t.call("set_doc", "users/" + tuid, {"email": "profe@escuela.edu", "type": "edu", "role": "teacher", "teacher_status": "verified", "classes": []})
	_check(not bool(w2["ok"]) and str(w2["error"]) == "PERMISSION_DENIED", "REGLAS: un docente NO puede marcarse como verificado")
	var tr: Dictionary = await t.call("set_doc", "teacher_requests/" + tuid, {"email": "profe@escuela.edu", "name": "Prof", "school": "Escuela", "status": "pending"})
	_check(not bool(tr["ok"]), "REGLAS: sin correo verificado no se puede pedir la verificación de docente")
	# --- verificación del correo ---
	var sv: Dictionary = await t.call("send_verification")
	_check(bool(sv["ok"]), "se envía el correo de verificación")
	_check(await _click_verify_link("profe@escuela.edu"), "el enlace del correo verifica la cuenta")
	await t.call("lookup")
	_check(bool(t.get("email_verified")), "el juego detecta el correo verificado")
	var tr2: Dictionary = await t.call("set_doc", "teacher_requests/" + tuid, {"email": "profe@escuela.edu", "name": "Prof", "school": "Escuela", "status": "pending"})
	_check(bool(tr2["ok"]), "con el correo verificado se crea la solicitud de docente")
	var tr3: Dictionary = await t.call("set_doc", "teacher_requests/" + tuid, {"status": "approved"}, ["status"])
	_check(not bool(tr3["ok"]), "REGLAS: el docente no puede aprobar su propia solicitud")
	# --- estudiante y partidas ---
	var s := _fb()
	await s.call("sign_up", "alumno@escuela.edu", "clave123")
	var suid: String = str(s.get("uid"))
	var sv1: Dictionary = await s.call("set_doc", "saves/" + suid, {"data": "{\"day\":3}", "updated": 100, "version": 2})
	_check(bool(sv1["ok"]), "el estudiante sube su partida a la nube")
	var sg: Dictionary = await s.call("get_doc", "saves/" + suid)
	_check(bool(sg["ok"]) and str(sg["data"]["data"]) == "{\"day\":3}", "y la vuelve a descargar igual")
	var steal: Dictionary = await t.call("get_doc", "saves/" + suid)
	_check(not bool(steal["ok"]), "REGLAS: nadie puede leer la partida de otro jugador")
	var bad: Dictionary = await s.call("set_doc", "saves/" + suid, {"data": "{}", "updated": 1, "version": 2, "extra": "x"})
	_check(not bool(bad["ok"]), "REGLAS: la partida solo admite los campos previstos")
	var sp: Dictionary = await s.call("pending_teachers")
	_check(int(sp["code"]) == 403 or (sp["data"] as Array).is_empty(), "REGLAS: un estudiante no ve las solicitudes de docentes")
	_check(not bool(await s.call("is_admin")), "un estudiante no es administrador")
	# --- sesión guardada (inicio automático) ---
	var s2 := _fb()
	var rf: Dictionary = await s2.call("refresh", str(s.get("refresh_token")))
	_check(bool(rf["ok"]) and str(s2.get("uid")) == suid, "la sesión se recupera con el refresh token (otro dispositivo o al reabrir)")
	# --- administrador ---
	var a := _fb()
	await a.call("sign_up", "admin@ejemplo.com", "admin123")
	var auid: String = str(a.get("uid"))
	# el administrador se crea A MANO en la consola; en el emulador, con la cabecera «owner» (salta las reglas)
	var own: PackedStringArray = PackedStringArray(["Content-Type: application/json", "Authorization: Bearer owner"])
	await _http("%s/v1/projects/%s/databases/(default)/documents/admins/%s" % [EMU_FS, PROJ, auid], HTTPClient.METHOD_PATCH, JSON.stringify({"fields": {"note": {"stringValue": "admin"}}}), own)
	var self_admin: Dictionary = await s.call("set_doc", "admins/" + suid, {"x": "y"})
	_check(not bool(self_admin["ok"]), "REGLAS: nadie puede hacerse administrador desde el juego")
	_check(bool(await a.call("is_admin")), "el administrador se reconoce")
	var pend: Dictionary = await a.call("pending_teachers")
	_check(bool(pend["ok"]) and (pend["data"] as Array).size() == 1 and str(pend["data"][0]["uid"]) == tuid, "el administrador ve la solicitud pendiente")
	var ap1: Dictionary = await a.call("set_doc", "teacher_requests/" + tuid, {"status": "approved", "reviewed_at": 123}, ["status", "reviewed_at"])
	var ap2: Dictionary = await a.call("set_doc", "users/" + tuid, {"teacher_status": "verified"}, ["teacher_status"])
	_check(bool(ap1["ok"]) and bool(ap2["ok"]), "el administrador aprueba la solicitud")
	var ap3: Dictionary = await a.call("set_doc", "users/" + tuid, {"email": "otro@x.com"}, ["email"])
	_check(not bool(ap3["ok"]), "REGLAS: el administrador solo puede cambiar el estado de docente")
	var tu: Dictionary = await t.call("get_doc", "users/" + tuid)
	_check(str(tu["data"]["teacher_status"]) == "verified", "el docente aparece como verificado")
	print("FIREBASE: %d OK, %d fallos" % [ok_n, fail_n])
	quit()
