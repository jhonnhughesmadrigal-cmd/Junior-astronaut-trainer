extends RefCounted
# v41 — Escena final en 3D en vivo (11 finales). Usa el mundo de la partida que acaba de terminar (base, terreno,
# tripulacion y efectos de event_fx.gd) con una puesta en escena y una camara de cine para cada final.
# - main.gd la crea en _build_ending_screen si la vista 3D esta activa; si no, queda el dibujo 2D (ending_art.gd).
# - view3d llama a tick() mientras view3d.ending_stage apunte aqui (la partida ya no corre: playing = false).
# - La tarjeta de resultados aparece a los REVEAL segundos o al pulsar una tecla / tocar la pantalla.
# - Victorias: la nave de rescate (art/3d/fx/rescue_ship.glb, diseno propio) aterriza junto a la base y la
#   tripulacion la recibe. Derrotas: la causa se ve en la escena (alarma y fuga, apagon, plaga, goteo, radiacion,
#   tripulacion abatida).

const SHIP_GLB: String = "res://art/3d/fx/rescue_ship.glb"
const REVEAL: float = 5.0

var g: Node = null
var v: Node3D = null
var fx: Node3D = null
var eid: String = ""
var won: bool = false
var t: float = 0.0
var view: TextureRect = null      # muestra la vista 3D detras de la tarjeta
var revealed: bool = false
var outside: bool = true
var actors: Array = []           # [{n, pose, from, to, phase}]
var keys: Array = []             # camara: [{t, pos, look}]
var orbit_c: Vector3 = Vector3.ZERO
var ship: Node3D = null
var ship_pad: Vector3 = Vector3.ZERO
var ship_land_t: float = 4.2
var landed: bool = false
var flame: CPUParticles3D = null
var burst_t: float = 0.0


func setup(game: Node, w: bool, ending_id: String) -> bool:
	g = game
	v = g.get("view3d")
	if v == null or v.get("efx") == null or v.get("interior") == null:
		return false
	fx = v.get("efx")
	won = w
	eid = ending_id
	fx.cine.reset()
	fx.call("setup")    # limpia efectos y bocadillos de la partida
	for k in ["breach", "storm_left", "ill_days"]:
		g.set(k, false if k == "breach" else 0)
	_stage()
	fx.cine._tags(false)   # sin etiquetas de nombre en la escena final
	v.set("ending_stage", self)
	v.set("cine_out", 1 if outside else 0)
	v.call("_update_visibility")
	return true


func stop() -> void:
	if v != null and is_instance_valid(v):
		v.set("ending_stage", null)
		v.set("cine_out", -1)
	if ship != null and is_instance_valid(ship):
		ship.queue_free()
	ship = null
	if fx != null and is_instance_valid(fx):
		fx.set("light_override", -1.0)
		(fx.get("force") as Dictionary).clear()
	g.set("breach", false)


# ------------------------------------------------------------------ puesta en escena

func _crew() -> Array:
	# [nodo, clave]: Zadiel + tripulacion
	var out: Array = [[v.get("player_node"), "w"]]
	var nn: Dictionary = v.get("npc_nodes")
	for ch in ["a", "k", "l"]:
		if nn.has(ch) and is_instance_valid(nn[ch]):
			out.append([nn[ch], ch])
	return out


func _place(n: Node3D, pos: Vector3, yaw: float, pose: String, phase: float, to: Vector3 = Vector3.INF) -> void:
	if outside and n.get_parent() != v:
		n.reparent(v, false)
	n.position = pos
	n.rotation = Vector3(0, yaw, 0)
	n.visible = true
	actors.append({"n": n, "pose": pose, "from": pos, "to": to if to != Vector3.INF else pos, "phase": phase})


func _gy(p: Vector3) -> float:
	return float(v.call("ground_y", p.x / 2.0, p.z / 2.0))


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, _gy(p), p.z)


func _key(tt: float, pos: Vector3, look: Vector3) -> void:
	keys.append({"t": tt, "pos": pos, "look": look})


