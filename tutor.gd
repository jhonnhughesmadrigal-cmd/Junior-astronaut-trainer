extends Control
# Tutorial guiado (se completa jugando, se puede saltar) y logros con insignias visibles.
# Todo se dibuja por codigo (sin imagenes).
const DS = preload("res://design_system.gd")

var game: Control = null
var idx: int = -1            # paso actual del tutorial; -1 = inactivo
var base: Dictionary = {}
var banner: PanelContainer
var banner_lbl: Label
var skip_btn: Button
var end_t: float = 0.0       # tiempo restante del mensaje final
var check_t: float = 0.0
var toast_t: float = 0.0
var toast_id: String = ""
var panel_open: bool = false
var station_flag: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 56
	banner = PanelContainer.new()
	var sb: StyleBoxFlat = DS.box(Color(0.035, 0.055, 0.10, 0.93), Color(DS.C_ACCENT, 0.7), 1, DS.R_LG, 14, 10)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	banner.add_theme_stylebox_override("panel", sb)
	banner.position = Vector2(300, 44)
	banner.visible = false
	add_child(banner)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	banner.add_child(hb)
	banner_lbl = Label.new()
	banner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_lbl.custom_minimum_size = Vector2(430, 0)
	banner_lbl.add_theme_font_size_override("font_size", 17)
	banner_lbl.add_theme_color_override("font_color", DS.C_TEXT)
	hb.add_child(banner_lbl)
	skip_btn = Button.new()
	skip_btn.text = Lang.t("Saltar tutorial [N]")
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.pressed.connect(skip)
	hb.add_child(skip_btn)


# ---------- tutorial ----------

func steps() -> Array:
	return [
		Lang.t("Misión: sobrevivir %d días. Primero muévete con W A S D o las flechas.") % game.MAX_DAYS,
		Lang.t("Cambia la cámara con la tecla C."),
		Lang.t("Acércate a un compañero (YARISBEL, ENOC o PAM) y pulsa E para hablar."),
		Lang.t("Las estaciones de colores mantienen la base viva. Acércate a una y pulsa E."),
		Lang.t("Abre tu mochila con la tecla I."),
		Lang.t("Abre tu diario de exploración con la tecla J."),
		Lang.t("Para recoger materiales, sal por la esclusa (puerta D). Vigila tu aire."),
	]


func start() -> void:
	idx = 0
	end_t = 0.0
	_snap()
	_show()


func _snap() -> void:
	base = {"dist": float(game.stats.get("distance", 0.0)), "cam": int(game.cam_mode), "talks": int(game.stats.get("talks", 0))}
	station_flag = false


func skip() -> void:
	if idx < 0:
		return
	idx = -1
	end_t = 0.0
	banner.visible = false
	game._sfx("next", -8.0)
	game._log(Lang.t("Tutorial saltado. Puedes repetirlo desde la pausa."))


func skip_silent() -> void:
	idx = -1
	banner.visible = false


func event(name: String) -> void:
	if name == "station":
		station_flag = true


func _show() -> void:
	var s: Array = steps()
	banner_lbl.text = "%d/%d  %s" % [idx + 1, s.size(), s[idx]]
	banner_lbl.add_theme_font_size_override("font_size", 22 if game.easy_read else 17)
	skip_btn.text = Lang.t("Saltar tutorial [N]")
	banner.visible = true


func _step_done() -> bool:
	match idx:
		0:
			return float(game.stats.get("distance", 0.0)) - float(base["dist"]) >= 3.0
		1:
			return int(game.cam_mode) != int(base["cam"])
		2:
			return int(game.stats.get("talks", 0)) > int(base["talks"])
		3:
			return station_flag
		4:
			return game.mode == 10
		5:
			return game.mode == 11
		6:
			return bool(game.outside)
	return false


func _finish() -> void:
	idx = -1
	banner_lbl.text = Lang.t("¡Tutorial completo! Duerme en la cama desde las 18:00. Pulsa F1 para ver los controles.")
	banner.visible = true
	end_t = 7.0
	game._sfx("good", -6.0)
	unlock("tutorial")


