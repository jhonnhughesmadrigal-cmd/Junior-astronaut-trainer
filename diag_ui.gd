extends Control
# Centro de diagnostico (v26): alertas, lecturas, hipotesis, intervenciones, mantenimiento e historial de incidentes.
# La logica esta en emergency.gd; aqui solo se dibuja y se llama al gestor. Teclado: [Tab] cambia de pestana, [Esc] o [H] cierran.
# Los botones se manejan con el raton o con las flechas y [Enter].

signal closed

const Data = preload("res://emergency_data.gd")
const C_OK: String = "#7cf59b"
const C_WARN: String = "#ffd166"
const C_BAD: String = "#ff6b6b"
const C_DIM: String = "#9aa7c7"
const C_ACC: String = "#7fb2ff"

var game: Node = null
var tab: int = 0              # 0 alertas, 1 sistemas, 2 historial
var sel_id: int = -1          # incidente elegido (-2 = informe pendiente)
var hist_sel: int = -1
var msg: String = ""          # mensaje de la ultima accion (bbcode)
var panel: PanelContainer = null
var title_lbl: Label = null
var tab_btns: Array = []
var content: VBoxContainer = null
var scroll: ScrollContainer = null
var foot: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	var st: StyleBoxFlat = game._panel_style()
	st.border_color = Color(0.35, 0.55, 0.95)
	st.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	for i in 3:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 34)
		b.pressed.connect(_set_tab.bind(i))
		head.add_child(b)
		tab_btns.append(b)
	var cb := Button.new()
	cb.text = "X"
	cb.custom_minimum_size = Vector2(40, 34)
	cb.pressed.connect(close)
	head.add_child(cb)
	v.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	foot = Label.new()
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", Color(0.6, 0.66, 0.8))
	v.add_child(foot)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if panel == null:
		return
	var w: float = minf(1180.0, size.x - 30.0)
	var h: float = minf(680.0, size.y - 30.0)
	panel.position = Vector2((size.x - w) / 2.0, (size.y - h) / 2.0)
	panel.size = Vector2(w, h)
	panel.custom_minimum_size = Vector2(w, h)


# ---------------------------------------------------------------- abrir y cerrar

func open(inc_id: int = -1) -> void:
	_layout()
	tab = 0
	msg = ""
	var emg: RefCounted = game.emg
	if not (emg.report as Dictionary).is_empty():
		sel_id = -2
	elif inc_id >= 0 and not (emg.find(inc_id) as Dictionary).is_empty():
		sel_id = inc_id
	elif sel_id < 0 or (emg.find(sel_id) as Dictionary).is_empty():
		sel_id = int(emg.active[0]["id"]) if not emg.active.is_empty() else -1
	visible = true
	render()


func close() -> void:
	visible = false
	closed.emit()


func handle_key(k: InputEventKey) -> void:
	if k.keycode == KEY_TAB:
		_set_tab((tab + 1) % 3)
		get_viewport().set_input_as_handled()


func _set_tab(i: int) -> void:
	tab = i
	msg = ""
	render()


# ---------------------------------------------------------------- constructores de interfaz

func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()


func _rt(bb: String, fs: int = 16) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.text = bb
	return r


func _btn(text: String, cb: Callable, h: float = 38.0) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _sec(text: String) -> RichTextLabel:
	return _rt("[color=%s][b]%s[/b][/color]" % [C_ACC, text.to_upper()], 15)


func _col(s: String) -> String:
	match s:
		"ok":
			return C_OK
		"bad":
			return C_BAD
	return C_WARN


func _fmt_time(day: int, clock: int) -> String:
	return Lang.t("Día %d, %02d:%02d") % [day, floori(float(clock) / 60.0), clock % 60]


func _bar(val: float, w: int = 14) -> String:
	var n: int = clampi(int(round(val / 100.0 * float(w))), 0, w)
	return "█".repeat(n) + "░".repeat(w - n)


# ---------------------------------------------------------------- render

