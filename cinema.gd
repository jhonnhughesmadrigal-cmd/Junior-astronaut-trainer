extends RefCounted
# v41 — Cinematicas cortas de los eventos (las pide event_fx.gd; solo dibujo).
# - Esperan a que el jugador este en modo 0 (sin dialogos ni menus) y ponen main.mode = 16: el reloj del juego
#   no avanza (main solo avanza el tiempo en los modos 0 y 5) y el jugador no se mueve.
# - Cada cinematica es una lista de planos: camara (desde -> hasta), mirar a, interior o exterior y rotulo.
# - La primera vez de cada tipo en la partida es larga; las siguientes, cortas. E / Esc / Espacio / Enter la saltan.
# - view3d consulta camera() en _update_camera y view_out() para mostrar el exterior aunque Zadiel este dentro.

const METEOR_GLB: String = "res://art/3d/fx/meteor.glb"
const CINE_MODE: int = 16

var fx = null                   # event_fx.gd
var active: bool = false
var kind: String = ""
var shots: Array = []
var si: int = 0
var t: float = 0.0              # tiempo dentro de la cinematica
var total: float = 0.0
var bars: float = 0.0           # 0-1 franjas de cine
var queue: Array = []
var seen: Dictionary = {}
var meteor: Node3D = null
var trail: CPUParticles3D = null
var impact_done: bool = false
var events: Array = []          # [[tiempo, Callable], ...]
var caption: String = ""
var cap_a: float = 0.0


func reset() -> void:
	queue.clear()
	seen.clear()
	if active:
		_finish()
	active = false


func first_time(k: String) -> bool:
	return not seen.has(k)


func request(k: String, long: bool) -> void:
	if fx == null or not bool(fx.g.view3d_on):
		return
	for q in queue:
		if str(q[0]) == k:
			return
	queue.append([k, long])


# ------------------------------------------------------------------ planos

func _shot(dur: float, out: int, from: Vector3, to: Vector3, look_a: Vector3, look_b: Vector3, cap: String, fov: float = 55.0) -> Dictionary:
	return {"dur": dur, "out": out, "from": from, "to": to, "la": look_a, "lb": look_b, "cap": cap, "fov": fov}


