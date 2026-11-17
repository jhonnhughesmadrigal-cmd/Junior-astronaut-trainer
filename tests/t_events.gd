extends SceneTree
# v41 — Eventos visibles, cinematicas, animaciones de Blender y escena final 3D.
# Uso (copiar a la raiz):  godot --path . --rendering-driver opengl3 --script res://t_events.gd
# No guarda ajustes: activa la vista 3D solo en memoria.

const CrewAnims = preload("res://crew_anims.gd")
const CrewPoses = preload("res://crew_poses.gd")
const EventLines = preload("res://event_lines.gd")
const LangEn = preload("res://lang_en.gd")

var main: Node = null
var v: Node3D = null
var fx: Node3D = null
var frame: int = 0
var ok: int = 0
var total: int = 0
var step: String = "start"
var wait: int = 0
var mem: Dictionary = {}
var endings: Array = ["heroes", "hilo", "ingenio", "unidos", "supervivientes", "fail_oxygen", "fail_energy",
	"fail_food", "fail_water", "fail_shield", "fail_morale"]
var ei: int = 0


func _initialize() -> void:
	Lang.code = "es"
	root.size = Vector2i(1280, 720)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
		print("  OK   ", what)
	else:
		print("  FALLA ", what)


func _static_checks() -> void:
	print("RECURSOS Y DATOS")
	for p in ["res://art/3d/anim/astronaut_jump.glb", "res://art/3d/anim/astronaut_collect.glb", "res://art/3d/fx/meteor.glb",
			"res://art/3d/fx/rescue_ship.glb", "res://audio/impact.wav", "res://audio/wind.wav", "res://audio/cough.wav",
			"res://audio/whoosh.wav", "res://audio/engine.wav"]:
		check(ResourceLoader.exists(p), "existe " + p)
	var j0: Dictionary = CrewAnims.sample("jump", 0.0)
	var j1: Dictionary = CrewAnims.sample("jump", 0.35)
	check(j0.size() >= 12 and absf(float(j0["kl_x"]) - float(j1["kl_x"])) < 1.0 and absf(float(j0["ar_x"]) - float(j1["ar_x"])) > 1.0,
		"salto de Blender: brazos de %.2f a %.2f entre agacharse y el aire" % [float(j0.get("ar_x", 0)), float(j1.get("ar_x", 0))])
	var c4: Dictionary = CrewAnims.sample("collect", 0.4)
	check(float(c4.get("rig_y", 0.0)) < -0.3 and float(c4.get("ar_x", 0.0)) > 1.5, "recogida de Blender: rodilla al suelo y brazo extendido (u=0.4)")
	check(absf(float(CrewAnims.sample("collect", 0.85).get("ar_z", 0.0)) + 0.43) < 0.1, "orden de los angulos (ar_z a 0.85 = -0.43)")
	var bad: Array = []
	for p2 in ["sick", "alarm", "cower", "cheer", "look_up", "tired", "point"]:
		if not CrewPoses.apply(p2, {}, 1.0, 0.0):
			bad.append(p2)
	check(bad.is_empty(), "las 7 poses de evento existen %s" % str(bad))
	var miss: Array = []
	for k in EventLines.LINES:
		for kk in EventLines.LINES[k]:
			for line in EventLines.LINES[k][kk]:
				if not LangEn.EN.has(str(line)):
					miss.append(line)
	check(miss.is_empty(), "todas las frases de la tripulacion tienen ingles (faltan %d)" % miss.size())


