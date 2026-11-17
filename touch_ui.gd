extends Control
# v30 — Controles tactiles para movil y tableta (solo interfaz: no cambia la logica del juego).
# Idea: cada boton SIMULA la tecla que el juego ya entiende (Input.parse_input_event), asi que el tactil
# usa exactamente el mismo camino que el teclado. Las teclas se leen de game.binds (si el jugador
# las cambio en Opciones, el tactil las sigue).
#  - Joystick (mitad izquierda, donde apoyes el pulgar): moverse; al borde, correr.
#  - Botones: Usar/Continuar, Saltar (solo fuera), Mochila, Mapa, Camara, Pausa.
#  - Paneles (mochila, mapa, diario, logros, banco, minijuego): boton Cerrar (= Esc).
#  - Dialogo con opciones: botones 1 y 2.
#  - Arrastrar en la mitad derecha: mirar (primera persona y camara detras del personaje).
# Se muestra solo en pantallas tactiles (Automatico) o segun Opciones > Controles (Siempre / Nunca).

const DS = preload("res://design_system.gd")
const CFG_PATH: String = "user://touch.cfg"
const DEAD: float = 0.28
const RUN_AT: float = 0.92
const JOY_R: float = 64.0

var game: Node = null
var setting: int = 0           # 0 automatico, 1 siempre, 2 nunca
var seen_touch: bool = false
var joy_id: int = -1
var joy_center: Vector2 = Vector2.ZERO
var joy_vec: Vector2 = Vector2.ZERO
var look_id: int = -1
var look_last: Vector2 = Vector2.ZERO
var held: Dictionary = {}      # tecla -> true mientras esta simulada
var btns: Array = []           # [{id, pos, r, icon, label, key}]
var press_id: Dictionary = {}  # indice de dedo -> id de boton
var flash: Dictionary = {}     # id de boton -> tiempo de resaltado


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 70   # por encima de mochila y banco (z 58), que se dibujan sobre el resto
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		setting = clampi(int(cfg.get_value("touch", "mode", 0)), 0, 2)


func set_mode(i: int) -> void:
	setting = clampi(i, 0, 2)
	var cfg := ConfigFile.new()
	cfg.set_value("touch", "mode", setting)
	cfg.save(CFG_PATH)
	_release_all()
	queue_redraw()


func enabled() -> bool:
	if setting == 1:
		return true
	if setting == 2:
		return false
	return seen_touch or DisplayServer.is_touchscreen_available()


# ---------- teclas simuladas ----------

func _key(code: int, down: bool) -> void:
	if code == 0:
		return
	if down == bool(held.get(code, false)):
		return
	var ev := InputEventKey.new()
	ev.keycode = code as Key
	ev.physical_keycode = code as Key
	ev.pressed = down
	held[code] = down
	Input.parse_input_event(ev)


func _tap(code: int) -> void:
	_key(code, true)
	_key(code, false)


func _bind(id: String) -> int:
	var b: Dictionary = game.get("binds")
	return int(b.get(id, 0))


func _release_all() -> void:
	for code in held.keys():
		if bool(held[code]):
			_key(int(code), false)
	joy_id = -1
	look_id = -1
	joy_vec = Vector2.ZERO
	press_id.clear()


# ---------- disposicion segun el modo de juego ----------

