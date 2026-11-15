extends RefCounted
# v28 — Terreno 3D subdividido (solo DIBUJO: la logica del juego sigue por casillas).
# - Malla con `sub` vertices por casilla (1 = como antes, 2 = cada 1 m) y dividida en bloques
#   para que el motor descarte lo que no se ve.
# - Crateres con perfil continuo (cuenco + borde) en vez de escalonado por casilla.
# - Luna: ondulaciones suaves de regolito y crateres pequenos secundarios.
# - Marte: campos de dunas orientadas con el viento (misma direccion que el polvo) y
#   afloramientos oscuros en las pendientes.
# - Color de vertice con variacion a gran escala, eyecciones claras alrededor de crateres
#   jovenes (Luna) y color segun la pendiente.
# Todas las formas y colores son de diseno del juego, NO un mapa real.

const T3: float = 2.0
const CHUNK: int = 24                       # casillas por bloque
const WIND: Vector2 = Vector2(0.944, 0.33)  # direccion del viento en Marte (= polvo de view3d)


static func _noise(seed_v: int, freq: float, oct: int, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = oct
	return n


# Perfil de crater (u = distancia / radio). Mismo perfil que la textura del suelo.
static func crater_profile(u: float, d: float) -> float:
	if u < 1.0:
		return -d * (1.0 - u * u) + d * 0.42 * smoothstep(0.6, 1.0, u)
	var d1: float = (u - 1.04) / 0.16
	return d * 0.45 * exp(-d1 * d1)


# Construye el terreno. Devuelve {"meshes": [ArrayMesh...], "heights": PackedFloat32Array,
# "sub": int, "gw": int (vertices por fila)}.
#  th: alturas por casilla (W*H) SIN crateres; tc: colores por casilla (Array de Color)
#  craters: Array de Vector4(x, y, radio, profundidad) en casillas/metros
#  chars: Array de String (filas del mapa); moon: bool; base_rect: Rect2 en casillas (zona plana)
static func build(W: int, H: int, th: PackedFloat32Array, tc: Array, craters: Array, chars: Array,
		moon: bool, base_rect: Rect2, sub: int, young: Array) -> Dictionary:
	sub = clampi(sub, 1, 3)
	var gw: int = W * sub + 1
	var gh: int = H * sub + 1
	var inv: float = 1.0 / float(sub)
	var N: int = gw * gh
	# --- alturas base (bilineal de las esquinas de casilla, como antes) ---
	var W1: int = W + 1
	var ch_h := PackedFloat32Array()
	ch_h.resize(W1 * (H + 1))
	var ch_c: Array = []
	ch_c.resize(W1 * (H + 1))
	var ch_flat := PackedFloat32Array()    # 1 = suelo llano "." (para dunas y detalle)
	ch_flat.resize(W1 * (H + 1))
	var ch_wall := PackedFloat32Array()    # 1 = relieve "#"
	ch_wall.resize(W1 * (H + 1))
	for cy in H + 1:
		for cx in W1:
			var hs: float = 0.0
			var col := Color(0, 0, 0)
			var fl: float = 0.0
			var wl: float = 0.0
			var cnt: int = 0
			for oy in range(-1, 1):
				for ox in range(-1, 1):
					var tx: int = cx + ox
					var ty: int = cy + oy
					if tx >= 0 and ty >= 0 and tx < W and ty < H:
						hs += th[ty * W + tx]
						var c: Color = tc[ty * W + tx]
						col = Color(col.r + c.r, col.g + c.g, col.b + c.b)
						var chr: String = String(chars[ty]).substr(tx, 1)
						if chr == ".":
							fl += 1.0
						elif chr == "#":
							wl += 1.0
						cnt += 1
			var k: float = 1.0 / float(cnt)
			ch_h[cy * W1 + cx] = hs * k
			ch_c[cy * W1 + cx] = Color(col.r * k, col.g * k, col.b * k)
			ch_flat[cy * W1 + cx] = fl * k
			ch_wall[cy * W1 + cx] = wl * k
	var hts := PackedFloat32Array()
	hts.resize(N)
	var cols := PackedColorArray()
	cols.resize(N)
	var flat_m := PackedFloat32Array()
	flat_m.resize(N)
	var wall_m := PackedFloat32Array()
	wall_m.resize(N)
	var dune_v := PackedFloat32Array()     # altura relativa de duna (0..1) para el color
	dune_v.resize(N)
	var n_macro := _noise(311, 0.012, 3)
	var n_mid := _noise(517, 0.07, 3)
	var n_alb := _noise(733, 0.02, 3)
	var n_patch := _noise(919, 0.045, 2)
	var n_wall := _noise(1201, 0.09, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	n_wall.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var n_warp := _noise(1409, 0.05, 2)
	var n_field := _noise(1601, 0.018, 2)
	var bx0: float = base_rect.position.x
	var by0: float = base_rect.position.y
	var bx1: float = base_rect.end.x
	var by1: float = base_rect.end.y
	for gy in gh:
		var fy: float = float(gy) * inv
		var y0: int = mini(int(fy), H - 1)
		var ty: float = fy - float(y0)
		for gx in gw:
			var fx: float = float(gx) * inv
			var x0: int = mini(int(fx), W - 1)
			var tx: float = fx - float(x0)
			var i00: int = y0 * W1 + x0
			var a: float = (1.0 - tx) * (1.0 - ty)
			var b: float = tx * (1.0 - ty)
			var c2: float = (1.0 - tx) * ty
			var d: float = tx * ty
			var h: float = ch_h[i00] * a + ch_h[i00 + 1] * b + ch_h[i00 + W1] * c2 + ch_h[i00 + W1 + 1] * d
			var flat: float = ch_flat[i00] * a + ch_flat[i00 + 1] * b + ch_flat[i00 + W1] * c2 + ch_flat[i00 + W1 + 1] * d
			var wall: float = ch_wall[i00] * a + ch_wall[i00 + 1] * b + ch_wall[i00 + W1] * c2 + ch_wall[i00 + W1 + 1] * d
			var q00: Color = ch_c[i00]
			var q10: Color = ch_c[i00 + 1]
			var q01: Color = ch_c[i00 + W1]
			var q11: Color = ch_c[i00 + W1 + 1]
			var col := Color(q00.r * a + q10.r * b + q01.r * c2 + q11.r * d,
				q00.g * a + q10.g * b + q01.g * c2 + q11.g * d,
				q00.b * a + q10.b * b + q01.b * c2 + q11.b * d)
			# distancia a la zona plana de la base (0 dentro, 1 a 4 casillas o mas)
			var dbx: float = maxf(maxf(bx0 - fx, fx - bx1), 0.0)
			var dby: float = maxf(maxf(by0 - fy, fy - by1), 0.0)
			var away: float = smoothstep(0.0, 4.0, maxf(dbx, dby))
			var mx: float = fx * T3
			var mz: float = fy * T3
			# relieve suave de gran escala + detalle medio
			var macro: float = n_macro.get_noise_2d(mx, mz)
			var mid: float = n_mid.get_noise_2d(mx, mz)
			var detail: float = (macro * (0.45 if moon else 0.6) + mid * (0.07 if moon else 0.09)) * away
			# relieve rocoso en "#" (crestas)
			detail += wall * away * (0.25 + 0.9 * maxf(n_wall.get_noise_2d(mx, mz), 0.0))
			var dv: float = 0.0
			if not moon:
				# dunas: perfil asimetrico (ladera larga a barlovento, corta a sotavento)
				var field: float = smoothstep(-0.05, 0.35, n_field.get_noise_2d(mx, mz)) * flat * away
				if field > 0.001:
					var s: float = (mx * WIND.x + mz * WIND.y) / 7.5 + n_warp.get_noise_2d(mx, mz) * 1.3
					var ph: float = s - floor(s)
					var prof: float = smoothstep(0.0, 0.78, ph) if ph < 0.78 else smoothstep(1.0, 0.78, ph)
					dv = prof * field
					detail += (prof - 0.35) * 0.62 * field
			var gi: int = gy * gw + gx
			hts[gi] = h + detail
			flat_m[gi] = flat * away
			wall_m[gi] = wall
			dune_v[gi] = dv
			# variacion de color a gran escala
			var alb: float = n_alb.get_noise_2d(mx, mz)
			var patch: float = n_patch.get_noise_2d(mx, mz)
			if moon:
				var k2: float = 1.0 + alb * 0.16
				# "mares": manchas oscuras y suaves
				k2 *= lerpf(1.0, 0.84, smoothstep(0.15, 0.55, patch) * away)
				col = Color(col.r * k2, col.g * k2, col.b * k2 * 1.01)
			else:
				var k3: float = 1.0 + alb * 0.12
				col = Color(col.r * k3, col.g * k3, col.b * k3)
				# basalto oscuro y polvo claro
				var dark := Color(col.r * 0.72, col.g * 0.68, col.b * 0.72)
				col = col.lerp(dark, smoothstep(0.2, 0.6, patch) * 0.7 * away)
			cols[gi] = col
	# --- crateres con perfil continuo ---
	for cr in craters:
		var cc: Vector4 = cr
		var reach: float = cc.z * 1.4
		var gx0: int = maxi(int((cc.x - reach) * sub), 0)
		var gx1: int = mini(int((cc.x + reach) * sub) + 1, gw - 1)
		var gy0: int = maxi(int((cc.y - reach) * sub), 0)
		var gy1: int = mini(int((cc.y + reach) * sub) + 1, gh - 1)
		var rinv: float = 1.0 / cc.z
		for gy in range(gy0, gy1 + 1):
			var dy: float = (float(gy) * inv - cc.y) * rinv
			for gx in range(gx0, gx1 + 1):
				var dx: float = (float(gx) * inv - cc.x) * rinv
				var u: float = sqrt(dx * dx + dy * dy)
				if u < 1.4:
					hts[gy * gw + gx] += crater_profile(u, cc.w)
	# eyecciones claras alrededor de crateres jovenes (Luna)
	for yc in young:
		var cc2: Vector4 = yc
		var reach2: float = cc2.z * 2.3
		var rinv2: float = 1.0 / cc2.z
		for gy in range(maxi(int((cc2.y - reach2) * sub), 0), mini(int((cc2.y + reach2) * sub) + 1, gh)):
			var dy2: float = (float(gy) * inv - cc2.y) * rinv2
			for gx in range(maxi(int((cc2.x - reach2) * sub), 0), mini(int((cc2.x + reach2) * sub) + 1, gw)):
				var dx2: float = (float(gx) * inv - cc2.x) * rinv2
				var u2: float = sqrt(dx2 * dx2 + dy2 * dy2)
				if u2 > 0.85 and u2 < 2.3:
					var w: float = smoothstep(2.3, 1.05, u2) * 0.2
					# rayos tenues
					var ang: float = atan2(dy2, dx2)
					w *= 0.65 + 0.35 * maxf(sin(ang * 7.0 + cc2.x), 0.0)
					var gi2: int = gy * gw + gx
					var c3: Color = cols[gi2]
					cols[gi2] = Color(c3.r * (1.0 + w), c3.g * (1.0 + w), c3.b * (1.0 + w * 1.05))
	# --- normales y color segun la pendiente ---
	var norms := PackedVector3Array()
	norms.resize(N)
	var step: float = T3 * inv
	for gy in gh:
		for gx in gw:
			var gi: int = gy * gw + gx
			var hl: float = hts[gy * gw + maxi(gx - 1, 0)]
			var hr: float = hts[gy * gw + mini(gx + 1, gw - 1)]
			var hu: float = hts[maxi(gy - 1, 0) * gw + gx]
			var hd: float = hts[mini(gy + 1, gh - 1) * gw + gx]
			var nn := Vector3(hl - hr, 2.0 * step, hu - hd).normalized()
			norms[gi] = nn
			var slope: float = clampf((1.0 - nn.y) * 4.0, 0.0, 1.0)
			var c4: Color = cols[gi]
			if moon:
				# regolito fresco y mas claro en las laderas empinadas
				var k4: float = 1.0 + slope * 0.16
				c4 = Color(c4.r * k4, c4.g * k4, c4.b * k4)
			else:
				# roca oscura asoma en las pendientes; crestas de duna con polvo mas claro
				c4 = c4.lerp(Color(c4.r * 0.62, c4.g * 0.55, c4.b * 0.56), slope * 0.8)
				var dv2: float = dune_v[gi]
				if dv2 > 0.0:
					var k5: float = 1.0 + (dv2 - 0.45) * 0.22
					c4 = Color(c4.r * k5, c4.g * k5 * 0.99, c4.b * k5 * 0.97)
			cols[gi] = c4
	# --- mallas por bloques ---
	var meshes: Array = []
	for by in range(0, H, CHUNK):
		for bx in range(0, W, CHUNK):
			meshes.append(_chunk(bx, by, mini(bx + CHUNK, W), mini(by + CHUNK, H), sub, gw, W, H, hts, norms, cols))
	return {"meshes": meshes, "heights": hts, "sub": sub, "gw": gw}


static func _chunk(tx0: int, ty0: int, tx1: int, ty1: int, sub: int, gw: int, W: int, H: int,
		hts: PackedFloat32Array, norms: PackedVector3Array, cols: PackedColorArray) -> ArrayMesh:
	var gx0: int = tx0 * sub
	var gy0: int = ty0 * sub
	var cw: int = (tx1 - tx0) * sub + 1
	var chh: int = (ty1 - ty0) * sub + 1
	var n: int = cw * chh
	var inv: float = 1.0 / float(sub)
	var verts := PackedVector3Array()
	verts.resize(n)
	var nr := PackedVector3Array()
	nr.resize(n)
	var cl := PackedColorArray()
	cl.resize(n)
	var uvs := PackedVector2Array()
	uvs.resize(n)
	var uvs2 := PackedVector2Array()
	uvs2.resize(n)
	var tans := PackedFloat32Array()
	tans.resize(n * 4)
	for ly in chh:
		for lx in cw:
			var gx: int = gx0 + lx
			var gy: int = gy0 + ly
			var gi: int = gy * gw + gx
			var li: int = ly * cw + lx
			var fx: float = float(gx) * inv
			var fy: float = float(gy) * inv
			verts[li] = Vector3(fx * T3, hts[gi], fy * T3)
			var nn: Vector3 = norms[gi]
			nr[li] = nn
			cl[li] = cols[gi]
			uvs[li] = Vector2(fx / float(W), fy / float(H))
			uvs2[li] = Vector2(fx, fy) / 5.0
			var tt: Vector3 = (Vector3(1, 0, 0) - nn * nn.x).normalized()
			tans[li * 4] = tt.x
			tans[li * 4 + 1] = tt.y
			tans[li * 4 + 2] = tt.z
			tans[li * 4 + 3] = 1.0
	var idx := PackedInt32Array()
	idx.resize((cw - 1) * (chh - 1) * 6)
	var k: int = 0
	for ly in chh - 1:
		for lx in cw - 1:
			var a: int = ly * cw + lx
			var b: int = a + 1
			var c: int = a + cw + 1
			var d: int = a + cw
			# diagonal alterna: evita el "serrucho" en las dunas
			if (lx + ly) % 2 == 0:
				idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
				idx[k + 3] = a; idx[k + 4] = c; idx[k + 5] = d
			else:
				idx[k] = a; idx[k + 1] = b; idx[k + 2] = d
				idx[k + 3] = b; idx[k + 4] = c; idx[k + 5] = d
			k += 6
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_COLOR] = cl
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uvs2
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


# Altura interpolada en coordenadas de casilla (fx, fy) sobre la rejilla fina.
static func sample(hts: PackedFloat32Array, gw: int, sub: int, W: int, H: int, fx: float, fy: float) -> float:
	var sx: float = clampf(fx, 0.0, float(W)) * float(sub)
	var sy: float = clampf(fy, 0.0, float(H)) * float(sub)
	var gh: int = H * sub + 1
	var x0: int = clampi(int(floor(sx)), 0, gw - 2)
	var y0: int = clampi(int(floor(sy)), 0, gh - 2)
	var tx: float = clampf(sx - float(x0), 0.0, 1.0)
	var ty: float = clampf(sy - float(y0), 0.0, 1.0)
	var i: int = y0 * gw + x0
	# misma diagonal que la malla, para que los pies no se hundan
	var a: float = hts[i]
	var b: float = hts[i + 1]
	var c: float = hts[i + gw + 1]
	var d: float = hts[i + gw]
	if (x0 + y0) % 2 == 0:
		if tx >= ty:
			return a + (b - a) * tx + (c - b) * ty
		return a + (c - d) * tx + (d - a) * ty
	if tx + ty <= 1.0:
		return a + (b - a) * tx + (d - a) * ty
	return c + (d - c) * (1.0 - tx) + (b - c) * (1.0 - ty)


# ---------- rocas facetadas ----------

# Roca: esfera deformada y recortada por planos (facetas angulosas) con la base aplanada.
# moon: bloques redondeados por el bombardeo de micrometeoritos; Marte: mas planas y angulosas.
static func rock_mesh(seed_v: int, moon: bool, seg: int = 10) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = seg
	sm.rings = maxi(seg / 2, 4)
	var arr: Array = sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var g := RandomNumberGenerator.new()
	g.seed = seed_v
	var n := _noise(seed_v, 1.3, 3)
	var planes: Array = []
	var np: int = 5 if moon else 7
	for i in np:
		var dir := Vector3(g.randf_range(-1, 1), g.randf_range(-0.3, 1.0), g.randf_range(-1, 1)).normalized()
		planes.append([dir, g.randf_range(0.5, 0.76) if not moon else g.randf_range(0.75, 0.92)])
	for i in v.size():
		var p: Vector3 = v[i]
		p *= 1.0 + 0.18 * n.get_noise_3dv(p * 1.6)
		for pl in planes:
			var dir2: Vector3 = pl[0]
			var dd: float = p.dot(dir2) - float(pl[1])
			if dd > 0.0:
				p -= dir2 * dd
		if p.y < -0.35:
			p.y = -0.35 + (p.y + 0.35) * 0.15
		if not moon:
			p.y *= 0.72
		v[i] = p
	arr[Mesh.ARRAY_VERTEX] = v
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.deindex()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()
