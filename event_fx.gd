extends Node3D
# v41 — Visibilidad de los eventos (solo dibujo; no cambia la logica del juego).
# Lo crea view3d (hijo suyo) y lo llama:
#   setup()          tras construir el mundo (cada partida)
#   trigger(k, d)    cuando main.gd anuncia un evento (meteor, micro, medical, storm_warn, storm, flare, power,
#                    oxygen, water, harvest, message, plague, salvage, sealed)
#   update(delta)    cada fotograma, despues de la luz (efectos que dependen del estado: brecha, tormenta...)
#   npc_pose(ch)     pose de evento de cada tripulante ("" = la normal)
# Efectos persistentes (mientras dure el problema): brecha (alarma roja giratoria, chispas, aire escapando,
# grieta; fuera humo y quemadura), apagon (luces que parpadean, chispas), fuga de O2 (vapor), fuga de agua
# (goteo), tormenta de polvo (viento con polvo, niebla densa, sol tapado, muro de polvo que se acerca),
# erupcion solar (destellos, escudo encendido) y enfermo (tos, pose encorvada, icono de botiquin).
# Bocadillos: frases cortas sobre la cabeza (event_lines.gd), al empezar el evento y cada ~20-30 s.
# Cinematicas (cinema.gd): pausan el reloj, franjas de cine, se saltan con E / Esc / clic.

const EventLines = preload("res://event_lines.gd")
const Cinema = preload("res://cinema.gd")
const ItemIcons = preload("res://item_icons.gd")

var v: Node3D = null            # view3d
var g: Node = null              # main.gd
var rng := RandomNumberGenerator.new()
var cine = null                 # cinema.gd
var t: float = 0.0
var in_root: Node3D = null      # efectos dentro de la base (hijo de view3d.interior)
var out_root: Node3D = null     # efectos fuera (hijo de view3d.exterior)
var parts: Dictionary = {}      # nombre -> nodo persistente
var moods: Dictionary = {}      # ch -> {"pose": String, "left": float}
var recent: Dictionary = {}     # tipo de evento -> segundos que quedan de ambiente
var sick_ch: String = ""
var bubbles: Dictionary = {}    # ch -> {"panel": PanelContainer, "label": Label, "left": float}
var talk_cd: float = 8.0
var overlay: Control = null
var vignette: Texture2D = null
var flicker: float = 1.0
var storm_k: float = 0.0        # 0-1: intensidad visual de la tormenta (sube y baja suave)
var flare_k: float = 0.0
var shield_flash: float = 0.0
var impact_flash: float = 0.0
var _light_e0: Dictionary = {}
var wind_player: AudioStreamPlayer = null   # v41: viento en bucle durante la tormenta
var force: Dictionary = {}      # v41: la escena final fuerza efectos sin incidente ("water", "o2", "flare")
var light_override: float = -1.0   # v41: >= 0 fija la intensidad de las luces del interior (escena final)


func init(view: Node3D) -> void:
	v = view
	g = view.get("game")
	rng.seed = 41041
	cine = Cinema.new()
	cine.fx = self


func setup() -> void:
	for k in parts.keys():
		var n = parts[k]
		if n != null and is_instance_valid(n):
			n.queue_free()
	parts.clear()
	moods.clear()
	recent.clear()
	sick_ch = ""
	_light_e0.clear()
	force.clear()
	light_override = -1.0
	storm_k = 0.0
	flare_k = 0.0
	for ch in bubbles.keys():
		var b: Dictionary = bubbles[ch]
		if is_instance_valid(b["panel"]):
			(b["panel"] as Node).queue_free()
	bubbles.clear()
	if cine != null:
		cine.reset()
	if in_root != null and is_instance_valid(in_root):
		in_root.queue_free()
	if out_root != null and is_instance_valid(out_root):
		out_root.queue_free()
	in_root = Node3D.new()
	in_root.name = "EventFxIn"
	(v.get("interior") as Node3D).add_child(in_root)
	out_root = Node3D.new()
	out_root.name = "EventFxOut"
	(v.get("exterior") as Node3D).add_child(out_root)


# ------------------------------------------------------------------ posiciones

func station_pos(ch: String, h: float = 1.2) -> Vector3:
	var map: Array = g.MAP
	for y in map.size():
		var x: int = str(map[y]).find(ch)
		if x >= 0:
			return v.call("_tp", x, y, h)
	return Vector3(16.0, h, 11.0)


func room_center() -> Vector3:
	return Vector3(float(str(g.MAP[0]).length()) * 0.5 * 2.0, 0.0, float(g.MAP.size()) * 0.5 * 2.0)


func breach_in_pos() -> Vector3:
	# pared norte, entre el soporte vital y el panel solar
	return Vector3(7.0, 1.9, 2.12)


