extends RefCounted
# v32 — Minijuegos nuevos del banco de trabajo (los usa minigames.gd; no cambian la logica del juego:
# como antes, al superarlos se fabrica la herramienta y los errores solo se cuentan).
#  - "layers"  Filtro de polvo: ordena las capas del filtro de la mas gruesa a la mas fina.
#  - "puzzle"  Mapa: recompone la foto «de satelite» del terreno (3x3 piezas, se intercambian).
#  - "leak"    Kit de parche: sella las grietas antes de que baje demasiado la presion.
# Datos citados (verificados en la sesion v32, ver DATOS.md): LRO ha cartografiado la Luna y un
# mosaico de la Luna llena usa 1.231 fotos de su camara; la camara HiRISE de MRO ve detalles de ≈ 1 m.

const DS = preload("res://design_system.gd")

var st: Dictionary = {}


static func is_new(kind: String) -> bool:
	return kind == "layers" or kind == "puzzle" or kind == "leak"


func setup(m: Control, kind: String) -> void:
	st = {"kind": kind}
	match kind:
		"layers":
			# indice 0 = la mas gruesa
			var order: Array = [0, 1, 2, 3]
			order.shuffle()
			if order == [0, 1, 2, 3]:
				order = [2, 0, 3, 1]
			st["cards"] = order
			st["placed"] = []
			st["note"] = ""
		"puzzle":
			st["tex"] = _orbital_tex(m.game)
			var perm: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8]
			while _solved(perm):
				perm.shuffle()
			st["perm"] = perm       # perm[casilla] = pieza que se ve ahi
			st["sel"] = -1
		"leak":
			st["pressure"] = 100.0
			st["sealed"] = []
			st["crack"] = Vector2(-1, -1)
			st["crack_t"] = 0.0
			st["wait"] = 0.8
			st["total"] = 5
			st["note"] = ""
			st["grow"] = 0.0


static func _solved(perm: Array) -> bool:
	for i in perm.size():
		if int(perm[i]) != i:
			return false
	return true


# ---------- foto orbital (rompecabezas del mapa) ----------

static func _orbital_tex(g) -> Texture2D:
	# 36 x 36 casillas alrededor de la base, 4 px por casilla, con sombreado del relieve real del juego
	var v = g.view3d if g != null else null
	var n: int = 36
	var ppt: int = 4
	var img := Image.create(n * ppt, n * ppt, false, Image.FORMAT_RGBA8)
	# encuadre: un crater, volcan o montana real del mapa (mas formas reconocibles que una llanura)
	var cx: int = int(g.BASE_X0)
	var cy: int = int(g.BASE_Y0) - 10
	for z in g.call("_zones"):
		if str(z.get("kind", "")) in ["crater", "volcano", "mountain"]:
			cx = int(z["cx"])
			cy = int(z["cy"])
			break
	var x0: int = clampi(cx - n / 2, 0, int(g.EXT_W) - n)
	var y0: int = clampi(cy - n / 2, 0, int(g.EXT_H) - n)
	# colores por casilla suavizados (sin «pixeles» de 4x4)
	var cimg := Image.create(n + 1, n + 1, false, Image.FORMAT_RGBA8)
	if v != null:
		for ty in n + 1:
			for tx in n + 1:
				cimg.set_pixel(tx, ty, v.call("_tile_color", clampi(x0 + tx, 0, int(g.EXT_W) - 1), clampi(y0 + ty, 0, int(g.EXT_H) - 1)))
	cimg.resize((n + 1) * ppt, (n + 1) * ppt, Image.INTERPOLATE_BILINEAR)
	var sun := Vector3(-0.6, 0.55, -0.45).normalized()
	for py in n * ppt:
		for px in n * ppt:
			var fx: float = float(x0) + (float(px) + 0.5) / float(ppt)
			var fy: float = float(y0) + (float(py) + 0.5) / float(ppt)
			var c := Color(0.5, 0.5, 0.5)
			var shade: float = 1.0
			if v != null:
				c = cimg.get_pixel(clampi(px + ppt / 2, 0, cimg.get_width() - 1), clampi(py + ppt / 2, 0, cimg.get_height() - 1))
				var e: float = 0.35
				var hx: float = float(v.call("ground_y", fx + e, fy)) - float(v.call("ground_y", fx - e, fy))
				var hy: float = float(v.call("ground_y", fx, fy + e)) - float(v.call("ground_y", fx, fy - e))
				var nrm := Vector3(-hx, 2.0 * e * 2.0, -hy).normalized()
				shade = clampf(0.2 + 1.3 * nrm.dot(sun), 0.2, 1.5)
			img.set_pixel(px, py, Color(c.r * shade * 1.25, c.g * shade * 1.25, c.b * shade * 1.25))
	return ImageTexture.create_from_image(img)


