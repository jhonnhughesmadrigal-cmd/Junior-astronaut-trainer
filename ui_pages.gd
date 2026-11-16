extends Node
# Interfaz del juego: tema visual, menú principal, opciones, controles y estadísticas.
# No contiene lógica de juego; llama a main.gd (game) para aplicar cambios.

const DS = preload("res://design_system.gd")
const MenuArt = preload("res://menu_art.gd")
const UiScreens = preload("res://ui_screens.gd")
const LessonUi = preload("res://lesson_ui.gd")
const ACCENT: Color = DS.C_ACCENT
const VERSION_TXT: String = "ALFA 0.1"

var game = null
var theme_res: Theme
var menu_root: Control
var menu_bg: TextureRect
var menu_planet: TextureRect
var dest_cards: Dictionary = {}
var page_holder: VBoxContainer
var pages: Dictionary = {}
var cur_page: String = "main"
var sel_loc: String = "Luna"
var sel_diff: int = 1
var btn_continue: Button
var continue_info: Label
var loc_buttons: Dictionary = {}
var diff_buttons: Array = []
var dest_text: RichTextLabel
var diff_text: Label
var endings_box: VBoxContainer     # v28: lista de finales (ui_screens.gd)
var howto_box: VBoxContainer       # v28: controles con teclas (ui_screens.gd)
var lessons_box: VBoxContainer     # v29: misiones de clase (lesson_ui.gd)
var lesson_filter: Dictionary = {"topic": "", "loc": "", "class": ""}
var profile_btn: Button = null     # v35: perfil activo en el menu
var compact: bool = false          # v31: menu compacto para pantallas bajas (movil)
var mref: Dictionary = {}          # v31: nodos del menu que cambian en modo compacto
var learn_overlay: Control
var learn_title: Label
var learn_meta: Label
var learn_status: Label
var learn_text: RichTextLabel
var learn_img: TextureRect
var learn_key: LineEdit
var quiz_q: Label
var quiz_btns: Array = []
var quiz_fb: RichTextLabel
var quiz_next: Button
var quiz_i: int = 0
var quiz_done: bool = false
var options_overlay: Control
var bind_btns: Dictionary = {}
var controls_overlay: Control
var stats_overlay: Control
var controls_text: RichTextLabel
var stats_text: RichTextLabel
var stats_chart: Control
var opt: Dictionary = {}
var screen_info: Label
var syncing: bool = false


# ---------- tema ----------

func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 8, mx: int = 14, my: int = 8) -> StyleBoxFlat:
	return DS.box(bg, border, bw, radius, mx, my)


func make_theme() -> Theme:
	return DS.make_theme()


func build_all() -> void:
	theme_res = make_theme()
	game.theme = theme_res
	_build_menu()
	_build_options()
	_build_controls()
	_build_stats()
	_build_learn()
	# v35: perfiles (educativo / personal / invitado) y su pantalla
	var prof := Node.new()
	prof.set_script(load("res://profiles.gd"))
	prof.name = "Profiles"
	game.add_child(prof)
	prof.call("setup", game)
	var pui := Control.new()
	pui.set_script(load("res://profile_ui.gd"))
	pui.name = "ProfileUI"
	game.add_child(pui)
	pui.call("setup", game, prof)
	refresh_profile()
	if (prof.get("current") as Dictionary).is_empty():
		pui.call("show_choose")
	# v29: motor de las misiones de clase
	var les := Control.new()
	les.set_script(load("res://lessons.gd"))
	les.name = "Lessons"
	les.set("game", game)
	game.add_child(les)
	game.set("lesson", les)
	# v30: controles tactiles (movil y tableta)
	var touch := Control.new()
	touch.set_script(load("res://touch_ui.gd"))
	touch.name = "TouchUI"
	touch.set("game", game)
	game.add_child(touch)
	opt["touch_node"] = touch
	# v31: interfaz adaptable a moviles (escala automatica, encaje de paneles, aviso de girar)
	var fit := Node.new()
	fit.set_script(load("res://ui_fit.gd"))
	fit.name = "UiFit"
	game.add_child(fit)
	fit.call("setup", game)
	# v28: microinteracciones (hover, pulsacion, fundido de paneles)
	var motion := Node.new()
	motion.set_script(load("res://ui_motion.gd"))
	motion.name = "UiMotion"
	game.add_child(motion)
	motion.call("setup", game, [game.get("fade_rect"), game.get("load_ov")])


# ---------- utilidades de interfaz ----------

func _lbl(text: String, size: int, col: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", DS.font("SemiBold" if size >= 20 else "Regular"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _rich(h: float, fit: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = fit
	r.scroll_active = not fit
	r.custom_minimum_size = Vector2(0, h)
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 16)
	return r


func _btn(text: String, cb: Callable, h: float = 42.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.pressed.connect(cb)
	return b


func _hline() -> HSeparator:
	return HSeparator.new()


# ---------- menú principal ----------

func _menu_btn(text: String, cb: Callable, icon_name: String = "", primary: bool = false) -> Button:
	var b := Button.new()
	b.text = "      " + text if icon_name != "" else text
	b.custom_minimum_size = Vector2(0, 40)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_font_override("font", DS.font("Medium"))
	var n: StyleBoxFlat = DS.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, DS.R_MD, DS.S4, DS.S2)
	var h: StyleBoxFlat = DS.box(Color(DS.C_SURF3, 0.85), DS.C_LINE_HI, 1, DS.R_MD, DS.S4, DS.S3)
	var p: StyleBoxFlat = DS.box(Color(DS.C_ACCENT, 0.18), DS.C_ACCENT, 1, DS.R_MD, DS.S4, DS.S3)
	if primary:
		n = DS.box(Color(DS.C_ACCENT, 0.14), Color(DS.C_ACCENT, 0.55), 1, DS.R_MD, DS.S4, DS.S3)
		h = DS.box(Color(DS.C_ACCENT, 0.24), DS.C_ACCENT, 1, DS.R_MD, DS.S4, DS.S3)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", DS.box(Color(0, 0, 0, 0), DS.C_ACCENT, 2, DS.R_MD, DS.S4, DS.S3))
	b.add_theme_color_override("font_color", DS.C_TEXT if primary else DS.C_DIM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(cb)
	b.set_meta("menu_btn", true)
	if icon_name != "":
		var ic: TextureRect = DS.icon_rect(icon_name, 20, DS.C_ACCENT if primary else DS.C_DIM)
		ic.position = Vector2(DS.S4, 10)
		b.add_child(ic)
	DS.hover_lift(b)
	return b


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.add_child(menu_root)
	menu_bg = TextureRect.new()
	menu_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_bg.stretch_mode = TextureRect.STRETCH_SCALE
	menu_bg.texture = game.vp3d.get_texture()
	menu_root.add_child(menu_bg)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	grad.colors = PackedColorArray([Color(0.02, 0.03, 0.06, 0.96), Color(0.02, 0.03, 0.06, 0.74), Color(0.02, 0.03, 0.06, 0.18)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 8
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	menu_root.add_child(margin)
	mref["margin"] = margin
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 40)
	mref["hb"] = hb
	margin.add_child(hb)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 4)
	hb.add_child(left)
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 10)
	menu_planet = TextureRect.new()
	menu_planet.texture = MenuArt.planet("Luna", 256)
	menu_planet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_planet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_planet.custom_minimum_size = Vector2(40, 40)
	menu_planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(menu_planet)
	var bc: Label = DS.caption(Lang.t("Junior Astronaut · Mission Trainer"))
	bc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(bc)
	left.add_child(brand)
	var title: Label = _lbl(Lang.t("MISIÓN PERSEO"), 40, DS.C_TEXT)
	mref["title"] = title
	mref["left"] = left
	title.add_theme_font_override("font", DS.font("SemiBold"))
	left.add_child(title)
	left.add_child(_lbl(Lang.t("Entrenador de misión · Luna y Marte"), 15, DS.C_DIM))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	mref["sp"] = sp
	left.add_child(sp)
	btn_continue = _menu_btn(Lang.t("Continuar partida"), _on_continue, "play", true)
	left.add_child(btn_continue)
	continue_info = _lbl("", 13, DS.C_DIM)
	left.add_child(continue_info)
	left.add_child(_menu_btn(Lang.t("Nueva misión"), _on_new_mission, "planet"))
	left.add_child(_menu_btn(Lang.t("Misiones de clase"), show_page.bind("lessons"), "map"))
	profile_btn = _menu_btn(Lang.t("Perfil"), open_profile, "crew")
	left.add_child(profile_btn)
	left.add_child(_menu_btn(Lang.t("Cómo jugar"), show_page.bind("howto"), "book"))
	left.add_child(_menu_btn(Lang.t("Finales"), show_page.bind("endings"), "trophy"))
	left.add_child(_menu_btn(Lang.t("Opciones"), open_options, "gear"))
	left.add_child(_menu_btn(Lang.t("Créditos"), show_page.bind("credits"), "crew"))
	if not game._is_web():
		left.add_child(_menu_btn(Lang.t("Salir"), _on_quit, "lock"))
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(grow)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 6)
	lang_row.add_child(_lbl("Idioma / Language", 13, DS.C_DIM))
	for lc in ["es", "en"]:
		var lb: Button = _btn("ES" if lc == "es" else "EN", _set_lang.bind(lc), 30.0)
		lb.custom_minimum_size = Vector2(46, 30)
		if Lang.code == lc:
			# idioma activo: se marca con el acento (no atenuado como un boton deshabilitado)
			for sn in ["normal", "hover", "pressed", "focus"]:
				lb.add_theme_stylebox_override(sn, DS.box(Color(DS.C_ACCENT, 0.18), DS.C_ACCENT, 1, DS.R_MD, 6, 4))
			lb.add_theme_color_override("font_color", DS.C_ACCENT)
		lang_row.add_child(lb)
	left.add_child(lang_row)
	var ver: Label = _lbl(Lang.t("%s · Historia original inspirada en la premisa de The Martian (2015)") % VERSION_TXT, 12, DS.C_MUTED)
	left.add_child(ver)
	mref["ver"] = ver
	page_holder = VBoxContainer.new()
	page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(page_holder)
	_build_page_main()
	_build_page_new()
	_build_page_howto()
	_build_page_endings()
	_build_page_credits()
	_build_page_lessons()
	show_page("main")


