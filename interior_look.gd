extends RefCounted
# v38 — Materiales y detalles del interior de la base (solo dibujo, generado por código).
# Criterio: menos superficies planas y claras, más estructura y profundidad, sin neón.
# - Remates de muro oscuros (antes casi blancos vistos desde arriba: deslumbraban).
# - Costillas estructurales, tuberías con abrazaderas y zócalo con una tira de luz tenue.
# - Equipo pegado a la pared (armarios, pantalla, estantería con cajas): no ocupa casillas
#   transitables más allá de unos centímetros, así que no estorba al caminar.
# - Unas pocas luces cálidas de pared (solo con efectos Medio/Alto) para crear zonas de luz.
# No cambia la lógica del juego.

const T: float = 2.0
const W: int = 16       # ancho del mapa interior (casillas)
const H: int = 10       # alto del mapa interior

static var lights: Array = []


# altura de un muro del perímetro según su fila (misma regla que view3d._build_interior)
static func wall_h(y: int) -> float:
	if y == 9:
		return 1.0
	if y == 3:
		return 1.7
	return 3.2


static func cap_mat(v: Node3D) -> StandardMaterial3D:
	return v._m(Color(0.16, 0.18, 0.22), 0.55, 0.5)


static func build(v: Node3D, parent: Node3D, moon: bool) -> void:
	lights.clear()
	var rib: StandardMaterial3D = v._m(Color(0.2, 0.22, 0.27), 0.6, 0.45)
	var steel: StandardMaterial3D = v._m(Color(0.56, 0.58, 0.62), 0.75, 0.35)
	var pipe_a: StandardMaterial3D = v._m(Color(0.42, 0.36, 0.26), 0.5, 0.5)    # ámbar apagado (paleta DS)
	var pipe_c: StandardMaterial3D = v._m(Color(0.26, 0.38, 0.42), 0.5, 0.5)    # cian apagado
	var dark: StandardMaterial3D = v._m(Color(0.12, 0.13, 0.16), 0.3, 0.6)
	var strip: StandardMaterial3D = v._m(Color(1.0, 0.86, 0.62), 0.0, 0.5, 0.55)
	_skirting(v, parent, dark, strip)
	_ribs(v, parent, rib, steel)
	_pipes(v, parent, steel, pipe_a, pipe_c)
	_equipment(v, parent, moon, dark, steel)
	_wall_lights(v, parent)


# Parte alta de los muros bajos (fila 9 y el tramo de la fila 3 en los laterales). Va dentro del
# nodo del techo, que solo se ve con las cámaras cercanas: desde arriba los muros siguen bajos
# para ver la base, y de cerca ya no se ve el vacío por encima de ellos.
static func build_upper(v: Node3D, ceiling: Node3D, map: Array) -> void:
	var wall: Material = null
	for e in v.int_mats:
		if str(e[1]) == "wall":
			wall = e[0]
	if wall == null:
		return
	var cap: StandardMaterial3D = cap_mat(v)
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			var ch: String = row[x]
			var h0: float = -1.0
			if ch == "#" and (y == 9 or (y == 3 and (x == 0 or x == W - 1))):
				h0 = wall_h(y)
			elif ch == "D" and y == 9:
				h0 = 2.7      # dintel sobre la puerta de la esclusa
			if h0 < 0.0:
				continue
			var hh: float = 3.2 - h0
			var c := Vector3((float(x) + 0.5) * T, h0 + hh / 2.0, (float(y) + 0.5) * T)
			v._add(ceiling, v._box(Vector3(T, hh, T)), wall, c, Vector3.ZERO, false)
			v._add(ceiling, v._box(Vector3(T + 0.06, 0.1, T + 0.06)), cap, Vector3(c.x, 3.25, c.z), Vector3.ZERO, false)


# --- zócalo con tira de luz (perfila el suelo y da profundidad) ---
static func _skirting(v: Node3D, p: Node3D, dark: Material, strip: Material) -> void:
	var L: float = float(W - 2) * T       # 28 m de pared interior a lo ancho
	var D: float = float(H - 2) * T       # 16 m de fondo
	# pared del fondo (z = 2), izquierda (x = 2) y derecha (x = 30)
	v._add(p, v._box(Vector3(L, 0.16, 0.08)), dark, Vector3(T + L / 2.0, 0.08, T + 0.04), Vector3.ZERO, false)
	v._add(p, v._box(Vector3(L, 0.025, 0.03)), strip, Vector3(T + L / 2.0, 0.19, T + 0.05), Vector3.ZERO, false)
	for sx in [T + 0.04, float(W - 1) * T - 0.04]:
		v._add(p, v._box(Vector3(0.08, 0.16, D)), dark, Vector3(sx, 0.08, T + D / 2.0), Vector3.ZERO, false)
		var ox: float = 0.01 if sx < 10.0 else -0.01
		v._add(p, v._box(Vector3(0.03, 0.025, D)), strip, Vector3(sx + ox, 0.19, T + D / 2.0), Vector3.ZERO, false)


