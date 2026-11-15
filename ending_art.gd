extends Control
# Ilustración animada (dibujada por código) para cada uno de los 11 finales.
# Solo dibuja; no toca el estado del juego.

var eid: String = "heroes"
var t: float = 0.0
var location: String = "Luna"


func setup(ending_id: String, loc: String) -> void:
	eid = ending_id
	location = loc
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


# ---------- utilidades ----------

func _sky(top: Color, bottom: Color, horizon: float) -> void:
	var sz: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, horizon), Vector2(0, horizon)]),
		PackedColorArray([top, top, bottom, bottom]))


func _ground(h: float, col: Color, col2: Color) -> void:
	var sz: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(sz.x, h), Vector2(sz.x, sz.y), Vector2(0, sz.y)]),
		PackedColorArray([col, col, col2, col2]))
	# lomas suaves
	var pts := PackedVector2Array()
	for i in 41:
		var x: float = sz.x * float(i) / 40.0
		pts.append(Vector2(x, h - 6.0 - 8.0 * sin(x * 0.011 + 1.0) - 5.0 * sin(x * 0.027)))
	pts.append(Vector2(sz.x, h + 4.0))
	pts.append(Vector2(0, h + 4.0))
	draw_colored_polygon(pts, col)


func _stars(n: int, limit_y: float, alpha: float = 1.0, twinkle: bool = true) -> void:
	var sd: int = 12345
	for i in n:
		sd = (sd * 1103515245 + 12345) & 0x7fffffff
		var x: float = float(sd % 10000) / 10000.0 * size.x
		sd = (sd * 1103515245 + 12345) & 0x7fffffff
		var y: float = float(sd % 10000) / 10000.0 * limit_y
		var a: float = alpha
		if twinkle:
			a *= 0.5 + 0.5 * sin(t * 2.0 + float(i))
		draw_circle(Vector2(x, y), 1.0 + float(i % 3) * 0.5, Color(1, 1, 1, a))


func _earth(p: Vector2, r: float, dim: float = 1.0) -> void:
	draw_circle(p, r, Color(0.2, 0.45, 0.85) * dim)
	draw_circle(p + Vector2(-r * 0.25, -r * 0.1), r * 0.35, Color(0.3, 0.65, 0.35) * dim)
	draw_circle(p + Vector2(r * 0.35, r * 0.3), r * 0.25, Color(0.3, 0.65, 0.35) * dim)
	draw_arc(p, r, 0.0, TAU, 32, Color(0.7, 0.85, 1.0, 0.5 * dim), 2.0)


func _base(p: Vector2, s: float, lit: bool, flag: bool = false, win_col: Color = Color(1.0, 0.95, 0.65)) -> void:
	# p = centro inferior de la base
	var body := Rect2(p + Vector2(-90, -48) * s, Vector2(180, 48) * s)
	draw_rect(body, Color(0.5, 0.53, 0.62))
	draw_rect(Rect2(body.position, Vector2(body.size.x, 6.0 * s)), Color(0.65, 0.68, 0.78))
	# cupula
	draw_circle(p + Vector2(0, -48) * s, 34.0 * s, Color(0.55, 0.75, 0.95, 0.55))
	draw_arc(p + Vector2(0, -48) * s, 34.0 * s, PI, TAU, 24, Color(0.8, 0.92, 1.0, 0.9), 2.0)
	draw_rect(Rect2(p + Vector2(-40, -48) * s, Vector2(80, 48) * s), Color(0.5, 0.53, 0.62))
	for i in 5:
		var wx: float = -78.0 + float(i) * 34.0
		if wx > -40.0 and wx < 20.0:
			continue
		var wc: Color = win_col if lit else Color(0.08, 0.09, 0.12)
		draw_rect(Rect2(p + Vector2(wx, -34) * s, Vector2(18, 12) * s), wc)
	draw_rect(Rect2(p + Vector2(-10, -26) * s, Vector2(20, 26) * s), Color(0.1, 0.11, 0.16))
	# antena
	draw_line(p + Vector2(70, -48) * s, p + Vector2(70, -84) * s, Color(0.7, 0.7, 0.75), 2.0 * s)
	draw_circle(p + Vector2(70, -86) * s, 3.0 * s, Color(1, 0.3, 0.3) if (int(t * 2.0) % 2 == 0 and lit) else Color(0.4, 0.15, 0.15))
	if flag:
		draw_line(p + Vector2(-100, 0), p + Vector2(-100, -70) * s, Color(0.85, 0.85, 0.85), 2.0 * s)
		var wave: float = 3.0 * sin(t * 3.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-100, -70) * s, p + Vector2(-70, -64 + wave) * s, p + Vector2(-100, -52) * s]), Color(0.9, 0.3, 0.3))


