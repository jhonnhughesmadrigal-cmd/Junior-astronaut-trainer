extends RefCounted
# v29 — Pagina "Misiones de clase" del menu: el docente filtra por tema y mundo y elige una mision.

const DS = preload("res://design_system.gd")
const LessonData = preload("res://lesson_data.gd")
const UiScreens = preload("res://ui_screens.gd")


# Construye (o reconstruye) el contenido dentro de `holder`. filt = {"topic": "" | tema, "loc": "" | "Luna" | "Marte"}
static func fill(holder: VBoxContainer, game, filt: Dictionary, on_filter: Callable) -> void:
	for c in holder.get_children():
		c.queue_free()
	var prog: Dictionary = game.lesson.call("progress") if game.lesson != null else {}
	holder.add_child(UiScreens.hint(Lang.t("Lecciones cortas (3–5 min) sobre un tema. El tiempo se detiene y no se toca la partida guardada. Al final hay preguntas y un resumen con fuentes de la NASA.")))
	# --- filtros ---
	var fr := HFlowContainer.new()
	fr.add_theme_constant_override("h_separation", DS.S1)
	fr.add_theme_constant_override("v_separation", DS.S1)
	holder.add_child(fr)
	fr.add_child(_chip_btn(Lang.t("Todos"), str(filt.get("topic", "")) == "", on_filter.bind("topic", "")))
	for t in LessonData.TOPICS:
		fr.add_child(_chip_btn(Lang.t(t), str(filt.get("topic", "")) == t, on_filter.bind("topic", t), str(LessonData.TOPIC_ICON.get(t, ""))))
	var wr := HBoxContainer.new()
	wr.add_theme_constant_override("separation", DS.S1)
	holder.add_child(wr)
	for pair in [["", Lang.t("Luna y Marte")], ["Luna", Lang.t("Luna")], ["Marte", Lang.t("Marte")]]:
		wr.add_child(_chip_btn(str(pair[1]), str(filt.get("loc", "")) == str(pair[0]), on_filter.bind("loc", str(pair[0]))))
	# v35: clases del perfil (estudiante: a las que se unio; docente: las que creo)
	var prof: Node = game.get_node_or_null("Profiles")
	var classes: Array = []
	if prof != null:
		classes = (prof.get("current") as Dictionary).get("classes", [])
	var allowed: Array = []
	if str(filt.get("class", "")) != "":
		allowed = (load("res://profiles.gd") as GDScript).call("read_code", str(filt["class"]))
	if not classes.is_empty():
		var cr := HFlowContainer.new()
		cr.add_theme_constant_override("h_separation", DS.S1)
		holder.add_child(cr)
		cr.add_child(_chip_btn(Lang.t("Todas las misiones"), str(filt.get("class", "")) == "", on_filter.bind("class", ""), "map"))
		for code in classes:
			cr.add_child(_chip_btn(Lang.t("Clase %s") % str(code), str(filt.get("class", "")) == str(code), on_filter.bind("class", str(code)), "book"))
	var nd: int = 0
	for m in LessonData.MISSIONS:
		if prog.has(str(m["id"])):
			nd += 1
	var pl: Label = DS.label(Lang.t("Completadas: %d de %d") % [nd, LessonData.MISSIONS.size()], 12, DS.C_DIM)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wr.add_child(pl)
	# --- tarjetas ---
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 330)
	holder.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", DS.S2)
	grid.add_theme_constant_override("v_separation", DS.S2)
	sc.add_child(grid)
	var shown: int = 0
	for mi in LessonData.MISSIONS.size():
		var m: Dictionary = LessonData.MISSIONS[mi]
		if not allowed.is_empty() and not allowed.has(mi):
			continue
		if str(filt.get("topic", "")) != "" and str(m["topic"]) != str(filt["topic"]):
			continue
		if str(filt.get("loc", "")) != "" and str(m["loc"]) != str(filt["loc"]):
			continue
		grid.add_child(_card(game, m, prog))
		shown += 1
	if shown == 0:
		holder.add_child(UiScreens.hint(Lang.t("No hay misiones con ese filtro.")))


static func _chip_btn(text: String, on: bool, cb: Callable, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_ALL
	var n: StyleBoxFlat = DS.box(Color(DS.C_ACCENT, 0.18) if on else DS.C_SURF2, DS.C_ACCENT if on else DS.C_LINE, 1, 999, DS.S3, 3)
	var h: StyleBoxFlat = DS.box(Color(DS.C_ACCENT, 0.24) if on else DS.C_SURF3, DS.C_ACCENT if on else DS.C_LINE_HI, 1, 999, DS.S3, 3)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", DS.box(Color(0, 0, 0, 0), DS.C_ACCENT, 2, 999, DS.S3, 3))
	b.add_theme_color_override("font_color", DS.C_ACCENT if on else DS.C_DIM)
	if icon_name != "":
		b.icon = DS.icon(icon_name, 14, DS.C_ACCENT if on else DS.C_DIM)
	b.pressed.connect(cb)
	return b


static func _card(game, m: Dictionary, prog: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 118)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", DS.card(1, DS.R_MD, 0.95))
	var hv: StyleBoxFlat = DS.card(2, DS.R_MD, 1.0)
	hv.border_color = DS.C_ACCENT
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", hv)
	b.tooltip_text = Lang.t("Empezar la misión")
	b.pressed.connect(func() -> void: game.lesson.call("start", str(m["id"])))
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + side, DS.S3)
	for side in ["top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, DS.S2)
	b.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", DS.S1)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(DS.icon_rect(str(LessonData.TOPIC_ICON.get(str(m["topic"]), "book")), 16, DS.C_ACCENT))
	var cap: Label = DS.caption(Lang.loc(str(m["loc"])) + " · " + Lang.t(str(m["topic"])) + " · ≈ %d min" % int(m["mins"]))
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(cap)
	if prog.has(str(m["id"])):
		top.add_child(UiScreens.chip(Lang.t("Hecha"), "good"))
	var t: Label = DS.label(Lang.t(str(m["title"])), 16, DS.C_TEXT, "SemiBold")
	v.add_child(t)
	var d: Label = DS.label(Lang.t(str(m["card"])), 13, DS.C_DIM)
	v.add_child(d)
	for n in [cap, t, d]:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b
