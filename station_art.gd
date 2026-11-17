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

static var anims: Array = []      # [{type, node|mat, st, ...}] animaciones registradas (st = nodo de la estacion)
static var stations: Array = []   # nodos de las estaciones construidas (para saber cual se esta usando)
static var _boost: Dictionary = {}   # id de la estacion -> 0..1 (cuanto reacciona: sube mientras se usa)
static var _flash: Dictionary = {}   # id de la estacion -> 1..0 (destello al terminar la accion)
static var _active: Node3D = null

# v39: modelos de Blender (tools/blender/stations.py) con piezas animables por nombre; tienen prioridad
# sobre los modelos por codigo de este archivo y de view3d.gd. Si falta el .glb, se usa el de codigo.
const GLB_DIR: String = "res://art/3d/base/"
const GLB_CHARS: Array = ["O", "S", "G", "W", "R", "C", "B", "T", "A", "D"]
const BLOB: Dictionary = {"O": 2.6, "S": 2.4, "R": 2.7, "C": 2.6, "G": 2.5, "W": 2.5}
const LED_ON: Dictionary = {"led_green": Color(0.35, 0.85, 0.45), "led_amber": Color(0.9, 0.6, 0.2),
	"led_red": Color(0.85, 0.25, 0.2), "led_blue": Color(0.3, 0.75, 1.0)}


static func reset() -> void:
	anims.clear()
	stations.clear()
	_boost.clear()
	_flash.clear()
	_active = null


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
	var before: int = anims.size()
	if not _build_glb(v, n, ch):
		if not _build_code(v, n, ch):
			return false
	for i in range(before, anims.size()):
		anims[i]["st"] = n
	stations.append(n)
	return true


# ---------- modelo de Blender: art/3d/base/station_X.glb ----------
static func _build_glb(v: Node3D, n: Node3D, ch: String) -> bool:
	if not ch in GLB_CHARS:
		return false
	var path: String = GLB_DIR + "station_" + ch + ".glb"
	if not ResourceLoader.exists(path):
		return false
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return false
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		return false
	if BLOB.has(ch):
		v._blob(n, float(BLOB[ch]))
	n.add_child(inst)
	var leaves: Array = [null, null]
	_wire(v, inst, {}, leaves)
	if leaves[0] != null and leaves[1] != null:
		anims.append({"type": "door", "leaves": leaves, "open": 0.0})
	return true


static func _wire(v: Node3D, node: Node, cache: Dictionary, leaves: Array) -> void:
	# recorre el modelo: registra las piezas animables (anim_*) y cambia los materiales especiales
	var nm: String = str(node.name)
	if nm.begins_with("anim_needle"):
		anims.append({"type": "needle", "node": node, "ph": float(anims.size()) * 1.7})
	elif nm == "anim_solar":
		anims.append({"type": "solar", "node": node})
	elif nm == "anim_dish":
		anims.append({"type": "dish", "node": node, "ph": 0.0})
	elif nm == "anim_coil":
		v.shield_ring = node
		anims.append({"type": "coil", "node": node})
	elif nm == "anim_leaf_l":
		leaves[0] = node
	elif nm == "anim_leaf_r":
		leaves[1] = node
	elif nm.begins_with("anim_fan"):
		anims.append({"type": "fan", "node": node})
	elif nm.begins_with("anim_sway"):
		anims.append({"type": "sway", "node": node, "ph": float(anims.size()) * 1.3})
	elif nm.begins_with("anim_twist"):
		anims.append({"type": "twist", "node": node})
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(i)
				if m == null:
					continue
				var r: Material = _swap(v, m, cache)
				if r != null:
					mi.set_surface_override_material(i, r)
				if m.resource_name == "glass" or m.resource_name == "water":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var s: Vector3 = mi.mesh.get_aabb().size
			if maxf(s.x, maxf(s.y, s.z)) < 0.12:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_wire(v, c, cache, leaves)


static func _swap(v: Node3D, m: Material, cache: Dictionary) -> Material:
	# materiales con nombre especial -> materiales del juego (animables). null = dejar el del .glb
	var key: String = m.resource_name
	if cache.has(key):
		return cache[key]
	var base: Color = Color.WHITE
	if m is BaseMaterial3D:
		base = (m as BaseMaterial3D).albedo_color
	var r: Material = null
	if key.begins_with("screen"):
		r = _emit(base, 0.5)
		anims.append({"type": "screen", "mat": r, "base": 0.5})
	elif key == "core":
		r = _emit(base, 0.6)
		anims.append({"type": "pulse", "mat": r, "base": 0.6, "amp": 0.35, "speed": 1.6})
	elif key.begins_with("led_"):
		var on: Color = LED_ON.get(key, base)
		var off: Color = on.darkened(0.72)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = off
		lm.emission_enabled = true
		lm.emission = off
		v.led_mats.append([lm, on, off])
		r = lm
	elif key == "shield_band":
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.5, 0.36, 0.3)
		sm.metallic = 0.6
		sm.roughness = 0.35
		sm.set_meta("normal", sm.albedo_color)
		v.shield_mat = sm
		r = sm
	elif key == "glass":
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.72, 0.92, 0.95, 0.2)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		gm.metallic = 0.3
		gm.roughness = 0.05
		r = gm
	elif key == "water":
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.18, 0.5, 0.95, 0.78)
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.emission_enabled = true
		wm.emission = Color(0.12, 0.35, 0.7)
		wm.emission_energy_multiplier = 0.35
		wm.roughness = 0.1
		r = wm
		anims.append({"type": "screen", "mat": wm, "base": 0.35})
	elif key == "solar_cell":
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = v._panel_tex()
		pm.albedo_color = Color(0.55, 0.62, 0.85)
		pm.metallic = 0.6
		pm.roughness = 0.25
		r = pm
	cache[key] = r
	return r