func base_box() -> Dictionary:
	var T: float = 2.0
	var bx: float = float(g.BASE_X0)
	var by: float = float(g.BASE_Y0)
	return {"x0": (bx - 3.0) * T, "x1": (bx + 7.0) * T, "z0": (by - 1.0) * T, "z1": (by + 3.0) * T,
		"c": Vector3((bx + 2.0) * T, 0.0, (by + 1.0) * T), "air": Vector3((bx + 2.5) * T, 0.0, (by + 3.0) * T)}


func breach_out_pos() -> Vector3:
	var b: Dictionary = base_box()
	return Vector3(float(b["x0"]) + 5.0, 2.3, float(b["z1"]) + 0.08)


func crew_head(ch: String) -> Vector3:
	var nn: Dictionary = v.get("npc_nodes")
	if nn.has(ch) and is_instance_valid(nn[ch]):
		return (nn[ch] as Node3D).global_position + Vector3(0, 2.35, 0)
	return Vector3.ZERO


# ------------------------------------------------------------------ utilidades de efectos

func _soft_mat(col: Color, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.albedo_texture = _dot_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static var _dot: Texture2D = null


static func _dot_tex() -> Texture2D:
	if _dot == null:
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		_dot = gt
	return _dot


func fx_q() -> float:
	# cantidad de particulas segun "Efectos" (Bajo/Medio/Alto)
	return [0.35, 0.7, 1.0][clampi(int(g.fx_idx), 0, 2)]


func particles(parent: Node3D, amount: int, life: float, col: Color, size: float, box: Vector3, dir: Vector3,
		spread: float, vmin: float, vmax: float, grav: Vector3, additive: bool = false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(4, int(float(amount) * fx_q()))
	p.lifetime = life
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	p.mesh = qm
	p.material_override = _soft_mat(col, additive)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var gr := Gradient.new()
	gr.set_color(0, Color(col.r, col.g, col.b, 0.0))
	gr.add_point(0.15, col)
	gr.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = gr
	p.local_coords = false
	parent.add_child(p)
	return p


func _crack_tex() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for arm in 9:
		var a: float = TAU * float(arm) / 9.0 + r.randf_range(-0.2, 0.2)
		var p := Vector2(64, 64)
		var len: float = r.randf_range(30, 60)
		for s in int(len):
			a += r.randf_range(-0.25, 0.25)
			p += Vector2(cos(a), sin(a))
			var w: int = 2 if s < len * 0.4 else 1
			for dx in range(-w, w + 1):
				for dy in range(-w, w + 1):
					var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
					if q.x >= 0 and q.y >= 0 and q.x < 128 and q.y < 128:
						img.set_pixelv(q, Color(0.05, 0.04, 0.04, 0.95))
	# centro quemado
	for y in 128:
		for x in 128:
			var d: float = Vector2(x - 64, y - 64).length()
			if d < 14.0:
				var c: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, Color(0.06, 0.05, 0.05, maxf(c.a, 1.0 - d / 14.0)))
	return ImageTexture.create_from_image(img)


func _quad(parent: Node3D, tex: Texture2D, size: Vector2, pos: Vector3, normal: Vector3, col: Color = Color.WHITE) -> MeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = col
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	if normal.abs() != Vector3.UP:
		mi.look_at(pos + normal, Vector3.UP)
		mi.rotate_object_local(Vector3.UP, PI)
	else:
		mi.rotation = Vector3(-PI / 2.0, 0, 0)
	return mi


func _light(parent: Node3D, pos: Vector3, col: Color, energy: float, rangev: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rangev
	l.shadow_enabled = false
	l.position = pos
	parent.add_child(l)
	return l


func _ensure(nm: String, build: Callable) -> Node3D:
	if not parts.has(nm) or not is_instance_valid(parts[nm]):
		parts[nm] = build.call()
	return parts[nm]


func _drop(nm: String) -> void:
	if parts.has(nm):
		var n = parts[nm]
		if n != null and is_instance_valid(n):
			n.queue_free()
		parts.erase(nm)


# ------------------------------------------------------------------ piezas persistentes

func _build_breach_in() -> Node3D:
	var n := Node3D.new()
	in_root.add_child(n)
	var p: Vector3 = breach_in_pos()
	_quad(n, _crack_tex(), Vector2(1.3, 1.3), p, Vector3(0, 0, 1))
	var sp: CPUParticles3D = particles(n, 26, 0.5, Color(1.0, 0.75, 0.35), 0.08, Vector3(0.12, 0.12, 0.02),
		Vector3(0, -0.3, 1), 40.0, 2.0, 4.5, Vector3(0, -9.0, 0), true)
	sp.position = p + Vector3(0, 0, 0.05)
	sp.name = "sparks"
	var va: CPUParticles3D = particles(n, 40, 1.4, Color(0.85, 0.9, 0.95, 0.5), 0.5, Vector3(0.08, 0.08, 0.02),
		Vector3(0, 0.1, 1), 12.0, 1.2, 2.6, Vector3(0, 0.3, 0))
	va.position = p + Vector3(0, 0, 0.05)
	va.name = "vapor"
	# baliza de alarma giratoria en el techo + luz roja que late
	var bc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.18
	cm.height = 0.22
	bc.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.8, 0.12, 0.1)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.15, 0.1)
	bm.emission_energy_multiplier = 2.0
	bc.material_override = bm
	bc.position = room_center() + Vector3(0, 3.0, 0)
	n.add_child(bc)
	var red: OmniLight3D = _light(n, room_center() + Vector3(0, 2.6, 0), Color(1.0, 0.18, 0.12), 0.0, 22.0)
	red.name = "alarm"
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.2, 0.12)
	spot.light_energy = 1.2
	spot.spot_range = 16.0
	spot.spot_angle = 22.0
	spot.position = room_center() + Vector3(0, 3.0, 0)
	spot.name = "beam"
	n.add_child(spot)
	return n