func _astro(p: Vector2, s: float, suit: Color, pose: String = "stand", phase: float = 0.0) -> void:
	# p = pies. pose: stand, wave, sit, slump, arms_out
	var hh: float = 0.0
	if pose == "slump":
		hh = 6.0 * s
	if pose == "sit":
		# sentado: torso inclinado
		draw_rect(Rect2(p + Vector2(-9, -26) * s, Vector2(18, 26) * s), suit)
		draw_rect(Rect2(p + Vector2(-16, -10) * s, Vector2(34, 10) * s), suit.darkened(0.15))
		draw_circle(p + Vector2(2, -34 + 4) * s, 9.0 * s, Color(0.92, 0.94, 1.0))
		draw_circle(p + Vector2(4, -32) * s, 5.0 * s, Color(0.15, 0.2, 0.35))
		return
	# piernas
	draw_rect(Rect2(p + Vector2(-7, -16) * s, Vector2(6, 16) * s), suit.darkened(0.2))
	draw_rect(Rect2(p + Vector2(1, -16) * s, Vector2(6, 16) * s), suit.darkened(0.2))
	# mochila
	draw_rect(Rect2(p + Vector2(-13, -38 + hh / s) * s, Vector2(6, 22) * s), Color(0.75, 0.77, 0.85))
	# torso
	draw_rect(Rect2(p + Vector2(-9, -38 + hh / s) * s, Vector2(18, 24) * s), suit)
	# brazos
	var arm_l: Vector2 = Vector2(-9, -34 + hh / s) * s
	var arm_r: Vector2 = Vector2(9, -34 + hh / s) * s
	match pose:
		"wave":
			draw_line(p + arm_l, p + arm_l + Vector2(-5, 16) * s, suit.darkened(0.1), 5.0 * s)
			draw_line(p + arm_r, p + arm_r + Vector2(8, -10 - 6.0 * sin(t * 6.0 + phase)) * s, suit.darkened(0.1), 5.0 * s)
		"arms_out":
			draw_line(p + arm_l, p + arm_l + Vector2(-16, 8) * s, suit.darkened(0.1), 5.0 * s)
			draw_line(p + arm_r, p + arm_r + Vector2(16, 8) * s, suit.darkened(0.1), 5.0 * s)
		"slump":
			draw_line(p + arm_l, p + arm_l + Vector2(-2, 18) * s, suit.darkened(0.1), 5.0 * s)
			draw_line(p + arm_r, p + arm_r + Vector2(2, 18) * s, suit.darkened(0.1), 5.0 * s)
		_:
			draw_line(p + arm_l, p + arm_l + Vector2(-3, 18) * s, suit.darkened(0.1), 5.0 * s)
			draw_line(p + arm_r, p + arm_r + Vector2(3, 18) * s, suit.darkened(0.1), 5.0 * s)
	# casco
	var hp: Vector2 = p + Vector2(0, -46 + hh / s) * s
	if pose == "slump":
		hp += Vector2(3, 3) * s
	draw_circle(hp, 10.0 * s, Color(0.92, 0.94, 1.0))
	draw_circle(hp + Vector2(2, 0) * s, 6.5 * s, Color(0.15, 0.22, 0.4))
	draw_circle(hp + Vector2(0, -3) * s, 2.0 * s, Color(0.7, 0.85, 1.0, 0.7))