func _build(k: String, long: bool) -> void:
	shots.clear()
	events.clear()
	impact_done = false
	var b: Dictionary = fx.base_box()
	var c: Vector3 = b["c"]
	var hull: Vector3 = fx.breach_out_pos()
	var bin: Vector3 = fx.breach_in_pos()
	var rc: Vector3 = fx.room_center()
	match k:
		"meteor":
			var fall: float = 2.1 if long else 1.4
			shots.append(_shot(fall + 0.5, 1, c + Vector3(26, 18, 34), c + Vector3(20, 14, 28), hull + Vector3(-6, 6, 0), hull,
				Lang.t("¡Un meteoro cae sobre la base!"), 50.0))
			events.append([0.15, _spawn_meteor.bind(hull, fall)])
			events.append([0.15 + fall, _impact.bind(hull)])
			if long:
				shots.append(_shot(1.6, 1, hull + Vector3(5, 2.4, 8), hull + Vector3(3, 1.8, 6), hull, hull,
					Lang.t("Impacto directo en el casco"), 48.0))
			shots.append(_shot(2.4 if long else 1.6, 0, bin + Vector3(4.5, 1.4, 7.5), bin + Vector3(3.0, 0.9, 5.5), bin + Vector3(0, -0.3, 0), bin,
				Lang.t("Brecha: el aire se escapa. Séllala con un kit de parche."), 60.0))
		"storm":
			var d: float = 4.2 if long else 2.4
			shots.append(_shot(d, 1, c + Vector3(70, 26, 60), c + Vector3(46, 18, 52), c + Vector3(0, 4, 0), c + Vector3(0, 2, 0),
				Lang.t("Llega la tormenta de polvo"), 55.0))
			if long:
				shots.append(_shot(2.0, 0, rc + Vector3(9, 8, 10), rc + Vector3(7, 6.5, 9), rc, rc,
					Lang.t("Los paneles solares apenas reciben luz"), 55.0))
		"flare":
			var d2: float = 3.4 if long else 2.2
			shots.append(_shot(d2, 1, c + Vector3(-18, 2.5, 26), c + Vector3(-14, 3.5, 22), c + Vector3(0, 9, 0), c + Vector3(0, 6, 0),
				Lang.t("Erupción solar: llega radiación"), 62.0))
			if long:
				var rp: Vector3 = fx.station_pos("R", 1.2)
				shots.append(_shot(2.0, 0, rp + Vector3(4, 2.2, 5), rp + Vector3(3, 1.8, 4), rp, rp,
					Lang.t("El escudo protege a la tripulación"), 55.0))
		"medical":
			var ch: String = str(fx.sick_ch)
			var hp: Vector3 = fx.crew_head(ch)
			var fwd := Vector3(0, 0, 1)
			var nn: Dictionary = fx.v.get("npc_nodes")
			if nn.has(ch) and is_instance_valid(nn[ch]):
				var ry: float = (nn[ch] as Node3D).rotation.y
				fwd = Vector3(-sin(ry), 0.0, -cos(ry))   # hacia donde mira el tripulante (de frente)
			if hp == Vector3.ZERO:
				hp = rc + Vector3(0, 2.3, 0)
			var side: Vector3 = fwd.cross(Vector3.UP).normalized()
			var who: String = str(fx.g.npcs[ch]["who"]) if fx.g.npcs.has(ch) else ""
			shots.append(_shot(3.2 if long else 2.0, 0, hp + fwd * 3.4 + side * 1.2 - Vector3(0, 0.5, 0), hp + fwd * 2.5 + side * 0.7 - Vector3(0, 0.7, 0),
				hp - Vector3(0, 1.0, 0), hp - Vector3(0, 1.1, 0), Lang.t("%s no se encuentra bien") % who, 48.0))
		"power":
			shots.append(_shot(2.6 if long else 1.6, 0, rc + Vector3(10, 9, 12), rc + Vector3(8, 8, 10), rc, rc,
				Lang.t("Fallo eléctrico: las luces parpadean"), 55.0))
	total = 0.0
	for s in shots:
		total += float(s["dur"])


func _start(k: String, long: bool) -> void:
	kind = k
	seen[k] = true
	_build(k, long)
	if shots.is_empty():
		return
	active = true
	t = 0.0
	si = 0
	bars = 0.0
	fx.g.set("mode", CINE_MODE)
	(fx.g.get("dlg") as Control).visible = false
	_hide_hud(true)
	_apply_view()


func _apply_view() -> void:
	var s: Dictionary = shots[si]
	fx.v.set("cine_out", int(s["out"]))
	fx.v.call("_update_visibility")
	caption = str(s["cap"])
	cap_a = 0.0


func _finish() -> void:
	if kind == "meteor" and not impact_done:
		_impact(fx.breach_out_pos(), true)
	if meteor != null and is_instance_valid(meteor):
		meteor.queue_free()
	meteor = null
	active = false
	shots.clear()
	events.clear()
	_hide_hud(false)
	if fx != null and fx.v != null:
		fx.v.set("cine_out", -1)
		fx.v.call("_update_visibility")
		fx.v.call("snap_camera")
		if int(fx.g.mode) == CINE_MODE:
			fx.g.set("mode", 0)


var _hidden: Array = []


# Durante la cinematica se ocultan el HUD y el registro (hijos de map_view), salvo la capa de efectos.
func _hide_hud(on: bool) -> void:
	if fx == null:
		return
	_tags(not on)
	if on:
		var mv = fx.g.get("map_view")
		if mv == null or not is_instance_valid(mv):
			return
		var kids: Array = (mv as Control).get_children()
		var tp = fx.g.get("tod_panel")
		if tp != null and is_instance_valid(tp) and not kids.has(tp):
			kids.append(tp)
		for c in kids:
			if c is CanvasItem and c != fx.overlay and (c as CanvasItem).visible:
				(c as CanvasItem).visible = false
				if not _hidden.has(c):
					_hidden.append(c)
	else:
		for c in _hidden:
			if is_instance_valid(c):
				(c as CanvasItem).visible = true
		_hidden.clear()


