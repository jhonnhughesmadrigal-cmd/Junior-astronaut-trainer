extends Control
# Minijuegos del banco de trabajo: cables, circuito (formas), diagnostico (botiquin) y memoria de patron.
# Se abre con begin(); al terminar emite done(ok, errores). Todo se dibuja por codigo.

const Data = preload("res://minigame_data.gd")
signal done(ok: bool, mistakes: int)

const COLS: Array = [Color(0.95, 0.27, 0.27), Color(0.3, 0.62, 1.0), Color(0.3, 0.85, 0.42), Color(1.0, 0.85, 0.2), Color(0.8, 0.42, 0.95)]
const BG: Color = Color(0.05, 0.06, 0.12, 0.97)

var game = null
var kind: String = ""
var tool_id: String = ""
var head: String = ""
var mistakes: int = 0
var finished: bool = false
var fin_t: float = 0.0
var flash: float = 0.0
var mouse: Vector2 = Vector2.ZERO
var sb: StyleBoxFlat = null
var case_order: Array = []

# cables / formas
var n: int = 0
var ccol: Array = []
var cshape: Array = []
var rorder: Array = []
var link: Array = []
var sel: int = -1
var drag: bool = false

# patron
var pads: int = 4
var total: int = 5
var seq: Array = []
var round_n: int = 1
var phase: String = "wait"
var phase_t: float = 0.0
var in_i: int = 0
var lit: int = -1
var lit_t: float = 0.0
var last_shown: int = -1
var note: String = ""

# diagnostico
var cs: Dictionary = {}
var step: int = 0
var opts: Array = []
var bad: Array = []
var answered: bool = false
var fb: String = ""


func _ready() -> void:
	sb = StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.5, 0.7, 1.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func begin(id: String, name_txt: String) -> void:
	tool_id = id
	mistakes = 0
	finished = false
	fin_t = 0.0
	flash = 0.0
	sel = -1
	drag = false
	note = ""
	match id:
		"patch":
			kind = "wires"
			n = 4
			head = Lang.t("Kit de parche: conecta los cables")
			_setup_wires(false)
		"repair":
			kind = "wires"
			n = 5
			head = Lang.t("Reparador: conecta el circuito")
			_setup_wires(true)
		"upg_wires":
			kind = "wires"
			n = 4
			head = Lang.t("Mejora: conecta los cables")
			_setup_wires(false)
		"upg_shapes":
			kind = "wires"
			n = 5
			head = Lang.t("Mejora: conecta el circuito")
			_setup_wires(true)
		"medkit":
			kind = "diagnosis"
			head = Lang.t("Botiquín: diagnóstico")
			_setup_case()
		"filter":
			kind = "pattern"
			pads = 4
			total = 5
			head = Lang.t("Memoria del filtro: recuerda el patrón")
			_setup_pattern()
		_:
			kind = "pattern"
			pads = 5
			total = 6
			head = Lang.t("Calibra el mapa: recuerda el patrón de estrellas")
			_setup_pattern()
	visible = true
	queue_redraw()


func _panel() -> Rect2:
	var w: float = minf(size.x - 40.0, 960.0)
	var h: float = minf(size.y - 40.0, 600.0)
	return Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)


# ---------- cables ----------

func _setup_wires(shapes: bool) -> void:
	ccol.clear()
	cshape.clear()
	var ids: Array = [0, 1, 2, 3, 4]
	ids.shuffle()
	for i in n:
		if shapes:
			# 5 piezas: dos son del mismo color y solo se distinguen por la forma
			var combos: Array = [[0, 0], [0, 1], [1, 2], [2, 3], [3, 4]]
			ccol.append(combos[i][0])
			cshape.append(combos[i][1])
		else:
			ccol.append(ids[i])
			cshape.append(0)
	rorder = range(n)
	var tries: int = 0
	while tries < 20:
		rorder.shuffle()
		var same: bool = true
		for j in n:
			if rorder[j] != j:
				same = false
		if not same:
			break
		tries += 1
	link = []
	for i in n:
		link.append(-1)