func _stage() -> void:
	var b: Dictionary = fx.base_box()
	var air: Vector3 = b["air"]
	var crew: Array = _crew()
	var interior_eids: Array = ["fail_oxygen", "fail_energy", "fail_food", "fail_water", "fail_morale"]
	outside = not interior_eids.has(eid)
	g.set("outside", outside)
	g.set("clock", {"heroes": 9 * 60 + 30, "hilo": 18 * 60 + 40, "ingenio": 11 * 60, "unidos": 10 * 60,
		"supervivientes": 8 * 60, "fail_shield": 12 * 60, "fail_oxygen": 23 * 60, "fail_energy": 23 * 60,
		"fail_food": 20 * 60, "fail_water": 15 * 60, "fail_morale": 21 * 60}.get(eid, 12 * 60))
	if outside:
		ship_pad = _on_ground(air + Vector3(13.0, 0, 11.0))
		var front: Vector3 = air.lerp(ship_pad, 0.42) + Vector3(-1.5, 0, 0)   # entre la esclusa y la nave
		var face_ship: float = atan2(-(ship_pad.x - front.x), -(ship_pad.z - front.z))
		match eid:
			"heroes", "hilo", "supervivientes":
				var pose: String = "tired" if eid == "hilo" else "idle"
				for i in crew.size():
					var p: Vector3 = _on_ground(front + Vector3(-2.4 + float(i) * 1.6, 0, float(i % 2) * 0.6))
					var dest: Vector3 = p
					if eid == "supervivientes":
						dest = _on_ground(p.lerp(ship_pad, 0.55) + Vector3(-1.5 + float(i), 0, 0))
					_place(crew[i][0], p, face_ship, pose, float(i) * 1.7, dest)
			"ingenio":
				var wp: Vector3 = _on_ground(front + Vector3(-2.0, 0, 0.5))
				_place(crew[0][0], wp, PI * 0.5, "hammer", 0.0)
				fx.v.call("fx_burst", wp + Vector3(-0.8, 0.5, 0), Color(1.0, 0.8, 0.35), 10, 1.0, 1.4)
				for i in range(1, crew.size()):
					_place(crew[i][0], _on_ground(front + Vector3(0.6 + float(i) * 1.4, 0, 1.2)), face_ship, "idle", float(i))
			"unidos":
				var cc: Vector3 = _on_ground(front + Vector3(1.0, 0, 1.5))
				for i in crew.size():
					var a: float = TAU * float(i) / float(crew.size())
					var p2: Vector3 = _on_ground(cc + Vector3(cos(a), 0, sin(a)) * 1.25)
					_place(crew[i][0], p2, atan2(-(cc.x - p2.x), -(cc.z - p2.z)), "idle", float(i) * 0.9)
				orbit_c = cc
			"fail_shield":
				(fx.force as Dictionary)["flare"] = true
				fx.set("shield_flash", 1.0)
				for i in crew.size():
					_place(crew[i][0], _on_ground(front + Vector3(-2.0 + float(i) * 1.4, 0, 0.4)), 0.0, "cower", float(i))
		if won:
			_spawn_ship()
		var grp: Vector3 = _on_ground(front + Vector3(0.5, 0, 0.5))
		if orbit_c == Vector3.ZERO:
			orbit_c = grp.lerp(ship_pad, 0.35) if won else grp
		if won:
			var away: Vector3 = (grp - ship_pad).normalized()
			var side: Vector3 = away.cross(Vector3.UP).normalized()
			if side.z < 0.0:
				side = -side   # siempre hacia el sur (lado abierto, lejos del casco)
			_key(0.0, grp + away * 2.0 + side * 7.0 + Vector3(0, 1.2, 0), ship_pad + Vector3(0, 16, 0))
			_key(ship_land_t, grp + away * 3.0 + side * 7.5 + Vector3(0, 2.0, 0), ship_pad + Vector3(0, 2.5, 0))
			_key(ship_land_t + 3.5, grp + away * 4.0 + side * 6.0 + Vector3(0, 2.4, 0), grp.lerp(ship_pad, 0.25) + Vector3(0, 1.3, 0))
		else:
			_key(0.0, grp + Vector3(-3, 2.2, 9), b["c"] + Vector3(0, 10, 0))
			_key(4.5, grp + Vector3(-2, 3.0, 7.5), grp + Vector3(0, 1.0, 0))
	else:
		var rc: Vector3 = fx.room_center()
		var spots: Dictionary = {}
		match eid:
			"fail_oxygen":
				g.set("breach", true)
				_crew_inside(crew, ["cower", "cower", "tired", "cower"])
				_key(0.0, rc + Vector3(7, 5.5, 8), rc)
				_key(6.0, rc + Vector3(3, 2.6, 4.5), rc + Vector3(0, 0.8, 0))
			"fail_energy":
				fx.set("light_override", 0.06)
				g.res["energy"] = 0.0
				_crew_inside(crew, ["tired", "tired", "tired", "look_up"])
				_key(0.0, rc + Vector3(-9, 7.5, 10), rc)
				_key(7.0, rc + Vector3(-5, 4.0, 7), rc + Vector3(0, 1.0, 0))
			"fail_food":
				var gp: Vector3 = fx.station_pos("G", 0.0)
				_crew_inside(crew, ["tired", "tired", "sick", "tired"], gp + Vector3(0, 0, 3.0))
				_key(0.0, gp + Vector3(6, 5, 9), gp)
				_key(6.0, gp + Vector3(2.5, 2.4, 5.5), gp + Vector3(0, 0.9, 0))
			"fail_water":
				var wp2: Vector3 = fx.station_pos("W", 0.0)
				(fx.force as Dictionary)["water"] = true
				_crew_inside(crew, ["tired", "tired", "tired", "sick"], wp2 + Vector3(-1.0, 0, 3.0))
				_key(0.0, wp2 + Vector3(-7, 5, 9), wp2)
				_key(6.0, wp2 + Vector3(-3, 2.4, 5), wp2 + Vector3(0, 1.0, 0))
			"fail_morale":
				fx.set("light_override", 0.45)
				var corners: Array = [Vector3(5, 0, 5), Vector3(26, 0, 6), Vector3(7, 0, 17), Vector3(24, 0, 16)]
				for i in crew.size():
					var cp: Vector3 = corners[i % corners.size()]
					_place(crew[i][0], cp, atan2(-(cp.x - rc.x), -(cp.z - rc.z)) + PI, "tired", float(i))
				_key(0.0, rc + Vector3(-11, 6, 9), rc)
				_key(7.0, rc + Vector3(11, 6, 9), rc)
		orbit_c = rc


