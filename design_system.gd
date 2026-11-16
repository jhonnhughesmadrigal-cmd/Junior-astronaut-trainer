extends RefCounted
# MISIÓN PERSEO — sistema de diseño v27.
# Una sola fuente de verdad para colores, tipografía, espaciado, radios, estilos y animaciones.
# Estética: azul noche sobrio, superficies por niveles, bordes finos, acento cian con moderación.
# Uso: const DS = preload("res://design_system.gd")  ->  DS.card(1), DS.C_TEXT, DS.icon("oxygen", 20) ...

# ---------- colores ----------
const C_BG: Color = Color(0.027, 0.043, 0.078)          # azul noche profundo (fondos)
const C_SURF1: Color = Color(0.051, 0.082, 0.141)       # panel base
const C_SURF2: Color = Color(0.067, 0.110, 0.188)       # tarjeta
const C_SURF3: Color = Color(0.094, 0.149, 0.251)       # tarjeta elevada / hover
const C_TEAL: Color = Color(0.055, 0.157, 0.188)        # azul petróleo (superficie secundaria)
const C_GRAPHITE: Color = Color(0.102, 0.118, 0.157)    # gris grafito (contenedores neutros)
const C_LINE: Color = Color(0.15, 0.20, 0.29)           # borde fino
const C_LINE_HI: Color = Color(0.22, 0.30, 0.43)        # borde destacado
const C_TEXT: Color = Color(0.949, 0.937, 0.910)        # blanco cálido
const C_DIM: Color = Color(0.604, 0.651, 0.729)         # gris frío (texto secundario)
const C_MUTED: Color = Color(0.43, 0.47, 0.55)          # texto terciario / deshabilitado
const C_ACCENT: Color = Color(0.32, 0.78, 0.91)         # cian: solo información activa e interacción
const C_ACCENT_DIM: Color = Color(0.32, 0.78, 0.91, 0.16)
const C_GOOD: Color = Color(0.36, 0.77, 0.54)           # verde suave
const C_WARN: Color = Color(0.91, 0.69, 0.29)           # ámbar
const C_BAD: Color = Color(0.90, 0.38, 0.30)            # rojo controlado

# ---------- espaciado, radios, bordes ----------
const S1: int = 4
const S2: int = 8
const S3: int = 12
const S4: int = 16
const S5: int = 24
const S6: int = 32
const R_SM: int = 6
const R_MD: int = 10
const R_LG: int = 14
const BORDER: int = 1

# ---------- tipografía (tamaños base; el ajuste de "escala de interfaz" del juego se aplica encima) ----------
const F_TITLE: int = 44
const F_H1: int = 28
const F_H2: int = 20
const F_SUB: int = 16
const F_BODY: int = 16
const F_LABEL: int = 13
const F_VALUE: int = 17
const F_ALERT: int = 18

# ---------- animación ----------
const T_FAST: float = 0.12
const T_BASE: float = 0.2
const T_SLOW: float = 0.32

static var _fonts: Dictionary = {}
static var _icon_cache: Dictionary = {}


# ---------- tipografía ----------

# weight: "Regular" | "Medium" | "SemiBold". Inter (SIL OFL 1.1), recortada a latín. Con respaldo a la fuente por defecto.
static func font(weight: String = "Regular") -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f: Font = ThemeDB.fallback_font
	var path: String = "res://fonts/Inter-%s.otf" % weight
	if ResourceLoader.exists(path):
		var ff: FontFile = load(path) as FontFile
		if ff != null:
			ff.fallbacks = [ThemeDB.fallback_font]
			f = ff
	_fonts[weight] = f
	return f


# ---------- estilos ----------

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = R_MD, mx: int = S4, my: int = S3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = float(mx)
	s.content_margin_right = float(mx)
	s.content_margin_top = float(my)
	s.content_margin_bottom = float(my)
	s.anti_aliasing = true
	return s


# Tarjeta por niveles: 0 = panel base, 1 = tarjeta, 2 = elevada. Sombra muy sutil en 2.
static func card(level: int = 1, radius: int = R_MD, alpha: float = 0.96) -> StyleBoxFlat:
	var bg: Color = [C_SURF1, C_SURF2, C_SURF3][clampi(level, 0, 2)]
	bg.a = alpha
	var s: StyleBoxFlat = box(bg, C_LINE, BORDER, radius, S4, S3)
	if level >= 2:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 2)
	return s


# Tarjeta con acento a la izquierda según estado ("good", "warn", "bad", "accent").
static func status_card(state: String) -> StyleBoxFlat:
	var s: StyleBoxFlat = card(1)
	s.border_color = state_color(state)
	s.border_width_left = 3
	return s