func _slot(side: int, idx: int) -> Vector2:
	var p: Rect2 = _panel()
	var top: float = p.position.y + 170.0
	var bot: float = p.end.y - 90.0
	var gap: float = (bot - top) / float(maxi(n - 1, 1))
	var x: float = p.position.x + 140.0 if side == 0 else p.end.x - 140.0
	return Vector2(x, top + gap * float(idx))


func _hit_slot(side: int, pos: Vector2) -> int:
	for i in n:
		if pos.distance_to(_slot(side, i)) <= 34.0:
			return i
	return -1


func _try_connect(l: int, rj: int) -> void:
	if l < 0 or rj < 0 or link[l] != -1 or link.has(rj):
		sel = -1
		return
	if rorder[rj] == l:
		link[l] = rj
		game._sfx("interact", -6.0)
		var all: bool = true
		for i in n:
			if link[i] == -1:
				all = false
		if all:
			finished = true
			fin_t = 0.0
			game._sfx("good", -6.0)
	else:
		mistakes += 1
		flash = 0.45
		game._sfx("error", -6.0)
	sel = -1


# ---------- patron ----------

func _setup_pattern() -> void:
	seq.clear()
	for i in total:
		var v: int = randi() % pads
		seq.append(v)
	round_n = 1
	in_i = 0
	phase = "wait"
	phase_t = -0.6
	lit = -1
	last_shown = -1
	note = Lang.t("Mira bien la secuencia...")


func _pad_rect(i: int) -> Rect2:
	var p: Rect2 = _panel()
	var s: float = minf(130.0, (p.size.x - 120.0) / float(pads) - 16.0)
	var tw: float = float(pads) * s + float(pads - 1) * 16.0
	var x0: float = p.position.x + (p.size.x - tw) / 2.0
	return Rect2(x0 + float(i) * (s + 16.0), p.position.y + 210.0, s, s)


func _press_pad(i: int) -> void:
	if phase != "input" or finished:
		return
	lit = i
	lit_t = 0.25
	game._sfx(["blip", "interact", "pickup", "step", "next"][i % 5], -6.0)
	if seq[in_i] == i:
		in_i += 1
		if in_i >= round_n:
			if round_n >= total:
				finished = true
				fin_t = 0.0
				game._sfx("good", -6.0)
			else:
				note = Lang.t("¡Bien! Ronda %d de %d") % [round_n, total]
				round_n += 1
				phase = "wait"
				phase_t = -0.9
				in_i = 0
	else:
		mistakes += 1
		flash = 0.45
		game._sfx("error", -6.0)
		note = Lang.t("Ups, esa no era. Mira otra vez.")
		phase = "wait"
		phase_t = -1.0
		in_i = 0


# ---------- diagnostico ----------

func _setup_case() -> void:
	var all: Array = Data.cases()
	if case_order.is_empty():
		case_order = range(all.size())
		case_order.shuffle()
	var idx: int = case_order.pop_back()
	cs = all[idx]
	step = 0
	_setup_step()


func _setup_step() -> void:
	var key: String = "o1" if step == 0 else "o2"
	opts.clear()
	for k in cs[key].size():
		opts.append({"t": cs[key][k], "ok": k == 0})
	opts.shuffle()
	bad.clear()
	answered = false
	fb = ""


func _sym_h(w: float) -> float:
	return ThemeDB.fallback_font.get_multiline_string_size(str(cs["sym"]), HORIZONTAL_ALIGNMENT_LEFT, w, 19).y


func _opt_rects() -> Array:
	var p: Rect2 = _panel()
	var font: Font = ThemeDB.fallback_font
	var res: Array = []
	var w: float = p.size.x - 80.0
	var y: float = p.position.y + 94.0 + _sym_h(w) + 40.0
	for o in opts:
		var sz: Vector2 = font.get_multiline_string_size(str(o["t"]), HORIZONTAL_ALIGNMENT_LEFT, w - 70.0, 19)
		var h: float = maxf(sz.y + 18.0, 44.0)
		res.append(Rect2(p.position.x + 40.0, y, w, h))
		y += h + 8.0
	return res