func _build_breach_out() -> Node3D:
	var n := Node3D.new()
	out_root.add_child(n)
	var p: Vector3 = breach_out_pos()
	var sc := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.03, 0.02, 0.02, 0.95))
	gr.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
	sc.gradient = gr
	sc.fill = GradientTexture2D.FILL_RADIAL
	sc.fill_from = Vector2(0.5, 0.5)
	sc.fill_to = Vector2(1.0, 0.5)
	_quad(n, sc, Vector2(2.4, 2.0), p, Vector3(0, 0, 1))
	_quad(n, _crack_tex(), Vector2(1.2, 1.2), p + Vector3(0, 0, 0.01), Vector3(0, 0, 1))
	var sm: CPUParticles3D = particles(n, 40, 3.2, Color(0.35, 0.33, 0.32, 0.55), 1.1, Vector3(0.2, 0.2, 0.1),
		Vector3(0.2, 1, 0.4), 20.0, 0.6, 1.4, Vector3(0.15, 0.25, 0))
	sm.position = p + Vector3(0, 0.2, 0.2)
	sm.name = "smoke"
	var sp: CPUParticles3D = particles(n, 18, 0.6, Color(1.0, 0.7, 0.3), 0.1, Vector3(0.1, 0.1, 0.05),
		Vector3(0, 0.2, 1), 50.0, 2.0, 4.0, Vector3(0, -4.0, 0), true)
	sp.position = p + Vector3(0, 0, 0.1)
	return n


func _build_vapor(at: Vector3) -> Node3D:
	var n := Node3D.new()
	in_root.add_child(n)
	var va: CPUParticles3D = particles(n, 22, 1.2, Color(0.9, 0.95, 1.0, 0.4), 0.35, Vector3(0.1, 0.05, 0.1),
		Vector3(0.3, 1, 0), 25.0, 0.5, 1.2, Vector3(0, 0.2, 0))
	va.position = at
	return n


func _build_drip(at: Vector3) -> Node3D:
	var n := Node3D.new()
	in_root.add_child(n)
	var dr: CPUParticles3D = particles(n, 10, 0.9, Color(0.45, 0.7, 1.0, 0.85), 0.07, Vector3(0.25, 0.02, 0.25),
		Vector3(0, -1, 0), 2.0, 0.2, 0.4, Vector3(0, -9.0, 0))
	dr.position = at + Vector3(0, 1.4, 0.6)
	var pud := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.35, 0.55, 0.8, 0.55))
	gr.set_color(1, Color(0.35, 0.55, 0.8, 0.0))
	pud.gradient = gr
	pud.fill = GradientTexture2D.FILL_RADIAL
	pud.fill_from = Vector2(0.5, 0.5)
	pud.fill_to = Vector2(1.0, 0.5)
	var q: MeshInstance3D = _quad(n, pud, Vector2(1.6, 1.2), Vector3(at.x, 0.03, at.z + 0.7), Vector3.UP)
	(q.material_override as StandardMaterial3D).metallic = 0.4
	(q.material_override as StandardMaterial3D).roughness = 0.05
	return n


func _build_sparks(at: Vector3) -> Node3D:
	var n := Node3D.new()
	in_root.add_child(n)
	var sp: CPUParticles3D = particles(n, 16, 0.45, Color(1.0, 0.85, 0.45), 0.07, Vector3(0.15, 0.1, 0.15),
		Vector3(0, 1, 0), 70.0, 1.5, 3.5, Vector3(0, -9.0, 0), true)
	sp.position = at
	sp.explosiveness = 0.6
	return n


