extends RefCounted
# Texturas procedurales del interior de la nave (suelo, paredes y techo). Se generan por codigo.
# Cada funcion devuelve [albedo, normal]; el normal es null si with_normal es false.
# El suelo y el techo cubren 4 x 4 m; la pared cubre 4 m de ancho x 4 m de alto (se repiten por
# triplanar en el mundo), asi las costuras coinciden con las casillas de 2 m del mapa.

static var _cache: Dictionary = {}


static func _hash(a: int, b: int, s: int) -> float:
	var h: int = (a * 374761393 + b * 668265263 + s * 2147483647) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h % 10000) / 10000.0


static func _noise(seed_v: int, freq: float, oct: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = oct
	return n.get_seamless_image(128, 128, false, false, 0.1, true)


static func _finish(a: Image, h: Image, with_normal: bool, bump: float) -> Array:
	a.generate_mipmaps()
	var res: Array = [ImageTexture.create_from_image(a), null]
	if with_normal:
		var nm: Image = h.duplicate()
		nm.bump_map_to_normal_map(bump)
		nm.generate_mipmaps()
		res[1] = ImageTexture.create_from_image(nm)
	return res


static func make(kind: String, moon: bool, size: int, with_normal: bool) -> Array:
	var key: String = "%s_%s_%d_%s" % [kind, str(moon), size, str(with_normal)]
	if _cache.has(key):
		return _cache[key]
	var a := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var res: Array = []
	match kind:
		"floor":
			_floor(a, h, size, moon)
			res = _finish(a, h, with_normal, 2.5)
		"wall":
			_wall(a, h, size, moon)
			res = _finish(a, h, with_normal, 2.0)
		"fabric":
			_fabric(a, h, size)
			res = _finish(a, h, with_normal, 1.2)
		_:
			_ceiling(a, h, size)
			res = _finish(a, h, with_normal, 1.5)
	_cache[key] = res
	return res


static func _floor(a: Image, h: Image, size: int, moon: bool) -> void:
	var base: Color = Color(0.46, 0.49, 0.58) if moon else Color(0.60, 0.40, 0.33)
	var stain: Image = _noise(7, 0.03, 4)
	var grain: Image = _noise(19, 0.4, 2)
	var T: float = float(size) * 0.5          # una placa = una casilla (2 m)
	var inv: float = 1.0 / T
	for y in size:
		for x in size:
			var tx: int = int(x / T)
			var ty: int = int(y / T)
			var u: float = fposmod(float(x), T) * inv
			var v: float = fposmod(float(y), T) * inv
			var d: float = minf(minf(u, 1.0 - u), minf(v, 1.0 - v))   # distancia al borde (0..0.5)
			var hv: float = _hash(tx, ty, 3)
			var sh: float = (hv - 0.5) * 0.10
			var st: float = stain.get_pixel(x % 128, y % 128).r
			var gr: float = grain.get_pixel(x % 128, y % 128).r
			var k: float = (0.86 + 0.18 * st) * (0.96 + 0.06 * gr) + sh
			var c: Color = Color(base.r * k, base.g * k, base.b * k)
			var ht: float = 0.5
			# placa con relieve antideslizante en algunas casillas
			if hv < 0.38 and d > 0.07:
				var p1: float = absf(fposmod((u + v) * 7.0, 1.0) - 0.5)
				var p2: float = absf(fposmod((u - v) * 7.0, 1.0) - 0.5)
				var dia: float = smoothstep(0.30, 0.14, p1 + p2 * 0.0) * smoothstep(0.30, 0.14, p2)
				c = c.lightened(0.10 * dia)
				ht = 0.5 + 0.28 * dia
			elif d > 0.075 and d < 0.095:
				c = c.darkened(0.16)      # borde interior hundido
				ht = 0.36
			# costura entre placas
			if d < 0.010:
				c = c.darkened(0.55)
				ht = 0.05
			elif d < 0.022:
				c = c.lightened(0.07) if (u < 0.5 and v < 0.5) else c.darkened(0.12)
				ht = 0.4
			# remaches en las esquinas
			var rv: float = INF
			for cx in [0.10, 0.90]:
				for cy in [0.10, 0.90]:
					rv = minf(rv, Vector2(u - cx, v - cy).length())
			if rv < 0.030:
				c = Color(0.78, 0.80, 0.88)
				ht = 0.95
			elif rv < 0.040:
				c = c.darkened(0.3)
				ht = 0.3
			a.set_pixel(x, y, c)
			h.set_pixel(x, y, Color(ht, ht, ht))


static func _wall(a: Image, h: Image, size: int, moon: bool) -> void:
	var base: Color = Color(0.30, 0.34, 0.44) if moon else Color(0.40, 0.31, 0.32)
	var stain: Image = _noise(31, 0.025, 4)
	var grain: Image = _noise(43, 0.45, 2)
	var P: float = float(size) * 0.5          # un panel = 2 m de ancho
	for y in size:
		for x in size:
			var pxi: int = int(x / P)
			var u: float = fposmod(float(x), P) / P          # 0..1 dentro del panel
			var m: float = 4.0 * (1.0 - float(y) / float(size))  # altura en metros (0 suelo, 4 arriba)
			var hv: float = _hash(pxi, 5, 8)
			var st: float = stain.get_pixel(x % 128, y % 128).r
			var gr: float = grain.get_pixel(x % 128, y % 128).r
			var k: float = (0.88 + 0.16 * st) * (0.97 + 0.05 * gr)
			# suciedad y sombra en la base
			k *= 0.80 + 0.20 * smoothstep(0.0, 1.0, m)
			var c: Color = Color(base.r * k, base.g * k, base.b * k)
			var ht: float = 0.5
			var edge: float = minf(u, 1.0 - u) * 2.0   # metros al borde vertical del panel (0..2 -> 0..1)
			var edge_m: float = minf(u, 1.0 - u) * 2.0
			if m < 0.30:
				# zocalo oscuro con franjas de aviso en algunos paneles
				c = Color(0.16, 0.17, 0.21) * (0.85 + 0.3 * gr)
				c.a = 1.0
				ht = 0.62
				if hv < 0.45:
					var band: float = fposmod((float(x) + float(y)) / float(size) * 28.0, 1.0)
					if band < 0.5:
						c = Color(0.95, 0.78, 0.12) * (0.85 + 0.15 * gr)
						c.a = 1.0
			elif m < 1.20:
				c = c.darkened(0.10)
				ht = 0.44
			elif m < 2.90:
				ht = 0.52
				# marco hundido en cada panel
				var inset: float = minf(edge_m - 0.14, minf(m - 1.34, 2.76 - m))
				if inset > -0.015 and inset < 0.015:
					c = c.darkened(0.28)
					ht = 0.30
				# rejilla de ventilacion en algunos paneles
				if hv > 0.7 and absf(u - 0.5) < 0.17 and m > 1.7 and m < 2.35:
					var slot: float = fposmod((m - 1.7) * 14.0, 1.0)
					if slot < 0.55:
						c = Color(0.06, 0.07, 0.10)
						ht = 0.10
					else:
						c = c.lightened(0.10)
						ht = 0.58
				# placa con luz indicadora en otros
				if hv < 0.22 and Vector2(u - 0.5, (m - 2.1) / 2.0).length() < 0.03:
					c = Color(0.3, 1.0, 0.5)
					ht = 0.8
			else:
				c = c.lightened(0.10)
				ht = 0.58
			# costuras horizontales
			for sm in [0.30, 1.20, 2.90]:
				var dm: float = absf(m - sm)
				if dm < 0.018:
					c = c.darkened(0.55)
					ht = 0.05
				elif dm < 0.04 and m > sm:
					c = c.lightened(0.07)
			# costura vertical entre paneles y remaches
			if edge_m < 0.014:
				c = c.darkened(0.55)
				ht = 0.05
			elif edge_m < 0.034:
				c = c.lightened(0.06) if u < 0.5 else c.darkened(0.12)
			var rvx: float = minf(edge_m, 2.0 - edge_m)
			if edge_m > 0.05 and edge_m < 0.13:
				for ry in [0.45, 0.75, 1.35, 2.15, 2.75, 3.1]:
					if absf(m - ry) < 0.026 and absf(edge_m - 0.09) < 0.026:
						c = Color(0.78, 0.80, 0.88)
						ht = 0.95
			a.set_pixel(x, y, c)
			h.set_pixel(x, y, Color(ht, ht, ht))


static func _ceiling(a: Image, h: Image, size: int) -> void:
	var stain: Image = _noise(57, 0.03, 3)
	var T: float = float(size) * 0.25          # placas de 1 m
	for y in size:
		for x in size:
			var u: float = fposmod(float(x), T) / T
			var v: float = fposmod(float(y), T) / T
			var d: float = minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var st: float = stain.get_pixel(x % 128, y % 128).r
			var k: float = 0.88 + 0.16 * st
			var c: Color = Color(0.24, 0.27, 0.35) * k
			c.a = 1.0
			var ht: float = 0.5
			if d < 0.02:
				c = c.darkened(0.5)
				ht = 0.1
			elif d < 0.05:
				c = c.lightened(0.06)
				ht = 0.45
			a.set_pixel(x, y, c)
			h.set_pixel(x, y, Color(ht, ht, ht))


static func _fabric(a: Image, h: Image, size: int) -> void:
	# trama de tela con costuras acolchadas suaves (casi blanca: se tine con el color del material)
	var noise: Image = _noise(77, 0.5, 2)
	var cells: float = 24.0
	for y in size:
		for x in size:
			var u: float = fposmod(float(x) / float(size) * cells, 1.0)
			var v: float = fposmod(float(y) / float(size) * cells, 1.0)
			var wx: float = 0.5 + 0.5 * sin(u * TAU)
			var wy: float = 0.5 + 0.5 * sin(v * TAU)
			var weave: float = ((wx if (int(float(x) / float(size) * cells) + int(float(y) / float(size) * cells)) % 2 == 0 else wy))
			var n: float = noise.get_pixel(x % 128, y % 128).r
			var k: float = 0.88 + 0.08 * weave + 0.06 * n
			# acolchado: surcos suaves cada 1/4 de la textura
			var q: float = absf(fposmod(float(y) / float(size) * 4.0, 1.0) - 0.5) * 2.0
			var quilt: float = smoothstep(0.82, 1.0, q)
			k *= 1.0 - 0.18 * quilt
			a.set_pixel(x, y, Color(k, k, k))
			var ht: float = 0.45 + 0.3 * weave - 0.25 * quilt
			h.set_pixel(x, y, Color(ht, ht, ht))
