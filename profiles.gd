extends Node
# v35 — Perfiles de jugador (solo en este dispositivo; NO hay servidor todavia).
#  - "edu": cuenta educativa (correo) con rol "student" o "teacher".
#      * teacher: queda en estado "pending" (pendiente de verificacion). Verificar de verdad y avisar
#        al administrador por correo necesita un servidor: aqui solo se registra la solicitud.
#      * student: se une a clases con un codigo que le da el docente.
#  - "personal": cuenta personal (correo); guardado propio. La sincronizacion entre dispositivos
#        (web/APK) necesita un servidor: hoy el guardado es local.
#  - "guest": invitado; su partida se borra al volver a abrir el juego (no se conserva).
# El correo NO se verifica (cualquiera puede escribir cualquier direccion) y se guarda en texto
# plano en user://profiles.cfg de este dispositivo.
#
# Clases sin servidor: el docente elige misiones y obtiene un codigo «PER-XXXX» que lleva dentro
# esas misiones (mascara de bits + control de errores de tecleo). No es seguro ni secreto: solo
# evita tener que montar un servidor para compartir una seleccion de misiones.

const CFG: String = "user://profiles.cfg"
const GUEST_SAVE: String = "user://save_guest.json"
const LEGACY_SAVE: String = "user://savegame.json"
const B32: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"   # sin 0/O ni 1/I para evitar confusiones

signal changed

var game = null
var list: Dictionary = {}       # id -> perfil (Dictionary)
var current: Dictionary = {}    # perfil activo ({} = ninguno elegido)


var fb: Node = null               # v36: cliente de Firebase (firebase.gd)
var cloud_note: String = ""       # ultimo estado de la nube (para la interfaz)


func setup(g) -> void:
	game = g
	if fb == null:
		fb = Node.new()
		fb.set_script(load("res://firebase.gd"))
		fb.name = "Firebase"
		add_child(fb)
	current = {}
	game.set("SAVE_PATH", LEGACY_SAVE)
	_load()
	# la partida de invitado no se conserva entre sesiones
	if FileAccess.file_exists(GUEST_SAVE):
		DirAccess.remove_absolute(GUEST_SAVE)
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		var last: String = str(cfg.get_value("meta", "last", ""))
		if list.has(last):
			activate(last)


# ---------- persistencia ----------

func _load() -> void:
	list.clear()
	var cfg := ConfigFile.new()
	if cfg.load(CFG) != OK:
		return
	for s in cfg.get_sections():
		if s.begins_with("p_"):
			var p: Dictionary = {}
			for k in cfg.get_section_keys(s):
				p[k] = cfg.get_value(s, k)
			list[s.substr(2)] = p


func _save() -> void:
	var cfg := ConfigFile.new()
	for id in list:
		for k in list[id]:
			cfg.set_value("p_" + str(id), k, list[id][k])
	cfg.set_value("meta", "last", str(current.get("id", "")) if str(current.get("type", "")) != "guest" else "")
	cfg.save(CFG)


# ---------- crear / activar ----------

static func valid_email(e: String) -> bool:
	var r := RegEx.new()
	r.compile("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$")
	return r.search(e.strip_edges()) != null


func _new_id() -> String:
	return "%d%04d" % [Time.get_unix_time_from_system(), randi() % 10000]


func create(type: String, email: String, role: String = "", extra: Dictionary = {}) -> Dictionary:
	if type == "guest":
		current = {"id": "guest", "type": "guest", "email": "", "role": ""}
		game.set("SAVE_PATH", GUEST_SAVE)
		_save()
		changed.emit()
		return current
	var id: String = _new_id()
	var p: Dictionary = {"id": id, "type": type, "email": email.strip_edges().to_lower(), "role": role,
		"created": Time.get_datetime_string_from_system(false, true), "classes": []}
	if role == "teacher":
		p["teacher_status"] = "pending"
		p["teacher_name"] = str(extra.get("name", ""))
		p["teacher_school"] = str(extra.get("school", ""))
	# el primer perfil con cuenta adopta la partida que ya hubiera en este dispositivo
	var path: String = "user://save_%s.json" % id
	if _accounts() == 0 and FileAccess.file_exists(LEGACY_SAVE):
		DirAccess.rename_absolute(LEGACY_SAVE, path)
	p["save"] = path
	list[id] = p
	activate(id)
	return p


