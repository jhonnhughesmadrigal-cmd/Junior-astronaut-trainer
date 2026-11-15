extends RefCounted
# v28 — Aspecto de cada mundo en 3D (luz, cielo, niebla, gradacion). Solo dibujo.
# Idea artistica (no son mediciones):
#  - Luna: sin atmosfera -> cielo negro, sol blanco y duro, sombras nitidas y casi sin luz
#    de relleno; nada de niebla (a lo lejos se ve igual de nitido). Gris neutro.
#  - Marte: atmosfera fina con polvo -> cielo ocre, luz calida mas difusa, sombras mas suaves,
#    bruma que da profundidad. Color tierra/oxido, menos saturado que un "naranja plano".

const LOOK: Dictionary = {
	"Luna": {
		"sun": Color(1.0, 0.98, 0.95), "sun_e": 1.45, "sun_low": Color(1.0, 0.86, 0.72),
		"amb_day": Color(0.42, 0.43, 0.46), "amb_e_day": 0.2,
		"amb_night": Color(0.13, 0.14, 0.18), "amb_e_night": 0.45,
		"shadow_blur": 0.6, "sat": 0.88, "contrast": 1.12, "exposure": 1.0,
		"max_elev": 40.0,
	},
	"Marte": {
		"sun": Color(1.0, 0.9, 0.78), "sun_e": 1.0, "sun_low": Color(1.0, 0.72, 0.5),
		"amb_day": Color(0.74, 0.55, 0.44), "amb_e_day": 0.3,
		"amb_night": Color(0.12, 0.1, 0.13), "amb_e_night": 0.45,
		"shadow_blur": 1.8, "sat": 0.8, "contrast": 1.1, "exposure": 0.84,
		"max_elev": 38.0,
	},
}


static func get_look(loc: String) -> Dictionary:
	return LOOK.get(loc, LOOK["Luna"])


# Color del suelo de Marte en 3D: un poco mas oscuro y menos saturado (tono tierra/oxido).
# Eleccion artistica; no esta calibrado con fotos de las misiones.
static func grade_ground(c: Color, loc: String) -> Color:
	if loc != "Marte":
		return c
	var l: float = c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	var d: Color = c.lerp(Color(l, l, l), 0.18)
	return Color(d.r * 0.8, d.g * 0.78, d.b * 0.8)


# Aplica la luz del exterior. daylight: 0..1 (con amanecer rapido); sk: 0..1 altura relativa del sol.
static func apply_outside(v: Node3D, loc: String, sk: float, daylight: float, storm: bool) -> void:
	var L: Dictionary = get_look(loc)
	var env: Environment = v.env
	var sun: DirectionalLight3D = v.sun
	sun.light_energy = float(L["sun_e"]) * smoothstep(0.0, 0.3, sk) * (0.75 if storm else 1.0)
	sun.light_color = (L["sun_low"] as Color).lerp(L["sun"], smoothstep(0.0, 0.6, sk))
	sun.shadow_blur = float(L["shadow_blur"]) * (1.8 if storm else 1.0)
	env.ambient_light_color = (L["amb_night"] as Color).lerp(L["amb_day"], daylight)
	env.ambient_light_energy = lerpf(float(L["amb_e_night"]), float(L["amb_e_day"]), daylight)
	env.adjustment_enabled = true
	env.adjustment_saturation = float(L["sat"]) * (0.85 if storm else 1.0)
	env.adjustment_contrast = float(L["contrast"])
	env.tonemap_exposure = float(L["exposure"]) * float(v.game.bright)
