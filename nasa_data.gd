extends Node
# Datos en vivo de la NASA para la parte de aprendizaje.
# Solo usa el endpoint APOD ("Astronomy Picture of the Day") de api.nasa.gov:
#   GET https://api.nasa.gov/planetary/apod?api_key=<clave>
# Campos que se leen (todos opcionales y comprobados en el codigo): title, explanation, url, media_type, date, copyright.
# Sin conexion, sin clave valida o con el limite agotado, el juego sigue con la leccion integrada.
# La clave por defecto es DEMO_KEY (limite documentado: 30 peticiones/hora y 50/dia por IP);
# el jugador puede escribir su propia clave gratuita de https://api.nasa.gov

signal updated

const APOD_URL: String = "https://api.nasa.gov/planetary/apod"
const CACHE_PATH: String = "user://nasa_cache.json"
const IMG_PATH: String = "user://nasa_apod.img"
const MAX_IMG_BYTES: int = 8000000

var key: String = "DEMO_KEY"
var status: String = "idle"   # idle | loading | ok | cached | error
var message: String = ""
var data: Dictionary = {}
var tex: ImageTexture = null
var _req: HTTPRequest
var _img_req: HTTPRequest


func _ready() -> void:
	_req = HTTPRequest.new()
	_req.timeout = 12.0
	_req.request_completed.connect(_on_apod)
	add_child(_req)
	_img_req = HTTPRequest.new()
	_img_req.timeout = 20.0
	_img_req.body_size_limit = MAX_IMG_BYTES
	_img_req.request_completed.connect(_on_image)
	add_child(_img_req)
	_load_cache()


func today() -> String:
	return Time.get_date_string_from_system(true)


func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if j is Dictionary and j.has("title"):
		data = j
		_load_cached_image()
		status = "cached"
		message = Lang.t("Guardado el %s (sin consultar de nuevo hoy).") % str(data.get("_fetched", "?"))


func _save_cache() -> void:
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func _load_cached_image() -> void:
	if not FileAccess.file_exists(IMG_PATH):
		return
	var b: PackedByteArray = FileAccess.get_file_as_bytes(IMG_PATH)
	_set_image(b)


func fetch(force: bool = false) -> void:
	if status == "loading":
		return
	if not force and not data.is_empty() and str(data.get("_fetched", "")) == today():
		status = "cached"
		message = Lang.t("Dato de hoy ya descargado.")
		updated.emit()
		return
	var k: String = key.strip_edges()
	if k == "":
		k = "DEMO_KEY"
	status = "loading"
	message = Lang.t("Consultando api.nasa.gov…")
	updated.emit()
	var err: int = _req.request(APOD_URL + "?api_key=" + k.uri_encode())
	if err != OK:
		_fail(Lang.t("No se pudo iniciar la petición (código %d).") % err)


func _fail(msg: String) -> void:
	status = "error" if data.is_empty() else "cached"
	message = msg + (Lang.t(" Se muestra el último dato guardado.") if not data.is_empty() else Lang.t(" Usa la lección integrada (funciona sin conexión)."))
	updated.emit()


func parse_apod(text: String) -> Dictionary:
	# devuelve {} si la respuesta no tiene el formato esperado
	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.data is Dictionary):
		return {}
	var d: Dictionary = parser.data
	if not d.has("title") or not d.has("explanation"):
		return {}
	var out: Dictionary = {}
	for f in ["title", "explanation", "url", "media_type", "date", "copyright"]:
		if d.has(f):
			out[f] = str(d[f])
	return out


func _on_apod(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail(Lang.t("Sin conexión con api.nasa.gov (resultado %d).") % result)
		return
	if code == 429:
		_fail(Lang.t("Límite de peticiones agotado para esta clave (DEMO_KEY: 30/hora y 50/día)."))
		return
	if code == 403 or code == 401:
		_fail(Lang.t("La clave fue rechazada (código %d). Revisa la clave.") % code)
		return
	if code != 200:
		_fail(Lang.t("Respuesta inesperada de la API (código %d).") % code)
		return
	var d: Dictionary = parse_apod(body.get_string_from_utf8())
	if d.is_empty():
		_fail(Lang.t("La respuesta de la API no tiene el formato esperado."))
		return
	d["_fetched"] = today()
	data = d
	tex = null
	status = "ok"
	message = Lang.t("Descargado de api.nasa.gov.")
	_save_cache()
	updated.emit()
	var u: String = str(d.get("url", ""))
	if str(d.get("media_type", "")) == "image" and u.begins_with("https://"):
		_img_req.request(u)


func _on_image(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() < 100:
		return
	if _set_image(body):
		var f := FileAccess.open(IMG_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(body)
			f.close()
		updated.emit()


# Tipo de imagen por sus primeros bytes: "jpg", "png", "webp" o "" (desconocido: no se intenta cargar).
static func image_kind(b: PackedByteArray) -> String:
	if b.size() >= 3 and b[0] == 0xFF and b[1] == 0xD8 and b[2] == 0xFF:
		return "jpg"
	if b.size() >= 8 and b[0] == 0x89 and b[1] == 0x50 and b[2] == 0x4E and b[3] == 0x47:
		return "png"
	if b.size() >= 12 and b.slice(0, 4).get_string_from_ascii() == "RIFF" and b.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	return ""


func _set_image(b: PackedByteArray) -> bool:
	# v40: se elige el cargador por la firma del archivo. Antes se probaba JPEG primero y, si la imagen era
	# PNG/WebP, Godot 4.7 escribia "ERR_PARSE_ERROR" en la consola aunque luego se cargara bien.
	var img := Image.new()
	var err: int = ERR_FILE_UNRECOGNIZED
	match image_kind(b):
		"jpg":
			err = img.load_jpg_from_buffer(b)
		"png":
			err = img.load_png_from_buffer(b)
		"webp":
			err = img.load_webp_from_buffer(b)
	if err != OK or img.get_width() < 2:
		return false
	var w: int = img.get_width()
	if w > 720:
		img.resize(720, int(float(img.get_height()) * 720.0 / float(w)), Image.INTERPOLATE_BILINEAR)
	tex = ImageTexture.create_from_image(img)
	return true


func daily_line() -> String:
	if data.is_empty():
		return ""
	return Lang.t("Foto astronómica del día (NASA APOD, %s): %s") % [str(data.get("date", "")), str(data.get("title", ""))]
