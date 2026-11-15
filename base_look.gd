extends RefCounted
# v28 — Materiales y detalles del exterior de la base (solo dibujo, generado por codigo).
# - Casco: paneles con juntas, remaches y suciedad suave (albedo + normal map triplanar).
# - Detalles planos o pegados al muro (no estorban al caminar): plataforma de aterrizaje,
#   cables por el suelo, equipo junto a la pared y bandera de la mision (diseno propio, sin logotipos).

static var _cache: Dictionary = {}


static func hull_textures(size: int, with_normal: bool) -> Array:
	var key: String = "hull_%d_%s" % [size, str(with_normal)]
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.seed = 77
	n.frequency = 0.02
	n.fractal_octaves = 4
	var nimg: Image = n.get_seamless_image(size, size, false, false, 0.1, true)
	var a := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cell: int = size / 4          # 4 x 4 paneles por textura
	var seam: int = maxi(1, size / 128)
	for y in size:
		for x in size:
			var lx: int = x % cell
			var ly: int = y % cell
			var nv: float = nimg.get_pixel(x, y).r
			var v: float = 0.93 + (nv - 0.5) * 0.08
			var hv: float = 0.6
			# paneles alternos un poco mas claros/oscuros
			if ((x / cell) + (y / cell)) % 2 == 0:
				v *= 0.97
			if lx < seam or ly < seam:
				v *= 0.62
				hv = 0.25
			else:
				# remaches cerca de las juntas
				var rx: int = lx % (cell / 4)
				var near: bool = (ly < seam * 5 and ly > seam * 2) or (lx < seam * 5 and lx > seam * 2)
				if near and rx >= cell / 8 - seam and rx <= cell / 8 + seam:
					v *= 0.85
					hv = 0.8
			a.set_pixel(x, y, Color(v, v, v))
			h.set_pixel(x, y, Color(hv, hv, hv))
	a.generate_mipmaps()
	var res: Array = [ImageTexture.create_from_image(a), null]
	if with_normal:
		h.bump_map_to_normal_map(2.5)
		h.generate_mipmaps()
		res[1] = ImageTexture.create_from_image(h)
	_cache[key] = res
	return res


static func hull_mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	m.metallic_specular = 0.4
	return m


# lv: 0 lisa, 1 textura, 2 textura + relieve
static func apply_hull_tex(m: StandardMaterial3D, lv: int) -> void:
	if lv == 0:
		m.albedo_texture = null
		m.normal_enabled = false
		m.normal_texture = null
		m.uv1_triplanar = false
		return
	var tx: Array = hull_textures(128 if lv == 1 else 256, lv == 2)
	m.albedo_texture = tx[0]
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.21, 0.21, 0.21)   # 4 paneles cada ~4,8 m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if lv == 2:
		m.normal_enabled = true
		m.normal_texture = tx[1]
		m.normal_scale = 0.8
	else:
		m.normal_enabled = false
		m.normal_texture = null