func render() -> void:
	if content == null:
		return
	var emg: RefCounted = game.emg
	title_lbl.text = Lang.t("CENTRO DE DIAGNÓSTICO") + "   " + game._clock_text()
	var names: Array = [Lang.t("Alertas"), Lang.t("Sistemas"), Lang.t("Historial")]
	for i in 3:
		(tab_btns[i] as Button).text = names[i] + ((" (%d)" % emg.active.size()) if i == 0 and not emg.active.is_empty() else "")
		(tab_btns[i] as Button).button_pressed = (i == tab)
	foot.text = Lang.t("[Tab] cambiar de pestaña   [Esc] o [%s] cerrar   Los valores de las lecturas son de simulación y reflejan el estado real de la base.") % game.key_name("diag")
	_clear()
	match tab:
		0:
			_render_alerts()
		1:
			_render_systems()
		_:
			_render_history()
	call_deferred("_focus_first")
	scroll.scroll_vertical = 0


func _focus_first() -> void:
	if not visible:
		return
	var b: Button = _first_button(content)
	if b != null and is_instance_valid(b):
		b.grab_focus()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and not (c as Button).disabled:
			return c as Button
		var r: Button = _first_button(c)
		if r != null:
			return r
	return null


# ----- pestana 0: alertas

func _render_alerts() -> void:
	var emg: RefCounted = game.emg
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	left.add_child(_sec(Lang.t("Incidentes activos")))
	if not (emg.report as Dictionary).is_empty():
		var rb: Button = _btn(Lang.t("Informe: ") + str(emg.report["name"]), _pick.bind(-2))
		rb.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		left.add_child(rb)
	if emg.active.is_empty():
		left.add_child(_rt("[color=%s]%s[/color]" % [C_DIM, Lang.t("No hay incidentes activos. Los sistemas funcionan con normalidad.")], 15))
	for inc in emg.active:
		var star: String = "★".repeat(int(inc["sev"]))
		var b: Button = _btn("%s  %s" % [star, emg.name_of(inc)], _pick.bind(int(inc["id"])), 44)
		b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5) if int(inc["id"]) == sel_id else Color(1.0, 0.85, 0.5))
		left.add_child(b)
	if sel_id == -2 and not (emg.report as Dictionary).is_empty():
		_render_report(right, emg.report)
		return
	var inc: Dictionary = emg.find(sel_id)
	if inc.is_empty():
		right.add_child(_rt("[color=%s]%s[/color]" % [C_DIM, Lang.t("Cuando algo falle, la alerta aparecerá aquí. También puedes revisar el estado de la base en la pestaña Sistemas y hacer mantenimiento preventivo para evitar averías.")], 16))
		return
	_render_incident(right, inc)


func _pick(id: int) -> void:
	sel_id = id
	msg = ""
	render()


