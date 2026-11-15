extends "res://inv_icons.gd"
# Interfaz del banco de trabajo: tarjetas para fabricar y mejorar, con el detalle y el costo a la derecha.
# Teclado: flechas o [1-8] eligen, [Enter] fabrica, [Esc] o [E] salen. Ratón: clic elige, clic en el boton fabrica.

signal closed

const CARD: float = 84.0
const GAP: float = 10.0
const UPG_IDS: Array = ["suit_o2", "suit_st", "pack"]
var sel: int = 0
var mouse: Vector2 = Vector2.ZERO


func _init() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2.ZERO
	visible = false


func open() -> void:
	sel = clampi(sel, 0, 7)
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	closed.emit()


func _panel() -> Rect2:
	var w: float = minf(940.0, size.x - 20.0)
	var h: float = minf(540.0, size.y - 20.0)
	return Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)


func _left_w(p: Rect2) -> float:
	return 5.0 * (CARD + GAP) + 20.0


func _card_rect(i: int) -> Rect2:
	var p: Rect2 = _panel()
	var x0: float = p.position.x + 30.0
	if i < 5:
		return Rect2(x0 + float(i) * (CARD + GAP), p.position.y + 130.0, CARD, CARD)
	return Rect2(x0 + float(i - 5) * (CARD + GAP), p.position.y + 300.0, CARD, CARD)


func _button_rect() -> Rect2:
	var p: Rect2 = _panel()
	var rx: float = p.position.x + 30.0 + _left_w(p) + 20.0
	return Rect2(rx, p.end.y - 86.0, p.end.x - rx - 30.0, 54.0)


# Datos de la casilla i (0-4 recetas, 5-7 mejoras del equipo)
func _entry(i: int) -> Dictionary:
	var e: Dictionary = {"id": "", "name": "", "desc": "", "cost": {}, "mins": 0, "ok": false, "why": "", "owned": -1, "lvl": -1}
	if i < 5:
		var r: Dictionary = game.RECIPES[i]
		e["id"] = str(r["id"])
		e["name"] = str(r["name"])
		e["desc"] = str(r["desc"])
		e["cost"] = r["cost"]
		e["mins"] = int(r["mins"])
		e["owned"] = int(game.tools[r["id"]])
		e["ok"] = game._can_craft(r)
		if not e["ok"]:
			e["why"] = Lang.t("Faltan materiales")
		if r["id"] == "map" and int(game.tools["map"]) > 0:
			e["ok"] = false
			e["why"] = Lang.t("Ya tienes un mapa de navegación")
	else:
		var j: int = i - 5
		var id: String = UPG_IDS[j]
		var names: Array = [Lang.t("Tanque del traje"), Lang.t("Aguante del traje"), Lang.t("Mochila")]
		var descs: Array = [Lang.t("+%d min de aire por nivel") % int(game.SUIT_O2_PER_LVL), Lang.t("Corres más tiempo sin cansarte"), Lang.t("+4 casillas por nivel")]
		var lv: int = game._upg_level(id)
		e["id"] = id
		e["name"] = names[j]
		e["desc"] = descs[j]
		e["lvl"] = lv
		if lv >= game.MAX_UPG:
			e["why"] = Lang.t("Nivel máximo")
		else:
			e["cost"] = game._upg_cost(id, lv + 1)
			e["ok"] = game._can_pay(e["cost"])
			if not e["ok"]:
				e["why"] = Lang.t("Faltan materiales")
	return e


func _try(i: int) -> void:
	sel = i
	if i < 5:
		game._craft(i)
	else:
		game._upgrade_suit(i - 5)
	if game.mode != 4:
		visible = false
	queue_redraw()


