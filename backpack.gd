extends "res://inv_icons.gd"
# Panel de la mochila: casillas, objeto en la mano y estado de las mejoras. Se abre con [I].

signal closed

const SLOT: float = 78.0
const COLS_N: int = 5
const DOLL_W: float = 215.0     # columna del muñeco (estilo Minecraft) a la izquierda
var mouse: Vector2 = Vector2.ZERO
var slots: Array = []
var doll_vp: SubViewportContainer = null
var doll_pivot: Node3D = null
var doll_yaw: float = 0.35
var dragging: bool = false


func _init() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2.ZERO
	visible = false


func open() -> void:
	_build()
	_ensure_doll()
	visible = true
	set_process(true)
	_place_doll()
	queue_redraw()


func close() -> void:
	visible = false
	set_process(false)
	dragging = false
	if doll_vp != null:
		doll_vp.visible = false
	closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	if not dragging and doll_pivot != null:
		doll_yaw += delta * 0.6
	if doll_pivot != null:
		doll_pivot.rotation.y = doll_yaw


# Vista 3D del astronauta con su traje, como el muñeco del inventario de Minecraft.
func _ensure_doll() -> void:
	if doll_vp != null or game == null or game.view3d == null:
		return
	doll_vp = SubViewportContainer.new()
	doll_vp.stretch = true
	doll_vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.size = Vector2i(190, 330)
	sv.msaa_3d = Viewport.MSAA_2X
	doll_vp.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, -2.6, 0.0)
	sun.light_energy = 1.3
	sv.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, 0.8, 0.0)
	fill.light_energy = 0.5
	sv.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 32.0
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.15, -4.6), Vector3(0.0, 0.92, 0.0), Vector3.UP)
	doll_pivot = Node3D.new()
	sv.add_child(doll_pivot)
	doll_pivot.add_child(game.view3d.make_preview_model())
	add_child(doll_vp)


func _doll_rect() -> Rect2:
	var p: Rect2 = _panel()
	return Rect2(p.position.x + 22.0, p.position.y + 72.0, DOLL_W - 30.0, minf(330.0, p.size.y - 190.0))


func _place_doll() -> void:
	if doll_vp == null:
		return
	var r: Rect2 = _doll_rect()
	doll_vp.position = r.position
	doll_vp.size = r.size
	doll_vp.visible = true


func _build() -> void:
	slots.clear()
	for id in MATS:
		var n: int = int(game.inv[id])
		while n > 0:
			var c: int = mini(n, game.STACK_MAT)
			slots.append({"id": id, "n": c})
			n -= c
	for id in TOOLS:
		var n2: int = int(game.tools[id])
		while n2 > 0:
			var c2: int = mini(n2, int(game.STACK_TOOL.get(id, 1)))
			slots.append({"id": id, "n": c2})
			n2 -= c2


func _panel() -> Rect2:
	var cap: int = game._pack_cap()
	var rows: int = int(ceil(float(cap) / float(COLS_N)))
	var w: float = DOLL_W + float(COLS_N) * (SLOT + 8.0) + 60.0 + 300.0
	w = minf(w, size.x - 20.0)
	# alto minimo: la columna de mejoras (9 filas) + 'en mano' + pie de texto tienen que caber dentro del panel
	var h: float = maxf(float(rows) * (SLOT + 8.0) + 150.0, 500.0)
	h = minf(h, size.y - 20.0)
	return Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)


func _slot_rect(i: int) -> Rect2:
	var p: Rect2 = _panel()
	var cx: int = i % COLS_N
	var cy: int = i / COLS_N
	return Rect2(p.position.x + 30.0 + DOLL_W + float(cx) * (SLOT + 8.0), p.position.y + 80.0 + float(cy) * (SLOT + 8.0), SLOT, SLOT)


func handle_key(k: InputEventKey) -> void:
	if k.keycode == KEY_ESCAPE or k.keycode == KEY_I or k.keycode == KEY_E:
		close()
	elif k.keycode == KEY_Q:
		game._cycle_hold()
		queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var mm := ev as InputEventMouseMotion
	if mm != null:
		mouse = mm.position
		if dragging:
			doll_yaw += mm.relative.x * 0.01
		queue_redraw()
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		dragging = false
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _doll_rect().has_point(mb.position):
		dragging = true    # arrastra el muñeco para girarlo
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		for i in slots.size():
			if _slot_rect(i).has_point(mb.position):
				var id: String = str(slots[i]["id"])
				if game.HOLDABLE.has(id):
					game._hold("" if game.held == id else id)
					queue_redraw()
				return


