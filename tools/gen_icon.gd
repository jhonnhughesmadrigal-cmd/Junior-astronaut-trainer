extends SceneTree
# v37 — Genera el icono de la app (art/app/): luna con cráteres y una órbita ámbar sobre azul noche.
# Dibujado por código (sin imágenes externas). Uso: godot --headless --path . --script res://tools/gen_icon.gd

func _px(img: Image, n: int, fg_only: bool) -> void:
	var c := Vector2(n, n) * 0.5
	var R: float = n * (0.27 if fg_only else 0.3)
	var craters: Array = [[Vector2(-0.32, -0.25), 0.22], [Vector2(0.28, 0.12), 0.17], [Vector2(-0.1, 0.38), 0.13], [Vector2(0.2, -0.4), 0.1]]
	for y in n:
		for x in n:
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			var col := Color(0, 0, 0, 0)
			if not fg_only:
				var t: float = p.y / n
				col = Color(0.05, 0.08, 0.16).lerp(Color(0.03, 0.05, 0.1), t)
				# estrellas pequenas
				var h: int = (x * 73856093) ^ (y * 19349663)
				if h % 997 == 0:
					col = Color(0.85, 0.88, 0.95)
			var d: Vector2 = (p - c) / R
			var r2: float = d.length_squared()
			# orbita (elipse inclinada) por detras de la luna
			var o: Vector2 = (p - c).rotated(-0.45)
			var e: float = pow(o.x / (n * 0.42), 2) + pow(o.y / (n * 0.13), 2)
			var ring: bool = absf(e - 1.0) < 0.06
			if ring and (r2 > 1.0 or o.y > 0.0):
				col = Color(0.86, 0.66, 0.28)
			if r2 <= 1.0:
				var shade: float = clampf(1.0 - 0.55 * (d.x * 0.6 + d.y * 0.6 + 0.4) * 0.5, 0.45, 1.0)
				var base := Color(0.78, 0.78, 0.76)
				for cr in craters:
					var dd: float = (d - (cr[0] as Vector2)).length() / float(cr[1])
					if dd < 1.0:
						base = base.darkened(0.18 if dd > 0.7 else 0.1)
				col = Color(base.r * shade, base.g * shade, base.b * shade)
				# borde suave
				if r2 > 0.94:
					col = col.lerp(Color(0.5, 0.52, 0.56), 0.5)
			img.set_pixel(x, y, col)
	# satelite pequeno sobre la orbita (delante)
	var sp: Vector2 = c + Vector2(n * 0.36, -n * 0.06).rotated(0.45) * Vector2(1, 1)
	for y in range(int(sp.y - n * 0.035), int(sp.y + n * 0.035)):
		for x in range(int(sp.x - n * 0.035), int(sp.x + n * 0.035)):
			if x >= 0 and y >= 0 and x < n and y < n and (Vector2(x, y) - sp).length() < n * 0.03:
				img.set_pixel(x, y, Color(0.95, 0.93, 0.88))


func _make(path: String, n: int, fg_only: bool = false, bg_only: bool = false) -> void:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	if bg_only:
		for y in n:
			for x in n:
				img.set_pixel(x, y, Color(0.05, 0.08, 0.16).lerp(Color(0.03, 0.05, 0.1), float(y) / n))
	else:
		_px(img, n, fg_only)
	img.save_png(path)
	print("icono: ", path)


func _initialize() -> void:
	_make("res://art/app/icon.png", 512)
	_make("res://art/app/icon_192.png", 192)
	_make("res://art/app/adaptive_fg_432.png", 432, true)
	_make("res://art/app/adaptive_bg_432.png", 432, false, true)
	quit()
