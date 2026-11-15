extends Control
# Inventario con iconos para el HUD. Si existe res://art/icons/<id>.png se usa esa imagen
# (por ejemplo generada con Ludo.ai); si no, se dibuja un icono sencillo por codigo.

const ICON: float = 22.0
const MATS: Array = ["scrap", "polymer", "circuits"]
const TOOLS: Array = ["patch", "medkit", "repair", "filter", "map"]
var LABELS: Dictionary = {"scrap": Lang.t("Chatarra"), "polymer": Lang.t("Polímero"), "circuits": Lang.t("Circuitos"),
	"patch": Lang.t("Kit de parche"), "medkit": Lang.t("Botiquín"), "repair": Lang.t("Reparador"), "filter": Lang.t("Filtro de polvo"), "map": Lang.t("Mapa")}

var game = null
var _tex_cache: Dictionary = {}
var _fly: Array = []      # {id, t, from}
var _bounce: Dictionary = {}  # id -> tiempo restante


func fly(id: String) -> void:
	# icono que vuela desde el centro de la pantalla hasta su casilla del HUD y rebota
	var from: Vector2 = get_viewport_rect().size * 0.5 - global_position
	_fly.append({"id": id, "t": 0.0, "from": from})
	set_process(true)


func _init() -> void:
	custom_minimum_size = Vector2(290, 76)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func refresh() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	for e in _fly:
		e["t"] = float(e["t"]) + delta / 0.7
	var i: int = _fly.size() - 1
	while i >= 0:
		if float(_fly[i]["t"]) >= 1.0:
			_bounce[str(_fly[i]["id"])] = 0.45
			_fly.remove_at(i)
		i -= 1
	for k in _bounce.keys():
		_bounce[k] = float(_bounce[k]) - delta
		if float(_bounce[k]) <= 0.0:
			_bounce.erase(k)
	queue_redraw()
	if _fly.is_empty() and _bounce.is_empty():
		set_process(false)


func _cell_pos(id: String) -> Vector2:
	if MATS.has(id):
		return Vector2(78.0 * MATS.find(id), 14.0)
	return Vector2(47.0 * TOOLS.find(id), 56.0)


func _tex(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var t: Texture2D = null
	var path: String = "res://art/icons/%s.png" % id
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[id] = t
	return t


func _count(id: String) -> int:
	if MATS.has(id):
		return int(game.inv[id])
	return int(game.tools[id])


func _draw() -> void:
	if game == null:
		return
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(0, 10), Lang.t("Materiales"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.72, 0.9))
	var x: float = 0.0
	for id in MATS:
		_cell(font, id, Vector2(x, 14.0))
		x += 78.0
	draw_string(font, Vector2(0, 52), Lang.t("Herramientas"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.72, 0.9))
	x = 0.0
	for id in TOOLS:
		_cell(font, id, Vector2(x, 56.0))
		x += 47.0
	for e in _fly:
		var u: float = clampf(float(e["t"]), 0.0, 1.0)
		var eu: float = u * u * (3.0 - 2.0 * u)
		var tgt: Vector2 = _cell_pos(str(e["id"])) + Vector2(ICON, ICON) * 0.5
		var pos: Vector2 = (e["from"] as Vector2).lerp(tgt, eu) - Vector2(0, sin(PI * u) * 60.0)
		var sz: float = lerpf(34.0, ICON, eu)
		var rr := Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
		var tx: Texture2D = _tex(str(e["id"]))
		if tx != null:
			draw_texture_rect(tx, rr, false)
		else:
			_icon(str(e["id"]), rr, 1.0)


func _cell(font: Font, id: String, p: Vector2) -> void:
	var n: int = _count(id)
	var a: float = 1.0 if n > 0 else 0.42
	var r := Rect2(p, Vector2(ICON, ICON))
	if _bounce.has(id):
		var b: float = float(_bounce[id]) / 0.45
		var sc: float = 1.0 + 0.45 * sin(PI * (1.0 - b))
		r = Rect2(r.get_center() - r.size * sc * 0.5, r.size * sc)
	var tx: Texture2D = _tex(id)
	if tx != null:
		draw_texture_rect(tx, r, false, Color(1, 1, 1, a))
	else:
		_icon(id, r, a)
	if game != null and str(game.held) == id and n > 0:
		draw_rect(r.grow(3.0), Color(1.0, 0.85, 0.3, 0.9), false, 2.0)
	var txt: String = str(n)
	if id == "map":
		txt = "sí" if n > 0 else "no"
	draw_string(font, p + Vector2(ICON + 4.0, 16.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55 + 0.45 * a))


