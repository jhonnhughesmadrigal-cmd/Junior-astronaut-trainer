extends SceneTree
# v37 — Prueba de mobile_os.gd: simula las notificaciones de Android («Atrás» y app en segundo plano)
# en escritorio. No sustituye a probar en un dispositivo real.
# Uso: cp tests/t_mobile.gd . && xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_mobile.gd

var main: Node = null
var ok_n: int = 0
var fail_n: int = 0


func _check(c: bool, what: String) -> void:
	if c:
		ok_n += 1
		print("OK: ", what)
	else:
		fail_n += 1
		print("FALLO: ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _back() -> void:
	main.get_node("MobileOS").propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(4)


func _initialize() -> void:
	Lang.code = "es"
	root.size = Vector2i(1280, 720)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	var mos: Node = main.get_node_or_null("MobileOS")
	_check(mos != null, "el módulo MobileOS está cargado")
	_check(not quit_on_go_back, "«Atrás» ya no cierra la app directamente")
	var prof: Node = main.get_node("Profiles")
	if (prof.get("current") as Dictionary).is_empty():
		prof.call("create", "guest", "")
	var pui: CanvasItem = main.get_node("ProfileUI")
	pui.call("close")
	var ui = main.get("ui")
	# portada: primer «Atrás» muestra el aviso, no sale
	await _back()
	_check(mos.get("_toast") != null and (mos.get("_toast") as Label).visible, "en la portada, el primer «Atrás» muestra el aviso")
	_check(float(mos.get("_exit_until")) > 0.0, "queda esperando el segundo «Atrás»")
	mos.set("_exit_until", -1.0)
	# página secundaria del menú: vuelve a la portada
	ui.call("show_page", "new")
	await _frames(2)
	_check(str(ui.get("cur_page")) == "new", "(se abre la selección de misión)")
	await _back()
	_check(str(ui.get("cur_page")) == "main", "«Atrás» en una página del menú vuelve a la portada")
	# panel de perfil abierto: lo cierra
	pui.call("show_choose")
	await _frames(2)
	await _back()
	_check(not pui.visible, "«Atrás» cierra el panel de perfil")
	# en partida: abre la pausa y la cierra
	main.set("show_tutorial", false)
	main.call("_new_game", "Marte")
	await _frames(20)
	# (al empezar hay un diálogo de historia: ahí «Atrás»/Esc lo gestiona el propio diálogo)
	(main.get("dlg") as CanvasItem).visible = false
	main.set("typing", false)
	main.set("mode", 0)
	var po: CanvasItem = main.get("pause_overlay")
	await _back()
	_check(po.visible, "en partida, «Atrás» abre la pausa (no cierra la app)")
	await _back()
	_check(not po.visible, "otro «Atrás» cierra la pausa")
	# segundo plano: guarda la partida
	var path: String = str(main.get("SAVE_PATH"))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	main.set("day", 7)
	mos.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _frames(2)
	_check(FileAccess.file_exists(path), "al pasar a segundo plano se guarda la partida")
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	_check(d is Dictionary and int(d.get("day", 0)) == 7, "la partida guardada es la actual (día 7)")
	_check(Lang.t("Pulsa «Atrás» otra vez para salir") != "", "texto del aviso traducible")
	print("MÓVIL: %d OK, %d fallos" % [ok_n, fail_n])
	quit()
