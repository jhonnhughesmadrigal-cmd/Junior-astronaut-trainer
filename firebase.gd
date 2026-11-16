extends Node
# v36 — Cliente mínimo de Firebase por REST (HTTPRequest): funciona igual en web y en Android, sin plugins.
#  Auth (Identity Toolkit): crear cuenta, iniciar sesión, enviar correo de verificación, consultar
#  si el correo está verificado y renovar la sesión (securetoken).
#  Firestore: leer/escribir documentos y consultar solicitudes pendientes (panel del administrador).
# Endpoints según la documentación oficial (firebase.google.com/docs/reference/rest/auth y la API REST
# de Firestore). Para pruebas, la variable de entorno FIREBASE_EMULATOR=127.0.0.1 usa el emulador local.

const Cfg = preload("res://firebase_config.gd")

var api_key: String = Cfg.API_KEY
var project: String = Cfg.PROJECT_ID
var emu: String = ""          # host del emulador ("" = servidores reales de Google)

# sesión actual
var uid: String = ""
var email: String = ""
var id_token: String = ""
var refresh_token: String = ""
var expires_at: float = 0.0
var email_verified: bool = false

const ERRORS: Dictionary = {
	"EMAIL_EXISTS": "Ya existe una cuenta con ese correo. Usa «Ya tengo cuenta».",
	"INVALID_LOGIN_CREDENTIALS": "Correo o contraseña incorrectos.",
	"INVALID_PASSWORD": "Correo o contraseña incorrectos.",
	"EMAIL_NOT_FOUND": "Correo o contraseña incorrectos.",
	"WEAK_PASSWORD": "La contraseña es muy corta: usa al menos 6 caracteres.",
	"INVALID_EMAIL": "Ese correo no parece válido.",
	"TOO_MANY_ATTEMPTS_TRY_LATER": "Demasiados intentos. Espera un momento y vuelve a probar.",
	"USER_DISABLED": "Esta cuenta está desactivada.",
	"PERMISSION_DENIED": "No tienes permiso para hacer eso.",
	"NETWORK": "Sin conexión con el servidor. Revisa internet y vuelve a probar.",
}


func _ready() -> void:
	var e: String = OS.get_environment("FIREBASE_EMULATOR")
	if e != "":
		emu = e
		if project == "":
			project = "demo-mision-perseo"
		if api_key == "":
			api_key = "demo-key"


func configured() -> bool:
	return api_key != "" and project != ""


static func friendly(err: String) -> String:
	for k in ERRORS:
		if err.begins_with(k):
			return Lang.t(ERRORS[k])
	return Lang.t("No se pudo completar (%s).") % err


# ---------- HTTP ----------

func _auth_url(method: String) -> String:
	if emu != "":
		return "http://%s:9099/identitytoolkit.googleapis.com/v1/accounts:%s?key=%s" % [emu, method, api_key]
	return "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s" % [method, api_key]


func _token_url() -> String:
	if emu != "":
		return "http://%s:9099/securetoken.googleapis.com/v1/token?key=%s" % [emu, api_key]
	return "https://securetoken.googleapis.com/v1/token?key=%s" % api_key


func _fs_url(path: String) -> String:
	var base: String = "https://firestore.googleapis.com" if emu == "" else "http://%s:8080" % emu
	return "%s/v1/projects/%s/databases/(default)/documents%s" % [base, project, path]