func _icon(id: String, r: Rect2, a: float) -> void:
	var c: Vector2 = r.get_center()
	match id:
		"scrap":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 4), c + Vector2(-5, -7), c + Vector2(3, -9), c + Vector2(9, -1), c + Vector2(6, 8), c + Vector2(-4, 9)]), Color(0.58, 0.6, 0.68, a))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -7), c + Vector2(3, -9), c + Vector2(1, -1), c + Vector2(-6, 0)]), Color(0.85, 0.88, 0.95, a))
		"polymer":
			draw_rect(Rect2(c + Vector2(-6, -7), Vector2(12, 15)), Color(0.35, 0.6, 0.95, a))
			draw_rect(Rect2(c + Vector2(-4, -10), Vector2(8, 4)), Color(0.8, 0.85, 0.95, a))
			draw_rect(Rect2(c + Vector2(-6, -1), Vector2(12, 4)), Color(1, 1, 1, 0.35 * a))
		"circuits":
			draw_rect(Rect2(c + Vector2(-8, -8), Vector2(16, 16)), Color(0.15, 0.55, 0.3, a))
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 8)), Color(0.12, 0.14, 0.18, a))
			for i in 3:
				draw_line(c + Vector2(-10, -4 + i * 4), c + Vector2(-8, -4 + i * 4), Color(0.95, 0.8, 0.3, a), 1.5)
				draw_line(c + Vector2(8, -4 + i * 4), c + Vector2(10, -4 + i * 4), Color(0.95, 0.8, 0.3, a), 1.5)
			draw_line(c + Vector2(-8, 6), c + Vector2(-2, 6), Color(0.5, 0.9, 0.6, a), 1.0)
		"patch":
			draw_rect(Rect2(c + Vector2(-8, -8), Vector2(16, 16)), Color(0.95, 0.55, 0.2, a))
			draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), Color(1, 1, 1, 0.55 * a), 1.5)
			draw_line(c + Vector2(8, -8), c + Vector2(-8, 8), Color(1, 1, 1, 0.55 * a), 1.5)
			draw_rect(Rect2(c + Vector2(-8, -8), Vector2(16, 16)), Color(0.45, 0.2, 0.05, a), false, 1.0)
		"medkit":
			draw_rect(Rect2(c + Vector2(-9, -6), Vector2(18, 14)), Color(0.95, 0.95, 0.97, a))
			draw_rect(Rect2(c + Vector2(-3, -9), Vector2(6, 3)), Color(0.7, 0.72, 0.78, a))
			draw_rect(Rect2(c + Vector2(-2, -4), Vector2(4, 10)), Color(0.9, 0.15, 0.15, a))
			draw_rect(Rect2(c + Vector2(-5, -1), Vector2(10, 4)), Color(0.9, 0.15, 0.15, a))
		"repair":
			draw_line(c + Vector2(-7, 8), c + Vector2(4, -3), Color(0.8, 0.82, 0.9, a), 3.5)
			draw_arc(c + Vector2(6, -6), 5.0, 0.6, 5.4, 12, Color(0.95, 0.8, 0.25, a), 3.0)
		"filter":
			draw_rect(Rect2(c + Vector2(-7, -8), Vector2(14, 16)), Color(0.55, 0.57, 0.65, a))
			for i in 4:
				draw_line(c + Vector2(-7, -5 + i * 4), c + Vector2(7, -5 + i * 4), Color(0.2, 0.22, 0.28, a), 1.5)
			draw_rect(Rect2(c + Vector2(-8, -10), Vector2(16, 3)), Color(0.8, 0.82, 0.9, a))
		"map":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -7), c + Vector2(-3, -9), c + Vector2(3, -7), c + Vector2(9, -9), c + Vector2(9, 7), c + Vector2(3, 9), c + Vector2(-3, 7), c + Vector2(-9, 9)]), Color(0.92, 0.85, 0.6, a))
			draw_line(c + Vector2(-3, -9), c + Vector2(-3, 7), Color(0.5, 0.4, 0.2, a), 1.0)
			draw_line(c + Vector2(3, -7), c + Vector2(3, 9), Color(0.5, 0.4, 0.2, a), 1.0)
			draw_circle(c + Vector2(5, 0), 1.8, Color(0.85, 0.2, 0.2, a))