func _desc(id: String) -> String:
	match id:
		"scrap":
			return Lang.t("Chatarra: material básico para fabricar y mejorar.")
		"polymer":
			return Lang.t("Polímero: plástico técnico para fabricar y mejorar.")
		"circuits":
			return Lang.t("Circuitos: los más escasos; necesarios para mejoras avanzadas.")
		"patch":
			return Lang.t("Kit de parche: sella una brecha en el generador de escudo. Se puede sostener.")
		"medkit":
			return Lang.t("Botiquín: habla con la Dra. YARISBEL para curar una enfermedad.")
		"repair":
			return Lang.t("Reparador: reduce el daño de una falla eléctrica (automático).")
		"filter":
			return Lang.t("Filtro de polvo: reduce el daño de una tormenta (automático).")
		"map":
			return Lang.t("Mapa de navegación: [Tab] y minimapa.")
	return ""


func _draw() -> void:
	if not visible or game == null:
		return
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65))
	var p: Rect2 = _panel()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.97)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.5, 0.7, 1.0)
	draw_style_box(sb, p)
	var used: int = game._slots_used()
	var cap: int = game._pack_cap()
	draw_string(font, p.position + Vector2(30, 44), Lang.t("Mochila  %d / %d casillas") % [used, cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.9, 0.5))
	var dr: Rect2 = _doll_rect()
	draw_rect(dr.grow(4.0), Color(0.08, 0.1, 0.19))
	draw_rect(dr.grow(4.0), Color(0.3, 0.4, 0.65), false, 2.0)
	draw_string(font, Vector2(dr.position.x, dr.end.y + 26.0), "Wilson", HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 18, Color(0.7, 0.95, 1.0))
	draw_string(font, Vector2(dr.position.x, dr.end.y + 46.0), Lang.t("Arrastra para girar"), HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 12, Color(0.6, 0.7, 0.9))
	var hover: String = ""
	for i in cap:
		var r: Rect2 = _slot_rect(i)
		draw_rect(r, Color(0.11, 0.14, 0.24))
		draw_rect(r, Color(0.3, 0.4, 0.65), false, 2.0)
		if i < slots.size():
			var it: Dictionary = slots[i]
			var id: String = str(it["id"])
			var ic := Rect2(r.position + Vector2(SLOT / 2.0 - 16.0, 10.0), Vector2(32.0, 32.0))
			var tx: Texture2D = _tex(id)
			if tx != null:
				draw_texture_rect(tx, ic, false)
			else:
				_icon(id, ic, 1.0)
			draw_string(font, r.position + Vector2(0, 62.0), "%s x%d" % [str(LABELS.get(id, id)).left(9), int(it["n"])], HORIZONTAL_ALIGNMENT_CENTER, SLOT, 12, Color(0.9, 0.93, 1.0))
			if game.held == id:
				draw_rect(r.grow(2.0), Color(1.0, 0.85, 0.3), false, 3.0)
			if r.has_point(mouse):
				hover = id
	# columna derecha: mejoras
	var x: float = p.end.x - 300.0
	var y: float = p.position.y + 80.0
	draw_string(font, Vector2(x, y), Lang.t("Equipo y mejoras"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.85, 1.0))
	var lines: Array = [
		Lang.t("Tanque del traje: nivel %d (%d min)") % [game.suit_lvl_o2, int(game._suit_max())],
		Lang.t("Aguante del traje: nivel %d") % game.suit_lvl_st,
		Lang.t("Mochila: nivel %d") % game.pack_lvl
	]
	for k in ["O", "S", "G", "W", "R", "C"]:
		lines.append("%s: %s %d" % [game._station_name(k), Lang.t("nivel"), int(game.st_lvl[k])])
	for l in lines:
		y += 26.0
		draw_string(font, Vector2(x, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, 280.0, 16, Color(0.9, 0.93, 1.0))
	var hold_txt: String = Lang.t("En mano: %s") % (game._tool_name(game.held) if game.held != "" else Lang.t("nada"))
	draw_string(font, Vector2(x, y + 36.0), hold_txt, HORIZONTAL_ALIGNMENT_LEFT, 280.0, 17, Color(1.0, 0.9, 0.5))
	var foot: String = _desc(hover) if hover != "" else Lang.t("Clic en el kit de parche para ponerlo en la mano ([Q] también). [I] o [Esc] cierra.")
	# el pie ocupa solo la parte izquierda (debajo de las casillas), nunca se cruza con la columna derecha
	draw_line(p.position + Vector2(24.0 + DOLL_W, p.size.y - 78.0), p.position + Vector2(p.size.x - 320.0, p.size.y - 78.0), Color(0.3, 0.4, 0.65), 1.0)
	draw_multiline_string(font, p.position + Vector2(30.0 + DOLL_W, p.size.y - 54.0), foot, HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 370.0 - DOLL_W, 15, 3, Color(0.8, 0.88, 1.0))