# ---------- entrada ----------

func click(m: Control, pos: Vector2, p: Rect2) -> void:
	match str(st.get("kind", "")):
		"layers":
			var rs: Array = _card_rects(p)
			for i in rs.size():
				if (rs[i] as Rect2).has_point(pos):
					_pick_layer(m, i)
					return
		"puzzle":
			var tiles: Array = _tile_rects(p)
			for i in tiles.size():
				if (tiles[i] as Rect2).has_point(pos):
					_pick_tile(m, i)
					return
		"leak":
			var cr: Vector2 = st["crack"]
			if cr.x >= 0.0 and pos.distance_to(_crack_pos(p, cr)) < 46.0:
				_seal(m)


func key(m: Control, k: InputEventKey, p: Rect2) -> void:
	match str(st.get("kind", "")):
		"layers":
			if k.keycode >= KEY_1 and k.keycode <= KEY_4:
				_pick_layer(m, int(k.keycode - KEY_1))
		"puzzle":
			if k.keycode >= KEY_1 and k.keycode <= KEY_9:
				_pick_tile(m, int(k.keycode - KEY_1))
		"leak":
			if k.keycode == KEY_E or k.keycode == KEY_SPACE or k.keycode == KEY_ENTER:
				if (st["crack"] as Vector2).x >= 0.0:
					_seal(m)


func _mistake(m: Control) -> void:
	m.mistakes += 1
	m.flash = 0.45
	m.game._sfx("error", -8.0)


# ---------- capas del filtro ----------

const LAYERS: Array = [
	["Malla gruesa", "atrapa las piedrecitas"],
	["Malla media", "atrapa la arena"],
	["Tela fina", "atrapa el polvo"],
	["Membrana muy fina", "atrapa el polvo finísimo"],
]


func _pick_layer(m: Control, i: int) -> void:
	var cards: Array = st["cards"]
	if i < 0 or i >= cards.size():
		return
	var want: int = (st["placed"] as Array).size()
	if int(cards[i]) == want:
		(st["placed"] as Array).append(cards[i])
		cards.remove_at(i)
		m.game._sfx("pickup", -8.0)
		st["note"] = ""
		if cards.is_empty():
			m.finished = true
	else:
		_mistake(m)
		st["note"] = Lang.t("Esa capa es más fina: si va primero, el polvo grande la tapa enseguida. Empieza por la más gruesa que quede.")


func _card_rects(p: Rect2) -> Array:
	var out: Array = []
	var cards: Array = st.get("cards", [])
	var x: float = p.position.x + p.size.x * 0.52
	var w: float = p.size.x * 0.44
	var row: float = _row(p)
	for i in cards.size():
		out.append(Rect2(x, p.position.y + 150.0 + float(i) * row, w, row - 12.0))
	return out


# alto de cada fila de capas segun el espacio (pantallas bajas: filas mas bajas)
static func _row(p: Rect2) -> float:
	return clampf((p.size.y - 220.0) / 4.0, 44.0, 78.0)


# ---------- rompecabezas ----------

func _tile_rects(p: Rect2) -> Array:
	var side: float = minf(p.size.y - 200.0, p.size.x * 0.5)
	var cell: float = side / 3.0
	var o := Vector2(p.position.x + 40.0, p.position.y + 140.0)
	var out: Array = []
	for i in 9:
		out.append(Rect2(o + Vector2(float(i % 3) * cell, float(i / 3) * cell), Vector2(cell - 4.0, cell - 4.0)))
	return out