func _crew_inside(crew: Array, poses: Array, near: Vector3 = Vector3.INF) -> void:
	var rc: Vector3 = fx.room_center() if near == Vector3.INF else near
	for i in crew.size():
		var a: float = TAU * float(i) / float(crew.size()) + 0.4
		var p: Vector3 = rc + Vector3(cos(a) * 2.2, 0, sin(a) * 1.6)
		_place(crew[i][0], p, atan2(-(rc.x - p.x), -(rc.z - p.z)), str(poses[i % poses.size()]), float(i) * 1.3)


func _spawn_ship() -> void:
	if not ResourceLoader.exists(SHIP_GLB):
		return
	ship = (load(SHIP_GLB) as PackedScene).instantiate()
	(v.get("exterior") as Node3D).add_child(ship)
	ship.position = ship_pad + Vector3(0, 40, 0)
	ship.rotation.y = 0.6
	var eng: Node3D = ship.find_child("anim_engine", true, false)
	if eng == null:
		eng = ship
	flame = fx.particles(eng, 90, 0.45, Color(1.0, 0.72, 0.38, 0.9), 0.9, Vector3(0.25, 0.1, 0.25),
		Vector3(0, -1, 0), 8.0, 7.0, 11.0, Vector3.ZERO, true)
	flame.local_coords = false
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.75, 0.45)
	gl.light_energy = 3.0
	gl.omni_range = 16.0
	gl.name = "engine_light"
	eng.add_child(gl)
	if g.has_method("_sfx"):
		g.call("_sfx", "engine", -6.0)
	# marca de aterrizaje en el suelo (ambar mate, como la plataforma)
	v.call("fx_ring", ship_pad + Vector3(0, 0.08, 0), Color(0.85, 0.65, 0.3, 0.9), 3.2)


# ------------------------------------------------------------------ por fotograma

func tick(delta: float) -> void:
	t += delta
	v.call("_update_light")
	fx.call("update", delta)
	fx.call("post_light")
	if v.get("wfx") != null:
		v.get("wfx").call("update", delta, float(v.get("last_daylight")))
	v.call("_fx_update", delta)
	_update_ship(delta)
	v.set("anim_k", clampf(1.0 - exp(-10.0 * delta), 0.04, 0.6))
	for a in actors:
		var n: Node3D = a["n"]
		if not is_instance_valid(n):
			continue
		var pose: String = str(a["pose"])
		if won and landed and pose in ["idle", "tired"]:
			pose = "cheer"   # la nave ya esta aqui
		var from: Vector3 = a["from"]
		var to: Vector3 = a["to"]
		if from != to and landed:
			var u: float = clampf((t - ship_land_t - 1.0) / 5.0, 0.0, 1.0)
			var p: Vector3 = from.lerp(to, u)
			n.position = _on_ground(p)
			if u > 0.0 and u < 1.0:
				pose = "walk"
				n.rotation.y = atan2(-(to.x - from.x), -(to.z - from.z))
		v.call("_anim_astronaut", n, pose, t, float(a["phase"]))
	if eid == "fail_food" and fmod(t, 1.6) < delta:
		v.call("fx_burst", fx.station_pos("G", 1.0), Color(0.5, 0.42, 0.25), 8, 0.6, 0.8)
	_update_camera(delta)
	if not revealed and t >= REVEAL:
		reveal()