# Devuelve {"ok": bool, "code": int, "data": Variant, "error": String}
func _req(url: String, method: int, body: Variant = null, auth: bool = false, content: String = "application/json") -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 20.0
	add_child(h)
	var headers: PackedStringArray = PackedStringArray(["Content-Type: " + content])
	if auth and id_token != "":
		headers.append("Authorization: Bearer " + id_token)
	var payload: String = ""
	if body is String:
		payload = body
	elif body != null:
		payload = JSON.stringify(body)
	var err: int = h.request(url, headers, method, payload)
	if err != OK:
		h.queue_free()
		return {"ok": false, "code": 0, "data": null, "error": "NETWORK"}
	var r: Array = await h.request_completed
	h.queue_free()
	var code: int = int(r[1])
	var txt: String = (r[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(txt) if txt != "" else null
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "data": null, "error": "NETWORK"}
	var e: String = ""
	if code >= 400:
		e = "HTTP_%d" % code
		if data is Dictionary and (data as Dictionary).has("error"):
			var ed = data["error"]
			if ed is Dictionary:
				e = str(ed.get("message", ed.get("status", e)))
			else:
				e = str(ed)
		if code == 403:
			e = "PERMISSION_DENIED"
	return {"ok": code < 400, "code": code, "data": data, "error": e}


# ---------- Auth ----------

func _take_session(d: Dictionary) -> void:
	uid = str(d.get("localId", d.get("user_id", uid)))
	email = str(d.get("email", email))
	id_token = str(d.get("idToken", d.get("id_token", "")))
	refresh_token = str(d.get("refreshToken", d.get("refresh_token", refresh_token)))
	expires_at = Time.get_unix_time_from_system() + float(d.get("expiresIn", d.get("expires_in", 3600))) - 60.0


func sign_up(mail: String, password: String) -> Dictionary:
	var r: Dictionary = await _req(_auth_url("signUp"), HTTPClient.METHOD_POST, {"email": mail, "password": password, "returnSecureToken": true})
	if r["ok"]:
		_take_session(r["data"])
		email_verified = false
	return r


func sign_in(mail: String, password: String) -> Dictionary:
	var r: Dictionary = await _req(_auth_url("signInWithPassword"), HTTPClient.METHOD_POST, {"email": mail, "password": password, "returnSecureToken": true})
	if r["ok"]:
		_take_session(r["data"])
		await lookup()
	return r


func send_verification() -> Dictionary:
	return await _req(_auth_url("sendOobCode"), HTTPClient.METHOD_POST, {"requestType": "VERIFY_EMAIL", "idToken": id_token})


func send_password_reset(mail: String) -> Dictionary:
	return await _req(_auth_url("sendOobCode"), HTTPClient.METHOD_POST, {"requestType": "PASSWORD_RESET", "email": mail})


# Consulta si el correo ya está verificado. Si lo está, renueva el token (la marca email_verified
# del token solo se actualiza al renovarlo, y las reglas de Firestore la usan).
func lookup() -> Dictionary:
	var r: Dictionary = await _req(_auth_url("lookup"), HTTPClient.METHOD_POST, {"idToken": id_token})
	if r["ok"] and r["data"] is Dictionary and (r["data"] as Dictionary).has("users"):
		var u: Dictionary = r["data"]["users"][0]
		var was: bool = email_verified
		email_verified = bool(u.get("emailVerified", false))
		if email_verified and not was:
			await refresh()
	return r


# Renueva la sesión con el refresh token guardado (inicio de sesión automático al abrir el juego).
func refresh(rt: String = "") -> Dictionary:
	if rt != "":
		refresh_token = rt
	var body: String = "grant_type=refresh_token&refresh_token=" + refresh_token.uri_encode()
	var r: Dictionary = await _req(_token_url(), HTTPClient.METHOD_POST, body, false, "application/x-www-form-urlencoded")
	if r["ok"]:
		_take_session(r["data"])
	return r


func ensure_token() -> bool:
	if id_token == "" or Time.get_unix_time_from_system() > expires_at:
		if refresh_token == "":
			return false
		var r: Dictionary = await refresh()
		return bool(r["ok"])
	return true


func sign_out() -> void:
	uid = ""
	email = ""
	id_token = ""
	refresh_token = ""
	email_verified = false


# ---------- Firestore: conversión de valores ----------

static func to_fs(v: Variant) -> Dictionary:
	match typeof(v):
		TYPE_NIL:
			return {"nullValue": null}
		TYPE_BOOL:
			return {"booleanValue": v}
		TYPE_INT:
			return {"integerValue": str(v)}
		TYPE_FLOAT:
			return {"doubleValue": v}
		TYPE_ARRAY:
			var vals: Array = []
			for x in v:
				vals.append(to_fs(x))
			return {"arrayValue": {"values": vals}}
		TYPE_DICTIONARY:
			return {"mapValue": {"fields": fields_of(v)}}
	return {"stringValue": str(v)}


static func fields_of(d: Dictionary) -> Dictionary:
	var f: Dictionary = {}
	for k in d:
		f[str(k)] = to_fs(d[k])
	return f


static func from_fs(v: Dictionary) -> Variant:
	if v.has("stringValue"):
		return str(v["stringValue"])
	if v.has("integerValue"):
		return int(v["integerValue"])
	if v.has("doubleValue"):
		return float(v["doubleValue"])
	if v.has("booleanValue"):
		return bool(v["booleanValue"])
	if v.has("timestampValue"):
		return str(v["timestampValue"])
	if v.has("arrayValue"):
		var out: Array = []
		for x in (v["arrayValue"] as Dictionary).get("values", []):
			out.append(from_fs(x))
		return out
	if v.has("mapValue"):
		return doc_data((v["mapValue"] as Dictionary))
	return null


static func doc_data(doc: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var f: Dictionary = doc.get("fields", {})
	for k in f:
		out[k] = from_fs(f[k])
	return out


# ---------- Firestore: documentos ----------

func get_doc(path: String) -> Dictionary:
	if not await ensure_token():
		return {"ok": false, "code": 401, "data": null, "error": "NO_SESSION"}
	var r: Dictionary = await _req(_fs_url("/" + path), HTTPClient.METHOD_GET, null, true)
	if r["ok"]:
		r["data"] = doc_data(r["data"])
	return r


# Escribe (crea o reemplaza) un documento. Con `only` se actualizan solo esos campos (updateMask).
func set_doc(path: String, data: Dictionary, only: Array = []) -> Dictionary:
	if not await ensure_token():
		return {"ok": false, "code": 401, "data": null, "error": "NO_SESSION"}
	var url: String = _fs_url("/" + path)
	if not only.is_empty():
		var q: PackedStringArray = PackedStringArray()
		for k in only:
			q.append("updateMask.fieldPaths=" + str(k).uri_encode())
		url += "?" + "&".join(q)
	return await _req(url, HTTPClient.METHOD_PATCH, {"fields": fields_of(data)}, true)


func delete_doc(path: String) -> Dictionary:
	if not await ensure_token():
		return {"ok": false, "code": 401, "data": null, "error": "NO_SESSION"}
	return await _req(_fs_url("/" + path), HTTPClient.METHOD_DELETE, null, true)


# Solicitudes de docente pendientes (solo las puede leer un administrador, según las reglas).
func pending_teachers() -> Dictionary:
	if not await ensure_token():
		return {"ok": false, "code": 401, "data": [], "error": "NO_SESSION"}
	var q: Dictionary = {"structuredQuery": {"from": [{"collectionId": "teacher_requests"}],
		"where": {"fieldFilter": {"field": {"fieldPath": "status"}, "op": "EQUAL", "value": {"stringValue": "pending"}}}}}
	var r: Dictionary = await _req(_fs_url(":runQuery"), HTTPClient.METHOD_POST, q, true)
	var out: Array = []
	if r["ok"] and r["data"] is Array:
		for row in r["data"]:
			if row is Dictionary and (row as Dictionary).has("document"):
				var d: Dictionary = doc_data(row["document"])
				d["uid"] = str(row["document"]["name"]).get_file()
				out.append(d)
	r["data"] = out
	return r


func is_admin() -> bool:
	if uid == "":
		return false
	var r: Dictionary = await get_doc("admins/" + uid)
	return bool(r["ok"])