# --- costillas estructurales en las uniones de paneles ---
static func _ribs(v: Node3D, p: Node3D, rib: Material, steel: Material) -> void:
	# fondo: entre casillas sin ventana (las ventanas están en x % 3 == 1)
	for k in [3, 6, 9, 12]:
		var x: float = float(k) * T
		_rib(v, p, rib, steel, Vector3(x, 0.0, T + 0.07), 3.2, Vector3(0.2, 0.0, 0.14))
	# laterales: cada 2 casillas, con la altura del tramo más bajo que toca
	for k in [2, 5, 7]:
		var hgt: float = minf(wall_h(k - 1), wall_h(k))
		var z: float = float(k) * T
		_rib(v, p, rib, steel, Vector3(T + 0.07, 0.0, z), hgt, Vector3(0.14, 0.0, 0.2))
		_rib(v, p, rib, steel, Vector3(float(W - 1) * T - 0.07, 0.0, z), hgt, Vector3(0.14, 0.0, 0.2))


static func _rib(v: Node3D, p: Node3D, rib: Material, steel: Material, base: Vector3, hgt: float, sz: Vector3) -> void:
	v._add(p, v._box(Vector3(sz.x, hgt, sz.z)), rib, base + Vector3(0, hgt / 2.0, 0), Vector3.ZERO, false)
	# pletinas metálicas arriba y abajo
	for yy in [0.35, hgt - 0.3]:
		v._add(p, v._box(Vector3(sz.x + 0.04, 0.08, sz.z + 0.04)), steel, base + Vector3(0, yy, 0), Vector3.ZERO, false)


# --- tuberías con abrazaderas ---
static func _pipes(v: Node3D, p: Node3D, steel: Material, pa: Material, pc: Material) -> void:
	var L: float = float(W - 2) * T
	var cx: float = T + L / 2.0
	# fondo, por encima de las ventanas
	_pipe_x(v, p, pa, Vector3(cx, 2.78, T + 0.12), L, 0.06)
	_pipe_x(v, p, pc, Vector3(cx, 2.98, T + 0.1), L, 0.045)
	for k in [3, 6, 9, 12]:
		v._add(p, v._box(Vector3(0.1, 0.36, 0.2)), steel, Vector3(float(k) * T, 2.88, T + 0.1), Vector3.ZERO, false)
	# laterales: dos tramos (el muro baja a 1,7 m en la fila 3)
	for sx in [T + 0.12, float(W - 1) * T - 0.12]:
		for seg in [[T, 3.0 * T], [4.0 * T, float(H - 1) * T]]:
			var z0: float = float(seg[0])
			var z1: float = float(seg[1])
			_pipe_z(v, p, pa if sx < 10.0 else pc, Vector3(sx, 2.82, (z0 + z1) / 2.0), z1 - z0, 0.055)
	# bajante con válvula en la pared derecha (fila 5)
	var vx: float = float(W - 1) * T - 0.14
	v._add(p, v._cyl(0.05, 0.05, 2.6, 12), pc, Vector3(vx, 1.5, 11.2), Vector3.ZERO, false)
	var wheel: MeshInstance3D = v._add(p, v._tor(0.1, 0.16), v._m(Color(0.7, 0.32, 0.25), 0.4, 0.5), Vector3(vx - 0.1, 1.3, 11.2), Vector3(0, 0, PI / 2.0), false)
	wheel.name = "valve"


static func _pipe_x(v: Node3D, p: Node3D, m: Material, c: Vector3, length: float, r: float) -> void:
	v._add(p, v._cyl(r, r, length, 12), m, c, Vector3(0, 0, PI / 2.0), false)


static func _pipe_z(v: Node3D, p: Node3D, m: Material, c: Vector3, length: float, r: float) -> void:
	v._add(p, v._cyl(r, r, length, 12), m, c, Vector3(PI / 2.0, 0, 0), false)