func _accounts() -> int:
	return list.size()


func activate(id: String) -> void:
	if not list.has(id):
		return
	current = list[id]
	game.set("SAVE_PATH", str(current.get("save", LEGACY_SAVE)))
	_save()
	changed.emit()
	if is_cloud():
		_resume_cloud()


# ---------- v36: cuentas en la nube (Firebase) ----------

func cloud_ready() -> bool:
	return fb != null and bool(fb.call("configured"))


func is_cloud() -> bool:
	return str(current.get("uid", "")) != "" and cloud_ready()


# al abrir el juego o cambiar de perfil: recupera la sesion, la partida y el estado de docente
func _resume_cloud() -> void:
	var pid: String = str(current.get("id", ""))
	var r: Dictionary = await fb.call("refresh", str(current.get("refresh_token", "")))
	if str(r.get("error", "")) == "STALE" or str(current.get("id", "")) != pid:
		return     # mientras tanto se cambio de cuenta: no tocar la nueva
	if not bool(r["ok"]):
		cloud_note = Lang.t("Sin conexión: se juega con la copia de este dispositivo.")
		changed.emit()
		return
	await fb.call("lookup")
	if str(current.get("id", "")) != pid:
		return
	current["verified"] = bool(fb.get("email_verified"))
	await pull_profile()
	if str(current.get("id", "")) != pid:
		return
	await pull_save()
	cloud_note = Lang.t("Conectado a la nube.")
	changed.emit()


func _store_cloud_profile(type: String, role: String, extra: Dictionary = {}) -> Dictionary:
	# perfil local enlazado a la cuenta (uno por uid en este dispositivo)
	var u: String = str(fb.get("uid"))
	var id: String = ""
	for k in list:
		if str(list[k].get("uid", "")) == u:
			id = str(k)
	if id == "":
		id = _new_id()
		list[id] = {"id": id, "save": "user://save_%s.json" % id, "classes": [],
			"created": Time.get_datetime_string_from_system(false, true)}
	var p: Dictionary = list[id]
	p["uid"] = u
	p["email"] = str(fb.get("email")).to_lower()
	p["type"] = type
	p["role"] = role
	p["refresh_token"] = str(fb.get("refresh_token"))
	p["verified"] = bool(fb.get("email_verified"))
	for k in extra:
		p[k] = extra[k]
	list[id] = p
	current = p
	game.set("SAVE_PATH", str(p["save"]))
	_save()
	changed.emit()
	return p


# crear cuenta. Devuelve "" si todo fue bien o el mensaje de error para el jugador.
func cloud_register(type: String, mail: String, password: String, role: String = "", extra: Dictionary = {}) -> String:
	var r: Dictionary = await fb.call("sign_up", mail.strip_edges().to_lower(), password)
	if not bool(r["ok"]):
		return fb.call("friendly", str(r["error"]))
	var st: String = "pending" if role == "teacher" else "none"
	var doc: Dictionary = {"email": str(fb.get("email")), "type": type, "role": role, "teacher_status": st,
		"classes": [], "created": Time.get_datetime_string_from_system(true, true)}
	if role == "teacher":
		doc["teacher_name"] = str(extra.get("name", ""))
		doc["teacher_school"] = str(extra.get("school", ""))
	var w: Dictionary = await fb.call("set_doc", "users/" + str(fb.get("uid")), doc)
	await fb.call("send_verification")
	var ex: Dictionary = {"teacher_status": st}
	for k in extra:
		ex["teacher_" + str(k)] = extra[k]
	_store_cloud_profile(type, role, ex)
	if not bool(w["ok"]):
		cloud_note = fb.call("friendly", str(w["error"]))
	return ""