func _ship(p: Vector2, s: float, flame: bool) -> void:
	# nave de rescate vertical, p = base
	draw_rect(Rect2(p + Vector2(-16, -90) * s, Vector2(32, 90) * s), Color(0.9, 0.9, 0.95))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -90) * s, p + Vector2(0, -122) * s, p + Vector2(16, -90) * s]), Color(0.85, 0.3, 0.3))
	draw_circle(p + Vector2(0, -66) * s, 7.0 * s, Color(0.2, 0.35, 0.6))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -20) * s, p + Vector2(-34, 6) * s, p + Vector2(-16, 0)]), Color(0.7, 0.2, 0.2))
	draw_colored_polygon(PackedVector2Array([p + Vector2(16, -20) * s, p + Vector2(34, 6) * s, p + Vector2(16, 0)]), Color(0.7, 0.2, 0.2))
	if flame:
		var fl: float = 22.0 + 8.0 * sin(t * 30.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 0), p + Vector2(0, fl) * s, p + Vector2(9, 0)]), Color(1.0, 0.7, 0.2, 0.9))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 0), p + Vector2(0, fl * 0.6) * s, p + Vector2(5, 0)]), Color(1.0, 0.95, 0.6, 0.95))


func _gear(c: Vector2, r: float, teeth: int, ang: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in teeth * 2:
		var a: float = ang + TAU * float(i) / float(teeth * 2)
		var rr: float = r if i % 2 == 0 else r * 0.78
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	draw_circle(c, r * 0.35, Color(0.08, 0.1, 0.16))


func _sun(c: Vector2, r: float, col: Color, rays: int) -> void:
	for i in rays:
		var a: float = t * 0.25 + TAU * float(i) / float(rays)
		draw_line(c + Vector2(cos(a), sin(a)) * r * 1.25, c + Vector2(cos(a), sin(a)) * r * (1.6 + 0.15 * sin(t * 2.0 + float(i))), Color(col.r, col.g, col.b, 0.55), 3.0)
	draw_circle(c, r * 1.15, Color(col.r, col.g, col.b, 0.18))
	draw_circle(c, r, col)


# ---------- dibujo principal ----------

func _draw() -> void:
	var sz: Vector2 = size
	if sz.x < 10.0:
		return
	var hz: float = sz.y * 0.38
	var cx: float = sz.x * 0.5
	var sc: float = clampf(sz.y / 720.0, 0.7, 1.6)
	var mars: bool = location == "Marte"
	match eid:
		"heroes":
			_sky(Color(0.1, 0.12, 0.35), Color(1.0, 0.7, 0.35), hz)
			_stars(50, hz * 0.6, 0.7)
			_sun(Vector2(cx, hz - 40.0 + 10.0 * sin(t * 0.3)), 46.0 * sc, Color(1.0, 0.86, 0.4), 16)
			_ground(hz, Color(0.62, 0.5, 0.4) if mars else Color(0.55, 0.55, 0.6), Color(0.3, 0.27, 0.28))
			_base(Vector2(cx - 170.0 * sc, hz + 34.0 * sc), 1.2 * sc, true, true)
			var ph: float = fmod(t * 0.12, 1.0)
			_ship(Vector2(cx + 190.0 * sc, hz + 34.0 * sc - (1.0 - ease(ph, 0.4)) * 200.0 * sc), 1.0 * sc, ph < 0.97)
			var hcols: Array = [Color(1.0, 0.62, 0.3), Color(0.4, 0.7, 1.0), Color(0.5, 0.9, 0.5), Color(0.9, 0.5, 0.9)]
			for i in 4:
				_astro(Vector2(cx - 60.0 * sc + float(i) * 40.0 * sc, hz + 52.0 * sc), 1.0 * sc, hcols[i], "wave", float(i))
			for i in 24:
				var a: float = float(i) * 2.4 + t * 0.5
				var px: float = cx + 260.0 * sin(a * 1.3 + float(i))
				var py: float = fmod(t * 40.0 + float(i) * 37.0, hz * 0.9)
				draw_rect(Rect2(Vector2(px, py), Vector2(5, 3)), Color.from_hsv(fmod(float(i) * 0.13, 1.0), 0.6, 1.0, 0.8))
		"hilo":
			_sky(Color(0.12, 0.06, 0.12), Color(0.85, 0.3, 0.2), hz)
			_stars(30, hz * 0.5, 0.6)
			draw_circle(Vector2(cx + 230.0 * sc, hz - 70.0 * sc), 26.0 * sc, Color(1.0, 0.5, 0.3))
			_ground(hz, Color(0.38, 0.27, 0.28) if not mars else Color(0.45, 0.25, 0.2), Color(0.15, 0.1, 0.12))
			var flick: bool = int(t * 4.0) % 5 != 0
			_base(Vector2(cx - 120.0 * sc, hz + 34.0 * sc), 1.3 * sc, flick)
			var sp: float = fmod(t * 0.08, 1.0)
			_ship(Vector2(cx + 150.0 * sc, hz - 70.0 * sc + (1.0 - sp) * -100.0 * sc + 40.0 * sc), 0.5 * sc, true)
			# indicadores: uno casi en cero parpadea
			for i in 6:
				var bx: float = 30.0 + float(i) * 22.0
				var h: float = 46.0 if i != 3 else 6.0 + 4.0 * sin(t * 8.0)
				var col: Color = Color(0.4, 0.75, 1.0) if i != 3 else Color(1.0, 0.25, 0.2)
				draw_rect(Rect2(Vector2(bx, 150.0 * sc - h), Vector2(14, h)), col)
				draw_rect(Rect2(Vector2(bx, 150.0 * sc - 46.0), Vector2(14, 46)), Color(1, 1, 1, 0.15), false, 1.0)
			_astro(Vector2(cx + 30.0 * sc, hz + 48.0 * sc), 1.2 * sc, Color(1.0, 0.62, 0.3), "arms_out")
		"ingenio":
			_sky(Color(0.03, 0.05, 0.14), Color(0.12, 0.18, 0.38), hz)
			_stars(60, hz * 0.8, 0.8)
			_ground(hz, Color(0.28, 0.3, 0.4), Color(0.12, 0.13, 0.2))
			# banco de trabajo
			var bw: Vector2 = Vector2(cx, hz + 60.0 * sc)
			draw_rect(Rect2(bw + Vector2(-170, -34) * sc, Vector2(340, 14) * sc), Color(0.55, 0.4, 0.28))
			draw_rect(Rect2(bw + Vector2(-160, -20) * sc, Vector2(10, 54) * sc), Color(0.4, 0.3, 0.22))
			draw_rect(Rect2(bw + Vector2(150, -20) * sc, Vector2(10, 54) * sc), Color(0.4, 0.3, 0.22))
			_gear(bw + Vector2(-90, -90) * sc, 44.0 * sc, 10, t * 0.8, Color(0.75, 0.78, 0.9))
			_gear(bw + Vector2(-12, -62) * sc, 28.0 * sc, 7, -t * 1.14 + 0.2, Color(0.95, 0.75, 0.3))
			_gear(bw + Vector2(60, -96) * sc, 36.0 * sc, 9, t * 0.9, Color(0.5, 0.85, 0.7))
			# llave inglesa
			draw_line(bw + Vector2(100, -44) * sc, bw + Vector2(150, -44) * sc, Color(0.8, 0.8, 0.85), 8.0 * sc)
			draw_circle(bw + Vector2(98, -44) * sc, 11.0 * sc, Color(0.8, 0.8, 0.85))
			draw_circle(bw + Vector2(94, -44) * sc, 6.0 * sc, Color(0.12, 0.18, 0.38))
			for i in 14:
				var a2: float = fmod(t * 1.5 + float(i) * 0.37, 1.0)
				var sp2: Vector2 = bw + Vector2(-12, -62) * sc + Vector2(cos(float(i) * 2.2), -abs(sin(float(i) * 1.3))) * a2 * 70.0 * sc
				draw_circle(sp2, 2.0, Color(1.0, 0.85, 0.4, 1.0 - a2))
			_astro(bw + Vector2(-200, 40) * sc, 1.3 * sc, Color(1.0, 0.62, 0.3), "wave")
		"unidos":
			_sky(Color(0.15, 0.1, 0.3), Color(0.9, 0.45, 0.45), hz)
			_stars(50, hz * 0.7, 0.8)
			_earth(Vector2(cx + 250.0 * sc, hz * 0.45), 28.0 * sc)
			_ground(hz, Color(0.45, 0.38, 0.45), Color(0.2, 0.15, 0.25))
			var cols: Array = [Color(1.0, 0.62, 0.3), Color(0.4, 0.7, 1.0), Color(0.5, 0.9, 0.5), Color(0.9, 0.5, 0.9)]
			for i in 4:
				var ax: float = cx + (float(i) - 1.5) * 62.0 * sc
				_astro(Vector2(ax, hz + 56.0 * sc), 1.5 * sc, cols[i], "arms_out")
			for i in 3:
				var ax2: float = cx + (float(i) - 1.0) * 62.0 * sc
				draw_line(Vector2(ax2 + 12.0 * sc, hz + 34.0 * sc), Vector2(ax2 + 50.0 * sc, hz + 34.0 * sc), Color(0.85, 0.87, 0.95), 5.0 * sc)
			for i in 10:
				var a3: float = fmod(t * 0.35 + float(i) * 0.1, 1.0)
				var hp: Vector2 = Vector2(cx + (float(i) - 4.5) * 40.0 * sc, hz - 20.0 * sc - a3 * 160.0 * sc)
				draw_circle(hp + Vector2(-3, 0), 4.0, Color(1.0, 0.45, 0.55, 1.0 - a3))
				draw_circle(hp + Vector2(3, 0), 4.0, Color(1.0, 0.45, 0.55, 1.0 - a3))
				draw_colored_polygon(PackedVector2Array([hp + Vector2(-7, 1), hp + Vector2(7, 1), hp + Vector2(0, 10)]), Color(1.0, 0.45, 0.55, 1.0 - a3))
		"supervivientes":
			_sky(Color(0.08, 0.15, 0.38), Color(0.55, 0.75, 0.95), hz)
			_stars(40, hz * 0.5, 0.5)
			_ground(hz, Color(0.62, 0.5, 0.4) if mars else Color(0.6, 0.6, 0.66), Color(0.3, 0.3, 0.36))
			_base(Vector2(cx - 220.0 * sc, hz + 34.0 * sc), 1.0 * sc, true)
			_ship(Vector2(cx + 150.0 * sc, hz + 40.0 * sc), 1.15 * sc, false)
			var cols2: Array = [Color(1.0, 0.62, 0.3), Color(0.4, 0.7, 1.0), Color(0.5, 0.9, 0.5), Color(0.9, 0.5, 0.9)]
			for i in 4:
				_astro(Vector2(cx - 60.0 * sc + float(i) * 44.0 * sc, hz + 56.0 * sc), 1.4 * sc, cols2[i], "wave" if i % 2 == 0 else "stand", float(i))
		"fail_oxygen":
			_sky(Color(0.01, 0.04, 0.08), Color(0.04, 0.16, 0.2), size.y)
			# casco grande con visor
			var hc: Vector2 = Vector2(cx, hz - 20.0 * sc)
			draw_circle(hc, 130.0 * sc, Color(0.85, 0.87, 0.93))
			draw_circle(hc + Vector2(6, 4), 98.0 * sc, Color(0.05, 0.1, 0.18))
			draw_arc(hc + Vector2(6, 4), 98.0 * sc, 0.0, TAU, 40, Color(0.4, 0.55, 0.7), 3.0)
			draw_circle(hc + Vector2(-34, -40) * sc, 14.0 * sc, Color(0.7, 0.85, 1.0, 0.35))
			# medidor vacio
			var gx: Vector2 = hc + Vector2(180, 40) * sc
			draw_arc(gx, 46.0 * sc, PI * 0.8, PI * 2.2, 24, Color(0.5, 0.6, 0.7), 4.0)
			draw_line(gx, gx + Vector2(-34, 22) * sc, Color(1.0, 0.3, 0.25), 3.0)
			draw_string(ThemeDB.fallback_font, gx + Vector2(-12, 64) * sc, "O₂", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * sc), Color(0.6, 0.75, 0.9))
			for i in 16:
				var a4: float = fmod(t * 0.3 + float(i) * 0.0625, 1.0)
				var bp: Vector2 = hc + Vector2(-40.0 + float(i % 5) * 20.0 + 8.0 * sin(t * 2.0 + float(i)), 90.0 - a4 * 260.0) * sc
				draw_arc(bp, (3.0 + float(i % 3) * 2.0) * sc, 0, TAU, 12, Color(0.6, 0.85, 1.0, 0.8 * (1.0 - a4)), 1.5)
		"fail_energy":
			_sky(Color(0.0, 0.0, 0.02), Color(0.03, 0.04, 0.09), hz)
			_stars(80, hz * 0.9, 0.9)
			_ground(hz, Color(0.12, 0.13, 0.18), Color(0.04, 0.04, 0.07))
			_base(Vector2(cx, hz + 50.0 * sc), 1.8 * sc, false)
			# una luz de emergencia que se apaga
			var on: bool = fmod(t, 5.0) < 0.6
			if on:
				draw_circle(Vector2(cx + 70.0 * 1.8 * sc, hz + 50.0 * sc - 86.0 * 1.8 * sc), 6.0 * sc, Color(1.0, 0.2, 0.2))
			# bateria vacia
			var bp2: Vector2 = Vector2(cx - 40.0 * sc, hz * 0.45)
			draw_rect(Rect2(bp2, Vector2(80, 36) * sc), Color(0.7, 0.7, 0.8), false, 3.0)
			draw_rect(Rect2(bp2 + Vector2(80, 10) * sc, Vector2(8, 16) * sc), Color(0.7, 0.7, 0.8))
			draw_rect(Rect2(bp2 + Vector2(4, 4) * sc, Vector2(8, 28) * sc), Color(1.0, 0.25, 0.2, 0.5 + 0.5 * sin(t * 4.0)))
		"fail_food":
			_sky(Color(0.15, 0.12, 0.1), Color(0.4, 0.3, 0.2), hz)
			_ground(hz, Color(0.35, 0.28, 0.2), Color(0.18, 0.13, 0.1))
			# invernadero seco
			var gp: Vector2 = Vector2(cx, hz + 46.0 * sc)
			draw_rect(Rect2(gp + Vector2(-160, -80) * sc, Vector2(320, 80) * sc), Color(0.6, 0.7, 0.7, 0.25))
			draw_rect(Rect2(gp + Vector2(-160, -80) * sc, Vector2(320, 80) * sc), Color(0.7, 0.8, 0.8, 0.7), false, 3.0)
			draw_arc(gp + Vector2(0, -80) * sc, 160.0 * sc, PI, TAU, 24, Color(0.7, 0.8, 0.8, 0.7), 3.0)
			for i in 6:
				var px2: float = -125.0 + float(i) * 50.0
				var sway: float = 3.0 * sin(t * 0.8 + float(i))
				draw_line(gp + Vector2(px2, 0) * sc, gp + Vector2(px2 + 14.0 + sway, -34.0) * sc, Color(0.5, 0.42, 0.2), 3.0 * sc)
				draw_line(gp + Vector2(px2 + 14.0 + sway, -34.0) * sc, gp + Vector2(px2 + 26.0 + sway, -26.0) * sc, Color(0.45, 0.35, 0.18), 3.0 * sc)
				draw_circle(gp + Vector2(px2 + 14.0 + sway, -36.0) * sc, 4.0 * sc, Color(0.4, 0.3, 0.15))
			# plato vacio
			var pp: Vector2 = Vector2(cx, hz * 0.55)
			draw_circle(pp, 50.0 * sc, Color(0.8, 0.8, 0.85))
			draw_circle(pp, 36.0 * sc, Color(0.3, 0.28, 0.3))
			draw_line(pp + Vector2(-90, 0) * sc, pp + Vector2(-60, 0) * sc, Color(0.8, 0.8, 0.85), 4.0 * sc)
			draw_line(pp + Vector2(60, 0) * sc, pp + Vector2(90, 0) * sc, Color(0.8, 0.8, 0.85), 4.0 * sc)
		"fail_water":
			_sky(Color(0.35, 0.22, 0.12), Color(0.8, 0.55, 0.3), hz)
			_sun(Vector2(cx + 220.0 * sc, hz * 0.4), 34.0 * sc, Color(1.0, 0.85, 0.5), 10)
			_ground(hz, Color(0.62, 0.42, 0.25), Color(0.3, 0.2, 0.12))
			# grietas
			var sd: int = 7
			for i in 14:
				sd = (sd * 1103515245 + 12345) & 0x7fffffff
				var x0: float = float(sd % 1000) / 1000.0 * sz.x
				var y0: float = hz + 12.0 + float(i % 5) * 24.0 * sc
				var p0: Vector2 = Vector2(x0, y0)
				for k in 4:
					sd = (sd * 1103515245 + 12345) & 0x7fffffff
					var p1: Vector2 = p0 + Vector2(float(sd % 60) - 30.0, 10.0 + float((sd / 7) % 16))
					draw_line(p0, p1, Color(0.15, 0.09, 0.05), 2.0)
					p0 = p1
			# gota vacia
			var dp: Vector2 = Vector2(cx, hz * 0.62 + 4.0 * sin(t * 1.5))
			var pts: PackedVector2Array = PackedVector2Array()
			for i in 25:
				var a5: float = TAU * float(i) / 24.0
				var r2: float = 42.0 * sc
				pts.append(dp + Vector2(sin(a5) * r2 * 0.8, -cos(a5) * r2 * (1.0 if cos(a5) < 0.0 else 0.8) * 1.0 + 8.0 * sc))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.75, 0.9, 1.0), 3.0)
			draw_line(dp + Vector2(-70, 40) * sc, dp + Vector2(70, 40) * sc, Color(0.2, 0.12, 0.08), 3.0)
		"fail_shield":
			_sky(Color(0.02, 0.07, 0.03), Color(0.1, 0.22, 0.05), size.y)
			var rc: Vector2 = Vector2(cx, hz - 10.0 * sc)
			var pulse: float = 0.7 + 0.3 * sin(t * 3.0)
			for ring in 4:
				draw_circle(rc, (70.0 + float(ring) * 34.0) * sc * pulse, Color(0.8, 1.0, 0.2, 0.06))
			for blade in 3:
				var a6: float = t * 0.4 + TAU * float(blade) / 3.0
				var pts2: PackedVector2Array = PackedVector2Array([rc])
				for k in 13:
					var aa: float = a6 - PI / 6.0 + (PI / 3.0) * float(k) / 12.0
					pts2.append(rc + Vector2(cos(aa), sin(aa)) * 100.0 * sc)
				draw_colored_polygon(pts2, Color(1.0, 0.9, 0.1, 0.9))
			draw_circle(rc, 18.0 * sc, Color(1.0, 0.9, 0.1))
			draw_circle(rc, 11.0 * sc, Color(0.05, 0.1, 0.03))
			for i in 30:
				var a7: float = fmod(t * 0.6 + float(i) * 0.033, 1.0)
				var ang: float = float(i) * 0.7
				var from: Vector2 = rc + Vector2(cos(ang), sin(ang)) * (260.0 * sc) * (1.0 - a7)
				draw_line(from, from + Vector2(cos(ang), sin(ang)) * 14.0, Color(0.7, 1.0, 0.3, 0.8 * a7), 2.0)
			_ground(hz + 70.0 * sc, Color(0.08, 0.1, 0.07), Color(0.03, 0.04, 0.03))
			_base(Vector2(cx, hz + 118.0 * sc), 0.9 * sc, true, false, Color(0.7, 1.0, 0.3))
		"fail_morale":
			_sky(Color(0.1, 0.11, 0.16), Color(0.35, 0.38, 0.46), hz)
			_stars(30, hz * 0.7, 0.35, false)
			_earth(Vector2(cx + 260.0 * sc, hz * 0.35), 16.0 * sc, 0.45)
			_ground(hz, Color(0.3, 0.32, 0.38), Color(0.12, 0.13, 0.18))
			_base(Vector2(cx - 220.0 * sc, hz + 30.0 * sc), 1.0 * sc, false)
			_astro(Vector2(cx + 20.0 * sc, hz + 56.0 * sc), 1.8 * sc, Color(0.55, 0.6, 0.75), "sit")
			for i in 60:
				var rx: float = fmod(float(i) * 97.0, sz.x)
				var ry: float = fmod(t * 120.0 + float(i) * 53.0, sz.y)
				draw_line(Vector2(rx, ry), Vector2(rx - 3.0, ry + 12.0), Color(0.7, 0.75, 0.9, 0.25), 1.0)
		_:
			_sky(Color(0.05, 0.06, 0.12), Color(0.1, 0.12, 0.22), size.y)