func _render_incident(box: VBoxContainer, inc: Dictionary) -> void:
	var emg: RefCounted = game.emg
	var kd: Dictionary = Data.kind_def(str(inc["kind"]))
	var kind: String = str(inc["kind"])
	box.add_child(_rt("[color=%s][b]⚠ %s[/b][/color]" % [C_BAD, Lang.t(str(kd["alert"]))], 20))
	var meta: String = Lang.t("%s  ·  Sistema: %s  ·  Gravedad: %s  ·  Detectada: %s") % [emg.name_of(inc), Lang.t(str(Data.SYS_NAMES.get(str(inc["sys"]), ""))), "★".repeat(int(inc["sev"])), _fmt_time(int(inc["day"]), int(inc["clock"]))]
	var rem: int = emg.remaining(inc)
	if rem >= 0 and (emg.is_env(inc) or kind == "medical"):
		meta += "  ·  " + Lang.t("Tiempo restante: %s") % str(game._fmt_dur(rem))
	box.add_child(_rt("[color=%s]%s[/color]" % [C_DIM, meta], 14))
	# pasos
	var labels: Array = [Lang.t("Alerta"), Lang.t("Investigar"), Lang.t("Diagnóstico"), Lang.t("Intervención")]
	if emg.is_env(inc):
		labels = [Lang.t("Alerta"), Lang.t("Investigar"), Lang.t("Preparar"), Lang.t("Impacto")]
	var si: int = emg.state_index(inc)
	if emg.is_env(inc):
		si = 2 if (inc["consulted"] as Array).size() > 0 else (1 if str(inc["state"]) != "detected" else 0)
		if float(inc["mit"]) < 1.0:
			si = 3
	var bar: String = ""
	for i in labels.size():
		var on: bool = i <= si
		bar += "[color=%s]%s %s[/color]   " % [C_OK if on else C_DIM, "●" if on else "○", labels[i]]
	box.add_child(_rt(bar, 15))
	box.add_child(_rt(Lang.t(str(kd["intro"])), 16))
	if msg != "":
		box.add_child(_rt(msg, 16))
	# instrumentos
	var cost: int = int(Data.CONSULT_MINS[emg.diff_i()])
	box.add_child(_sec(Lang.t("Instrumentos") + ("  (%s)" % (Lang.t("cada consulta cuesta %d min") % cost) if cost > 0 else "")))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(flow)
	for key in (kd["instr"] as Array):
		var done: bool = (inc["consulted"] as Array).has(key)
		var b: Button = Button.new()
		b.text = ("✔ " if done else "") + Lang.t(str(Data.INSTR[key]))
		b.custom_minimum_size = Vector2(0, 36)
		b.pressed.connect(_on_consult.bind(int(inc["id"]), str(key)))
		flow.add_child(b)
	for key in (inc["consulted"] as Array):
		if str(key).begins_with("done_"):
			continue
		var bb: String = "[b]%s[/b]\n" % Lang.t(str(Data.INSTR[key]))
		for ln in emg.readings(inc, str(key)):
			bb += "[color=%s]• %s[/color]\n" % [_col(str(ln["s"])), str(ln["t"])]
		box.add_child(_rt(bb.strip_edges(), 15))
	if kind != "medical" and not bool(inc["advised"]):
		box.add_child(_btn(Lang.t("Pedir consejo a %s (10 min)") % str(kd["owner"]), _on_advice.bind(int(inc["id"])), 34))
	elif kind != "medical":
		box.add_child(_rt("[color=%s]%s[/color]" % [C_ACC, Lang.t(str(kd["advice"]))], 15))
	# diagnostico
	if emg.has_diag_step(inc):
		box.add_child(_sec(Lang.t("Diagnóstico: ¿cuál es la causa?")))
		if str(inc["diag"]) != "":
			box.add_child(_rt("[color=%s]✔ %s[/color]" % [C_OK, emg.hyp_text(inc, str(inc["diag"]))], 16))
		elif not emg.can_diagnose(inc):
			var n: int = (inc["consulted"] as Array).size()
			box.add_child(_rt("[color=%s]%s[/color]" % [C_WARN, Lang.t("Consulta al menos %d instrumentos antes de elegir una causa (llevas %d). Las lecturas deben respaldar tu decisión.") % [emg.steps_needed(inc), n]], 15))
		else:
			box.add_child(_rt("[color=%s]%s[/color]" % [C_DIM, Lang.t("Elige la causa que mejor explican las lecturas. Una hipótesis equivocada cuesta tiempo.")], 14))
			for hid in (inc["hyps"] as Array):
				var wrong: bool = (inc["wrong"] as Array).has(hid)
				var hb: Button = _btn(("✘ " if wrong else "") + emg.hyp_text(inc, str(hid)), _on_hyp.bind(int(inc["id"]), str(hid)), 40)
				hb.disabled = wrong
				box.add_child(hb)
	# intervencion
	if emg.can_intervene(inc):
		box.add_child(_sec(Lang.t("Intervención") if not emg.is_env(inc) else Lang.t("Preparación")))
		for iv in emg.ivs(inc):
			box.add_child(_iv_row(inc, iv))
	elif emg.has_diag_step(inc):
		box.add_child(_rt("[color=%s]%s[/color]" % [C_DIM, Lang.t("Las opciones de intervención aparecerán cuando identifiques la causa.")], 14))


func _iv_row(inc: Dictionary, iv: Dictionary) -> Control:
	var emg: RefCounted = game.emg
	var mins: int = emg.iv_mins(inc, iv)
	var line: String = "%s\n%s  ·  %s" % [Lang.t(str(iv["n"])), Lang.t(str(iv["d"])) if str(iv.get("d", "")) != "" else "", Lang.t("Tiempo: %s") % str(game._fmt_dur(mins)) if mins > 0 else Lang.t("Sin tiempo de trabajo")]
	var miss: String = emg.needs_text(iv)
	if miss != "":
		line += "\n" + Lang.t("Te falta: %s") % miss
	var b: Button = _btn(line, _on_iv.bind(int(inc["id"]), str(iv["id"])), 66)
	if miss != "":
		b.add_theme_color_override("font_color", Color(1.0, 0.7, 0.65))
	return b