func _pick(i: int) -> void:
	if answered or finished or i < 0 or i >= opts.size() or bad.has(i):
		return
	if opts[i]["ok"]:
		answered = true
		game._sfx("good", -6.0)
		fb = str(cs["w1"] if step == 0 else cs["w2"])
	else:
		bad.append(i)
		mistakes += 1
		flash = 0.3
		game._sfx("error", -6.0)
		fb = str(cs["h1"] if step == 0 else cs["h2"])


func _next_step() -> void:
	if not answered:
		return
	if step == 0:
		step = 1
		_setup_step()
	else:
		finished = true
		fin_t = 0.0
		game._sfx("craft", -6.0)


# ---------- entrada ----------

func handle_key(k: InputEventKey) -> void:
	if k.keycode == KEY_ESCAPE:
		visible = false
		done.emit(false, mistakes)
		return
	if finished:
		return
	if kind == "diagnosis":
		if k.keycode >= KEY_1 and k.keycode <= KEY_4:
			_pick(int(k.keycode - KEY_1))
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_E or k.keycode == KEY_SPACE:
			_next_step()
	elif kind == "pattern":
		if k.keycode >= KEY_1 and k.keycode <= KEY_5:
			var i: int = int(k.keycode - KEY_1)
			if i < pads:
				_press_pad(i)


func _gui_input(ev: InputEvent) -> void:
	var mm := ev as InputEventMouseMotion
	if mm != null:
		mouse = mm.position
		if drag:
			queue_redraw()
		return
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or finished:
		return
	mouse = mb.position
	if kind == "wires":
		if mb.pressed:
			var l: int = _hit_slot(0, mb.position)
			if l >= 0 and link[l] == -1:
				sel = l
				drag = true
				return
			var r: int = _hit_slot(1, mb.position)
			if r >= 0 and sel >= 0:
				_try_connect(sel, r)
				drag = false
		else:
			if drag:
				drag = false
				var r2: int = _hit_slot(1, mb.position)
				if r2 >= 0 and sel >= 0:
					_try_connect(sel, r2)
	elif kind == "pattern":
		if mb.pressed:
			for i in pads:
				if _pad_rect(i).has_point(mb.position):
					_press_pad(i)
	elif kind == "diagnosis":
		if mb.pressed:
			if answered:
				_next_step()
				return
			var rs: Array = _opt_rects()
			for i in rs.size():
				if (rs[i] as Rect2).has_point(mb.position):
					_pick(i)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if flash > 0.0:
		flash -= delta
	if finished:
		fin_t += delta
		if fin_t >= 1.1:
			visible = false
			done.emit(true, mistakes)
		queue_redraw()
		return
	if kind == "pattern":
		if lit_t > 0.0:
			lit_t -= delta
			if lit_t <= 0.0 and phase != "show":
				lit = -1
		phase_t += delta
		if phase == "wait" and phase_t >= 0.0:
			phase = "show"
			phase_t = 0.0
			last_shown = -1
		elif phase == "show":
			var i: int = int(phase_t / 0.75)
			if i >= round_n:
				phase = "input"
				lit = -1
				in_i = 0
				note = Lang.t("Repite la secuencia (%d de %d)") % [round_n, total]
			else:
				var within: float = phase_t - float(i) * 0.75
				if within < 0.5:
					lit = seq[i]
					if last_shown != i:
						last_shown = i
						game._sfx(["blip", "interact", "pickup", "step", "next"][int(seq[i]) % 5], -9.0)
				else:
					lit = -1
	queue_redraw()


# ---------- dibujo ----------

func _txt(pos: Vector2, s: String, fs: int, col: Color, w: float = -1.0) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, w, fs, col)


func _para(pos: Vector2, s: String, fs: int, col: Color, w: float) -> float:
	var font: Font = ThemeDB.fallback_font
	draw_multiline_string(font, pos + Vector2(0, float(fs)), s, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, col)
	return font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y