# Detalles alrededor de la base. v: view3d (usa sus utilidades _add/_box/_cyl/_m/_tor).
static func build_details(v: Node3D, parent: Node3D, bx: float, by: float, moon: bool) -> void:
	var T: float = 2.0
	var dark: StandardMaterial3D = v._m(Color(0.2, 0.22, 0.26), 0.5, 0.55)
	var paint: StandardMaterial3D = v._m(Color(0.74, 0.6, 0.3), 0.1, 0.65)   # ambar del sistema de diseno
	var white: StandardMaterial3D = v._m(Color(0.86, 0.87, 0.88), 0.2, 0.5)
	var metal: StandardMaterial3D = v._m(Color(0.62, 0.64, 0.68), 0.75, 0.38)
	# --- plataforma de aterrizaje (al sureste, plana: se puede caminar encima) ---
	# busca un hueco libre ("." en un radio de 3 casillas) para no tapar materiales ni rocas
	var spot := Vector2(bx + 10.0, by + 5.6)
	for cand in [Vector2(bx + 10.0, by + 5.6), Vector2(bx + 11.0, by + 3.0), Vector2(bx - 7.0, by + 5.0), Vector2(bx + 10.0, by + 8.0), Vector2(bx - 8.0, by + 2.0)]:
		var ok: bool = true
		for oy in range(-3, 4):
			for ox in range(-3, 4):
				if v._tile_char(int(cand.x) + ox, int(cand.y) + oy) != ".":
					ok = false
		if ok:
			spot = cand
			break
	var pc := Vector3(spot.x * T, 0.0, spot.y * T)
	pc.y = v.ground_y(pc.x / T, pc.z / T)
	v._add(parent, v._cyl(4.6, 4.8, 0.12, 40), v._m(Color(0.3, 0.31, 0.33), 0.1, 0.85), pc + Vector3(0, 0.06, 0))
	var ring: MeshInstance3D = v._add(parent, v._tor(3.7, 3.95), paint, pc + Vector3(0, 0.12, 0), Vector3.ZERO, false)
	ring.scale = Vector3(1.0, 0.25, 1.0)
	# marcas en cruz
	for a in 2:
		v._add(parent, v._box(Vector3(2.4, 0.02, 0.3)), white, pc + Vector3(0, 0.13, 0), Vector3(0, float(a) * PI / 2.0, 0), false)
	# luces de borde (tenues)
	for i in 8:
		var an: float = TAU * float(i) / 8.0
		v._add(parent, v._box(Vector3(0.12, 0.06, 0.12)), v._m(Color(1.0, 0.86, 0.6), 0.0, 0.4, 0.7), pc + Vector3(cos(an) * 4.5, 0.15, sin(an) * 4.5), Vector3.ZERO, false)
	# --- cables por el suelo: de la base a la plataforma y al oeste ---
	var cab: StandardMaterial3D = v._m(Color(0.12, 0.13, 0.15), 0.1, 0.7)
	var c0 := Vector3((bx + 7.0) * T + 0.3, 0.0, (by + 2.6) * T)
	_cable(v, parent, cab, c0, pc + Vector3(-4.6, 0, -1.0), 12)
	_cable(v, parent, cab, Vector3((bx - 3.0) * T - 0.3, 0.0, (by + 2.4) * T), Vector3((bx - 6.0) * T, 0.0, (by + 2.0) * T), 8)
	# --- equipo pegado a la pared sur (no estorba) ---
	var z1: float = (by + 3.0) * T
	for i in 3:
		var ex: float = (bx - 2.2 + float(i) * 0.7) * T
		v._add(parent, v._box(Vector3(0.9, 0.7, 0.55)), white if i != 1 else dark, Vector3(ex, 0.35, z1 + 0.32))
		v._add(parent, v._box(Vector3(0.92, 0.06, 0.57)), metal, Vector3(ex, 0.72, z1 + 0.32), Vector3.ZERO, false)
	# tanque horizontal y caja electrica junto a la pared este de la esclusa
	var tx: float = (bx + 5.4) * T
	v._add(parent, v._cyl(0.36, 0.36, 1.6, 20), white, Vector3(tx, 0.42, z1 + 0.4), Vector3(0, 0, PI / 2.0))
	for sd in [-1.0, 1.0]:
		v._add(parent, v._box(Vector3(0.1, 0.4, 0.6)), dark, Vector3(tx + sd * 0.55, 0.2, z1 + 0.4), Vector3.ZERO, false)
	v._add(parent, v._box(Vector3(0.6, 0.8, 0.22)), dark, Vector3((bx + 6.4) * T, 1.1, z1 + 0.12))
	v._add(parent, v._box(Vector3(0.12, 0.08, 0.02)), v._m(Color(0.4, 0.85, 0.55), 0.0, 0.4, 0.8), Vector3((bx + 6.4) * T - 0.15, 1.35, z1 + 0.24), Vector3.ZERO, false)
	# --- bandera de la mision (diseno propio: franjas de la paleta, sin logotipos) ---
	var fp := Vector3((bx + 0.6) * T, 0.0, z1 + 0.5)
	v._add(parent, v._cyl(0.035, 0.045, 3.0, 10), metal, fp + Vector3(0, 1.5, 0))
	v._add(parent, v._cyl(0.02, 0.02, 1.3, 8), metal, fp + Vector3(0.65, 2.9, 0), Vector3(0, 0, PI / 2.0), false)
	var cols: Array = [Color(0.05, 0.1, 0.2), Color(0.86, 0.68, 0.26), Color(0.05, 0.1, 0.2)]
	for i in 3:
		# en la Luna la bandera no ondea (no hay aire): queda plana y tensada por la barra
		var flag: MeshInstance3D = v._add(parent, v._box(Vector3(1.25, 0.26, 0.015)), v._m(cols[i], 0.0, 0.8), fp + Vector3(0.66, 2.75 - float(i) * 0.26, 0), Vector3.ZERO, false)
		if not moon:
			flag.rotation = Vector3(0, 0.12 * float(i - 1), 0)
	v._add(parent, v._sph(0.07, 10), white, fp + Vector3(0.3, 2.62, 0.01), Vector3.ZERO, false)


static func _cable(v: Node3D, parent: Node3D, mat: Material, a: Vector3, b: Vector3, segs: int) -> void:
	var prev: Vector3 = a
	prev.y = v.ground_y(a.x / 2.0, a.z / 2.0) + 0.05
	for i in range(1, segs + 1):
		var t: float = float(i) / float(segs)
		var p: Vector3 = a.lerp(b, t)
		p.x += sin(t * 5.0) * 0.35
		p.y = v.ground_y(p.x / 2.0, p.z / 2.0) + 0.05
		var mid: Vector3 = (prev + p) * 0.5
		var d: Vector3 = p - prev
		var mi: MeshInstance3D = v._add(parent, v._box(Vector3(0.07, 0.06, d.length() + 0.04)), mat, mid, Vector3.ZERO, false)
		if d.length() > 0.01:
			mi.look_at_from_position(mid, p, Vector3.UP)
		prev = p