# ----- acciones

func _on_consult(id: int, key: String) -> void:
	var inc: Dictionary = game.emg.find(id)
	if inc.is_empty():
		return
	game.emg.consult(inc, key)
	msg = ""
	_after_action()


func _on_advice(id: int) -> void:
	var inc: Dictionary = game.emg.find(id)
	if inc.is_empty():
		return
	game.emg.ask_advice(inc)
	_after_action()


func _on_hyp(id: int, hid: String) -> void:
	var inc: Dictionary = game.emg.find(id)
	if inc.is_empty():
		return
	var r: Dictionary = game.emg.choose_hyp(inc, hid)
	if bool(r["ok"]):
		game._sfx("good", -6.0)
		msg = "[color=%s]✔ %s[/color]\n[color=%s]%s[/color]" % [C_OK, Lang.t("¡Diagnóstico correcto!"), C_DIM, str(r["text"])]
	else:
		game._sfx("error")
		var cost: int = int(r.get("mins", 0))
		msg = "[color=%s]✘ %s[/color] %s\n[color=%s]%s[/color]" % [C_BAD, Lang.t("Esa causa no encaja."), (Lang.t("Perdiste %d min.") % cost) if cost > 0 else "", C_DIM, str(r["text"])]
	_after_action()


func _on_iv(id: int, iv_id: String) -> void:
	var inc: Dictionary = game.emg.find(id)
	if inc.is_empty():
		return
	var iv: Dictionary = game.emg.iv_by_id(inc, iv_id)
	var miss: String = game.emg.needs_text(iv)
	if miss != "":
		game._sfx("error")
		msg = "[color=%s]%s[/color]" % [C_BAD, Lang.t("No puedes hacerlo todavía. Te falta: %s") % miss]
		render()
		return
	var err: String = game.call("_emg_start_iv", id, iv_id)
	if err != "":
		game._sfx("error")
		msg = "[color=%s]%s[/color]" % [C_BAD, err]
		render()


func _after_action() -> void:
	if not game.playing or game.mode != 14:
		visible = false
		return
	# un plazo puede haber cerrado el incidente mientras pasaba el tiempo
	if not (game.emg.report as Dictionary).is_empty() and (game.emg.find(sel_id) as Dictionary).is_empty():
		sel_id = -2
	render()


# ----- informe de un incidente cerrado

func _render_report(box: VBoxContainer, e: Dictionary) -> void:
	var res: String = str(e["result"])
	var rc: String = C_OK if res == "resolved" else (C_WARN if res == "partial" else C_BAD)
	var rt: String = {"resolved": Lang.t("RESUELTO"), "partial": Lang.t("RESUELTO PARCIALMENTE"), "failed": Lang.t("NO RESUELTO A TIEMPO")}.get(res, "")
	box.add_child(_rt("[color=%s][b]%s — %s[/b][/color]" % [rc, rt, str(e["name"])], 20))
	if not (e["verify"] as Array).is_empty():
		var vb: String = "[b]%s[/b]\n" % Lang.t("Verificación")
		for ln in (e["verify"] as Array):
			vb += "[color=%s]✔ %s[/color]\n" % [C_OK, str(ln)]
		box.add_child(_rt(vb.strip_edges(), 15))
	_lesson_blocks(box, e["lesson"])
	box.add_child(_btn(Lang.t("Aceptar el informe"), _on_ack, 40))


func _lesson_blocks(box: VBoxContainer, ls: Dictionary) -> void:
	var order: Array = [["what", Lang.t("Qué ocurrió")], ["why", Lang.t("Por qué ocurrió")], ["did", Lang.t("Qué hiciste")], ["learn", Lang.t("Qué aprendiste")], ["tip", Lang.t("Para la próxima misión")]]
	for o in order:
		if str(ls.get(o[0], "")) == "":
			continue
		box.add_child(_rt("[color=%s][b]%s[/b][/color]\n%s" % [C_ACC, str(o[1]).to_upper(), str(ls[o[0]])], 16))