func _page(nm: String, title: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2({"new": 620, "howto": 720, "credits": 620, "lessons": 720}.get(nm, 580), 0)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_END
	pc.add_theme_stylebox_override("panel", DS.card(1, DS.R_LG, 0.93))
	page_holder.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	v.add_child(_lbl(title, 24, DS.C_TEXT))
	v.add_child(_hline())
	pages[nm] = pc
	return v


func show_page(nm: String) -> void:
	cur_page = nm
	for k in pages:
		pages[k].visible = (k == nm)
	if pages.has(nm):
		DS.fade_in(pages[nm], DS.T_BASE, 10.0)
	if nm == "endings":
		_fill_endings()
	elif nm == "howto":
		_fill_howto()
	elif nm == "lessons":
		_fill_lessons()
	if game != null and nm != "new" and game.in_menu:
		game._menu_preview(game.menu_loc)


# v31: modo compacto del menu (lo activa ui_fit.gd cuando la pantalla es baja, p. ej. un movil)
func set_compact(on: bool) -> void:
	if on == compact or mref.is_empty():
		return
	compact = on
	for side in ["left", "right", "top", "bottom"]:
		(mref["margin"] as MarginContainer).add_theme_constant_override("margin_" + side, 14 if on else 34)
	(mref["hb"] as HBoxContainer).add_theme_constant_override("separation", 18 if on else 40)
	(mref["title"] as Label).add_theme_font_size_override("font_size", 30 if on else 40)
	(mref["sp"] as Control).custom_minimum_size = Vector2(0, 2 if on else 14)
	(mref["ver"] as Label).visible = not on
	(mref["left"] as VBoxContainer).custom_minimum_size = Vector2(280 if on else 330, 0)
	(mref["left"] as VBoxContainer).add_theme_constant_override("separation", 2 if on else 4)
	continue_info.visible = not on
	for c in (mref["left"] as VBoxContainer).get_children():
		if c is Button and c.has_meta("menu_btn"):
			(c as Button).custom_minimum_size = Vector2(0, 34 if on else 40)
	_refresh_rich.call_deferred()


# los RichTextLabel con alto automatico no recalculan su alto al cambiar el ancho: se reasigna el texto
func _refresh_rich() -> void:
	for n in menu_root.find_children("*", "RichTextLabel", true, false):
		var r: RichTextLabel = n
		if r.fit_content:
			var t: String = r.text
			r.text = ""
			r.text = t


func _build_page_main() -> void:
	var v: VBoxContainer = _page("main", Lang.t("La misión"))
	var r: RichTextLabel = _rich(0, true)
	mref["main_rich"] = r
	r.text = Lang.t("La nave de reabastecimiento falló y el rescate tardará [b]30 días[/b] en llegar.\n\nComo [b]Wilson[/b], ingeniero y botánico, mantienes viva a una tripulación de cuatro: oxígeno, energía, comida, agua y protección contra la radiación.\n\n[b]•[/b] Un reloj en tiempo real con día y noche\n[b]•[/b] Fabrica herramientas y explora la superficie\n[b]•[/b] Visita lugares reales: Apolo 11, Shackleton, Jezero, Olympus Mons...\n[b]•[/b] Pesadillas, eventos graves, 11 finales distintos\n[b]•[/b] Vista 3D con cámara en primera persona")
	v.add_child(r)
	v.add_child(_lbl(Lang.t("Versión alfa: puede haber errores. Gracias por probarla."), 13, Color(1.0, 0.85, 0.5)))


const DEST: Dictionary = {
	"Luna": {"name": "LUNA", "tag": "Noche de 14 días", "desc": "Sin atmósfera: la radiación y los micrometeoritos llegan directos. La noche lunar dura unos 14 días sin luz solar.", "rows": [["planet", "Gravedad", "≈ 1,6 m/s² (1/6 de la Tierra)"], ["shield", "Atmósfera", "Prácticamente ninguna"], ["temp", "Temperatura", "≈ −180 a +120 °C"], ["alert", "Riesgo", "Noche larga, poca energía"]]},
	"Marte": {"name": "MARTE", "tag": "Tormentas de polvo", "desc": "Atmósfera muy delgada, frío y polvo. Las tormentas cubren los paneles solares y bajan la energía.", "rows": [["planet", "Gravedad", "≈ 3,7 m/s² (38 % de la Tierra)"], ["shield", "Atmósfera", "≈ 0,6 % de la terrestre"], ["temp", "Temperatura", "Media ≈ −60 °C"], ["alert", "Riesgo", "Tormentas de polvo"]]},
}


func _build_page_new() -> void:
	var v: VBoxContainer = _page("new", Lang.t("Nueva misión"))
	v.add_theme_constant_override("separation", 6)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var grp := ButtonGroup.new()
	for loc in ["Luna", "Marte"]:
		var info: Dictionary = DEST[loc]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(0, 262)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_contents = true
		b.add_theme_stylebox_override("normal", DS.card(1, DS.R_LG, 1.0))
		var hov: StyleBoxFlat = DS.card(2, DS.R_LG, 1.0)
		hov.border_color = DS.C_LINE_HI
		b.add_theme_stylebox_override("hover", hov)
		var sel: StyleBoxFlat = DS.card(2, DS.R_LG, 1.0)
		sel.border_color = DS.C_ACCENT
		sel.set_border_width_all(2)
		b.add_theme_stylebox_override("pressed", sel)
		b.add_theme_stylebox_override("hover_pressed", sel)
		b.add_theme_stylebox_override("focus", sel)
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.add_theme_constant_override("separation", 6)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var img := TextureRect.new()
		img.texture = MenuArt.landscape(loc, 520, 200)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.custom_minimum_size = Vector2(0, 84)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(img)
		var body := MarginContainer.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "bottom"]:
			body.add_theme_constant_override("margin_" + side, 12)
		col.add_child(body)
		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 3)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(bv)
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(head)
		var nm: Label = DS.label(Lang.t(info["name"]), 20, DS.C_TEXT, "SemiBold")
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(nm)
		var chk: TextureRect = DS.icon_rect("check", 20, DS.C_ACCENT)
		chk.name = "Check"
		chk.visible = false
		head.add_child(chk)
		var tg: Label = DS.label(Lang.t(info["tag"]), 13, DS.C_ACCENT, "Medium")
		tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(tg)
		for r in info["rows"]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(DS.icon_rect(r[0], 15, DS.C_DIM))
			var rl: Label = DS.label(Lang.t(r[1]) + ":", 12, DS.C_DIM)
			rl.autowrap_mode = TextServer.AUTOWRAP_OFF
			rl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(rl)
			var rv: Label = DS.label(Lang.t(r[2]), 12, DS.C_TEXT)
			rv.autowrap_mode = TextServer.AUTOWRAP_OFF
			rv.clip_text = true
			rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(rv)
			bv.add_child(row)
		b.toggled.connect(_on_loc_toggled.bind(loc))
		hb.add_child(b)
		DS.hover_lift(b)
		loc_buttons[loc] = b
		dest_cards[loc] = chk
	dest_text = _rich(0, true)
	dest_text.add_theme_font_size_override("normal_font_size", 13)
	v.add_child(dest_text)
	v.add_child(DS.caption(Lang.t("Dificultad")))
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 6)
	v.add_child(hb2)
	var grp2 := ButtonGroup.new()
	for i in game.DIFFICULTIES.size():
		var b2 := Button.new()
		b2.toggle_mode = true
		b2.button_group = grp2
		b2.custom_minimum_size = Vector2(0, 38)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.text = game.DIFFICULTIES[i]["name"]
		b2.toggled.connect(_on_diff_toggled.bind(i))
		var psel: StyleBoxFlat = DS.box(Color(DS.C_ACCENT, 0.18), DS.C_ACCENT, 1, DS.R_MD, DS.S3, DS.S2)
		b2.add_theme_stylebox_override("pressed", psel)
		b2.add_theme_stylebox_override("hover_pressed", psel)
		hb2.add_child(b2)
		diff_buttons.append(b2)
	diff_text = _lbl("", 14, DS.C_DIM)
	v.add_child(diff_text)
	v.add_child(_hline())
	var hb3 := HBoxContainer.new()
	hb3.add_theme_constant_override("separation", 10)
	v.add_child(hb3)
	hb3.add_child(_btn(Lang.t("Volver"), show_page.bind("main"), 44.0))
	var go: Button = _btn(Lang.t("COMENZAR MISIÓN"), _on_start, 44.0)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.add_theme_font_size_override("font_size", 19)
	var gn: StyleBoxFlat = DS.box(Color(DS.C_ACCENT, 0.9), Color(0, 0, 0, 0), 0, DS.R_MD, DS.S4, DS.S3)
	var gh: StyleBoxFlat = DS.box(Color(0.42, 0.85, 0.96), Color(0, 0, 0, 0), 0, DS.R_MD, DS.S4, DS.S3)
	go.add_theme_stylebox_override("normal", gn)
	go.add_theme_stylebox_override("hover", gh)
	go.add_theme_stylebox_override("pressed", gn)
	go.add_theme_color_override("font_color", Color(0.03, 0.07, 0.12))
	go.add_theme_color_override("font_hover_color", Color(0.03, 0.07, 0.12))
	go.add_theme_color_override("font_pressed_color", Color(0.03, 0.07, 0.12))
	hb3.add_child(go)