func _update_ship(delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	var u: float = clampf(t / ship_land_t, 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - u, 3.0)    # frena al acercarse al suelo
	ship.position = ship_pad + Vector3(0, 40.0 * (1.0 - e), 0)
	if u >= 1.0 and not landed:
		landed = true
		v.call("fx_burst", ship_pad + Vector3(0, 0.3, 0), Color(0.75, 0.7, 0.62), 40, 5.0, 1.4)
		v.call("fx_ring", ship_pad + Vector3(0, 0.1, 0), Color(0.8, 0.75, 0.68), 6.0)
		g.set("shake_t", 0.4)
	if flame != null and is_instance_valid(flame):
		flame.emitting = not landed or t < ship_land_t + 0.8
	var gl: OmniLight3D = ship.find_child("engine_light", true, false)
	if gl != null:
		gl.light_energy = 3.0 if not landed else maxf(0.0, gl.light_energy - delta * 4.0)
	# polvo levantado por el motor al acercarse al suelo
	if not landed and u > 0.55:
		burst_t -= delta
		if burst_t <= 0.0:
			burst_t = 0.25
			v.call("fx_burst", ship_pad + Vector3(0, 0.2, 0), Color(0.72, 0.66, 0.58), 10, 4.0, 0.8)


func _update_camera(delta: float) -> void:
	var cam: Camera3D = v.get("cam")
	if keys.is_empty():
		return
	var pos: Vector3
	var look: Vector3
	var last: Dictionary = keys[keys.size() - 1]
	if t >= float(last["t"]):
		# despues del recorrido: orbita lenta alrededor de la escena
		var rel: Vector3 = (last["pos"] as Vector3) - orbit_c
		var ang: float = (t - float(last["t"])) * 0.06
		pos = orbit_c + rel.rotated(Vector3.UP, ang)
		look = last["look"]
	else:
		var i: int = 0
		while i < keys.size() - 2 and t >= float(keys[i + 1]["t"]):
			i += 1
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i + 1]
		var u: float = clampf((t - float(a["t"])) / maxf(0.01, float(b["t"]) - float(a["t"])), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		pos = (a["pos"] as Vector3).lerp(b["pos"], u)
		look = (a["look"] as Vector3).lerp(b["look"], u)
	var sk: float = float(g.get("shake_t"))
	if sk > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * sk * 0.3
		g.set("shake_t", maxf(0.0, sk - delta * 1.2))
	if outside:
		pos.y = maxf(pos.y, _gy(pos) + 0.8)
		var guard: int = 0
		while bool(v.call("_in_base_box", pos)) and guard < 20:
			pos.z += 1.0   # fuera del casco y de su porche (lado sur, abierto)
			guard += 1
	cam.fov = 50.0
	cam.position = pos
	cam.look_at(look, Vector3.UP)
	(v.get("skydome") as Node3D).position = cam.position


# ------------------------------------------------------------------ vista y tarjeta

# Control que muestra la vista 3D a pantalla completa (detras de la tarjeta del final).
func make_view() -> Control:
	view = TextureRect.new()
	view.texture = (g.get("vp3d") as SubViewport).get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(_on_view_input)
	view.draw.connect(_draw_hint)
	var box: Control = g.get("root_box")
	box.modulate.a = 0.0
	return view


func _draw_hint() -> void:
	if revealed or view == null:
		return
	var font: Font = view.get_theme_default_font()
	var a: float = clampf(t - 1.0, 0.0, 1.0) * 0.7
	view.draw_string(font, Vector2(0, view.size.y - 28.0), Lang.t("Pulsa una tecla para ver el resultado"), HORIZONTAL_ALIGNMENT_CENTER, view.size.x, 16, Color(1, 1, 1, a))


func _on_view_input(e: InputEvent) -> void:
	if not revealed and ((e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)):
		reveal()


func handle_key(k: InputEventKey) -> bool:
	if revealed or not k.pressed or k.echo:
		return false
	reveal()
	return true


func reveal() -> void:
	if revealed:
		return
	revealed = true
	if view != null and is_instance_valid(view):
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.queue_redraw()
	var box: Control = g.get("root_box")
	if box != null and is_instance_valid(box):
		var tw: Tween = box.create_tween()
		tw.tween_property(box, "modulate:a", 1.0, 0.6)