func _on_ack() -> void:
	game.emg.report = {}
	sel_id = int(game.emg.active[0]["id"]) if not game.emg.active.is_empty() else -1
	msg = ""
	render()


# ----- pestana 1: sistemas y mantenimiento

func _pressure_now() -> float:
	var emg: RefCounted = game.emg
	for inc in emg.active:
		if str(inc["kind"]) == "oxygen" and str(inc["cause"]) == "leak":
			return 101.3 - minf(9.0, 1.2 + 0.7 * float(inc["elapsed"]) / 60.0)
	return 101.3


func _render_systems() -> void:
	var emg: RefCounted = game.emg
	var g: Node = game
	content.add_child(_sec(Lang.t("Lecturas de la base (simulación, con datos reales del juego)")))
	var res: Dictionary = g.res
	var temp: float = 22.0 - maxf(0.0, (30.0 - float(res["energy"])) * 0.12)
	var lines: Array = []
	lines.append([Lang.t("Presión: %s kPa") % emg._f1(_pressure_now()), "ok" if _pressure_now() > 98.0 else "bad"])
	lines.append([Lang.t("Oxígeno: %d %%") % int(round(float(res["oxygen"]))), "ok" if float(res["oxygen"]) >= 40.0 else "bad"])
	lines.append([Lang.t("Energía: %d %%") % int(round(float(res["energy"]))), "ok" if float(res["energy"]) >= 40.0 else "bad"])
	lines.append([Lang.t("Agua: %d %%") % int(round(float(res["water"]))), "ok" if float(res["water"]) >= 40.0 else "bad"])
	lines.append([Lang.t("Temperatura interior: %s °C (baja si falta energía para calefacción)") % emg._f1(temp), "ok" if temp > 19.0 else "warn"])
	lines.append([Lang.t("Filtros de aire: %d %%") % int(round(emg.cond("filters"))), emg._cond_status(emg.cond("filters"))])
	var eq: float = (emg.cond("life") + emg.cond("power") + emg.cond("water") + emg.cond("ext")) / 4.0
	lines.append([Lang.t("Estado de los equipos (promedio): %d %%") % int(round(eq)), emg._cond_status(eq)])
	var crew: String = Lang.t("1 tripulante con síntomas") if int(g.ill_days) > 0 else Lang.t("Todos estables")
	lines.append([Lang.t("Tripulantes: %s, moral %d %%") % [crew, int(round(float(res["morale"])))], "warn" if int(g.ill_days) > 0 else "ok"])
	var bb: String = ""
	for l in lines:
		bb += "[color=%s]• %s[/color]\n" % [_col(str(l[1])), str(l[0])]
	content.add_child(_rt(bb.strip_edges(), 16))
	content.add_child(_sec(Lang.t("Mantenimiento preventivo")))
	content.add_child(_rt("[color=%s]%s[/color]" % [C_DIM, Lang.t("Cuanto mejor mantenido está un sistema, menos probable es que falle. El mantenimiento no elimina el riesgo: solo lo reduce. Las estaciones también ayudan un poco al usarlas.")], 14))
	if msg != "":
		content.add_child(_rt(msg, 15))
	for s in Data.SYS_ORDER:
		var c: float = emg.cond(str(s))
		var rk: float = emg.risk(str(s))
		var rl: String = Lang.t("bajo") if rk < 0.85 else (Lang.t("medio") if rk < 1.3 else Lang.t("alto"))
		var rc: String = C_OK if rk < 0.85 else (C_WARN if rk < 1.3 else C_BAD)
		var cost: String = Lang.t("1 polímero") if str(s) == "filters" else Lang.t("1 chatarra")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(row)
		var info: RichTextLabel = _rt("[b]%s[/b]  %s  %d %%\n[color=%s]%s[/color]" % [Lang.t(str(Data.SYS_NAMES[s])), _bar(c), int(round(c)), rc, Lang.t("Riesgo de avería: %s") % rl], 15)
		row.add_child(info)
		var pb: Button = Button.new()
		pb.text = Lang.t("Mantener (45 min, %s)") % cost
		pb.custom_minimum_size = Vector2(250, 40)
		pb.pressed.connect(_on_preventive.bind(str(s)))
		row.add_child(pb)