# --- equipo pegado a la pared ---
static func _equipment(v: Node3D, p: Node3D, moon: bool, dark: Material, steel: Material) -> void:
	var white: StandardMaterial3D = v._m(Color(0.8, 0.81, 0.82), 0.2, 0.5)
	var panel: StandardMaterial3D = v._m(Color(0.3, 0.33, 0.4), 0.4, 0.5)
	var xr: float = float(W - 1) * T        # cara interior de la pared derecha (x = 30)
	# armarios de la tripulación (derecha, filas 7–8)
	for i in 3:
		var z: float = 14.4 + float(i) * 1.1
		v._add(p, v._box(Vector3(0.4, 2.0, 1.0)), white if i != 1 else panel, Vector3(xr - 0.2, 1.0, z))
		v._add(p, v._box(Vector3(0.02, 1.8, 0.02)), dark, Vector3(xr - 0.41, 1.0, z + 0.49), Vector3.ZERO, false)
		v._add(p, v._box(Vector3(0.03, 0.3, 0.05)), steel, Vector3(xr - 0.42, 1.15, z + 0.35), Vector3.ZERO, false)
		for s in 3:
			v._add(p, v._box(Vector3(0.02, 0.03, 0.6)), dark, Vector3(xr - 0.41, 1.75 + float(s) * 0.07, z), Vector3.ZERO, false)
	# armario bajo con botiquín (derecha, fila 2; el muro es alto)
	v._add(p, v._box(Vector3(0.45, 1.2, 1.4)), white, Vector3(xr - 0.22, 0.6, 5.0))
	v._add(p, v._box(Vector3(0.47, 0.06, 1.42)), steel, Vector3(xr - 0.22, 1.22, 5.0), Vector3.ZERO, false)
	# cruz verde de primeros auxilios (símbolo genérico, no la cruz roja protegida)
	var green: StandardMaterial3D = v._m(Color(0.25, 0.62, 0.42), 0.0, 0.6, 0.2)
	v._add(p, v._box(Vector3(0.02, 0.26, 0.08)), green, Vector3(xr - 0.46, 0.85, 5.0), Vector3.ZERO, false)
	v._add(p, v._box(Vector3(0.02, 0.08, 0.26)), green, Vector3(xr - 0.46, 0.85, 5.0), Vector3.ZERO, false)
	# pantalla de estado (izquierda, filas 4–5)
	var xl: float = T
	v._add(p, v._box(Vector3(0.12, 1.0, 1.7)), dark, Vector3(xl + 0.06, 1.75, 10.0))
	var scr: StandardMaterial3D = v._m(Color(0.1, 0.22, 0.28), 0.0, 0.3, 0.45)
	v._add(p, v._box(Vector3(0.02, 0.8, 1.5)), scr, Vector3(xl + 0.13, 1.75, 10.0), Vector3.ZERO, false)
	# gráfica sencilla en la pantalla (barras tenues)
	var bar: StandardMaterial3D = v._m(Color(0.45, 0.8, 0.88), 0.0, 0.4, 0.9)
	for i in 6:
		var bh: float = 0.12 + 0.07 * float((i * 5) % 7)
		v._add(p, v._box(Vector3(0.01, bh, 0.14)), bar, Vector3(xl + 0.145, 1.45 + bh / 2.0, 9.4 + float(i) * 0.24), Vector3.ZERO, false)
	# estantería con cajas (izquierda, filas 7–8)
	var shelf_z: float = 16.0
	for sy in [0.05, 0.75, 1.45]:
		v._add(p, v._box(Vector3(0.5, 0.05, 3.0)), steel, Vector3(xl + 0.26, sy, shelf_z), Vector3.ZERO, false)
	for sz in [-1.5, 1.5]:
		v._add(p, v._box(Vector3(0.5, 1.5, 0.05)), steel, Vector3(xl + 0.26, 0.75, shelf_z + sz), Vector3.ZERO, false)
	var box_cols: Array = [Color(0.62, 0.52, 0.32), Color(0.75, 0.76, 0.78), Color(0.32, 0.36, 0.42)]
	var g := RandomNumberGenerator.new()
	g.seed = 38
	for row in 2:
		var zc: float = shelf_z - 1.25
		while zc < shelf_z + 1.2:
			var w: float = g.randf_range(0.35, 0.6)
			var bh2: float = g.randf_range(0.25, 0.5)
			if zc + w > shelf_z + 1.4:
				break
			var bm: StandardMaterial3D = v._m(box_cols[g.randi() % box_cols.size()], 0.05, 0.8)
			v._add(p, v._box(Vector3(0.42, bh2, w)), bm, Vector3(xl + 0.26, 0.08 + float(row) * 0.7 + bh2 / 2.0, zc + w / 2.0))
			zc += w + 0.06
	# rejillas de ventilación en el suelo, junto a las paredes (planas: se puede pisar)
	var grate: StandardMaterial3D = v._m(Color(0.1, 0.11, 0.13), 0.5, 0.6)
	for gp in [Vector3(3.0, 0.012, 5.0), Vector3(28.8, 0.012, 15.0)]:
		v._add(p, v._box(Vector3(0.7, 0.02, 1.2)), grate, gp, Vector3.ZERO, false)
		for i in 5:
			v._add(p, v._box(Vector3(0.6, 0.025, 0.05)), steel, gp + Vector3(0, 0.005, -0.4 + float(i) * 0.2), Vector3.ZERO, false)