func _layout() -> void:
	btns.clear()
	if game == null or not bool(game.get("playing")):
		return
	var vs: Vector2 = get_viewport_rect().size
	var md: int = int(game.get("mode"))
	var m: float = 22.0
	if md == 0 or md == 5:
		var base := Vector2(vs.x - m - 58.0, vs.y - m - 132.0)   # por encima del reloj del HUD
		btns.append({"id": "use", "pos": base, "r": 50.0, "icon": "hand", "label": Lang.t("Usar"), "key": _bind("interact")})
		if bool(game.get("outside")):
			btns.append({"id": "jump", "pos": base + Vector2(-122.0, 30.0), "r": 40.0, "icon": "jump", "label": Lang.t("Salto"), "key": _bind("jump")})
		btns.append({"id": "pack", "pos": base + Vector2(-20.0, -112.0), "r": 30.0, "icon": "box", "label": Lang.t("Mochila"), "key": _bind("pack")})
		btns.append({"id": "map", "pos": base + Vector2(-88.0, -92.0), "r": 30.0, "icon": "map", "label": Lang.t("Mapa"), "key": _bind("map")})
		btns.append({"id": "diary", "pos": base + Vector2(48.0, -112.0), "r": 26.0, "icon": "book", "label": Lang.t("Diario"), "key": _bind("diary")})
		if bool(game.get("view3d_on")):
			btns.append({"id": "cam", "pos": base + Vector2(-160.0, -62.0), "r": 30.0, "icon": "camera", "label": Lang.t("Cámara"), "key": _bind("cam")})
		var ppos := Vector2(vs.x * 0.5 + 170.0, 34.0)
		if vs.y < 600.0 or bool(game.call("lesson_active")):
			# pantalla baja (movil) o mision de clase (tarjeta arriba a la derecha): pausa en el grupo de botones
			ppos = base + Vector2(-150.0, -122.0)
		btns.append({"id": "pause", "pos": ppos, "r": 26.0, "icon": "pause", "label": "", "key": KEY_ESCAPE})
	elif md == 1 or md == 8:
		var pos := Vector2(vs.x - m - 58.0, vs.y - m - 132.0)
		if md == 1 and bool(game.get("choice_active")):
			btns.append({"id": "c1", "pos": pos + Vector2(-110.0, 0.0), "r": 40.0, "icon": "", "label": "1", "key": KEY_1})
			btns.append({"id": "c2", "pos": pos, "r": 40.0, "icon": "", "label": "2", "key": KEY_2})
		else:
			btns.append({"id": "next", "pos": pos, "r": 46.0, "icon": "play", "label": Lang.t("Seguir"), "key": KEY_E})
	elif md == 2 or md == 9:
		# confirmar dormir (2) o encargar una mejora al Ing. Enoc (9): E = si, Esc = cancelar
		var cpos := Vector2(vs.x - m - 58.0, vs.y - m - 132.0)
		btns.append({"id": "yes", "pos": cpos, "r": 46.0, "icon": "check", "label": Lang.t("Sí"), "key": KEY_E})
		btns.append({"id": "no", "pos": cpos + Vector2(-118.0, 20.0), "r": 38.0, "icon": "close", "label": Lang.t("Cancelar"), "key": KEY_ESCAPE})
	elif md in [4, 6, 7, 10, 11, 12]:
		btns.append({"id": "close", "pos": Vector2(vs.x - m - 30.0, m + 30.0), "r": 30.0, "icon": "close", "label": Lang.t("Cerrar"), "key": KEY_ESCAPE})


func _joy_allowed() -> bool:
	var md: int = int(game.get("mode"))
	return bool(game.get("playing")) and (md == 0 or md == 5)


func _hit(p: Vector2) -> Dictionary:
	for b in btns:
		if p.distance_to(b["pos"]) <= float(b["r"]) + 10.0:
			return b
	return {}


# ---------- entrada ----------