func _build_storm_out() -> Node3D:
	var n := Node3D.new()
	out_root.add_child(n)
	# viento con polvo alrededor del jugador (lo mueve update)
	var w: CPUParticles3D = particles(n, 420, 2.2, Color(0.78, 0.52, 0.32, 0.5), 1.6, Vector3(26, 6, 26),
		Vector3(1, 0.05, 0.25), 8.0, 9.0, 16.0, Vector3.ZERO)
	w.name = "wind"
	var w2: CPUParticles3D = particles(n, 260, 1.4, Color(0.9, 0.66, 0.42, 0.35), 0.25, Vector3(18, 4, 18),
		Vector3(1, 0.1, 0.2), 6.0, 14.0, 22.0, Vector3.ZERO)
	w2.name = "grit"
	# muro de polvo (aviso y llegada): cilindro abierto con degradado vertical
	var wall := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 48
	wall.mesh = cm
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.72, 0.46, 0.28, 0.0))
	gr.add_point(0.45, Color(0.7, 0.45, 0.28, 0.55))
	gr.set_color(1, Color(0.62, 0.4, 0.25, 0.85))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = gt
	wall.material_override = m
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.name = "wall"
	n.add_child(wall)
	return n


func _build_storm_in() -> Node3D:
	var n := Node3D.new()
	in_root.add_child(n)
	var d: CPUParticles3D = particles(n, 60, 4.0, Color(0.85, 0.65, 0.45, 0.35), 0.12, Vector3(14, 1.4, 9),
		Vector3(1, 0, 0), 30.0, 0.1, 0.35, Vector3(0, -0.02, 0))
	d.position = room_center() + Vector3(0, 1.4, 0)
	return n


func _build_shield() -> Node3D:
	# burbuja del escudo alrededor de la base (fuera) y luz violeta en el generador (dentro)
	var n := Node3D.new()
	out_root.add_child(n)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 40
	sm.rings = 20
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.55, 0.45, 1.0, 0.0)
	m.rim_enabled = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b: Dictionary = base_box()
	mi.position = b["c"]
	mi.scale = Vector3((float(b["x1"]) - float(b["x0"])) * 0.75, 7.0, (float(b["z1"]) - float(b["z0"])) * 1.4)
	mi.name = "bubble"
	n.add_child(mi)
	var rad: CPUParticles3D = particles(n, 90, 0.9, Color(0.85, 0.8, 1.0, 0.8), 0.12, Vector3(30, 2, 30),
		Vector3(-0.4, -1, -0.2), 5.0, 25.0, 40.0, Vector3.ZERO, true)
	rad.position = (b["c"] as Vector3) + Vector3(0, 26.0, 0)
	rad.name = "rays"
	var gl: OmniLight3D = _light(in_root, station_pos("R", 1.6), Color(0.65, 0.5, 1.0), 0.0, 9.0)
	gl.name = "flare_glow"
	parts["flare_glow"] = gl
	return n


func _build_sick_icon() -> Node3D:
	var s := Sprite3D.new()
	s.texture = ItemIcons.texture("medkit")
	s.pixel_size = 0.0045
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.modulate = Color(1, 1, 1, 0.92)
	in_root.add_child(s)
	return s


# ------------------------------------------------------------------ eventos

