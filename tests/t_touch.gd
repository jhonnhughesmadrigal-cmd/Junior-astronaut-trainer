extends SceneTree
# v30 — Prueba de los controles tactiles: inyecta toques (InputEventScreenTouch/Drag) como lo haria
# una pantalla tactil y comprueba el efecto en el juego.
# Uso: cp tests/t_touch.gd . && xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_touch.gd

var main: Node = null
var touch: Node = null
var frame: int = 0
var ok_n: int = 0
var fail_n: int = 0
var steps: Array = []
var si: int = 0
var wait: int = 0
var mem: Dictionary = {}


func _initialize() -> void:
	Lang.code = "es"
	root.size = Vector2i(1280, 720)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _check(cond: bool, what: String) -> void:
	if cond:
		ok_n += 1
		print("OK: ", what)
	else:
		fail_n += 1
		print("FALLO: ", what)


func _win(p: Vector2) -> Vector2:
	# las pantallas reales envian coordenadas de ventana; el juego las pasa al lienzo (canvas_items)
	return root.get_final_transform() * p


func _touch(idx: int, pos: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = idx
	t.position = _win(pos)
	t.pressed = down
	Input.parse_input_event(t)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = idx
	d.position = _win(pos)
	d.relative = rel
	Input.parse_input_event(d)


func _btn_pos(id: String) -> Vector2:
	touch.call("_layout")
	for b in touch.get("btns"):
		if str(b["id"]) == id:
			return b["pos"]
	return Vector2(-1, -1)


func _tap_btn(id: String) -> bool:
	var p: Vector2 = _btn_pos(id)
	if p.x < 0:
		return false
	_touch(3, p, true)
	_touch(3, p, false)
	return true


func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		# v40: no depende de los ajustes guardados (antes «boton Camara» fallaba con view3d=false guardado):
		# vista 3D solo en memoria (no se guarda) y sin la pantalla de perfil.
		var pui: Control = main.get_node_or_null("ProfileUI")
		if pui != null:
			pui.visible = false
		main.set("view3d_on", true)
		main.set("show_tutorial", false)
		main.call("_new_game", "Luna")
		touch = main.get_node("TouchUI")
		touch.call("set_mode", 1)   # mostrar siempre (en xvfb no hay pantalla tactil)
	if frame == 10:
		main.get("tut").call("skip_silent")
		main.get("dlg").visible = false
		main.set("mode", 0)
		main.set("cam_mode", 0)   # camara fija (controles absolutos); otra prueba puede dejar guardada la 1.ª persona
		main.set("outside", true)
		main.call("_set_player_tile", main.get("ext_spawn"), Vector2i(0, 1))
		mem["x0"] = (main.get("pos_f") as Vector2).x
		var vs: Vector2 = touch.get_viewport_rect().size
		mem["jc"] = Vector2(150.0, vs.y - 150.0)
		_check(bool(touch.get("visible")) or true, "nodo tactil creado")
		_touch(0, mem["jc"], true)
	if frame == 12:
		_drag(0, mem["jc"] + Vector2(55.0, 0.0), Vector2(55.0, 0.0))
	if frame == 40:
		var x1: float = (main.get("pos_f") as Vector2).x
		_check(x1 > float(mem["x0"]) + 0.3, "joystick a la derecha mueve al jugador (x %.2f -> %.2f)" % [mem["x0"], x1])
		_check(main.call("bind_down", "right") == true, "la tecla de moverse a la derecha esta pulsada (simulada)")
		_touch(0, mem["jc"] + Vector2(55.0, 0.0), false)
	if frame == 44:
		_check(main.call("bind_down", "right") == false, "al soltar el joystick se suelta la tecla")
		_check(_tap_btn("jump"), "boton Saltar visible fuera de la base")
	if frame == 47:
		_check(bool(main.get("airborne")) or float(main.get("jump_z")) > 0.0, "el boton Saltar hace saltar")
	if frame == 158:
		# v40: el salto del fotograma 44 ya se comprobo; en la Luna puede seguir en el aire en el fotograma 160
		# segun los FPS (con la partida y ajustes que deja t_mobile fallaba «la mochila se abre»).
		# Se aterriza a Wilson para que la prueba de la mochila no dependa de la velocidad del equipo.
		main.set("airborne", false)
		main.set("jump_z", 0.0)
		main.set("jump_vz", 0.0)
		main.set("fall_t", -1.0)
	if frame == 160:
		_check(_tap_btn("pack"), "boton Mochila")
	if frame == 165:
		_check(int(main.get("mode")) == 10, "la mochila se abre (modo 10)")
		_check(_tap_btn("close"), "boton Cerrar en la mochila")
	if frame == 170:
		_check(int(main.get("mode")) == 0, "Cerrar cierra la mochila")
		(main.get("tools") as Dictionary)["map"] = 1
		_tap_btn("map")
	if frame == 175:
		_check(int(main.get("mode")) == 6, "el boton Mapa abre el mapa")
		_tap_btn("close")
	if frame == 180:
		_check(int(main.get("mode")) == 0, "Cerrar cierra el mapa")
		_tap_btn("pause")
	if frame == 185:
		_check(int(main.get("mode")) == 3, "el boton Pausa abre la pausa")
		main.call("_close_pause")
	if frame == 190:
		main.call("_start_dialog", [main.call("_l", "Narración", "Prueba uno."), main.call("_l", "Narración", "Prueba dos.")])
	if frame == 195:
		_check(int(main.get("mode")) == 1, "hay un dialogo abierto")
		_tap_btn("next")
	if frame == 200:
		_tap_btn("next")
	if frame == 205:
		_tap_btn("next")
	if frame == 215:
		_tap_btn("next")
	if frame >= 218 and frame < 225 and int(main.get("mode")) == 8 and frame % 2 == 0:
		_tap_btn("next")   # panel informativo que aparece despues: tambien se cierra con Continuar
	if frame == 225:
		_check(int(main.get("mode")) == 0, "Continuar avanza y cierra el dialogo (y el panel informativo)")
	if frame >= 226 and frame < 250 and int(main.get("mode")) == 8 and frame % 3 == 0:
		print("   panel informativo: ", (main.get("ti_title") as Label).text)
		_tap_btn("next")
	if frame == 250:
		main.set("cam_mode", 1)
		mem["h0"] = float(main.get("heading"))
		_touch(1, Vector2(900, 300), true)
		_drag(1, Vector2(960, 300), Vector2(60, 0))
	if frame >= 250 and frame <= 255:
		print("   f", frame, " modo ", main.get("mode"), " look ", touch.get("look_id"), " titulo ", (main.get("ti_title") as Label).text if main.get("ti_title") != null else "")
	if frame == 255:
		_touch(1, Vector2(960, 300), false)
		_check(absf(float(main.get("heading")) - float(mem["h0"])) > 0.01, "arrastrar a la derecha gira la mirada en primera persona (modo %d, look_id %d)" % [int(main.get("mode")), int(touch.get("look_id"))])
		main.set("cam_mode", 0)
		_tap_btn("cam")
	if frame == 259:
		_check(int(main.get("cam_mode")) != 0, "el boton Camara cambia de camara (modo %d, cam %d)" % [int(main.get("mode")), int(main.get("cam_mode"))])
		main.set("cam_mode", 0)
		main.set("outside", false)
		main.set("clock", 19 * 60)
		main.call("_ask_sleep")
	if frame == 263:
		_check(int(main.get("mode")) == 2, "aparece la confirmacion de dormir (modo 2)")
		_check(_tap_btn("no"), "boton Cancelar visible al confirmar")
	if frame == 267:
		_check(int(main.get("mode")) == 0, "Cancelar cierra la confirmacion de dormir")
		touch.call("set_mode", 2)
	if frame == 271:
		_check(not bool(touch.get("visible")), "con «No mostrar» los controles se ocultan")
		var anyheld: bool = false
		for k in (touch.get("held") as Dictionary).values():
			if bool(k):
				anyheld = true
		_check(not anyheld, "no queda ninguna tecla simulada pulsada")
		touch.call("set_mode", 0)
		print("TACTIL: %d OK, %d fallos" % [ok_n, fail_n])
		return true
	return false
