extends SceneTree
# v39 — Estaciones de Blender (art/3d/base/) y astronauta (art/3d/astronaut.glb).
# Comprueba que se cargan los modelos, que sus piezas animables quedan registradas y que cada estacion
# reacciona mientras Zadiel la usa (modo 5) y da un destello al terminar.
# Uso (copiar a la raiz):  godot --path . --rendering-driver opengl3 --script res://t_stations.gd
# No guarda ajustes: activa la vista 3D solo en memoria.

const StationArt = preload("res://station_art.gd")

var main: Node = null
var frame: int = 0
var ok: int = 0
var total: int = 0
var queue: Array = ["O", "S", "R", "W", "G", "A", "T"]
var cur: String = ""
var step: int = 0
var wait: int = 0


func _initialize() -> void:
	Lang.code = "es"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
		print("  OK   ", what)
	else:
		print("  FALLA ", what)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		var pui: Control = main.get_node_or_null("ProfileUI")
		if pui != null:
			pui.visible = false
		main.set("show_tutorial", false)
		main.set("view3d_on", true)     # solo en memoria (no llama a _save_settings)
		main.set("cam_mode", 1)
		main.call("_new_game", "Luna")
	if frame == 60:
		var tut = main.get("tut")
		if tut != null and tut.has_method("skip_silent"):
			tut.call("skip_silent")
		main.set("mode", 0)
		_static_checks()
	if frame > 60:
		return _run_queue()
	return false


func _static_checks() -> void:
	var v: Node3D = main.get("view3d")
	var pn: Dictionary = v.get("prop_nodes")
	print("Estaciones construidas: ", StationArt.stations.size())
	check(StationArt.stations.size() >= 8, "se construyen las estaciones")
	for ch in ["O", "S", "R", "W", "G", "A", "C", "D"]:
		var n: Node3D = pn.get(ch) if pn.has(ch) else null
		if n == null:
			n = _station_by_child({"D": "anim_leaf_l", "A": "anim_dish", "C": "station_C"}.get(ch, "station_" + ch))
		check(n != null and n.find_child("station_" + ch, true, false) != null, "estacion %s usa el modelo de Blender" % ch)
	check(_has_anim("needle"), "agujas del soporte vital registradas")
	check(_has_anim("solar"), "panel solar registrado")
	check(_has_anim("dish"), "antena de la radio registrada")
	check(_has_anim("door"), "hojas de la esclusa registradas")
	check(_has_anim("fan"), "ventilador del reciclador registrado")
	check(_has_anim("sway"), "plantas del invernadero registradas")
	check(v.get("shield_ring") != null and str((v.get("shield_ring") as Node).name) == "anim_coil", "bobina del escudo = shield_ring")
	check(v.get("shield_mat") != null, "banda del escudo = shield_mat (alerta de brecha)")
	var pl: Node3D = v.get("player_node")
	check(pl != null and pl.find_child("visor", true, false) != null or (pl != null and pl.find_child("head", true, false) != null
		and pl.find_child("astronaut", true, false) != null), "Zadiel usa el astronauta de Blender")


func _station_by_child(child: String) -> Node3D:
	for s in StationArt.stations:
		if is_instance_valid(s) and s.find_child(child, true, false) != null:
			return s
	return null


func _has_anim(tp: String) -> bool:
	for a in StationArt.anims:
		if str(a["type"]) == tp:
			return true
	return false


func _run_queue() -> bool:
	if wait > 0:
		wait -= 1
		return false
	var v: Node3D = main.get("view3d")
	match step:
		0:
			if queue.is_empty():
				print("RESULTADO: %d/%d" % [ok, total])
				quit(0 if ok == total else 1)
				return true
			cur = queue.pop_front()
			var n: Node3D = v.get("prop_nodes").get(cur) if v.get("prop_nodes").has(cur) else null
			if n == null:
				n = _station_by_child({"T": "anim_twist", "A": "anim_dish"}.get(cur, "station_" + cur))
			if n == null:
				check(false, "estacion %s encontrada" % cur)
				return false
			# Zadiel en la casilla de al lado (la logica del juego no mira si es transitable aqui)
			var tx: int = int(floor(n.global_position.x / 2.0))
			var ty: int = int(floor(n.global_position.z / 2.0))
			main.call("_set_player_tile", Vector2i(tx, ty + 1), Vector2i(0, -1))
			main.call("_start_task", 120.0, 1.0, "press")
			set_meta("st", n)
			step = 1
			wait = 40
		1:
			var n2: Node3D = get_meta("st")
			var b: float = float(StationArt._boost.get(n2.get_instance_id(), 0.0))
			check(b > 0.6, "estacion %s reacciona mientras se usa (boost %.2f)" % [cur, b])
			main.call("_finish_task")
			main.set("mode", 0)
			step = 2
			wait = 3
		2:
			var n3: Node3D = get_meta("st")
			var f: float = float(StationArt._flash.get(n3.get_instance_id(), 0.0))
			check(f > 0.4, "estacion %s destella al terminar (flash %.2f)" % [cur, f])
			step = 0
			wait = 30
	return false