func _on_preventive(sys: String) -> void:
	var r: String = game.call("_emg_preventive", sys)
	msg = r
	if game.playing and game.mode == 14:
		render()


# ----- pestana 2: historial

func _render_history() -> void:
	var emg: RefCounted = game.emg
	if emg.history.is_empty():
		content.add_child(_rt("[color=%s]%s[/color]" % [C_DIM, Lang.t("Aún no hay incidentes en el historial. Cada emergencia que resuelvas quedará registrada aquí con tu diagnóstico y lo que aprendiste.")], 16))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	left.add_child(_sec(Lang.t("Incidentes anteriores")))
	if hist_sel < 0 or hist_sel >= emg.history.size():
		hist_sel = emg.history.size() - 1
	for i in range(emg.history.size() - 1, -1, -1):
		var e: Dictionary = emg.history[i]
		var mark: String = {"resolved": "✔", "partial": "◐", "failed": "✘"}.get(str(e["result"]), "?")
		var b: Button = _btn("%s  %s\n%s" % [mark, str(e["name"]), _fmt_time(int(e["day"]), int(e["clock"]))], _hist_pick.bind(i), 52)
		if i == hist_sel:
			b.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		left.add_child(b)
	var e2: Dictionary = emg.history[hist_sel]
	var res: String = str(e2["result"])
	var rc: String = C_OK if res == "resolved" else (C_WARN if res == "partial" else C_BAD)
	var rt: String = {"resolved": Lang.t("Resuelto"), "partial": Lang.t("Resuelto parcialmente"), "failed": Lang.t("No resuelto a tiempo")}.get(res, "")
	right.add_child(_rt("[b]%s[/b]" % str(e2["name"]), 20))
	var meta: String = Lang.t("Sistema: %s  ·  Detectada: %s  ·  Cerrada: %s  ·  Gravedad: %s") % [str(e2["sys"]), _fmt_time(int(e2["day"]), int(e2["clock"])), _fmt_time(int(e2["day1"]), int(e2["clock1"])), "★".repeat(int(e2["sev"]))]
	right.add_child(_rt("[color=%s]%s[/color]" % [C_DIM, meta], 14))
	right.add_child(_rt("[color=%s][b]%s[/b][/color]" % [rc, Lang.t("Resultado: %s") % rt], 16))
	var sb: String = "[b]%s[/b]\n" % Lang.t("Síntomas y lecturas")
	for s in (e2["sym"] as Array):
		sb += "• %s\n" % str(s)
	right.add_child(_rt(sb.strip_edges(), 15))
	if not (e2["hyps"] as Array).is_empty():
		var hb: String = "[b]%s[/b]\n" % Lang.t("Hipótesis consideradas")
		for h in (e2["hyps"] as Array):
			var st: String = str(h["s"])
			hb += "[color=%s]%s %s[/color]\n" % [C_OK if st == "ok" else (C_BAD if st == "wrong" else C_DIM), "✔" if st == "ok" else ("✘" if st == "wrong" else "·"), str(h["t"])]
		right.add_child(_rt(hb.strip_edges(), 15))
	if str(e2["diag"]) != "":
		right.add_child(_rt("[b]%s[/b]\n%s" % [Lang.t("Diagnóstico seleccionado"), str(e2["diag"])], 15))
	if str(e2["iv"]) != "":
		right.add_child(_rt("[b]%s[/b]\n%s" % [Lang.t("Intervención realizada"), str(e2["iv"])], 15))
	var used: String = ""
	for k in (e2["used"] as Dictionary):
		var nm: String = Lang.t(str(game.emg.MAT_NAMES.get(k, game.emg.TOOL_NAMES.get(k, k))))
		used += "%d %s, " % [int((e2["used"] as Dictionary)[k]), nm]
	right.add_child(_rt("[b]%s[/b] %s\n[b]%s[/b] %s" % [Lang.t("Tiempo utilizado:"), str(game._fmt_dur(int(e2["mins"]))), Lang.t("Recursos consumidos:"), used.trim_suffix(", ") if used != "" else Lang.t("ninguno")], 15))
	_lesson_blocks(right, e2["lesson"])


func _hist_pick(i: int) -> void:
	hist_sel = i
	render()