# --- luces de pared: aplique visible + luz cálida suave ---
static func _wall_lights(v: Node3D, p: Node3D) -> void:
	var lamp: StandardMaterial3D = v._m(Color(1.0, 0.93, 0.8), 0.0, 0.4, 1.4)
	var housing: StandardMaterial3D = v._m(Color(0.22, 0.24, 0.28), 0.6, 0.45)
	var spots: Array = [
		[Vector3(7.0, 2.45, T + 0.16), Vector3(0, 0, 1)],
		[Vector3(25.0, 2.45, T + 0.16), Vector3(0, 0, 1)],
		[Vector3(T + 0.16, 2.45, 13.0), Vector3(1, 0, 0)],
		[Vector3(float(W - 1) * T - 0.16, 2.45, 7.0 + 6.0), Vector3(-1, 0, 0)],
	]
	# luz central suave y algo más fría (sin aplique: cuelga del techo, que no se ve desde arriba)
	var lc := OmniLight3D.new()
	lc.light_color = Color(0.92, 0.95, 1.0)
	lc.light_energy = 0.8
	lc.light_specular = 0.2
	lc.omni_range = 11.0
	lc.omni_attenuation = 1.6
	lc.position = Vector3(16.0, 3.0, 11.0)
	p.add_child(lc)
	lights.append(lc)
	for s in spots:
		var pos: Vector3 = s[0]
		var n: Vector3 = s[1]
		var horiz: bool = absf(n.z) > 0.5
		v._add(p, v._box(Vector3(0.7 if horiz else 0.16, 0.12, 0.16 if horiz else 0.7)), housing, pos, Vector3.ZERO, false)
		v._add(p, v._box(Vector3(0.6 if horiz else 0.04, 0.05, 0.04 if horiz else 0.6)), lamp, pos + n * 0.07 + Vector3(0, -0.06, 0), Vector3.ZERO, false)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.88, 0.72)
		l.light_energy = 1.5
		l.light_specular = 0.25
		l.omni_range = 9.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.position = pos + n * 0.6 + Vector3(0, -0.2, 0)
		p.add_child(l)
		lights.append(l)


# luces solo con efectos Medio/Alto (en Bajo se ahorra su coste)
static func apply_gfx(fx_idx: int) -> void:
	for l in lights:
		if is_instance_valid(l):
			(l as OmniLight3D).visible = fx_idx >= 1


# v38 — Fusiona las piezas fijas (hijas directas de `parent`, sin hijos propios) que comparten
# material y modo de sombra en una sola malla: muchas menos llamadas de dibujo (importante en
# tabletas y móviles). No toca estaciones, personajes ni puertas (son nodos con hijos).
static func merge_static(parent: Node3D) -> int:
	var groups: Dictionary = {}
	for ch in parent.get_children():
		var mi: MeshInstance3D = ch as MeshInstance3D
		if mi == null or mi.get_child_count() > 0 or mi.mesh == null or mi.material_override == null or not mi.visible:
			continue
		var key: Array = [mi.material_override, mi.cast_shadow]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(mi)
	var removed: int = 0
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list:
			var m: MeshInstance3D = mi
			for s in m.mesh.get_surface_count():
				st.append_from(m.mesh, s, m.transform)
		var merged := MeshInstance3D.new()
		merged.name = "Fusion"
		merged.mesh = st.commit()
		merged.material_override = key[0]
		merged.cast_shadow = key[1]
		parent.add_child(merged)
		for mi in list:
			parent.remove_child(mi)
			(mi as Node).queue_free()
			removed += 1
		removed -= 1
	return removed