func _shape(c: Vector2, s: int, r: float, col: Color) -> void:
	var dark: Color = col.darkened(0.55)
	match s:
		1:
			draw_rect(Rect2(c - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), dark)
			draw_rect(Rect2(c - Vector2(r, r) * 0.75, Vector2(r, r) * 1.5), col)
		2:
			var a := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 1.05, r * 0.85), c + Vector2(-r * 1.05, r * 0.85)])
			draw_colored_polygon(a, dark)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.65), c + Vector2(r * 0.75, r * 0.6), c + Vector2(-r * 0.75, r * 0.6)]), col)
		3:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r * 1.0, 0), c + Vector2(0, r * 1.1), c + Vector2(-r * 1.0, 0)]), dark)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.8), c + Vector2(r * 0.72, 0), c + Vector2(0, r * 0.8), c + Vector2(-r * 0.72, 0)]), col)
		4:
			var st := PackedVector2Array()
			var st2 := PackedVector2Array()
			for k in 10:
				var an: float = -PI / 2.0 + TAU * float(k) / 10.0
				var rr: float = r * (1.15 if k % 2 == 0 else 0.5)
				st.append(c + Vector2(cos(an), sin(an)) * rr)
				st2.append(c + Vector2(cos(an), sin(an)) * rr * 0.7)
			draw_colored_polygon(st, dark)
			draw_colored_polygon(st2, col)
		_:
			draw_circle(c, r, dark)
			draw_circle(c, r * 0.78, col)


func _wire_curve(a: Vector2, b: Vector2, col: Color, wdt: float) -> void:
	var pts := PackedVector2Array()
	for k in 25:
		var t: float = float(k) / 24.0
		var mid: float = (a.x + b.x) / 2.0
		var p0: Vector2 = a
		var p1: Vector2 = Vector2(mid, a.y)
		var p2: Vector2 = Vector2(mid, b.y)
		var p3: Vector2 = b
		var q: Vector2 = p0 * pow(1.0 - t, 3.0) + p1 * 3.0 * pow(1.0 - t, 2.0) * t + p2 * 3.0 * (1.0 - t) * t * t + p3 * pow(t, 3.0)
		pts.append(q)
	draw_polyline(pts, col.darkened(0.5), wdt + 4.0, true)
	draw_polyline(pts, col, wdt, true)


func _draw() -> void:
	if not visible or sb == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	var p: Rect2 = _panel()
	draw_style_box(sb, p)
	_txt(p.position + Vector2(30, 44), head, 26, Color(1.0, 0.9, 0.5), p.size.x - 260.0)
	var ec: Color = Color(1.0, 0.45, 0.4) if flash > 0.0 else Color(0.7, 0.8, 1.0)
	_txt(Vector2(p.end.x - 200.0, p.position.y + 42.0), Lang.t("Errores: %d") % mistakes, 20, ec, 180.0)
	_txt(p.position + Vector2(30, p.size.y - 22.0), Lang.t("[Esc] Volver al banco"), 15, Color(0.6, 0.7, 0.9))
	if flash > 0.0:
		draw_rect(p, Color(1, 0.1, 0.1, 0.12 * (flash / 0.45)))
	match kind:
		"wires":
			_draw_wires(p)
		"pattern":
			_draw_pattern(p)
		"diagnosis":
			_draw_diag(p)
	if finished:
		var msg: String = Lang.t("¡Listo!") if kind != "wires" else Lang.t("¡Conectado!")
		draw_rect(Rect2(p.position + Vector2(0, p.size.y / 2.0 - 50.0), Vector2(p.size.x, 100.0)), Color(0.02, 0.1, 0.05, 0.9))
		draw_string(ThemeDB.fallback_font, p.position + Vector2(0, p.size.y / 2.0 + 14.0), msg, HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 52, Color(0.5, 1.0, 0.6))


func _draw_wires(p: Rect2) -> void:
	var instr: String = Lang.t("Conecta cada cable con su pareja del mismo color. Haz clic en un extremo y luego en el otro (o arrastra).")
	if tool_id == "repair" or tool_id == "upg_shapes":
		instr = Lang.t("Reconecta el circuito: une cada pieza con su pareja del mismo color Y la misma forma.")
	_para(p.position + Vector2(30, 62), instr, 18, Color(0.82, 0.88, 1.0), p.size.x - 60.0)
	for i in n:
		if link[i] >= 0:
			_wire_curve(_slot(0, i), _slot(1, link[i]), COLS[ccol[i]], 9.0)
	if drag and sel >= 0:
		_wire_curve(_slot(0, sel), mouse, COLS[ccol[sel]], 7.0)
	for i in n:
		var l: Vector2 = _slot(0, i)
		_shape(l, cshape[i], 24.0, COLS[ccol[i]])
		if sel == i:
			draw_arc(l, 32.0, 0.0, TAU, 28, Color.WHITE, 3.0)
		var it: int = rorder[i]
		var r: Vector2 = _slot(1, i)
		_shape(r, cshape[it], 24.0, COLS[ccol[it]])
		if link.has(i):
			draw_arc(r, 32.0, 0.0, TAU, 28, Color(0.5, 1.0, 0.6), 3.0)


