extends RefCounted
# Texturas procedurales del espacio: Tierra, Via Lactea, brillo de estrellas y ventanas.
# Todo se genera por codigo (sin imagenes) y se guarda en cache.

static var _cache: Dictionary = {}

const EARTH_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_dir = vec3(0.6, 0.3, 0.74);
void fragment() {
	vec2 uv = vec2(UV.x + TIME * 0.004, UV.y);
	vec3 base = texture(albedo_tex, uv).rgb;
	float cl = texture(cloud_tex, vec2(UV.x + TIME * 0.007, UV.y)).r;
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float d = dot(nw, normalize(sun_dir));
	float day = smoothstep(-0.12, 0.28, d);
	vec3 col = mix(base, vec3(0.97, 0.98, 1.0), clamp(cl * 1.15, 0.0, 0.92));
	// brillo del oceano
	vec3 h = normalize(normalize(sun_dir) + vw);
	float spec = pow(max(dot(nw, h), 0.0), 60.0) * (1.0 - cl) * step(0.0, base.b - base.g - 0.05);
	vec3 lit = col * (0.06 + 1.05 * day) + vec3(1.0, 0.95, 0.85) * spec * 0.7 * day;
	// luces de ciudades en la parte oscura (solo tierra)
	float land = step(base.b, base.g + 0.04);
	float city = smoothstep(0.78, 0.9, texture(cloud_tex, uv * 3.0).g) * land * (1.0 - day) * (1.0 - cl);
	lit += vec3(1.0, 0.8, 0.4) * city * 0.9;
	// atmosfera
	float fr = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
	lit += vec3(0.35, 0.6, 1.0) * fr * (0.25 + 0.95 * day);
	ALBEDO = lit;
}
"""


static func _noise_img(seed_v: int, freq: float, oct: int, w: int, h: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = oct
	return n.get_seamless_image(w, h, false, false, 0.1, true)


static func earth_images(w: int = 384) -> Array:
	var key: String = "earth%d" % w
	if _cache.has(key):
		return _cache[key]
	var h: int = w / 2
	var land: Image = _noise_img(11, 0.012 * 256.0 / float(w) * 2.0, 5, w, h)
	var det: Image = _noise_img(23, 0.05 * 256.0 / float(w) * 2.0, 3, w, h)
	var cl: Image = _noise_img(37, 0.02 * 256.0 / float(w) * 2.0, 5, w, h)
	var cl2: Image = _noise_img(41, 0.06 * 256.0 / float(w) * 2.0, 3, w, h)
	var alb := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var clo := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var lat: float = absf(float(y) / float(h) * 2.0 - 1.0)   # 0 ecuador, 1 polo
		for x in w:
			var l: float = land.get_pixel(x, y).r
			var dt: float = det.get_pixel(x, y).r
			var c: Color
			if l > 0.5:
				# tierra: verde, bosque, desierto segun latitud y detalle
				var e: float = clampf((l - 0.5) * 3.0, 0.0, 1.0)
				var green: Color = Color(0.16, 0.42, 0.18).lerp(Color(0.1, 0.3, 0.14), dt)
				var desert: Color = Color(0.72, 0.6, 0.38)
				var dz: float = smoothstep(0.35, 0.65, dt) * (1.0 - smoothstep(0.1, 0.55, lat))
				c = green.lerp(desert, dz)
				c = c.lerp(Color(0.55, 0.5, 0.42), e * 0.5)   # montanas
			else:
				var depth: float = clampf((0.5 - l) * 3.5, 0.0, 1.0)
				c = Color(0.1, 0.4, 0.75).lerp(Color(0.02, 0.1, 0.3), depth)
			if lat > 0.84:
				c = c.lerp(Color(0.95, 0.97, 1.0), smoothstep(0.84, 0.93, lat + (dt - 0.5) * 0.06))
			alb.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
			var cv: float = clampf((cl.get_pixel(x, y).r - 0.48) * 3.4, 0.0, 1.0) * (0.55 + 0.6 * cl2.get_pixel(x, y).r)
			# nubes mas densas en las bandas tropicales y polares
			cv *= 0.8 + 0.4 * (1.0 - absf(lat - 0.4))
			clo.set_pixel(x, y, Color(clampf(cv, 0.0, 1.0), det.get_pixel(x, y).r, 0.0, 1.0))
	alb.generate_mipmaps()
	clo.generate_mipmaps()
	var res: Array = [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(clo), alb, clo]
	_cache[key] = res
	return res


static func earth_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = EARTH_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var t: Array = earth_images(384)
	m.set_shader_parameter("albedo_tex", t[0])
	m.set_shader_parameter("cloud_tex", t[1])
	m.set_shader_parameter("sun_dir", Vector3(0.62, 0.28, 0.73).normalized())
	return m


static func milky_way(w: int = 256) -> ImageTexture:
	var key: String = "milky%d" % w
	if _cache.has(key):
		return _cache[key]
	var h: int = w / 2
	var n1: Image = _noise_img(51, 0.02 * 256.0 / float(w) * 2.0, 5, w, h)
	var n2: Image = _noise_img(63, 0.05 * 256.0 / float(w) * 2.0, 4, w, h)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var nrm: Vector3 = Vector3(0.35, 0.85, 0.4).normalized()
	for y in h:
		var phi: float = (float(y) / float(h) - 0.5) * PI
		for x in w:
			var th: float = float(x) / float(w) * TAU
			var d: Vector3 = Vector3(cos(phi) * cos(th), sin(phi), cos(phi) * sin(th))
			var b: float = d.dot(nrm)
			var core: float = exp(-pow(b / 0.16, 2.0))
			var wide: float = exp(-pow(b / 0.42, 2.0)) * 0.35
			var a: float = n1.get_pixel(x, y).r
			var dust: float = smoothstep(0.52, 0.7, n2.get_pixel(x, y).r) * core
			var v: float = (core * (0.5 + 0.9 * a) + wide * (0.5 + a)) * (1.0 - 0.7 * dust)
			v = clampf(v * 0.42, 0.0, 0.7)
			var warm: float = clampf(core * a * 1.3, 0.0, 1.0)
			var c: Color = Color(0.55, 0.62, 0.9).lerp(Color(1.0, 0.85, 0.65), warm)
			img.set_pixel(x, y, Color(c.r * v, c.g * v, c.b * v, 1.0))
	img.generate_mipmaps()
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func glow_sprite(size: int = 32, core: float = 0.18) -> ImageTexture:
	var key: String = "glow%d_%.2f" % [size, core]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = (float(size) - 1.0) / 2.0
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			var v: float = pow(a, 2.6) + smoothstep(core * 2.2, 0.0, d) * 0.9
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, v))
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func halo_sprite(size: int = 128) -> ImageTexture:
	var key: String = "halo%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = (float(size) - 1.0) / 2.0
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			var v: float = pow(a, 2.2) * 0.55
			img.set_pixel(x, y, Color(0.35 * v, 0.6 * v, 1.0 * v, v))
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func star_color(g: RandomNumberGenerator) -> Color:
	# temperaturas reales aproximadas: azuladas, blancas, amarillas y anaranjadas
	var r: float = g.randf()
	if r < 0.22:
		return Color(0.65, 0.78, 1.0)
	if r < 0.6:
		return Color(1.0, 1.0, 1.0)
	if r < 0.85:
		return Color(1.0, 0.94, 0.75)
	return Color(1.0, 0.72, 0.5)


# Disco de la Tierra (para las ventanas), renderizado en CPU con fases
static func earth_disc(size: int, sun: Vector3) -> Image:
	var t: Array = earth_images(384)
	var alb: Image = t[2]
	var clo: Image = t[3]
	var w: int = alb.get_width()
	var h: int = alb.get_height()
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s: Vector3 = sun.normalized()
	var c: float = (float(size) - 1.0) / 2.0
	for y in size:
		for x in size:
			var dx: float = (float(x) - c) / c
			var dy: float = -(float(y) - c) / c
			var r2: float = dx * dx + dy * dy
			if r2 > 1.0:
				continue
			var dz: float = sqrt(1.0 - r2)
			var n: Vector3 = Vector3(dx, dy, dz)
			var lon: float = atan2(n.x, n.z) + 0.9
			var lat: float = asin(clampf(n.y, -1.0, 1.0))
			var u: int = int(fposmod(lon / TAU, 1.0) * float(w)) % w
			var v: int = clampi(int((0.5 - lat / PI) * float(h)), 0, h - 1)
			var col: Color = alb.get_pixel(u, v)
			var cv: float = clo.get_pixel(u, v).r
			col = col.lerp(Color(0.97, 0.98, 1.0), clampf(cv * 1.15, 0.0, 0.92))
			var day: float = smoothstep(-0.12, 0.28, n.dot(s))
			var k: float = 0.06 + 1.05 * day
			var fr: float = pow(1.0 - dz, 2.6)
			var out: Color = Color(col.r * k + 0.35 * fr * (0.25 + 0.95 * day), col.g * k + 0.6 * fr * (0.25 + 0.95 * day), col.b * k + 1.0 * fr * (0.25 + 0.95 * day), 1.0)
			var edge: float = clampf((1.0 - r2) * 18.0, 0.0, 1.0)
			out.a = edge
			img.set_pixel(x, y, out)
	return img


# Imagen completa de una ventana: cielo con estrellas suaves, Via Lactea, Tierra y horizonte lunar o marciano
static func window_image(moon: bool, x_seed: int, w: int, h: int) -> Image:
	var key: String = "win%s_%d_%d_%d" % [str(moon), x_seed, w, h]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var g := RandomNumberGenerator.new()
	g.seed = 900 + x_seed
	var horizon: int = int(float(h) * 0.82)
	# cielo
	if moon:
		for y in h:
			var t: float = float(y) / float(h)
			var c: Color = Color(0.005, 0.006, 0.02).lerp(Color(0.02, 0.025, 0.06), t * t)
			for x in w:
				img.set_pixel(x, y, c)
		# banda de Via Lactea diagonal con ruido
		var nb: Image = _noise_img(70 + x_seed, 0.05, 4, w, h)
		for y in horizon:
			for x in w:
				var b: float = (float(x) / float(w) - float(y) / float(h) * 0.7) - (0.35 + 0.06 * float(x_seed % 5))
				var band: float = exp(-pow(b / 0.16, 2.0))
				var v: float = band * (0.1 + 0.34 * nb.get_pixel(x, y).r)
				var p: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, Color(p.r + v * 0.7, p.g + v * 0.78, p.b + v, 1.0))
	else:
		for y in h:
			var t2: float = float(y) / float(h)
			var c2: Color = Color(0.55, 0.32, 0.25).lerp(Color(0.92, 0.66, 0.5), t2)
			for x in w:
				img.set_pixel(x, y, c2)
	# estrellas (solo en el cielo oscuro) con brillo suave
	if moon:
		var n_stars: int = int(float(w * h) / 55.0)
		for i in n_stars:
			var sx: int = g.randi_range(0, w - 1)
			var sy: int = g.randi_range(0, horizon - 2)
			var col: Color = star_color(g)
			var br: float = pow(g.randf(), 2.2) * 0.9 + 0.1
			var p2: Color = img.get_pixel(sx, sy)
			img.set_pixel(sx, sy, Color(minf(p2.r + col.r * br, 1.0), minf(p2.g + col.g * br, 1.0), minf(p2.b + col.b * br, 1.0), 1.0))
			if br > 0.6:
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qx: int = sx + o.x
					var qy: int = sy + o.y
					if qx >= 0 and qy >= 0 and qx < w and qy < horizon:
						var p3: Color = img.get_pixel(qx, qy)
						img.set_pixel(qx, qy, Color(minf(p3.r + col.r * br * 0.35, 1.0), minf(p3.g + col.g * br * 0.35, 1.0), minf(p3.b + col.b * br * 0.35, 1.0), 1.0))
		# Tierra en algunas ventanas
		if x_seed == 7:
			var ds: int = int(float(h) * 0.42)
			var disc: Image = earth_disc(ds, Vector3(0.65, 0.3, 0.7))
			var ox: int = int(float(w) * 0.6)
			var oy: int = int(float(h) * 0.12)
			# halo azul
			for y in range(maxi(0, oy - 10), mini(horizon, oy + ds + 10)):
				for x in range(maxi(0, ox - 10), mini(w, ox + ds + 10)):
					var d: float = Vector2(float(x - ox) - float(ds) / 2.0, float(y - oy) - float(ds) / 2.0).length() / (float(ds) / 2.0)
					if d > 1.0 and d < 1.35:
						var a: float = pow(1.0 - (d - 1.0) / 0.35, 2.0) * 0.28
						var p4: Color = img.get_pixel(x, y)
						img.set_pixel(x, y, Color(p4.r + 0.3 * a, p4.g + 0.55 * a, p4.b + a, 1.0))
			img.blend_rect(disc, Rect2i(0, 0, ds, ds), Vector2i(ox, oy))
	# suelo (regolito lunar o arena marciana) con cráteres sencillos y sombras
	var gc: Color = Color(0.42, 0.42, 0.46) if moon else Color(0.5, 0.26, 0.17)
	var gnoise: Image = _noise_img(90 + x_seed, 0.08, 3, w, h)
	for y in range(horizon, h):
		var t3: float = float(y - horizon) / float(maxi(1, h - horizon))
		for x in w:
			var v2: float = 0.75 + 0.5 * gnoise.get_pixel(x, y).r
			var k2: float = (1.0 - 0.45 * t3) * v2
			img.set_pixel(x, y, Color(gc.r * k2, gc.g * k2, gc.b * k2, 1.0))
	# colinas lejanas
	var hn: Image = _noise_img(120 + x_seed, 0.03, 3, w, 8)
	for x in w:
		var hh: int = int(float(h) * 0.07 * (hn.get_pixel(x, 2).r * 2.0))
		for y in range(maxi(0, horizon - hh), horizon):
			var shade: float = 0.65 + 0.3 * float(y - (horizon - hh)) / float(maxi(1, hh))
			img.set_pixel(x, y, Color(gc.r * shade * 0.7, gc.g * shade * 0.7, gc.b * shade * 0.75, 1.0))
	_cache[key] = img
	return img
