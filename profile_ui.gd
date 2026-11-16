extends Control
# v35 — Pantallas de perfil (sistema de diseno DS). Usa profiles.gd; no cambia la logica del juego.
#  choose  -> ¿Quien juega? (perfiles de este dispositivo + educativa / personal / invitado)
#  email   -> correo (educativa o personal)
#  role    -> estudiante o docente (cuenta educativa)
#  teacher -> datos del docente y aviso de verificacion pendiente
#  account -> perfil activo: clases (unirse / crear), cambiar de perfil, cerrar sesion
#  newclass-> el docente elige misiones y obtiene un codigo de clase

const DS = preload("res://design_system.gd")
const LessonData = preload("res://lesson_data.gd")
const UiScreens = preload("res://ui_screens.gd")
const Profiles = preload("res://profiles.gd")

var game = null
var prof: Node = null
var card: PanelContainer = null
var body: VBoxContainer = null
var pending_type: String = ""
var pending_email: String = ""
var msg: Label = null


func setup(g, p: Node) -> void:
	game = g
	prof = p
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	var dim := ColorRect.new()
	dim.color = Color(DS.C_BG, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	var sb: StyleBoxFlat = DS.card(2, DS.R_LG, 0.98)
	sb.content_margin_left = DS.S5
	sb.content_margin_right = DS.S5
	sb.content_margin_top = DS.S4
	sb.content_margin_bottom = DS.S4
	card.add_theme_stylebox_override("panel", sb)
	cc.add_child(card)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", DS.S2)
	card.add_child(body)
	visible = false


# ---------- utilidades ----------

func _clear() -> void:
	for c in body.get_children():
		c.queue_free()
	msg = null


func _title(cap: String, t: String) -> void:
	if cap != "":
		body.add_child(DS.caption(cap))
	body.add_child(DS.label(t, DS.F_H1, DS.C_TEXT, "SemiBold"))


func _btn(text: String, cb: Callable, primary: bool = false, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if icon_name != "" else HORIZONTAL_ALIGNMENT_CENTER
	if icon_name != "":
		b.icon = DS.icon(icon_name, 20, DS.C_ACCENT if primary else DS.C_DIM)
	if primary:
		b.add_theme_stylebox_override("normal", DS.box(Color(DS.C_ACCENT, 0.18), Color(DS.C_ACCENT, 0.7), 1, DS.R_MD, DS.S4, DS.S2))
		b.add_theme_stylebox_override("hover", DS.box(Color(DS.C_ACCENT, 0.28), DS.C_ACCENT, 1, DS.R_MD, DS.S4, DS.S2))
	b.pressed.connect(cb)
	return b


func _option(icon_name: String, title: String, desc: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 66)
	b.add_theme_stylebox_override("normal", DS.card(1, DS.R_MD, 0.95))
	var hv: StyleBoxFlat = DS.card(2, DS.R_MD, 1.0)
	hv.border_color = DS.C_ACCENT
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("focus", hv)
	b.pressed.connect(cb)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", DS.S3)
	m.add_theme_constant_override("margin_right", DS.S3)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", DS.S3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var ic: TextureRect = DS.icon_rect(icon_name, 24, DS.C_ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t: Label = DS.label(title, 16, DS.C_TEXT, "SemiBold")
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d: Label = DS.label(desc, 13, DS.C_DIM)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	return b


func _input_line(ph: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.custom_minimum_size = Vector2(0, 42)
	e.add_theme_stylebox_override("normal", DS.box(DS.C_SURF1, DS.C_LINE_HI, 1, DS.R_MD, DS.S3, DS.S2))
	e.add_theme_stylebox_override("focus", DS.box(DS.C_SURF1, DS.C_ACCENT, 2, DS.R_MD, DS.S3, DS.S2))
	return e


func _msg_line() -> void:
	msg = DS.label("", 13, DS.C_WARN)
	msg.visible = false
	body.add_child(msg)


func _say(t: String, ok: bool = false) -> void:
	if msg != null:
		msg.text = t
		msg.add_theme_color_override("font_color", DS.C_GOOD if ok else DS.C_WARN)
		msg.visible = true


func _open() -> void:
	visible = true
	DS.fade_in(card, DS.T_BASE, 0.0)


func close() -> void:
	visible = false
	var ui = game.get("ui")
	if ui != null:
		ui.call("refresh_profile")


# ---------- ¿quien juega? ----------

func show_choose() -> void:
	_clear()
	_title(Lang.t("Perfil"), Lang.t("¿Quién juega?"))
	if not prof.list.is_empty():
		body.add_child(DS.caption(Lang.t("En este dispositivo")))
		for id in prof.list:
			var p: Dictionary = prof.list[id]
			var kind: String = Lang.t("Personal")
			if str(p["type"]) == "edu":
				kind = Lang.t("Docente") if str(p["role"]) == "teacher" else Lang.t("Estudiante")
			body.add_child(_option("crew", str(p["email"]), kind, _pick.bind(str(id))))
		body.add_child(HSeparator.new())
		body.add_child(DS.caption(Lang.t("Nuevo perfil")))
	body.add_child(_option("book", Lang.t("Cuenta educativa"), Lang.t("Para clase: estudiante o docente."), _ask_email.bind("edu")))
	body.add_child(_option("crew", Lang.t("Cuenta personal"), Lang.t("Para jugar en casa con tu propio guardado."), _ask_email.bind("personal")))
	body.add_child(_option("play", Lang.t("Jugar como invitado"), Lang.t("Sin correo. La partida se borra al cerrar el juego."), _guest))
	body.add_child(UiScreens.hint(Lang.t("Los perfiles se guardan solo en este dispositivo. Pide ayuda a un adulto para usar tu correo.")))
	_open()


func _pick(id: String) -> void:
	prof.call("activate", id)
	close()


func _guest() -> void:
	prof.call("create", "guest", "")
	close()


# ---------- correo ----------

func _ask_email(type: String) -> void:
	pending_type = type
	_clear()
	_title(Lang.t("Cuenta educativa") if type == "edu" else Lang.t("Cuenta personal"), Lang.t("Escribe tu correo"))
	var e: LineEdit = _input_line(Lang.t("nombre@escuela.edu") if type == "edu" else Lang.t("nombre@gmail.com"))
	e.name = "Email"
	body.add_child(e)
	if type == "edu":
		body.add_child(UiScreens.hint(Lang.t("Usa el correo que te dio tu escuela.")))
	_msg_line()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S2)
	body.add_child(row)
	var back: Button = _btn(Lang.t("Volver"), show_choose)
	row.add_child(back)
	var go: Button = _btn(Lang.t("Continuar"), _email_ok.bind(e), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	e.text_submitted.connect(func(_t: String) -> void: _email_ok(e))
	_open()
	e.grab_focus.call_deferred()


func _email_ok(e: LineEdit) -> void:
	var t: String = e.text.strip_edges()
	if not Profiles.valid_email(t):
		_say(Lang.t("Ese correo no parece válido. Revisa que tenga @ y un dominio (por ejemplo: nombre@gmail.com)."))
		return
	pending_email = t
	if pending_type == "edu":
		_ask_role()
	else:
		prof.call("create", "personal", t)
		close()


# ---------- rol (cuenta educativa) ----------

func _ask_role() -> void:
	_clear()
	_title(pending_email, Lang.t("¿Eres estudiante o docente?"))
	body.add_child(_option("crew", Lang.t("Estudiante"), Lang.t("Únete a las clases de tu docente con un código."), _student))
	body.add_child(_option("book", Lang.t("Docente"), Lang.t("Crea clases eligiendo misiones. Requiere verificación."), _teacher_form))
	body.add_child(_btn(Lang.t("Volver"), _ask_email.bind("edu")))
	_open()


func _student() -> void:
	prof.call("create", "edu", pending_email, "student")
	show_account()


func _teacher_form() -> void:
	_clear()
	_title(Lang.t("Docente"), Lang.t("Solicitud de verificación"))
	var n: LineEdit = _input_line(Lang.t("Tu nombre"))
	body.add_child(n)
	var s: LineEdit = _input_line(Lang.t("Escuela o institución"))
	body.add_child(s)
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", DS.status_card("warn"))
	note.add_child(DS.label(Lang.t("Tu cuenta quedará «pendiente de verificación». El envío automático de la solicitud al administrador todavía no está activo: necesita un servidor que aún no existe. Mientras tanto puedes preparar clases en modo de prueba."), 13, DS.C_TEXT))
	body.add_child(note)
	_msg_line()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S2)
	body.add_child(row)
	row.add_child(_btn(Lang.t("Volver"), _ask_role))
	var go: Button = _btn(Lang.t("Enviar solicitud"), func() -> void:
		if n.text.strip_edges().length() < 2 or s.text.strip_edges().length() < 2:
			_say(Lang.t("Escribe tu nombre y tu escuela."))
			return
		prof.call("create", "edu", pending_email, "teacher", {"name": n.text.strip_edges(), "school": s.text.strip_edges()})
		show_account(), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	_open()


# ---------- cuenta activa ----------

func show_account() -> void:
	if prof.current.is_empty():
		show_choose()
		return
	_clear()
	var p: Dictionary = prof.current
	_title(Lang.t("Perfil"), str(prof.call("label")))
	if prof.call("is_guest"):
		body.add_child(UiScreens.hint(Lang.t("Modo invitado: tu partida se borra al cerrar el juego. Para guardarla, crea una cuenta personal.")))
	elif str(p["type"]) == "personal":
		body.add_child(UiScreens.hint(Lang.t("Tu partida se guarda en este dispositivo. Continuar en otro dispositivo (web o APK) necesitará un servidor que aún no existe.")))
	if prof.call("is_teacher"):
		var st: String = str(p.get("teacher_status", "pending"))
		var chip: Control = UiScreens.chip(Lang.t("Verificado") if st == "verified" else Lang.t("Pendiente de verificación"), "good" if st == "verified" else "warn")
		body.add_child(chip)
		body.add_child(DS.caption(Lang.t("Mis clases")))
		_class_list(p, false)
		body.add_child(_btn(Lang.t("Crear clase"), show_new_class, true, "map"))
	elif prof.call("is_student"):
		body.add_child(DS.caption(Lang.t("Mis clases")))
		_class_list(p, true)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", DS.S2)
		body.add_child(row)
		var e: LineEdit = _input_line(Lang.t("Código de clase (PER-XXXX)"))
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(e)
		row.add_child(_btn(Lang.t("Unirme"), func() -> void:
			if prof.call("join_class", e.text):
				show_account()
			else:
				_say(Lang.t("Código no válido. Revisa que esté bien escrito (por ejemplo: PER-3K7M)."))
			, true))
		_msg_line()
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", DS.S2)
	body.add_child(row2)
	row2.add_child(_btn(Lang.t("Cambiar de perfil"), func() -> void:
		prof.call("sign_out")
		show_choose()))
	var ok: Button = _btn(Lang.t("Listo"), close, true)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(ok)
	_open()


func _class_list(p: Dictionary, student: bool) -> void:
	var cls: Array = p.get("classes", [])
	if cls.is_empty():
		body.add_child(UiScreens.hint(Lang.t("Todavía no hay clases.")))
		return
	for code in cls:
		var ms: Array = Profiles.read_code(str(code))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", DS.S2)
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", DS.card(1, DS.R_MD, 0.9))
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t: Label = DS.label("%s · %s" % [str(code), Lang.t("%d misiones") % ms.size()], 14, DS.C_TEXT, "Medium")
		pc.add_child(t)
		row.add_child(pc)
		var x: Button = _btn(Lang.t("Quitar"), func() -> void:
			prof.call("leave_class", str(code))
			show_account())
		row.add_child(x)
		body.add_child(row)


# ---------- crear clase (docente) ----------

func show_new_class() -> void:
	_clear()
	_title(Lang.t("Docente"), Lang.t("Crear clase"))
	body.add_child(UiScreens.hint(Lang.t("Elige las misiones de la clase. Obtendrás un código para compartir con tus estudiantes.")))
	var checks: Array = []
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DS.S3)
	body.add_child(grid)
	for i in LessonData.MISSIONS.size():
		var m: Dictionary = LessonData.MISSIONS[i]
		var c := CheckBox.new()
		c.text = "%s · %s" % [Lang.loc(str(m["loc"])), Lang.t(str(m["title"]))]
		c.add_theme_font_size_override("font_size", 13)
		grid.add_child(c)
		checks.append(c)
	var out: Label = DS.label("", DS.F_H1, DS.C_ACCENT, "SemiBold")
	out.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	out.visible = false
	body.add_child(out)
	_msg_line()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S2)
	body.add_child(row)
	row.add_child(_btn(Lang.t("Volver"), show_account))
	var go: Button = _btn(Lang.t("Generar código"), func() -> void:
		var sel: Array = []
		for i in checks.size():
			if (checks[i] as CheckBox).button_pressed:
				sel.append(i)
		if sel.is_empty():
			_say(Lang.t("Elige al menos una misión."))
			return
		var code: String = Profiles.make_code(sel)
		prof.call("add_teacher_class", code)
		out.text = code
		out.visible = true
		DisplayServer.clipboard_set(code)
		_say(Lang.t("Código creado. Compártelo con tus estudiantes (se intentó copiar al portapapeles)."), true), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	_open()
