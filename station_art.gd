extends RefCounted
# v33 — Estaciones de la base con el estilo de la referencia generada con Ludo.ai (solo como
# referencia visual: todo se construye por codigo con primitivas, sin importar imagenes ni modelos).
# Estilo: gris calido metalico, grafito, verde oliva, acentos oxido/ambar, madera en el banco,
# pantallas y pilotos pequenos (sin neon). Animaciones discretas en animate().
# Frentes (igual que los modelos anteriores): O, S, W miran a +Z; C, A, D, T miran a -Z
# (el banco T lo gira view3d 180 grados).

const GREY := Color(0.6, 0.59, 0.56)
const GREY_D := Color(0.42, 0.42, 0.41)
const GRAPH := Color(0.22, 0.22, 0.24)
const OLIVE := Color(0.42, 0.45, 0.36)
const RUST := Color(0.72, 0.42, 0.22)
const AMBER := Color(0.8, 0.58, 0.24)
const WOOD := Color(0.55, 0.38, 0.22)
const BEIGE := Color(0.6, 0.56, 0.49)
const COPPER := Color(0.7, 0.44, 0.26)

static var anims: Array = []      # [{type, node|mat, ...}] animaciones registradas


static func reset() -> void:
	anims.clear()


static func has_style(ch: String) -> bool:
	return ch in ["O", "S", "R", "C", "T", "A", "D"]