# iniciar sesion con una cuenta existente (en este u otro dispositivo)
func cloud_login(mail: String, password: String) -> String:
	var r: Dictionary = await fb.call("sign_in", mail.strip_edges().to_lower(), password)
	if not bool(r["ok"]):
		return fb.call("friendly", str(r["error"]))
	var d: Dictionary = await fb.call("get_doc", "users/" + str(fb.get("uid")))
	var data: Dictionary = d["data"] if bool(d["ok"]) else {}
	_store_cloud_profile(str(data.get("type", "personal")), str(data.get("role", "")),
		{"teacher_status": str(data.get("teacher_status", "none")), "classes": data.get("classes", [])})
	await pull_save()
	return ""


func resend_verification() -> bool:
	var r: Dictionary = await fb.call("send_verification")
	return bool(r["ok"])


# comprueba si el jugador ya pulso el enlace del correo
func check_verified() -> bool:
	if not is_cloud():
		return false
	await fb.call("ensure_token")
	await fb.call("lookup")
	current["verified"] = bool(fb.get("email_verified"))
	list[str(current["id"])] = current
	_save()
	changed.emit()
	return bool(current["verified"])


# docente: envia la solicitud (requiere correo verificado; lo exigen las reglas)
func submit_teacher_request() -> String:
	if not await check_verified():
		return Lang.t("Primero verifica tu correo: abre el enlace que te enviamos.")
	var req: Dictionary = {"email": str(fb.get("email")), "name": str(current.get("teacher_name", "")),
		"school": str(current.get("teacher_school", "")), "status": "pending", "created": Time.get_datetime_string_from_system(true, true)}
	var r: Dictionary = await fb.call("set_doc", "teacher_requests/" + str(current["uid"]), req)
	if not bool(r["ok"]):
		return fb.call("friendly", str(r["error"]))
	current["request_sent"] = true
	list[str(current["id"])] = current
	_save()
	changed.emit()
	return ""


func pull_profile() -> void:
	if not is_cloud():
		return
	var d: Dictionary = await fb.call("get_doc", "users/" + str(current["uid"]))
	if bool(d["ok"]):
		current["teacher_status"] = str(d["data"].get("teacher_status", current.get("teacher_status", "none")))
		var cc: Array = d["data"].get("classes", [])
		for c in cc:
			if not (current.get("classes", []) as Array).has(c):
				(current["classes"] as Array).append(c)
		list[str(current["id"])] = current
		_save()


func push_profile() -> void:
	if not is_cloud():
		return
	await fb.call("set_doc", "users/" + str(current["uid"]), {"classes": current.get("classes", [])}, ["classes"])


# partida: copia en la nube despues de cada guardado local.
# Las subidas van de una en una y siempre se sube el archivo MAS RECIENTE (si se guarda dos veces
# seguidas, la segunda subida espera a la primera: asi una version vieja nunca pisa a una nueva).
var _uploading: bool = false
var _upload_again: bool = false


func on_saved() -> void:
	if not is_cloud():
		return
	if _uploading:
		_upload_again = true
		return
	_uploading = true
	while true:
		_upload_again = false
		var path: String = str(current.get("save", ""))
		if not FileAccess.file_exists(path):
			break
		var txt: String = FileAccess.get_file_as_string(path)
		var now: int = int(Time.get_unix_time_from_system())
		current["save_updated"] = now
		list[str(current["id"])] = current
		_save()
		var r: Dictionary = await fb.call("set_doc", "saves/" + str(current["uid"]), {"data": txt, "updated": now, "version": 2})
		cloud_note = Lang.t("Partida guardada en la nube.") if bool(r["ok"]) else Lang.t("No se pudo subir la partida (se guardó en este dispositivo).")
		if not _upload_again:
			break
	_uploading = false


# descarga la partida de la nube si es mas reciente que la de este dispositivo
func pull_save() -> void:
	if not is_cloud():
		return
	var d: Dictionary = await fb.call("get_doc", "saves/" + str(current["uid"]))
	if not bool(d["ok"]):
		return
	var cloud_t: int = int(d["data"].get("updated", 0))
	var path: String = str(current["save"])
	if not FileAccess.file_exists(path) or cloud_t > int(current.get("save_updated", 0)):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(str(d["data"].get("data", "")))
			f.close()
			current["save_updated"] = cloud_t
			list[str(current["id"])] = current
			_save()