func _draw_pattern(p: Rect2) -> void:
	_para(p.position + Vector2(30, 62), Lang.t("Haz clic en las luces o usa las teclas 1-%d.") % pads, 18, Color(0.82, 0.88, 1.0), p.size.x - 60.0)
	_txt(p.position + Vector2(30, 150), note, 24, Color(1.0, 0.95, 0.7), p.size.x - 60.0)
	for i in pads:
		var r: Rect2 = _pad_rect(i)
		var col: Color = COLS[i % 5]
		var on: bool = lit == i
		draw_rect(r, col.darkened(0.45) if not on else col.lightened(0.35))
		draw_rect(r.grow(-8.0), col.darkened(0.2) if not on else Color(1, 1, 1, 0.9))
		draw_rect(r, Color(1, 1, 1, 0.8 if on else 0.2), false, 3.0)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(0, r.size.y / 2.0 + 10.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color(0, 0, 0, 0.6))
	# progreso
	var bx: float = p.position.x + 30.0
	for k in total:
		var c: Color = Color(0.4, 1.0, 0.5) if k < round_n - 1 or (finished) else Color(0.3, 0.35, 0.5)
		draw_circle(Vector2(bx + float(k) * 26.0, p.end.y - 70.0), 9.0, c)


func _draw_diag(p: Rect2) -> void:
	var x: float = p.position.x + 40.0
	var w: float = p.size.x - 80.0
	var step_txt: String = Lang.t("Paso 1 de 2 - Diagnóstico") if step == 0 else Lang.t("Paso 2 de 2 - Qué lleva el botiquín")
	_txt(Vector2(x, p.position.y + 74.0), "%s - %s" % [str(cs["title"]), step_txt] if step == 1 else step_txt, 17, Color(0.6, 0.85, 1.0), w)
	var h1: float = _para(Vector2(x, p.position.y + 82.0), str(cs["sym"]), 19, Color(0.95, 0.95, 1.0), w)
	var qy: float = p.position.y + 94.0 + h1
	_txt(Vector2(x, qy + 24.0), str(cs["q1"] if step == 0 else cs["q2"]), 22, Color(1.0, 0.9, 0.5), w)
	var rs: Array = _opt_rects()
	for i in rs.size():
		var r: Rect2 = rs[i]
		var col: Color = Color(0.13, 0.17, 0.3)
		var bc: Color = Color(0.4, 0.55, 0.9)
		if bad.has(i):
			col = Color(0.3, 0.1, 0.12)
			bc = Color(0.9, 0.3, 0.3)
		elif answered and opts[i]["ok"]:
			col = Color(0.08, 0.3, 0.14)
			bc = Color(0.4, 1.0, 0.5)
		elif not answered and r.has_point(mouse):
			col = Color(0.2, 0.26, 0.45)
		draw_rect(r, col)
		draw_rect(r, bc, false, 2.0)
		_txt(r.position + Vector2(12, 28.0), str(i + 1), 22, bc)
		_para(r.position + Vector2(50, 9.0), str(opts[i]["t"]), 19, Color(0.95, 0.95, 1.0), r.size.x - 70.0)
	var last: Rect2 = rs[rs.size() - 1]
	var fy: float = last.end.y + 12.0
	if fb != "":
		var fc: Color = Color(0.7, 1.0, 0.75) if answered else Color(1.0, 0.75, 0.55)
		_para(Vector2(x, fy), fb, 18, fc, w)
	if answered:
		_txt(Vector2(x, p.end.y - 48.0), Lang.t("Pulsa [Enter] o haz clic para continuar"), 17, Color(1.0, 0.95, 0.6))