static func _emit(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.roughness = 0.4
	return m


static func build(v: Node3D, n: Node3D, ch: String) -> bool:
	if not has_style(ch):
		return false
	var grey: StandardMaterial3D = v._m(GREY, 0.55, 0.42)
	var greyd: StandardMaterial3D = v._m(GREY_D, 0.55, 0.45)
	var graph: StandardMaterial3D = v._m(GRAPH, 0.4, 0.55)
	var rust: StandardMaterial3D = v._m(RUST, 0.3, 0.6)
	match ch:
		"O":
			_oxygen(v, n, grey, greyd, graph, rust)
		"S":
			_solar(v, n, grey, graph)
		"R":
			_shield(v, n, grey, greyd, graph, rust)
		"C":
			_sofa(v, n, graph)
		"T":
			_bench(v, n, grey, graph)
		"A":
			_radio(v, n, grey, greyd, graph)
		"D":
			_door(v, n, grey, greyd, graph)
	return true


# ---------- soporte vital: dos tanques altos + consola ----------
static func _oxygen(v, n: Node3D, grey, greyd, graph, rust) -> void:
	v._blob(n, 2.6)
	v._add(n, v._box(Vector3(1.9, 0.12, 1.2)), graph, Vector3(0, 0.06, 0))
	for i in 2:
		var x: float = -0.62 + float(i) * 0.46
		v._add(n, v._cyl(0.21, 0.21, 1.55, 24), grey, Vector3(x, 0.92, -0.15))
		v._add(n, v._sph(0.21, 20, true), grey, Vector3(x, 1.69, -0.15))
		v._add(n, v._cyl(0.215, 0.215, 0.1, 24), rust, Vector3(x, 0.45, -0.15))
		v._add(n, v._cyl(0.215, 0.215, 0.06, 24), graph, Vector3(x, 1.25, -0.15))
		v._add(n, v._cyl(0.06, 0.07, 0.16, 10), graph, Vector3(x, 1.95, -0.15))
		v._add(n, v._tor(0.05, 0.09), v._m(Color(0.75, 0.22, 0.18), 0.3, 0.5), Vector3(x, 2.05, -0.15), Vector3.ZERO, false)
	# tuberia que une los tanques con la consola
	v._add(n, v._cyl(0.035, 0.035, 1.2, 10), greyd, Vector3(-0.05, 2.0, -0.15), Vector3(0, 0, PI / 2.0), false)
	v._add(n, v._cyl(0.035, 0.035, 0.6, 10), greyd, Vector3(0.55, 1.72, -0.15), Vector3.ZERO, false)
	# consola con pantalla, manometros y botones
	v._add(n, v._box(Vector3(0.78, 1.12, 0.62)), grey, Vector3(0.5, 0.68, 0.0))
	v._add(n, v._box(Vector3(0.82, 0.06, 0.66)), graph, Vector3(0.5, 1.26, 0.0), Vector3.ZERO, false)
	v._add(n, v._box(Vector3(0.56, 0.34, 0.03)), graph, Vector3(0.5, 1.02, 0.31), Vector3.ZERO, false)
	var scr: StandardMaterial3D = _emit(Color(0.38, 0.68, 0.8), 0.45)
	v._add(n, v._box(Vector3(0.48, 0.26, 0.02)), scr, Vector3(0.5, 1.02, 0.33), Vector3.ZERO, false)
	anims.append({"type": "screen", "mat": scr, "base": 0.45})
	for i in 2:
		var gx: float = 0.36 + float(i) * 0.28
		v._add(n, v._cyl(0.09, 0.09, 0.04, 16), graph, Vector3(gx, 0.62, 0.32), Vector3(PI / 2.0, 0, 0), false)
		v._add(n, v._cyl(0.07, 0.07, 0.02, 16), v._m(Color(0.88, 0.86, 0.8), 0.0, 0.5), Vector3(gx, 0.62, 0.345), Vector3(PI / 2.0, 0, 0), false)
		var nd := Node3D.new()
		nd.position = Vector3(gx, 0.62, 0.36)
		n.add_child(nd)
		v._add(nd, v._box(Vector3(0.012, 0.06, 0.01)), v._m(Color(0.75, 0.18, 0.15), 0.0, 0.5), Vector3(0, 0.025, 0), Vector3.ZERO, false)
		anims.append({"type": "needle", "node": nd, "ph": float(i) * 1.7})
	v._led(n, Vector3(0.3, 0.32, 0.33), Color(0.35, 0.85, 0.45), Color(0.08, 0.25, 0.1))
	v._led(n, Vector3(0.45, 0.32, 0.33), Color(0.9, 0.6, 0.2), Color(0.25, 0.15, 0.05))
	v._add(n, v._box(Vector3(0.1, 0.06, 0.03)), v._m(Color(0.7, 0.2, 0.18), 0.2, 0.5), Vector3(0.66, 0.32, 0.33), Vector3.ZERO, false)
	# manguera curva hasta el suelo
	v._add(n, v._tor(0.18, 0.23), graph, Vector3(0.95, 0.3, 0.1), Vector3(0, 0, PI / 2.0), false)


# ---------- panel solar en pie con bateria ----------
static func _solar(v, n: Node3D, grey, graph) -> void:
	v._blob(n, 2.4)
	v._add(n, v._box(Vector3(0.8, 0.14, 0.8)), graph, Vector3(-0.15, 0.07, 0))
	v._add(n, v._box(Vector3(0.42, 0.9, 0.36)), grey, Vector3(-0.15, 0.58, 0))
	var mount := Node3D.new()
	mount.position = Vector3(-0.15, 1.15, 0)
	n.add_child(mount)
	v._add(mount, v._sph(0.1, 12), graph, Vector3.ZERO)
	var pan := Node3D.new()
	mount.add_child(pan)
	pan.rotation = Vector3(-0.6, 0, 0)
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = v._panel_tex()
	pm.albedo_color = Color(0.55, 0.62, 0.85)
	pm.metallic = 0.6
	pm.roughness = 0.25
	v._add(pan, v._box(Vector3(1.4, 0.05, 1.05)), pm, Vector3(0, 0.12, 0))
	var fr: StandardMaterial3D = v._m(Color(0.82, 0.8, 0.76), 0.5, 0.4)
	for zz in [-0.54, 0.54]:
		v._add(pan, v._box(Vector3(1.48, 0.08, 0.06)), fr, Vector3(0, 0.12, zz), Vector3.ZERO, false)
	for xx in [-0.72, 0.72]:
		v._add(pan, v._box(Vector3(0.06, 0.08, 1.1)), fr, Vector3(xx, 0.12, 0), Vector3.ZERO, false)
	anims.append({"type": "solar", "node": mount})
	# bateria con asa y cables
	v._add(n, v._box(Vector3(0.5, 0.42, 0.36)), graph, Vector3(0.6, 0.21, 0.25))
	v._add(n, v._box(Vector3(0.52, 0.05, 0.38)), grey, Vector3(0.6, 0.44, 0.25), Vector3.ZERO, false)
	v._add(n, v._tor(0.06, 0.08), grey, Vector3(0.6, 0.5, 0.25), Vector3(PI / 2.0, 0, 0), false)
	v._led(n, Vector3(0.6, 0.3, 0.44), Color(0.35, 0.85, 0.45), Color(0.08, 0.25, 0.1))
	v._add(n, v._tor(0.22, 0.26), v._m(Color(0.12, 0.12, 0.13), 0.1, 0.7), Vector3(0.25, 0.03, 0.4), Vector3.ZERO, false)


# ---------- generador del escudo: cuerpo con bobina de cobre ----------
static func _shield(v, n: Node3D, grey, greyd, graph, rust) -> void:
	v._blob(n, 2.7)
	v._add(n, v._cyl(0.85, 0.95, 0.22, 8), graph, Vector3(0, 0.11, 0))
	v._add(n, v._cyl(0.55, 0.6, 1.05, 24), grey, Vector3(0, 0.75, 0))
	# banda que parpadea en rojo con una brecha (shield_mat de view3d)
	var sm: StandardMaterial3D = v._m(Color(0.5, 0.28, 0.75), 0.6, 0.35).duplicate() as StandardMaterial3D
	sm.albedo_color = Color(0.5, 0.36, 0.3)
	sm.set_meta("normal", sm.albedo_color)
	v.shield_mat = sm
	v._add(n, v._cyl(0.565, 0.565, 0.12, 24), sm, Vector3(0, 0.5, 0))
	v._add(n, v._cyl(0.565, 0.565, 0.06, 24), rust, Vector3(0, 1.05, 0))
	# bobina: espiras de cobre alrededor de un nucleo
	var coil := Node3D.new()
	coil.position = Vector3(0, 1.62, 0)
	n.add_child(coil)
	var cu: StandardMaterial3D = v._m(COPPER, 0.85, 0.32)
	for k in 6:
		v._add(coil, v._tor(0.4, 0.47), cu, Vector3(0, -0.28 + float(k) * 0.11, 0), Vector3.ZERO, false)
	var core: StandardMaterial3D = _emit(Color(0.95, 0.72, 0.42), 0.6)
	v._add(coil, v._cyl(0.3, 0.3, 0.66, 16), core, Vector3.ZERO, Vector3.ZERO, false)
	v._add(coil, v._cyl(0.48, 0.48, 0.05, 24), graph, Vector3(0, 0.36, 0), Vector3.ZERO, false)
	v.shield_ring = coil
	anims.append({"type": "pulse", "mat": core, "base": 0.6, "amp": 0.35, "speed": 1.6})
	# tanques laterales y panel
	for sx in [-1.0, 1.0]:
		v._add(n, v._cyl(0.14, 0.14, 0.8, 14), greyd, Vector3(0.7 * sx, 0.55, -0.25))
		v._add(n, v._cyl(0.03, 0.03, 0.4, 8), graph, Vector3(0.55 * sx, 0.85, -0.25), Vector3(0, 0, PI / 2.0), false)
	v._add(n, v._box(Vector3(0.36, 0.3, 0.05)), graph, Vector3(0, 0.82, 0.6), Vector3.ZERO, false)
	v._led(n, Vector3(-0.08, 0.85, 0.64), Color(0.35, 0.85, 0.45), Color(0.08, 0.25, 0.1))
	v._led(n, Vector3(0.08, 0.85, 0.64), Color(0.9, 0.6, 0.2), Color(0.25, 0.15, 0.05))


# ---------- zona de descanso: sofa beige, mesita y lampara ----------
static func _sofa(v, n: Node3D, graph) -> void:
	v._blob(n, 2.6)
	var cush: StandardMaterial3D = v._m(BEIGE, 0.0, 0.85)
	var cush2: StandardMaterial3D = v._m(BEIGE.darkened(0.12), 0.0, 0.85)
	var frame: StandardMaterial3D = v._m(Color(0.32, 0.3, 0.28), 0.4, 0.55)
	v._add(n, v._box(Vector3(1.7, 0.18, 0.85)), frame, Vector3(0.15, 0.22, 0.05))
	for sx in [-0.65, 0.95]:
		for sz in [-0.3, 0.38]:
			v._add(n, v._cyl(0.04, 0.04, 0.14, 8), graph, Vector3(sx, 0.07, sz))
	for i in 2:
		var x: float = -0.25 + float(i) * 0.8
		# cojines abombados (capsulas aplastadas), como en la referencia
		var seat: MeshInstance3D = v._add(n, v._cap(0.2, 0.76), cush, Vector3(x, 0.42, -0.02), Vector3(0, 0, PI / 2.0))
		seat.scale = Vector3(0.75, 1.0, 1.6)
		var back: MeshInstance3D = v._add(n, v._cap(0.22, 0.74), cush2, Vector3(x, 0.78, 0.36), Vector3(0, 0, PI / 2.0))
		back.scale = Vector3(1.35, 1.0, 0.6)
	for sx in [-0.7, 1.0]:
		v._add(n, v._box(Vector3(0.16, 0.42, 0.82)), cush2, Vector3(sx, 0.52, 0.05))
	# costuras (bandas oxido)
	v._add(n, v._box(Vector3(1.6, 0.03, 0.02)), v._m(RUST, 0.2, 0.6), Vector3(0.15, 0.3, -0.33), Vector3.ZERO, false)
	# mesita con cajones (izquierda) y lampara de pie (derecha)
	v._add(n, v._box(Vector3(0.45, 0.6, 0.45)), v._m(WOOD.darkened(0.15), 0.1, 0.65), Vector3(-1.05, 0.3, 0.0))
	for k in 2:
		v._add(n, v._box(Vector3(0.38, 0.2, 0.02)), v._m(WOOD, 0.1, 0.6), Vector3(-1.05, 0.2 + float(k) * 0.24, -0.23), Vector3.ZERO, false)
		v._add(n, v._box(Vector3(0.1, 0.025, 0.02)), graph, Vector3(-1.05, 0.2 + float(k) * 0.24, -0.25), Vector3.ZERO, false)
	v._add(n, v._cyl(0.025, 0.025, 1.1, 8), graph, Vector3(1.18, 0.6, 0.25))
	v._add(n, v._cyl(0.12, 0.08, 0.2, 14), v._m(Color(0.9, 0.82, 0.62), 0.0, 0.6, 0.35), Vector3(1.18, 1.2, 0.25), Vector3.ZERO, false)
	v._add(n, v._cyl(0.14, 0.16, 0.04, 14), graph, Vector3(1.18, 0.02, 0.25))


# ---------- banco de trabajo: tablero de madera, cajones, panel de herramientas, tornillo ----------
static func _bench(v, n: Node3D, grey, graph) -> void:
	var wood: StandardMaterial3D = v._m(WOOD, 0.1, 0.65)
	v._add(n, v._box(Vector3(1.9, 0.1, 0.95)), wood, Vector3(0, 1.0, 0))
	v._add(n, v._box(Vector3(1.94, 0.05, 0.99)), graph, Vector3(0, 0.94, 0), Vector3.ZERO, false)
	for sx in [-0.88, 0.88]:
		for sz in [-0.4, 0.4]:
			v._add(n, v._box(Vector3(0.08, 0.94, 0.08)), graph, Vector3(sx, 0.47, sz))
	v._add(n, v._box(Vector3(1.75, 0.05, 0.05)), graph, Vector3(0, 0.2, 0.4), Vector3.ZERO, false)
	# cajonera izquierda (frente -Z)
	v._add(n, v._box(Vector3(0.62, 0.78, 0.82)), v._m(Color(0.35, 0.34, 0.33), 0.4, 0.55), Vector3(-0.55, 0.52, 0))
	for k in 3:
		var y: float = 0.3 + float(k) * 0.24
		v._add(n, v._box(Vector3(0.54, 0.19, 0.02)), v._m(Color(0.45, 0.44, 0.42), 0.4, 0.5), Vector3(-0.55, y, -0.42), Vector3.ZERO, false)
		v._add(n, v._box(Vector3(0.18, 0.03, 0.03)), grey, Vector3(-0.55, y, -0.44), Vector3.ZERO, false)
	# panel perforado con herramientas (detras)
	v._add(n, v._box(Vector3(1.8, 0.85, 0.05)), v._m(Color(0.3, 0.3, 0.31), 0.3, 0.6), Vector3(0, 1.6, 0.45))
	var hole: StandardMaterial3D = v._m(Color(0.16, 0.16, 0.17), 0.0, 0.8)
	for yy in 4:
		for xx in 12:
			v._add(n, v._box(Vector3(0.025, 0.025, 0.01)), hole, Vector3(-0.8 + float(xx) * 0.145, 1.3 + float(yy) * 0.2, 0.42), Vector3.ZERO, false)
	var tcols: Array = [Color(0.72, 0.26, 0.2), Color(0.66, 0.66, 0.68), Color(0.8, 0.58, 0.24), Color(0.66, 0.66, 0.68), Color(0.72, 0.26, 0.2)]
	for i in 5:
		var tx: float = -0.65 + float(i) * 0.32
		var tm: StandardMaterial3D = v._m(tcols[i], 0.5, 0.45)
		v._add(n, v._box(Vector3(0.05, 0.36, 0.03)), tm, Vector3(tx, 1.62, 0.41), Vector3(0, 0, 0.08 * float(i - 2)), false)
		v._add(n, v._box(Vector3(0.12, 0.08, 0.03)), grey, Vector3(tx, 1.82, 0.41), Vector3.ZERO, false)
	# tornillo de banco (derecha, al frente)
	v._add(n, v._box(Vector3(0.3, 0.16, 0.22)), grey, Vector3(0.65, 1.13, -0.3))
	v._add(n, v._box(Vector3(0.3, 0.16, 0.06)), grey, Vector3(0.65, 1.13, -0.48))
	v._add(n, v._cyl(0.025, 0.025, 0.36, 8), graph, Vector3(0.65, 1.13, -0.6), Vector3(PI / 2.0, 0, 0), false)
	v._add(n, v._cyl(0.02, 0.02, 0.24, 8), graph, Vector3(0.65, 1.13, -0.78), Vector3(0, 0, PI / 2.0), false)
	# lampara de trabajo
	v._add(n, v._cyl(0.03, 0.03, 0.5, 8), graph, Vector3(-0.85, 1.28, 0.25))
	v._add(n, v._sph(0.08, 10), v._m(Color(1.0, 0.92, 0.72), 0.0, 0.4, 0.8), Vector3(-0.7, 1.5, 0.15), Vector3.ZERO, false)


# ---------- radio: consola con pantalla, mando y antena parabolica giratoria ----------
static func _radio(v, n: Node3D, grey, greyd, graph) -> void:
	v._add(n, v._box(Vector3(1.2, 0.8, 0.7)), grey, Vector3(0, 0.4, 0.05))
	v._add(n, v._box(Vector3(1.24, 0.06, 0.74)), graph, Vector3(0, 0.82, 0.05), Vector3.ZERO, false)
	# cajon inferior
	v._add(n, v._box(Vector3(0.9, 0.2, 0.02)), greyd, Vector3(0, 0.2, -0.31), Vector3.ZERO, false)
	v._add(n, v._box(Vector3(0.2, 0.03, 0.03)), graph, Vector3(0, 0.2, -0.33), Vector3.ZERO, false)
	# panel inclinado con pantalla, botones y diales
	var pnl := Node3D.new()
	pnl.position = Vector3(0, 0.98, -0.12)
	pnl.rotation = Vector3(-0.5, 0, 0)
	n.add_child(pnl)
	v._add(pnl, v._box(Vector3(1.0, 0.36, 0.08)), greyd, Vector3.ZERO)
	var scr: StandardMaterial3D = _emit(Color(0.85, 0.55, 0.25), 0.45)
	v._add(pnl, v._box(Vector3(0.36, 0.2, 0.02)), scr, Vector3(-0.22, 0.03, -0.05), Vector3.ZERO, false)
	anims.append({"type": "screen", "mat": scr, "base": 0.45})
	for i in 3:
		v._add(pnl, v._cyl(0.05, 0.05, 0.04, 12), graph, Vector3(0.1 + float(i) * 0.13, 0.06, -0.05), Vector3(PI / 2.0, 0, 0), false)
	var bc: Array = [Color(0.75, 0.22, 0.18), Color(0.35, 0.7, 0.4), Color(0.8, 0.58, 0.24)]
	for i in 3:
		v._add(pnl, v._box(Vector3(0.07, 0.05, 0.03)), v._m(bc[i], 0.1, 0.5), Vector3(0.1 + float(i) * 0.13, -0.09, -0.05), Vector3.ZERO, false)
	v._led(n, Vector3(-0.45, 0.72, -0.31), Color(0.35, 0.85, 0.45), Color(0.08, 0.25, 0.1))
	v._led(n, Vector3(-0.32, 0.72, -0.31), Color(0.9, 0.6, 0.2), Color(0.25, 0.15, 0.05))
	# microfono de cuello flexible
	v._add(n, v._cyl(0.015, 0.015, 0.4, 6), graph, Vector3(0.45, 1.05, -0.05), Vector3(0.4, 0, 0), false)
	v._add(n, v._cap(0.04, 0.12), graph, Vector3(0.45, 1.24, -0.14), Vector3(0.4, 0, 0), false)
	# mastil con antena parabolica (gira despacio)
	v._add(n, v._cyl(0.05, 0.06, 0.95, 10), graph, Vector3(-0.35, 1.3, 0.25))
	var head := Node3D.new()
	head.position = Vector3(-0.35, 1.85, 0.25)
	n.add_child(head)
	var dish: MeshInstance3D = v._add(head, v._sph(0.46, 20, true), v._m(Color(0.78, 0.77, 0.74), 0.5, 0.4), Vector3(0, 0.05, 0), Vector3(-1.0, 0, 0))
	dish.scale = Vector3(1.0, 0.45, 1.0)
	v._add(head, v._cyl(0.015, 0.015, 0.36, 6), graph, Vector3(0, 0.22, -0.14), Vector3(-1.0, 0, 0), false)
	v._add(head, v._sph(0.035, 8), v._m(Color(0.75, 0.22, 0.18), 0.0, 0.5), Vector3(0, 0.36, -0.28), Vector3.ZERO, false)
	anims.append({"type": "dish", "node": head})


# ---------- esclusa: marco robusto con esquinas achaflanadas, puerta corredera y franjas ambar ----------
static func _door(v, n: Node3D, grey, greyd, graph) -> void:
	# marco: montantes y travesanos + cuatro chaflanes (aspecto octogonal de la referencia)
	var fz: float = 0.0
	for sx in [-1.0, 1.0]:
		v._add(n, v._box(Vector3(0.4, 2.6, 0.8)), greyd, Vector3(1.0 * sx, 1.55, fz))
	v._add(n, v._box(Vector3(2.4, 0.42, 0.8)), greyd, Vector3(0, 3.06, fz))
	v._add(n, v._box(Vector3(2.4, 0.3, 0.8)), greyd, Vector3(0, 0.15, fz))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			v._add(n, v._box(Vector3(0.5, 0.5, 0.82)), greyd, Vector3(0.78 * sx, 1.55 + 1.22 * sy, fz), Vector3(0, 0, PI / 4.0), false)
	# borde interior oscuro
	v._add(n, v._box(Vector3(1.64, 2.5, 0.7)), v._m(Color(0.08, 0.08, 0.1), 0.0, 0.9), Vector3(0, 1.55, fz + 0.06), Vector3.ZERO, false)
	# dos hojas que se deslizan a los lados
	var amber: StandardMaterial3D = v._m(AMBER, 0.3, 0.55)
	var leaves: Array = []
	for sd in [-1.0, 1.0]:
		var leaf := Node3D.new()
		n.add_child(leaf)
		v._add(leaf, v._box(Vector3(0.82, 2.4, 0.12)), grey, Vector3(0.41 * sd, 1.55, -0.3))
		# franjas diagonales ambar en la parte alta
		for k in 3:
			v._add(leaf, v._box(Vector3(0.1, 0.42, 0.02)), amber, Vector3((0.16 + float(k) * 0.22) * sd, 2.45, -0.37), Vector3(0, 0, -0.65 * sd), false)
		# junta central y paneles
		v._add(leaf, v._box(Vector3(0.04, 2.3, 0.02)), graph, Vector3(0.02 * sd, 1.55, -0.37), Vector3.ZERO, false)
		v._add(leaf, v._box(Vector3(0.6, 0.03, 0.02)), graph, Vector3(0.42 * sd, 2.12, -0.37), Vector3.ZERO, false)
		v._add(leaf, v._box(Vector3(0.6, 0.03, 0.02)), graph, Vector3(0.42 * sd, 0.75, -0.37), Vector3.ZERO, false)
		leaves.append(leaf)
	v._add(leaves[1], v._tor(0.07, 0.11), graph, Vector3(0.16, 1.45, -0.39), Vector3(PI / 2.0, 0, 0), false)
	anims.append({"type": "door", "leaves": leaves, "open": 0.0})
	# panel de control con pilotos
	v._add(n, v._box(Vector3(0.26, 0.5, 0.06)), graph, Vector3(1.0, 1.55, -0.43), Vector3.ZERO, false)
	v._led(n, Vector3(1.0, 1.7, -0.47), Color(0.35, 0.85, 0.45), Color(0.08, 0.25, 0.1))
	v._led(n, Vector3(1.0, 1.55, -0.47), Color(0.9, 0.6, 0.2), Color(0.25, 0.15, 0.05))
	v._led(n, Vector3(1.0, 1.4, -0.47), Color(0.75, 0.22, 0.18), Color(0.25, 0.06, 0.05))
	v._add(n, v._box(Vector3(1.6, 0.05, 0.9)), v._m(Color(0.3, 0.3, 0.32), 0.5, 0.5), Vector3(0, 0.03, -0.1), Vector3.ZERO, false)


# ---------- animaciones (se llaman cada fotograma desde view3d._update_props) ----------
static func animate(v: Node3D, t: float, dt: float) -> void:
	var g = v.game
	for a in anims:
		match str(a["type"]):
			"screen":
				var m: StandardMaterial3D = a["mat"]
				m.emission_energy_multiplier = float(a["base"]) * (0.9 + 0.1 * sin(t * 2.3))
			"pulse":
				var m2: StandardMaterial3D = a["mat"]
				m2.emission_energy_multiplier = float(a["base"]) + float(a["amp"]) * (0.5 + 0.5 * sin(t * float(a["speed"])))
			"needle":
				var nd: Node3D = a["node"]
				if is_instance_valid(nd):
					nd.rotation.z = -0.4 + 0.25 * sin(t * 0.7 + float(a["ph"])) + 0.05 * sin(t * 5.0 + float(a["ph"]))
			"dish":
				var hd: Node3D = a["node"]
				if is_instance_valid(hd):
					hd.rotation.y = 0.9 * sin(t * 0.15)
			"solar":
				# sigue la hora del dia (de este a oeste); de noche vuelve al centro
				var mt: Node3D = a["node"]
				if is_instance_valid(mt):
					var h: float = float(g.clock) / 60.0
					var want: float = 0.0
					if h >= 6.0 and h <= 20.0:
						want = lerpf(-0.7, 0.7, (h - 6.0) / 14.0)
					mt.rotation.y = lerpf(mt.rotation.y, want, minf(1.0, dt * 1.5))
			"door":
				# se abre cuando Wilson esta cerca de la esclusa (dentro de la base) o cruzandola
				var want_o: float = 0.0
				if not bool(g.outside) and g.has_method("_tile"):
					var dp: Vector2 = Vector2(-1, -1)
					if v.has_meta("door_tile"):
						dp = v.get_meta("door_tile")
					var pf: Vector2 = g.pos_f
					if dp.x >= 0.0 and pf.distance_to(dp) < 2.2:
						want_o = 1.0
				if int(g.mode) == 13:
					want_o = 1.0
				a["open"] = lerpf(float(a["open"]), want_o, minf(1.0, dt * 3.0))
				var o: float = float(a["open"])
				var lv: Array = a["leaves"]
				if is_instance_valid(lv[0]):
					(lv[0] as Node3D).position.x = -0.82 * o
					(lv[1] as Node3D).position.x = 0.82 * o