# Etiquetas de nombre (Label3D) de la tripulacion y de Zadiel: fuera durante la cinematica (en primer plano tapan).
func _tags(show: bool) -> void:
	var nodes: Array = (fx.v.get("npc_nodes") as Dictionary).values()
	nodes.append(fx.v.get("player_node"))
	for n in nodes:
		if n == null or not is_instance_valid(n):
			continue
		for l in (n as Node).find_children("*", "Label3D", false, false):
			(l as Label3D).visible = show


func update(delta: float) -> void:
	if not active:
		bars = maxf(0.0, bars - delta * 3.0)
		if not queue.is_empty() and bool(fx.g.playing) and int(fx.g.mode) == 0 and not bool(fx.g.fading):
			var q: Array = queue.pop_front()
			_start(str(q[0]), bool(q[1]))
		return
	t += delta
	_hide_hud(true)   # main vuelve a mostrar el HUD al refrescar: se oculta en cada fotograma
	bars = minf(1.0, bars + delta * 3.0)
	cap_a = minf(1.0, cap_a + delta * 2.5)
	while not events.is_empty() and t >= float(events[0][0]):
		var e: Array = events.pop_front()
		(e[1] as Callable).call()
	var acc: float = 0.0
	for i in shots.size():
		acc += float(shots[i]["dur"])
		if t < acc:
			if i != si:
				si = i
				_apply_view()
			break
	if t >= total:
		_finish()
		return
	_update_meteor(delta)


func camera() -> Dictionary:
	if not active or shots.is_empty():
		return {}
	var s: Dictionary = shots[si]
	var start: float = 0.0
	for i in si:
		start += float(shots[i]["dur"])
	var u: float = clampf((t - start) / float(s["dur"]), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var pos: Vector3 = (s["from"] as Vector3).lerp(s["to"], u)
	var shake: float = float(fx.g.shake_t)
	if shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.5
	return {"pos": pos, "look": (s["la"] as Vector3).lerp(s["lb"], u), "fov": float(s["fov"])}


func view_out() -> int:
	if not active or shots.is_empty():
		return -1
	return int(shots[si]["out"])


# ------------------------------------------------------------------ meteoro

func _spawn_meteor(target: Vector3, fall: float) -> void:
	var root: Node3D = fx.out_root
	meteor = Node3D.new()
	root.add_child(meteor)
	var model: Node3D = null
	if ResourceLoader.exists(METEOR_GLB):
		model = (load(METEOR_GLB) as PackedScene).instantiate()
	else:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.7
		sm.height = 1.4
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.28, 0.24)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.45, 0.15)
		m.emission_energy_multiplier = 1.5
		mi.material_override = m
		model = mi
	model.scale = Vector3.ONE * 2.2
	meteor.add_child(model)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.25)
	glow.light_energy = 4.0
	glow.omni_range = 14.0
	meteor.add_child(glow)
	trail = fx.particles(meteor, 160, 0.8, Color(1.0, 0.62, 0.28, 0.95), 2.0, Vector3(0.5, 0.5, 0.5),
		Vector3(0, 1, 0), 15.0, 0.5, 1.5, Vector3.ZERO, true)
	trail.local_coords = false
	var smoke: CPUParticles3D = fx.particles(meteor, 70, 1.8, Color(0.42, 0.38, 0.36, 0.55), 2.6, Vector3(0.5, 0.5, 0.5),
		Vector3(0, 1, 0), 20.0, 0.2, 0.8, Vector3.ZERO)
	smoke.local_coords = false
	meteor.set_meta("from", target + Vector3(-24, 30, 4))   # arriba a la izquierda, dentro del encuadre
	meteor.set_meta("to", target)
	meteor.set_meta("t0", t)
	if fx.g.has_method("_sfx"):
		fx.g.call("_sfx", "whoosh", -4.0)
	meteor.set_meta("dur", fall)
	meteor.global_position = meteor.get_meta("from")


