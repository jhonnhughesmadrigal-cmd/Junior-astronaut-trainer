extends Node
# v31 — Interfaz adaptable a moviles (solo interfaz; no cambia la logica del juego).
# 1) Escala automatica: en pantallas tactiles bajas (movil en horizontal) agranda toda la interfaz
#    (content_scale_factor) para que el texto se lea: alto CSS < 450 px -> x1,35; < 600 px -> x1,15.
#    Se multiplica por la opcion «Tamano de la interfaz» del jugador.
# 2) Encaje: si un panel abierto (menu, pausa, opciones, mapa, mochila, banco, diagnostico, etc.)
#    no cabe en la pantalla, se reduce lo justo para caber y se centra. Si cabe, no se toca.
# 3) Movil en vertical: aviso «Gira el dispositivo» (el juego esta pensado en horizontal).

const DS = preload("res://design_system.gd")

var game = null   # main.gd (sin tipo: se leen sus constantes y variables)
var force_k: float = 0.0        # pruebas: fuerza el factor de movil (0 = automatico)
var k: float = 1.0
var _t: float = 0.0
var _scaled: Array = []         # controles a los que se aplico escala
var rotate_ov: Control = null
var skip: Array = []


func setup(g) -> void:
	game = g
	_build_rotate()
	skip = [game.get("root_margin"), game.get("fade_rect"), game.get_node_or_null("TouchUI"), game.get_node_or_null("UiMotion"), rotate_ov]


# ---------- 1) escala automatica ----------

func _short_side_css() -> float:
	if OS.has_feature("web"):
		var w = JavaScriptBridge.eval("window.innerWidth", true)
		var h = JavaScriptBridge.eval("window.innerHeight", true)
		if w != null and h != null:
			return minf(float(w), float(h))
	var ws: Vector2i = DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios"):
		# v37: en el movil nativo, pixeles fisicos -> dp (160 ppp = 1 dp), como los px CSS de la web
		var dpi: float = float(DisplayServer.screen_get_dpi())
		if dpi > 0.0:
			return float(mini(ws.x, ws.y)) * 160.0 / dpi
	var sc: float = maxf(DisplayServer.screen_get_scale(), 1.0)
	return float(mini(ws.x, ws.y)) / sc


func _touch_on() -> bool:
	var t: Node = game.get_node_or_null("TouchUI")
	return t != null and bool(t.call("enabled"))


func phone_k() -> float:
	if force_k > 0.0:
		return force_k
	if not _touch_on():
		return 1.0
	var s: float = _short_side_css()
	if s < 450.0:
		return 1.35
	if s < 600.0:
		return 1.15
	return 1.0


func _apply_scale() -> void:
	k = phone_k()
	var scales: Array = game.UI_SCALES
	var base: float = float(scales[clampi(int(game.get("ui_scale_idx")), 0, scales.size() - 1)])
	var want: float = base * k
	var w: Window = game.get_window()
	if absf(w.content_scale_factor - want) > 0.001:
		w.content_scale_factor = want


# ---------- 2) encaje de paneles ----------

func _target_of(root: Control) -> Control:
	# el contenedor de contenido mas grande (PanelContainer o MarginContainer) hasta 3 niveles
	var best: Control = null
	var best_a: float = 0.0
	var stack: Array = [[root, 0]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var n: Node = e[0]
		var d: int = int(e[1])
		for c in n.get_children():
			if not (c is Control) or not (c as Control).visible:
				continue
			var cc: Control = c
			if cc is PanelContainer or cc is MarginContainer:
				var a: float = cc.size.x * cc.size.y
				if a > best_a:
					best_a = a
					best = cc
			if d < 2:
				stack.append([cc, d + 1])
	return best


func _fit(c: Control, vs: Vector2) -> void:
	var s: Vector2 = c.size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	var pad: float = 8.0
	# con controles tactiles se deja libre una franja a la derecha para el boton «Cerrar»
	var pad_r: float = 70.0 if _touch_on() else pad
	var f: float = minf(1.0, minf((vs.x - pad - pad_r) / s.x, (vs.y - pad * 2.0) / s.y))
	if f >= 0.999:
		if c in _scaled:
			c.scale = Vector2.ONE
			c.pivot_offset = Vector2.ZERO
			_scaled.erase(c)
		return
	# pivote que deja el panel reducido centrado en la zona libre de la pantalla.
	# Posicion SIN escala: global_position ya incluye la escala aplicada y haria derivar el calculo.
	var par: Control = c.get_parent() as Control
	var p: Vector2 = (par.get_global_rect().position if par != null else Vector2.ZERO) + c.position
	var center_after: Vector2 = Vector2((pad + vs.x - pad_r) / 2.0, vs.y / 2.0)
	var cpiv: Vector2 = (center_after - (p + s / 2.0) * f) / (1.0 - f)
	c.pivot_offset = cpiv - p
	c.scale = Vector2(f, f)
	if not (c in _scaled):
		_scaled.append(c)


func _fit_all() -> void:
	var vs: Vector2 = game.get_viewport_rect().size
	var seen: Array = []
	for ch in game.get_children():
		if not (ch is Control) or ch in skip or ch is ColorRect or ch is TextureRect:
			continue
		var root: Control = ch
		if not root.visible:
			continue
		var t: Control = _target_of(root)
		if t != null:
			_fit(t, vs)
			seen.append(t)
	# paneles que ya no estan visibles: escala normal
	for c in _scaled.duplicate():
		if not is_instance_valid(c):
			_scaled.erase(c)
		elif not (c in seen):
			c.scale = Vector2.ONE
			c.pivot_offset = Vector2.ZERO
			_scaled.erase(c)


# ---------- 3) aviso de girar el dispositivo ----------

func _build_rotate() -> void:
	rotate_ov = Control.new()
	rotate_ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_ov.mouse_filter = Control.MOUSE_FILTER_STOP
	rotate_ov.visible = false
	rotate_ov.z_index = 100
	rotate_ov.name = "RotateHint"
	var bg := ColorRect.new()
	bg.color = DS.C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_ov.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_ov.add_child(cc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", DS.S3)
	cc.add_child(v)
	var ic: TextureRect = DS.icon_rect("rotate", 150, DS.C_ACCENT)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	# en vertical el lienzo logico se ve muy reducido: letra grande
	var t: Label = DS.label(Lang.t("Gira el dispositivo"), 64, DS.C_TEXT, "SemiBold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(700, 0)
	v.add_child(t)
	var d: Label = DS.label(Lang.t("Misión Perseo se juega con la pantalla en horizontal."), 38, DS.C_DIM)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(700, 0)
	v.add_child(d)
	game.add_child(rotate_ov)


func _rotate_check() -> void:
	var vs: Vector2 = game.get_viewport_rect().size
	var want: bool = _touch_on() and vs.y > vs.x
	if rotate_ov.visible != want:
		rotate_ov.visible = want
	if want:
		game.move_child(rotate_ov, game.get_child_count() - 1)


func _process(delta: float) -> void:
	if game == null:
		return
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	_apply_scale()
	var ui = game.get("ui")
	if ui != null:
		ui.call("set_compact", game.get_viewport_rect().size.y < 600.0)
	_fit_all()
	_rotate_check()