func _input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not seen_touch:
			seen_touch = true
			queue_redraw()
	if not enabled() or not bool(game.get("playing")):
		return
	var vs: Vector2 = get_viewport_rect().size
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_layout()
			var b: Dictionary = _hit(t.position)
			if not b.is_empty():
				press_id[t.index] = str(b["id"])
				flash[str(b["id"])] = 0.18
				_key(int(b["key"]), true)
				get_viewport().set_input_as_handled()
			elif _joy_allowed() and t.position.x < vs.x * 0.45 and t.position.y > vs.y * 0.35 and joy_id < 0:
				joy_id = t.index
				joy_center = t.position
				joy_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
			elif _joy_allowed() and t.position.x >= vs.x * 0.45 and look_id < 0:
				look_id = t.index
				look_last = t.position
		else:
			if press_id.has(t.index):
				var id: String = press_id[t.index]
				press_id.erase(t.index)
				for b2 in btns:
					if str(b2["id"]) == id:
						_key(int(b2["key"]), false)
				get_viewport().set_input_as_handled()
			if t.index == joy_id:
				joy_id = -1
				joy_vec = Vector2.ZERO
				_apply_joy()
			if t.index == look_id:
				look_id = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == joy_id:
			var v: Vector2 = (d.position - joy_center) / JOY_R
			if v.length() > 1.0:
				# el centro sigue al dedo si se pasa del borde (no hace falta volver a apoyar)
				joy_center += (d.position - joy_center).normalized() * (v.length() - 1.0) * JOY_R
				v = v.normalized()
			joy_vec = v
			_apply_joy()
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif d.index == look_id:
			var cm: int = int(game.get("cam_mode"))
			if cm == 1 or cm == 2:
				game.call("_mouse_look", (d.position - look_last) * 1.6)
			look_last = d.position
	elif event is InputEventMouseButton:
		# raton simulado a partir del dedo (device = -1): no debe "usar" al tocar el joystick o un boton
		# en juego (modos 0 y 5) el dedo solo actua mediante el joystick y los botones; en menus,
		# paneles, cuestionarios y dialogos el raton simulado sigue llegando a la interfaz.
		var mb: InputEventMouseButton = event
		if mb.device == InputEvent.DEVICE_ID_EMULATION and _joy_allowed() and not _over_gui_button(mb.position):
			get_viewport().set_input_as_handled()


# hay un boton de la interfaz visible bajo el dedo (p. ej. «Saltar tutorial»)? Entonces el toque es suyo.
func _over_gui_button(p: Vector2) -> bool:
	for n in game.find_children("*", "BaseButton", true, false):
		var b: BaseButton = n
		if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(p):
			return true
	return false


func _apply_joy() -> void:
	var v: Vector2 = joy_vec
	var on: bool = v.length() > DEAD
	_key(_bind("up"), on and v.y < -0.38)
	_key(_bind("down"), on and v.y > 0.38)
	_key(_bind("left"), on and v.x < -0.38)
	_key(_bind("right"), on and v.x > 0.38)
	_key(_bind("sprint"), on and v.length() >= RUN_AT)


func _process(delta: float) -> void:
	if game == null:
		return
	var vis: bool = enabled() and bool(game.get("playing"))
	if not vis and not held.is_empty():
		_release_all()
	if vis and not _joy_allowed() and joy_id >= 0:
		joy_id = -1
		joy_vec = Vector2.ZERO
		_apply_joy()
	for k in flash.keys():
		flash[k] = float(flash[k]) - delta
		if float(flash[k]) <= 0.0:
			flash.erase(k)
	visible = vis
	_place_log(vis)
	if vis:
		_touch_hints()
	# los paneles (mochila, banco...) se ponen delante al abrirse: el boton «Cerrar» debe quedar encima
	if vis and int(game.get("mode")) in [4, 6, 7, 10, 11, 12]:
		var par: Node = get_parent()
		if par.get_child(par.get_child_count() - 1) != self:
			par.move_child(self, par.get_child_count() - 1)
	if vis:
		queue_redraw()


# textos de ayuda que nombran teclas: en tactil se cambian por los botones equivalentes
func _touch_hints() -> void:
	var h = game.get("dlg_hint")
	if h == null or not is_instance_valid(h) or not (h as Label).is_visible_in_tree():
		return
	var lb: Label = h
	var rep: Dictionary = {
		Lang.t("[E] continuar"): Lang.t("Toca «Seguir» para continuar"),
		Lang.t("Elige con 1 o 2"): Lang.t("Toca 1 o 2 para elegir"),
		Lang.t("[E] Dormir      [Esc] Cancelar"): Lang.t("Toca «Sí» para dormir o «Cancelar»"),
		Lang.t("[E] Encargar la obra al Ing. Enoc      [Esc] Cancelar"): Lang.t("Toca «Sí» para encargar la obra al Ing. Enoc o «Cancelar»"),
	}
	if rep.has(lb.text):
		lb.text = rep[lb.text]