# ---------- logros ----------

func ach_list() -> Array:
	return [
		{"id": "tutorial", "n": Lang.t("Primeros pasos"), "d": Lang.t("Completa el tutorial."), "s": "flag", "c": Color(0.4, 0.8, 1.0)},
		{"id": "explorer", "n": Lang.t("Explorador"), "d": Lang.t("Visita 3 lugares del mundo."), "s": "planet", "c": Color(0.5, 0.9, 0.6)},
		{"id": "scholar", "n": Lang.t("Estudioso"), "d": Lang.t("Lee 3 placas informativas."), "s": "book", "c": Color(1.0, 0.85, 0.3)},
		{"id": "cartographer", "n": Lang.t("Cartógrafo"), "d": Lang.t("Estudia todos los lugares."), "s": "star", "c": Color(1.0, 0.7, 0.2)},
		{"id": "maker", "n": Lang.t("Manitas"), "d": Lang.t("Fabrica tu primera herramienta."), "s": "gear", "c": Color(0.8, 0.8, 0.95)},
		{"id": "builder", "n": Lang.t("Ingeniero"), "d": Lang.t("Termina una mejora."), "s": "bolt", "c": Color(1.0, 0.9, 0.3)},
		{"id": "master", "n": Lang.t("Obra maestra"), "d": Lang.t("Lleva una estación al nivel 3."), "s": "star", "c": Color(0.9, 0.5, 1.0)},
		{"id": "gatherer", "n": Lang.t("Recolector"), "d": Lang.t("Recoge 25 materiales."), "s": "drop", "c": Color(0.5, 0.85, 1.0)},
		{"id": "walker", "n": Lang.t("Caminante"), "d": Lang.t("Recorre 300 casillas."), "s": "flag", "c": Color(0.9, 0.6, 0.4)},
		{"id": "friend", "n": Lang.t("Buen compañero"), "d": Lang.t("Habla 10 veces con la tripulación."), "s": "heart", "c": Color(1.0, 0.5, 0.6)},
		{"id": "chronicler", "n": Lang.t("Cronista"), "d": Lang.t("Abre tu diario de exploración."), "s": "book", "c": Color(0.85, 0.7, 0.5)},
		{"id": "survivor10", "n": Lang.t("Superviviente"), "d": Lang.t("Llega al día 10."), "s": "heart", "c": Color(0.6, 1.0, 0.7)},
		{"id": "survivor20", "n": Lang.t("Veterano"), "d": Lang.t("Llega al día 20."), "s": "star", "c": Color(1.0, 0.8, 0.4)},
	]


func unlock(id: String) -> void:
	if game.ach_done.has(id):
		return
	game.ach_done[id] = true
	game._save_settings()
	toast_id = id
	toast_t = 5.0
	game._sfx("good", -4.0)


func _check_achievements() -> void:
	var st: Dictionary = game.stats
	var nz: int = game._zones().size() - 1
	if game.zones_seen.size() >= 3:
		unlock("explorer")
	if game.studied.size() >= 3:
		unlock("scholar")
	if nz > 0 and game.studied.size() >= nz:
		unlock("cartographer")
	if int(st.get("tools_built", 0)) >= 1:
		unlock("maker")
	if int(st.get("upgrades", 0)) >= 1:
		unlock("builder")
	for k in game.st_lvl.keys():
		if int(game.st_lvl[k]) >= 3:
			unlock("master")
	if int(st.get("collected", 0)) >= 25:
		unlock("gatherer")
	if float(st.get("distance", 0.0)) >= 300.0:
		unlock("walker")
	if int(st.get("talks", 0)) >= 10:
		unlock("friend")
	if game.mode == 11:
		unlock("chronicler")
	if int(game.day) >= 10:
		unlock("survivor10")
	if int(game.day) >= 20:
		unlock("survivor20")


func open_panel() -> void:
	if game.mode != 0 or game.airborne or game.fall_t >= 0.0:
		return
	panel_open = true
	game.mode = 12
	game._sfx("next", -6.0)
	queue_redraw()


