extends RefCounted
# v41 — Poses de la tripulacion para los eventos (las usa view3d._anim_astronaut).
# Rellenan el diccionario de objetivos `tg` (mismas claves que las poses por codigo de view3d):
#   rig_y, body_x, head_x, head_y, al_x, ar_x, al_z, ar_z, el_x, er_x, ll_x, lr_x, kl_x, kr_x, bob
# Devuelven true si conocen la pose.
#   sick    enfermo: encorvado, mano al pecho y tos cada pocos segundos
#   alarm   alarma: mira arriba y alrededor, brazos medio levantados
#   cower   protegerse (meteoro, erupcion solar): agachado, brazos sobre el casco
#   cheer   celebrar (cosecha, mensaje de la Tierra, brecha sellada): brazos arriba y saltitos
#   look_up mirar al cielo/techo (tormenta, ruido en el casco)
#   tired   cansado/abatido (plaga, apagon): hombros caidos, cabeza baja
#   point   senalar (aviso de tormenta, fuga): brazo derecho estirado


static func apply(pose: String, tg: Dictionary, t: float, phase: float) -> bool:
	match pose:
		"sick":
			# tos: un golpe corto cada ~3,2 s (desfasado por tripulante)
			var c: float = fmod(t + phase * 1.3, 3.2)
			var cough: float = 0.0
			if c < 0.6:
				cough = sin(c / 0.6 * PI * 3.0) * (1.0 - c / 0.6)
			tg["body_x"] = -0.38 - 0.25 * absf(cough)
			tg["head_x"] = 0.25 + 0.2 * absf(cough)
			tg["head_y"] = sin(t * 0.5 + phase) * 0.1
			tg["ar_x"] = 1.15 + 0.25 * absf(cough)   # mano al pecho/boca
			tg["er_x"] = 1.9
			tg["ar_z"] = 0.25
			tg["al_x"] = 0.35
			tg["el_x"] = 0.6
			tg["kl_x"] = -0.25
			tg["kr_x"] = -0.25
			tg["ll_x"] = 0.12
			tg["lr_x"] = 0.12
			tg["rig_y"] = -0.05 - 0.04 * absf(cough)
			tg["bob"] = sin(t * 1.1 + phase) * 0.01
			return true
		"alarm":
			tg["head_x"] = -0.35
			tg["head_y"] = sin(t * 2.4 + phase) * 0.6
			tg["body_x"] = 0.05
			tg["al_x"] = 0.9 + 0.2 * sin(t * 5.0 + phase)
			tg["ar_x"] = 0.9 + 0.2 * sin(t * 5.0 + phase + 1.5)
			tg["al_z"] = 0.35
			tg["ar_z"] = -0.35
			tg["el_x"] = 0.9
			tg["er_x"] = 0.9
			tg["bob"] = absf(sin(t * 6.0 + phase)) * 0.03
			return true
		"cower":
			tg["rig_y"] = -0.32
			tg["body_x"] = -0.7
			tg["ll_x"] = 1.2
			tg["lr_x"] = 1.2
			tg["kl_x"] = -2.0
			tg["kr_x"] = -2.0
			tg["al_x"] = 2.6
			tg["ar_x"] = 2.6
			tg["al_z"] = -0.4
			tg["ar_z"] = 0.4
			tg["el_x"] = 1.9
			tg["er_x"] = 1.9
			tg["head_x"] = 0.5
			tg["head_y"] = 0.0
			tg["bob"] = sin(t * 18.0 + phase) * 0.006   # temblor
			return true
		"cheer":
			var hop: float = absf(sin(t * 5.5 + phase))
			tg["rig_y"] = hop * 0.18
			tg["al_x"] = 2.8 + 0.2 * sin(t * 11.0 + phase)
			tg["ar_x"] = 2.8 + 0.2 * sin(t * 11.0 + phase + 1.0)
			tg["al_z"] = 0.5
			tg["ar_z"] = -0.5
			tg["el_x"] = 0.2
			tg["er_x"] = 0.2
			tg["kl_x"] = -0.6 * (1.0 - hop)
			tg["kr_x"] = -0.6 * (1.0 - hop)
			tg["head_x"] = -0.3
			tg["head_y"] = 0.0
			tg["bob"] = 0.0
			return true
		"look_up":
			tg["head_x"] = -0.55
			tg["head_y"] = sin(t * 0.8 + phase) * 0.45
			tg["body_x"] = 0.08
			tg["al_x"] = 0.15
			tg["ar_x"] = 0.15
			return true
		"tired":
			tg["body_x"] = -0.28
			tg["head_x"] = 0.45
			tg["head_y"] = sin(t * 0.4 + phase) * 0.15
			tg["al_x"] = -0.05
			tg["ar_x"] = -0.05
			tg["al_z"] = 0.02
			tg["ar_z"] = -0.02
			tg["el_x"] = 0.05
			tg["er_x"] = 0.05
			tg["rig_y"] = -0.03
			tg["bob"] = sin(t * 0.9 + phase) * 0.008
			return true
		"point":
			tg["ar_x"] = 1.55
			tg["ar_z"] = -0.15
			tg["er_x"] = 0.05
			tg["al_x"] = 0.2 + 0.1 * sin(t * 3.0 + phase)
			tg["head_x"] = -0.1
			tg["head_y"] = 0.0
			tg["body_x"] = -0.05
			return true
	return false