# Lo llama main.gd (via view3d.event_fx) cuando ocurre algo.
func trigger(kind: String, data: Dictionary = {}) -> void:
	if v == null or in_root == null:
		return
	var long: bool = cine.first_time(kind)
	match kind:
		"meteor":
			_mood_all("cower", 5.0)
			recent["meteor"] = 25.0
			cine.request("meteor", long)
			_say_event("meteor", 0.3)
		"micro":
			g.set("shake_t", maxf(float(g.get("shake_t")), 0.45))
			_mood_all("look_up", 6.0)
			recent["micro"] = 6.0
			var p: Vector3 = breach_in_pos() + Vector3(rng.randf_range(-3, 6), rng.randf_range(-0.4, 0.6), 0)
			v.call("fx_burst", p, Color(1.0, 0.8, 0.4), 12, 2.0, 1.6)
			_say_event("micro", 0.6, 1)
		"medical":
			sick_ch = str(data.get("ch", "")) if data.has("ch") else _pick_sick()
			recent["medical"] = 20.0
			cine.request("medical", long)
			_say_event("medical", 0.4)
		"storm_warn":
			recent["storm_warn"] = 30.0
			_mood("l", "point", 5.0)
			_say_event("storm_warn", 0.4, 2)
		"storm":
			recent["storm"] = 30.0
			cine.request("storm", long)
			_mood_all("look_up", 8.0)
			_say_event("storm", 1.0)
		"flare":
			recent["flare"] = 25.0
			shield_flash = 1.0
			cine.request("flare", long)
			_mood_all("cower", 6.0)
			_say_event("flare", 0.4)
		"power":
			recent["power"] = 12.0
			cine.request("power", long)
			_mood("k", "point", 4.0)
			_say_event("power", 0.5, 2)
		"oxygen":
			recent["oxygen"] = 10.0
			_say_event("oxygen", 0.5, 1)
		"water":
			recent["water"] = 10.0
			_say_event("water", 0.5, 1)
		"harvest":
			recent["harvest"] = 9.0
			_mood_all("cheer", 5.0)
			var gp: Vector3 = station_pos("G", 1.4)
			v.call("fx_burst", gp, Color(0.55, 0.95, 0.45), 26, 1.8, 2.8)
			v.call("fx_ring", gp - Vector3(0, 1.3, 0), Color(0.55, 0.95, 0.45), 1.0)
			v.call("fx_popup", gp + Vector3(0, 1.4, 0), Lang.t("+12 comida"), Color(0.6, 1.0, 0.5))
			_say_event("harvest", 0.3, 2)
		"message":
			recent["message"] = 9.0
			_mood_all("cheer", 4.0)
			var ap: Vector3 = station_pos("A", 2.2)
			for i in 3:
				v.call("fx_ring", ap + Vector3(0, float(i) * 0.4, 0), Color(0.55, 0.85, 1.0), 0.5 + float(i) * 0.4)
			v.call("fx_popup", ap + Vector3(0, 0.8, 0), Lang.t("+10 moral"), Color(0.6, 0.9, 1.0))
			_say_event("message", 0.3, 2)
		"plague":
			recent["plague"] = 20.0
			_mood_all("tired", 8.0)
			var pp: Vector3 = station_pos("G", 1.0)
			v.call("fx_burst", pp, Color(0.5, 0.42, 0.25), 22, 1.0, 1.4)
			v.call("fx_popup", pp + Vector3(0, 1.6, 0), Lang.t("-25 comida"), Color(1.0, 0.6, 0.4))
			_say_event("plague", 0.4, 2)
		"salvage":
			recent["salvage"] = 8.0
			_mood("k", "cheer", 4.0)
			var kp: Vector3 = crew_head("k")
			if kp != Vector3.ZERO:
				v.call("fx_burst", kp - Vector3(0, 1.0, 0), Color(0.75, 0.75, 0.72), 14, 1.2, 1.8)
				v.call("fx_popup", kp, Lang.t("+2 chatarra"), Color(0.9, 0.9, 0.85))
			_say_event("salvage", 0.3, 2)
		"sealed":
			recent["sealed"] = 8.0
			_mood_all("cheer", 4.0)
			_say_event("sealed", 0.3, 2)
	talk_cd = rng.randf_range(20.0, 30.0)


func _pick_sick() -> String:
	var ks: Array = ["a", "k", "l"]
	return ks[(int(g.day) + int(g.clock)) % 3]


func _mood(ch: String, pose: String, secs: float) -> void:
	moods[ch] = {"pose": pose, "left": secs}


func _mood_all(pose: String, secs: float) -> void:
	for ch in (v.get("npc_nodes") as Dictionary).keys():
		_mood(ch, pose, secs)


func npc_pose(ch: String) -> String:
	if g == null:
		return ""
	if moods.has(ch) and float(moods[ch]["left"]) > 0.0:
		var p: String = str(moods[ch]["pose"])
		if not (ch == sick_ch and int(g.ill_days) > 0 and p == "cheer"):
			return p
	if ch == sick_ch and int(g.ill_days) > 0:
		return "sick"
	if bool(g.breach):
		return "alarm"
	if int(g.storm_left) > 0 and not bool(g.outside):
		return "look_up"
	if g.emg != null and bool(g.emg.has_kind("flare")):
		return "look_up"
	return ""


# ------------------------------------------------------------------ bocadillos

func _say_event(kind: String, delay: float = 0.4, max_n: int = 3) -> void:
	var chs: Array = (v.get("npc_nodes") as Dictionary).keys()
	chs.shuffle()
	var n: int = 0
	for ch in chs:
		if n >= max_n:
			break
		var line: String = EventLines.pick(kind, ch, ch == sick_ch, rng)
		if line == "":
			continue
		get_tree().create_timer(delay + float(n) * 1.6).timeout.connect(say.bind(ch, line))
		n += 1


