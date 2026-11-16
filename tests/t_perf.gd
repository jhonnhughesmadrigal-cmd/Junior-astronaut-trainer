extends SceneTree
# Mide (v28): tiempo de crear la partida y primitivas/llamadas de dibujo por fotograma en el exterior.
# Uso: cp tests/t_perf.gd . && LOC=Luna Q=2 [INSIDE=1: dentro de la base] xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_perf.gd
# Cifras RELATIVAS (render por software en el equipo de desarrollo), no una medida de GPU real.
var main: Node = null
var frame: int = 0
var acc: Array = []

func _initialize() -> void:
	Lang.code = "es"
	root.size = Vector2i(1280, 720)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		main.set("show_tutorial", false)
		main.set("auto_quality", false)
		main.call("_set_quality", int(OS.get_environment("Q")))
		var t0: int = Time.get_ticks_usec()
		main.call("_new_game", OS.get_environment("LOC"))
		print("crear_partida_ms: ", (Time.get_ticks_usec() - t0) / 1000)
	if frame == 8:
		main.set("outside", OS.get_environment("INSIDE") != "1")
		main.call("_set_player_tile", main.get("ext_spawn"), Vector2i(0, 1))
		main.get("dlg").visible = false
		main.set("mode", 0)
		main.get("view3d").call("snap_camera")
	if frame > 40 and frame <= 60:
		var vp: Viewport = main.get("vp3d")
		var rid: RID = vp.get_viewport_rid()
		acc.append([RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)])
	if frame == 61:
		var a: Array = acc[acc.size() - 1]
		print("primitivas_visibles: ", a[0], " llamadas: ", a[1], " primitivas_sombra: ", a[2])
		return true
	return false
