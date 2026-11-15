extends RefCounted
# Texturas y mallas procedurales para los elementos de afuera (rocas, vetas de metal, hielo, polimero).
# Todo se genera por codigo: no usa imagenes externas. Los valores son claros (~0.5-1.0) porque
# se multiplican por el color de cada instancia.

static var _cache: Dictionary = {}


static func _noise(seed_v: int, freq: float, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, oct: int = 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = oct
	return n


static func _field(n: FastNoiseLite, size: int) -> Image:
	# imagen L8 normalizada 0..1 y que repite sin costuras
	return n.get_seamless_image(size, size, false, false, 0.1, true)


static func make(kind: String, size: int, with_normal: bool) -> Array:
	var key: String = "%s_%d_%s" % [kind, size, str(with_normal)]
	if _cache.has(key):
		return _cache[key]
	var h := Image.create(size, size, false, Image.FORMAT_RGBA8)   # altura (para el normal) en R
	var a := Image.create(size, size, false, Image.FORMAT_RGBA8)   # color
	match kind:
		"rock":
			_rock(a, h, size)
		"ore":
			_ore(a, h, size)
		"ice":
			_ice(a, h, size)
		"crate":
			_crate(a, h, size)
	var res: Array = [ImageTexture.create_from_image(a), null]
	if with_normal:
		var nm: Image = h.duplicate()
		nm.bump_map_to_normal_map(3.0 if kind != "crate" else 2.0)
		res[1] = ImageTexture.create_from_image(nm)
	_cache[key] = res
	return res


static func _rock(a: Image, h: Image, size: int) -> void:
	var f1: Image = _field(_noise(11, 0.018, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 5), size)
	var cell := _noise(5, 0.03, FastNoiseLite.TYPE_CELLULAR, 1)
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var f2: Image = _field(cell, size)
	var f3: Image = _field(_noise(23, 0.35, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2), size)
	for y in size:
		for x in size:
			var base: float = f1.get_pixel(x, y).r
			var edge: float = f2.get_pixel(x, y).r
			var spk: float = f3.get_pixel(x, y).r
			var crack: float = smoothstep(0.0, 0.22, edge)
			var v: float = lerpf(0.5, 1.0, base) * (0.72 + 0.28 * crack) * (0.9 + 0.1 * spk)
			if spk > 0.88:
				v *= 1.12
			v = clampf(v, 0.0, 1.0)
			a.set_pixel(x, y, Color(v, v * 0.985, v * 0.96))
			var hv: float = clampf(base * 0.6 + crack * 0.4 + spk * 0.1, 0.0, 1.0)
			h.set_pixel(x, y, Color(hv, hv, hv))


static func _ore(a: Image, h: Image, size: int) -> void:
	# metal rayado: vetas horizontales, rayones y puntos de oxido
	var brush := _noise(31, 0.012, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var f1: Image = _field(brush, size)
	var f2: Image = _field(_noise(47, 0.22, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2), size)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for y in size:
		for x in size:
			var streak: float = f1.get_pixel(x, 0).r   # solo varia con x: bandas verticales
			var m: float = f1.get_pixel((x * 3) % size, (y / 12) % size).r
			var v: float = lerpf(0.5, 0.88, streak * 0.6 + m * 0.4)
			var rust: float = f2.get_pixel(x, y).r
			var c := Color(v, v, v * 1.04)
			if rust > 0.72:
				c = c.lerp(Color(0.78, 0.45, 0.25), (rust - 0.72) * 3.0)
			a.set_pixel(x, y, c)
			h.set_pixel(x, y, Color(v, v, v))
	for i in int(size * 0.35):
		var x0: int = rng.randi() % size
		var y0: int = rng.randi() % size
		var len: int = rng.randi_range(size / 10, size / 3)
		var dx: float = rng.randf_range(-1.0, 1.0)
		var dy: float = rng.randf_range(-1.0, 1.0)
		var d: Vector2 = Vector2(dx, dy).normalized()
		for t in len:
			var px: int = posmod(x0 + int(d.x * t), size)
			var py: int = posmod(y0 + int(d.y * t), size)
			var cc: Color = a.get_pixel(px, py)
			a.set_pixel(px, py, cc.lightened(0.3))
			h.set_pixel(px, py, Color(0.2, 0.2, 0.2))


static func _ice(a: Image, h: Image, size: int) -> void:
	var cell := _noise(7, 0.045, FastNoiseLite.TYPE_CELLULAR, 1)
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var f1: Image = _field(cell, size)
	var f2: Image = _field(_noise(13, 0.02, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 4), size)
	var f3: Image = _field(_noise(29, 0.5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1), size)
	for y in size:
		for x in size:
			var edge: float = f1.get_pixel(x, y).r
			var cl: float = f2.get_pixel(x, y).r
			var sp: float = f3.get_pixel(x, y).r
			var crack: float = 1.0 - smoothstep(0.0, 0.12, edge)    # lineas blancas de fractura
			var v: float = lerpf(0.78, 1.0, cl)
			var c := Color(v * 0.86, v * 0.96, v)
			c = c.lerp(Color(1, 1, 1), crack * 0.85)
			if sp > 0.9:
				c = c.lerp(Color(1, 1, 1), 0.5)
			a.set_pixel(x, y, c)
			var hv: float = clampf(0.5 + (edge - 0.5) * 0.5 + cl * 0.2, 0.0, 1.0)
			h.set_pixel(x, y, Color(hv, hv, hv))


static func _crate(a: Image, h: Image, size: int) -> void:
	# caja de polimero: paneles con bordes, remaches y franja de aviso
	var f1: Image = _field(_noise(61, 0.05, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3), size)
	var f2: Image = _field(_noise(73, 0.4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1), size)
	var half: int = size / 2
	for y in size:
		for x in size:
			var v: float = lerpf(0.82, 1.0, f1.get_pixel(x, y).r) * (0.95 + 0.05 * f2.get_pixel(x, y).r)
			var c := Color(v, v, v)
			var hv: float = 0.6
			# paneles: 2x2 por cara con ranura
			var lx: int = x % half
			var ly: int = y % half
			var bd: int = maxi(1, size / 64)
			if lx < bd or ly < bd:
				c = c.darkened(0.45)
				hv = 0.15
			elif lx < bd * 2 or ly < bd * 2:
				c = c.lightened(0.12)
				hv = 0.8
			# remaches en las esquinas de cada panel
			var rr: int = maxi(2, size / 40)
			var corner: Vector2 = Vector2(float(lx), float(ly))
			for cx in [size / 24 + bd * 3, half - size / 24 - bd * 3]:
				for cy in [size / 24 + bd * 3, half - size / 24 - bd * 3]:
					if corner.distance_to(Vector2(float(cx), float(cy))) < rr:
						c = Color(0.55, 0.55, 0.58)
						hv = 1.0
			# franja diagonal de aviso en la parte baja de la cara
			if y > size - size / 6 and y < size - size / 24:
				if ((x + y) / maxi(size / 16, 2)) % 2 == 0:
					c = Color(0.22, 0.2, 0.18)
				else:
					c = Color(1.0, 0.85, 0.3)
				hv = 0.5
			a.set_pixel(x, y, c)
			h.set_pixel(x, y, Color(hv, hv, hv))


# ---------- suelo con crateres ----------

# craters: Array de Vector4(x, y, radio, 0) en casillas. Devuelve [albedo, normal|null].
# El albedo es gris claro (se multiplica por el color de vertice del terreno).
static func make_ground(craters: Array, tiles_w: int, tiles_h: int, ppt: int, with_normal: bool, relief: float) -> Array:
	var key: String = "ground_%d_%d_%d_%s_%d_%.2f" % [tiles_w, tiles_h, ppt, str(with_normal), craters.size(), relief]
	if craters.size() > 0:
		var c0: Vector4 = craters[0]
		key += "_%.2f_%.2f" % [c0.x, c0.y]
	if _cache.has(key):
		return _cache[key]
	var tw: int = tiles_w * ppt
	var th: int = tiles_h * ppt
	var hf := PackedFloat32Array()
	hf.resize(tw * th)
	hf.fill(0.5)
	var al := PackedByteArray()
	al.resize(tw * th)
	al.fill(236)
	# Perfil radial tabulado (en funcion de u^2, asi no hace falta sqrt por pixel).
	# La altura es proporcional a la profundidad del crater; el albedo no depende del tamano.
	var n_lut: int = 2048
	var u2_max: float = 1.7 * 1.7
	var k_scale: float = float(n_lut) / u2_max
	var h_lut := PackedFloat32Array()
	var a_lut := PackedInt32Array()
	h_lut.resize(n_lut)
	a_lut.resize(n_lut)
	for k in n_lut:
		var u: float = sqrt((float(k) + 0.5) / k_scale)
		var hn: float = 0.0
		var a: float = 0.0
		if u < 1.0:
			hn = -(1.0 - u * u) + 0.45 * 0.94 * smoothstep(0.6, 1.0, u)
			a = -0.06 * (1.0 - u)            # piso un poco mas oscuro
		else:
			var d1: float = (u - 1.04) / 0.16
			hn = 0.45 * exp(-d1 * d1)
			if u < 1.7:
				var ej: float = 1.0 - (u - 1.0) / 0.7
				hn += 0.45 * 0.18 * ej * ej      # manto de eyecciones
				a = 0.07 * ej * ej + 0.05 * exp(-d1 * d1)
		h_lut[k] = hn
		a_lut[k] = int(a * 255.0)
	for cr in craters:
		var c: Vector4 = cr
		var R: float = c.z * float(ppt)
		var cx: float = c.x * float(ppt)
		var cy: float = c.y * float(ppt)
		var reach: float = R * 1.7
		var x0: int = maxi(int(cx - reach), 0)
		var x1: int = mini(int(cx + reach) + 1, tw)
		var y0: int = maxi(int(cy - reach), 0)
		var y1: int = mini(int(cy + reach) + 1, th)
		var depth: float = R * 0.17 * 0.05     # profundidad ~ 1/6 del radio (ya con la escala del relieve)
		var kk: float = k_scale / (R * R)
		for py in range(y0, y1):
			var dy: float = float(py) - cy
			var dy2: float = dy * dy
			var row: int = py * tw
			for px in range(x0, x1):
				var dx: float = float(px) - cx
				var k: int = int((dx * dx + dy2) * kk)
				if k >= n_lut:
					continue
				var i: int = row + px
				hf[i] += h_lut[k] * depth
				al[i] = clampi(al[i] + a_lut[k], 120, 255)
	var res: Array = [null, null]
	var ai: Image = Image.create_from_data(tw, th, false, Image.FORMAT_L8, al)
	res[0] = ImageTexture.create_from_image(ai)
	if with_normal:
		var hi: Image = Image.create_from_data(tw, th, false, Image.FORMAT_RF, hf.to_byte_array())
		hi.bump_map_to_normal_map(relief)
		hi.generate_mipmaps(true)
		res[1] = ImageTexture.create_from_image(hi)
	_cache[key] = res
	return res


# grano fino que se repite (polvo/regolito) para el detalle del suelo
static func make_grain(size: int) -> Array:
	var key: String = "grain_%d" % size
	if _cache.has(key):
		return _cache[key]
	var f1: Image = _field(_noise(71, 0.06, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 4), size)
	var f2: Image = _field(_noise(83, 0.25, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2), size)
	var a := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var v1: float = f1.get_pixel(x, y).r
			var v2: float = f2.get_pixel(x, y).r
			var v: float = 0.86 + 0.14 * (v1 * 0.6 + v2 * 0.4)
			a.set_pixel(x, y, Color(v, v, v))
			var hv: float = v1 * 0.55 + v2 * 0.45
			h.set_pixel(x, y, Color(hv, hv, hv))
	h.bump_map_to_normal_map(2.0)
	var res: Array = [ImageTexture.create_from_image(a), ImageTexture.create_from_image(h)]
	_cache[key] = res
	return res


# ---------- mallas ----------

static func lumpy_mesh(seg: int, amp: float, seed_v: int, flat: bool = true) -> ArrayMesh:
	# roca irregular: esfera deformada con ruido (facetas planas si flat)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = seg
	sm.rings = maxi(seg / 2, 4)
	var arr: Array = sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := _noise(seed_v, 1.1, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var n2 := _noise(seed_v + 5, 3.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	for i in v.size():
		var p: Vector3 = v[i]
		var d: float = 1.0 + amp * n.get_noise_3dv(p * 1.8) + amp * 0.35 * n2.get_noise_3dv(p * 3.0)
		v[i] = p * d
	arr[Mesh.ARRAY_VERTEX] = v
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.deindex()
	if flat:
		st.generate_normals()
	else:
		st.set_smooth_group(-1)
		st.generate_normals()
	return st.commit()


static func crystal_mesh() -> ArrayMesh:
	# prisma hexagonal con punta, de altura 1 centrado en el origen
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: float = 0.5
	var y0: float = -0.5
	var y1: float = 0.18
	var y2: float = 0.5
	var ring0: Array = []
	var ring1: Array = []
	var ring2: Array = []
	for i in 6:
		var an: float = TAU * float(i) / 6.0
		ring0.append(Vector3(cos(an) * r, y0, sin(an) * r))
		ring1.append(Vector3(cos(an) * r, y1, sin(an) * r))
		ring2.append(Vector3(cos(an) * r * 0.22, y2, sin(an) * r * 0.22))
	for i in 6:
		var j: int = (i + 1) % 6
		_quad(st, ring0[i], ring0[j], ring1[j], ring1[i])
		_quad(st, ring1[i], ring1[j], ring2[j], ring2[i])
		st.add_vertex(ring2[i])
		st.add_vertex(ring2[j])
		st.add_vertex(Vector3(0, y2, 0))
		st.add_vertex(ring0[j])
		st.add_vertex(ring0[i])
		st.add_vertex(Vector3(0, y0, 0))
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, c, b, a, d, c]:
		st.add_vertex(p)