func say(ch: String, text: String, secs: float = 4.2) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	var b: Dictionary = bubbles.get(ch, {})
	if b.is_empty() or not is_instance_valid(b["panel"]):
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.96, 0.94, 0.94)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 5
		sb.content_margin_bottom = 6
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 4
		pc.add_theme_stylebox_override("panel", sb)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.add_theme_color_override("font_color", Color(0.1, 0.11, 0.14))
		l.add_theme_font_size_override("font_size", 15)
		pc.add_child(l)
		overlay.add_child(pc)
		b = {"panel": pc, "label": l, "left": 0.0}
		bubbles[ch] = b
	(b["label"] as Label).text = text
	if ch == sick_ch and int(g.ill_days) > 0 and g.has_method("_sfx"):
		g.call("_sfx", "cough", -10.0)
	var pc2: PanelContainer = b["panel"]
	var lb: Label = b["label"]
	if text.length() <= 30:
		lb.autowrap_mode = TextServer.AUTOWRAP_OFF
		lb.custom_minimum_size = Vector2.ZERO
	else:
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(240, 0)
	pc2.reset_size()
	b["left"] = secs
	pc2.modulate.a = 0.0


func _update_bubbles(delta: float) -> void:
	var cam: Camera3D = v.get("cam")
	var mv: Vector2 = g.call("_mv")
	var vs: Vector2 = (v.get_viewport() as Viewport).get_visible_rect().size
	for ch in bubbles.keys():
		var b: Dictionary = bubbles[ch]
		var pc: PanelContainer = b["panel"]
		if not is_instance_valid(pc):
			continue
		b["left"] = float(b["left"]) - delta
		var show: bool = float(b["left"]) > 0.0 and not bool(g.outside) and not cine.active and g.mode == 0
		var head: Vector3 = crew_head(ch)
		if show and head != Vector3.ZERO and not cam.is_position_behind(head):
			var sp: Vector2 = cam.unproject_position(head) / vs * mv
			pc.reset_size()
			pc.position = Vector2(clampf(sp.x - pc.size.x * 0.5, 6.0, mv.x - pc.size.x - 6.0), clampf(sp.y - pc.size.y, 70.0, mv.y - pc.size.y - 6.0))
			pc.modulate.a = minf(1.0, pc.modulate.a + delta * 5.0) * clampf(float(b["left"]) * 2.0, 0.0, 1.0)
			pc.visible = true
		else:
			pc.visible = false


# ------------------------------------------------------------------ actualizacion por fotograma

