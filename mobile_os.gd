extends Node
# v37 — Comportamiento del sistema en móviles (Android). No cambia la lógica del juego.
# - Botón/gesto «Atrás»: por defecto Godot cierra la app (quit_on_go_back) y se perdería la partida.
#   Aquí «Atrás» hace lo mismo que Esc (cerrar panel, pausa, volver al menú) y, en la portada,
#   hay que pulsarlo dos veces para salir.
# - Al pasar la app a segundo plano (NOTIFICATION_APPLICATION_PAUSED) se guarda la partida,
#   porque Android puede cerrar la app sin avisar mientras está en segundo plano.
# - v38: teclado en pantalla: si tapa el campo de texto activo, el panel sube lo justo
#   (en horizontal el teclado de un móvil ocupa casi media pantalla).
# No está probado en un dispositivo real (solo en escritorio simulando las notificaciones).

const DS = preload("res://design_system.gd")
const EXIT_WINDOW: float = 2.0

var game: Node = null
var _exit_until: float = -1.0
var _toast: Label = null
var _toast_tw: Tween = null
var _kb_node: Control = null     # panel desplazado por el teclado
var _kb_base_y: float = 0.0


func setup(g: Node) -> void:
	game = g
	get_tree().quit_on_go_back = false
	set_process(OS.has_feature("mobile"))


func _process(_delta: float) -> void:
	kb_fit(DisplayServer.virtual_keyboard_get_height())


# kb_px: alto del teclado en píxeles de la ventana (0 = cerrado)
func kb_fit(kb_px: int) -> void:
	var vp: Viewport = get_viewport()
	var focus: Control = vp.gui_get_focus_owner()
	if kb_px <= 0 or not (focus is LineEdit or focus is TextEdit):
		_kb_restore()
		return
	# panel que se mueve: el antecesor del campo que cuelga directamente del juego
	var n: Node = focus
	while n.get_parent() != null and n.get_parent() != game:
		n = n.get_parent()
	var root: Control = n as Control
	if root == null or n.get_parent() != game:
		return
	if _kb_node != root:
		_kb_restore()
		_kb_node = root
		_kb_base_y = root.position.y
	var vis: Vector2 = vp.get_visible_rect().size
	var win_h: float = maxf(1.0, float(DisplayServer.window_get_size().y))
	var limit: float = vis.y - float(kb_px) * vis.y / win_h - 12.0
	var bottom: float = focus.get_global_rect().end.y - (root.position.y - _kb_base_y)
	root.position.y = _kb_base_y - maxf(0.0, bottom - limit)


func _kb_restore() -> void:
	if _kb_node != null and is_instance_valid(_kb_node):
		_kb_node.position.y = _kb_base_y
	_kb_node = null


func _notification(what: int) -> void:
	if game == null:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back.call_deferred()   # diferido: durante la notificación el nodo no admite hijos (el aviso)
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _at_title() -> bool:
	# portada del menú principal sin nada abierto encima
	if bool(game.get("playing")) or not bool(game.get("in_menu")):
		return false
	var ui = game.get("ui")
	if ui == null or str(ui.get("cur_page")) != "main":
		return false
	if bool(game.call("_any_overlay")):
		return false
	var pui: Node = game.get_node_or_null("ProfileUI")
	if pui != null and (pui as CanvasItem).visible and not (game.get_node("Profiles").get("current") as Dictionary).is_empty():
		return false
	return true


func go_back() -> void:
	var pui: Node = game.get_node_or_null("ProfileUI")
	if _at_title():
		if _now() < _exit_until:
			save_now()
			get_tree().quit()
			return
		_exit_until = _now() + EXIT_WINDOW
		_show_toast(Lang.t("Pulsa «Atrás» otra vez para salir"))
		return
	if pui != null and (pui as CanvasItem).visible:
		pui.call("close")
		return
	_send_escape()


func _send_escape() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = down
		Input.parse_input_event(ev)


func save_now() -> void:
	if bool(game.get("playing")):
		game.call("_save_game")


func _show_toast(text: String) -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 120
		add_child(layer)
		_toast = Label.new()
		_toast.add_theme_font_size_override("font_size", 18)
		_toast.add_theme_color_override("font_color", DS.C_TEXT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(DS.C_SURF3, 0.95)
		sb.set_corner_radius_all(DS.R_MD)
		sb.content_margin_left = DS.S4
		sb.content_margin_right = DS.S4
		sb.content_margin_top = DS.S2
		sb.content_margin_bottom = DS.S2
		_toast.add_theme_stylebox_override("normal", sb)
		_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_toast.offset_bottom = -40
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_toast)
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.visible = true
	if _toast_tw != null:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(EXIT_WINDOW - 0.4)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