func _build_page_howto() -> void:
	var v: VBoxContainer = _page("howto", Lang.t("Cómo jugar"))
	howto_box = VBoxContainer.new()
	v.add_child(howto_box)
	v.add_child(UiScreens.hint(Lang.t("Las teclas se pueden cambiar en Opciones > Controles.")))


func _build_page_endings() -> void:
	var v: VBoxContainer = _page("endings", Lang.t("Finales"))
	endings_box = VBoxContainer.new()
	v.add_child(endings_box)


func _build_page_credits() -> void:
	var v: VBoxContainer = _page("credits", Lang.t("Créditos"))
	v.add_child(UiScreens.credits())


func open_profile() -> void:
	var pui: Node = game.get_node_or_null("ProfileUI")
	if pui != null:
		pui.call("show_account")


# v35: el boton del menu muestra el perfil activo; al cambiar de perfil se recarga «Continuar»
func refresh_profile() -> void:
	var prof: Node = game.get_node_or_null("Profiles")
	if prof == null or profile_btn == null:
		return
	profile_btn.text = "      " + Lang.t("Perfil") + ": " + str(prof.call("label"))
	profile_btn.clip_text = true
	profile_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if btn_continue != null:
		refresh_continue()
	if cur_page == "lessons":
		_fill_lessons()


func _build_page_lessons() -> void:
	var v: VBoxContainer = _page("lessons", Lang.t("Misiones de clase"))
	lessons_box = VBoxContainer.new()
	lessons_box.add_theme_constant_override("separation", DS.S2)
	v.add_child(lessons_box)


func _fill_lessons() -> void:
	LessonUi.fill(lessons_box, game, lesson_filter, _on_lesson_filter)


func _on_lesson_filter(key: String, val: String) -> void:
	lesson_filter[key] = val
	_fill_lessons()


func _fill_endings() -> void:
	for c in endings_box.get_children():
		c.queue_free()
	endings_box.add_child(UiScreens.endings_list(game))


func _fill_howto() -> void:
	for c in howto_box.get_children():
		c.queue_free()
	howto_box.add_child(UiScreens.howto(controls_rows()))


func refresh_continue() -> void:
	var ok: bool = game._save_compatible()
	btn_continue.disabled = not ok
	var sm: String = game._save_summary() if ok else Lang.t("No hay partida guardada.")
	var ls: PackedStringArray = sm.split("\n")
	continue_info.text = ls[0] if ls.size() < 2 else ls[0] + "\n" + ls[ls.size() - 1]


func open_menu(page: String = "main") -> void:
	menu_root.visible = true
	sel_diff = game.difficulty
	if game.menu_loc != "":
		sel_loc = game.menu_loc
	refresh_continue()
	_sync_new_page()
	show_page(page)


func close_menu() -> void:
	menu_root.visible = false


func _sync_new_page() -> void:
	syncing = true
	loc_buttons[sel_loc].button_pressed = true
	diff_buttons[sel_diff].button_pressed = true
	syncing = false
	_update_dest_text()
	_update_diff_text()


func _update_dest_text() -> void:
	dest_text.text = Lang.t(DEST[sel_loc]["desc"])
	for k in dest_cards:
		(dest_cards[k] as Control).visible = (k == sel_loc)
	if menu_planet != null:
		menu_planet.texture = MenuArt.planet(sel_loc, 256)


func _update_diff_text() -> void:
	var texts: Array = [Lang.t("Menos gasto de recursos, menos eventos y menos pesadillas. Para aprender las mecánicas."), Lang.t("Equilibrada. La experiencia pensada para la misión."), Lang.t("Más gasto, más eventos y más pesadillas. Exige planificar bien el tiempo y las herramientas."), Lang.t("Empieza duro y empeora cada día: mucho gasto, muchos eventos y cada vez menos material en la superficie. Solo para expertos.")]
	diff_text.text = texts[sel_diff]


func _on_loc_toggled(on: bool, loc: String) -> void:
	if syncing or not on:
		return
	sel_loc = loc
	_update_dest_text()
	if game.preview_built != loc:
		game.loading_run(Lang.t("Preparando %s…") % Lang.loc(loc), game._menu_preview.bind(loc))
	else:
		game._menu_preview(loc)


func _on_diff_toggled(on: bool, i: int) -> void:
	if syncing or not on:
		return
	sel_diff = i
	_update_diff_text()


func _on_new_mission() -> void:
	_sync_new_page()
	show_page("new")
	game._menu_preview(sel_loc)


func _on_start() -> void:
	game.difficulty = sel_diff
	game._save_settings()
	game.loading_run(Lang.t("Preparando tu base en %s…") % Lang.loc(sel_loc), game._new_game.bind(sel_loc))