func update(delta: float) -> void:
	if v == null or in_root == null or not is_instance_valid(in_root):
		return
	t += delta
	_ensure_overlay()
	for ch in moods.keys():
		moods[ch]["left"] = float(moods[ch]["left"]) - delta
	for k in recent.keys():
		recent[k] = float(recent[k]) - delta
		if float(recent[k]) <= 0.0:
			recent.erase(k)
	cine.update(delta)
	var inside: bool = not bool(v.call("is_out"))
	# --- brecha en el casco ---
	if bool(g.breach):
		var bi: Node3D = _ensure("breach_in", _build_breach_in)
		var bo: Node3D = _ensure("breach_out", _build_breach_out)
		var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
		var al: OmniLight3D = bi.get_node_or_null("alarm")
		if al != null:
			al.light_energy = 0.15 + 0.5 * pulse
		var beam: SpotLight3D = bi.get_node_or_null("beam")
		if beam != null:
			beam.rotation = Vector3(-0.9, t * 3.2, 0)
		bi.visible = true
		bo.visible = true
	else:
		if parts.has("breach_in"):
			_drop("breach_in")
			_drop("breach_out")
	# --- incidentes activos (centro de diagnostico) ---
	var has_o2: bool = (g.emg != null and bool(g.emg.has_kind("oxygen")) and not bool(g.breach)) or force.has("o2")
	var has_w: bool = (g.emg != null and bool(g.emg.has_kind("water"))) or force.has("water")
	var has_p: bool = g.emg != null and bool(g.emg.has_kind("power"))
	if has_o2:
		_ensure("o2", _build_vapor.bind(station_pos("O", 1.3)))
	else:
		_drop("o2")
	if has_w:
		_ensure("water", _build_drip.bind(station_pos("W", 0.0)))
	else:
		_drop("water")
	var low_e: bool = float((g.res as Dictionary).get("energy", 100.0)) < 12.0
	if has_p or low_e:
		_ensure("pspark", _build_sparks.bind(station_pos("S", 1.4)))
		flicker = 0.55 + 0.45 * (1.0 if fmod(t * 7.3, 1.0) > 0.18 else 0.15) * (0.75 + 0.25 * sin(t * 31.0))
	else:
		_drop("pspark")
		flicker = 1.0
	if recent.has("power") and cine.active:
		flicker = 0.25 + 0.75 * float(fmod(t * 9.0, 1.0) > 0.5)
	_apply_light_flicker()
	# --- tormenta ---
	var storm_on: bool = int(g.storm_left) > 0
	var warn_on: bool = g.emg != null and bool(g.emg.has_kind("storm")) and not storm_on
	storm_k = move_toward(storm_k, 1.0 if storm_on else 0.0, delta * 0.35)
	if storm_k > 0.01 or warn_on:
		var so: Node3D = _ensure("storm_out", _build_storm_out)
		var pf: Vector2 = g.pos_f if bool(g.outside) else Vector2(float(g.BASE_X0 + 2), float(g.BASE_Y0 + 4))
		var cen := Vector3(pf.x * 2.0, float(v.call("ground_y", pf.x, pf.y)), pf.y * 2.0)
		for nm in ["wind", "grit"]:
			var pp: CPUParticles3D = so.get_node_or_null(nm)
			if pp != null:
				pp.position = cen + Vector3(-14.0, 3.0, 0)
				pp.emitting = storm_k > 0.05
				pp.speed_scale = 0.6 + 0.6 * storm_k
		var wall: MeshInstance3D = so.get_node_or_null("wall")
		if wall != null:
			var r: float = 260.0
			if warn_on:
				var inc: Dictionary = g.call("_emg_find_kind", "storm")
				var left: float = float(g.emg.remaining(inc)) if not inc.is_empty() else 600.0
				r = lerpf(70.0, 260.0, clampf(left / 720.0, 0.0, 1.0))
			elif storm_k > 0.0:
				r = lerpf(260.0, 20.0, storm_k)
			wall.position = cen + Vector3(0, 14.0, 0)
			wall.scale = Vector3(r, 40.0, r)
			wall.visible = r > 22.0
		if storm_on and inside:
			_ensure("storm_in", _build_storm_in)
		else:
			_drop("storm_in")
	else:
		_drop("storm_out")
		_drop("storm_in")
	_update_wind()
	# --- erupcion solar ---
	var flare_on: bool = (g.emg != null and bool(g.emg.has_kind("flare"))) or force.has("flare")
	flare_k = move_toward(flare_k, 1.0 if (flare_on or recent.has("flare")) else 0.0, delta * 0.8)
	shield_flash = maxf(0.0, shield_flash - delta * 0.35)
	if flare_k > 0.01:
		var sh: Node3D = _ensure("shield", _build_shield)
		var bub: MeshInstance3D = sh.get_node_or_null("bubble")
		if bub != null:
			(bub.material_override as StandardMaterial3D).albedo_color.a = (0.05 + 0.04 * sin(t * 4.0)) * flare_k + 0.3 * shield_flash
		var rays: CPUParticles3D = sh.get_node_or_null("rays")
		if rays != null:
			rays.emitting = flare_k > 0.2
		if parts.has("flare_glow") and is_instance_valid(parts["flare_glow"]):
			(parts["flare_glow"] as OmniLight3D).light_energy = (1.2 + 0.8 * sin(t * 5.0)) * flare_k
	else:
		_drop("shield")
		_drop("flare_glow")
	# --- enfermo ---
	if int(g.ill_days) > 0:
		if sick_ch == "":
			sick_ch = _pick_sick()
		var ic: Node3D = _ensure("sick_icon", _build_sick_icon)
		var hp: Vector3 = crew_head(sick_ch)
		ic.visible = hp != Vector3.ZERO
		ic.global_position = hp + Vector3(0, 0.45 + 0.08 * sin(t * 2.5), 0)
	else:
		_drop("sick_icon")
		if sick_ch != "" and int(g.ill_days) <= 0:
			sick_ch = ""
	# --- charla de fondo mientras dura algo ---
	talk_cd -= delta
	if talk_cd <= 0.0 and inside and g.mode == 0 and not cine.active:
		talk_cd = rng.randf_range(20.0, 30.0)
		var k2: String = _ambient_kind()
		if k2 != "":
			_say_event(k2, 0.0, 1)
	_update_bubbles(delta)
	if overlay != null:
		overlay.queue_redraw()


func _update_wind() -> void:
	var vol: float = storm_k * float(g.get("sfx_vol")) * (1.0 if bool(v.call("is_out")) else 0.3)
	if vol <= 0.01:
		if wind_player != null and is_instance_valid(wind_player) and wind_player.playing:
			wind_player.stop()
		return
	if wind_player == null or not is_instance_valid(wind_player):
		var st = load("res://audio/wind.wav") if ResourceLoader.exists("res://audio/wind.wav") else null
		if st == null or not (st is AudioStreamWAV):
			return
		var w: AudioStreamWAV = (st as AudioStreamWAV).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2   # 16 bits mono
		wind_player = AudioStreamPlayer.new()
		wind_player.stream = w
		add_child(wind_player)
	if not wind_player.playing:
		wind_player.play()
	wind_player.volume_db = linear_to_db(maxf(vol, 0.0001)) - 4.0