func _update_meteor(delta: float) -> void:
	if meteor == null or not is_instance_valid(meteor):
		return
	var u: float = clampf((t - float(meteor.get_meta("t0"))) / float(meteor.get_meta("dur")), 0.0, 1.0)
	var a: Vector3 = meteor.get_meta("from")
	var b: Vector3 = meteor.get_meta("to")
	meteor.global_position = a.lerp(b, u * u)   # acelera al caer
	if meteor.get_child_count() > 0:
		(meteor.get_child(0) as Node3D).rotate(Vector3(1, 0.4, 0.2).normalized(), delta * 6.0)


func _impact(at: Vector3, quiet: bool = false) -> void:
	if impact_done:
		return
	impact_done = true
	if meteor != null and is_instance_valid(meteor):
		meteor.queue_free()
		meteor = null
	if quiet:
		return
	fx.impact_flash = 1.0
	fx.g.set("shake_t", 1.2)
	var v: Node3D = fx.v
	v.call("fx_burst", at, Color(1.0, 0.6, 0.25), 40, 6.0, 6.0)
	v.call("fx_burst", at, Color(0.5, 0.46, 0.42), 30, 4.0, 3.0)
	v.call("fx_ring", Vector3(at.x, float(v.call("ground_y", at.x / 2.0, at.z / 2.0)) + 0.1, at.z + 1.0), Color(0.75, 0.7, 0.62), 4.0)
	# escombros que salen despedidos y caen
	var deb: CPUParticles3D = fx.particles(fx.out_root, 46, 1.6, Color(0.42, 0.38, 0.35, 1.0), 0.22, Vector3(0.6, 0.6, 0.4),
		Vector3(0, 1, 0.6), 60.0, 4.0, 9.0, Vector3(0, -6.0, 0))
	deb.position = at
	deb.one_shot = true
	deb.explosiveness = 0.9
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.7, 0.4)
	fl.light_energy = 12.0
	fl.omni_range = 30.0
	fl.position = at + Vector3(0, 1.0, 2.0)
	fx.out_root.add_child(fl)
	var tw: Tween = fx.create_tween()
	tw.tween_property(fl, "light_energy", 0.0, 0.9)
	tw.tween_callback(fl.queue_free)
	fx.get_tree().create_timer(3.0).timeout.connect(deb.queue_free)
	var g = fx.g
	if g.has_method("_sfx"):
		g.call("_sfx", "impact", -2.0)


# ------------------------------------------------------------------ dibujo y entrada

func draw(c: Control, sz: Vector2) -> void:
	if bars <= 0.001:
		return
	var h: float = sz.y * 0.11 * bars
	c.draw_rect(Rect2(0, 0, sz.x, h), Color(0, 0, 0, 0.96))
	c.draw_rect(Rect2(0, sz.y - h, sz.x, h), Color(0, 0, 0, 0.96))
	if not active:
		return
	var font: Font = c.get_theme_default_font()
	var fs: int = int(clampf(sz.y * 0.035, 16.0, 30.0))
	if caption != "":
		c.draw_string(font, Vector2(0, sz.y - h * 0.5 + fs * 0.35), caption, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, Color(1, 1, 1, cap_a))
	var hint: String = Lang.t("Saltar [E]")
	c.draw_string(font, Vector2(0, h * 0.5 + 6.0), hint, HORIZONTAL_ALIGNMENT_RIGHT, sz.x - 24.0, int(fs * 0.6), Color(1, 1, 1, 0.55 * bars))


func handle_key(k: InputEventKey) -> bool:
	if not active:
		return false
	if k.pressed and not k.echo and k.keycode in [KEY_E, KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_finish()
	return true