# ---------- modelos por codigo (v33) ----------
static func _build_code(v: Node3D, n: Node3D, ch: String) -> bool:
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
	anims.append({"type": "coil", "node": coil})
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


# ---------- estacion en uso: la que esta junto a Wilson mientras hace una tarea (modo 5) ----------
static func _find_active(v: Node3D, g) -> Node3D:
	if int(g.mode) != 5 or bool(g.outside):
		return null
	var pl: Node3D = v.player_node
	if pl == null or not is_instance_valid(pl):
		return null
	var pp: Vector3 = pl.global_position
	var best: Node3D = null
	var bd: float = 3.3
	for s in stations:
		if not is_instance_valid(s):
			continue
		var d: float = Vector2(s.global_position.x - pp.x, s.global_position.z - pp.z).length()
		if d < bd:
			bd = d
			best = s
	return best


# ---------- animaciones (se llaman cada fotograma desde view3d._update_props) ----------
# Cada estacion tiene una animacion discreta en reposo; mientras Wilson la usa, "boost" sube a 1 y la
# animacion se intensifica (pantallas, agujas, bobina, antena, ventilador, plantas, manivela). Al terminar
# la tarea hay un destello ("flash") y un anillo de luz en el suelo.
static func animate(v: Node3D, t: float, dt: float) -> void:
	var g = v.game
	var act: Node3D = _find_active(v, g)
	if act != _active:
		if _active != null and is_instance_valid(_active) and int(g.mode) != 5:
			_flash[_active.get_instance_id()] = 1.0
			if v.has_method("fx_ring"):
				v.fx_ring(_active.global_position + Vector3(0, 0.08, 0), Color(0.55, 0.95, 0.75), 1.2)
		_active = act
	for s in stations:
		if not is_instance_valid(s):
			continue
		var id: int = s.get_instance_id()
		_boost[id] = lerpf(float(_boost.get(id, 0.0)), 1.0 if s == act else 0.0, minf(1.0, dt * 4.0))
		_flash[id] = maxf(0.0, float(_flash.get(id, 0.0)) - dt * 1.4)
	for a in anims:
		var b: float = 0.0
		var f: float = 0.0
		var st = a.get("st")
		if st != null and is_instance_valid(st):
			b = float(_boost.get(st.get_instance_id(), 0.0))
			f = float(_flash.get(st.get_instance_id(), 0.0))
		match str(a["type"]):
			"screen":
				var m: StandardMaterial3D = a["mat"]
				m.emission_energy_multiplier = float(a["base"]) * (0.9 + 0.1 * sin(t * 2.3)) * (1.0 + 1.8 * b) \
					+ b * 0.18 * sin(t * 17.0) + f * 2.5
			"pulse":
				var m2: StandardMaterial3D = a["mat"]
				var sp: float = float(a["speed"]) * (1.0 + 2.0 * b)
				m2.emission_energy_multiplier = float(a["base"]) + float(a["amp"]) * (0.5 + 0.5 * sin(t * sp)) + 0.9 * b + 2.0 * f
			"needle":
				var nd: Node3D = a["node"]
				if is_instance_valid(nd):
					var ph: float = float(a["ph"])
					nd.rotation.z = -0.4 + (0.25 + 0.5 * b) * sin(t * (0.7 + 3.3 * b) + ph) + (0.05 + 0.06 * b) * sin(t * 5.0 + ph)
			"dish":
				var hd: Node3D = a["node"]
				if is_instance_valid(hd):
					if a.has("ph"):
						a["ph"] = float(a["ph"]) + dt * (0.15 + 1.4 * b)
						hd.rotation.y = 0.9 * sin(float(a["ph"]))
					else:
						hd.rotation.y = 0.9 * sin(t * 0.15)
			"coil":
				var cn: Node3D = a["node"]
				if is_instance_valid(cn):
					cn.rotation.y += dt * 6.0 * b   # view3d ya la gira despacio; aqui acelera al usarla
			"fan":
				var fn: Node3D = a["node"]
				if is_instance_valid(fn):
					fn.rotation.y += dt * (2.0 + 14.0 * b)
			"sway":
				var sw: Node3D = a["node"]
				if is_instance_valid(sw):
					var p2: float = float(a["ph"])
					sw.rotation.z = 0.035 * sin(t * 1.2 + p2) + b * 0.07 * sin(t * 5.0 + p2)
					sw.rotation.x = 0.025 * sin(t * 0.9 + p2 * 1.3)
			"twist":
				var tw: Node3D = a["node"]
				if is_instance_valid(tw):
					tw.rotation.z += dt * 9.0 * b
			"solar":
				# sigue la hora del dia (de este a oeste); de noche vuelve al centro
				var mt: Node3D = a["node"]
				if is_instance_valid(mt):
					var h: float = float(g.clock) / 60.0
					var want: float = 0.0
					if h >= 6.0 and h <= 20.0:
						want = lerpf(-0.7, 0.7, (h - 6.0) / 14.0)
					want += b * 0.12 * sin(t * 4.0)   # al usarlo, el panel se reajusta buscando el sol
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