func _ambient_kind() -> String:
	if bool(g.breach):
		return "breach"
	if int(g.ill_days) > 0:
		return "sick"
	if int(g.storm_left) > 0:
		return "storm"
	if g.emg != null:
		if bool(g.emg.has_kind("flare")):
			return "flare"
		if bool(g.emg.has_kind("storm")):
			return "storm_warn"
		if bool(g.emg.has_kind("power")):
			return "power"
		if bool(g.emg.has_kind("oxygen")):
			return "oxygen"
		if bool(g.emg.has_kind("water")):
			return "water"
	return ""


func _apply_light_flicker() -> void:
	var InteriorLook = load("res://interior_look.gd")
	for l in InteriorLook.lights:
		if l == null or not is_instance_valid(l):
			continue
		var id: int = (l as Object).get_instance_id()
		if not _light_e0.has(id):
			_light_e0[id] = (l as OmniLight3D).light_energy
		var f: float = flicker if light_override < 0.0 else light_override
		if bool(g.breach):
			f *= 0.75
		(l as OmniLight3D).light_energy = float(_light_e0[id]) * f


# Ajustes de luz y niebla despues de view3d._update_light (tormenta, erupcion, impacto).
func post_light() -> void:
	if v == null:
		return
	var env: Environment = v.get("env")
	var sun: DirectionalLight3D = v.get("sun")
	var out: bool = bool(v.call("is_out"))
	if out and storm_k > 0.0:
		env.fog_enabled = true
		env.fog_density = lerpf(env.fog_density, 0.05, storm_k)
		env.fog_light_color = env.fog_light_color.lerp(Color(0.62, 0.42, 0.28), storm_k)
		sun.light_energy *= 1.0 - 0.6 * storm_k
		env.adjustment_saturation *= 1.0 - 0.25 * storm_k
	if out and flare_k > 0.0:
		var fl: float = maxf(0.0, sin(t * 2.3) * sin(t * 5.1)) * 0.6 * flare_k + shield_flash * 0.8
		env.tonemap_exposure *= 1.0 + fl
	if impact_flash > 0.0:
		env.tonemap_exposure *= 1.0 + impact_flash * 2.5
		impact_flash = maxf(0.0, impact_flash - get_process_delta_time() * 2.0)


# ------------------------------------------------------------------ capa de pantalla (velos y cine)

func _ensure_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	var mv = g.get("map_view")
	if mv == null or not is_instance_valid(mv):
		return
	overlay = Control.new()
	overlay.name = "EventOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(mv as Control).add_child(overlay)
	(mv as Control).move_child(overlay, 0)
	overlay.draw.connect(_draw_overlay)
	bubbles.clear()


func _vig() -> Texture2D:
	if vignette == null:
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 0))
		gr.add_point(0.55, Color(1, 1, 1, 0.0))
		gr.set_color(1, Color(1, 1, 1, 1))
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.05, 0.5)
		gt.width = 128
		gt.height = 128
		vignette = gt
	return vignette


func _draw_overlay() -> void:
	var sz: Vector2 = overlay.size
	var out: bool = bool(v.call("is_out"))
	# alarma roja dentro con la brecha
	if bool(g.breach) and not out:
		var a: float = 0.12 + 0.16 * (0.5 + 0.5 * sin(t * 6.0))
		overlay.draw_texture_rect(_vig(), Rect2(Vector2.ZERO, sz), false, Color(0.85, 0.05, 0.04, a))
	# tormenta fuera: velo de polvo y rafagas
	if out and storm_k > 0.01:
		overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.62, 0.4, 0.24, 0.22 * storm_k))
		overlay.draw_texture_rect(_vig(), Rect2(Vector2.ZERO, sz), false, Color(0.45, 0.28, 0.16, 0.55 * storm_k))
		var r := RandomNumberGenerator.new()
		r.seed = 99
		var nl: int = int(70.0 * fx_q())
		for i in nl:
			var y: float = r.randf() * sz.y
			var spd: float = r.randf_range(500.0, 1100.0)
			var x: float = fmod(r.randf() * sz.x + t * spd, sz.x + 200.0) - 100.0
			var ln: float = r.randf_range(40.0, 140.0)
			overlay.draw_line(Vector2(x, y), Vector2(x + ln, y + ln * 0.08), Color(0.92, 0.75, 0.55, 0.18 * storm_k), r.randf_range(1.0, 2.5))
	# erupcion solar: destello blanco-violeta
	if flare_k > 0.01:
		var fl: float = maxf(0.0, sin(t * 2.3) * sin(t * 5.1)) * 0.12 * flare_k + 0.25 * shield_flash
		overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.85, 0.8, 1.0, fl))
	if impact_flash > 0.0:
		overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.92, 0.8, 0.7 * impact_flash))
	cine.draw(overlay, sz)


# ------------------------------------------------------------------ entrada (cinematica)

func handle_key(k: InputEventKey) -> bool:
	return cine.handle_key(k)
