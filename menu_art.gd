extends RefCounted
# Ilustraciones procedurales originales para el menú (sin imágenes externas): planetas y paisajes.
# Todo se genera por código con ruido; se cachea por tipo y tamaño.

static var _cache: Dictionary = {}


static func _noise(seed_v: int, freq: float, oct: int = 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = oct
	return n


# Esfera iluminada de la Luna ("Luna") o Marte ("Marte"). Fondo transparente.
static func planet(kind: String, size: int = 256) -> Texture2D:
	var key: String = "p_%s_%d" % [kind, size]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var moon: bool = (kind == "Luna")
	var nz: FastNoiseLite = _noise(11 if moon else 23, 2.4)
	var nz2: FastNoiseLite = _noise(5, 9.0, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if moon else 19
	var craters: Array = []
	for i in (46 if moon else 22):
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * 0.9
		craters.append([cos(a) * r, sin(a) * r, rng.randf_range(0.02, 0.09 if moon else 0.07)])
	var light: Vector3 = Vector3(-0.55, -0.45, 0.7).normalized()
	var base: Color = Color(0.62, 0.62, 0.60) if moon else Color(0.62, 0.30, 0.17)
	var dark: Color = Color(0.30, 0.31, 0.33) if moon else Color(0.34, 0.15, 0.09)
	var c: float = float(size) / 2.0
	for y in size:
		for x in size:
			var nx: float = (float(x) + 0.5 - c) / c
			var ny: float = (float(y) + 0.5 - c) / c
			var d2: float = nx * nx + ny * ny
			if d2 > 1.0:
				continue
			var nzv: float = sqrt(1.0 - d2)
			var normal := Vector3(nx, ny, nzv)
			var h: float = nz.get_noise_3d(nx * 1.4, ny * 1.4, nzv * 1.4) * 0.5 + 0.5
			var det: float = nz2.get_noise_3d(nx * 2.0, ny * 2.0, nzv * 2.0)
			var col: Color = dark.lerp(base, smoothstep(0.35, 0.65, h))
			col = col * (0.92 + det * 0.10)
			var shade: float = 0.0
			for cr in craters:
				var dx: float = nx - float(cr[0])
				var dy: float = ny - float(cr[1])
				var dd: float = sqrt(dx * dx + dy * dy) / float(cr[2])
				if dd < 1.0:
					col = col * (0.82 + 0.1 * dd)
					# borde iluminado del lado de la luz
					var side: float = (dx * light.x + dy * light.y) / max(0.001, float(cr[2]))
					shade += clampf(side, -1.0, 1.0) * 0.07 * smoothstep(0.55, 0.9, dd)
				elif dd < 1.25:
					shade += 0.045 * (1.0 - (dd - 1.0) * 4.0)
			if not moon and ny < -0.86:
				col = col.lerp(Color(0.9, 0.88, 0.85), smoothstep(-0.86, -0.93, ny))
			var lam: float = maxf(0.0, normal.dot(light))
			var lit: float = 0.07 + 0.93 * smoothstep(0.0, 0.85, lam)
			col = col * (lit + shade)
			if not moon:
				var rim: float = pow(1.0 - nzv, 3.0) * 0.5 * lit
				col = col.lerp(Color(0.95, 0.62, 0.40), rim)
			var edge: float = clampf((1.0 - sqrt(d2)) * float(size) * 0.5, 0.0, 1.0)
			col.a = edge
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Paisaje en capas para las tarjetas de destino. kind: "Luna" | "Marte".
static func landscape(kind: String, w: int = 520, h: int = 220) -> Texture2D:
	var key: String = "l_%s_%d_%d" % [kind, w, h]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var moon: bool = (kind == "Luna")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3 if moon else 9
	var sky_top: Color = Color(0.01, 0.015, 0.04) if moon else Color(0.36, 0.17, 0.12)
	var sky_bot: Color = Color(0.04, 0.05, 0.09) if moon else Color(0.84, 0.52, 0.34)
	var horizon: float = float(h) * 0.56
	for y in h:
		var t: float = clampf(float(y) / horizon, 0.0, 1.0)
		var sc: Color = sky_top.lerp(sky_bot, pow(t, 1.6 if moon else 1.2))
		for x in w:
			img.set_pixel(x, y, sc)
	if moon:
		for i in 90:
			var sx: int = rng.randi_range(0, w - 1)
			var sy: int = rng.randi_range(0, int(horizon) - 4)
			var b: float = rng.randf_range(0.35, 0.95)
			img.set_pixel(sx, sy, Color(b, b, b * 1.05))
		# la Tierra, pequeña, sobre el horizonte
		var ex: float = float(w) * 0.72
		var ey: float = horizon * 0.42
		var er: float = float(h) * 0.07
		for y in range(int(ey - er) - 1, int(ey + er) + 2):
			for x in range(int(ex - er) - 1, int(ex + er) + 2):
				var dx: float = (float(x) - ex) / er
				var dy: float = (float(y) - ey) / er
				var dd: float = dx * dx + dy * dy
				if dd <= 1.0:
					var lam: float = clampf(0.25 + (-dx * 0.6 - dy * 0.4) * 0.8, 0.05, 1.0)
					var oc: Color = Color(0.16, 0.36, 0.7).lerp(Color(0.82, 0.86, 0.9), smoothstep(0.55, 0.9, absf(dy * 0.6 + sin(dx * 3.0) * 0.25)))
					img.set_pixel(x, y, oc * lam)
	else:
		# sol pequeño y velado, y polvo en el horizonte
		var sx2: float = float(w) * 0.28
		var sy2: float = horizon * 0.55
		for y in int(horizon):
			for x in w:
				var dd2: float = Vector2(float(x) - sx2, float(y) - sy2).length()
				var g: float = exp(-dd2 * dd2 / (2.0 * 26.0 * 26.0)) * 0.55
				var core: float = 1.0 - smoothstep(4.0, 6.0, dd2)
				var cur: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.lerp(Color(1.0, 0.9, 0.75), clampf(g * 0.45 + core, 0.0, 1.0)))
	# capas de relieve: lejana -> cercana
	var layers: Array = []
	if moon:
		layers = [[0.50, 0.060, 0.8, Color(0.20, 0.21, 0.24)], [0.64, 0.085, 1.4, Color(0.30, 0.31, 0.33)], [0.80, 0.07, 2.6, Color(0.42, 0.42, 0.42)], [0.94, 0.04, 4.0, Color(0.20, 0.20, 0.21)]]
	else:
		layers = [[0.50, 0.075, 0.9, Color(0.58, 0.32, 0.22)], [0.64, 0.10, 1.6, Color(0.50, 0.24, 0.14)], [0.80, 0.08, 2.8, Color(0.40, 0.18, 0.10)], [0.94, 0.045, 4.2, Color(0.20, 0.09, 0.06)]]
	for li in layers.size():
		var L: Array = layers[li]
		var nz: FastNoiseLite = _noise(40 + li * 7 + (0 if moon else 100), float(L[2]) / float(w) * 6.0, 4)
		var base_y: float = float(h) * float(L[0])
		var amp: float = float(h) * float(L[1])
		var col: Color = L[3]
		for x in w:
			var hh: float = base_y - (nz.get_noise_1d(float(x)) * 0.5 + 0.5) * amp
			for y in range(int(hh), h):
				var depth: float = float(y - int(hh)) / maxf(1.0, float(h) - hh)
				var cc: Color = col * (1.08 - depth * 0.35)
				# luz rasante en la cresta
				if y - int(hh) < 2:
					cc = cc.lerp(Color(1, 0.93, 0.82), 0.25)
				cc.a = 1.0
				img.set_pixel(x, y, cc)
	# rocas en primer plano
	for i in 14:
		var rx: int = rng.randi_range(6, w - 12)
		var ry: int = rng.randi_range(int(float(h) * 0.84), h - 6)
		var rr: int = rng.randi_range(3, 8)
		var rc: Color = Color(0.13, 0.13, 0.14) if moon else Color(0.16, 0.07, 0.05)
		for y in range(-rr, 1):
			for x in range(-rr - 2, rr + 3):
				if x * x * 0.7 + y * y * 1.6 < rr * rr and ry + y < h and rx + x < w:
					var rim: float = 0.0 if y > -rr / 2 else 0.18
					img.set_pixel(rx + x, ry + y, rc.lerp(Color(0.7, 0.6, 0.5), rim))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
