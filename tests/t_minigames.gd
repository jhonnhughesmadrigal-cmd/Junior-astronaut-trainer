extends SceneTree
# v32 — Prueba de los minijuegos nuevos del banco: Kit de parche (sellar la fuga), Filtro de polvo
# (capas) y Mapa (rompecabezas orbital). Fabrica cada herramienta por la via normal (_craft ->
# minijuego -> done) resolviendo con clics simulados, y comprueba que la herramienta se obtiene,
# que un error se cuenta sin castigo y que Esc cancela sin gastar materiales.
# Uso: cp tests/t_minigames.gd . && xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_minigames.gd

var main: Node = null
var mg: Control = null
var frame: int = 0
var ok_n: int = 0
var fail_n: int = 0
var queue: Array = [["patch", 0], ["filter", 3], ["map", 4], ["cancel", 3]]
var cur: Array = []
var state: String = "idle"
var wait: int = 0
var tools0: int = 0
var did_wrong: bool = false
var inv0: Dictionary = {}


func _initialize() -> void:
	Lang.code = "es"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _check(c: bool, what: String) -> void:
	if c:
		ok_n += 1
		print("OK: ", what)
	else:
		fail_n += 1
		print("FALLO: ", what)


func _click(pos: Vector2) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = pos
	mg.call("_gui_input", mb)


func _center(r: Rect2) -> Vector2:
	return r.position + r.size / 2.0


func _next() -> void:
	if queue.is_empty():
		state = "end"
		return
	cur = queue.pop_front()
	main.set("mode", 0)
	(main.get("inv") as Dictionary).merge({"scrap": 9, "polymer": 9, "circuits": 9}, true)
	inv0 = (main.get("inv") as Dictionary).duplicate()
	var tid: String = "filter" if cur[0] == "cancel" else str(cur[0])
	tools0 = int((main.get("tools") as Dictionary)[tid])
	main.call("_craft", int(cur[1]))
	did_wrong = false
	wait = 0
	state = "play"


func _play() -> void:
	wait += 1
	var ext = mg.get("ext")
	var st: Dictionary = ext.get("st")
	var p: Rect2 = mg.call("_panel")
	if wait == 2:
		_check(mg.visible, "%s: el minijuego se abre" % cur[0])
		var want: String = {"patch": "leak", "filter": "layers", "map": "puzzle", "cancel": "layers"}[cur[0]]
		_check(str(mg.get("kind")) == want, "%s: minijuego «%s»" % [cur[0], want])
	if wait < 3:
		return
	if cur[0] == "cancel":
		var k := InputEventKey.new()
		k.keycode = KEY_ESCAPE
		k.pressed = true
		mg.call("handle_key", k)
		state = "check"
		wait = 0
		return
	if bool(mg.get("finished")):
		return
	match str(st["kind"]):
		"layers":
			var rs: Array = ext.call("_card_rects", p)
			var cards: Array = st["cards"]
			var want_i: int = (st["placed"] as Array).size()
			if not did_wrong:
				did_wrong = true
				for i in cards.size():
					if int(cards[i]) != want_i:
						var m0: int = int(mg.get("mistakes"))
						_click(_center(rs[i]))
						_check(int(mg.get("mistakes")) == m0 + 1, "filter: una capa en mal orden cuenta 1 error")
						return
			for i in cards.size():
				if int(cards[i]) == want_i:
					_click(_center(rs[i]))
					return
		"puzzle":
			var tiles: Array = ext.call("_tile_rects", p)
			var perm: Array = st["perm"]
			for i in 9:
				if int(perm[i]) != i:
					var j: int = perm.find(i)
					_click(_center(tiles[i]))
					_click(_center(tiles[j]))
					return
		"leak":
			var cr: Vector2 = st["crack"]
			if cr.x >= 0.0 and wait % 4 == 0:
				_click(ext.call("_crack_pos", p, cr))
	if wait > 2000:
		_check(false, "%s: no se termino" % cur[0])
		state = "check"


func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		main.set("show_tutorial", false)
		main.call("_new_game", "Marte")
		mg = main.get("mg")
	if frame == 10:
		main.get("tut").call("skip_silent")
		main.get("dlg").visible = false
		_next()
		return false
	if frame < 10:
		return false
	match state:
		"play":
			_play()
			if bool(mg.get("finished")) or not mg.visible:
				state = "check"
				wait = 0
		"check":
			wait += 1
			if wait == 120:
				var tid: String = "filter" if cur[0] == "cancel" else str(cur[0])
				var t1: int = int((main.get("tools") as Dictionary)[tid])
				if cur[0] == "cancel":
					_check(t1 == tools0, "cancel: Esc no fabrica la herramienta")
					_check((main.get("inv") as Dictionary).hash() == inv0.hash(), "cancel: Esc no gasta materiales")
				else:
					_check(t1 == tools0 + 1, "%s: superar el minijuego fabrica la herramienta (%d -> %d)" % [cur[0], tools0, t1])
				main.set("mode", 0)
				main.get("dlg").visible = false
				_next()
		"end":
			print("MINIJUEGOS: %d OK, %d fallos" % [ok_n, fail_n])
			return true
	return false
