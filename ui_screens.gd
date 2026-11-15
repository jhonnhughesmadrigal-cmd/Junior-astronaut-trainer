extends RefCounted
# v28 — Pantallas rediseñadas con el sistema de diseno (DS): Como jugar, Creditos, Finales
# (lista del menu) y la pantalla de final de partida. Solo interfaz: no cambia la logica.

const DS = preload("res://design_system.gd")


# ---------- componentes ----------

# Tecla con aspecto de "tecla fisica" (fondo elevado, borde, letra media).
static func keycap(text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = DS.box(DS.C_SURF3, DS.C_LINE_HI, 1, DS.R_SM, DS.S2, 2)
	sb.border_width_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	var l: Label = DS.label(text, DS.F_LABEL, DS.C_TEXT, "Medium")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pc.add_child(l)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pc


# Encabezado de seccion con icono.
static func section(icon_name: String, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", DS.S2)
	if icon_name != "":
		h.add_child(DS.icon_rect(icon_name, 16, DS.C_ACCENT))
	var c: Label = DS.caption(text)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(c)
	return h


static func hint(text: String) -> Label:
	return DS.label(text, DS.F_LABEL, DS.C_DIM)


# Chip de estado pequeno ("good", "warn", "bad", "accent", "" neutro).
static func chip(text: String, state: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var c: Color = DS.state_color(state)
	pc.add_theme_stylebox_override("panel", DS.box(Color(c, 0.14), Color(c, 0.5), 1, 999, DS.S2, 1))
	var l: Label = DS.label(text, 12, c, "SemiBold")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	pc.add_child(l)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pc


# Barra de progreso fina (frac 0..1) con color de estado.
static func progress(frac: float, state: String = "accent", h: float = 6.0) -> Control:
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(0, h)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.add_theme_stylebox_override("panel", DS.box(DS.C_SURF3, Color(0, 0, 0, 0), 0, int(h / 2.0), 0, 0))
	var fg := Panel.new()
	fg.add_theme_stylebox_override("panel", DS.box(DS.state_color(state), Color(0, 0, 0, 0), 0, int(h / 2.0), 0, 0))
	fg.anchor_bottom = 1.0
	fg.anchor_right = clampf(frac, 0.0, 1.0)
	bg.add_child(fg)
	return bg


static func _card(state: String = "") -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", DS.status_card(state) if state != "" else DS.card(1, DS.R_MD, 0.9))
	return pc


static func _strip(t: String) -> String:
	return t.replace("[b]", "").replace("[/b]", "")


# ---------- Como jugar ----------

# rows: [[tecla, accion] ...]; una fila con accion "" es un encabezado de grupo.
static func howto(rows: Array) -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 390)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", DS.S5)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cols)
	var groups: Array = []
	for r in rows:
		if str(r[1]) == "":
			groups.append([_strip(str(r[0])), []])
		elif not groups.is_empty():
			groups[groups.size() - 1][1].append(r)
	var icons: Array = ["planet", "tool", "map", "gear"]
	var colv: Array = [VBoxContainer.new(), VBoxContainer.new()]
	for c in colv:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", DS.S2)
		cols.add_child(c)
	for gi in groups.size():
		var col: VBoxContainer = colv[0 if gi < 2 else 1]
		if col.get_child_count() > 0:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, DS.S2)
			col.add_child(sp)
		col.add_child(section(icons[gi % icons.size()], groups[gi][0]))
		for r in groups[gi][1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", DS.S3)
			var kbox := HBoxContainer.new()
			kbox.custom_minimum_size = Vector2(150, 0)
			kbox.add_theme_constant_override("separation", 4)
			var parts: PackedStringArray = str(r[0]).split(" / ")
			var short: bool = true
			for k in parts:
				if k.length() > 10:
					short = false
			if not short:
				parts = PackedStringArray([str(r[0])])
			for k in parts:
				kbox.add_child(keycap(k))
			row.add_child(kbox)
			var al: Label = DS.label(str(r[1]), 14, DS.C_TEXT)
			al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(al)
			col.add_child(row)
	return sc


# ---------- Creditos ----------

static func credits() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", DS.S2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", DS.S2)
	var t: Label = DS.label(Lang.t("Misión Perseo"), DS.F_H2, DS.C_TEXT, "SemiBold")
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(t)
	head.add_child(chip(Lang.t("Versión alfa"), "warn"))
	v.add_child(head)
	v.add_child(hint(Lang.t("Junior Astronaut Mission Trainer · proyecto escolar hecho con Godot 4 (motor libre, licencia MIT).")))
	var items: Array = [
		["book", Lang.t("Historia"), Lang.t("Original, inspirada en la premisa de la película The Martian (2015). Personajes y diálogos inventados para este proyecto.")],
		["planet", Lang.t("Datos reales"), Lang.t("NASA y otras fuentes citadas en DATOS.md. Las cifras son aproximadas: verifícalas en la fuente original.")],
		["tool", Lang.t("Arte, 3D, música y sonido"), Lang.t("Generados por código para este proyecto, sin archivos externos ni logotipos de la NASA.")],
		["box", Lang.t("Tipografía"), Lang.t("Inter, de Rasmus Andersson (SIL Open Font License 1.1).")],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DS.S3)
	grid.add_theme_constant_override("v_separation", DS.S3)
	v.add_child(grid)
	for it in items:
		var pc: PanelContainer = _card()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.custom_minimum_size = Vector2(250, 0)
		var iv := VBoxContainer.new()
		iv.add_theme_constant_override("separation", DS.S1)
		pc.add_child(iv)
		iv.add_child(section(str(it[0]), str(it[1])))
		iv.add_child(DS.label(str(it[2]), 14, DS.C_TEXT))
		grid.add_child(pc)
	return v


# ---------- Finales (lista del menu) ----------

static func endings_list(game) -> Control:
	var order: Array = ["heroes", "ingenio", "unidos", "hilo", "supervivientes", "fail_oxygen", "fail_energy", "fail_food", "fail_water", "fail_shield", "fail_morale"]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", DS.S2)
	var n: int = game.endings_seen.size()
	var tot: int = game.ENDINGS.size()
	var top := HBoxContainer.new()
	var tl: Label = DS.label(Lang.t("Descubiertos: %d / %d") % [n, tot], 14, DS.C_DIM, "Medium")
	top.add_child(tl)
	v.add_child(top)
	v.add_child(progress(float(n) / float(maxi(tot, 1)), "accent"))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 340)
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", DS.S2)
	sc.add_child(list)
	for eid in order:
		var e: Dictionary = game.ENDINGS[eid]
		var lose: bool = str(eid).begins_with("fail_")
		var seen: bool = game.endings_seen.has(eid)
		var pc: PanelContainer = _card(("bad" if lose else "good") if seen else "")
		list.add_child(pc)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", DS.S3)
		pc.add_child(row)
		row.add_child(DS.icon_rect("trophy" if seen and not lose else ("alert" if seen else "lock"), 20, DS.C_TEXT if seen else DS.C_MUTED))
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 2)
		row.add_child(tv)
		var hh := HBoxContainer.new()
		hh.add_theme_constant_override("separation", DS.S2)
		var title: Label = DS.label(str(e["title"]) if seen else "???", 15, DS.C_TEXT if seen else DS.C_MUTED, "SemiBold")
		title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		hh.add_child(title)
		hh.add_child(chip(Lang.t("Derrota") if lose else Lang.t("Supervivencia"), ("bad" if lose else "good") if seen else ""))
		tv.add_child(hh)
		tv.add_child(DS.label(str(e["desc"]) if seen else Lang.t("Final por descubrir."), 13, DS.C_DIM if seen else DS.C_MUTED))
	return v