func _pick_tile(m: Control, i: int) -> void:
	var perm: Array = st["perm"]
	var sel: int = int(st["sel"])
	if sel < 0:
		st["sel"] = i
		m.game._sfx("blip", -10.0)
		return
	if sel == i:
		st["sel"] = -1
		return
	var a: int = perm[sel]
	perm[sel] = perm[i]
	perm[i] = a
	st["sel"] = -1
	if int(perm[sel]) != sel and int(perm[i]) != i:
		m.mistakes += 1   # intercambio que no coloca ninguna pieza: solo se cuenta
	m.game._sfx("interact", -8.0)
	if _solved(perm):
		m.finished = true


# ---------- sellar la fuga ----------

func _crack_pos(p: Rect2, c: Vector2) -> Vector2:
	var area := Rect2(p.position + Vector2(40.0, 150.0), Vector2(p.size.x * 0.6, p.size.y - 230.0))
	return area.position + c * area.size


func _seal(m: Control) -> void:
	(st["sealed"] as Array).append(st["crack"])
	st["crack"] = Vector2(-1, -1)
	st["wait"] = 0.7
	st["pressure"] = minf(100.0, float(st["pressure"]) + 6.0)
	m.game._sfx("pickup", -6.0)
	if (st["sealed"] as Array).size() >= int(st["total"]):
		m.finished = true


func process(m: Control, delta: float) -> void:
	if str(st.get("kind", "")) != "leak" or m.finished:
		return
	var cr: Vector2 = st["crack"]
	if cr.x < 0.0:
		st["wait"] = float(st["wait"]) - delta
		if float(st["wait"]) <= 0.0:
			st["crack"] = Vector2(randf_range(0.12, 0.88), randf_range(0.15, 0.85))
			st["grow"] = 0.0
			m.game._sfx("alarm", -18.0)
	else:
		st["grow"] = minf(1.0, float(st["grow"]) + delta * 1.5)
		st["pressure"] = float(st["pressure"]) - delta * 7.0
		if float(st["pressure"]) < 55.0:
			_mistake(m)
			st["pressure"] = 80.0
			st["note"] = Lang.t("¡La presión bajó demasiado! El sistema repuso aire. Toca la grieta más rápido.")


# ---------- dibujo ----------

func _font() -> Font:
	return DS.font("Regular")