# en modo tactil el registro de mensajes se coloca entre el joystick y los botones
var _log_orig: Array = []
func _place_log(on: bool) -> void:
	var lp = game.get("log_panel")
	if lp == null or not is_instance_valid(lp):
		_log_orig = []
		return
	var c: Control = lp
	if _log_orig.is_empty():
		_log_orig = [c.offset_left, c.offset_right]
	var vs: Vector2 = get_viewport_rect().size
	var want: Array = [240.0, minf(240.0 + 470.0, vs.x - 300.0)] if on else _log_orig
	if not is_equal_approx(c.offset_left, float(want[0])) or not is_equal_approx(c.offset_right, float(want[1])):
		c.offset_left = float(want[0])
		c.offset_right = float(want[1])


# ---------- dibujo (sistema de diseno: translucido, sin neon) ----------

func _draw() -> void:
	if not visible:
		return
	_layout()
	var vs: Vector2 = get_viewport_rect().size
	var font: Font = DS.font("SemiBold")
	if _joy_allowed():
		var c: Vector2 = joy_center if joy_id >= 0 else Vector2(118.0, vs.y - 128.0)
		var a: float = 0.95 if joy_id >= 0 else 0.55
		draw_circle(c, JOY_R + 10.0, Color(DS.C_SURF1, 0.45 * a))
		draw_arc(c, JOY_R + 10.0, 0.0, TAU, 48, Color(DS.C_LINE_HI, 0.8 * a), 2.0, true)
		var k: Vector2 = c + joy_vec * JOY_R
		draw_circle(k, 30.0, Color(DS.C_SURF3, 0.9 * a))
		draw_arc(k, 30.0, 0.0, TAU, 32, Color(DS.C_ACCENT if joy_vec.length() >= RUN_AT else DS.C_DIM, 0.9 * a), 2.0, true)
		if joy_id < 0:
			draw_string(font, c + Vector2(-60.0, JOY_R + 34.0), Lang.t("Moverse"), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 12, Color(DS.C_DIM, 0.8))
	for b in btns:
		var p: Vector2 = b["pos"]
		var r: float = float(b["r"])
		var on: bool = flash.has(str(b["id"])) or press_id.values().has(str(b["id"]))
		draw_circle(p, r, Color(DS.C_ACCENT, 0.3) if on else Color(DS.C_SURF1, 0.62))
		draw_arc(p, r, 0.0, TAU, 40, Color(DS.C_ACCENT, 0.9) if on else Color(DS.C_LINE_HI, 0.9), 2.0, true)
		var ic: String = str(b["icon"])
		var lbl: String = str(b["label"])
		if ic != "":
			var sz: int = int(r * 0.8)
			var tex: Texture2D = DS.icon(ic, sz, DS.C_TEXT)
			if tex != null:
				var yo: float = -6.0 if (lbl != "" and r >= 40.0) else 0.0
				draw_texture_rect(tex, Rect2(p - Vector2(sz, sz) / 2.0 + Vector2(0, yo), Vector2(sz, sz)), false)
			if lbl != "" and r >= 40.0:
				draw_string(font, p + Vector2(-r, r * 0.62), lbl, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 11, DS.C_TEXT)
			elif lbl != "":
				draw_string_outline(font, p + Vector2(-r - 12.0, r + 15.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0 + 24.0, 12, 4, Color(DS.C_BG, 0.85))
				draw_string(font, p + Vector2(-r - 12.0, r + 15.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0 + 24.0, 12, DS.C_TEXT)
		else:
			draw_string(font, p + Vector2(-r, 8.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 24, DS.C_TEXT)