static func state_color(state: String) -> Color:
	match state:
		"good":
			return C_GOOD
		"warn":
			return C_WARN
		"bad":
			return C_BAD
		"accent":
			return C_ACCENT
	return C_DIM


# Valor 0..1 -> estado de alerta (recursos: por debajo de 0.25 aviso, de 0.12 crítico).
static func level_state(frac: float) -> String:
	if frac < 0.12:
		return "bad"
	if frac < 0.28:
		return "warn"
	return "good"


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("Regular")
	t.default_font_size = F_BODY
	var normal: StyleBoxFlat = box(C_SURF2, C_LINE, BORDER, R_MD, S4, S2 + 2)
	var hover: StyleBoxFlat = box(C_SURF3, C_ACCENT, BORDER, R_MD, S4, S2 + 2)
	var pressed: StyleBoxFlat = box(Color(0.10, 0.22, 0.31), C_ACCENT, BORDER, R_MD, S4, S2 + 2)
	var disabled: StyleBoxFlat = box(Color(0.06, 0.08, 0.12, 0.7), Color(0.12, 0.15, 0.21), BORDER, R_MD, S4, S2 + 2)
	var focus: StyleBoxFlat = box(Color(0, 0, 0, 0), C_ACCENT, 2, R_MD, S4, S2 + 2)
	for cls in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, C_TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, C_TEXT)
		t.set_color("font_disabled_color", cls, C_MUTED)
		t.set_font_size("font_size", cls, F_BODY + 1)
		t.set_font("font", cls, font("Medium"))
	t.set_stylebox("panel", "PanelContainer", card(0, R_LG, 0.95))
	t.set_stylebox("panel", "Panel", card(0, R_LG, 0.95))
	t.set_stylebox("tab_selected", "TabContainer", box(C_SURF3, C_ACCENT, BORDER, R_SM, S4, S2))
	t.set_stylebox("tab_unselected", "TabContainer", box(C_SURF1, C_LINE, BORDER, R_SM, S4, S2))
	t.set_stylebox("tab_hovered", "TabContainer", box(C_SURF2, C_LINE_HI, BORDER, R_SM, S4, S2))
	t.set_stylebox("panel", "TabContainer", box(Color(C_SURF1, 0.9), C_LINE, BORDER, R_SM, S4, S3))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", C_DIM)
	t.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	t.set_font_size("font_size", "TabContainer", F_BODY)
	t.set_stylebox("slider", "HSlider", box(C_GRAPHITE, Color(0, 0, 0, 0), 0, 4, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", box(Color(C_ACCENT, 0.75), Color(0, 0, 0, 0), 0, 4, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(C_ACCENT, Color(0, 0, 0, 0), 0, 4, 0, 3))
	t.set_stylebox("background", "ProgressBar", box(C_GRAPHITE, Color(0, 0, 0, 0), 0, 3, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(C_ACCENT, Color(0, 0, 0, 0), 0, 3, 0, 0))
	t.set_stylebox("separator", "HSeparator", box(C_LINE, Color(0, 0, 0, 0), 0, 0, 0, 0))
	t.set_constant("separation", "HSeparator", S3)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_color("font_color", "Label", C_TEXT)
	t.set_font("normal_font", "RichTextLabel", font("Regular"))
	t.set_font("bold_font", "RichTextLabel", font("SemiBold"))
	return t


# ---------- iconografía (SVG propios, trazo uniforme de 2 px en cuadrícula de 24) ----------

const ICON_PATHS: Dictionary = {
	"oxygen": "<circle cx='9' cy='14' r='4.5'/><circle cx='17' cy='8' r='2.5'/><circle cx='18' cy='16' r='1.5'/>",
	"energy": "<path d='M13 2 5 13h6l-1 9 8-11h-6z'/>",
	"water": "<path d='M12 3c3.5 4.5 6 7.5 6 11a6 6 0 0 1-12 0c0-3.5 2.5-6.5 6-11z'/>",
	"food": "<path d='M12 7c-3-3-8-1-8 4 0 5 4 9 8 9s8-4 8-9c0-5-5-7-8-4z'/><path d='M12 7c0-2 1-3 3-4'/>",
	"shield": "<path d='M12 3 5 6v6c0 4.5 3 7.5 7 9 4-1.5 7-4.5 7-9V6z'/>",
	"morale": "<circle cx='12' cy='12' r='9'/><path d='M8 14c1 2 2.2 3 4 3s3-1 4-3'/><path d='M9 9.5v.5M15 9.5v.5'/>",
	"clock": "<circle cx='12' cy='12' r='9'/><path d='M12 7v5l3 2'/>",
	"alert": "<path d='M12 3 2.5 20h19z'/><path d='M12 10v5M12 17.5v.5'/>",
	"crew": "<circle cx='12' cy='8' r='3.5'/><path d='M5 20c0-4 3-6.5 7-6.5s7 2.5 7 6.5'/>",
	"temp": "<path d='M10 14V5a2 2 0 0 1 4 0v9a4 4 0 1 1-4 0z'/>",
	"signal": "<path d='M4 18a11 11 0 0 1 16 0M7.5 18a6 6 0 0 1 9 0'/><circle cx='12' cy='20' r='0.8'/>",
	"map": "<path d='m3 6 6-2 6 2 6-2v14l-6 2-6-2-6 2z'/><path d='M9 4v14M15 6v14'/>",
	"box": "<path d='m3 7 9-4 9 4v10l-9 4-9-4z'/><path d='m3 7 9 4 9-4M12 11v10'/>",
	"tool": "<path d='M14.5 6.5a4 4 0 0 0-5 5L3 18l3 3 6.5-6.5a4 4 0 0 0 5-5l-3 3-2.5-.5-.5-2.5z'/>",
	"book": "<path d='M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z'/><path d='M8 4v16'/>",
	"trophy": "<path d='M8 4h8v5a4 4 0 0 1-8 0zM8 6H4v1a4 4 0 0 0 4 4M16 6h4v1a4 4 0 0 1-4 4M12 13v4M8 20h8'/>",
	"check": "<path d='m5 12.5 4.5 4.5L19 7.5'/>",
	"lock": "<rect x='5' y='11' width='14' height='9' rx='2'/><path d='M8 11V8a4 4 0 0 1 8 0v3'/>",
	"play": "<path d='M7 4v16l13-8z'/>",
	"gear": "<circle cx='12' cy='12' r='3'/><path d='M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2'/>",
	"moon": "<path d='M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z'/>",
	"planet": "<circle cx='12' cy='12' r='6'/><path d='M3 16c3 2 15-3 18-8'/>",
	# v30: controles tactiles
	"jump": "<path d='M12 20V6M6 11l6-6 6 6'/><path d='M7 20h10'/>",
	"hand": "<circle cx='12' cy='12' r='8'/><circle cx='12' cy='12' r='3'/>",
	"pause": "<path d='M9 5v14M15 5v14'/>",
	"camera": "<rect x='3' y='7' width='18' height='13' rx='2'/><circle cx='12' cy='13.5' r='3.5'/><path d='M9 7l1.5-2.5h3L15 7'/>",
	"close": "<path d='M6 6l12 12M18 6 6 18'/>",
}


# Icono como textura (SVG rasterizado una vez por nombre/tamaño/color). Si el SVG no se puede cargar, devuelve null.
static func icon(name: String, size: int = 20, col: Color = C_TEXT) -> Texture2D:
	var key: String = "%s_%d_%s" % [name, size, col.to_html(false)]
	if _icon_cache.has(key):
		return _icon_cache[key]
	if not ICON_PATHS.has(name):
		return null
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>%s</svg>" % [col.to_html(false), ICON_PATHS[name]]
	var img := Image.new()
	var err: int = img.load_svg_from_string(svg, float(size) / 24.0 * 2.0)
	if err != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex


static func icon_rect(name: String, size: int = 20, col: Color = C_TEXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(name, size, col)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---------- componentes pequeños ----------

static func label(text: String, size: int = F_BODY, col: Color = C_TEXT, weight: String = "Regular") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", font(weight))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# Etiqueta de sección: mayúsculas pequeñas, gris frío.
static func caption(text: String) -> Label:
	var l: Label = label(text.to_upper(), F_LABEL, C_DIM, "SemiBold")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


# ---------- animación ----------

# Aparición breve: opacidad + ligero desplazamiento vertical. No bloquea la jugabilidad (≤ 0,2 s).
static func fade_in(c: Control, dur: float = T_BASE, rise: float = 8.0) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw: Tween = c.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur)
	if rise > 0.0:
		var p0: Vector2 = c.position
		c.position = p0 + Vector2(0, rise)
		tw.tween_property(c, "position", p0, dur)


# Pulso corto de escala al confirmar algo.
static func pulse(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	var tw: Tween = c.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2(1.04, 1.04), T_FAST * 0.6)
	tw.tween_property(c, "scale", Vector2.ONE, T_FAST)


# Hover suave del botón: oscurece/aclara con modulate (el cambio de borde lo hace el tema).
static func hover_lift(b: Control) -> void:
	b.mouse_entered.connect(func() -> void:
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "modulate", Color(1.08, 1.08, 1.08), T_FAST))
	b.mouse_exited.connect(func() -> void:
		var tw2: Tween = b.create_tween()
		tw2.tween_property(b, "modulate", Color.WHITE, T_FAST))