func draw(m: Control, p: Rect2) -> void:
	var f: Font = _font()
	var fb: Font = DS.font("SemiBold")
	match str(st.get("kind", "")):
		"layers":
			m._para(p.position + Vector2(30, 62), Lang.t("El aire entra por arriba con polvo de todos los tamaños. Coloca las capas del filtro en orden: primero la más gruesa y al final la más fina (clic o teclas 1-4)."), 17, Color(0.82, 0.88, 1.0), p.size.x - 60.0)
			# columna del filtro
			var row: float = _row(p)
			var col := Rect2(p.position.x + 60.0, p.position.y + 150.0, p.size.x * 0.34, 4.0 * row + 4.0)
			m.draw_string(f, col.position + Vector2(0, -10), Lang.t("Entrada de aire ↓"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DS.C_DIM)
			m.draw_rect(col, Color(DS.C_SURF1, 0.9))
			m.draw_rect(col, DS.C_LINE_HI, false, 2.0)
			var placed: Array = st["placed"]
			for i in 4:
				var r := Rect2(col.position.x + 8.0, col.position.y + 6.0 + float(i) * row, col.size.x - 16.0, row - 14.0)
				if i < placed.size():
					_layer_card(m, r, int(placed[i]), true)
				else:
					m.draw_rect(r, Color(1, 1, 1, 0.04))
					m.draw_rect(r, Color(DS.C_LINE, 0.9), false, 1.0)
					m.draw_string(f, r.position + Vector2(12, r.size.y / 2.0 + 5.0), Lang.t("Capa %d") % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DS.C_MUTED)
			m.draw_string(f, col.position + Vector2(0, col.size.y + 22.0), Lang.t("Aire limpio ↓"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DS.C_GOOD)
			var rs: Array = _card_rects(p)
			var cards: Array = st["cards"]
			for i in cards.size():
				_layer_card(m, rs[i], int(cards[i]), false, i + 1)
			if str(st["note"]) != "":
				var ny: float = p.position.y + 150.0 + float((st["cards"] as Array).size()) * row + 4.0
				m._para(Vector2(p.position.x + p.size.x * 0.52, minf(ny, p.end.y - 90.0)), str(st["note"]), 14, DS.C_WARN, p.size.x * 0.44)
		"puzzle":
			m._para(p.position + Vector2(30, 62), Lang.t("Recompón la foto del terreno tomada desde órbita: toca dos piezas para cambiarlas de sitio (o teclas 1-9)."), 17, Color(0.82, 0.88, 1.0), p.size.x - 60.0)
			var tex: Texture2D = st["tex"]
			var tiles: Array = _tile_rects(p)
			var perm: Array = st["perm"]
			var ts: Vector2 = tex.get_size() / 3.0
			for i in 9:
				var r: Rect2 = tiles[i]
				var piece: int = perm[i]
				var src := Rect2(Vector2(float(piece % 3), float(piece / 3)) * ts, ts)
				m.draw_texture_rect_region(tex, r, src)
				var ok: bool = piece == i
				m.draw_rect(r, Color(DS.C_GOOD, 0.8) if ok else Color(DS.C_LINE_HI, 0.8), false, 2.0)
				if int(st["sel"]) == i:
					m.draw_rect(r.grow(3.0), DS.C_ACCENT, false, 4.0)
			# referencia pequena y dato real
			var side: float = (tiles[8] as Rect2).end.x - (tiles[0] as Rect2).position.x
			var rx: float = p.position.x + 40.0 + side + 40.0
			var rw: float = minf(minf(p.end.x - rx - 30.0, 220.0), p.size.y - 360.0)
			rw = maxf(rw, 90.0)
			m.draw_string(fb, Vector2(rx, p.position.y + 150.0), Lang.t("Así debe quedar"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DS.C_DIM)
			m.draw_texture_rect(tex, Rect2(rx, p.position.y + 160.0, rw, rw), false, Color(1, 1, 1, 0.85))
			m._para(Vector2(rx, p.position.y + 172.0 + rw), Lang.t("Así se hacen los mapas reales: uniendo muchas fotos tomadas desde órbita. Un mosaico de la Luna llena de la NASA usa 1.231 fotos de la cámara del orbitador LRO; en Marte, la cámara HiRISE del orbitador MRO ve detalles de ≈ 1 m."), 13, DS.C_TEXT, p.end.x - rx - 30.0)
		"leak":
			m._para(p.position + Vector2(30, 62), Lang.t("Aparecen grietas en el casco y el aire se escapa. Toca cada grieta para sellarla antes de que baje demasiado la presión (o pulsa E / Espacio)."), 17, Color(0.82, 0.88, 1.0), p.size.x - 60.0)
			var area := Rect2(p.position + Vector2(40.0, 150.0), Vector2(p.size.x * 0.6, p.size.y - 230.0))
			m.draw_rect(area, Color(0.42, 0.45, 0.5))
			for gx in 4:
				m.draw_line(Vector2(area.position.x + area.size.x * float(gx) / 4.0, area.position.y), Vector2(area.position.x + area.size.x * float(gx) / 4.0, area.end.y), Color(0.3, 0.32, 0.36), 2.0)
			for k in 18:
				m.draw_circle(area.position + Vector2(10.0 + float(k % 6) * area.size.x / 6.0, 12.0 + float(k / 6) * area.size.y / 3.0), 3.0, Color(0.6, 0.62, 0.68))
			for sp in st["sealed"]:
				var c: Vector2 = _crack_pos(p, sp)
				m.draw_circle(c, 30.0, Color(0.85, 0.66, 0.24))
				m.draw_arc(c, 30.0, 0.0, TAU, 32, Color(0.55, 0.4, 0.12), 3.0)
			var cr: Vector2 = st["crack"]
			if cr.x >= 0.0:
				var c2: Vector2 = _crack_pos(p, cr)
				var gr: float = float(st["grow"])
				var pts := PackedVector2Array([c2 + Vector2(-26, -10) * gr, c2 + Vector2(-8, -2) * gr, c2 + Vector2(4, -14) * gr, c2 + Vector2(14, 4) * gr, c2 + Vector2(28, 12) * gr])
				m.draw_polyline(pts, Color(0.05, 0.05, 0.08), 5.0)
				var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
				m.draw_arc(c2, 40.0, 0.0, TAU, 32, Color(DS.C_WARN, 0.5 + 0.4 * pulse), 3.0)
				for k in 5:
					var a: float = float(k) / 5.0 * TAU + Time.get_ticks_msec() / 300.0
					m.draw_circle(c2 + Vector2(cos(a), sin(a)) * (18.0 + 12.0 * pulse), 2.5, Color(0.8, 0.9, 1.0, 0.7))
			# manometro
			var gc := Vector2(p.position.x + p.size.x * 0.82, p.position.y + 260.0)
			var pr: float = clampf(float(st["pressure"]) / 100.0, 0.0, 1.0)
			m.draw_arc(gc, 70.0, PI * 0.8, PI * 2.2, 48, Color(DS.C_SURF3), 12.0)
			var pc: Color = DS.C_GOOD if pr > 0.75 else (DS.C_WARN if pr > 0.6 else DS.C_BAD)
			m.draw_arc(gc, 70.0, PI * 0.8, PI * 0.8 + PI * 1.4 * pr, 48, pc, 12.0)
			m.draw_string(fb, gc + Vector2(-60, 10), "%d %%" % int(round(float(st["pressure"]))), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 26, DS.C_TEXT)
			m.draw_string(f, gc + Vector2(-80, 100), Lang.t("Presión de la base"), HORIZONTAL_ALIGNMENT_CENTER, 160.0, 14, DS.C_DIM)
			m.draw_string(f, gc + Vector2(-80, 124), Lang.t("Grietas selladas: %d / %d") % [(st["sealed"] as Array).size(), int(st["total"])], HORIZONTAL_ALIGNMENT_CENTER, 160.0, 14, DS.C_TEXT)
			if str(st["note"]) != "":
				m._para(Vector2(p.position.x + 40.0, p.end.y - 78.0), str(st["note"]), 14, DS.C_WARN, p.size.x * 0.6)


func _layer_card(m: Control, r: Rect2, layer: int, placed: bool, num: int = 0) -> void:
	var f: Font = _font()
	var fb: Font = DS.font("SemiBold")
	m.draw_rect(r, Color(DS.C_SURF3, 0.95) if not placed else Color(DS.C_GOOD, 0.18))
	m.draw_rect(r, DS.C_GOOD if placed else DS.C_LINE_HI, false, 2.0)
	# muestra de la malla: puntos mas pequenos y juntos cuanto mas fina
	var gap: float = [16.0, 11.0, 7.0, 4.5][layer]
	var dot: float = [3.0, 2.2, 1.4, 0.9][layer]
	var mx: float = r.position.x + 10.0
	var yy: float = r.position.y + 10.0
	while yy < r.end.y - 8.0:
		var xx: float = mx
		while xx < mx + 56.0:
			m.draw_circle(Vector2(xx, yy), dot, Color(0.75, 0.8, 0.9, 0.85))
			xx += gap
		yy += gap
	var name_txt: String = Lang.t(str(LAYERS[layer][0]))
	if num > 0:
		name_txt = "%d · %s" % [num, name_txt]
	var cy: float = r.size.y / 2.0
	m.draw_string(fb, r.position + Vector2(78, cy - 2.0), name_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 86.0, 16, DS.C_TEXT)
	m.draw_string(f, r.position + Vector2(78, cy + 16.0), Lang.t(str(LAYERS[layer][1])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 86.0, 13, DS.C_DIM)
