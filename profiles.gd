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


func setup(g) -> void:
	game = g
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