func handle_key(k: InputEventKey) -> void:
	var kc: int = k.keycode
	if kc == KEY_ESCAPE or kc == KEY_E:
		close()
	elif kc >= KEY_1 and kc <= KEY_8:
		_try(kc - KEY_1)
	elif kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_SPACE:
		_try(sel)
	elif kc == KEY_RIGHT or kc == KEY_D:
		sel = (sel + 1) % 8
		queue_redraw()
	elif kc == KEY_LEFT or kc == KEY_A:
		sel = (sel + 7) % 8
		queue_redraw()
	elif kc == KEY_DOWN or kc == KEY_S:
		if sel < 5:
			sel = 5 + mini(sel, 2)
		queue_redraw()
	elif kc == KEY_UP or kc == KEY_W:
		if sel >= 5:
			sel -= 5
		queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var mm := ev as InputEventMouseMotion
	if mm != null:
		mouse = mm.position
		queue_redraw()
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		for i in 8:
			if _card_rect(i).has_point(mb.position):
				if sel == i and mb.double_click:
					_try(i)
				sel = i
				queue_redraw()
				return
		if _button_rect().has_point(mb.position):
			_try(sel)
			return
		if not _panel().has_point(mb.position):
			close()


func _mat_icon(id: String, r: Rect2) -> void:
	var tx: Texture2D = _tex(id)
	if tx != null:
		draw_texture_rect(tx, r, false)
	else:
		_icon(id, r, 1.0)


func _draw_upg_glyph(id: String, r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	match id:
		"suit_o2":
			draw_circle(c, 14.0, Color(0.55, 0.8, 1.0))
			draw_circle(c, 9.0, Color(0.12, 0.2, 0.35))
			draw_rect(Rect2(c + Vector2(-4, -20), Vector2(8, 7)), Color(0.85, 0.2, 0.2))
		"suit_st":
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -17), c + Vector2(-10, 3), c + Vector2(-1, 3), c + Vector2(-5, 17), c + Vector2(11, -4), c + Vector2(2, -4)]), Color(1.0, 0.85, 0.3))
		_:
			draw_rect(Rect2(c + Vector2(-14, -12), Vector2(28, 26)), Color(0.45, 0.6, 0.85))
			draw_rect(Rect2(c + Vector2(-9, -5), Vector2(18, 10)), Color(0.2, 0.3, 0.5))
			draw_arc(c + Vector2(0, -12), 7.0, PI, TAU, 10, Color(0.8, 0.88, 1.0), 3.0)