# ---------- pantalla de final de partida ----------

# Construye la tarjeta del final dentro de game.root_box (igual que antes, ahora con DS).
static func ending_screen(game, won: bool, eid: String) -> void:
	var e: Dictionary = game.ENDINGS[eid]
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game.root_box.add_child(spacer)
	var cc := CenterContainer.new()
	game.root_box.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(820, 0)
	var sb: StyleBoxFlat = DS.card(2, DS.R_LG, 0.94)
	sb.border_color = Color(DS.C_GOOD if won else DS.C_BAD, 0.55)
	sb.border_width_top = 3
	sb.content_margin_left = DS.S5
	sb.content_margin_right = DS.S5
	sb.content_margin_top = DS.S4
	sb.content_margin_bottom = DS.S4
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", DS.S3)
	pc.add_child(v)
	# --- pagina 1: historia ---
	var p1 := VBoxContainer.new()
	p1.add_theme_constant_override("separation", DS.S2)
	v.add_child(p1)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", DS.S3)
	head.add_child(DS.icon_rect("trophy" if won else "alert", 28, DS.C_GOOD if won else DS.C_BAD))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(DS.caption(Lang.t("¡MISIÓN CUMPLIDA!") if won else Lang.t("MISIÓN FALLIDA")))
	hv.add_child(DS.label(str(e["title"]), DS.F_H1, DS.C_TEXT, "SemiBold"))
	head.add_child(hv)
	head.add_child(chip(Lang.t("Supervivencia") if won else Lang.t("Derrota"), "good" if won else "bad"))
	p1.add_child(head)
	p1.add_child(DS.label(str(e["desc"]), DS.F_BODY, DS.C_TEXT))
	var epi := PanelContainer.new()
	epi.add_theme_stylebox_override("panel", DS.box(Color(DS.C_TEAL, 0.8), Color(0, 0, 0, 0), 0, DS.R_MD, DS.S4, DS.S3))
	epi.add_child(DS.label(str(game.ENDING_EPILOGUE[eid]), 15, Color(0.82, 0.9, 0.95)))
	p1.add_child(epi)
	if game.ENDING_TIP.has(eid):
		var tip: PanelContainer = _card("warn")
		var th := HBoxContainer.new()
		th.add_theme_constant_override("separation", DS.S2)
		th.add_child(DS.icon_rect("book", 18, DS.C_WARN))
		th.add_child(DS.label(str(game.ENDING_TIP[eid]), 14, DS.C_TEXT))
		tip.add_child(th)
		p1.add_child(tip)
	var n: int = game.endings_seen.size()
	var tot: int = game.ENDINGS.size()
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", DS.S3)
	var pl: Label = DS.label(Lang.t("Finales descubiertos: %d / %d") % [n, tot], 13, DS.C_DIM)
	pl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pl.autowrap_mode = TextServer.AUTOWRAP_OFF
	pr.add_child(pl)
	var bar: Control = progress(float(n) / float(maxi(tot, 1)), "accent", 4.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(bar)
	p1.add_child(pr)
	# --- pagina 2: estadisticas ---
	var p2 := VBoxContainer.new()
	p2.add_theme_constant_override("separation", DS.S2)
	p2.visible = false
	v.add_child(p2)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", DS.S4)
	p2.add_child(hb)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.custom_minimum_size = Vector2(360, 250)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.text = game.ui.stats_bbcode()
	hb.add_child(rt)
	var rv := VBoxContainer.new()
	rv.custom_minimum_size = Vector2(360, 0)
	hb.add_child(rv)
	rv.add_child(section("clock", Lang.t("Recursos por día")))
	rv.add_child(game.ui.make_chart(230.0))
	# --- botones ---
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", DS.S2)
	v.add_child(br)
	var bt := Button.new()
	bt.text = Lang.t("Ver estadísticas")
	bt.custom_minimum_size = Vector2(0, 42)
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.pressed.connect(func() -> void:
		p2.visible = not p2.visible
		p1.visible = not p2.visible
		bt.text = Lang.t("Ver historia") if p2.visible else Lang.t("Ver estadísticas")
		DS.fade_in(p2 if p2.visible else p1, DS.T_BASE, 6.0))
	br.add_child(bt)
	var b1 := Button.new()
	b1.text = Lang.t("Volver al menú")
	b1.custom_minimum_size = Vector2(0, 42)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.pressed.connect(game._show_menu)
	br.add_child(b1)
	var b2 := Button.new()
	b2.text = Lang.t("Jugar de nuevo")
	b2.custom_minimum_size = Vector2(0, 42)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.pressed.connect(game._new_game.bind(game.location))
	# boton principal con acento (unico)
	b2.add_theme_stylebox_override("normal", DS.box(Color(DS.C_ACCENT, 0.18), Color(DS.C_ACCENT, 0.7), 1, DS.R_MD, DS.S4, DS.S2))
	b2.add_theme_stylebox_override("hover", DS.box(Color(DS.C_ACCENT, 0.28), DS.C_ACCENT, 1, DS.R_MD, DS.S4, DS.S2))
	br.add_child(b2)
	for b in [bt, b1, b2]:
		DS.hover_lift(b)
	DS.fade_in(pc, DS.T_SLOW, 0.0)   # solo opacidad: la posicion la decide el contenedor
