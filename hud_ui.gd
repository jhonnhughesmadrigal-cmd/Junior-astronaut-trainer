extends PanelContainer
# HUD compacto v27: misión (día/hora/destino), estado ambiental en chips y 6 recursos con icono, nombre, valor y barra fina.
# Solo presenta datos reales del juego; no contiene lógica de simulación.

const DS = preload("res://design_system.gd")

const RES_ICONS: Dictionary = {"oxygen": "oxygen", "energy": "energy", "food": "food", "water": "water", "shield": "shield", "morale": "morale"}
const RES_ORDER: Array = ["oxygen", "energy", "water", "food", "shield", "morale"]

var game = null
var bars: Dictionary = {}
var vals: Dictionary = {}
var icons: Dictionary = {}
var cells: Dictionary = {}
var last: Dictionary = {}
var title: Label
var sub: Label
var chip_row: HFlowContainer
var chips_key: String = ""
var inv_holder: VBoxContainer


func setup(g) -> void:
	game = g
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _style())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# --- misión ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(DS.icon_rect("clock", 18, DS.C_ACCENT))
	title = DS.label("", DS.F_VALUE, DS.C_TEXT, "SemiBold")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	root.add_child(head)
	sub = DS.label("", 12, DS.C_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sub)
	chip_row = HFlowContainer.new()
	chip_row.add_theme_constant_override("h_separation", 4)
	chip_row.add_theme_constant_override("v_separation", 4)
	chip_row.custom_minimum_size = Vector2(252, 0)
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chip_row)
	root.add_child(_sep())
	# --- recursos en 2 columnas ---
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 7)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grid)
	var names: Dictionary = {"oxygen": Lang.t("Oxígeno"), "energy": Lang.t("Energía"), "food": Lang.t("Comida"), "water": Lang.t("Agua"), "shield": Lang.t("Escudo"), "morale": Lang.t("Moral")}
	for k in RES_ORDER:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 3)
		cell.custom_minimum_size = Vector2(122, 0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: TextureRect = DS.icon_rect(RES_ICONS[k], 16, DS.C_DIM)
		icons[k] = ic
		row.add_child(ic)
		var nl: Label = DS.label(str(names[k]), 12, DS.C_DIM)
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nl)
		var vl: Label = DS.label("", 13, DS.C_TEXT, "SemiBold")
		vl.autowrap_mode = TextServer.AUTOWRAP_OFF
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vals[k] = vl
		row.add_child(vl)
		cell.add_child(row)
		var b := ProgressBar.new()
		b.max_value = 100
		b.show_percentage = false
		b.custom_minimum_size = Vector2(0, 5)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_theme_stylebox_override("background", DS.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 3, 0, 0))
		b.add_theme_stylebox_override("fill", DS.box(DS.C_ACCENT, Color(0, 0, 0, 0), 0, 3, 0, 0))
		bars[k] = b
		cell.add_child(b)
		cells[k] = cell
		grid.add_child(cell)
	root.add_child(_sep())
	inv_holder = VBoxContainer.new()
	inv_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inv_holder)


func _sep() -> Control:
	var c := ColorRect.new()
	c.color = Color(DS.C_LINE, 0.8)
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _style() -> StyleBoxFlat:
	var s: StyleBoxFlat = DS.box(Color(0.035, 0.055, 0.10, 0.84), Color(DS.C_LINE_HI, 0.7), 1, DS.R_LG, 12, 10)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	return s


func _chip(text: String, state: String, icon_name: String = "") -> Control:
	var col: Color = DS.state_color(state)
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", DS.box(Color(col, 0.16), Color(col, 0.6), 1, 99, 8, 2))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if icon_name != "":
		h.add_child(DS.icon_rect(icon_name, 12, col))
	var l: Label = DS.label(text, 11, DS.C_TEXT, "Medium")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return p


# Se llama desde main._refresh(): todo sale del estado real del juego.
func refresh() -> void:
	if game == null:
		return
	title.text = Lang.t("Día %d / %d") % [game.day, game.MAX_DAYS] + "  ·  " + game._clock_text()
	sub.text = "%s  ·  %s  ·  %s" % [Lang.loc(game.location), game._phase_name(), game.DIFFICULTIES[game.difficulty]["name"]]
	var tags: Array = []
	if game._is_night():
		tags.append([Lang.t("Noche lunar"), "accent", "moon"])
	if game.storm_left > 0:
		tags.append([Lang.t("Tormenta de polvo"), "warn", "alert"])
	if game.breach:
		tags.append([Lang.t("Brecha en el casco"), "bad", "alert"])
	if game.emg != null and game.emg.has_active():
		tags.append([Lang.t("Emergencia") + " [%s]" % game.key_name("diag"), "bad", "alert"])
	if game.ill_days > 0:
		tags.append([Lang.t("Enfermedad"), "warn", "crew"])
	if game._efficiency() < 1.0:
		tags.append([Lang.t("Cansado"), "warn", "clock"])
	if game.outside:
		tags.append(["EVA", "accent", "planet"])
	var key: String = str(tags)
	if key != chips_key:
		chips_key = key
		for c in chip_row.get_children():
			c.queue_free()
		for t in tags:
			chip_row.add_child(_chip(str(t[0]), str(t[1]), str(t[2])))
		chip_row.visible = not tags.is_empty()
	for k in RES_ORDER:
		var v: float = float(game.res[k])
		var st: String = DS.level_state(v / 100.0)
		var col: Color = DS.C_ACCENT if st == "good" else DS.state_color(st)
		(bars[k] as ProgressBar).value = v
		var fill: StyleBoxFlat = (bars[k] as ProgressBar).get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null and fill.bg_color != col:
			fill.bg_color = col
		var vl: Label = vals[k]
		vl.text = ("! " if st != "good" else "") + "%d %%" % int(round(v))
		(icons[k] as TextureRect).modulate = col if st != "good" else Color(1, 1, 1, 0.85)
		if last.has(k) and absf(v - float(last[k])) >= 1.0 and is_inside_tree():
			var flash: Color = DS.C_GOOD if v > float(last[k]) else DS.C_WARN
			vl.add_theme_color_override("font_color", flash)
			var tw: Tween = vl.create_tween()
			tw.tween_method(func(t: float) -> void: vl.add_theme_color_override("font_color", flash.lerp(DS.C_TEXT, t)), 0.0, 1.0, 0.6)
		last[k] = v