func _draw() -> void:
	if not visible or game == null:
		return
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65))
	var p: Rect2 = _panel()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.97)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.8, 0.35)
	draw_style_box(sb, p)
	draw_string(font, p.position + Vector2(30, 44), Lang.t("Banco de trabajo"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.9, 0.5))
	# materiales que tienes
	var mx: float = p.position.x + 30.0
	var my: float = p.position.y + 62.0
	for id in MATS:
		_mat_icon(id, Rect2(mx, my, 26.0, 26.0))
		draw_string(font, Vector2(mx + 32.0, my + 20.0), "%s: %d" % [str(LABELS[id]), int(game.inv[id])], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.9, 0.93, 1.0))
		mx += 150.0
	draw_string(font, p.position + Vector2(30, 116), Lang.t("Fabricar (minijuego)"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.6, 0.85, 1.0))
	draw_string(font, p.position + Vector2(30, 286), Lang.t("Mejorar el equipo (solo materiales)"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.6, 0.85, 1.0))
	for i in 8:
		var r: Rect2 = _card_rect(i)
		var e: Dictionary = _entry(i)
		var dim: float = 1.0 if bool(e["ok"]) else 0.45
		draw_rect(r, Color(0.11, 0.14, 0.24))
		draw_rect(r, Color(0.3, 0.4, 0.65), false, 2.0)
		var ic := Rect2(r.position + Vector2(CARD / 2.0 - 16.0, 12.0), Vector2(32.0, 32.0))
		if i < 5:
			var tx: Texture2D = _tex(str(e["id"]))
			if tx != null:
				draw_texture_rect(tx, ic, false, Color(1, 1, 1, dim))
			else:
				_icon(str(e["id"]), ic, dim)
			if int(e["owned"]) > 0:
				draw_string(font, r.position + Vector2(CARD - 24.0, 18.0), "x%d" % int(e["owned"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.9, 0.5))
		else:
			_draw_upg_glyph(str(e["id"]), ic)
			for q in game.MAX_UPG:
				var col: Color = Color(1.0, 0.85, 0.3) if q < int(e["lvl"]) else Color(0.25, 0.3, 0.45)
				draw_rect(Rect2(r.position + Vector2(CARD / 2.0 - 21.0 + float(q) * 15.0, CARD - 12.0), Vector2(12, 5)), col)
		draw_multiline_string(font, r.position + Vector2(2, 56.0), str(e["name"]), HORIZONTAL_ALIGNMENT_CENTER, CARD - 4.0, 12, 2, Color(0.9, 0.93, 1.0, dim + 0.2))
		draw_string(font, r.position + Vector2(4, 14.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.9))
		if i == sel:
			draw_rect(r.grow(3.0), Color(1.0, 0.85, 0.3), false, 3.0)
		elif r.has_point(mouse):
			draw_rect(r.grow(2.0), Color(0.6, 0.8, 1.0), false, 2.0)
	# detalle a la derecha
	var e2: Dictionary = _entry(sel)
	var rx: float = p.position.x + 30.0 + _left_w(p) + 20.0
	var rw: float = p.end.x - rx - 30.0
	draw_line(Vector2(rx - 12.0, p.position.y + 20.0), Vector2(rx - 12.0, p.end.y - 20.0), Color(0.3, 0.4, 0.65), 1.0)
	var y: float = p.position.y + 44.0
	draw_string(font, Vector2(rx, y), str(e2["name"]), HORIZONTAL_ALIGNMENT_LEFT, rw, 22, Color(1.0, 0.9, 0.5))
	y += 26.0
	var d_txt: String = str(e2["desc"])
	if sel >= 5 and int(e2["lvl"]) >= 0:
		d_txt += "  (" + Lang.t("nivel %d de %d") % [int(e2["lvl"]), game.MAX_UPG] + ")"
	draw_multiline_string(font, Vector2(rx, y), d_txt, HORIZONTAL_ALIGNMENT_LEFT, rw, 15, 3, Color(0.8, 0.88, 1.0))
	y += 70.0
	draw_string(font, Vector2(rx, y), Lang.t("Materiales necesarios"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.85, 1.0))
	y += 12.0
	var cost: Dictionary = e2["cost"]
	if cost.is_empty():
		draw_string(font, Vector2(rx, y + 24.0), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.75, 0.9))
	for id in MATS:
		if not cost.has(id):
			continue
		var need: int = int(cost[id])
		var have: int = int(game.inv[id])
		var good: bool = have >= need
		_mat_icon(id, Rect2(rx, y + 4.0, 26.0, 26.0))
		draw_string(font, Vector2(rx + 34.0, y + 24.0), "%s" % str(LABELS[id]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.93, 1.0))
		draw_string(font, Vector2(rx + rw - 120.0, y + 24.0), Lang.t("%d de %d") % [have, need], HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 16, Color(0.5, 1.0, 0.6) if good else Color(1.0, 0.5, 0.4))
		y += 34.0
	if sel < 5:
		draw_string(font, Vector2(rx, y + 30.0), Lang.t("Tiempo de trabajo: %s") % game._fmt_dur(int(e2["mins"])), HORIZONTAL_ALIGNMENT_LEFT, rw, 15, Color(0.8, 0.88, 1.0))
	# boton
	var b: Rect2 = _button_rect()
	var ok: bool = bool(e2["ok"])
	var hov: bool = b.has_point(mouse)
	var bc: Color = Color(0.2, 0.55, 0.3) if ok else Color(0.25, 0.27, 0.34)
	if ok and hov:
		bc = Color(0.28, 0.7, 0.4)
	draw_rect(b, bc)
	draw_rect(b, Color(0.5, 0.9, 0.6) if ok else Color(0.4, 0.42, 0.5), false, 2.0)
	var label: String = ""
	if ok:
		label = (Lang.t("Fabricar") if sel < 5 else Lang.t("Mejorar")) + "  [Enter]"
	else:
		label = str(e2["why"])
	draw_string(font, b.position + Vector2(0, 34.0), label, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 20, Color(1, 1, 1) if ok else Color(0.8, 0.82, 0.9))
	draw_string(font, Vector2(rx, p.end.y - 14.0), Lang.t("Flechas o [1-8] eligen · [Esc] sale"), HORIZONTAL_ALIGNMENT_LEFT, rw, 13, Color(0.6, 0.7, 0.9))
