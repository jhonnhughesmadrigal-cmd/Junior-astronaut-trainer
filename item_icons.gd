extends RefCounted
# v34 — Iconos de materiales y herramientas con el estilo de la referencia generada con Ludo.ai
# (solo como guia visual: se dibujan como SVG por codigo, sin importar imagenes).
# Estilo: plano, silueta clara, pocos colores (grafito, gris claro, ambar, verde de placa).
# Un PNG en res://art/icons/<id>.png sigue teniendo prioridad (inv_icons.gd).

const SIZE: int = 64

const SVG: Dictionary = {
	# chatarra: chapa doblada y rasgada, grafito con un canto claro
	"scrap": "<path d='M10 22 L30 8 L54 14 L50 34 L40 52 L22 50 L28 40 L14 38 Z' fill='#6c6e74'/>" +
		"<path d='M30 8 L54 14 L50 34 L36 26 Z' fill='#9a9ca2'/>" +
		"<path d='M10 22 L30 8 L36 26 L22 30 Z' fill='#55575c'/>" +
		"<path d='M28 40 L22 50 L40 52 L36 44 Z' fill='#808288'/>" +
		"<path d='M30 8 L54 14' stroke='#c9cbd0' stroke-width='2'/>",
	# polimero: pila de laminas
	"polymer": "<path d='M32 44 L58 34 L32 24 L6 34 Z' fill='#55575c'/>" +
		"<path d='M32 38 L58 28 L32 18 L6 28 Z' fill='#6c6e74'/>" +
		"<path d='M32 32 L58 22 L32 12 L6 22 Z' fill='#83858b'/>" +
		"<path d='M32 26 L58 16 L32 6 L6 16 Z' fill='#a3a5ab'/>" +
		"<path d='M6 34 L32 44 L58 34 L58 37 L32 47 L6 37 Z' fill='#3d3e42'/>",
	# circuitos: placa verde, chip negro, pines y conector
	"circuits": "<rect x='10' y='10' width='44' height='44' rx='5' fill='#2f9e55'/>" +
		"<rect x='10' y='10' width='44' height='44' rx='5' fill='none' stroke='#237a41' stroke-width='2'/>" +
		"<rect x='26' y='22' width='18' height='18' rx='2' fill='#1d1e21'/>" +
		"<rect x='20' y='5' width='14' height='6' fill='#1d1e21'/>" +
		"<rect x='6' y='26' width='5' height='3' fill='#d9a43c'/><rect x='6' y='32' width='5' height='3' fill='#d9a43c'/><rect x='6' y='38' width='5' height='3' fill='#d9a43c'/>" +
		"<rect x='22' y='50' width='20' height='9' rx='1' fill='#e8e6e1'/>" +
		"<circle cx='16' cy='16' r='2.2' fill='#b9e3c7'/><circle cx='48' cy='48' r='2.2' fill='#b9e3c7'/>",
	# kit de parche: parche cuadrado ambar con borde punteado + tubo de sellador
	"patch": "<rect x='6' y='16' width='34' height='34' rx='3' fill='#e3a33a'/>" +
		"<rect x='12' y='22' width='22' height='22' rx='1' fill='#f6efe2'/>" +
		"<rect x='12' y='22' width='22' height='22' rx='1' fill='none' stroke='#c47f1f' stroke-width='2' stroke-dasharray='3 2'/>" +
		"<rect x='46' y='20' width='10' height='30' rx='3' fill='#e3a33a'/>" +
		"<rect x='46' y='30' width='10' height='8' fill='#f6efe2'/>" +
		"<path d='M48 20 L54 20 L52 8 L50 8 Z' fill='#e3a33a'/>" +
		"<rect x='47' y='50' width='8' height='5' rx='1' fill='#b8741c'/>",
	# botiquin: maletin gris claro con asa y cruz clara
	"medkit": "<rect x='22' y='10' width='20' height='10' rx='3' fill='none' stroke='#b9b8b4' stroke-width='4'/>" +
		"<rect x='6' y='18' width='52' height='38' rx='6' fill='#e7e6e3'/>" +
		"<rect x='6' y='18' width='52' height='6' rx='3' fill='#d6d5d1'/>" +
		"<rect x='28' y='27' width='8' height='22' rx='1' fill='#c9c8c4'/>" +
		"<rect x='21' y='34' width='22' height='8' rx='1' fill='#c9c8c4'/>",
	# reparador: soldador grafito + chip ambar
	"repair": "<rect x='13' y='4' width='8' height='10' rx='2' fill='#4a4b50'/>" +
		"<rect x='11' y='13' width='12' height='26' rx='4' fill='#4a4b50'/>" +
		"<rect x='14' y='18' width='6' height='4' fill='#8a8c92'/>" +
		"<path d='M14 39 L20 39 L18 56 L16 56 Z' fill='#9a9ca2'/>" +
		"<rect x='15' y='56' width='4' height='4' fill='#e3a33a'/>" +
		"<rect x='32' y='8' width='18' height='14' rx='2' fill='#4a4b50'/>" +
		"<rect x='34' y='4' width='3' height='4' fill='#4a4b50'/><rect x='40' y='4' width='3' height='4' fill='#4a4b50'/><rect x='46' y='4' width='3' height='4' fill='#4a4b50'/>" +
		"<rect x='32' y='34' width='22' height='18' rx='2' fill='#e3a33a'/>" +
		"<rect x='37' y='39' width='12' height='8' fill='#c47f1f'/>" +
		"<rect x='28' y='38' width='4' height='3' fill='#e3a33a'/><rect x='28' y='45' width='4' height='3' fill='#e3a33a'/><rect x='54' y='38' width='4' height='3' fill='#e3a33a'/><rect x='54' y='45' width='4' height='3' fill='#e3a33a'/>",
	# filtro de polvo: anillos apilados con malla
	"filter": "<ellipse cx='32' cy='48' rx='26' ry='9' fill='#a8661f'/>" +
		"<rect x='6' y='22' width='52' height='26' fill='#c9802a'/>" +
		"<path d='M8 26 L56 42 M8 34 L44 46 M20 24 L56 36 M32 24 L56 30 M8 42 L20 46 M44 24 L56 26' stroke='#7d4a14' stroke-width='1.6'/>" +
		"<path d='M8 42 L24 26 M16 46 L36 26 M28 47 L48 26 M40 47 L56 32 M52 46 L56 42' stroke='#7d4a14' stroke-width='1.6'/>" +
		"<rect x='6' y='33' width='52' height='3' fill='#a8661f'/>" +
		"<ellipse cx='32' cy='22' rx='26' ry='9' fill='#e3a33a'/>" +
		"<ellipse cx='32' cy='22' rx='16' ry='5' fill='#f2d9a6'/>" +
		"<ellipse cx='32' cy='22' rx='10' ry='3' fill='#c9a46a'/>",
	# mapa: plano plegado gris claro con marcador ambar
	"map": "<path d='M6 18 L22 12 L42 18 L58 12 L58 52 L42 58 L22 52 L6 58 Z' fill='#e1e0dc'/>" +
		"<path d='M22 12 L42 18 L42 58 L22 52 Z' fill='#cfcec9'/>" +
		"<path d='M14 40 Q24 34 32 40 T50 36' stroke='#b8b7b2' stroke-width='2' fill='none'/>" +
		"<path d='M38 30 C30 22 30 10 38 8 C46 10 46 22 38 30 Z' fill='#e3a33a'/>" +
		"<circle cx='38' cy='15' r='3.6' fill='#f6efe2'/>",
}

static var _cache: Dictionary = {}


static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var t: Texture2D = null
	if SVG.has(id):
		var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s</svg>" % SVG[id]
		var img := Image.new()
		# se rasteriza a 128 px (2x) para que se vea nitido tambien en pantallas grandes y en la mochila
		if img.load_svg_from_string(svg, 2.0) == OK:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_cache[id] = t
	return t