# ---------- v36: administrador ----------

func is_admin() -> bool:
	return is_cloud() and bool(await fb.call("is_admin"))


func pending_teachers() -> Array:
	var r: Dictionary = await fb.call("pending_teachers")
	return r["data"] if bool(r["ok"]) else []


func review_teacher(teacher_uid: String, approve: bool) -> bool:
	var now: int = int(Time.get_unix_time_from_system())
	var r1: Dictionary = await fb.call("set_doc", "teacher_requests/" + teacher_uid, {"status": "approved" if approve else "rejected", "reviewed_at": now}, ["status", "reviewed_at"])
	var r2: Dictionary = {"ok": true}
	if approve:
		r2 = await fb.call("set_doc", "users/" + teacher_uid, {"teacher_status": "verified"}, ["teacher_status"])
	return bool(r1["ok"]) and bool(r2["ok"])


func remove(id: String) -> void:
	if not list.has(id):
		return
	var path: String = str(list[id].get("save", ""))
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	list.erase(id)
	if str(current.get("id", "")) == id:
		current = {}
	_save()
	changed.emit()


func sign_out() -> void:
	if fb != null:
		fb.call("sign_out")
	current = {}
	_save()
	changed.emit()


func is_guest() -> bool:
	return str(current.get("type", "")) == "guest"


func is_teacher() -> bool:
	return str(current.get("role", "")) == "teacher"


func is_student() -> bool:
	return str(current.get("type", "")) == "edu" and str(current.get("role", "")) == "student"


func label() -> String:
	if current.is_empty():
		return Lang.t("Sin perfil")
	if is_guest():
		return Lang.t("Invitado")
	var kind: String = Lang.t("Personal")
	if str(current["type"]) == "edu":
		kind = Lang.t("Docente") if is_teacher() else Lang.t("Estudiante")
	return "%s · %s" % [str(current.get("email", "")), kind]


# ---------- clases con codigo ----------

static func _chk(mask: int) -> int:
	return (mask * 7 + 13) % 32


# misiones: Array de indices (0..n-1) de lesson_data.MISSIONS
static func make_code(missions: Array) -> String:
	var mask: int = 0
	for i in missions:
		mask |= 1 << int(i)
	var v: int = mask | (_chk(mask) << 9)     # 9 bits de misiones + 5 de control = 14 bits
	var s: String = ""
	for k in 3:
		s = B32[v % 32] + s
		v = v / 32
	return "PER-" + B32[1] + s                 # primer caracter: version del formato (1)


static func read_code(code: String) -> Array:
	# devuelve los indices de misiones, o [] si el codigo no es valido
	var c: String = code.strip_edges().to_upper().replace(" ", "").replace("PER-", "").replace("PER", "")
	if c.length() != 4 or c[0] != B32[1]:
		return []
	var v: int = 0
	for k in range(1, 4):
		var d: int = B32.find(c[k])
		if d < 0:
			return []
		v = v * 32 + d
	var mask: int = v & 511
	if mask == 0 or (v >> 9) != _chk(mask):
		return []
	var out: Array = []
	for i in 9:
		if mask & (1 << i):
			out.append(i)
	return out


func join_class(code: String) -> bool:
	var ms: Array = read_code(code)
	if ms.is_empty() or current.is_empty() or is_guest():
		return false
	var norm: String = make_code(ms)
	var cls: Array = current.get("classes", [])
	if not cls.has(norm):
		cls.append(norm)
	current["classes"] = cls
	list[str(current["id"])] = current
	_save()
	changed.emit()
	push_profile()
	return true


func leave_class(code: String) -> void:
	var cls: Array = current.get("classes", [])
	cls.erase(code)
	current["classes"] = cls
	if list.has(str(current.get("id", ""))):
		list[str(current["id"])] = current
	_save()
	changed.emit()


func add_teacher_class(code: String) -> void:
	var cls: Array = current.get("classes", [])
	if not cls.has(code):
		cls.append(code)
	current["classes"] = cls
	list[str(current["id"])] = current
	_save()
	changed.emit()
