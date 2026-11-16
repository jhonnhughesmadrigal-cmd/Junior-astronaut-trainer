extends Control
# v29 — Motor de las "Misiones de clase" (lecciones cortas que elige el docente).
# - Usa el mundo normal del juego, pero con el TIEMPO CONGELADO (no se gastan recursos ni hay eventos)
#   y SIN GUARDAR (no toca la partida del alumno). main.gd solo consulta lesson_active().
# - Pasos: ir a un lugar, observar, saltar (mide el tiempo en el aire), recoger hielo, salir por la esclusa.
# - Al final: cuestionario sin castigo (se puede reintentar) y tarjeta "Lo que aprendiste" con fuentes.
# - Progreso en user://lessons.cfg (separado de los ajustes y del guardado).

const DS = preload("res://design_system.gd")
const LessonData = preload("res://lesson_data.gd")
const PROGRESS_PATH: String = "user://lessons.cfg"
const MODE_LESSON: int = 15

var game: Node = null
var active: bool = false
var mission: Dictionary = {}
var step_i: int = 0
var phase: String = ""          # "steps", "quiz", "done"
var t_total: float = 0.0
var t_step: float = 0.0
var observe_acc: float = 0.0
var jumps: Array = []           # segundos en el aire de cada salto
var air_t: float = -1.0
var depl0: int = 0
var target: Vector2 = Vector2(-1, -1)
var beam: Node3D = null
var quiz_i: int = 0
var first_try_ok: int = 0
var tried: bool = false
var card: PanelContainer = null
var card_lbl: Dictionary = {}
var overlay: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()


# ---------- progreso ----------

static func progress() -> Dictionary:
	var cfg := ConfigFile.new()
	var out: Dictionary = {}
	if cfg.load(PROGRESS_PATH) == OK and cfg.has_section("done"):
		for k in cfg.get_section_keys("done"):
			out[k] = cfg.get_value("done", k)
	return out