func close_panel() -> void:
	panel_open = false
	if game.mode == 12:
		game.mode = 0
	queue_redraw()


func handle_key(k: InputEventKey) -> void:
	if k.keycode == KEY_K or k.keycode == KEY_ESCAPE:
		close_panel()


func tick(delta: float) -> void:
	if not game.playing:
		banner.visible = false
		return
	check_t -= delta
	if check_t <= 0.0:
		check_t = 0.5
		_check_achievements()
	if toast_t > 0.0:
		toast_t -= delta
		queue_redraw()
	if end_t > 0.0:
		end_t -= delta
		if end_t <= 0.0:
			banner.visible = false
	if idx >= 0:
		var hide: bool = game.mode in [3, 7, 8, 12]
		banner.visible = not hide
		var vw: float = get_viewport_rect().size.x
		banner.size = Vector2.ZERO
		banner.position = Vector2(clampf((vw - banner.size.x) / 2.0, 300.0, maxf(300.0, vw - banner.size.x - 8.0)), 44.0)
		if _step_done():
			game._sfx("next", -6.0)
			idx += 1
			if idx >= steps().size():
				_finish()
			else:
				_snap()
				_show()


func handle_skip_key(k: InputEventKey) -> bool:
	if idx >= 0 and k.keycode == KEY_N and not k.echo:
		skip()
		return true
	return false


# ---------- dibujo de insignias ----------

func _medal(c: Vector2, r: float, col: Color, shape: String, on: bool) -> void:
	var main_c: Color = col if on else Color(0.3, 0.32, 0.38)
	draw_circle(c, r, main_c.darkened(0.45))
	draw_circle(c, r * 0.88, main_c)
	draw_arc(c, r * 0.88, 0.0, TAU, 32, main_c.lightened(0.5) if on else Color(0.45, 0.47, 0.52), 2.0)
	var ink: Color = Color(0.1, 0.1, 0.18) if on else Color(0.18, 0.19, 0.24)
	var u: float = r * 0.5
	match shape:
		"star":
			var pts: PackedVector2Array = PackedVector2Array()
			for i in 10:
				var a: float = -PI / 2.0 + float(i) * PI / 5.0
				var rr: float = u if i % 2 == 0 else u * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, ink)
		"planet":
			draw_circle(c, u * 0.7, ink)
			draw_arc(c, u * 1.05, -0.5, 2.6, 16, ink, 3.0)
		"book":
			draw_rect(Rect2(c + Vector2(-u, -u * 0.7), Vector2(u * 0.95, u * 1.4)), ink)
			draw_rect(Rect2(c + Vector2(u * 0.05, -u * 0.7), Vector2(u * 0.95, u * 1.4)), ink.lightened(0.15))
		"gear":
			draw_circle(c, u * 0.75, ink)
			for i in 8:
				var a2: float = float(i) * TAU / 8.0
				draw_circle(c + Vector2(cos(a2), sin(a2)) * u * 0.95, u * 0.2, ink)
			draw_circle(c, u * 0.3, main_c)
		"bolt":
			draw_colored_polygon(PackedVector2Array([c + Vector2(u * 0.2, -u), c + Vector2(-u * 0.6, u * 0.15), c + Vector2(-u * 0.05, u * 0.15), c + Vector2(-u * 0.3, u), c + Vector2(u * 0.65, -u * 0.25), c + Vector2(u * 0.05, -u * 0.25)]), ink)
		"drop":
			draw_circle(c + Vector2(0, u * 0.25), u * 0.7, ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u), c + Vector2(-u * 0.62, u * 0.05), c + Vector2(u * 0.62, u * 0.05)]), ink)
		"heart":
			draw_circle(c + Vector2(-u * 0.4, -u * 0.15), u * 0.5, ink)
			draw_circle(c + Vector2(u * 0.4, -u * 0.15), u * 0.5, ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.88, 0.0), c + Vector2(u * 0.88, 0.0), c + Vector2(0, u * 0.95)]), ink)
		_:
			draw_line(c + Vector2(-u * 0.6, u), c + Vector2(-u * 0.6, -u), ink, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.6, -u), c + Vector2(u * 0.9, -u * 0.5), c + Vector2(-u * 0.6, 0.0)]), ink)