func _process(_d: float) -> bool:
	frame += 1
	match step:
		"start":
			if frame == 3:
				_static_checks()
				var pui: Control = main.get_node_or_null("ProfileUI")
				if pui != null:
					pui.visible = false
				main.set("show_tutorial", false)
				main.set("view3d_on", true)
				main.call("_new_game", "Luna")
			if frame == 10:
				main.get("tut").call("skip_silent")
				main.get("dlg").visible = false
				main.set("mode", 0)
				v = main.get("view3d")
				fx = v.get("efx")
				print("EVENTOS")
				check(fx != null, "view3d crea event_fx")
				step = "meteor"
				wait = 0
		"meteor":
			wait += 1
			if wait == 1:
				main.set("breach", true)
				main.call("_efx", "meteor")
				mem["clock"] = int(main.get("clock"))
			if wait == 6:
				check(int(main.get("mode")) == 16 and bool(fx.cine.active), "el meteoro lanza una cinematica (modo 16)")
				check(bool(fx.parts.has("breach_in")) and bool(fx.parts.has("breach_out")), "brecha visible dentro y fuera")
			if wait == 40:
				check(int(main.get("clock")) == int(mem["clock"]), "el reloj no avanza durante la cinematica")
				var k := InputEventKey.new()
				k.keycode = KEY_E
				k.pressed = true
				check(bool(fx.call("handle_key", k)), "E salta la cinematica")
			if wait == 44:
				check(int(main.get("mode")) == 0 and not bool(fx.cine.active) and int(v.get("cine_out")) == -1, "tras saltarla vuelve al juego")
				check(bool(fx.cine.impact_done), "al saltarla el impacto queda hecho")
				check(fx.call("npc_pose", "k") != "", "la tripulacion reacciona (pose de evento)")
			if wait == 120:
				check(_bubbles_shown() > 0, "bocadillos de la tripulacion (%d)" % _bubbles_shown())
				main.set("breach", false)
				main.call("_efx", "sealed")
			if wait == 126:
				check(not fx.parts.has("breach_in"), "al sellar desaparecen la alarma y la fuga")
				step = "cine_end"
				wait = 0
		"cine_end":
			# una cinematica corta termina sola y devuelve el control
			wait += 1
			if wait == 1:
				main.call("_efx", "power")
			if wait == 4:
				mem["t0"] = Time.get_ticks_msec()
				check(bool(fx.cine.active), "el fallo electrico tiene cinematica")
			if wait > 4 and not bool(fx.cine.active) and not mem.has("done"):
				mem["done"] = true
				var secs: float = float(Time.get_ticks_msec() - int(mem["t0"])) / 1000.0
				check(int(main.get("mode")) == 0 and secs < 8.0, "la cinematica termina sola (%.1f s) y devuelve el control" % secs)
			if wait == 900 and not mem.has("done"):
				check(false, "la cinematica termina sola (sigue activa tras 900 fotogramas)")
				mem["done"] = true
			if mem.has("done"):
				step = "states"
				wait = 0
		"states":
			wait += 1
			if wait == 1:
				main.set("ill_days", 3)
				main.call("_efx", "medical", {"ch": "a"})
				main.set("storm_left", 2)
				main.get("emg").call("spawn", "flare", main.get("rng"))
				main.get("emg").call("spawn", "water", main.get("rng"))
			if wait > 3 and bool(fx.cine.active):
				var k2 := InputEventKey.new()
				k2.keycode = KEY_ESCAPE
				k2.pressed = true
				fx.call("handle_key", k2)
			if wait == 200:
				check(str(fx.get("sick_ch")) == "a" and fx.parts.has("sick_icon"), "la enferma lleva icono de botiquin")
				(fx.get("moods") as Dictionary).clear()   # pasada la reaccion a la erupcion (protegerse)
				check(fx.call("npc_pose", "a") == "sick", "la enferma tose y anda encorvada (pose sick)")
				check(fx.parts.has("storm_out"), "tormenta: viento, muro de polvo")
				check(fx.parts.has("shield"), "erupcion solar: escudo encendido")
				check(fx.parts.has("water"), "fuga de agua: goteo y charco")
				main.set("outside", true)
			if wait == 230:
				var env: Environment = v.get("env")
				check(float(fx.get("storm_k")) > 0.2, "la tormenta sube poco a poco (k=%.2f)" % float(fx.get("storm_k")))
				for e in ["harvest", "message", "plague", "salvage", "micro", "storm_warn", "oxygen"]:
					main.call("_efx", e)
				check(true, "los demas eventos se muestran sin errores")
				main.set("outside", false)
				step = "ending"
				wait = 0
		"ending":
			wait += 1
			var eid: String = endings[ei]
			if wait == 1:
				main.call("_finish", not eid.begins_with("fail_"), eid)
			if wait == 40:
				var ec = main.get("ending_cine")
				check(ec != null and v.get("ending_stage") != null, "final %s: escena 3D en vivo" % eid)
				if ec != null:
					check(float(ec.t) > 0.1 and not (ec.actors as Array).is_empty(), "final %s: la escena avanza con la tripulacion" % eid)
					if not eid.begins_with("fail_"):
						check(ec.ship != null, "final %s: nave de rescate" % eid)
					var k3 := InputEventKey.new()
					k3.keycode = KEY_SPACE
					k3.pressed = true
					ec.call("handle_key", k3)
					check(bool(ec.revealed), "final %s: una tecla muestra la tarjeta" % eid)
			if wait == 44:
				main.call("_show_menu")
			if wait == 48:
				check(main.get("ending_cine") == null and v.get("ending_stage") == null and int(v.get("cine_out")) == -1, "final %s: al volver al menu se limpia" % eid)
				ei += 1
				if ei >= endings.size():
					print("RESULTADO: %d/%d" % [ok, total])
					quit(0 if ok == total else 1)
					return true
				main.call("_new_game", "Marte" if ei % 2 == 1 else "Luna")
			if wait == 56:
				main.get("tut").call("skip_silent")
				wait = 0
	return false


func _bubbles_shown() -> int:
	var n: int = 0
	for ch in fx.bubbles:
		var b: Dictionary = fx.bubbles[ch]
		if is_instance_valid(b["panel"]) and float(b["left"]) > -100.0:
			n += 1
	return n