func _save_progress(id: String, score: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	cfg.set_value("done", id, maxi(score, int(cfg.get_value("done", id, 0))))
	cfg.save(PROGRESS_PATH)


# ---------- inicio y fin ----------

func start(id: String) -> void:
	mission = LessonData.by_id(id)
	if mission.is_empty():
		return
	active = true
	step_i = 0
	phase = "steps"
	t_total = 0.0
	quiz_i = 0
	first_try_ok = 0
	_close_overlay()
	game.call("_new_game", str(mission["loc"]))   # con lesson_active(): sin guardar, sin historia ni tutorial
	var tut = game.get("tut")
	if tut != null and tut.has_method("skip_silent"):
		tut.call("skip_silent")
	game.set("clock", 10 * 60)
	if bool(mission.get("storm", false)):
		game.set("storm_left", 2)
	if str(mission["start"]) == "outside":
		game.set("outside", true)
		game.call("_set_player_tile", game.get("ext_spawn"), Vector2i(0, 1))
		var v3 = game.get("view3d")
		if v3 != null:
			# la partida se acaba de crear en este mismo fotograma: hay que pasar la vista 3D al exterior a mano
			v3.set("last_outside", true)
			v3.call("_update_visibility")
			v3.set("cam_focus", v3.call("_tp", int(game.get("player").x), int(game.get("player").y)))
			v3.call("snap_camera")
	game.call("_refresh")
	game.call("_log", Lang.t("[color=#7fd0ff]Misión de clase: %s. El tiempo está detenido y no se guarda la partida.[/color]") % Lang.t(str(mission["title"])))
	_begin_step()
	get_parent().move_child(self, get_parent().get_child_count() - 1)   # por encima del HUD recien creado
	card.visible = true
	DS.fade_in(card, DS.T_BASE, 0.0)


func stop() -> void:
	active = false
	phase = ""
	mission = {}
	_clear_beam()
	_close_overlay()
	if card != null:
		card.visible = false


func _begin_step() -> void:
	t_step = 0.0
	observe_acc = 0.0
	jumps.clear()
	air_t = -1.0
	depl0 = (game.get("depleted") as Dictionary).size()
	var st: Dictionary = _step()
	target = _target_of(st)
	_clear_beam()
	if target.x >= 0.0 and str(st["kind"]) == "goto":
		_make_beam(target)
	_update_card()


func _step() -> Dictionary:
	var steps: Array = mission["steps"]
	return steps[clampi(step_i, 0, steps.size() - 1)]


func _target_of(st: Dictionary) -> Vector2:
	var z: String = str(st.get("zone", ""))
	if z == "":
		return Vector2(-1, -1)
	if z == "panels":
		return Vector2(float(game.BASE_X0) - 0.5, float(game.BASE_Y0) - 2.5)
	var zs: Array = game.call("_zones")
	var want: String = Lang.t(z)
	for zz in zs:
		if str(zz["name"]) == want and int(zz.get("lx", -1)) >= 0:
			return Vector2(float(zz["lx"]) + 0.5, float(zz["ly"]) + 0.5)
	return Vector2(-1, -1)


# ---------- marcador 3D: columna de luz tenue ----------

func _make_beam(t: Vector2) -> void:
	var v3 = game.get("view3d")
	if v3 == null or v3.get("exterior") == null:
		return
	beam = Node3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(DS.C_WARN, 0.22)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.45
	cyl.height = 26.0
	cyl.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 13.0, 0)
	beam.add_child(mi)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.6
	tor.outer_radius = 1.75
	ring.mesh = tor
	var rm: StandardMaterial3D = m.duplicate()
	rm.albedo_color = Color(DS.C_WARN, 0.55)
	ring.material_override = rm
	ring.position = Vector3(0, 0.1, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(ring)
	(v3.get("exterior") as Node3D).add_child(beam)
	beam.position = Vector3(t.x * 2.0, float(v3.call("ground_y", t.x, t.y)), t.y * 2.0)


func _clear_beam() -> void:
	if beam != null and is_instance_valid(beam):
		beam.queue_free()
	beam = null


# ---------- bucle ----------

func _process(delta: float) -> void:
	if not active or game == null or not bool(game.get("playing")):
		return
	if phase != "steps":
		return
	t_total += delta
	var md: int = int(game.get("mode"))
	card.visible = (md == 0 or md == 5)
	if md != 0 and md != 5:
		return          # hay un dialogo, la pausa u otro panel: se espera
	t_step += delta
	var st: Dictionary = _step()
	var done: bool = false
	var pf: Vector2 = game.get("pos_f")
	var outside: bool = bool(game.get("outside"))
	match str(st["kind"]):
		"goto":
			done = outside and target.x >= 0.0 and pf.distance_to(target) < 2.6
		"observe":
			if outside and target.x >= 0.0 and pf.distance_to(target) < 3.5:
				observe_acc += delta
			done = observe_acc >= float(st.get("secs", 3.0))
		"jump":
			var air: bool = bool(game.get("airborne"))
			if air and air_t < 0.0:
				air_t = 0.0
			elif air:
				air_t += delta
			elif air_t >= 0.0:
				jumps.append(air_t)
				air_t = -1.0
			done = jumps.size() >= int(st.get("n", 3))
		"ice":
			done = (game.get("depleted") as Dictionary).size() > depl0 and md == 0
		"exit":
			done = outside
	_update_card()
	if done:
		game.call("_sfx", "good", -6.0)
		step_i += 1
		if step_i >= (mission["steps"] as Array).size():
			_clear_beam()
			_open_quiz()
		else:
			_begin_step()


# ---------- tarjeta de objetivo (arriba a la derecha) ----------

func _build_card() -> void:
	card = PanelContainer.new()
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = DS.card(2, DS.R_LG, 0.92)
	sb.border_color = Color(DS.C_WARN, 0.5)
	sb.border_width_left = 3
	card.add_theme_stylebox_override("panel", sb)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -380.0
	card.offset_right = -14.0
	card.offset_top = 14.0
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	card_lbl["cap"] = DS.caption("")
	card_lbl["title"] = DS.label("", 17, DS.C_TEXT, "SemiBold")
	card_lbl["step"] = DS.label("", 12, DS.C_WARN, "SemiBold")
	card_lbl["text"] = DS.label("", 14, DS.C_TEXT)
	card_lbl["info"] = DS.label("", 13, DS.C_ACCENT, "Medium")
	card_lbl["hint"] = DS.label(Lang.t("[Esc] pausa · «Salir al menú» termina la misión"), 11, DS.C_MUTED)
	for k in ["cap", "title", "step", "text", "info", "hint"]:
		(card_lbl[k] as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(card_lbl[k])


func _update_card() -> void:
	if mission.is_empty():
		return
	var steps: Array = mission["steps"]
	var st: Dictionary = _step()
	(card_lbl["cap"] as Label).text = (Lang.t("Misión de clase") + " · " + Lang.loc(str(mission["loc"])) + " · " + Lang.t(str(mission["topic"]))).to_upper()
	(card_lbl["title"] as Label).text = Lang.t(str(mission["title"]))
	(card_lbl["step"] as Label).text = Lang.t("Paso %d de %d") % [mini(step_i + 1, steps.size()), steps.size()]
	(card_lbl["text"] as Label).text = Lang.t(str(st["text"]))
	var info: String = ""
	var pf: Vector2 = game.get("pos_f")
	match str(st["kind"]):
		"goto":
			if target.x >= 0.0:
				info = Lang.t("Distancia: ≈ %d m") % int(round(pf.distance_to(target) * 2.0))
		"observe":
			info = Lang.t("Observando… %d %%") % int(clampf(observe_acc / float(st.get("secs", 3.0)), 0.0, 1.0) * 100.0)
		"jump":
			var parts: PackedStringArray = PackedStringArray()
			for i in jumps.size():
				parts.append(Lang.t("salto %d: %.1f s") % [i + 1, float(jumps[i])])
			info = Lang.t("Tiempo en el aire — ") + (", ".join(parts) if parts.size() > 0 else Lang.t("aún sin saltos"))
	(card_lbl["info"] as Label).text = info
	(card_lbl["info"] as Label).visible = info != ""


# ---------- cuestionario ----------

func _open_quiz() -> void:
	phase = "quiz"
	quiz_i = 0
	first_try_ok = 0
	card.visible = false
	game.set("mode", MODE_LESSON)
	_show_question()


func _panel(w: float) -> VBoxContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(DS.C_BG, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(w, 0)
	var sb: StyleBoxFlat = DS.card(2, DS.R_LG, 0.97)
	sb.content_margin_left = DS.S5
	sb.content_margin_right = DS.S5
	sb.content_margin_top = DS.S4
	sb.content_margin_bottom = DS.S4
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", DS.S3)
	pc.add_child(v)
	DS.fade_in(overlay, DS.T_BASE, 0.0)
	return v


func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _btn(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if cb.is_valid():
		b.pressed.connect(cb)
	if primary:
		b.add_theme_stylebox_override("normal", DS.box(Color(DS.C_ACCENT, 0.18), Color(DS.C_ACCENT, 0.7), 1, DS.R_MD, DS.S4, DS.S2))
		b.add_theme_stylebox_override("hover", DS.box(Color(DS.C_ACCENT, 0.28), DS.C_ACCENT, 1, DS.R_MD, DS.S4, DS.S2))
	return b


func _show_question() -> void:
	var quiz: Array = mission["quiz"]
	var q: Dictionary = quiz[quiz_i]
	tried = false
	var v: VBoxContainer = _panel(640.0)
	v.add_child(DS.caption(Lang.t("Pregunta %d de %d") % [quiz_i + 1, quiz.size()]))
	v.add_child(DS.label(Lang.t(str(q["q"])), DS.F_H2, DS.C_TEXT, "SemiBold"))
	# orden de las respuestas: fijo por mision y pregunta (no siempre la primera es la correcta)
	var order: Array = [0, 1, 2]
	var rot: int = (quiz_i + str(mission["id"]).length()) % 3
	for i in rot:
		order.push_back(order.pop_front())
	var fb: Label = DS.label("", 14, DS.C_TEXT)
	var answers := VBoxContainer.new()
	answers.add_theme_constant_override("separation", DS.S2)
	v.add_child(answers)
	var next: Button = _btn(Lang.t("Siguiente") if quiz_i + 1 < quiz.size() else Lang.t("Ver lo que aprendí"), _next_question, true)
	next.visible = false
	for idx in order:
		var b: Button = _btn(Lang.t(str((q["a"] as Array)[idx])), Callable())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_answer.bind(int(idx), int(q["ok"]), b, fb, next, answers))
		answers.add_child(b)
	v.add_child(fb)
	v.add_child(next)
	fb.visible = false


func _answer(idx: int, ok: int, b: Button, fb: Label, next: Button, answers: VBoxContainer) -> void:
	var q: Dictionary = (mission["quiz"] as Array)[quiz_i]
	fb.visible = true
	if idx == ok:
		if not tried:
			first_try_ok += 1
		game.call("_sfx", "good", -6.0)
		b.add_theme_stylebox_override("normal", DS.status_card("good"))
		b.add_theme_stylebox_override("disabled", DS.status_card("good"))
		fb.text = Lang.t("¡Correcto! ") + Lang.t(str(q["why"]))
		fb.add_theme_color_override("font_color", DS.C_TEXT)
		for c in answers.get_children():
			(c as Button).disabled = true
		next.visible = true
		next.grab_focus()
		DS.pulse(b)
	else:
		tried = true
		game.call("_sfx", "error", -10.0)
		b.disabled = true
		b.add_theme_stylebox_override("disabled", DS.status_card("warn"))
		fb.text = Lang.t("Casi. Piensa otra vez y prueba otra respuesta.")
		fb.add_theme_color_override("font_color", DS.C_WARN)


func _next_question() -> void:
	quiz_i += 1
	if quiz_i < (mission["quiz"] as Array).size():
		_show_question()
	else:
		_show_summary()


# ---------- resumen ----------

func _show_summary() -> void:
	phase = "done"
	var nq: int = (mission["quiz"] as Array).size()
	_save_progress(str(mission["id"]), first_try_ok)
	var v: VBoxContainer = _panel(700.0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", DS.S3)
	head.add_child(DS.icon_rect("check", 28, DS.C_GOOD))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(DS.caption(Lang.t("¡Misión completada!")))
	hv.add_child(DS.label(Lang.t(str(mission["title"])), DS.F_H1, DS.C_TEXT, "SemiBold"))
	head.add_child(hv)
	v.add_child(head)
	v.add_child(DS.label(Lang.t("Respuestas correctas a la primera: %d de %d · Tiempo: %d min %02d s") % [first_try_ok, nq, int(t_total) / 60, int(t_total) % 60], 13, DS.C_DIM))
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", DS.box(Color(DS.C_TEAL, 0.8), Color(0, 0, 0, 0), 0, DS.R_MD, DS.S4, DS.S3))
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", DS.S1)
	box.add_child(bv)
	bv.add_child(DS.caption(Lang.t("Lo que aprendiste")))
	for l in mission["learned"]:
		bv.add_child(DS.label("•  " + Lang.t(str(l)), 15, DS.C_TEXT))
	v.add_child(box)
	v.add_child(DS.caption(Lang.t("Fuentes")))
	for s in mission["sources"]:
		var lb := LinkButton.new()
		lb.text = Lang.t(str(s[0]))
		lb.uri = str(s[1])
		lb.add_theme_font_size_override("font_size", 13)
		lb.add_theme_color_override("font_color", DS.C_ACCENT)
		lb.tooltip_text = str(s[1])
		v.add_child(lb)
	v.add_child(DS.label(Lang.t("Las cifras con «≈» son aproximadas: verifícalas en la fuente."), 12, DS.C_MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S2)
	v.add_child(row)
	row.add_child(_btn(Lang.t("Repetir misión"), _repeat))
	row.add_child(_btn(Lang.t("Volver a las misiones"), _back_to_list, true))


func _repeat() -> void:
	var id: String = str(mission["id"])
	start(id)


func _back_to_list() -> void:
	stop()
	game.call("_show_menu")
	var ui = game.get("ui")
	if ui != null:
		ui.call("show_page", "lessons")


func handle_key(k: InputEventKey) -> void:
	# teclado en el cuestionario/resumen: Esc vuelve a la lista de misiones; el resto con raton/Tab/Enter
	if k.keycode == KEY_ESCAPE and phase == "done":
		_back_to_list()