func _draw() -> void:
	if game == null:
		return
	var font: Font = DS.font("Regular")
	var fsb: Font = DS.font("SemiBold")
	var vs: Vector2 = get_viewport_rect().size
	if toast_t > 0.0 and toast_id != "":
		for a in ach_list():
			if a["id"] == toast_id:
				var slide: float = clampf(minf(toast_t, 5.0 - toast_t) * 4.0, 0.0, 1.0)
				var w: float = 330.0
				var p: Vector2 = Vector2(vs.x - w - 14.0 + (1.0 - slide) * (w + 20.0), 70.0)
				draw_style_box(DS.card(2, DS.R_LG, 0.97), Rect2(p, Vector2(w, 72)))
				_medal(p + Vector2(38, 36), 24.0, a["c"], a["s"], true)
				draw_string(fsb, p + Vector2(76, 26), Lang.t("LOGRO DESBLOQUEADO").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DS.C_ACCENT)
				draw_string(fsb, p + Vector2(76, 48), a["n"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DS.C_TEXT)
				draw_string(font, p + Vector2(76, 65), a["d"], HORIZONTAL_ALIGNMENT_LEFT, w - 84.0, 12, DS.C_DIM)
	if not panel_open:
		return
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.02, 0.05, 0.78))
	var list: Array = ach_list()
	var pw: float = 800.0
	var ph: float = 560.0
	var o: Vector2 = (vs - Vector2(pw, ph)) / 2.0
	draw_style_box(DS.card(2, DS.R_LG, 0.98), Rect2(o, Vector2(pw, ph)))
	var done_n: int = 0
	for a in list:
		if game.ach_done.has(a["id"]):
			done_n += 1
	draw_string(fsb, o + Vector2(28, 44), Lang.t("LOGROS E INSIGNIAS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, DS.C_TEXT)
	draw_string(fsb, o + Vector2(pw - 188, 42), "%d / %d" % [done_n, list.size()], HORIZONTAL_ALIGNMENT_RIGHT, 160, 20, DS.C_ACCENT)
	var bar := Rect2(o + Vector2(28, 58), Vector2(pw - 56, 5))
	draw_style_box(DS.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 3, 0, 0), bar)
	if done_n > 0:
		draw_style_box(DS.box(DS.C_ACCENT, Color(0, 0, 0, 0), 0, 3, 0, 0), Rect2(bar.position, Vector2(bar.size.x * float(done_n) / float(list.size()), 5)))
	var cols: int = 5
	for i in list.size():
		var a: Dictionary = list[i]
		var on: bool = game.ach_done.has(a["id"])
		var cx: float = o.x + 20.0 + float(i % cols) * 152.0 + 76.0
		var cy: float = o.y + 125.0 + float(i / cols) * 148.0
		var cell := Rect2(cx - 70.0, cy - 46.0, 140.0, 136.0)
		draw_style_box(DS.box(DS.C_SURF2 if on else DS.C_SURF1, DS.C_LINE_HI if on else DS.C_LINE, 1, DS.R_MD, 0, 0), cell)
		_medal(Vector2(cx, cy), 28.0, a["c"], a["s"], on)
		if not on:
			var lk: Texture2D = DS.icon("lock", 16, DS.C_MUTED)
			if lk != null:
				draw_texture(lk, Vector2(cell.end.x - 24.0, cell.position.y + 6.0))
		var nm: String = a["n"] if on else "???"
		var tw: float = fsb.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(fsb, Vector2(cx - tw / 2.0, cy + 46.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DS.C_TEXT if on else DS.C_MUTED)
		draw_multiline_string(font, Vector2(cx - 64.0, cy + 62.0), a["d"], HORIZONTAL_ALIGNMENT_CENTER, 128.0, 11, 3, DS.C_DIM if on else DS.C_MUTED)
	draw_string(font, o + Vector2(28, ph - 16), Lang.t("[K] o [Esc]: cerrar"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DS.C_MUTED)