func _on_continue() -> void:
	game.loading_run(Lang.t("Cargando tu partida…"), game._continue_game)


func _on_quit() -> void:
	get_tree().quit()


# ---------- opciones ----------

func _slider(text: String, val: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l: Label = _lbl(text, 16)
	l.custom_minimum_size = Vector2(190, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(240, 24)
	s.value_changed.connect(cb)
	row.add_child(s)
	return row


func _opt_row(text: String, items: Array, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l: Label = _lbl(text, 16)
	l.custom_minimum_size = Vector2(190, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.item_selected.connect(cb)
	row.add_child(o)
	return row


func _overlay(title: String, w: float) -> Array:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	game.add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(DS.C_BG, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(w, 0)
	pc.add_theme_stylebox_override("panel", DS.card(2, DS.R_LG, 0.97))
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	v.add_child(_lbl(title, DS.F_H1, DS.C_TEXT))
	v.add_child(_hline())
	return [ov, v]


func _build_options() -> void:
	var made: Array = _overlay(Lang.t("Opciones"), 700.0)
	options_overlay = made[0]
	var v: VBoxContainer = made[1]
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 380)
	v.add_child(tabs)
	# --- pantalla --- (v28: con desplazamiento, para que el panel quepa en pantallas bajas)
	var t1sc := ScrollContainer.new()
	t1sc.name = Lang.t("Pantalla")
	t1sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(t1sc)
	var t1 := VBoxContainer.new()
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1.add_theme_constant_override("separation", 10)
	t1sc.add_child(t1)
	var r1: HBoxContainer = _opt_row(Lang.t("Modo de pantalla"), [Lang.t("Ventana"), Lang.t("Pantalla completa"), Lang.t("Ventana sin bordes")], _on_display_mode)
	opt["display"] = r1.get_child(1)
	t1.add_child(r1)
	var r2: HBoxContainer = _opt_row(Lang.t("Tamaño de ventana"), [Lang.t("Automático")], _on_win_size)
	opt["winsize"] = r2.get_child(1)
	t1.add_child(r2)
	if game._is_web():
		r2.visible = false
		(opt["display"] as OptionButton).remove_item(2)
	var r3: HBoxContainer = _opt_row(Lang.t("Tamaño de la interfaz"), [Lang.t("Compacta (85%)"), Lang.t("Normal (100%)")], _on_ui_scale)
	opt["uiscale"] = r3.get_child(1)
	t1.add_child(r3)
	var r4: HBoxContainer = _opt_row(Lang.t("Velocidad de las tareas"), [Lang.t("Lenta (x5 / x10)"), Lang.t("Normal (x20 / x40)"), Lang.t("Rápida (x50 / x100)"), Lang.t("Muy rápida (x120 / x240)")], _on_task_speed)
	opt["taskspeed"] = r4.get_child(1)
	t1.add_child(r4)
	var c1 := CheckButton.new()
	c1.text = Lang.t("Sincronización vertical (VSync)")
	c1.toggled.connect(_on_vsync)
	opt["vsync"] = c1
	t1.add_child(c1)
	var c2 := CheckButton.new()
	c2.text = Lang.t("Mostrar FPS (F3)")
	c2.toggled.connect(_on_fps)
	opt["fps"] = c2
	t1.add_child(c2)
	var ce := CheckButton.new()
	ce.text = Lang.t("Modo de lectura fácil (letra grande y frases cortas)")
	ce.toggled.connect(_on_easy)
	opt["easy"] = ce
	t1.add_child(ce)
	var ct := CheckButton.new()
	ct.text = Lang.t("Tutorial guiado al empezar cada misión")
	ct.toggled.connect(_on_tut_opt)
	opt["tut"] = ct
	t1.add_child(ct)
	screen_info = _lbl("", 13, DS.C_MUTED)
	t1.add_child(screen_info)
	# --- gráficos ---
	var gsc := ScrollContainer.new()
	gsc.name = Lang.t("Gráficos")
	gsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(gsc)
	var t2 := VBoxContainer.new()
	t2.add_theme_constant_override("separation", 9)
	t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gsc.add_child(t2)
	var g1: HBoxContainer = _opt_row(Lang.t("Calidad general"), [Lang.t("Baja"), Lang.t("Media"), Lang.t("Alta"), Lang.t("Personalizada")], _on_quality)
	opt["quality"] = g1.get_child(1)
	t2.add_child(g1)
	t2.add_child(UiScreens.hint(Lang.t("Baja, Media y Alta ajustan todo lo de abajo de una vez. Si cambias algo por tu cuenta pasa a «Personalizada».")))
	t2.add_child(UiScreens.section("", Lang.t("Rendimiento (si el juego va lento, baja esto primero)")))
	t2.add_child(_gfx_row("shadow_q", Lang.t("Sombras"), [Lang.t("Apagadas"), Lang.t("Bajas"), Lang.t("Altas")]))
	t2.add_child(_gfx_row("aa_mode", Lang.t("Suavizado de bordes (MSAA)"), [Lang.t("Apagado"), "2x", "4x"]))
	var rs: HBoxContainer = _slider(Lang.t("Escala de render: 100 %"), (game.render_scale - 0.5) / 0.5, _on_scale)
	opt["scale"] = rs.get_child(1)
	opt["scale_lbl"] = rs.get_child(0)
	t2.add_child(rs)
	t2.add_child(_gfx_row("fps_idx", Lang.t("Límite de FPS"), [Lang.t("Sin límite"), "30", "60", "120"]))
	t2.add_child(_gfx_row("fx_idx", Lang.t("Efectos y partículas"), [Lang.t("Pocos"), Lang.t("Medios"), Lang.t("Todos")]))
	t2.add_child(UiScreens.hint(Lang.t("Sombras: la opción que más cuesta. Escala: dibuja el 3D a menos resolución (se ve más borroso pero rinde más). MSAA suaviza los bordes. FPS: limitar ahorra batería. Efectos: menos chispas y piedritas.")))
	t2.add_child(UiScreens.section("", Lang.t("Calidad visual")))
	t2.add_child(_gfx_row("tex_quality", Lang.t("Texturas del exterior"), [Lang.t("Sencillas"), Lang.t("Detalladas"), Lang.t("Alta (relieve)")]))
	t2.add_child(_gfx_row("sky_idx", Lang.t("Estrellas del cielo"), [Lang.t("Pocas"), Lang.t("Medias"), Lang.t("Todas")]))
	var c4 := CheckButton.new()
	c4.text = Lang.t("Glow (resplandor de luces y hielo)")
	c4.toggled.connect(_on_gfx_check.bind("glow_on"))
	opt["glow_on"] = c4
	t2.add_child(c4)
	var c5 := CheckButton.new()
	c5.text = Lang.t("Niebla de polvo en Marte")
	c5.toggled.connect(_on_gfx_check.bind("haze_on"))
	opt["haze_on"] = c5
	t2.add_child(c5)
	var br: HBoxContainer = _slider(Lang.t("Brillo: 100 %"), (game.bright - 0.8) / 0.4, _on_bright)
	opt["bright"] = br.get_child(1)
	opt["bright_lbl"] = br.get_child(0)
	t2.add_child(br)
	t2.add_child(UiScreens.hint(Lang.t("Texturas y piedritas: el detalle de forma de las rocas se actualiza al empezar una misión nueva; lo demás se aplica al instante.")))
	var caq := CheckButton.new()
	caq.text = Lang.t("Bajar la calidad automáticamente si el juego va lento")
	caq.toggled.connect(_on_auto_q)
	opt["auto_q"] = caq
	t2.add_child(caq)
	var c3 := CheckButton.new()
	c3.text = Lang.t("Vista 3D (V)")
	c3.toggled.connect(_on_view3d)
	opt["view3d"] = c3
	t2.add_child(c3)
	var g2: HBoxContainer = _opt_row(Lang.t("Cámara (C)"), game.CAM_NAMES, _on_cam)
	opt["cam"] = g2.get_child(1)
	t2.add_child(g2)
	# --- sonido ---
	var t3 := VBoxContainer.new()
	t3.name = Lang.t("Sonido")
	t3.add_theme_constant_override("separation", 14)
	tabs.add_child(t3)
	var s1: HBoxContainer = _slider(Lang.t("Música"), game.music_vol, _on_music)
	opt["music"] = s1.get_child(1)
	t3.add_child(s1)
	var s2: HBoxContainer = _slider(Lang.t("Efectos"), game.sfx_vol, _on_sfx)
	opt["sfx"] = s2.get_child(1)
	t3.add_child(s2)
	# --- juego ---
	var t4 := VBoxContainer.new()
	t4.name = Lang.t("Juego")
	t4.add_theme_constant_override("separation", 14)
	tabs.add_child(t4)
	var s3: HBoxContainer = _slider(Lang.t("Sensibilidad del ratón"), (game.mouse_sens - 0.3) / 1.7, _on_sens)
	opt["sens"] = s3.get_child(1)
	t4.add_child(s3)
	t4.add_child(UiScreens.hint(Lang.t("El ratón gira la mirada en primera persona y en la cámara detrás del personaje.")))
	var rl: HBoxContainer = _opt_row("Idioma / Language", ["Español", "English"], _on_lang_opt)
	opt["lang"] = rl.get_child(1)
	t4.add_child(rl)
	opt["lang_hint"] = UiScreens.hint(Lang.t("El idioma se cambia desde el menú principal (reinicia la escena)."))
	t4.add_child(opt["lang_hint"])
	# --- controles reasignables ---
	var csc := ScrollContainer.new()
	csc.name = Lang.t("Controles")
	csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(csc)
	var t5 := VBoxContainer.new()
	t5.add_theme_constant_override("separation", 6)
	t5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	csc.add_child(t5)
	t5.add_child(UiScreens.hint(Lang.t("Pulsa una acción y luego la tecla que quieras. Si esa tecla ya la usa otra acción, se intercambian. Las flechas siempre mueven; Esc, F1, F2, F3, F11 y Enter no se pueden cambiar.")))
	for d in game.BIND_DEFS:
		var brow := HBoxContainer.new()
		var bl: Label = _lbl(Lang.t(str(d[1])), 15)
		bl.custom_minimum_size = Vector2(230, 0)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(bl)
		var bb := Button.new()
		bb.custom_minimum_size = Vector2(150, 0)
		bb.focus_mode = Control.FOCUS_NONE
		bb.pressed.connect(_on_rebind.bind(str(d[0])))
		brow.add_child(bb)
		bind_btns[str(d[0])] = bb
		t5.add_child(brow)
	t5.add_child(UiScreens.section("", Lang.t("Clic del ratón")))
	var cl: HBoxContainer = _opt_row(Lang.t("Clic izquierdo"), _click_names(), _on_click_left)
	opt["click_left"] = cl.get_child(1)
	t5.add_child(cl)
	var cr: HBoxContainer = _opt_row(Lang.t("Clic derecho"), _click_names(), _on_click_right)
	opt["click_right"] = cr.get_child(1)
	t5.add_child(cr)
	t5.add_child(_btn(Lang.t("Restablecer controles"), _on_reset_binds))
	t5.add_child(UiScreens.section("", Lang.t("Pantalla táctil (móvil y tableta)")))
	var tr: HBoxContainer = _opt_row(Lang.t("Controles táctiles"), [Lang.t("Automático (si la pantalla es táctil)"), Lang.t("Mostrar siempre"), Lang.t("No mostrar")], _on_touch_mode)
	opt["touch"] = tr.get_child(1)
	t5.add_child(tr)
	t5.add_child(UiScreens.hint(Lang.t("Joystick a la izquierda (al borde corres), botones a la derecha. Arrastra en la mitad derecha para mirar en primera persona.")))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	hb.add_child(_btn(Lang.t("Restablecer"), _on_reset_options))
	var close: Button = _btn(Lang.t("Cerrar"), close_options)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(close)


func _on_touch_mode(i: int) -> void:
	if opt.has("touch_node"):
		(opt["touch_node"] as Node).call("set_mode", i)


func open_options() -> void:
	if opt.has("touch") and opt.has("touch_node"):
		(opt["touch"] as OptionButton).select(int((opt["touch_node"] as Node).get("setting")))
	_populate_win_sizes()
	sync_options()
	refresh_binds()
	options_overlay.visible = true
	game._overlay_opened()


func close_options() -> void:
	game.rebinding = ""
	options_overlay.visible = false
	game._save_settings()
	game._overlay_closed()


func _populate_win_sizes() -> void:
	var o: OptionButton = opt["winsize"]
	o.clear()
	o.add_item(Lang.t("Automático (según tu pantalla)"))
	o.set_item_metadata(0, -1)
	var maxs: Vector2i = game._usable_size()
	for i in game.WIN_PRESETS.size():
		var sz: Vector2i = game.WIN_PRESETS[i]
		if sz.x <= maxs.x and sz.y <= maxs.y:
			o.add_item("%d × %d" % [sz.x, sz.y])
			o.set_item_metadata(o.item_count - 1, i)


func _on_auto_q(on: bool) -> void:
	if not syncing:
		game.auto_quality = on
		game.perf_drops = 0
		game._save_settings()


func _on_lang_opt(idx: int) -> void:
	if syncing:
		return
	_set_lang("es" if idx == 0 else "en")


func _set_lang(code: String) -> void:
	# Solo desde el menu principal: recarga la escena para reconstruir todos los textos.
	if game.playing or code == Lang.code:
		return
	Lang.code = code
	game._save_settings()
	game.get_tree().reload_current_scene()


func sync_options() -> void:
	syncing = true
	(opt["lang"] as OptionButton).select(0 if Lang.code == "es" else 1)
	(opt["lang"] as OptionButton).disabled = game.playing
	(opt["lang_hint"] as Label).visible = game.playing
	(opt["display"] as OptionButton).select(mini(game.display_mode, (opt["display"] as OptionButton).item_count - 1))
	var ws: OptionButton = opt["winsize"]
	for i in ws.item_count:
		var md: Variant = ws.get_item_metadata(i)
		if md != null and int(md) == game.win_idx:
			ws.select(i)
	(opt["uiscale"] as OptionButton).select(game.ui_scale_idx)
	(opt["taskspeed"] as OptionButton).select(game.task_speed_idx)
	(opt["vsync"] as CheckButton).set_pressed_no_signal(game.vsync_on)
	(opt["fps"] as CheckButton).set_pressed_no_signal(game.show_fps)
	(opt["easy"] as CheckButton).set_pressed_no_signal(game.easy_read)
	(opt["tut"] as CheckButton).set_pressed_no_signal(game.show_tutorial)
	(opt["quality"] as OptionButton).select(game.quality)
	for k in ["shadow_q", "aa_mode", "fps_idx", "fx_idx", "tex_quality", "sky_idx"]:
		(opt[k] as OptionButton).select(int(game.get(k)))
	(opt["glow_on"] as CheckButton).set_pressed_no_signal(game.glow_on)
	(opt["auto_q"] as CheckButton).set_pressed_no_signal(game.auto_quality)
	(opt["haze_on"] as CheckButton).set_pressed_no_signal(game.haze_on)
	(opt["scale"] as HSlider).set_value_no_signal((game.render_scale - 0.5) / 0.5)
	(opt["scale_lbl"] as Label).text = Lang.t("Escala de render: %d %%") % int(round(game.render_scale * 100.0))
	(opt["bright"] as HSlider).set_value_no_signal((game.bright - 0.8) / 0.4)
	(opt["bright_lbl"] as Label).text = Lang.t("Brillo: %d %%") % int(round(game.bright * 100.0))
	(opt["view3d"] as CheckButton).set_pressed_no_signal(game.view3d_on)
	(opt["cam"] as OptionButton).select(game.cam_mode)
	(opt["music"] as HSlider).set_value_no_signal(game.music_vol)
	(opt["sfx"] as HSlider).set_value_no_signal(game.sfx_vol)
	(opt["sens"] as HSlider).set_value_no_signal((game.mouse_sens - 0.3) / 1.7)
	syncing = false
	update_screen_info()


func update_screen_info() -> void:
	if screen_info == null:
		return
	var scr: Vector2i = game._screen_size()
	var win: Vector2i = game.get_window().size
	screen_info.text = Lang.t("Pantalla: %d × %d  ·  Ventana: %d × %d  ·  Área lógica de juego: %d × %d") % [scr.x, scr.y, win.x, win.y, int(game.size.x), int(game.size.y)]


func _on_display_mode(i: int) -> void:
	if not syncing:
		game._set_display_mode(i)


func _on_win_size(i: int) -> void:
	if syncing:
		return
	var ws: OptionButton = opt["winsize"]
	game._set_win_idx(int(ws.get_item_metadata(i)))


func _on_ui_scale(i: int) -> void:
	if not syncing:
		game._set_ui_scale(i)


func _on_task_speed(i: int) -> void:
	if not syncing:
		game.task_speed_idx = i
		game._save_settings()


func _on_vsync(on: bool) -> void:
	if not syncing:
		game._set_vsync(on)


func _click_names() -> Array:
	return [Lang.t("Usar lo que tienes enfrente"), Lang.t("Mejorar la estación"), Lang.t("Saltar"), Lang.t("Abrir la mochila"), Lang.t("Cambiar objeto en mano"), Lang.t("Nada")]


func refresh_binds() -> void:
	for id in bind_btns.keys():
		(bind_btns[id] as Button).text = Lang.t("Pulsa una tecla...") if game.rebinding == id else game.key_name(id)
	if opt.has("click_left"):
		syncing = true
		(opt["click_left"] as OptionButton).select(game.CLICK_ACTIONS.find(game.click_left))
		(opt["click_right"] as OptionButton).select(game.CLICK_ACTIONS.find(game.click_right))
		syncing = false


func _on_rebind(id: String) -> void:
	game.begin_rebind(id, refresh_binds)
	refresh_binds()


func _on_click_left(i: int) -> void:
	if not syncing:
		game.click_left = game.CLICK_ACTIONS[i]
		game._save_settings()


func _on_click_right(i: int) -> void:
	if not syncing:
		game.click_right = game.CLICK_ACTIONS[i]
		game._save_settings()


func _on_reset_binds() -> void:
	game._default_binds()
	game.rebinding = ""
	game._save_settings()
	refresh_binds()


func _on_easy(on: bool) -> void:
	if not syncing:
		game.easy_read = on
		game._save_settings()


func _on_tut_opt(on: bool) -> void:
	if not syncing:
		game.show_tutorial = on
		game._save_settings()


func _on_fps(on: bool) -> void:
	if not syncing:
		game.show_fps = on


func _gfx_row(key: String, text: String, items: Array) -> HBoxContainer:
	var row: HBoxContainer = _opt_row(text, items, _on_gfx_opt.bind(key))
	opt[key] = row.get_child(1)
	return row


func _on_gfx_opt(i: int, key: String) -> void:
	if not syncing:
		game._set_gfx(key, i)


func _on_gfx_check(on: bool, key: String) -> void:
	if not syncing:
		game._set_gfx(key, on)


func _on_scale(v: float) -> void:
	if syncing:
		return
	var sc: float = snappedf(0.5 + 0.5 * v, 0.05)
	(opt["scale_lbl"] as Label).text = Lang.t("Escala de render: %d %%") % int(round(sc * 100.0))
	game._set_gfx("render_scale", sc)


func _on_bright(v: float) -> void:
	if syncing:
		return
	var b: float = snappedf(0.8 + 0.4 * v, 0.05)
	(opt["bright_lbl"] as Label).text = Lang.t("Brillo: %d %%") % int(round(b * 100.0))
	game._set_gfx("bright", b)


func _on_quality(i: int) -> void:
	if not syncing:
		game._set_quality(i)
		sync_options()


func _on_view3d(on: bool) -> void:
	if not syncing:
		game._set_view3d(on)


func _on_cam(i: int) -> void:
	if not syncing:
		game._set_cam_mode(i)


func _on_music(v: float) -> void:
	if syncing:
		return
	game.music_vol = v
	game._apply_volumes()


func _on_sfx(v: float) -> void:
	if syncing:
		return
	game.sfx_vol = v
	game._sfx("interact")


func _on_sens(v: float) -> void:
	if not syncing:
		game.mouse_sens = 0.3 + 1.7 * v


func _on_reset_options() -> void:
	game._reset_options()
	sync_options()


# ---------- controles ----------

func controls_bbcode() -> String:
	var rows: Array = controls_rows()
	var t: String = "[table=2]"
	for r in rows:
		if r[1] == "":
			t += "[cell][color=#7fd0ff]%s[/color][/cell][cell] [/cell]" % r[0]
		else:
			t += "[cell][color=#ffe29a]%s[/color]    [/cell][cell]%s[/cell]" % [r[0], r[1]]
	t += "[/table]"
	return t


func controls_rows() -> Array:
	var kn: Callable = game.key_name
	return [
		[Lang.t("[b]Moverse[/b]"), ""],
		["%s %s %s %s / %s" % [kn.call("up"), kn.call("left"), kn.call("down"), kn.call("right"), Lang.t("flechas")], Lang.t("Caminar (vista fija o aérea)")],
		[kn.call("sprint"), Lang.t("Correr")],
		[kn.call("jump"), Lang.t("Saltar (cruza huecos y pasa sobre rocas, solo afuera)")],
		[Lang.t("Ratón"), Lang.t("Mirar (primera persona y detrás del personaje)")],
		[Lang.t("[b]Actuar[/b]"), ""],
		[kn.call("interact"), Lang.t("Usar lo que tienes enfrente")],
		[Lang.t("Clic izquierdo / derecho"), Lang.t("Acciones del ratón (se cambian en Opciones > Controles)")],
		[kn.call("map"), Lang.t("Mapa de navegación")],
		[kn.call("pack"), Lang.t("Mochila")],
		[kn.call("diary"), Lang.t("Diario de exploración")],
		[kn.call("ach"), Lang.t("Logros e insignias")],
		["N", Lang.t("Saltar el tutorial guiado")],
		[kn.call("upgrade"), Lang.t("Mejorar la estación frente a ti (obra de ENOC)")],
		[kn.call("hold"), Lang.t("Cambiar el objeto en la mano (kit de parche)")],
		[Lang.t("[b]Cámara y pantalla[/b]"), ""],
		[kn.call("cam"), Lang.t("Cambiar de cámara (4 vistas)")],
		[Lang.t("Rueda del ratón"), Lang.t("Acercar o alejar")],
		[kn.call("view"), Lang.t("Vista 3D / 2D")],
		["F11", Lang.t("Pantalla completa")],
		[Lang.t("[b]Interfaz[/b]"), ""],
		[kn.call("chat"), Lang.t("Mostrar u ocultar el chat")],
		["F1", Lang.t("Controles")],
		["F2", Lang.t("Estadísticas")],
		["F3", Lang.t("Mostrar FPS")],
		[kn.call("mute"), Lang.t("Silenciar la música")],
		["Esc", Lang.t("Pausa")]
	]


func _build_controls() -> void:
	var made: Array = _overlay(Lang.t("Controles"), 640.0)
	controls_overlay = made[0]
	var v: VBoxContainer = made[1]
	controls_text = _rich(380)
	controls_text.text = controls_bbcode()
	v.add_child(controls_text)
	v.add_child(_btn(Lang.t("Cerrar (Esc)"), close_controls))


func open_controls() -> void:
	controls_text.text = controls_bbcode()
	controls_overlay.visible = true
	game._overlay_opened()


func close_controls() -> void:
	controls_overlay.visible = false
	game._overlay_closed()


# ---------- estadísticas ----------

func _fmt_time(secs: float) -> String:
	var s: int = int(secs)
	return "%d min %02d s" % [floori(float(s) / 60.0), s % 60]


func stats_bbcode() -> String:
	var g = game
	var st: Dictionary = g.stats
	var zs: Array = g._zones()
	var total_expl: int = 0
	for i in g.explored.size():
		total_expl += g.explored[i]
	var pct: float = 0.0
	if g.explored.size() > 0:
		pct = 100.0 * float(total_expl) / float(g.explored.size())
	var tb: int = int(st["tools_built"])
	var t: String = Lang.t("[b][color=#7fd0ff]Misión[/color][/b]\n")
	t += Lang.t("Destino: %s  ·  Dificultad: %s\n") % [g.location, g.DIFFICULTIES[g.difficulty]["name"]]
	t += Lang.t("Día [b]%d / %d[/b]  ·  %s  ·  rescate en %d días\n") % [g.day, g.MAX_DAYS, g._clock_text(), maxi(g.MAX_DAYS - g.day, 0)]
	t += Lang.t("Tiempo de juego: %s\n\n") % _fmt_time(float(st["play_time"]))
	t += Lang.t("[b][color=#7fd0ff]Exploración[/color][/b]\n")
	t += Lang.t("Salidas al exterior: %d  ·  Distancia recorrida: %d m\n") % [int(st["expeditions"]), int(float(st["distance"]) * 2.0)]
	t += Lang.t("Mundo explorado: %.1f%%  ·  Zonas visitadas: %d / %d\n") % [pct, g.zones_seen.size(), zs.size()]
	t += Lang.t("Lugares estudiados: %d / %d  ·  Material recogido: %d\n\n") % [int(st["landmarks"]), zs.size() - 1, int(st["collected"])]
	t += Lang.t("[b][color=#7fd0ff]Base y tripulación[/color][/b]\n")
	t += Lang.t("Herramientas fabricadas: %d  ·  Charlas: %d\n") % [tb, int(st["talks"])]
	t += Lang.t("Eventos graves: %d  ·  Días con brecha: %d\n") % [int(st["bad_events"]), int(st["breach_days"])]
	t += Lang.t("Pesadillas: %d  ·  Noches en vela: %d\n") % [int(st["nightmares"]), int(st["collapses"])]
	var chs: Dictionary = st["choices"]
	if chs.size() > 0:
		var parts := PackedStringArray()
		for k in chs:
			parts.append("%s: %s" % [k, chs[k]])
		t += Lang.t("Decisiones: %s\n") % ", ".join(parts)
	t += Lang.t("\n[b][color=#7fd0ff]Recursos ahora[/color][/b]\n")
	for k in g.NAMES:
		t += "%s: %d   " % [g.NAMES[k], int(g.res[k])]
	return t


func make_chart(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.draw.connect(_draw_chart.bind(c))
	return c


func _draw_chart(c: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var sz: Vector2 = c.size
	var pad: Vector2 = Vector2(34.0, 22.0)
	var area := Rect2(pad, sz - Vector2(pad.x + 10.0, pad.y + 22.0))
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.06, 0.12, 0.9))
	for i in 5:
		var yy: float = area.position.y + area.size.y * float(i) / 4.0
		c.draw_line(Vector2(area.position.x, yy), Vector2(area.end.x, yy), Color(0.3, 0.38, 0.55, 0.35), 1.0)
		c.draw_string(font, Vector2(4.0, yy + 4.0), str(100 - i * 25), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.7, 0.85))
	var hist: Array = game.history.duplicate()
	var live: Dictionary = {"day": game.day, "res": game.res.duplicate()}
	if game.playing or hist.size() > 0:
		hist.append(live)
	var n: int = hist.size()
	if n < 2:
		c.draw_string(font, area.position + Vector2(10.0, 30.0), Lang.t("Aún no hay datos suficientes."), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.8, 0.95))
		return
	for k in game.NAMES:
		var pts := PackedVector2Array()
		for i in n:
			var r: Dictionary = hist[i]["res"]
			var v: float = clampf(float(r[k]), 0.0, 100.0)
			pts.append(Vector2(area.position.x + area.size.x * float(i) / float(n - 1), area.end.y - area.size.y * v / 100.0))
		c.draw_polyline(pts, game.bar_colors[k], 2.0, true)
	var step: int = maxi(int(ceil(float(n) / 8.0)), 1)
	for i in range(0, n, step):
		var xx: float = area.position.x + area.size.x * float(i) / float(n - 1)
		c.draw_string(font, Vector2(xx - 6.0, area.end.y + 15.0), "D%d" % int(hist[i]["day"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.7, 0.85))
	var short: Dictionary = {"oxygen": Lang.t("Oxígeno"), "energy": Lang.t("Energía"), "food": Lang.t("Comida"), "water": Lang.t("Agua"), "shield": Lang.t("Escudo"), "morale": Lang.t("Moral")}
	var lx: float = area.position.x + 2.0
	for k in game.NAMES:
		c.draw_rect(Rect2(Vector2(lx, 7.0), Vector2(10.0, 4.0)), game.bar_colors[k])
		c.draw_string(font, Vector2(lx + 13.0, 12.0), short[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.88, 1.0))
		lx += 66.0


func _build_stats() -> void:
	var made: Array = _overlay(Lang.t("Estadísticas"), 860.0)
	stats_overlay = made[0]
	var v: VBoxContainer = made[1]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	stats_text = _rich(390)
	stats_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(stats_text)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	hb.add_child(right)
	right.add_child(_lbl(Lang.t("Recursos por día"), 18, Color(0.6, 0.85, 1.0)))
	stats_chart = make_chart(300.0)
	right.add_child(stats_chart)
	v.add_child(_btn(Lang.t("Cerrar (Esc)"), close_stats))


func open_stats() -> void:
	stats_text.text = stats_bbcode()
	stats_chart.queue_redraw()
	stats_overlay.visible = true
	game._overlay_opened()


func close_stats() -> void:
	stats_overlay.visible = false
	game._overlay_closed()


# ---------- aprende (datos NASA + lección de supervivencia) ----------
# Las preguntas son conocimiento general muy difundido; las cifras son aproximadas
# y estan listadas en DATOS.md con la fuente a verificar.

var QUIZ: Array = [
	{"q": Lang.t("¿Cuánto dura aproximadamente la noche en la Luna (en días terrestres)?"),
	 "o": [Lang.t("Unas 12 horas"), Lang.t("Unos 14 días"), Lang.t("Unos 90 días")], "a": 1,
	 "e": Lang.t("Un día lunar completo dura ~29,5 días terrestres: ~14 de luz y ~14 de oscuridad. Sin sol, los paneles no producen: por eso necesitas energía almacenada.")},
	{"q": Lang.t("¿Por qué la radiación solar es un riesgo mayor en la Luna que en la Tierra?"),
	 "o": [Lang.t("La Luna está más cerca del Sol que de la Tierra"), Lang.t("No tiene atmósfera densa ni campo magnético global que la frene"), Lang.t("Porque el polvo lunar es radiactivo")], "a": 1,
	 "e": Lang.t("La Tierra se protege con su atmósfera y su magnetosfera. En la Luna las partículas de las erupciones solares llegan casi sin freno: de ahí el escudo anti-radiación del juego.")},
	{"q": Lang.t("¿De qué está compuesta en su mayor parte la atmósfera de Marte?"),
	 "o": [Lang.t("Dióxido de carbono"), Lang.t("Oxígeno"), Lang.t("Nitrógeno puro")], "a": 0,
	 "e": Lang.t("Es sobre todo CO₂ y muy delgada. El experimento MOXIE del rover Perseverance produjo oxígeno a partir de ese CO₂: una idea clave para respirar en Marte.")},
	{"q": Lang.t("¿Cuánto dura aproximadamente un día marciano (un «sol»)?"),
	 "o": [Lang.t("Unas 24 h 40 min"), Lang.t("Unas 12 horas"), Lang.t("Unas 30 horas")], "a": 0,
	 "e": Lang.t("Un sol dura ~24 h 39 min: parecido al día terrestre, lo que ayuda a mantener rutinas de sueño. (Cifra aproximada; verifícala en una fuente de la NASA.)")},
	{"q": Lang.t("¿Dónde se ha detectado hielo de agua en la Luna?"),
	 "o": [Lang.t("En cráteres de los polos que casi nunca reciben luz solar"), Lang.t("En el ecuador, bajo el sol directo"), Lang.t("En ningún lugar: la Luna es completamente seca")], "a": 0,
	 "e": Lang.t("La misión LCROSS (2009) detectó agua al impactar en un cráter polar en sombra permanente. Por eso las bases lunares se plantean cerca de los polos. Estudios posteriores siguen refinando cuánta hay.")},
	{"q": Lang.t("En 2018 una tormenta de polvo global en Marte terminó la misión del rover Opportunity. ¿Por qué?"),
	 "o": [Lang.t("El polvo bloqueó la luz solar que alimentaba sus paneles"), Lang.t("El polvo congeló sus ruedas"), Lang.t("Se quedó sin comunicaciones por una erupción solar")], "a": 0,
	 "e": Lang.t("Con el cielo oscurecido sus paneles solares no recargaron las baterías y el contacto se perdió. Es lo que reproduce el juego: tormenta de polvo = menos energía (usa el filtro y administra la batería).")},
	{"q": Lang.t("En la Estación Espacial Internacional, ¿qué se hace con el agua usada (sudor, orina, humedad)?"),
	 "o": [Lang.t("Se tira al espacio"), Lang.t("Se recicla en gran parte para volver a beberla"), Lang.t("Se guarda sin tratar")], "a": 1,
	 "e": Lang.t("El sistema de soporte vital recupera la gran mayoría del agua (la NASA ha comunicado cifras cercanas al 98 %; verifica la cifra actual). Es el modelo de tu acción «Reciclar agua».")},
	{"q": Lang.t("Una erupción solar intensa se aproxima. ¿Cuál es la mejor estrategia?"),
	 "o": [Lang.t("Salir a recolectar rápido antes de que llegue"), Lang.t("Permanecer dentro con el escudo alto y avisar a la tripulación"), Lang.t("Apagar todo el soporte vital para ahorrar energía")], "a": 1,
	 "e": Lang.t("Quedarse en la zona mejor protegida es lo recomendado en la exploración espacial. En el juego: no salgas (EVA) y mantén el escudo anti-radiación por encima de 30.")}
]


func _build_learn() -> void:
	var made: Array = _overlay(Lang.t("Aprende · datos de la NASA"), 860.0)
	learn_overlay = made[0]
	var v: VBoxContainer = made[1]
	v.add_child(_lbl(Lang.t("Foto astronómica del día (APOD, api.nasa.gov)"), 16, Color(1.0, 0.9, 0.6)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	learn_img = TextureRect.new()
	learn_img.custom_minimum_size = Vector2(260, 140)
	learn_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	learn_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(learn_img)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	learn_title = _lbl("", 18, Color(0.85, 0.95, 1.0))
	col.add_child(learn_title)
	learn_meta = _lbl("", 13, Color(0.65, 0.75, 0.9))
	col.add_child(learn_meta)
	learn_text = _rich(84)
	col.add_child(learn_text)
	learn_status = _lbl("", 13, Color(0.7, 0.85, 1.0))
	v.add_child(learn_status)
	var kr := HBoxContainer.new()
	kr.add_theme_constant_override("separation", 8)
	v.add_child(kr)
	kr.add_child(_lbl(Lang.t("Tu clave de api.nasa.gov (gratis; vacía = DEMO_KEY):"), 13, Color(0.75, 0.82, 0.95)))
	learn_key = LineEdit.new()
	learn_key.custom_minimum_size = Vector2(230, 0)
	learn_key.secret = false
	learn_key.placeholder_text = "DEMO_KEY"
	kr.add_child(learn_key)
	kr.add_child(_btn(Lang.t("Guardar y actualizar"), _learn_save_key, 34.0))
	v.add_child(_hline())
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 8)
	v.add_child(qh)
	qh.add_child(_lbl(Lang.t("Lección de supervivencia (sin conexión · +2 moral, 1 vez/día)"), 16, Color(1.0, 0.9, 0.6)))
	quiz_q = _lbl("", 16)
	v.add_child(quiz_q)
	for i in 3:
		var b: Button = _btn("", _quiz_pick.bind(i), 30.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		quiz_btns.append(b)
		v.add_child(b)
	quiz_fb = _rich(64)
	v.add_child(quiz_fb)
	quiz_next = _btn(Lang.t("Siguiente"), _quiz_next, 30.0)
	qh.add_child(quiz_next)
	qh.add_child(_btn(Lang.t("Cerrar"), close_learn, 30.0))


func open_learn() -> void:
	learn_key.text = "" if game.nasa_key == "DEMO_KEY" else game.nasa_key
	quiz_i = game.learn_correct % QUIZ.size()
	_quiz_show()
	_learn_refresh()
	if not game.nasa.is_connected("updated", _learn_refresh):
		game.nasa.connect("updated", _learn_refresh)
	game.nasa.call("fetch", false)
	learn_overlay.visible = true
	game._overlay_opened()


func close_learn() -> void:
	if not learn_overlay.visible:
		return
	learn_overlay.visible = false
	game._overlay_closed()


func _learn_save_key() -> void:
	var k: String = learn_key.text.strip_edges()
	game.nasa_key = k if k != "" else "DEMO_KEY"
	game.nasa.set("key", game.nasa_key)
	game._save_settings()
	game.nasa.call("fetch", true)


func _learn_refresh() -> void:
	var d: Dictionary = game.nasa.get("data")
	var st: String = str(game.nasa.get("status"))
	if d.is_empty():
		learn_title.text = Lang.t("(Sin datos todavía)")
		learn_meta.text = ""
		learn_text.text = Lang.t("Si hay conexión, aquí aparecerá la imagen astronómica del día publicada por la NASA. Mientras tanto puedes practicar con la lección de abajo.")
	else:
		learn_title.text = str(d.get("title", ""))
		var cr: String = str(d.get("copyright", ""))
		learn_meta.text = Lang.t("Fecha APOD: %s%s") % [str(d.get("date", "")), ("  ·  © " + cr.strip_edges()) if cr != "" else ""]
		var ex: String = str(d.get("explanation", ""))
		if ex.length() > 380:
			ex = ex.substr(0, 380).strip_edges() + "…"
		learn_text.text = ex.replace("[", "[lb]") + Lang.t("\n[i](Texto original de la NASA, en inglés.)[/i]")
	learn_img.texture = game.nasa.get("tex")
	learn_status.text = Lang.t("Estado: %s — %s") % [{"idle": Lang.t("en espera"), "loading": "descargando", "ok": Lang.t("datos nuevos"), "cached": Lang.t("datos guardados"), "error": Lang.t("sin datos")}.get(st, st), str(game.nasa.get("message"))]


func _quiz_show() -> void:
	var q: Dictionary = QUIZ[quiz_i]
	quiz_done = false
	quiz_q.text = "%d/%d  %s" % [quiz_i + 1, QUIZ.size(), str(q["q"])]
	for i in 3:
		var b: Button = quiz_btns[i]
		b.text = "%s) %s" % [["A", "B", "C"][i], str(q["o"][i])]
		b.disabled = false
	quiz_fb.text = ""
	quiz_next.disabled = true


func _quiz_pick(i: int) -> void:
	if quiz_done:
		return
	quiz_done = true
	var q: Dictionary = QUIZ[quiz_i]
	for b in quiz_btns:
		(b as Button).disabled = true
	if i == int(q["a"]):
		var bonus: String = ""
		if game.learned_day != game.day and game.playing:
			game.learned_day = game.day
			game._add("morale", 2.0)
			game.learn_correct += 1
			game._refresh()
			game._log(Lang.t("[color=cyan]Sesión de aprendizaje: la tripulación repasa datos reales (+2 moral).[/color]"))
			bonus = Lang.t("  [b](+2 moral)[/b]")
		game._sfx("good")
		quiz_fb.text = Lang.t("[color=lightgreen][b]¡Correcto!%s[/b][/color] %s") % [bonus, str(q["e"])]
	else:
		game._sfx("error")
		quiz_fb.text = Lang.t("[color=orange][b]No exactamente.[/b][/color] Respuesta: %s) %s. %s") % [["A", "B", "C"][int(q["a"])], str(q["o"][int(q["a"])]), str(q["e"])]
	quiz_next.disabled = false


func _quiz_next() -> void:
	quiz_i = (quiz_i + 1) % QUIZ.size()
	_quiz_show()
