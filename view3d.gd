extends Node3D
# Capa de render 3D. Solo LEE el estado del juego (main.gd); no cambia la lógica.
# Todo se construye por código con mallas primitivas: no usa imágenes externas.

const T3: float = 2.0 # metros por casilla
const HIDDEN: Transform3D = Transform3D(Basis(Vector3(0.001, 0, 0), Vector3(0, 0.001, 0), Vector3(0, 0, 0.001)), Vector3(0, -200, 0))

var game = null
var cam: Camera3D
var sun: DirectionalLight3D
var moonlight: DirectionalLight3D
var fill: DirectionalLight3D
var alert_light: OmniLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var interior: Node3D
var exterior: Node3D
var skydome: Node3D
var dust_fx: CPUParticles3D = null
var dust_mat: StandardMaterial3D = null
var player_node: Node3D
var npc_nodes: Dictionary = {}
var prop_nodes: Dictionary = {}
var scaf_nodes: Dictionary = {}
var ext_lv: Node3D
var enoc_hammer: Node3D
var target_ring: MeshInstance3D
var shield_mat: StandardMaterial3D
var shield_ring: Node3D
var beacon_mat: StandardMaterial3D
var led_mats: Array = []
var heights: PackedFloat32Array = PackedFloat32Array()
var node_data: Array = []
var zs: Array = []
var mats: Dictionary = {}
var suit_mats: Array = []   # materiales de tela de los trajes [material, "fabric"]
var anim_k: float = 0.22
var zoom: float = 1.0
var cam_focus: Vector3 = Vector3.ZERO
var yaw_player: float = 0.0
var t_node: float = 0.0
var sync_t: float = 0.0
var W: int = 0
var H: int = 0
var last_outside: bool = false
var py_s: float = 0.0
var py_ok: bool = false
var yaw_cam: float = 0.0
var menu_mode: bool = false
var ceiling: Node3D
var int_mats: Array = []   # [material, tipo] del interior (suelo/pared/techo) para cambiar la calidad de textura
var act_u: float = 0.0
var ext_mats: Array = []   # [material, tipo de textura]
const ExtTex = preload("res://ext_tex.gd")
const IntTex = preload("res://int_tex.gd")
const SpaceTex = preload("res://space_tex.gd")
var craters: Array = []                 # Vector4(x, y, radio en casillas, profundidad en m)
var crater_hf: PackedFloat32Array = PackedFloat32Array()
var young_craters: Array = []           # v28: crateres con eyecciones claras (Luna)
var micro_craters: Array = []           # v28: solo para la textura del suelo
var t_sub: int = 1                      # v28: vertices de terreno por casilla
var t_gw: int = 0
const Terrain3D = preload("res://terrain3d.gd")
const WorldLook = preload("res://world_look.gd")
const BaseLook = preload("res://base_look.gd")
const CrewLook = preload("res://crew_look.gd")
const StationArt = preload("res://station_art.gd")
const InteriorLook = preload("res://interior_look.gd")
var hull_mats: Array = []               # v28: materiales del casco con textura de paneles
var wfx: Node3D = null                  # v28: particulas del exterior (world_fx.gd)
var ice_pts: PackedVector3Array = PackedVector3Array()
var last_daylight: float = 1.0
var terrain_mat: StandardMaterial3D = null
var jump_shadow: MeshInstance3D = null
var fx_list: Array = []
var fx_node: Node3D = null
var _fx_acc: float = 0.0
var _fx_step: int = -1


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.05
	cam.far = 900.0
	add_child(cam)
	cam.make_current()
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	moonlight = DirectionalLight3D.new()
	moonlight.light_color = Color(0.66, 0.72, 0.88)   # v28: luz de la Tierra mas neutra (antes azul intenso)
	moonlight.light_energy = 0.3
	moonlight.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	add_child(moonlight)
	fill = DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.95, 0.88)
	fill.light_energy = 0.9
	fill.shadow_enabled = true
	fill.directional_shadow_max_distance = 60.0
	fill.rotation_degrees = Vector3(-62.0, 18.0, 0.0)
	add_child(fill)
	alert_light = OmniLight3D.new()
	alert_light.light_color = Color(1.0, 0.1, 0.05)
	alert_light.omni_range = 40.0
	alert_light.position = Vector3(16.0, 5.0, 10.0)
	alert_light.visible = false
	add_child(alert_light)
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ---------- utilidades ----------

func _m(c: Color, metal: float = 0.0, rough: float = 0.8, emit: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s_%.2f_%.2f_%.2f" % [c.to_html(true), metal, rough, emit]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[key] = m
	return m


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _cyl(rt: float, rb: float, h: float, seg: int = 28) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _sph(r: float, seg: int = 16, hemi: bool = false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	var sg: int = maxi(seg, 8) if seg < 12 else maxi(seg, 24)
	s.radial_segments = sg
	s.rings = maxi(int(sg / 2.0), 4)
	return s


func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 28
	c.rings = 10
	return c


func _tor(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 12
	return t


func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sm(c: Color, metal: float = 0.0, rough: float = 0.8, emit: float = 0.0) -> StandardMaterial3D:
	# material de personaje: no recibe sombra propia (evita las manchas dentadas del traje)
	var key: String = "A%s_%.2f_%.2f_%.2f" % [c.to_html(true), metal, rough, emit]
	if mats.has(key):
		return mats[key]
	var m: StandardMaterial3D = _m(c, metal, rough, emit).duplicate() as StandardMaterial3D
	m.disable_receive_shadows = true
	if metal < 0.5 and emit <= 0.0:
		# luz de borde suave: el traje se ve menos plano y duro
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.55
	mats[key] = m
	return m


func _fabric(c: Color, rough: float = 0.65) -> StandardMaterial3D:
	# tela del traje: igual que _sm pero con trama (textura segun la calidad)
	var key: String = "F%s_%.2f" % [c.to_html(true), rough]
	if mats.has(key):
		return mats[key]
	var m: StandardMaterial3D = _sm(c, 0.0, rough).duplicate() as StandardMaterial3D
	suit_mats.append([m, "fabric"])
	mats[key] = m
	return m


func _tp(x: int, y: int, h: float = 0.0) -> Vector3:
	return Vector3((float(x) + 0.5) * T3, h, (float(y) + 0.5) * T3)


func _mm_mat(metal: float, rough: float, transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.metallic = metal
	m.roughness = rough
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.5, 0.8, 1.0)
		m.emission_energy_multiplier = 0.5
	return m


func _ext_mat(kind: String, metal: float, rough: float, transparent: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = _mm_mat(metal, rough, transparent)
	if transparent:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ext_mats.append([m, kind])
	return m


func apply_gfx() -> void:
	# ajustes graficos del jugador (sombras, glow, brillo, estrellas)
	if sun == null or env == null:
		return
	var sq: int = clampi(int(game.shadow_q), 0, 2)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sq == 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [40.0, 45.0, 85.0][sq]
	fill.directional_shadow_max_distance = [30.0, 40.0, 60.0][sq]
	env.glow_enabled = game.glow_on
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.tonemap_exposure = 0.9 * float(game.bright)
	InteriorLook.apply_gfx(int(game.fx_idx))
	if skydome != null:
		var st: Node = skydome.get_node_or_null("Estrellas")
		if st != null:
			(st as MultiMeshInstance3D).multimesh.visible_instance_count = int(game.STAR_COUNTS[clampi(int(game.sky_idx), 0, 2)])


func fx_scale(n: int) -> int:
	return maxi(1, int(round(float(n) * float(game.FX_FACTOR[clampi(int(game.fx_idx), 0, 2)]))))


func apply_textures() -> void:
	# nivel 0: colores lisos | 1: textura 128 px | 2: textura 256 px + relieve (normal map)
	var lv: int = clampi(int(game.tex_quality), 0, 2)
	_apply_terrain_tex()
	_apply_interior_tex()
	_apply_suit_tex()
	for hm in hull_mats:
		BaseLook.apply_hull_tex(hm, lv)
	var scales: Dictionary = {"rock": 0.55, "ore": 1.3, "ice": 1.1, "crate": 0.83}
	for e in ext_mats:
		var m: StandardMaterial3D = e[0]
		var kind: String = str(e[1])
		if lv == 0:
			m.albedo_texture = null
			m.normal_enabled = false
			m.normal_texture = null
			continue
		var tx: Array = ExtTex.make(kind, 128 if lv == 1 else 256, lv == 2)
		m.albedo_texture = tx[0]
		m.uv1_triplanar = true
		var sc: float = float(scales.get(kind, 1.0))
		m.uv1_scale = Vector3(sc, sc, sc)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if lv == 2 and tx[1] != null:
			m.normal_enabled = true
			m.normal_texture = tx[1]
			m.normal_scale = 1.1
		else:
			m.normal_enabled = false
			m.normal_texture = null


func _apply_suit_tex() -> void:
	var lv: int = clampi(int(game.tex_quality), 0, 2)
	for e in suit_mats:
		var m: StandardMaterial3D = e[0]
		if lv == 0:
			m.albedo_texture = null
			m.normal_enabled = false
			m.normal_texture = null
			continue
		var tx: Array = IntTex.make("fabric", false, 128 if lv == 1 else 256, lv == 2)
		m.albedo_texture = tx[0]
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(3.5, 3.5, 3.5)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if lv == 2 and tx[1] != null:
			m.normal_enabled = true
			m.normal_texture = tx[1]
			m.normal_scale = 0.8
		else:
			m.normal_enabled = false
			m.normal_texture = null


func _apply_interior_tex() -> void:
	var lv: int = clampi(int(game.tex_quality), 0, 2)
	var moon: bool = game.location == "Luna"
	for e in int_mats:
		var m: StandardMaterial3D = e[0]
		var kind: String = str(e[1])
		if lv == 0:
			m.albedo_texture = null
			m.normal_enabled = false
			m.normal_texture = null
			continue
		var tx: Array = IntTex.make(kind, moon, 128 if lv == 1 else 512, lv == 2)
		m.albedo_texture = tx[0]
		m.albedo_color = Color(1, 1, 1)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if lv == 2 and tx[1] != null:
			m.normal_enabled = true
			m.normal_texture = tx[1]
			m.normal_scale = 1.0
		else:
			m.normal_enabled = false
			m.normal_texture = null


func _int_mat(kind: String, flat: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = flat
	m.roughness = rough
	m.metallic = metal
	int_mats.append([m, kind])
	return m


func _make_mm(parent: Node3D, mesh: Mesh, mat: Material, count: int, shadow: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if not shadow:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


# MultiMesh repartido en bloques espaciales (MM_CHUNK x MM_CHUNK casillas): un MultiMesh unico
# tiene una sola caja de colision y se dibuja entero (y otra vez en cada capa de sombras)
# aunque solo se vea una parte del mapa. En bloques, el motor descarta los que no se ven.
const MM_CHUNK: int = 12


class ChunkMM extends RefCounted:
	var chunks: Array = []
	var chunk_of: PackedInt32Array = PackedInt32Array()
	var local_i: PackedInt32Array = PackedInt32Array()

	func set_xf(i: int, xf: Transform3D) -> void:
		(chunks[chunk_of[i]] as MultiMeshInstance3D).multimesh.set_instance_transform(local_i[i], xf)

	func set_col(i: int, c: Color) -> void:
		(chunks[chunk_of[i]] as MultiMeshInstance3D).multimesh.set_instance_color(local_i[i], c)


# tiles[b] = casilla de la unidad b; cada unidad usa `per` instancias (indices b*per + j).
func _make_mm_c(parent: Node3D, mesh: Mesh, mat: Material, tiles: Array, per: int, shadow: bool = true) -> ChunkMM:
	var cm := ChunkMM.new()
	cm.chunk_of.resize(tiles.size() * per)
	cm.local_i.resize(tiles.size() * per)
	var key_idx: Dictionary = {}
	var counts: Array = []
	for b in tiles.size():
		var t: Vector2i = tiles[b]
		var key: int = (t.y / MM_CHUNK) * 1000 + (t.x / MM_CHUNK)
		if not key_idx.has(key):
			key_idx[key] = counts.size()
			counts.append(0)
		var ci: int = key_idx[key]
		for j in per:
			cm.chunk_of[b * per + j] = ci
			cm.local_i[b * per + j] = counts[ci]
			counts[ci] += 1
	for ci in counts.size():
		cm.chunks.append(_make_mm(parent, mesh, mat, int(counts[ci]), shadow))
	return cm


func _xf(pos: Vector3, yaw: float, sc: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sc), pos)


# ---------- construcción ----------

func setup() -> void:
	zs = game._zones()
	W = game.EXT_W
	H = game.EXT_H
	for n in [interior, exterior, skydome, player_node, target_ring, dust_fx, wfx]:
		if n != null:
			n.queue_free()
	for k in npc_nodes:
		npc_nodes[k].queue_free()
	npc_nodes.clear()
	refl_kind = ""
	prop_nodes.clear()
	scaf_nodes.clear()
	ext_lv = null
	enoc_hammer = null
	node_data.clear()
	led_mats.clear()
	mats.clear()
	suit_mats.clear()
	shield_mat = null
	shield_ring = null
	beacon_mat = null
	_build_sky()
	StationArt.reset()
	_build_interior()
	_build_ceiling()
	_build_exterior()
	player_node = _make_astronaut(Color(0.97, 0.97, 1.0), "wilson")
	add_child(player_node)
	_nametag(player_node, "Wilson", Color(0.7, 0.95, 1.0))
	_apply_suit_tex()
	var ring_mat: StandardMaterial3D = _m(Color(0.3, 0.9, 1.0, 0.55), 0.0, 0.5, 2.0)
	target_ring = _add(self, _tor(0.78, 0.92), ring_mat, Vector3.ZERO, Vector3.ZERO, false)
	target_ring.visible = false
	cam_focus = _tp(game.player.x, game.player.y)
	last_outside = game.outside
	_update_visibility()


func _build_sky() -> void:
	skydome = Node3D.new()
	add_child(skydome)
	var g := RandomNumberGenerator.new()
	g.seed = 777
	# Via Lactea: esfera interior con textura aditiva
	var mw := SphereMesh.new()
	mw.radius = 440.0
	mw.height = 880.0
	mw.radial_segments = 40
	mw.rings = 20
	var mwm := StandardMaterial3D.new()
	mwm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mwm.cull_mode = BaseMaterial3D.CULL_FRONT
	mwm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mwm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mwm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mwm.albedo_texture = SpaceTex.milky_way(256)
	mwm.render_priority = -5
	var mwi: MeshInstance3D = _add(skydome, mw, mwm, Vector3.ZERO, Vector3.ZERO, false)
	mwi.name = "ViaLactea"
	# estrellas: destellos suaves con colores y tamanos variados
	var count: int = int(game.STAR_COUNTS[2])
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.vertex_color_use_as_albedo = true
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_mat.billboard_keep_scale = true
	star_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	star_mat.albedo_texture = SpaceTex.glow_sprite(32, 0.18)
	star_mat.render_priority = -4
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	var mmi: MultiMeshInstance3D = _make_mm(skydome, qm, star_mat, count, false)
	for i in count:
		var v := Vector3(g.randf_range(-1.0, 1.0), g.randf_range(-0.05, 1.0), g.randf_range(-1.0, 1.0)).normalized()
		# unas pocas estrellas brillantes y muchas debiles
		var mag: float = pow(g.randf(), 3.2)
		var s: float = 2.2 + mag * 9.0
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), v * 420.0))
		var col: Color = SpaceTex.star_color(g)
		var b: float = 0.35 + mag * 0.9 + g.randf() * 0.25
		mmi.multimesh.set_instance_color(i, Color(col.r * b, col.g * b, col.b * b, 1.0))
	mmi.name = "Estrellas"
	if game.location == "Luna":
		# la Tierra: esfera con continentes, nubes, fase, brillo del oceano y atmosfera
		var epos: Vector3 = Vector3(160.0, 150.0, -330.0)
		var hq := QuadMesh.new()
		hq.size = Vector2(124.0, 124.0)
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		hm.albedo_texture = SpaceTex.halo_sprite(128)
		hm.render_priority = -3
		var halo := _add(skydome, hq, hm, epos, Vector3.ZERO, false)
		halo.name = "TierraHalo"
		var es := SphereMesh.new()
		es.radius = 36.0
		es.height = 72.0
		es.radial_segments = 48
		es.rings = 24
		var earth := _add(skydome, es, SpaceTex.earth_material(), epos, Vector3(0.0, 0.0, 0.0), false)
		earth.rotation = Vector3(0.0, 2.2, 0.0)
		earth.name = "Tierra"
	dust_fx = null
	if game.location == "Marte":
		_build_dust()


func _build_dust() -> void:
	# polvo tibio que el viento arrastra cerca del suelo (ambiente caluroso de Marte)
	dust_fx = CPUParticles3D.new()
	dust_fx.amount = 160
	dust_fx.lifetime = 8.0
	dust_fx.preprocess = 8.0
	dust_fx.local_coords = false
	dust_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust_fx.emission_box_extents = Vector3(16.0, 1.1, 16.0)
	dust_fx.direction = Vector3(1.0, 0.04, 0.35)
	dust_fx.spread = 18.0
	dust_fx.gravity = Vector3.ZERO
	dust_fx.initial_velocity_min = 1.4
	dust_fx.initial_velocity_max = 2.8
	dust_fx.scale_amount_min = 0.4
	dust_fx.scale_amount_max = 0.9
	dust_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4)
	dust_mat = StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust_mat.billboard_keep_scale = true
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.vertex_color_use_as_albedo = true
	dust_mat.albedo_texture = SpaceTex.glow_sprite(32, 0.02)
	dust_mat.albedo_color = Color(0.95, 0.65, 0.4, 0.16)
	dust_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = dust_mat
	dust_fx.mesh = q
	dust_fx.visible = false
	add_child(dust_fx)


func _earth_tex() -> ImageTexture:
	var n: int = 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx: float = (float(x) - 63.5) / 63.5
			var dy: float = (float(y) - 63.5) / 63.5
			var r2: float = dx * dx + dy * dy
			if r2 > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c: Color = Color(0.12, 0.3, 0.75)
			var nz: float = sin(dx * 7.0 + 1.0) * cos(dy * 6.0 - 0.5) + sin((dx + dy) * 11.0) * 0.4
			if nz > 0.55:
				c = Color(0.25, 0.55, 0.3)
			var cloud: float = sin(dx * 13.0 + dy * 5.0) * sin(dy * 9.0 - dx * 4.0)
			if cloud > 0.62:
				c = c.lerp(Color.WHITE, 0.8)
			var shade: float = clampf(1.0 - r2 * 0.5 - (dx * 0.35 - dy * 0.25) * 0.4, 0.3, 1.0)
			c = Color(c.r * shade, c.g * shade, c.b * shade, 1.0)
			if r2 > 0.9:
				c = c.lerp(Color(0.55, 0.78, 1.0), (r2 - 0.9) * 8.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# ---------- astronautas ----------

# ---------- modelos importados (Ludo.ai u otros): res://art/3d/<nombre>.glb ----------
# Si el archivo no existe se usa el modelo dibujado por codigo.
const ART_3D: String = "res://art/3d/"
const MAT_SIZE: Dictionary = {"scrap": 1.3, "crate": 1.35, "ice": 1.7}
const STATION_SIZE: Dictionary = {"O": 2.8, "S": 2.5, "G": 2.1, "W": 2.2, "R": 2.3, "C": 1.9, "B": 2.5, "T": 1.9, "A": 2.3, "D": 3.4}
var _glb_cache: Dictionary = {}


func _glb_scene(nm: String) -> PackedScene:
	if _glb_cache.has(nm):
		return _glb_cache[nm]
	var ps: PackedScene = null
	var path: String = ART_3D + nm + ".glb"
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	_glb_cache[nm] = ps
	return ps


func _collect_meshes(n: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf: Transform3D = parent_xf
	if n is Node3D:
		xf = parent_xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append({"mesh": (n as MeshInstance3D).mesh, "xf": xf})
	for c in n.get_children():
		_collect_meshes(c, xf, out)


func _glb_parts(nm: String, size: float) -> Array:
	# Devuelve [{mesh, xf}] normalizado: base en y=0, centrado en x/z y con la dimension mayor = size (metros).
	var ps: PackedScene = _glb_scene(nm)
	if ps == null:
		return []
	var root: Node = ps.instantiate()
	var found: Array = []
	_collect_meshes(root, Transform3D.IDENTITY, found)
	root.free()
	if found.is_empty():
		return []
	var box: AABB = AABB()
	var first: bool = true
	for f in found:
		var bb: AABB = (f["xf"] as Transform3D) * (f["mesh"] as Mesh).get_aabb()
		if first:
			box = bb
			first = false
		else:
			box = box.merge(bb)
	var m: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if m <= 0.0001:
		return []
	var sc: float = size / m
	var center := Vector3(box.position.x + box.size.x / 2.0, box.position.y, box.position.z + box.size.z / 2.0)
	var norm := Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), -center * sc)
	for f in found:
		f["xf"] = norm * (f["xf"] as Transform3D)
	return found


func _glb_instances(parent: Node3D, parts: Array, count: int) -> Array:
	# Un MultiMesh por cada malla del modelo (conserva sus materiales/texturas).
	var out: Array = []
	for pt in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pt["mesh"]
		mm.instance_count = count
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		parent.add_child(mmi)
		out.append(mmi)
	return out


func _place_glb_nodes(kind: String, size: float, tiles: Array, lift: float, g: RandomNumberGenerator) -> bool:
	# Coloca un modelo .glb en cada casilla recolectable. Devuelve false si no hay modelo.
	var parts: Array = _glb_parts(kind, size)
	if parts.is_empty() or tiles.is_empty():
		return false
	var insts: Array = _glb_instances(exterior, parts, tiles.size())
	for i in tiles.size():
		var p: Vector2i = tiles[i]
		var gy: float = ground_y(float(p.x) + 0.5, float(p.y) + 0.5)
		var base: Transform3D = _xf(_tp(p.x, p.y, gy + lift), g.randf() * TAU, Vector3.ONE)
		var plist: Array = []
		for k in parts.size():
			var xf: Transform3D = base * (parts[k]["xf"] as Transform3D)
			(insts[k] as MultiMeshInstance3D).multimesh.set_instance_transform(i, xf)
			plist.append([insts[k], i, xf])
		node_data.append({"x": p.x, "y": p.y, "hidden": false, "parts": plist})
	return true


func _place_glb_prop(parent: Node3D, nm: String, size: float) -> bool:
	var parts: Array = _glb_parts(nm, size)
	if parts.is_empty():
		return false
	for pt in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = pt["mesh"]
		mi.transform = pt["xf"]
		parent.add_child(mi)
	return true


func _limb(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _nametag(parent: Node3D, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 44
	l.pixel_size = 0.0095
	l.outline_size = 12
	l.outline_modulate = Color(0.02, 0.03, 0.08, 0.95)
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.double_sided = true
	l.position = Vector3(0, 2.55, 0)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.name = "Nombre"
	parent.add_child(l)


func _make_astronaut(suit: Color, role: String = "") -> Node3D:
	# Traje mas detallado. role: "" (sin marca), "wilson", "a" (YARISBEL, medica), "k" (ENOC), "l" (PAM, comandante)
	var n := Node3D.new()
	var accent: Color = suit
	match role:
		"wilson":
			accent = Color(1.0, 0.55, 0.15)
		"a":
			accent = Color(0.85, 0.2, 0.2)
		"k":
			accent = Color(0.15, 0.5, 0.6)
		"l":
			accent = Color(0.95, 0.78, 0.2)   # comandante: dorado
	accent = CrewLook.role_color(role, accent)
	var white: StandardMaterial3D = _fabric(Color(0.93, 0.92, 0.9), 0.72)
	var suitm: StandardMaterial3D = _fabric(suit.lerp(Color(0.94, 0.93, 0.91), 0.55), 0.74)
	var shell: StandardMaterial3D = CrewLook.helmet()
	var bear: StandardMaterial3D = CrewLook.bearing()
	var accm: StandardMaterial3D = _sm(accent, 0.1, 0.5)
	var dark: StandardMaterial3D = _sm(Color(0.22, 0.24, 0.3), 0.4, 0.55)
	var metal: StandardMaterial3D = _sm(Color(0.7, 0.72, 0.8), 0.85, 0.3)
	var glove: StandardMaterial3D = _sm(Color(0.82, 0.84, 0.9), 0.0, 0.75)
	var rig := Node3D.new()
	n.add_child(rig)
	var body := Node3D.new()
	rig.add_child(body)
	# torso y cintura
	_add(body, _cap(0.29, 0.86), suitm, Vector3(0, 1.22, 0))
	_add(body, _cap(0.26, 0.62), suitm, Vector3(0, 0.92, 0))
	_add(body, _tor(0.22, 0.31), dark, Vector3(0, 1.0, 0))
	# cuello: anillo metalico que une casco y torso
	_add(body, _cyl(0.2, 0.24, 0.16, 12), metal, Vector3(0, 1.5, 0))
	_add(body, _box(Vector3(0.1, 0.07, 0.03)), metal, Vector3(0, 1.02, -0.27), Vector3.ZERO, false)
	# panel de control del pecho con luces
	_add(body, _box(Vector3(0.32, 0.2, 0.06)), dark, Vector3(0, 1.32, -0.27))
	_add(body, _sph(0.028, 6), _sm(Color(0.3, 1.0, 0.45), 0.0, 0.3, 1.0), Vector3(-0.09, 1.34, -0.31), Vector3.ZERO, false)
	_add(body, _sph(0.028, 6), _sm(Color(1.0, 0.8, 0.2), 0.0, 0.3, 1.0), Vector3(0.0, 1.34, -0.31), Vector3.ZERO, false)
	_add(body, _sph(0.028, 6), _sm(Color(1.0, 0.3, 0.3), 0.0, 0.3, 0.9), Vector3(0.09, 1.34, -0.31), Vector3.ZERO, false)
	_add(body, _box(Vector3(0.22, 0.04, 0.02)), metal, Vector3(0, 1.26, -0.305), Vector3.ZERO, false)
	# parche de rol en el pecho izquierdo
	_add(body, _box(Vector3(0.1, 0.1, 0.03)), accm, Vector3(-0.17, 1.5, -0.25), Vector3.ZERO, false)
	if role == "a":   # medica: cruz blanca en el parche
		_add(body, _box(Vector3(0.08, 0.025, 0.035)), white, Vector3(-0.17, 1.5, -0.26), Vector3.ZERO, false)
		_add(body, _box(Vector3(0.025, 0.08, 0.035)), white, Vector3(-0.17, 1.5, -0.26), Vector3.ZERO, false)
	# mochila de soporte vital con tanques y mangueras
	var pack := Node3D.new()
	pack.position = Vector3(0, 1.6, 0.3)
	body.add_child(pack)
	_add(pack, _box(Vector3(0.46, 0.62, 0.24)), metal, Vector3(0, -0.32, 0))
	_add(pack, _cyl(0.07, 0.07, 0.56, 14), white, Vector3(-0.12, -0.32, 0.14))
	_add(pack, _cyl(0.07, 0.07, 0.56, 14), white, Vector3(0.12, -0.32, 0.14))
	_add(pack, _sph(0.07, 12), white, Vector3(-0.12, -0.04, 0.14))
	_add(pack, _sph(0.07, 12), white, Vector3(0.12, -0.04, 0.14))
	_add(body, _cyl(0.025, 0.025, 0.3, 6), dark, Vector3(-0.2, 1.5, -0.1), Vector3(0.6, 0, 0.0), false)
	_add(body, _cyl(0.025, 0.025, 0.3, 6), dark, Vector3(0.2, 1.5, -0.1), Vector3(0.6, 0, 0.0), false)
	_add(body, _box(Vector3(0.18, 0.04, 0.02)), accm, Vector3(0, 1.45, 0.43), Vector3.ZERO, false)
	# detalles extra del traje: correas, lampara del casco, antena y bandera
	_add(body, _box(Vector3(0.05, 0.55, 0.03)), accm, Vector3(-0.14, 1.28, -0.26), Vector3.ZERO, false)
	_add(body, _box(Vector3(0.05, 0.55, 0.03)), accm, Vector3(0.14, 1.28, -0.26), Vector3.ZERO, false)
	var ant := Node3D.new()
	ant.position = Vector3(0.18, 1.78, 0.32)
	body.add_child(ant)
	_add(ant, _cyl(0.012, 0.012, 0.3), metal, Vector3(0, 0.0, 0), Vector3.ZERO, false)
	_add(ant, _sph(0.025, 6), _sm(Color(1.0, 0.3, 0.3), 0.0, 0.3, 0.9), Vector3(0, 0.16, 0), Vector3.ZERO, false)
	_add(body, _box(Vector3(0.13, 0.07, 0.025)), _sm(Color(0.2, 0.3, 0.75), 0.0, 0.7), Vector3(0.17, 1.5, -0.25), Vector3.ZERO, false)
	_add(body, _box(Vector3(0.13, 0.025, 0.027)), _sm(Color(0.9, 0.2, 0.2), 0.0, 0.7), Vector3(0.17, 1.488, -0.25), Vector3.ZERO, false)
	_add(body, _cyl(0.14, 0.14, 0.05, 12), _sm(Color(0.3, 0.32, 0.4), 0.5, 0.5), Vector3(0, 1.14, 0.0), Vector3.ZERO, false)
	# cabeza: casco con visor reflectante
	var head := Node3D.new()
	head.position = Vector3(0, 1.66, 0)
	body.add_child(head)
	_add(head, _sph(0.31, 24), shell, Vector3.ZERO)
	var visor: MeshInstance3D = _add(head, _sph(0.24, 20), CrewLook.visor(), Vector3(0, -0.01, -0.2))
	visor.scale = Vector3(1.05, 0.86, 0.8)
	var hl: MeshInstance3D = _add(head, _sph(0.06, 8), _sm(Color(1, 1, 1, 0.55), 0.0, 0.2, 0.6), Vector3(0.1, 0.08, -0.37), Vector3.ZERO, false)
	hl.scale = Vector3(1.0, 0.6, 0.4)
	_add(head, _box(Vector3(0.08, 0.04, 0.2)), accm, Vector3(0, 0.3, 0.0))
	_add(head, _sph(0.04, 6), _sm(Color(0.9, 1.0, 1.0), 0.0, 0.3, 1.0), Vector3(0.26, 0.05, -0.1), Vector3.ZERO, false)
	_add(head, _tor(0.24, 0.31), bear, Vector3(0, -0.27, 0))
	_add(head, _box(Vector3(0.1, 0.06, 0.08)), _sm(Color(1.0, 0.97, 0.8), 0.0, 0.3, 1.0), Vector3(-0.22, 0.14, -0.2), Vector3.ZERO, false)
	# franja de rol en el casco (identifica a cada astronauta tambien de espaldas)
	var hb: MeshInstance3D = _add(head, _tor(0.295, 0.318), accm, Vector3(0, 0.02, 0), Vector3(PI / 2.0, PI / 2.0, 0), false)
	hb.scale = Vector3(1.0, 1.0, 1.0)
	_add(head, _tor(0.17, 0.2), _sm(Color(0.6, 0.62, 0.7), 0.8, 0.3), Vector3(0, -0.01, -0.09), Vector3(PI / 2.0, 0, 0), false)
	# brazos: hombro -> codo -> mano
	var arms: Array = []
	for sd in [-1.0, 1.0]:
		var sh: Node3D = _limb(body, Vector3(0.34 * sd, 1.48, 0))
		_add(sh, _sph(0.15, 14), suitm, Vector3(0, 0.0, 0))
		_add(sh, _tor(0.1, 0.135), bear, Vector3(0, -0.08, 0), Vector3.ZERO, false)
		_add(sh, _cap(0.095, 0.38), suitm, Vector3(0, -0.18, 0))
		_add(sh, _cyl(0.104, 0.104, 0.07, 16), accm, Vector3(0, -0.21, 0), Vector3.ZERO, false)
		var el: Node3D = _limb(sh, Vector3(0, -0.34, 0))
		_add(el, _sph(0.09, 8), dark, Vector3.ZERO)
		_add(el, _tor(0.075, 0.115), suitm, Vector3(0, -0.02, 0), Vector3.ZERO, false)
		_add(sh, _tor(0.085, 0.125), suitm, Vector3(0, -0.3, 0), Vector3.ZERO, false)
		_add(el, _cap(0.085, 0.34), suitm, Vector3(0, -0.16, 0))
		_add(el, _box(Vector3(0.17, 0.05, 0.17)), bear, Vector3(0, -0.24, 0), Vector3.ZERO, false)
		_add(el, _sph(0.095, 10), glove, Vector3(0, -0.34, 0))
		_add(el, _box(Vector3(0.1, 0.09, 0.06)), glove, Vector3(0, -0.39, -0.05), Vector3.ZERO, false)
		arms.append([sh, el])
	if role == "k":
		var hm := Node3D.new()
		arms[1][1].add_child(hm)
		_add(hm, _box(Vector3(0.05, 0.05, 0.55)), _sm(Color(0.6, 0.4, 0.2), 0.0, 0.8), Vector3(0, -0.36, -0.22), Vector3.ZERO, false)
		_add(hm, _box(Vector3(0.12, 0.13, 0.2)), _sm(Color(0.75, 0.77, 0.85), 0.9, 0.3), Vector3(0, -0.36, -0.5), Vector3.ZERO, false)
		hm.visible = false
		enoc_hammer = hm
	# pelvis horizontal que une las dos piernas con el torso
	_add(rig, _cap(0.19, 0.56), suitm, Vector3(0, 0.74, 0), Vector3(0, 0, PI / 2.0))
	# piernas: cadera -> rodilla -> bota
	var legs: Array = []
	for sd in [-1.0, 1.0]:
		var hp: Node3D = _limb(rig, Vector3(0.15 * sd, 0.68, 0))
		_add(hp, _sph(0.14, 12), suitm, Vector3.ZERO)
		_add(hp, _cap(0.125, 0.4), suitm, Vector3(0, -0.18, 0))
		_add(hp, _cyl(0.134, 0.134, 0.07, 16), accm, Vector3(0, -0.22, 0), Vector3.ZERO, false)
		var kn: Node3D = _limb(hp, Vector3(0, -0.34, 0))
		_add(kn, _sph(0.115, 8), dark, Vector3.ZERO)
		_add(kn, _tor(0.1, 0.15), suitm, Vector3(0, -0.02, 0), Vector3.ZERO, false)
		_add(kn, _sph(0.1, 10), dark, Vector3(0, 0.0, -0.1), Vector3.ZERO, false)
		_add(kn, _sph(0.14, 12), dark, Vector3(0, -0.4, -0.2))
		_add(kn, _cap(0.105, 0.34), suitm, Vector3(0, -0.16, 0))
		_add(kn, _box(Vector3(0.22, 0.05, 0.1)), dark, Vector3(0, -0.03, -0.09), Vector3.ZERO, false)
		_add(kn, _box(Vector3(0.22, 0.13, 0.36)), dark, Vector3(0, -0.34, -0.06))
		_add(kn, _box(Vector3(0.24, 0.04, 0.38)), metal, Vector3(0, -0.4, -0.06), Vector3.ZERO, false)
		legs.append([hp, kn])
	n.set_meta("parts", {"pack": pack, "ant": ant, "rig": rig, "body": body, "head": head,
		"arm_l": arms[0][0], "elb_l": arms[0][1], "arm_r": arms[1][0], "elb_r": arms[1][1],
		"leg_l": legs[0][0], "kn_l": legs[0][1], "leg_r": legs[1][0], "kn_r": legs[1][1]})
	return n


func _anim_astronaut(n: Node3D, pose: String, t: float, phase: float = 0.0) -> void:
	# pose: idle, walk, run, work, craft, gather, talk, wave
	var P: Dictionary = n.get_meta("parts")
	var rig: Node3D = P["rig"]
	var body: Node3D = P["body"]
	var head: Node3D = P["head"]
	var al: Node3D = P["arm_l"]
	var ar: Node3D = P["arm_r"]
	var el: Node3D = P["elb_l"]
	var er: Node3D = P["elb_r"]
	var ll: Node3D = P["leg_l"]
	var lr: Node3D = P["leg_r"]
	var kl: Node3D = P["kn_l"]
	var kr: Node3D = P["kn_r"]
	# valores por defecto (reposo con respiracion)
	var tg: Dictionary = {
		"rig_y": 0.0, "body_x": 0.0, "head_x": 0.0, "head_y": sin(t * 0.7 + phase) * 0.18,
		"al_x": sin(t * 1.6 + phase + 1.0) * 0.04, "ar_x": sin(t * 1.6 + phase) * 0.04, "al_z": 0.06, "ar_z": -0.06, "el_x": 0.12, "er_x": 0.12,
		"ll_x": 0.0, "lr_x": 0.0, "kl_x": 0.0, "kr_x": 0.0, "bob": sin(t * 1.6 + phase) * 0.012
	}
	match pose:
		"walk", "run":
			var f: float = 12.0 if pose == "walk" else 17.0
			var amp: float = 0.75 if pose == "walk" else 1.0
			var sw: float = sin(t * f)
			tg["al_x"] = sw * amp
			tg["ar_x"] = -sw * amp
			tg["ll_x"] = -sw * amp
			tg["lr_x"] = sw * amp
			tg["kl_x"] = -maxf(0.0, sin(t * f + 1.4)) * 0.9 * amp
			tg["kr_x"] = -maxf(0.0, -sin(t * f + 1.4)) * 0.9 * amp
			tg["el_x"] = 0.25 + (0.5 if pose == "run" else 0.1)
			tg["er_x"] = tg["el_x"]
			tg["bob"] = absf(sin(t * f)) * (0.07 if pose == "walk" else 0.1)
			tg["body_x"] = -0.06 if pose == "walk" else -0.2
			tg["head_y"] = 0.0
		"work":
			tg["body_x"] = -0.12
			tg["al_x"] = 1.0 + 0.25 * sin(t * 7.0)
			tg["ar_x"] = 1.0 + 0.25 * sin(t * 7.0 + 2.0)
			tg["el_x"] = 0.9
			tg["er_x"] = 0.9
			tg["head_x"] = -0.15
			tg["head_y"] = sin(t * 2.0) * 0.12
		"craft":
			tg["body_x"] = -0.1
			tg["al_x"] = 0.9
			tg["el_x"] = 1.0
			tg["ar_x"] = 1.5 + 0.7 * sin(t * 10.0)
			tg["er_x"] = 0.6 + 0.6 * sin(t * 10.0 + 0.6)
			tg["head_x"] = -0.2
		"gather":
			tg["rig_y"] = -0.25
			tg["body_x"] = -0.55
			tg["ll_x"] = 1.1
			tg["lr_x"] = 1.1
			tg["kl_x"] = -1.8
			tg["kr_x"] = -1.8
			tg["al_x"] = 1.5 + 0.4 * sin(t * 6.0)
			tg["ar_x"] = 1.5 + 0.4 * sin(t * 6.0 + PI)
			tg["el_x"] = 0.3
			tg["er_x"] = 0.3
			tg["head_x"] = 0.35
		"grab":
			# recogida: agacharse, alcanzar, levantar y guardar en la mochila (segun avance de la tarea)
			var u: float = act_u
			var reach: float = clampf(u / 0.45, 0.0, 1.0)
			var lift: float = clampf((u - 0.45) / 0.35, 0.0, 1.0)
			var stow: float = clampf((u - 0.8) / 0.2, 0.0, 1.0)
			tg["rig_y"] = -0.25 * (1.0 - lift)
			tg["body_x"] = lerpf(-0.1, -0.6, reach) * (1.0 - lift) + (-0.1) * lift
			tg["ll_x"] = 1.0 * (1.0 - lift)
			tg["lr_x"] = 1.0 * (1.0 - lift)
			tg["kl_x"] = -1.7 * (1.0 - lift)
			tg["kr_x"] = -1.7 * (1.0 - lift)
			tg["ar_x"] = lerpf(1.2, 2.1, reach) - 1.0 * lift - 1.6 * stow
			tg["al_x"] = lerpf(1.0, 1.9, reach) - 0.8 * lift
			tg["el_x"] = 0.3 + 0.7 * lift
			tg["er_x"] = 0.3 + 0.9 * lift
			tg["head_x"] = 0.35 * (1.0 - lift)
		"mine":
			# picar hielo: tres golpes por encima de la cabeza
			var sw2: float = (sin(act_u * TAU * 3.0 - PI * 0.5) + 1.0) * 0.5
			tg["body_x"] = -0.1 - 0.4 * sw2
			tg["ar_x"] = 2.8 - 2.1 * sw2
			tg["al_x"] = 2.6 - 2.0 * sw2
			tg["er_x"] = 0.5
			tg["el_x"] = 0.5
			tg["kl_x"] = -0.5 * sw2
			tg["kr_x"] = -0.5 * sw2
			tg["head_x"] = 0.2 * sw2
		"hammer":
			# martillar: brazo derecho golpea, el izquierdo sujeta
			var hs: float = (sin(t * 10.0 + phase) + 1.0) * 0.5
			tg["body_x"] = -0.14
			tg["ar_x"] = 2.2 - 1.1 * hs
			tg["er_x"] = 0.5 + 0.6 * hs
			tg["al_x"] = 1.0
			tg["el_x"] = 0.9
			tg["head_x"] = 0.18
			tg["head_y"] = 0.0
			tg["kl_x"] = -0.2 * hs
		"press":
			# pulsar un panel: brazo estirado y toques
			var tap: float = maxf(0.0, sin(act_u * TAU * 3.5))
			tg["body_x"] = -0.12
			tg["ar_x"] = 1.45 + 0.25 * tap
			tg["er_x"] = 0.08
			tg["al_x"] = 0.15
			tg["head_x"] = 0.1
			tg["head_y"] = 0.0
		"jump":
			# salto: brazos arriba y piernas recogidas
			tg["ar_x"] = 2.5
			tg["al_x"] = 2.4
			tg["ar_z"] = -0.35
			tg["al_z"] = 0.35
			tg["el_x"] = 0.3
			tg["er_x"] = 0.3
			tg["ll_x"] = 0.7
			tg["lr_x"] = -0.2
			tg["kl_x"] = -1.2
			tg["kr_x"] = -0.7
			tg["body_x"] = -0.1
			tg["head_x"] = -0.1
			tg["head_y"] = 0.0
		"fall":
			# caida: brazos y piernas agitados
			tg["ar_x"] = 2.2 + 0.6 * sin(t * 18.0)
			tg["al_x"] = 2.2 + 0.6 * sin(t * 18.0 + 2.0)
			tg["ar_z"] = -0.8
			tg["al_z"] = 0.8
			tg["ll_x"] = 0.5 * sin(t * 16.0)
			tg["lr_x"] = -0.5 * sin(t * 16.0)
			tg["kl_x"] = -0.6
			tg["kr_x"] = -0.6
			tg["head_y"] = 0.0
		"talk":
			tg["ar_x"] = 0.7 + 0.45 * sin(t * 4.2 + phase)
			tg["er_x"] = 0.9 + 0.3 * sin(t * 5.1 + phase)
			tg["al_x"] = 0.25 + 0.15 * sin(t * 3.3 + phase)
			tg["head_x"] = 0.08 * sin(t * 5.0 + phase)
			tg["head_y"] = sin(t * 1.4 + phase) * 0.25
		"wave":
			tg["ar_z"] = -2.7
			tg["er_x"] = 0.0
			tg["er_x"] = 0.4 * sin(t * 7.0)
			tg["head_y"] = -0.2
	tg["head_x"] = float(tg["head_x"]) - float(tg["body_x"]) * 0.55   # la cabeza compensa la inclinacion del torso
	var k: float = anim_k # suavizado hacia la pose (independiente de los FPS)
	rig.position.y = lerpf(rig.position.y, float(tg["rig_y"]) + float(tg["bob"]), k)
	body.rotation.x = lerpf(body.rotation.x, tg["body_x"], k)
	head.rotation.x = lerpf(head.rotation.x, tg["head_x"], k)
	head.rotation.y = lerpf(head.rotation.y, tg["head_y"], k)
	al.rotation.x = lerpf(al.rotation.x, tg["al_x"], k)
	ar.rotation.x = lerpf(ar.rotation.x, tg["ar_x"], k)
	al.rotation.z = lerpf(al.rotation.z, tg["al_z"], k)
	ar.rotation.z = lerpf(ar.rotation.z, tg["ar_z"], k)
	el.rotation.x = lerpf(el.rotation.x, tg["el_x"], k)
	er.rotation.x = lerpf(er.rotation.x, tg["er_x"], k)
	ll.rotation.x = lerpf(ll.rotation.x, tg["ll_x"], k)
	lr.rotation.x = lerpf(lr.rotation.x, tg["lr_x"], k)
	kl.rotation.x = lerpf(kl.rotation.x, tg["kl_x"], k)
	kr.rotation.x = lerpf(kr.rotation.x, tg["kr_x"], k)
	# movimiento secundario: la cadera se balancea, el torso gira contra ella, mochila y antena con retraso
	var moving_p: bool = pose == "walk" or pose == "run"
	var wf: float = 12.0 if pose == "walk" else 17.0
	var sw3: float = sin(t * wf) if moving_p else 0.0
	var amp3: float = 1.0 if pose == "walk" else 1.4
	rig.rotation.z = lerpf(rig.rotation.z, sw3 * 0.035 * amp3 + sin(t * 0.9 + phase) * 0.012, k)
	rig.rotation.y = lerpf(rig.rotation.y, -sw3 * 0.07 * amp3, k)
	body.rotation.y = lerpf(body.rotation.y, sw3 * 0.11 * amp3, k)
	body.rotation.z = lerpf(body.rotation.z, -sw3 * 0.02 * amp3, k)
	var pk: Node3D = P["pack"]
	var an: Node3D = P["ant"]
	var bounce: float = absf(sw3)
	pk.rotation.x = lerpf(pk.rotation.x, 0.05 * bounce * amp3 + (0.06 if pose == "gather" or pose == "grab" else 0.0), 0.12)
	an.rotation.z = lerpf(an.rotation.z, sin(t * wf * 0.5 + 1.0) * 0.12 * bounce * amp3 + sin(t * 1.3 + phase) * 0.03, 0.1)
	an.rotation.x = lerpf(an.rotation.x, cos(t * wf * 0.5) * 0.1 * bounce * amp3, 0.1)


func _player_pose() -> String:
	if game.mode == 5:
		match game.task_kind:
			"grab":
				return "grab"
			"mine":
				return "mine"
			"press":
				return "press"
		if game.outside:
			return "gather"
		return "craft" if game.task_is_craft else "work"
	if game.fall_t >= 0.0:
		return "fall"
	if game.outside and game.jump_z > 0.03:
		return "jump"
	if game.mode == 1:
		return "talk"
	if game.moving:
		return "run" if game.bind_down("sprint") else "walk"
	return "idle"


# ---------- efectos de acciones (recoger, picar, pulsar, fabricar) ----------

func _fx_root() -> Node3D:
	if fx_node == null or not is_instance_valid(fx_node):
		fx_node = Node3D.new()
		add_child(fx_node)
	return fx_node


func work_point(up: float = 0.9) -> Vector3:
	var fwd: Vector3 = Vector3(-sin(yaw_player), 0.0, -cos(yaw_player))
	return player_node.position + fwd * 0.85 + Vector3(0.0, up, 0.0)


func _fx_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	return m


func fx_burst(pos: Vector3, col: Color, n: int = 10, speed: float = 1.6, up: float = 2.2) -> void:
	n = fx_scale(n)
	var root: Node3D = _fx_root()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	for i in n:
		if fx_list.size() > 160:
			break
		var m := MeshInstance3D.new()
		m.mesh = sm
		var mat: StandardMaterial3D = _fx_mat(col)
		m.material_override = mat
		m.position = pos
		root.add_child(m)
		var a: float = randf() * TAU
		var r: float = randf_range(0.3, 1.0) * speed
		fx_list.append({"k": "p", "n": m, "mat": mat, "col": col, "v": Vector3(cos(a) * r, randf_range(0.4, 1.0) * up, sin(a) * r), "life": 0.0, "max": randf_range(0.45, 0.85), "g": 6.0})


func fx_popup(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 56
	l.pixel_size = 0.006
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.position = pos
	_fx_root().add_child(l)
	fx_list.append({"k": "label", "n": l, "col": col, "v": Vector3(0, 0.9, 0), "life": 0.0, "max": 1.3, "g": 0.0})


func fx_ring(pos: Vector3, col: Color, size: float = 0.5) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = size * 0.88
	tm.outer_radius = size
	tm.rings = 20
	tm.ring_segments = 6
	m.mesh = tm
	var mat: StandardMaterial3D = _fx_mat(col)
	m.material_override = mat
	m.position = pos
	_fx_root().add_child(m)
	fx_list.append({"k": "ring", "n": m, "mat": mat, "col": col, "v": Vector3.ZERO, "life": 0.0, "max": 0.55, "g": 0.0})


func fx_fly(from: Vector3, col: Color) -> void:
	# una pieza vuela desde el punto de recogida hasta la mochila del jugador
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.2)
	m.mesh = bm
	var mat: StandardMaterial3D = _fx_mat(col)
	m.material_override = mat
	m.position = from
	_fx_root().add_child(m)
	fx_list.append({"k": "fly", "n": m, "mat": mat, "col": col, "from": from, "v": Vector3.ZERO, "life": 0.0, "max": 0.6, "g": 0.0})


func fx_event(kind: String, text: String, col: Color) -> void:
	# lo llama main.gd: kind = grab | mine | press | craft | done | ring
	if player_node == null or not game.view3d_on:
		return
	var wp: Vector3 = work_point(0.9)
	match kind:
		"grab":
			fx_burst(player_node.position + (wp - player_node.position) * 0.9 + Vector3(0, 0.1, 0), col, 12, 1.2, 1.6)
			fx_fly(wp - Vector3(0, 0.6, 0), col)
		"mine":
			fx_burst(wp - Vector3(0, 0.7, 0), Color(0.75, 0.92, 1.0), 14, 1.6, 2.2)
			fx_fly(wp - Vector3(0, 0.5, 0), Color(0.75, 0.92, 1.0))
		"press":
			fx_ring(wp, col, 0.35)
		"craft":
			fx_burst(wp, Color(1.0, 0.8, 0.3), 14, 1.4, 2.4)
		"done":
			fx_burst(player_node.position + Vector3(0, 1.1, 0), col, 16, 1.5, 2.6)
			fx_ring(player_node.position + Vector3(0, 0.05, 0), col, 0.6)
		"ring":
			fx_ring(wp - Vector3(0, 0.6, 0), col, 0.45)
	if text != "":
		fx_popup(player_node.position + Vector3(0, 2.2, 0), text, col)


func _task_fx(delta: float) -> void:
	# efectos continuos mientras dura la tarea, segun el progreso
	if game.mode == 5 and game.task_total > 0.0:
		act_u = clampf(1.0 - game.task_left / game.task_total, 0.0, 1.0)
		var wp: Vector3 = work_point(0.9)
		match game.task_kind:
			"mine":
				var st: int = int(floor(act_u * 3.0 + 0.25))
				if st != _fx_step:
					_fx_step = st
					fx_burst(wp - Vector3(0, 0.75, 0), Color(0.8, 0.93, 1.0), 6, 1.2, 1.8)
			"press":
				var st2: int = int(floor(act_u * 3.5 + 0.25))
				if st2 != _fx_step:
					_fx_step = st2
					fx_ring(wp, Color(0.5, 0.9, 1.0), 0.18)
			"craft":
				_fx_acc += delta
				if _fx_acc > 0.18:
					_fx_acc = 0.0
					fx_burst(wp, Color(1.0, 0.78, 0.3), 3, 1.0, 1.6)
			"grab":
				var st3: int = int(floor(act_u * 4.0))
				if st3 != _fx_step:
					_fx_step = st3
					fx_burst(wp - Vector3(0, 0.75, 0), Color(0.7, 0.66, 0.6), 4, 0.8, 1.0)
	else:
		_fx_step = -1
		act_u = 0.0


func _fx_update(delta: float) -> void:
	var i: int = fx_list.size() - 1
	while i >= 0:
		var e: Dictionary = fx_list[i]
		var n: Node3D = e["n"]
		if n == null or not is_instance_valid(n):
			fx_list.remove_at(i)
			i -= 1
			continue
		e["life"] = float(e["life"]) + delta
		var u: float = clampf(float(e["life"]) / float(e["max"]), 0.0, 1.0)
		var col: Color = e["col"]
		match str(e["k"]):
			"p":
				var v: Vector3 = e["v"]
				v.y -= float(e["g"]) * delta
				e["v"] = v
				n.position += v * delta
				var mat: StandardMaterial3D = e["mat"]
				mat.albedo_color = Color(col.r, col.g, col.b, 1.0 - u)
			"label":
				n.position += (e["v"] as Vector3) * delta
				(n as Label3D).modulate = Color(col.r, col.g, col.b, 1.0 - maxf(0.0, (u - 0.55) / 0.45))
				var sc: float = 0.7 + 0.5 * minf(u * 6.0, 1.0)
				n.scale = Vector3(sc, sc, sc)
			"ring":
				var s: float = 1.0 + 2.2 * u
				n.scale = Vector3(s, 1.0, s)
				var mat2: StandardMaterial3D = e["mat"]
				mat2.albedo_color = Color(col.r, col.g, col.b, 0.9 * (1.0 - u))
			"fly":
				var a: Vector3 = e["from"]
				var b: Vector3 = player_node.position + Vector3(0, 1.0, 0)
				n.position = a.lerp(b, u * u * (3.0 - 2.0 * u)) + Vector3(0, sin(PI * u) * 0.6, 0)
				n.rotation.y += delta * 9.0
				var s2: float = 1.0 - 0.6 * u
				n.scale = Vector3(s2, s2, s2)
		if u >= 1.0:
			if str(e["k"]) == "fly":
				fx_burst(player_node.position + Vector3(0, 1.0, 0), col, 5, 0.6, 1.2)
			n.queue_free()
			fx_list.remove_at(i)
		i -= 1


# ---------- interior ----------

func _floor_tex(moon: bool) -> ImageTexture:
	var base: Color = Color(0.46, 0.48, 0.56) if moon else Color(0.56, 0.37, 0.31)
	var img := Image.create(256, 160, false, Image.FORMAT_RGBA8)
	for ty in 10:
		for tx in 16:
			var shade: float = (game._hf(tx, ty, 1) - 0.5) * 0.08
			var c := Color(base.r + shade, base.g + shade, base.b + shade)
			for py in 16:
				for px in 16:
					var col: Color = c
					if px == 0 or py == 0:
						col = c.darkened(0.25)
					elif px == 1 or py == 1:
						col = c.lightened(0.05)
					img.set_pixel(tx * 16 + px, ty * 16 + py, col)
			for i in 4:
				var sx: int = 2 + int(game._hf(tx, ty, 10 + i) * 12.0)
				var sy: int = 2 + int(game._hf(tx, ty, 20 + i) * 12.0)
				img.set_pixel(tx * 16 + sx, ty * 16 + sy, c.darkened(0.2))
	var t: ImageTexture = ImageTexture.create_from_image(img)
	return t


func _window_tex(moon: bool, x: int) -> ImageTexture:
	var lv: int = clampi(int(game.tex_quality), 0, 2)
	var w: int = 128 if lv < 2 else 192
	var img: Image = SpaceTex.window_image(moon, x, w, int(float(w) * 1.07))
	var t: ImageTexture = ImageTexture.create_from_image(img)
	return t


func _panel_tex() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var c: Color = Color(0.1, 0.2, 0.55)
			if x % 16 == 0 or y % 16 == 0:
				c = Color(0.55, 0.65, 0.95)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _build_interior() -> void:
	interior = Node3D.new()
	add_child(interior)
	var moon: bool = game.location == "Luna"
	int_mats.clear()
	# v38: suelo menos claro (antes deslumbraba visto desde arriba)
	var floor_mat: StandardMaterial3D = _int_mat("floor", Color(0.36, 0.38, 0.43) if moon else Color(0.45, 0.32, 0.28), 0.5, 0.25)
	_add(interior, _box(Vector3(16.0 * T3, 0.2, 10.0 * T3)), floor_mat, Vector3(8.0 * T3, -0.1, 5.0 * T3))
	var wall: StandardMaterial3D = _int_mat("wall", Color(0.26, 0.29, 0.38), 0.55, 0.35)
	var trim: StandardMaterial3D = _m(Color(0.5, 0.56, 0.68), 0.6, 0.35)
	var cap: StandardMaterial3D = InteriorLook.cap_mat(self)
	var map: Array = game.MAP
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			var ch: String = row[x]
			var c: Vector3 = _tp(x, y)
			if ch == "#":
				if y == 0 and x % 3 == 1 and x > 0 and x < 15:
					_build_window(x, y, moon, wall, trim)
					continue
				var h: float = 3.2
				if y == 9:
					h = 1.0
				elif y == 3:
					h = 1.7
				_add(interior, _box(Vector3(T3, h, T3)), wall, c + Vector3(0, h / 2.0, 0))
				_add(interior, _box(Vector3(T3 + 0.06, 0.1, T3 + 0.06)), cap, c + Vector3(0, h + 0.05, 0), Vector3.ZERO, false)
			elif ch != "." and ch != "P":
				if game.npcs.has(ch):
					var n: Dictionary = game.npcs[ch]
					var a: Node3D = _make_astronaut(n["suit"], ch)
					a.position = c
					interior.add_child(a)
					_nametag(a, Lang.speaker(str(n["who"])), (n["suit"] as Color).lightened(0.35))
					npc_nodes[ch] = a
				else:
					_build_prop(ch, c)
	# v38: estructura, tuberías, equipo de pared y luces (interior_look.gd)
	InteriorLook.build(self, interior, moon)
	InteriorLook.apply_gfx(int(game.fx_idx))
	InteriorLook.merge_static(interior)


func _build_ceiling() -> void:
	ceiling = Node3D.new()
	ceiling.visible = false
	interior.add_child(ceiling)
	_add(ceiling, _box(Vector3(16.0 * T3 + 0.2, 0.2, 10.0 * T3 + 0.2)), _int_mat("ceiling", Color(0.2, 0.22, 0.3), 0.6, 0.4), Vector3(16.0, 3.4, 10.0), Vector3.ZERO, false)
	var lm: StandardMaterial3D = _m(Color(1.0, 0.97, 0.88), 0.0, 0.5, 1.8)
	for lx in [5.0, 13.0, 21.0, 29.0]:
		for lz in [6.0, 14.0]:
			_add(ceiling, _box(Vector3(2.6, 0.06, 0.5)), lm, Vector3(lx, 3.27, lz), Vector3.ZERO, false)
	InteriorLook.build_upper(self, ceiling, game.MAP)   # v38
	InteriorLook.merge_static(ceiling)


func _build_window(x: int, y: int, moon: bool, wall: Material, trim: Material) -> void:
	var c: Vector3 = _tp(x, y)
	_add(interior, _box(Vector3(T3, 0.9, T3)), wall, c + Vector3(0, 0.45, 0))
	_add(interior, _box(Vector3(T3, 0.7, T3)), wall, c + Vector3(0, 2.85, 0))
	_add(interior, _box(Vector3(T3 + 0.06, 0.1, T3 + 0.06)), InteriorLook.cap_mat(self), c + Vector3(0, 3.25, 0), Vector3.ZERO, false)   # v38
	var q := QuadMesh.new()
	q.size = Vector2(T3 - 0.5, 1.6)
	var wm := StandardMaterial3D.new()
	wm.albedo_texture = _window_tex(moon, x)
	wm.emission_enabled = true
	wm.emission_texture = wm.albedo_texture
	wm.emission_energy_multiplier = 0.9
	_add(interior, q, wm, Vector3(c.x, 1.7, float(y + 1) * T3 - 0.02), Vector3.ZERO, false)
	_add(interior, _box(Vector3(T3, 0.12, 0.2)), trim, Vector3(c.x, 1.0, float(y + 1) * T3 - 0.1), Vector3.ZERO, false)
	_add(interior, _box(Vector3(0.12, 1.6, 0.2)), trim, Vector3(c.x - (T3 - 0.5) / 2.0, 1.7, float(y + 1) * T3 - 0.1), Vector3.ZERO, false)
	_add(interior, _box(Vector3(0.12, 1.6, 0.2)), trim, Vector3(c.x + (T3 - 0.5) / 2.0, 1.7, float(y + 1) * T3 - 0.1), Vector3.ZERO, false)


func _led(parent: Node3D, pos: Vector3, on: Color, off: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = off
	m.emission_enabled = true
	m.emission = off
	led_mats.append([m, on, off])
	_add(parent, _sph(0.07, 8), m, pos, Vector3.ZERO, false)


func _blob_tex() -> Texture2D:
	if blob_tex == null:
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(0, 0, 0, 0.55))
		gr.set_color(1, Color(0, 0, 0, 0.0))
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		blob_tex = gt
	return blob_tex


var blob_tex: Texture2D = null


func _blob(parent: Node3D, size: float) -> void:
	# sombra suave de contacto bajo los objetos (da peso y asienta el modelo en el suelo)
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = _blob_tex()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.disable_receive_shadows = true
	var mi := _add(parent, q, bm, Vector3(0, 0.015, 0), Vector3(-PI / 2.0, 0, 0), false)
	mi.name = "blob"


func _bolts(parent: Node3D, radius: float, y: float, count: int) -> void:
	var bm: StandardMaterial3D = _m(Color(0.8, 0.82, 0.9), 0.95, 0.25)
	for i in count:
		var a: float = TAU * float(i) / float(count)
		_add(parent, _cyl(0.035, 0.035, 0.05, 8), bm, Vector3(cos(a) * radius, y, sin(a) * radius), Vector3.ZERO, false)


func _build_prop(ch: String, c: Vector3) -> void:
	var n := Node3D.new()
	n.position = c
	if ch == "T":
		n.rotation.y = PI      # el banco esta contra la pared norte: su frente (cajones) mira al jugador, al sur
	interior.add_child(n)
	var metal: StandardMaterial3D = _m(Color(0.62, 0.64, 0.72), 0.8, 0.3)
	var dark: StandardMaterial3D = _m(Color(0.2, 0.22, 0.28), 0.5, 0.5)
	if game.stations.has(ch) and ch != "B" and ch != "T":
		prop_nodes[ch] = n
		_build_lvl(ch, n)
		_build_scaffold(ch, n)
	if STATION_SIZE.has(ch) and _place_glb_prop(n, "station_" + ch, float(STATION_SIZE[ch])):
		return
	# v33: estaciones con el estilo de la referencia (station_art.gd), con animaciones discretas
	if StationArt.build(self, n, ch):
		if ch == "D":
			set_meta("door_tile", Vector2(c.x / T3, c.z / T3))
		return
	match ch:
		"O":
			# tanque de oxigeno: cuerpo pulido que refleja el cielo, bandas, valvula y manometro
			_blob(n, 2.6)
			var tank: StandardMaterial3D = _m(Color(0.66, 0.84, 1.0), 0.85, 0.2)
			var band: StandardMaterial3D = _m(Color(0.12, 0.38, 0.8), 0.6, 0.3)
			_add(n, _cyl(0.55, 0.55, 1.7, 40), tank, Vector3(0, 1.0, 0))
			_add(n, _sph(0.55, 32, true), tank, Vector3(0, 1.85, 0))
			_add(n, _sph(0.55, 32, true), tank, Vector3(0, 0.15, 0), Vector3(PI, 0, 0))
			_add(n, _cyl(0.575, 0.575, 0.3, 40), band, Vector3(0, 1.3, 0))
			_add(n, _cyl(0.575, 0.575, 0.08, 40), _m(Color(0.9, 0.92, 0.98), 0.9, 0.15), Vector3(0, 0.78, 0))
			_add(n, _cyl(0.575, 0.575, 0.08, 40), _m(Color(0.9, 0.92, 0.98), 0.9, 0.15), Vector3(0, 1.62, 0))
			_add(n, _cyl(0.09, 0.11, 0.3), metal, Vector3(0, 2.48, 0))
			_add(n, _tor(0.1, 0.22), _m(Color(0.9, 0.2, 0.2), 0.4, 0.35), Vector3(0, 2.66, 0))
			_add(n, _cyl(0.04, 0.04, 0.5), metal, Vector3(0.0, 2.66, 0.0), Vector3(0, 0, PI / 2.0))
			# manometro
			_add(n, _cyl(0.17, 0.17, 0.06), _m(Color(0.1, 0.11, 0.15), 0.6, 0.3), Vector3(0, 1.3, 0.585), Vector3(PI / 2.0, 0, 0))
			_add(n, _cyl(0.14, 0.14, 0.02), _m(Color(0.7, 1.0, 0.8), 0.0, 0.3, 1.2), Vector3(0, 1.3, 0.62), Vector3(PI / 2.0, 0, 0), false)
			_add(n, _box(Vector3(0.015, 0.11, 0.01)), _m(Color(0.9, 0.1, 0.1), 0.0, 0.4, 1.0), Vector3(0.03, 1.33, 0.635), Vector3(0, 0, -0.5), false)
			# base con tornillos y tuberia
			_add(n, _cyl(0.85, 0.9, 0.12, 8), dark, Vector3(0, 0.06, 0))
			_bolts(n, 0.78, 0.13, 8)
			_add(n, _cyl(0.07, 0.07, 1.0), metal, Vector3(0.7, 0.5, -0.5))
			_add(n, _sph(0.1, 10), metal, Vector3(0.7, 1.0, -0.5))
		"S":
			# panel solar con marco, celdas brillantes y mastil articulado
			_blob(n, 2.4)
			_add(n, _cyl(0.15, 0.2, 0.18, 8), dark, Vector3(0, 0.09, 0))
			_add(n, _cyl(0.07, 0.1, 1.5), _m(Color(0.7, 0.72, 0.8), 0.9, 0.25), Vector3(0, 0.9, 0))
			_add(n, _sph(0.13, 14), _m(Color(0.75, 0.77, 0.85), 0.9, 0.2), Vector3(0, 1.7, 0))
			var pm := StandardMaterial3D.new()
			pm.albedo_texture = _panel_tex()
			pm.metallic = 0.85
			pm.roughness = 0.12
			var pan := Node3D.new()
			pan.position = Vector3(0, 1.85, 0)
			pan.rotation = Vector3(-0.55, 0, 0)
			n.add_child(pan)
			_add(pan, _box(Vector3(1.9, 0.06, 1.3)), pm, Vector3.ZERO)
			var fr: StandardMaterial3D = _m(Color(0.78, 0.8, 0.88), 0.9, 0.2)
			_add(pan, _box(Vector3(2.0, 0.09, 0.06)), fr, Vector3(0, 0, 0.66), Vector3.ZERO, false)
			_add(pan, _box(Vector3(2.0, 0.09, 0.06)), fr, Vector3(0, 0, -0.66), Vector3.ZERO, false)
			_add(pan, _box(Vector3(0.06, 0.09, 1.3)), fr, Vector3(0.97, 0, 0), Vector3.ZERO, false)
			_add(pan, _box(Vector3(0.06, 0.09, 1.3)), fr, Vector3(-0.97, 0, 0), Vector3.ZERO, false)
			_add(pan, _box(Vector3(0.04, 0.09, 1.3)), fr, Vector3.ZERO, Vector3.ZERO, false)
			_add(n, _cyl(0.025, 0.025, 0.8), metal, Vector3(0, 1.45, -0.35), Vector3(-0.3, 0, 0), false)
			_add(n, _box(Vector3(0.4, 0.3, 0.3)), dark, Vector3(0.55, 0.15, 0.4))
			_led(n, Vector3(0.55, 0.22, 0.56), Color(0.2, 1.0, 0.4), Color(0.05, 0.3, 0.1))
		"G":
			# invernadero: maceta con borde, plantas con hojas, cupula de cristal con nervios
			_blob(n, 2.5)
			var soil: StandardMaterial3D = _m(Color(0.3, 0.2, 0.15), 0.0, 0.95)
			_add(n, _box(Vector3(1.7, 0.4, 1.7)), _m(Color(0.5, 0.52, 0.6), 0.7, 0.35), Vector3(0, 0.2, 0))
			_add(n, _box(Vector3(1.5, 0.08, 1.5)), soil, Vector3(0, 0.42, 0))
			var stem: StandardMaterial3D = _m(Color(0.2, 0.55, 0.2), 0.0, 0.6)
			var leafm: StandardMaterial3D = _m(Color(0.28, 0.8, 0.32), 0.0, 0.5)
			for i in 6:
				var a: float = TAU * float(i) / 6.0
				var px: float = cos(a) * 0.5
				var pz: float = sin(a) * 0.5
				_add(n, _cyl(0.025, 0.04, 0.8, 8), stem, Vector3(px, 0.85, pz))
				for k in 3:
					var lf: MeshInstance3D = _add(n, _sph(0.2, 12), leafm, Vector3(px + cos(a + float(k) * 2.1) * 0.14, 1.0 + float(k) * 0.13, pz + sin(a + float(k) * 2.1) * 0.14), Vector3(0, a + float(k), 0.3))
					lf.scale = Vector3(1.4, 0.35, 0.8)
			_add(n, _sph(1.0, 32, true), _m(Color(0.65, 1.0, 0.88, 0.22), 0.3, 0.04), Vector3(0, 0.42, 0), Vector3.ZERO, false)
			_add(n, _tor(0.97, 1.03), _m(Color(0.75, 0.78, 0.86), 0.9, 0.2), Vector3(0, 0.44, 0), Vector3.ZERO, false)
			for rb in 3:
				_add(n, _tor(0.985, 1.012), _m(Color(0.75, 0.78, 0.86), 0.9, 0.2), Vector3(0, 0.42, 0), Vector3(PI / 2.0, 0, float(rb) * PI / 3.0), false)
			_add(n, _sph(0.08, 8), _m(Color(0.9, 1.0, 0.9), 0.0, 0.3, 2.0), Vector3(0, 1.4, 0), Vector3.ZERO, false)
		"W":
			# reciclador de agua: tanque de cristal con agua, marco, bomba y mirilla
			_blob(n, 2.5)
			_add(n, _cyl(0.62, 0.62, 1.7, 40), _m(Color(0.75, 0.84, 0.92, 0.3), 0.5, 0.05), Vector3(0, 1.0, 0), Vector3.ZERO, false)
			_add(n, _cyl(0.57, 0.57, 1.0, 40), _m(Color(0.18, 0.5, 0.95, 0.82), 0.1, 0.1, 0.45), Vector3(0, 0.65, 0), Vector3.ZERO, false)
			var fm: StandardMaterial3D = _m(Color(0.78, 0.8, 0.88), 0.9, 0.2)
			_add(n, _cyl(0.68, 0.68, 0.12, 40), fm, Vector3(0, 0.06, 0))
			_add(n, _cyl(0.68, 0.68, 0.12, 40), fm, Vector3(0, 1.88, 0))
			for k in 4:
				var a2: float = TAU * float(k) / 4.0 + PI / 4.0
				_add(n, _cyl(0.04, 0.04, 1.8, 10), fm, Vector3(cos(a2) * 0.66, 0.97, sin(a2) * 0.66))
			for k in 4:
				_add(n, _box(Vector3(0.3, 0.02, 0.02)), _m(Color(1, 1, 1), 0.0, 0.5, 0.6), Vector3(0, 0.35 + float(k) * 0.35, 0.64), Vector3.ZERO, false)
			_add(n, _box(Vector3(0.5, 0.42, 0.42)), dark, Vector3(0.95, 0.21, 0.2))
			_add(n, _cyl(0.07, 0.07, 0.6), metal, Vector3(0.78, 0.5, 0.1), Vector3(0, 0, PI / 2.0))
			_add(n, _cyl(0.06, 0.06, 0.6), metal, Vector3(0.95, 0.7, 0.2))
			_led(n, Vector3(1.05, 0.33, 0.42), Color(0.3, 0.85, 1.0), Color(0.05, 0.2, 0.3))
			_add(n, _sph(0.13, 12), _m(Color(0.3, 0.85, 1.0), 0.0, 0.3, 1.8), Vector3(0, 2.15, 0), Vector3.ZERO, false)
		"R":
			# generador de escudo: base hexagonal biselada, pilonas con bobinas y nucleo brillante
			_blob(n, 2.7)
			shield_mat = _m(Color(0.52, 0.3, 0.8), 0.8, 0.25)
			shield_mat = shield_mat.duplicate() as StandardMaterial3D
			_add(n, _cyl(1.05, 1.15, 0.2, 6), dark, Vector3(0, 0.1, 0))
			_add(n, _cyl(0.92, 1.05, 0.2, 6), shield_mat, Vector3(0, 0.3, 0))
			var coil: StandardMaterial3D = _m(Color(0.95, 0.75, 0.3), 0.9, 0.2)
			for i in 3:
				var a3: float = TAU * float(i) / 3.0
				var cxp: float = cos(a3) * 0.7
				var czp: float = sin(a3) * 0.7
				_add(n, _cyl(0.07, 0.11, 1.9, 12), metal, Vector3(cxp, 1.25, czp))
				for k in 3:
					_add(n, _tor(0.1, 0.15), coil, Vector3(cxp, 0.7 + float(k) * 0.35, czp), Vector3(PI / 2.0, 0, 0), false)
				_add(n, _sph(0.1, 10), _m(Color(0.9, 0.7, 1.0), 0.0, 0.3, 2.2), Vector3(cxp, 2.25, czp), Vector3.ZERO, false)
			_add(n, _sph(0.3, 24), _m(Color(1.0, 0.88, 0.25), 0.0, 0.3, 2.4), Vector3(0, 1.2, 0), Vector3.ZERO, false)
			shield_ring = Node3D.new()
			shield_ring.position = Vector3(0, 1.2, 0)
			n.add_child(shield_ring)
			_add(shield_ring, _tor(0.6, 0.72), _m(Color(0.78, 0.55, 1.0), 0.6, 0.25, 0.9), Vector3.ZERO, Vector3(PI / 2.0 - 0.3, 0, 0), false)
		"C":
			# area de descanso: sofa redondeado, cojines y mesita con lampara
			_blob(n, 2.6)
			var cush: StandardMaterial3D = _m(Color(0.96, 0.52, 0.34), 0.0, 0.8)
			var cush2: StandardMaterial3D = _m(Color(0.78, 0.38, 0.24), 0.0, 0.85)
			_add(n, _box(Vector3(1.9, 0.14, 0.9)), _m(Color(0.3, 0.2, 0.18), 0.4, 0.5), Vector3(0, 0.12, 0.1))
			var seat: MeshInstance3D = _add(n, _cap(0.22, 1.7), cush, Vector3(0, 0.42, 0.12), Vector3(0, 0, PI / 2.0))
			seat.scale = Vector3(1.0, 1.0, 1.9)
			var back: MeshInstance3D = _add(n, _cap(0.24, 1.7), cush, Vector3(0, 0.88, 0.5), Vector3(0, 0, PI / 2.0))
			back.scale = Vector3(1.4, 1.0, 0.8)
			for sx in [-1.0, 1.0]:
				var arm: MeshInstance3D = _add(n, _cap(0.17, 0.9), cush2, Vector3(0.98 * sx, 0.62, 0.15), Vector3(PI / 2.0, 0, 0))
				arm.scale = Vector3(1.0, 1.0, 1.0)
			_add(n, _sph(0.2, 14), _m(Color(1.0, 0.4, 0.5), 0.0, 0.7), Vector3(0.45, 0.78, 0.15))
			_add(n, _sph(0.17, 14), _m(Color(0.4, 0.75, 1.0), 0.0, 0.7), Vector3(-0.4, 0.74, 0.18))
		"B":
			var frame: StandardMaterial3D = _m(Color(0.55, 0.58, 0.68), 0.6, 0.4)
			var sheet: StandardMaterial3D = _m(Color(0.3, 0.45, 0.8), 0.0, 0.85)
			var pillow: StandardMaterial3D = _m(Color(0.95, 0.95, 1.0), 0.0, 0.9)
			for sx in [-0.82, 0.82]:
				for sz in [-1.15, 1.15]:
					_add(n, _cyl(0.07, 0.08, 0.22, 10), frame, Vector3(sx, 0.11, sz))
			_add(n, _box(Vector3(1.78, 0.14, 2.46)), frame, Vector3(0, 0.29, 0))
			# colchon redondeado
			var mat_m: MeshInstance3D = _add(n, _box(Vector3(1.64, 0.26, 2.3)), _m(Color(0.86, 0.88, 0.95), 0.0, 0.9), Vector3(0, 0.46, 0))
			for sz in [-1.15, 1.15]:
				_add(n, _cyl(0.13, 0.13, 1.64, 12), _m(Color(0.86, 0.88, 0.95), 0.0, 0.9), Vector3(0, 0.46, sz), Vector3(0, 0, PI / 2.0))
			# manta con dobles
			_add(n, _box(Vector3(1.68, 0.12, 1.3)), sheet, Vector3(0, 0.64, -0.4))
			_add(n, _cyl(0.07, 0.07, 1.68, 10), sheet, Vector3(0, 0.66, 0.26), Vector3(0, 0, PI / 2.0))
			_add(n, _box(Vector3(1.7, 0.03, 0.12)), _m(Color(0.95, 0.8, 0.2), 0.0, 0.7), Vector3(0, 0.71, -0.2), Vector3.ZERO, false)
			# almohada
			var pil: MeshInstance3D = _add(n, _sph(0.38, 14), pillow, Vector3(0, 0.74, 0.78))
			pil.scale = Vector3(1.5, 0.42, 0.9)
			# cabecera con panel y luz de lectura
			_add(n, _box(Vector3(1.9, 0.9, 0.12)), frame, Vector3(0, 0.62, 1.28))
			_add(n, _box(Vector3(0.6, 0.2, 0.04)), _m(Color(0.1, 0.12, 0.2), 0.0, 0.5), Vector3(0, 0.95, 1.2), Vector3.ZERO, false)
			_add(n, _box(Vector3(0.5, 0.06, 0.03)), _m(Color(0.5, 0.8, 1.0), 0.0, 0.4, 1.6), Vector3(0, 0.95, 1.18), Vector3.ZERO, false)
			_add(n, _cyl(0.025, 0.025, 0.5), metal, Vector3(0.7, 1.3, 1.22))
			_add(n, _sph(0.09, 8), _m(Color(1.0, 0.95, 0.7), 0.0, 0.4, 2.0), Vector3(0.7, 1.55, 1.1), Vector3.ZERO, false)
			# pie de cama con barra
			_add(n, _box(Vector3(1.78, 0.3, 0.08)), frame, Vector3(0, 0.42, -1.25))
			_led(n, Vector3(0.7, 0.6, -1.27), Color(0.3, 0.6, 1.0), Color(0.05, 0.12, 0.25))
		"T":
			var wood: StandardMaterial3D = _m(Color(0.6, 0.46, 0.3), 0.1, 0.65)
			var bin_cols: Array = [Color(0.9, 0.3, 0.25), Color(0.25, 0.7, 0.9), Color(0.95, 0.8, 0.2)]
			_add(n, _box(Vector3(1.9, 0.12, 1.0)), wood, Vector3(0, 1.0, 0))
			_add(n, _box(Vector3(1.94, 0.05, 1.04)), metal, Vector3(0, 0.95, 0), Vector3.ZERO, false)
			for sx in [-0.85, 0.85]:
				for sz in [-0.4, 0.4]:
					_add(n, _box(Vector3(0.08, 0.95, 0.08)), metal, Vector3(sx, 0.47, sz))
			_add(n, _box(Vector3(1.7, 0.06, 0.06)), metal, Vector3(0, 0.3, 0.4), Vector3.ZERO, false)
			_add(n, _box(Vector3(1.7, 0.06, 0.06)), metal, Vector3(0, 0.3, -0.4), Vector3.ZERO, false)
			# cajones
			_add(n, _box(Vector3(0.7, 0.42, 0.8)), dark, Vector3(-0.5, 0.6, 0))
			for i in 2:
				_add(n, _box(Vector3(0.6, 0.15, 0.03)), _m(Color(0.35, 0.38, 0.48), 0.5, 0.5), Vector3(-0.5, 0.5 + float(i) * 0.2, -0.42), Vector3.ZERO, false)
				_add(n, _box(Vector3(0.18, 0.03, 0.03)), metal, Vector3(-0.5, 0.5 + float(i) * 0.2, -0.45), Vector3.ZERO, false)
			# panel de herramientas en la pared trasera
			_add(n, _box(Vector3(1.8, 0.9, 0.06)), _m(Color(0.3, 0.33, 0.42), 0.3, 0.6), Vector3(0, 1.62, 0.46))
			for i in 5:
				var tx: float = -0.7 + float(i) * 0.35
				_add(n, _box(Vector3(0.05, 0.4, 0.04)), _m(bin_cols[i % 3], 0.4, 0.5), Vector3(tx, 1.62, 0.42), Vector3(0, 0, 0.1 * float(i - 2)), false)
				_add(n, _box(Vector3(0.12, 0.1, 0.04)), metal, Vector3(tx, 1.84, 0.42), Vector3.ZERO, false)
			# tornillo de banco, engranaje y cajitas de piezas
			_add(n, _box(Vector3(0.26, 0.2, 0.22)), metal, Vector3(0.7, 1.16, -0.2))
			_add(n, _cyl(0.03, 0.03, 0.3), dark, Vector3(0.7, 1.2, -0.38), Vector3(PI / 2.0, 0, 0), false)
			var gear: MeshInstance3D = _add(n, _cyl(0.28, 0.28, 0.07, 12), _m(Color(0.85, 0.7, 0.2), 0.8, 0.35), Vector3(0.05, 1.1, -0.1))
			_add(n, _cyl(0.09, 0.09, 0.09, 8), dark, Vector3(0.05, 1.12, -0.1))
			for i in 3:
				_add(n, _box(Vector3(0.22, 0.12, 0.22)), _m(bin_cols[i], 0.0, 0.7), Vector3(-0.2 + float(i) * 0.26, 1.12, 0.28))
			# lampara articulada
			_add(n, _cyl(0.04, 0.04, 0.55), metal, Vector3(-0.8, 1.3, 0.3))
			_add(n, _cyl(0.03, 0.03, 0.5), metal, Vector3(-0.62, 1.55, 0.3), Vector3(0, 0, 1.0), false)
			_add(n, _sph(0.1, 8), _m(Color(1.0, 0.95, 0.7), 0.0, 0.4, 2.2), Vector3(-0.42, 1.7, 0.3), Vector3.ZERO, false)
		"A":
			var shell: StandardMaterial3D = _m(Color(0.3, 0.33, 0.42), 0.5, 0.5)
			_add(n, _box(Vector3(1.4, 0.85, 0.75)), dark, Vector3(0, 0.43, 0.05))
			_add(n, _box(Vector3(1.46, 0.08, 0.8)), shell, Vector3(0, 0.88, 0.05), Vector3.ZERO, false)
			# pantalla con ondas
			_add(n, _box(Vector3(0.84, 0.46, 0.05)), _m(Color(0.02, 0.1, 0.06), 0.0, 0.3), Vector3(0, 0.6, -0.34), Vector3.ZERO, false)
			var eq: StandardMaterial3D = _m(Color(0.2, 0.95, 0.5), 0.0, 0.4, 1.6)
			for i in 11:
				var hh: float = 0.08 + 0.18 * absf(sin(float(i) * 1.3))
				_add(n, _box(Vector3(0.045, hh, 0.02)), eq, Vector3(-0.36 + float(i) * 0.072, 0.44 + hh / 2.0, -0.37), Vector3.ZERO, false)
			# perillas, botones y altavoz
			for i in 3:
				_add(n, _cyl(0.07, 0.07, 0.06, 12), metal, Vector3(-0.55 + float(i) * 0.2, 0.24, -0.34), Vector3(PI / 2.0, 0, 0), false)
			for i in 3:
				_add(n, _box(Vector3(0.1, 0.06, 0.04)), _m(bin_col_a(i), 0.0, 0.5, 0.6), Vector3(0.1 + float(i) * 0.16, 0.24, -0.35), Vector3.ZERO, false)
			for i in 5:
				_add(n, _box(Vector3(0.28, 0.015, 0.02)), _m(Color(0.05, 0.05, 0.08), 0.0, 0.5), Vector3(0.52, 0.42 + float(i) * 0.05, -0.36), Vector3.ZERO, false)
			# mastil y antena parabolica
			_add(n, _cyl(0.05, 0.06, 1.2), metal, Vector3(0.5, 1.5, 0.15))
			_add(n, _cyl(0.025, 0.025, 0.7), metal, Vector3(0.5, 1.3, 0.35), Vector3(0.6, 0, 0), false)
			var dish: MeshInstance3D = _add(n, _sph(0.58, 18, true), _m(Color(0.9, 0.9, 0.95), 0.6, 0.3), Vector3(0.5, 2.15, 0.15), Vector3(-0.9, 0, 0))
			dish.scale = Vector3(1.0, 0.55, 1.0)
			_add(n, _cyl(0.015, 0.015, 0.4), metal, Vector3(0.5, 2.35, -0.1), Vector3(-0.9, 0, 0), false)
			_add(n, _sph(0.045, 8), _m(Color(1.0, 0.3, 0.3), 0.0, 0.4, 1.8), Vector3(0.5, 2.5, -0.2), Vector3.ZERO, false)
			# antena de latigo y auriculares
			_add(n, _cyl(0.012, 0.012, 1.0), metal, Vector3(-0.6, 1.4, 0.2), Vector3.ZERO, false)
			_add(n, _tor(0.07, 0.1), dark, Vector3(-0.62, 0.95, -0.1), Vector3(PI / 2.0, 0, 0), false)
			_led(n, Vector3(-0.45, 0.9, -0.3), Color(0.2, 1.0, 0.3), Color(0.05, 0.25, 0.08))
			_led(n, Vector3(-0.3, 0.9, -0.3), Color(1.0, 0.75, 0.2), Color(0.25, 0.18, 0.05))
		"D":
			var hazard: StandardMaterial3D = _m(Color(0.95, 0.8, 0.1), 0.0, 0.5, 0.4)
			_add(n, _box(Vector3(0.4, 3.2, 0.8)), metal, Vector3(-0.9, 1.6, 0))
			_add(n, _box(Vector3(0.4, 3.2, 0.8)), metal, Vector3(0.9, 1.6, 0))
			_add(n, _box(Vector3(2.2, 0.45, 0.8)), metal, Vector3(0, 3.0, 0))
			# hoja de la puerta con ventanilla y rueda de cierre
			_add(n, _box(Vector3(1.4, 2.6, 0.2)), _m(Color(0.2, 0.22, 0.3), 0.7, 0.35), Vector3(0, 1.3, 0))
			_add(n, _cyl(0.3, 0.3, 0.06, 20), _m(Color(0.05, 0.1, 0.2), 0.0, 0.2, 0.3), Vector3(0, 1.9, -0.11), Vector3(PI / 2.0, 0, 0), false)
			_add(n, _tor(0.3, 0.38), metal, Vector3(0, 1.9, -0.12), Vector3(PI / 2.0, 0, 0), false)
			_add(n, _tor(0.12, 0.2), metal, Vector3(0, 1.05, -0.14), Vector3(PI / 2.0, 0, 0), false)
			for k in 3:
				_add(n, _box(Vector3(0.04, 0.34, 0.04)), metal, Vector3(0, 1.05, -0.15), Vector3(0, 0, float(k) * PI / 3.0), false)
			for i in 4:
				_add(n, _box(Vector3(1.4, 0.16, 0.22)), hazard, Vector3(0, 0.3 + float(i) * 0.16, 0.0), Vector3.ZERO, false)
			# bisagras, remaches y panel de estado
			for i in 3:
				_add(n, _cyl(0.07, 0.07, 0.24, 8), dark, Vector3(-0.72, 0.5 + float(i) * 1.0, -0.05), Vector3.ZERO, false)
			_add(n, _box(Vector3(0.3, 0.5, 0.06)), dark, Vector3(1.0, 1.5, -0.42), Vector3.ZERO, false)
			_led(n, Vector3(1.0, 1.65, -0.46), Color(0.2, 1.0, 0.4), Color(0.05, 0.3, 0.1))
			_led(n, Vector3(1.0, 1.5, -0.46), Color(1.0, 0.75, 0.2), Color(0.3, 0.2, 0.05))
			_led(n, Vector3(1.0, 1.35, -0.46), Color(1.0, 0.25, 0.2), Color(0.3, 0.06, 0.05))
			_add(n, _box(Vector3(1.4, 0.05, 0.9)), _m(Color(0.3, 0.32, 0.4), 0.5, 0.5), Vector3(0, 0.03, 0), Vector3.ZERO, false)
			_led(n, Vector3(0, 3.35, 0), Color(0.2, 1.0, 0.4), Color(0.05, 0.3, 0.1))
			_add(n, _cyl(0.14, 0.14, 0.12, 12), metal, Vector3(0, 3.26, 0), Vector3.ZERO, false)


func bin_col_a(i: int) -> Color:
	return [Color(1.0, 0.4, 0.3), Color(0.3, 0.8, 1.0), Color(1.0, 0.85, 0.3)][i % 3]


# ---------- mejoras por nivel (interior) ----------

func _gold(emit: float = 0.5) -> StandardMaterial3D:
	return _m(Color(1.0, 0.82, 0.25), 0.8, 0.3, emit)


func _build_lvl(ch: String, n: Node3D) -> void:
	var old: Node = n.get_node_or_null("lv")
	if old != null:
		old.queue_free()
	var lvn := Node3D.new()
	lvn.name = "lv"
	n.add_child(lvn)
	var lv: int = int(game.st_lvl.get(ch, 0))
	if lv <= 0:
		return
	var metal: StandardMaterial3D = _m(Color(0.62, 0.64, 0.72), 0.8, 0.3)
	var dark: StandardMaterial3D = _m(Color(0.2, 0.22, 0.28), 0.5, 0.5)
	for i in lv:
		_add(lvn, _sph(0.07, 8), _gold(1.6), Vector3(-0.2 + 0.2 * float(i), 0.16, 1.0), Vector3.ZERO, false)
	match ch:
		"O":
			var tk: StandardMaterial3D = _m(Color(0.6, 0.82, 1.0), 0.6, 0.3)
			_add(lvn, _cyl(0.32, 0.32, 1.1), tk, Vector3(1.25, 0.65, 0))
			_add(lvn, _sph(0.32, 12, true), tk, Vector3(1.25, 1.2, 0))
			_add(lvn, _cyl(0.06, 0.06, 0.8), metal, Vector3(0.9, 1.0, 0), Vector3(0, 0, PI / 2.0))
			if lv >= 2:
				_add(lvn, _cyl(0.32, 0.32, 1.1), tk, Vector3(-1.25, 0.65, 0))
				_add(lvn, _sph(0.32, 12, true), tk, Vector3(-1.25, 1.2, 0))
				_add(lvn, _cyl(0.06, 0.06, 0.8), metal, Vector3(-0.9, 1.0, 0), Vector3(0, 0, PI / 2.0))
				_add(lvn, _cyl(0.58, 0.58, 0.1), _gold(0.3), Vector3(0, 0.55, 0))
				_add(lvn, _cyl(0.58, 0.58, 0.1), _gold(0.3), Vector3(0, 1.75, 0))
			if lv >= 3:
				_add(lvn, _cyl(0.07, 0.07, 3.0), _gold(0.4), Vector3(0, 2.3, 0), Vector3(0, 0, PI / 2.0))
				_add(lvn, _tor(0.36, 0.5), _m(Color(0.4, 0.85, 1.0), 0.4, 0.3, 1.4), Vector3(0, 2.4, 0), Vector3.ZERO, false)
		"S":
			var pm := StandardMaterial3D.new()
			pm.albedo_texture = _panel_tex()
			pm.metallic = 0.6
			pm.roughness = 0.25
			_add(lvn, _cyl(0.07, 0.09, 1.3), metal, Vector3(1.55, 0.65, 0))
			_add(lvn, _box(Vector3(1.4, 0.07, 1.0)), pm, Vector3(1.55, 1.4, 0), Vector3(-0.55, 0, 0))
			if lv >= 2:
				_add(lvn, _cyl(0.07, 0.09, 1.3), metal, Vector3(-1.55, 0.65, 0))
				_add(lvn, _box(Vector3(1.4, 0.07, 1.0)), pm, Vector3(-1.55, 1.4, 0), Vector3(-0.55, 0, 0))
				_add(lvn, _box(Vector3(0.6, 0.5, 0.5)), dark, Vector3(0.0, 0.3, 0.85))
				_led(lvn, Vector3(0.0, 0.45, 1.12), Color(0.2, 1.0, 0.4), Color(0.05, 0.3, 0.1))
			if lv >= 3:
				_add(lvn, _sph(0.14, 10), _m(Color(0.5, 0.95, 1.0), 0.0, 0.3, 2.4), Vector3(0, 2.75, 0), Vector3.ZERO, false)
				_add(lvn, _tor(0.2, 0.28), _m(Color(0.5, 0.95, 1.0), 0.0, 0.3, 1.6), Vector3(0, 2.75, 0), Vector3.ZERO, false)
		"G":
			var pot: StandardMaterial3D = _m(Color(0.35, 0.25, 0.2), 0.0, 0.9)
			_add(lvn, _box(Vector3(0.8, 0.3, 0.8)), pot, Vector3(1.45, 0.15, 0))
			for i in 3:
				_add(lvn, _cyl(0.035, 0.04, 0.5), _m(Color(0.2, 0.55, 0.2), 0.0, 0.7), Vector3(1.25 + 0.2 * float(i), 0.55, 0.0))
				var lf: MeshInstance3D = _add(lvn, _sph(0.18, 8), _m(Color(0.25, 0.75, 0.3), 0.0, 0.7), Vector3(1.25 + 0.2 * float(i), 0.85, 0.0))
				lf.scale = Vector3(1.2, 0.6, 1.0)
			if lv >= 2:
				_add(lvn, _cyl(0.04, 0.04, 2.6), metal, Vector3(0, 2.0, 0), Vector3(0, 0, PI / 2.0))
				_add(lvn, _box(Vector3(2.2, 0.06, 0.25)), _m(Color(0.85, 0.35, 1.0), 0.0, 0.3, 1.8), Vector3(0, 1.94, 0), Vector3.ZERO, false)
				_add(lvn, _cyl(0.04, 0.04, 2.0), metal, Vector3(-1.2, 1.0, 0))
				_add(lvn, _cyl(0.04, 0.04, 2.0), metal, Vector3(1.2, 1.0, 0))
			if lv >= 3:
				_add(lvn, _tor(1.05, 1.12), _gold(0.5), Vector3(0, 0.45, 0), Vector3.ZERO, false)
				for i in 6:
					var a: float = TAU * float(i) / 6.0
					_add(lvn, _sph(0.07, 6), _m(Color(0.95, 0.25, 0.25), 0.0, 0.4, 0.6), Vector3(cos(a) * 0.5, 0.95, sin(a) * 0.5), Vector3.ZERO, false)
		"W":
			var wt: StandardMaterial3D = _m(Color(0.3, 0.6, 0.95, 0.75), 0.2, 0.2, 0.3)
			_add(lvn, _cyl(0.36, 0.36, 1.3), wt, Vector3(1.4, 0.75, 0), Vector3.ZERO, false)
			_add(lvn, _tor(0.34, 0.4), metal, Vector3(1.4, 1.4, 0), Vector3.ZERO, false)
			_add(lvn, _cyl(0.07, 0.07, 0.8), metal, Vector3(0.95, 0.9, 0), Vector3(0, 0, PI / 2.0))
			if lv >= 2:
				_add(lvn, _box(Vector3(0.5, 0.5, 0.5)), dark, Vector3(1.4, 0.25, 0.8))
				_add(lvn, _cyl(0.06, 0.06, 0.9), metal, Vector3(1.4, 0.55, 0.45), Vector3(PI / 2.0, 0, 0))
			if lv >= 3:
				for sz in [-0.3, 0.3]:
					_add(lvn, _cyl(0.1, 0.1, 1.5), _m(Color(0.75, 0.85, 0.9, 0.6), 0.3, 0.2), Vector3(-1.2, 0.8, sz), Vector3.ZERO, false)
					_add(lvn, _sph(0.11, 8), _m(Color(0.3, 1.0, 0.5), 0.0, 0.3, 2.0), Vector3(-1.2, 1.6, sz), Vector3.ZERO, false)
		"R":
			var pyl: StandardMaterial3D = _m(Color(0.5, 0.28, 0.75), 0.6, 0.3)
			for sd in [-1.0, 1.0]:
				_add(lvn, _cyl(0.07, 0.1, 1.7), pyl, Vector3(1.5 * sd, 0.85, 0.7))
				_add(lvn, _sph(0.14, 8), _m(Color(0.85, 0.65, 1.0), 0.0, 0.3, 2.0), Vector3(1.5 * sd, 1.8, 0.7), Vector3.ZERO, false)
			if lv >= 2:
				_add(lvn, _tor(0.8, 0.88), _m(Color(0.9, 0.7, 1.0), 0.5, 0.3, 0.9), Vector3(0, 1.2, 0), Vector3(PI / 2.0 + 0.3, 0, 0), false)
			if lv >= 3:
				_add(lvn, _tor(1.05, 1.15), _gold(1.0), Vector3(0, 1.2, 0), Vector3(PI / 2.0, 0, 0), false)
				_add(lvn, _sph(0.18, 10), _m(Color(1.0, 0.9, 0.4), 0.0, 0.3, 3.0), Vector3(0, 2.2, 0), Vector3.ZERO, false)
		"C":
			_add(lvn, _cyl(0.04, 0.05, 1.5), metal, Vector3(1.3, 0.75, -0.2))
			_add(lvn, _sph(0.2, 10), _m(Color(1.0, 0.9, 0.55), 0.0, 0.4, 1.8), Vector3(1.3, 1.6, -0.2), Vector3.ZERO, false)
			if lv >= 2:
				_add(lvn, _box(Vector3(2.4, 0.03, 1.6)), _m(Color(0.55, 0.3, 0.55), 0.0, 0.95), Vector3(0, 0.02, 0.5), Vector3.ZERO, false)
				_add(lvn, _cyl(0.2, 0.15, 0.35), _m(Color(0.7, 0.4, 0.3), 0.0, 0.8), Vector3(-1.35, 0.18, 0.1))
				_add(lvn, _sph(0.3, 10), _m(Color(0.25, 0.7, 0.3), 0.0, 0.7), Vector3(-1.35, 0.6, 0.1))
			if lv >= 3:
				for i in 9:
					var u: float = float(i) / 8.0
					var col: Color = Color(1.0, 0.85, 0.4) if i % 2 == 0 else Color(1.0, 0.5, 0.55)
					_add(lvn, _sph(0.06, 6), _m(col, 0.0, 0.4, 2.0), Vector3(-1.1 + 2.2 * u, 2.2 - 0.25 * sin(u * PI), 0.1), Vector3.ZERO, false)


func _build_scaffold(ch: String, n: Node3D) -> void:
	var sc := Node3D.new()
	sc.name = "scaf"
	n.add_child(sc)
	var yel: StandardMaterial3D = _m(Color(1.0, 0.8, 0.1), 0.2, 0.6, 0.3)
	for sx in [-1.2, 1.2]:
		for sz in [-1.0, 1.0]:
			_add(sc, _cyl(0.05, 0.05, 2.9), yel, Vector3(sx, 1.45, sz), Vector3.ZERO, false)
	for yy in [0.9, 1.9, 2.9]:
		_add(sc, _box(Vector3(2.5, 0.05, 0.05)), yel, Vector3(0, yy, 1.0), Vector3.ZERO, false)
		_add(sc, _box(Vector3(2.5, 0.05, 0.05)), yel, Vector3(0, yy, -1.0), Vector3.ZERO, false)
		_add(sc, _box(Vector3(0.05, 0.05, 2.1)), yel, Vector3(1.2, yy, 0), Vector3.ZERO, false)
		_add(sc, _box(Vector3(0.05, 0.05, 2.1)), yel, Vector3(-1.2, yy, 0), Vector3.ZERO, false)
	_add(sc, _box(Vector3(0.05, 3.1, 0.05)), yel, Vector3(0, 1.45, 1.0), Vector3(0, 0, 0.75), false)
	sc.visible = not game.build.is_empty() and str(game.build["ch"]) == ch
	scaf_nodes[ch] = sc


func set_build(ch: String) -> void:
	for k in scaf_nodes:
		scaf_nodes[k].visible = (k == ch)


func refresh_station(ch: String) -> void:
	if prop_nodes.has(ch):
		_build_lvl(ch, prop_nodes[ch])
	_build_base_ext_lv()
	if game.outside:
		fx_burst(_actor_pos(Vector2(float(game.BASE_X0 + 2) * game.TILE, float(game.BASE_Y0 + 2) * game.TILE)) + Vector3(0, 2.0, 0), Color(1.0, 0.85, 0.3), 24, 2.5, 3.0)
	elif npc_nodes.has("k"):
		fx_burst(npc_nodes["k"].position + Vector3(0, 1.8, 0), Color(1.0, 0.85, 0.3), 24, 2.5, 3.0)


func enoc_spark() -> void:
	if not npc_nodes.has("k"):
		return
	var n: Node3D = npc_nodes["k"]
	var fwd: Vector3 = Vector3(-sin(n.rotation.y), 0.0, -cos(n.rotation.y))
	fx_burst(n.position + fwd * 0.85 + Vector3(0, 1.1, 0), Color(1.0, 0.8, 0.3), 7, 1.4, 1.8)


# ---------- exterior ----------

func _tile_char(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= W or y >= H:
		return "#"
	var row: String = game.ext_rows[y]
	return row[x]


func _zd(zid: int, x: int, y: int) -> float:
	if zid <= 0:
		return 2.0
	var z: Dictionary = zs[zid]
	var dx: float = (float(x) + 0.5 - float(z["cx"])) / float(z["rx"])
	var dy: float = (float(y) + 0.5 - float(z["cy"])) / float(z["ry"])
	return dx * dx + dy * dy


func _tile_h(x: int, y: int) -> float:
	var ch: String = _tile_char(x, y)
	var zid: int = game._zone_at(x, y)
	var kind: String = "base"
	if zid > 0:
		kind = zs[zid]["kind"]
	var d: float = _zd(zid, x, y)
	var nz: float = game._hf(x, y, 91) - 0.5
	var base: float = 0.12 * sin(float(x) * 0.31) * cos(float(y) * 0.27) + nz * 0.14
	if x >= game.BASE_X0 - 7 and x < game.BASE_X0 + 14 and y >= game.BASE_Y0 - 6 and y < game.BASE_Y0 + 9:
		return base * 0.1
	if ch == "X":
		return -4.0 + nz * 0.4
	if ch == "#":
		var h: float = 2.2 + nz * 1.2
		if x == 0 or y == 0 or x == W - 1 or y == H - 1:
			h = 3.2 + nz
		elif kind == "mountain":
			h = 2.6 + 3.4 * clampf(1.0 - d / 0.35, 0.0, 1.0) + nz * 0.8
		elif kind == "volcano":
			h = 2.6 + 3.8 * clampf(1.0 - d / 0.55, 0.0, 1.0) + nz * 0.8
		elif kind == "crater" or kind == "valley":
			h = 1.7 + nz * 0.9
			if d < float(zs[zid].get("peak", 0.0)):
				h = 3.4 + nz
		return h
	var ch_h: float = 0.0
	if not crater_hf.is_empty():
		ch_h = crater_hf[y * W + x]
	match kind:
		"crater", "valley":
			if d < 0.72:
				base -= 0.55 * clampf((0.72 - d) / 0.4, 0.0, 1.0)
		"basin":
			base -= 0.4 * clampf(1.0 - d, 0.0, 1.0)
		"mountain", "volcano":
			base += 1.4 * clampf((1.0 - d) / 0.7, 0.0, 1.0)
	return base + ch_h


func ground_y(fx: float, fy: float) -> float:
	if heights.is_empty():
		return 0.0
	return Terrain3D.sample(heights, t_gw, t_sub, W, H, fx, fy)


# ---------- crateres del suelo (relieve + textura) ----------

func _make_craters() -> void:
	craters.clear()
	crater_hf = PackedFloat32Array()
	crater_hf.resize(W * H)
	var g := RandomNumberGenerator.new()
	g.seed = 9001
	var moon: bool = game.location == "Luna"
	var tries: int = 190 if moon else 95
	var rmax: float = 7.0 if moon else 5.5
	var bx0: float = float(game.BASE_X0) - 8.0
	var by0: float = float(game.BASE_Y0) - 7.0
	var bx1: float = float(game.BASE_X0) + 15.0
	var by1: float = float(game.BASE_Y0) + 10.0
	for i in tries:
		var r: float = 1.3 + pow(g.randf(), 2.2) * rmax
		var x: float = g.randf_range(3.0, float(W) - 3.0)
		var y: float = g.randf_range(3.0, float(H) - 3.0)
		if x > bx0 - r and x < bx1 + r and y > by0 - r and y < by1 + r:
			continue
		var ok: bool = true
		for k in 9:
			var px: float = x
			var py: float = y
			if k > 0:
				var an: float = TAU * float(k) / 8.0
				px = x + cos(an) * r * 0.95
				py = y + sin(an) * r * 0.95
			var ch: String = _tile_char(int(floor(px)), int(floor(py)))
			if ch == "#" or ch == "X" or ch == "H" or ch == "D" or ch == "L":
				ok = false
				break
		if not ok:
			continue
		for o in craters:
			var oc: Vector4 = o
			if Vector2(x, y).distance_to(Vector2(oc.x, oc.y)) < maxf(r, oc.z) * 0.95:
				ok = false
				break
		if not ok:
			continue
		craters.append(Vector4(x, y, r, clampf(r * 0.2, 0.2, 1.6)))
	# v28: crateres secundarios pequenos (mas en la Luna) y crateres "jovenes" con eyecciones claras.
	# El relieve ya no se suma por casilla: terrain3d.gd usa un perfil continuo (crater_hf queda vacio).
	var extra: int = 150 if moon else 40
	for i in extra:
		var r2: float = g.randf_range(0.9, 2.3) if moon else g.randf_range(0.9, 1.8)
		var x2: float = g.randf_range(3.0, float(W) - 3.0)
		var y2: float = g.randf_range(3.0, float(H) - 3.0)
		if x2 > bx0 - r2 and x2 < bx1 + r2 and y2 > by0 - r2 and y2 < by1 + r2:
			continue
		var ch2: String = _tile_char(int(floor(x2)), int(floor(y2)))
		if ch2 != ".":
			continue
		var ok2: bool = true
		for o in craters:
			var oc2: Vector4 = o
			if Vector2(x2, y2).distance_to(Vector2(oc2.x, oc2.y)) < (r2 + oc2.z) * 0.8:
				ok2 = false
				break
		if ok2:
			craters.append(Vector4(x2, y2, r2, clampf(r2 * 0.22, 0.18, 0.5)))
	young_craters.clear()
	if moon:
		for cr in craters:
			var c3: Vector4 = cr
			if c3.z > 2.2 and g.randf() < 0.3:
				young_craters.append(c3)
	# microcrateres: solo en la textura del suelo (normal map), no en la malla
	micro_craters.clear()
	for i in (700 if moon else 160):
		micro_craters.append(Vector4(g.randf_range(1.0, float(W) - 1.0), g.randf_range(1.0, float(H) - 1.0), g.randf_range(0.18, 0.6), 0.0))
	crater_hf = PackedFloat32Array()


func _apply_terrain_tex() -> void:
	if terrain_mat == null:
		return
	var m: StandardMaterial3D = terrain_mat
	var lv: int = clampi(int(game.tex_quality), 0, 2)
	if lv == 0:
		m.albedo_texture = null
		m.normal_enabled = false
		m.normal_texture = null
		m.detail_enabled = false
		return
	var ppt: int = 6 if lv == 1 else 10
	var tx: Array = ExtTex.make_ground(craters + micro_craters, W, H, ppt, lv == 2, 7.0)
	m.albedo_texture = tx[0]
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var gr: Array = ExtTex.make_grain(128 if lv == 1 else 256)
	m.detail_enabled = true
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = gr[0]
	if lv == 2:
		m.normal_enabled = true
		m.normal_texture = tx[1]
		m.normal_scale = 1.0
		m.detail_normal = gr[1]
	else:
		m.normal_enabled = false
		m.normal_texture = null
		m.detail_normal = null


func _tile_color(x: int, y: int) -> Color:
	var ch: String = _tile_char(x, y)
	var zid: int = game._zone_at(x, y)
	var ground: Color = game.zone_ground[zid]
	var rock: Color = game.zone_rock[zid]
	var sh: float = 1.0 + (game._hf(x, y, 3) - 0.5) * 0.2
	var c: Color = Color(ground.r * sh, ground.g * sh, ground.b * sh)
	if ch == "#":
		c = rock.lerp(ground, 0.15)
		c = Color(c.r * (0.9 + sh * 0.1), c.g * (0.9 + sh * 0.1), c.b * (0.9 + sh * 0.1))
	elif ch == "X":
		c = Color(0.2, 0.1, 0.08)
	if game.location == "Luna":
		c = Color(c.r * 0.6, c.g * 0.6, c.b * 0.57)
	return WorldLook.grade_ground(c, game.location)


func _build_terrain(parent: Node3D) -> void:
	# v28: malla subdividida y por bloques (terrain3d.gd). Calidad baja: 1 vertice por casilla.
	var th := PackedFloat32Array()
	th.resize(W * H)
	var tc: Array = []
	tc.resize(W * H)
	for y in H:
		for x in W:
			th[y * W + x] = _tile_h(x, y)
			tc[y * W + x] = _tile_color(x, y)
	var sub: int = 1 if clampi(int(game.tex_quality), 0, 2) == 0 else 2
	var base_rect := Rect2(float(game.BASE_X0) - 7.0, float(game.BASE_Y0) - 6.0, 21.0, 15.0)
	var r: Dictionary = Terrain3D.build(W, H, th, tc, craters, game.ext_rows, game.location == "Luna", base_rect, sub, young_craters)
	heights = r["heights"]
	t_sub = int(r["sub"])
	t_gw = int(r["gw"])
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.roughness = 0.97 if game.location == "Luna" else 0.92
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var holder := Node3D.new()
	holder.name = "Terreno"
	parent.add_child(holder)
	for m in r["meshes"]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = tm
		holder.add_child(mi)
	terrain_mat = tm
	_apply_terrain_tex()


func _build_exterior() -> void:
	ext_mats.clear()
	exterior = Node3D.new()
	add_child(exterior)
	_make_craters()
	_build_terrain(exterior)
	var g := RandomNumberGenerator.new()
	g.seed = 4242
	var lists: Dictionary = {"r": [], "m": [], "i": [], "c": [], "L": []}
	for y in H:
		var row: String = game.ext_rows[y]
		for x in W:
			var ch: String = row[x]
			if lists.has(ch):
				lists[ch].append(Vector2i(x, y))
	# rocas grandes
	var rocks: Array = lists["r"]
	var lvm: int = clampi(int(game.tex_quality), 0, 2)
	var rock_seg: int = [8, 10, 12][lvm]
	var moon_w: bool = game.location == "Luna"
	var mm_r: ChunkMM = _make_mm_c(exterior, Terrain3D.rock_mesh(1, moon_w, rock_seg), _ext_mat("rock", 0.0, 0.93), rocks, 1)
	for i in rocks.size():
		var p: Vector2i = rocks[i]
		var zc: Color = game.zone_rock[game._zone_at(p.x, p.y)]
		var s: float = g.randf_range(0.6, 1.0)
		var pos: Vector3 = _tp(p.x, p.y, ground_y(float(p.x) + 0.5, float(p.y) + 0.5) + 0.18 * s)
		mm_r.set_xf(i, _xf(pos, g.randf() * TAU, Vector3(s * 1.1, s * 0.85, s)))
		var sh: float = g.randf_range(0.85, 1.15)
		mm_r.set_col(i, Color(zc.r * sh, zc.g * sh, zc.b * sh))
	# vetas de metal: roca oscura + trozos metalicos
	var metals: Array = lists["m"]
	if _place_glb_nodes("material_scrap", float(MAT_SIZE["scrap"]), metals, 0.0, g):
		metals = []
	var mm_mr: ChunkMM = _make_mm_c(exterior, Terrain3D.rock_mesh(2, moon_w, rock_seg), _ext_mat("rock", 0.0, 0.93), metals, 1)
	var mm_mm: ChunkMM = _make_mm_c(exterior, ExtTex.lumpy_mesh(6, 0.22, 3), _ext_mat("ore", 0.55, 0.5), metals, 3)
	for i in metals.size():
		var p2: Vector2i = metals[i]
		var gy: float = ground_y(float(p2.x) + 0.5, float(p2.y) + 0.5)
		var zr: Color = game.zone_rock[game._zone_at(p2.x, p2.y)].darkened(0.3)
		var xr: Transform3D = _xf(_tp(p2.x, p2.y, gy + 0.3), g.randf() * TAU, Vector3(0.95, 0.7, 0.85))
		mm_mr.set_xf(i, xr)
		mm_mr.set_col(i, zr)
		var parts: Array = [[mm_mr, i, xr]]
		for j in 3:
			var off := Vector3(g.randf_range(-0.5, 0.5), g.randf_range(0.2, 0.7), g.randf_range(-0.5, 0.5))
			var s2: float = g.randf_range(0.18, 0.34)
			var xm: Transform3D = _xf(_tp(p2.x, p2.y, gy) + off + Vector3(0, 0.3, 0), g.randf() * TAU, Vector3(s2, s2 * 1.4, s2))
			mm_mm.set_xf(i * 3 + j, xm)
			mm_mm.set_col(i * 3 + j, Color(0.82, 0.88, 1.0))
			parts.append([mm_mm, i * 3 + j, xm])
		node_data.append({"x": p2.x, "y": p2.y, "hidden": false, "parts": parts})
	# hielo: cristales
	ice_pts = PackedVector3Array()
	var ices: Array = lists["i"]
	if _place_glb_nodes("material_ice", float(MAT_SIZE["ice"]), ices, 0.0, g):
		ices = []
	var mm_i: ChunkMM = _make_mm_c(exterior, ExtTex.crystal_mesh(), _ext_mat("ice", 0.0, 0.1, true), ices, 3)
	for i in ices.size():
		var p3: Vector2i = ices[i]
		var gy3: float = ground_y(float(p3.x) + 0.5, float(p3.y) + 0.5)
		var parts3: Array = []
		for j in 3:
			var hgt: float = g.randf_range(0.9, 1.7)
			var off3 := Vector3(g.randf_range(-0.55, 0.55), hgt / 2.0 - 0.1, g.randf_range(-0.55, 0.55))
			var xi: Transform3D = Transform3D(Basis.from_euler(Vector3(g.randf_range(-0.3, 0.3), g.randf() * TAU, g.randf_range(-0.3, 0.3))) * Basis.from_scale(Vector3(0.62, hgt, 0.62)), _tp(p3.x, p3.y, gy3) + off3)
			mm_i.set_xf(i * 3 + j, xi)
			mm_i.set_col(i * 3 + j, Color(0.72, 0.92, 1.0, 0.82))
			ice_pts.append(xi.origin + Vector3(0, hgt * 0.45, 0))
			parts3.append([mm_i, i * 3 + j, xi])
		node_data.append({"x": p3.x, "y": p3.y, "hidden": false, "parts": parts3})
	# cargamento: cajas
	var crates: Array = lists["c"]
	if _place_glb_nodes("material_crate", float(MAT_SIZE["crate"]), crates, 0.0, g):
		crates = []
	beacon_mat = StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(1.0, 0.2, 0.15)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.2, 0.15)
	beacon_mat.emission_energy_multiplier = 2.0
	var mm_c: ChunkMM = _make_mm_c(exterior, _box(Vector3(1.2, 0.95, 1.2)), _ext_mat("crate", 0.25, 0.5), crates, 1)
	var mm_b: ChunkMM = _make_mm_c(exterior, _box(Vector3(1.26, 0.16, 1.26)), _mm_mat(0.5, 0.4), crates, 1)
	var mm_l: ChunkMM = _make_mm_c(exterior, _sph(0.1, 6), beacon_mat, crates, 1, false)
	for i in crates.size():
		var p4: Vector2i = crates[i]
		var gy4: float = ground_y(float(p4.x) + 0.5, float(p4.y) + 0.5)
		var yaw: float = g.randf() * TAU
		var xc: Transform3D = _xf(_tp(p4.x, p4.y, gy4 + 0.45), yaw, Vector3.ONE)
		var xb: Transform3D = _xf(_tp(p4.x, p4.y, gy4 + 0.5), yaw, Vector3.ONE)
		var xl: Transform3D = Transform3D(Basis.IDENTITY, _tp(p4.x, p4.y, gy4 + 1.05) + Basis(Vector3.UP, yaw) * Vector3(0.45, 0, 0.45))
		mm_c.set_xf(i, xc)
		mm_c.set_col(i, Color(0.5, 0.54, 0.43))      # v33: verde oliva (referencia de arte)
		mm_b.set_xf(i, xb)
		mm_b.set_col(i, Color(0.24, 0.24, 0.25))
		mm_l.set_xf(i, xl)
		mm_l.set_col(i, Color.WHITE)
		node_data.append({"x": p4.x, "y": p4.y, "hidden": false, "parts": [[mm_c, i, xc], [mm_b, i, xb], [mm_l, i, xl]]})
	# guijarros decorativos
	var pebbles: Array = []
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if _tile_char(x, y) == "." and g.randf() < 0.2 * float(game.FX_FACTOR[clampi(int(game.fx_idx), 0, 2)]):
				pebbles.append(Vector2i(x, y))
	var mm_p: ChunkMM = _make_mm_c(exterior, ExtTex.lumpy_mesh(6, 0.3, 4), _ext_mat("rock", 0.0, 1.0), pebbles, 1, false)
	for i in pebbles.size():
		var p5: Vector2i = pebbles[i]
		var fx: float = float(p5.x) + g.randf()
		var fy: float = float(p5.y) + g.randf()
		var s5: float = g.randf_range(0.08, 0.22)
		var zr5: Color = game.zone_rock[game._zone_at(p5.x, p5.y)]
		mm_p.set_xf(i, _xf(Vector3(fx * T3, ground_y(fx, fy) + s5 * 0.4, fy * T3), g.randf() * TAU, Vector3(s5 * 1.3, s5 * 0.7, s5)))
		mm_p.set_col(i, Color(zr5.r * 1.1, zr5.g * 1.1, zr5.b * 1.1))
	_scatter_boulders(g)
	# placas / monumentos
	for p6 in lists["L"]:
		var zid: int = game._zone_at(p6.x, p6.y)
		var lm: String = zs[zid]["lm"]
		var model: Node3D = _make_landmark(lm)
		model.position = _tp(p6.x, p6.y, ground_y(float(p6.x) + 0.5, float(p6.y) + 0.5))
		exterior.add_child(model)
	_build_base_exterior()
	wfx = Node3D.new()
	wfx.set_script(load("res://world_fx.gd"))
	add_child(wfx)
	wfx.call("setup", self, game.location == "Luna", ice_pts)
	apply_textures()
	apply_gfx()
	refresh_nodes()


func _scatter_boulders(g: RandomNumberGenerator) -> void:
	# v28: bloques sueltos decorativos (sin colision). Luna: sobre todo en los bordes de los crateres
	# (material expulsado por el impacto); Marte: piedras planas dispersas. Cantidad segun "Efectos".
	var moon: bool = game.location == "Luna"
	var k: float = float(game.FX_FACTOR[clampi(int(game.fx_idx), 0, 2)])
	var spots: Array = []   # [fx, fy, escala]
	if moon:
		for cr in craters:
			var c: Vector4 = cr
			if c.z < 1.6:
				continue
			var n: int = int(c.z * 2.2 * k)
			for i in n:
				var an: float = g.randf() * TAU
				var rr: float = c.z * g.randf_range(0.95, 1.5)
				spots.append([c.x + cos(an) * rr, c.y + sin(an) * rr, g.randf_range(0.12, 0.34) * (1.0 + c.z * 0.05)])
	var n2: int = int((260.0 if moon else 420.0) * k)
	for i in n2:
		spots.append([g.randf_range(2.0, float(W) - 2.0), g.randf_range(2.0, float(H) - 2.0), g.randf_range(0.1, 0.3)])
	var tiles: Array = []
	var keep: Array = []
	var bx0: float = float(game.BASE_X0) - 5.0
	var bx1: float = float(game.BASE_X0) + 12.0
	var by0: float = float(game.BASE_Y0) - 4.0
	var by1: float = float(game.BASE_Y0) + 8.0
	for sp in spots:
		var fx: float = sp[0]
		var fy: float = sp[1]
		if fx > bx0 and fx < bx1 and fy > by0 and fy < by1:
			continue
		var ch: String = _tile_char(int(fx), int(fy))
		if ch != "." and ch != "#":
			continue
		tiles.append(Vector2i(int(fx), int(fy)))
		keep.append(sp)
	if tiles.is_empty():
		return
	var mm: ChunkMM = _make_mm_c(exterior, Terrain3D.rock_mesh(7, moon, 8), _ext_mat("rock", 0.0, 0.95), tiles, 1, false)
	for i in keep.size():
		var sp2: Array = keep[i]
		var fx2: float = sp2[0]
		var fy2: float = sp2[1]
		var s2: float = sp2[2]
		var zr: Color = game.zone_rock[game._zone_at(int(fx2), int(fy2))]
		var sh: float = g.randf_range(0.8, 1.1)
		mm.set_xf(i, _xf(Vector3(fx2 * T3, ground_y(fx2, fy2) + s2 * 0.12, fy2 * T3), g.randf() * TAU, Vector3(s2 * 1.2, s2 * 0.9, s2)))
		mm.set_col(i, Color(zr.r * sh, zr.g * sh, zr.b * sh))


func refresh_nodes() -> void:
	for nd in node_data:
		var dep: bool = game._is_depleted(nd["x"], nd["y"]) and game.fx_hold_node != game._node_key(nd["x"], nd["y"])
		if dep != nd["hidden"]:
			nd["hidden"] = dep
			for part in nd["parts"]:
				var cmm: ChunkMM = part[0]
				cmm.set_xf(part[1], HIDDEN if dep else part[2])


func _make_landmark(lm: String) -> Node3D:
	var n := Node3D.new()
	var metal: StandardMaterial3D = _m(Color(0.7, 0.72, 0.8), 0.8, 0.3)
	match lm:
		"apollo":
			var gold: StandardMaterial3D = _m(Color(0.92, 0.74, 0.25), 0.9, 0.28)
			_add(n, _cyl(1.2, 1.4, 1.1, 8), gold, Vector3(0, 1.6, 0))
			_add(n, _cyl(0.9, 1.2, 0.5, 8), _m(Color(0.75, 0.78, 0.85), 0.8, 0.35), Vector3(0, 2.4, 0))
			_add(n, _box(Vector3(0.7, 0.4, 0.15)), _m(Color(0.05, 0.1, 0.2), 0.9, 0.1), Vector3(0, 1.8, -1.28))
			for i in 4:
				var a: float = TAU * float(i) / 4.0 + PI / 4.0
				var dx: float = cos(a)
				var dz: float = sin(a)
				var leg: MeshInstance3D = _add(n, _cyl(0.05, 0.06, 1.7), metal, Vector3(dx * 1.45, 0.9, dz * 1.45))
				leg.rotation = Vector3(dz * 0.45, 0, -dx * 0.45)
				_add(n, _cyl(0.32, 0.32, 0.06), metal, Vector3(dx * 1.8, 0.04, dz * 1.8))
			_add(n, _cyl(0.03, 0.03, 1.2), metal, Vector3(0, 3.3, 0))
			_add(n, _cyl(0.03, 0.03, 3.4), _m(Color(0.9, 0.9, 0.9), 0.4, 0.5), Vector3(2.8, 1.7, 0.6))
			_add(n, _box(Vector3(1.3, 0.8, 0.03)), _m(Color(0.95, 0.95, 0.95), 0.0, 0.9), Vector3(3.45, 3.0, 0.6))
		"rover":
			var white: StandardMaterial3D = _m(Color(0.9, 0.9, 0.94), 0.3, 0.5)
			var tire: StandardMaterial3D = _m(Color(0.15, 0.15, 0.18), 0.2, 0.8)
			_add(n, _box(Vector3(2.0, 0.55, 1.3)), white, Vector3(0, 1.0, 0))
			_add(n, _box(Vector3(1.4, 0.1, 1.0)), _m(Color(0.1, 0.2, 0.55), 0.6, 0.3), Vector3(-0.2, 1.33, 0))
			for sx in [-0.8, 0.0, 0.8]:
				for sz in [-0.8, 0.8]:
					_add(n, _cyl(0.32, 0.32, 0.22, 14), tire, Vector3(sx, 0.34, sz), Vector3(PI / 2.0, 0, 0))
			_add(n, _cyl(0.05, 0.05, 1.3), metal, Vector3(0.7, 1.9, -0.2))
			_add(n, _box(Vector3(0.5, 0.25, 0.3)), _m(Color(0.25, 0.3, 0.4), 0.6, 0.3), Vector3(0.7, 2.6, -0.2))
			_add(n, _sph(0.07, 8), _m(Color(0.4, 0.9, 1.0), 0.0, 0.3, 2.0), Vector3(0.7, 2.62, -0.37), Vector3.ZERO, false)
			var arm: MeshInstance3D = _add(n, _cyl(0.05, 0.05, 1.0), metal, Vector3(-1.2, 0.9, 0.0))
			arm.rotation = Vector3(0, 0, 0.9)
		"plaque":
			_add(n, _box(Vector3(1.1, 0.12, 0.7)), _m(Color(0.3, 0.32, 0.4), 0.5, 0.5), Vector3(0, 0.06, 0))
			_add(n, _box(Vector3(0.9, 2.1, 0.28)), _m(Color(0.52, 0.55, 0.66), 0.7, 0.35), Vector3(0, 1.1, 0))
			_add(n, _box(Vector3(0.62, 0.05, 0.02)), _m(Color(0.1, 0.12, 0.2), 0.0, 0.5), Vector3(0, 1.5, -0.15), Vector3.ZERO, false)
			_add(n, _box(Vector3(0.62, 0.05, 0.02)), _m(Color(0.1, 0.12, 0.2), 0.0, 0.5), Vector3(0, 1.2, -0.15), Vector3.ZERO, false)
			_add(n, _box(Vector3(0.62, 0.05, 0.02)), _m(Color(0.1, 0.12, 0.2), 0.0, 0.5), Vector3(0, 0.9, -0.15), Vector3.ZERO, false)
			_add(n, _sph(0.2, 10), _m(Color(0.3, 0.9, 1.0), 0.0, 0.3, 2.4), Vector3(0, 2.4, 0), Vector3.ZERO, false)
			_add(n, _tor(0.85, 0.95), _m(Color(0.3, 0.9, 1.0, 0.6), 0.0, 0.5, 1.6), Vector3(0, 0.08, 0), Vector3.ZERO, false)
		"wreck":
			var burnt: StandardMaterial3D = _m(Color(0.62, 0.38, 0.2), 0.6, 0.55)
			var gray: StandardMaterial3D = _m(Color(0.55, 0.57, 0.64), 0.7, 0.4)
			var p1: MeshInstance3D = _add(n, _box(Vector3(2.4, 0.15, 1.5)), burnt, Vector3(-0.4, 0.6, 0.2))
			p1.rotation = Vector3(0.35, 0.5, 0.2)
			var p2: MeshInstance3D = _add(n, _box(Vector3(1.8, 0.15, 1.2)), gray, Vector3(1.2, 0.5, -0.6))
			p2.rotation = Vector3(-0.3, -0.4, 0.5)
			var tank: MeshInstance3D = _add(n, _cyl(0.55, 0.55, 2.2), gray, Vector3(-0.8, 0.5, -0.9), Vector3(0.0, 0.6, PI / 2.0))
			tank.rotation = Vector3(0.1, 0.6, PI / 2.0)
			_add(n, _cyl(0.04, 0.04, 1.6), metal, Vector3(0.4, 1.2, 0.6), Vector3(0.3, 0, 0.6))
			_add(n, _sph(0.15, 8), _m(Color(1.0, 0.5, 0.1), 0.0, 0.4, 2.2), Vector3(-0.1, 0.9, 0.2), Vector3.ZERO, false)
	return n


func _build_base_exterior() -> void:
	var T: float = T3
	var bx: float = float(game.BASE_X0)
	var by: float = float(game.BASE_Y0)
	var x0: float = (bx - 3.0) * T
	var x1: float = (bx + 7.0) * T
	var z0: float = (by - 1.0) * T
	var z1: float = (by + 3.0) * T
	var cx: float = (x0 + x1) * 0.5
	var cz: float = (z0 + z1) * 0.5
	var W2: float = x1 - x0
	var D2: float = z1 - z0
	# v28: casco blanco calido con paneles (textura procedural), grafito y acentos ambar
	hull_mats.clear()
	var hull: StandardMaterial3D = BaseLook.hull_mat(Color(0.8, 0.81, 0.82), 0.35, 0.5)
	var hull2: StandardMaterial3D = BaseLook.hull_mat(Color(0.36, 0.39, 0.44), 0.45, 0.45)
	hull_mats.append(hull)
	hull_mats.append(hull2)
	var dark: StandardMaterial3D = _m(Color(0.2, 0.22, 0.27), 0.55, 0.45)
	var trim: StandardMaterial3D = _m(Color(0.86, 0.87, 0.88), 0.5, 0.35)
	# cimientos y casco por capas
	_add(exterior, _box(Vector3(W2 + 0.8, 0.35, D2 + 0.8)), dark, Vector3(cx, 0.17, cz))
	_add(exterior, _box(Vector3(W2, 2.7, D2)), hull, Vector3(cx, 1.7, cz))
	_add(exterior, _box(Vector3(W2 + 0.08, 0.7, D2 + 0.08)), hull2, Vector3(cx, 0.75, cz))
	_add(exterior, _box(Vector3(W2 + 0.3, 0.16, D2 + 0.3)), trim, Vector3(cx, 3.12, cz))
	_add(exterior, _box(Vector3(W2 - 0.8, 0.1, D2 - 0.8)), _m(Color(0.5, 0.54, 0.64), 0.6, 0.4), Vector3(cx, 3.25, cz))
	# nervaduras verticales
	for i in 11:
		var rx: float = x0 + float(i) * W2 / 10.0
		_add(exterior, _box(Vector3(0.12, 2.6, 0.12)), hull2, Vector3(rx, 1.7, z1 + 0.04), Vector3.ZERO, false)
		_add(exterior, _box(Vector3(0.12, 2.6, 0.12)), hull2, Vector3(rx, 1.7, z0 - 0.04), Vector3.ZERO, false)
	# barandilla del techo
	var rail: StandardMaterial3D = _m(Color(0.78, 0.62, 0.24), 0.4, 0.5)
	for zz in [z0 + 0.5, z1 - 0.5]:
		_add(exterior, _box(Vector3(W2 - 1.0, 0.07, 0.07)), rail, Vector3(cx, 3.8, zz), Vector3.ZERO, false)
	for k in 9:
		var px2: float = x0 + 0.5 + float(k) * (W2 - 1.0) / 8.0
		for zz in [z0 + 0.5, z1 - 0.5]:
			_add(exterior, _cyl(0.035, 0.035, 0.55), rail, Vector3(px2, 3.5, zz), Vector3.ZERO, false)
	# ventanas
	var wm: StandardMaterial3D = _m(Color(1.0, 0.88, 0.62), 0.0, 0.4, 0.75)
	var wm2: StandardMaterial3D = _m(Color(0.62, 0.78, 0.92), 0.0, 0.4, 0.55)
	var ax: float = (bx + 2.5) * T
	var az: float = z1
	for i in 9:
		var wx: float = x0 + 1.2 + float(i) * (W2 - 2.4) / 8.0
		if absf(wx - ax) > 2.0:
			_add(exterior, _box(Vector3(1.4, 0.95, 0.1)), dark, Vector3(wx, 1.9, z1 + 0.05), Vector3.ZERO, false)
			_add(exterior, _box(Vector3(1.2, 0.75, 0.06)), wm if i % 3 != 1 else wm2, Vector3(wx, 1.9, z1 + 0.09), Vector3.ZERO, false)
		_add(exterior, _box(Vector3(1.4, 0.95, 0.1)), dark, Vector3(wx, 1.9, z0 - 0.05), Vector3.ZERO, false)
		_add(exterior, _box(Vector3(1.2, 0.75, 0.06)), wm2, Vector3(wx, 1.9, z0 - 0.09), Vector3.ZERO, false)
	# modulos laterales (habitaculos cilindricos)
	var modm: StandardMaterial3D = BaseLook.hull_mat(Color(0.82, 0.83, 0.84), 0.35, 0.45)
	hull_mats.append(modm)
	for sd in [-1.0, 1.0]:
		var mx: float = cx + sd * (W2 * 0.5 + 1.0)
		_add(exterior, _cyl(1.7, 1.7, 2.0), modm, Vector3(mx, 1.7, cz), Vector3(0, 0, PI / 2.0))
		_add(exterior, _sph(1.7, 14, true), modm, Vector3(mx + sd * 1.0, 1.7, cz), Vector3(0, 0, -sd * PI / 2.0))
		_add(exterior, _tor(1.62, 1.78), dark, Vector3(mx, 1.7, cz), Vector3(0, 0, PI / 2.0), false)
		_add(exterior, _box(Vector3(0.1, 0.8, 1.0)), wm2, Vector3(mx + sd * 1.2, 2.0, cz), Vector3.ZERO, false)
	# cupula central
	var dome: MeshInstance3D = _add(exterior, _sph(3.7, 24, true), _m(Color(0.7, 0.9, 1.0, 0.42), 0.1, 0.08), Vector3(cx, 3.3, cz), Vector3.ZERO, false)
	dome.scale = Vector3(1.0, 0.75, 0.9)
	_add(exterior, _tor(3.6, 3.82), dark, Vector3(cx, 3.32, cz), Vector3.ZERO, false)
	for a in 3:
		var rb: MeshInstance3D = _add(exterior, _tor(3.55, 3.62), trim, Vector3(cx, 3.3, cz), Vector3(PI / 2.0, 0, float(a) * PI / 3.0), false)
		rb.scale = Vector3(1.0, 1.0, 0.75)
	_add(exterior, _sph(0.35, 10), _m(Color(0.7, 0.95, 1.0), 0.0, 0.3, 1.8), Vector3(cx, 3.5, cz), Vector3.ZERO, false)
	# esclusa con marquesina
	_add(exterior, _box(Vector3(3.0, 3.1, 1.3)), dark, Vector3(ax, 1.55, az + 0.5))
	_add(exterior, _box(Vector3(1.6, 2.3, 0.12)), _m(Color(0.14, 0.16, 0.22), 0.6, 0.4), Vector3(ax, 1.15, az + 1.16))
	for i in 4:
		_add(exterior, _box(Vector3(1.6, 0.18, 0.14)), _m(Color(0.82, 0.64, 0.2), 0.2, 0.55), Vector3(ax, 0.4 + float(i) * 0.55, az + 1.2), Vector3.ZERO, false)
	_add(exterior, _box(Vector3(3.8, 0.16, 2.0)), _m(Color(0.8, 0.64, 0.24), 0.4, 0.45), Vector3(ax, 3.2, az + 0.9))
	for sx in [-1.7, 1.7]:
		_add(exterior, _cyl(0.07, 0.07, 3.1), rail, Vector3(ax + sx, 1.55, az + 1.8))
	_led(exterior, Vector3(ax, 2.75, az + 1.25), Color(0.2, 1.0, 0.4), Color(0.05, 0.3, 0.1))
	# balizas del camino a la esclusa
	for i in 4:
		for sx in [-1.4, 1.4]:
			_add(exterior, _box(Vector3(0.14, 0.08, 0.14)), _m(Color(1.0, 0.85, 0.55), 0.0, 0.4, 0.9), Vector3(ax + sx, 0.05, az + 2.2 + float(i) * 1.6), Vector3.ZERO, false)
	# antenas
	_add(exterior, _cyl(0.06, 0.08, 4.2), _m(Color(0.8, 0.8, 0.86), 0.7, 0.3), Vector3(x0 + 1.0, 5.2, z0 + 1.2))
	_led(exterior, Vector3(x0 + 1.0, 7.4, z0 + 1.2), Color(1.0, 0.15, 0.1), Color(0.3, 0.03, 0.02))
	var dish: MeshInstance3D = _add(exterior, _sph(0.8, 14, true), _m(Color(0.9, 0.9, 0.95), 0.6, 0.3), Vector3(x1 - 2.0, 3.9, z0 + 1.6), Vector3(-0.8, 0.4, 0), false)
	dish.scale = Vector3(1.0, 0.5, 1.0)
	_add(exterior, _cyl(0.07, 0.1, 0.8), dark, Vector3(x1 - 2.0, 3.5, z0 + 1.6))
	BaseLook.build_details(self, exterior, bx, by, game.location == "Luna")
	_build_base_ext_lv()


func _build_base_ext_lv() -> void:
	# piezas que cambian con el nivel de cada estacion
	if ext_lv != null and is_instance_valid(ext_lv):
		ext_lv.queue_free()
	ext_lv = Node3D.new()
	exterior.add_child(ext_lv)
	var T: float = T3
	var bx: float = float(game.BASE_X0)
	var by: float = float(game.BASE_Y0)
	var metal: StandardMaterial3D = _m(Color(0.72, 0.75, 0.82), 0.8, 0.3)
	var dark: StandardMaterial3D = _m(Color(0.22, 0.25, 0.33), 0.6, 0.4)
	var L: Dictionary = game.st_lvl
	# paneles solares: 2 de base + 2 por nivel
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = _panel_tex()
	pm.metallic = 0.6
	pm.roughness = 0.25
	var np: int = 2 + 2 * int(L["S"])
	for i in np:
		var px: float = (bx - 2.0 + float(i) * 1.25 + 0.5) * T
		var pz: float = (by - 3.0 + 0.5) * T
		_add(ext_lv, _cyl(0.08, 0.1, 1.3), dark, Vector3(px, 0.65, pz))
		_add(ext_lv, _box(Vector3(2.1, 0.08, 1.7)), pm, Vector3(px, 1.45, pz), Vector3(-0.5, 0, 0))
	if int(L["S"]) >= 3:
		_add(ext_lv, _sph(0.2, 8), _m(Color(0.5, 0.95, 1.0), 0.0, 0.3, 2.4), Vector3((bx + 0.5) * T, 2.4, (by - 3.0 + 0.5) * T - 1.4), Vector3.ZERO, false)
	# tanques de oxigeno (oeste)
	var tk: StandardMaterial3D = _m(Color(0.6, 0.82, 1.0), 0.6, 0.3)
	for i in int(L["O"]):
		var tx: float = (bx - 5.5) * T
		var tz: float = (by - 0.6 + float(i) * 1.2 + 0.5) * T
		_add(ext_lv, _cyl(0.75, 0.75, 2.6), tk, Vector3(tx, 0.95, tz), Vector3(0, 0, PI / 2.0))
		_add(ext_lv, _sph(0.75, 12, true), tk, Vector3(tx + 1.3, 0.95, tz), Vector3(0, 0, -PI / 2.0))
		_add(ext_lv, _sph(0.75, 12, true), tk, Vector3(tx - 1.3, 0.95, tz), Vector3(0, 0, PI / 2.0))
		_add(ext_lv, _cyl(0.78, 0.78, 0.3), _m(Color(0.15, 0.4, 0.8), 0.3, 0.45), Vector3(tx, 0.95, tz), Vector3(0, 0, PI / 2.0))
		_add(ext_lv, _cyl(0.1, 0.1, 2.0), metal, Vector3(tx + 2.3, 0.6, tz), Vector3(0, 0, PI / 2.0))
	# invernadero en el techo
	var gl: int = int(L["G"])
	if gl > 0:
		var gx: float = (bx + 5.0) * T
		var gz: float = (by - 0.1) * T
		var gr: float = 0.9 + 0.55 * float(gl)
		var gd: MeshInstance3D = _add(ext_lv, _sph(gr, 18, true), _m(Color(0.6, 1.0, 0.8, 0.35), 0.1, 0.1), Vector3(gx, 3.35, gz), Vector3.ZERO, false)
		gd.scale = Vector3(1.4, 0.9, 1.0)
		_add(ext_lv, _tor(gr * 1.4 - 0.03, gr * 1.4 + 0.05), metal, Vector3(gx, 3.37, gz), Vector3.ZERO, false)
		for i in gl + 2:
			var a: float = TAU * float(i) / float(gl + 2)
			_add(ext_lv, _sph(0.2, 8), _m(Color(0.25, 0.75, 0.3), 0.0, 0.7), Vector3(gx + cos(a) * gr * 0.6, 3.6, gz + sin(a) * gr * 0.5), Vector3.ZERO, false)
	# torre de agua (este)
	for i in int(L["W"]):
		var wx: float = (bx + 8.8 + float(i) * 1.3 + 0.5) * T
		var wz: float = (by - 0.6 + 0.5) * T
		for sx in [-0.6, 0.6]:
			for sz in [-0.6, 0.6]:
				_add(ext_lv, _cyl(0.06, 0.08, 2.2), metal, Vector3(wx + sx, 1.1, wz + sz))
		_add(ext_lv, _cyl(0.9, 0.9, 1.5), _m(Color(0.3, 0.6, 0.95, 0.85), 0.3, 0.2, 0.25), Vector3(wx, 2.9, wz))
		_add(ext_lv, _sph(0.9, 12, true), _m(Color(0.3, 0.6, 0.95), 0.3, 0.2, 0.25), Vector3(wx, 3.65, wz))
		_add(ext_lv, _tor(0.88, 0.96), metal, Vector3(wx, 2.9, wz), Vector3.ZERO, false)
	# pilonas del escudo
	var rl: int = int(L["R"])
	if rl > 0:
		var pyl: Array = [Vector2(bx - 4.2, by - 2.0), Vector2(bx + 7.2, by - 2.0)]
		if rl >= 2:
			pyl.append(Vector2(bx - 4.2, by + 3.4))
			pyl.append(Vector2(bx + 7.2, by + 3.4))
		for pv in pyl:
			var rp: Vector3 = Vector3(((pv as Vector2).x + 0.5) * T, 0.0, ((pv as Vector2).y + 0.5) * T)
			_add(ext_lv, _cyl(0.14, 0.22, 4.0), _m(Color(0.5, 0.28, 0.75), 0.6, 0.3), rp + Vector3(0, 2.0, 0))
			_add(ext_lv, _sph(0.32, 10), _m(Color(0.85, 0.65, 1.0), 0.0, 0.3, 2.2), rp + Vector3(0, 4.2, 0), Vector3.ZERO, false)
		if rl >= 3:
			var sr: MeshInstance3D = _add(ext_lv, _tor(6.3 * T - 0.06, 6.3 * T + 0.06), _m(Color(0.75, 0.5, 1.0, 0.5), 0.0, 0.3, 1.2), Vector3((bx + 1.5) * T + T * 0.5, 4.2, (by + 1.0) * T + T * 0.5), Vector3.ZERO, false)
			sr.scale = Vector3(1.0, 1.0, 1.0)
	# mirador del area de descanso
	var cl: int = int(L["C"])
	if cl > 0:
		var mx: float = (bx - 1.0) * T
		var mz: float = (by - 0.5) * T
		var mr: float = 0.7 + 0.35 * float(cl)
		_add(ext_lv, _sph(mr, 16, true), _m(Color(1.0, 0.8, 0.65, 0.4), 0.1, 0.1), Vector3(mx, 3.3, mz), Vector3.ZERO, false)
		_add(ext_lv, _tor(mr - 0.03, mr + 0.05), metal, Vector3(mx, 3.32, mz), Vector3.ZERO, false)
		if cl >= 2:
			for sd in [-1.0, 1.0]:
				_add(ext_lv, _sph(0.12, 6), _m(Color(1.0, 0.9, 0.5), 0.0, 0.4, 2.0), Vector3(mx + sd * (mr + 0.6), 3.4, mz), Vector3.ZERO, false)
		if cl >= 3:
			_add(ext_lv, _cyl(0.05, 0.07, 1.4), metal, Vector3(mx + 0.3, 4.2, mz), Vector3(0, 0, 0.8))


# ---------- actualización por fotograma ----------

func zoom_by(d: float) -> void:
	zoom = clampf(zoom + d, 0.55, 1.8)


func _update_visibility() -> void:
	if game == null or interior == null:
		return
	var out: bool = game.outside
	interior.visible = not out
	exterior.visible = out
	sun.visible = out
	moonlight.visible = out
	fill.visible = not out
	skydome.visible = out
	target_ring.visible = false


func set_menu(on: bool) -> void:
	menu_mode = on
	if interior == null:
		return
	if on:
		interior.visible = false
		exterior.visible = true
		sun.visible = true
		moonlight.visible = true
		fill.visible = false
		skydome.visible = true
		player_node.visible = false
		target_ring.visible = false
		alert_light.visible = false
	else:
		last_outside = not game.outside
		player_node.visible = true


func _menu_process(delta: float) -> void:
	t_node += delta
	_update_light()
	_update_props()
	var center := Vector3((float(game.BASE_X0) + 3.0) * T3, 0.0, (float(game.BASE_Y0) + 1.0) * T3)
	var a: float = t_node * 0.06 + 0.6
	var cp: Vector3 = center + Vector3(cos(a) * 30.0, 9.5 + sin(t_node * 0.25) * 1.2, sin(a) * 30.0)
	cp.y = maxf(cp.y, ground_y(cp.x / T3, cp.z / T3) + 3.0)
	cam.fov = 50.0
	cam.position = cp
	cam.look_at(center + Vector3(0.0, 2.5, 0.0), Vector3.UP)
	skydome.position = cam.position
	if dust_fx != null:
		dust_fx.position = cam.position + Vector3(0.0, 1.0, 0.0)


func _process(delta: float) -> void:
	if game == null or interior == null:
		return
	if menu_mode:
		_menu_process(delta)
		return
	if not game.playing:
		return
	t_node += delta
	if game.outside != last_outside:
		last_outside = game.outside
		_update_visibility()
		if game.outside:
			cam_focus = _tp(game.player.x, game.player.y)
	if not game.view3d_on:
		return # en la vista 2D no hace falta animar la escena 3D
	_update_light()
	if wfx != null:
		wfx.call("update", delta, last_daylight)
	_task_fx(delta)
	_update_actors(delta)
	_fx_update(delta)
	_update_camera(delta)
	_update_props()
	sync_t += delta
	if sync_t > 0.5:
		sync_t = 0.0
		if game.outside:
			refresh_nodes()


func _update_light() -> void:
	var t: float = float(game.clock) / 60.0
	var moon: bool = game.location == "Luna"
	var day_f: float = 0.0
	var u: float = 0.0
	if t >= 6.0 and t <= 20.0:
		u = (t - 6.0) / 14.0
		day_f = sin(PI * u)
	var lunar_dark: bool = game._is_night()
	var sk: float = 0.0 if lunar_dark else day_f
	var daylight: float = clampf(sk * 3.0, 0.0, 1.0)
	last_daylight = daylight
	var elev: float = deg_to_rad(6.0 + (float(WorldLook.get_look(game.location)["max_elev"]) - 6.0) * sk)
	var phi: float = PI * u
	# v28: el arco del sol es mas lateral (este-oeste) para que las sombras crucen la vista y den relieve
	var to_sun := Vector3(cos(phi) * cos(elev), sin(elev), sin(phi) * cos(elev) * 0.45).normalized()
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	sun.light_energy = (1.0 if moon else 1.1) * smoothstep(0.0, 0.3, sk)
	sun.light_color = Color(1.0, 0.78 + 0.22 * sk, 0.6 + 0.4 * sk) if moon else Color(1.0, 0.72 + 0.16 * sk, 0.5 + 0.26 * sk)
	if dust_fx != null:
		dust_fx.visible = game.outside and daylight > 0.05
		dust_fx.speed_scale = 2.6 if game.storm_left > 0 else 1.0
		dust_mat.albedo_color = Color(0.95, 0.65, 0.4, (0.45 if game.storm_left > 0 else 0.15) * daylight)
	sun.shadow_enabled = sk > 0.02 and game.shadows_on
	moonlight.light_energy = lerpf(0.5, 0.0, daylight)
	# gradacion suave por mundo: Marte menos saturado y con mas contraste (menos "naranja plano"), Luna neutra
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.86 if game.location == "Marte" else 0.95
	env.adjustment_contrast = 1.06
	env.tonemap_exposure = 0.9 * float(game.bright)
	if game.outside or menu_mode:
		# v28: luz, sombras y gradacion propias de cada mundo (world_look.gd)
		WorldLook.apply_outside(self, game.location, sk, daylight, game.storm_left > 0)
		if moon:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.0, 0.0, 0.012)
			_set_reflection("moon")
			env.fog_enabled = false
		else:
			env.background_mode = Environment.BG_SKY
			refl_kind = "mars"
			var top: Color = Color(0.03, 0.04, 0.1).lerp(Color(0.66, 0.45, 0.32), daylight)
			var hor: Color = Color(0.12, 0.08, 0.12).lerp(Color(0.97, 0.7, 0.44), daylight)
			if game.storm_left > 0:
				top = top.lerp(Color(0.6, 0.38, 0.22), 0.7)
				hor = hor.lerp(Color(0.75, 0.48, 0.28), 0.8)
			sky_mat.sky_top_color = top
			sky_mat.sky_horizon_color = hor
			sky_mat.ground_horizon_color = hor
			sky_mat.ground_bottom_color = hor.darkened(0.4)
			env.fog_enabled = game.haze_on
			env.fog_light_color = hor
			env.fog_density = 0.012 if game.storm_left > 0 else 0.0055
		var stars_vis: bool = moon or daylight < 0.6
		skydome.visible = stars_vis
	else:
		var dim: float = 0.55 if game._is_night_clock() else 1.0
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.03, 0.06)
		_set_reflection("in")
		env.fog_enabled = false
		env.ambient_light_color = Color(0.55, 0.6, 0.78)
		# v38: menos luz plana dentro; las luces de pared (interior_look.gd) dan zonas de luz.
		# Sin esas luces (efectos en Bajo) se mantiene el nivel anterior para no oscurecer.
		var lit: bool = int(game.fx_idx) >= 1
		env.ambient_light_energy = (0.32 if lit else 0.42) * dim
		fill.light_energy = (0.55 if lit else 0.75) * dim
		if lit:
			sun.light_energy *= 0.35   # v38: dentro de la base el sol solo entra por las ventanas (antes aplanaba el suelo)
		fill.shadow_enabled = game.shadows_on


var refl_kind: String = ""


func _set_reflection(kind: String) -> void:
	# el cielo falso solo se actualiza al cambiar de lugar (recalcular el reflejo cuesta)
	if refl_kind == kind:
		return
	refl_kind = kind
	if kind == "in":
		# v38: dentro, los metales reflejan un «techo» oscuro, no un cielo casi blanco
		# (ese reflejo aclaraba y aplanaba el suelo entero)
		sky_mat.sky_top_color = Color(0.2, 0.22, 0.28)
		sky_mat.sky_horizon_color = Color(0.36, 0.38, 0.44)
		sky_mat.ground_horizon_color = Color(0.3, 0.31, 0.36)
		sky_mat.ground_bottom_color = Color(0.16, 0.17, 0.21)
	elif kind == "moon":
		sky_mat.sky_top_color = Color(0.02, 0.03, 0.08)
		sky_mat.sky_horizon_color = Color(0.3, 0.32, 0.4)
		sky_mat.ground_horizon_color = Color(0.3, 0.3, 0.34)
		sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.12)


func _npc_pose(ch: String) -> String:
	if game.mode == 1 and not game.outside and game.dlg_name.text == str(game.npcs[ch]["who"]):
		return "talk"
	return "idle"


func _actor_pos(tile_px: Vector2) -> Vector3:
	var tp: Vector2 = tile_px / float(game.TILE)
	var wp := Vector3((tp.x + 0.5) * T3, 0.0, (tp.y + 0.5) * T3)
	if game.outside:
		wp.y = ground_y(tp.x + 0.5, tp.y + 0.5)
	return wp


func _update_jump_shadow(ground_p: Vector3) -> void:
	# sombra redonda en el suelo mientras se salta (se ve bien aunque las sombras esten apagadas)
	if jump_shadow == null or not is_instance_valid(jump_shadow):
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 0.02
		cm.radial_segments = 16
		cm.rings = 1
		jump_shadow = MeshInstance3D.new()
		jump_shadow.mesh = cm
		jump_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(0, 0, 0, 0.4)
		jump_shadow.material_override = sm
		add_child(jump_shadow)
	var up: bool = game.outside and game.jump_z > 0.03 and game.fall_t < 0.0
	jump_shadow.visible = up
	if up:
		var s: float = clampf(1.0 - game.jump_z * 0.25, 0.4, 1.0)
		jump_shadow.scale = Vector3(s, 1.0, s)
		jump_shadow.position = ground_p + Vector3(0.0, 0.05, 0.0)


func _update_actors(delta: float) -> void:
	player_node.position = _actor_pos(game.player_px)
	# suaviza la altura del terreno (laderas y bajadas sin saltos bruscos)
	if game.outside and game.playing:
		var ty: float = player_node.position.y
		if not py_ok or absf(ty - py_s) > 4.0:
			py_s = ty
		else:
			py_s = lerpf(py_s, ty, 1.0 - exp(-12.0 * delta))
		py_ok = true
		player_node.position.y = py_s
	else:
		py_ok = false
	var ground_p: Vector3 = player_node.position
	if game.outside:
		player_node.position.y += game.jump_z
	_update_jump_shadow(ground_p)
	anim_k = clampf(1.0 - exp(-13.0 * delta), 0.04, 0.6)
	var target: float = game.heading
	yaw_player = lerp_angle(yaw_player, target, 1.0 - exp(-14.0 * delta))
	player_node.rotation.y = yaw_player
	_anim_astronaut(player_node, _player_pose(), t_node)
	player_node.visible = game.cam_mode != 1 and not (game.fall_t > game.FALL_TIME * 0.55)
	var pp: Vector3 = player_node.position
	var idx: int = 0
	for ch in npc_nodes:
		var n: Node3D = npc_nodes[ch]
		if ch == "k" and game.enoc_px.x >= 0.0:
			n.position = _actor_pos(game.enoc_px)
			if game.enoc_move or game.enoc_work:
				var fv: Vector3 = Vector3(game.enoc_dir.x, 0.0, game.enoc_dir.y)
				n.rotation.y = lerp_angle(n.rotation.y, atan2(-fv.x, -fv.z), 1.0 - exp(-12.0 * delta))
				var kp: String = "hammer" if game.enoc_work else "walk"
				if enoc_hammer != null:
					enoc_hammer.visible = game.enoc_work
				_anim_astronaut(n, kp, t_node, 0.0)
				idx += 1
				continue
		if enoc_hammer != null and ch == "k":
			enoc_hammer.visible = false
		var d: Vector3 = pp - n.position
		d.y = 0.0
		if not game.outside and d.length() < 11.0:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-6.0 * delta))
		_anim_astronaut(n, _npc_pose(ch), t_node, float(idx) * 1.7)
		idx += 1
	# anillo de interaccion
	var show: bool = false
	if game.mode == 0:
		var np: Vector2i = game._find_target()
		if np.x >= 0:
			show = true
			var ty: float = 0.06
			if game.outside:
				ty = ground_y(float(np.x) + 0.5, float(np.y) + 0.5) + 0.08
			target_ring.position = _tp(np.x, np.y, ty)
			var pulse: float = 1.0 + 0.08 * sin(t_node * 5.0)
			target_ring.scale = Vector3(pulse, 1.0, pulse)
	target_ring.visible = show


func _blocked(p: Vector3) -> bool:
	# casco de la base o marquesina de la esclusa (que sobresale ~2 m hacia el sur)
	if _in_base_box(p):
		return true
	var ax: float = (float(game.BASE_X0) + 2.5) * T3
	var z1: float = float(game.BASE_Y0 + 3) * T3
	return absf(p.x - ax) < 2.3 and p.z > z1 and p.z < z1 + 2.3 and p.y < 3.7


func _in_base_box(p: Vector3) -> bool:
	# volumen del casco y los modulos de la base (en metros del mundo), con un margen
	var x0: float = float(game.BASE_X0 - 3) * T3 - 0.5
	var x1: float = float(game.BASE_X0 + 7) * T3 + 0.5
	var z0: float = float(game.BASE_Y0 - 1) * T3 - 0.5
	var z1: float = float(game.BASE_Y0 + 3) * T3 + 0.5
	return p.x > x0 and p.x < x1 and p.z > z0 and p.z < z1 and p.y < 3.5   # altura del casco (la cupula alta no estorba)


var cam_snap: bool = false


func make_preview_model() -> Node3D:
	# astronauta suelto para la vista del inventario (otro mundo 3D)
	var n: Node3D = _make_astronaut(Color(0.97, 0.97, 1.0), "wilson")
	_apply_suit_tex()
	return n


func snap_camera() -> void:
	cam_snap = true


func _update_camera(delta: float) -> void:
	var mode: int = game.cam_mode
	var pos: Vector3 = player_node.position
	if cam_snap:
		# tras cruzar la esclusa la camara se coloca de golpe detras del jugador (sin girar de lado)
		cam_snap = false
		yaw_cam = game.heading
		cam_focus = pos
	if mode == 1:
		yaw_cam = game.heading
	else:
		yaw_cam = lerp_angle(yaw_cam, game.heading, 1.0 - exp(-10.0 * delta))
	cam_focus = cam_focus.lerp(pos, 1.0 - exp(-7.0 * delta))
	var dirv := Vector3(-sin(yaw_cam), 0.0, -cos(yaw_cam))
	var focus: Vector3 = cam_focus
	var want_fov: float = 52.0
	var cp: Vector3
	var look: Vector3
	match mode:
		1:
			want_fov = 78.0
			var bob: float = 0.0
			if game.moving:
				bob = absf(sin(t_node * 12.0)) * 0.05
			cp = pos + Vector3(0.0, 1.62 + bob, 0.0) + dirv * 0.1
			look = cp + dirv * 10.0 + Vector3(0.0, tan(clampf(game.pitch, -1.2, 1.0)) * 10.0, 0.0)
		2:
			want_fov = 62.0
			var back: float = 7.0 * zoom
			var hgt: float = 2.6 * zoom
			if game.outside:
				back = 8.5 * zoom
				hgt = 3.6 * zoom
			cp = focus - dirv * back + Vector3(0.0, hgt + 0.6, 0.0)
			look = focus + dirv * 3.0 + Vector3(0.0, 1.3, 0.0)
		3:
			want_fov = 50.0
			if game.outside:
				cp = focus + Vector3(0.0, 22.0, 4.0) * zoom
				look = focus
			else:
				focus = Vector3(16.0, 0.0, 10.0)
				cp = focus + Vector3(0.0, 27.0, 4.0) * zoom
				look = focus
		_:
			var off: Vector3
			if game.outside:
				off = Vector3(0.0, 10.0, 14.5) * zoom
			else:
				off = Vector3(0.0, 15.0, 13.0) * zoom
				focus.x = clampf(focus.x, 12.0, 20.0)
				focus.z = clampf(focus.z, 8.5, 11.5)
			cp = focus + off
			look = focus + Vector3(0.0, 1.0, 0.0)
	if not game.outside and (mode == 1 or mode == 2):
		# dentro de la nave la camara nunca sale del volumen interior (paredes en x/z y techo en y)
		cp.x = clampf(cp.x, 2.3, 29.7)
		cp.z = clampf(cp.z, 2.3, 17.7)
		cp.y = clampf(cp.y, 0.4, 3.05)
		if mode == 2:
			# si el recorte la acerca al jugador, subimos el punto de mira para no mirar al suelo
			look.y = maxf(look.y, 0.9)
	if game.outside and mode == 2:
		# la camara en tercera persona no puede meterse dentro del casco de la base: se acerca y sube
		var fp: Vector3 = focus + Vector3(0.0, 1.3, 0.0)
		if _in_base_box(fp.lerp(cp, 1.0)) or _in_base_box(fp.lerp(cp, 0.6)) or _in_base_box(fp.lerp(cp, 0.3)):
			# bloqueada por el casco: primero subimos la camara por encima del techo, mirando hacia el jugador
			var done: bool = false
			for opt_cam in [[3.2, 7.5], [2.2, 9.0], [1.2, 10.5], [0.4, 12.0]]:
				# camara casi encima del jugador, por encima del techo y de la marquesina de la esclusa
				var up_cp: Vector3 = focus - dirv * float(opt_cam[0]) * zoom + Vector3(0.0, float(opt_cam[1]) * zoom, 0.0)
				if not _blocked(up_cp) and not _blocked(fp.lerp(up_cp, 0.7)) and not _blocked(fp.lerp(up_cp, 0.5)) and not _blocked(fp.lerp(up_cp, 0.3)):
					cp = up_cp
					look = focus + Vector3(0.0, 1.0, 0.0)
					done = true
					break
			var back2: float = 8.5 * zoom
			for ang in ([] if done else [PI / 2.0, -PI / 2.0, PI]):
				var dv: Vector3 = Vector3(-sin(yaw_cam + ang), 0.0, -cos(yaw_cam + ang))
				var alt: Vector3 = focus - dv * back2 + Vector3(0.0, 3.6 * zoom + 0.6, 0.0)
				if not _in_base_box(alt) and not _in_base_box(fp.lerp(alt, 0.5)) and not _in_base_box(fp.lerp(alt, 0.25)):
					cp = alt
					look = focus + Vector3(0.0, 1.3, 0.0)
					done = true
					break
			if not done:
				cp = fp
	if game.outside and mode != 1:
		cp.y = maxf(cp.y, ground_y(cp.x / T3, cp.z / T3) + (1.4 if mode == 2 else 3.0))
	if game.shake_t > 0.0:
		cp += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * game.shake_t * 0.45
	cam.fov = lerpf(cam.fov, want_fov, 1.0 - exp(-6.0 * delta))
	cam.position = cp
	cam.look_at(look, Vector3.UP)
	skydome.position = cam.position
	if dust_fx != null:
		# v28: el polvo flota cerca del suelo alrededor del jugador (no pegado a la camara:
		# los sprites cercanos a la camara se veian como rectangulos grandes)
		var pf: Vector2 = game.pos_f
		dust_fx.position = Vector3(pf.x * T3, ground_y(pf.x, pf.y) + 2.0, pf.y * T3)
	if ceiling != null:
		ceiling.visible = (mode == 1 or mode == 2) and not game.outside


func _update_props() -> void:
	var on: bool = int(t_node * 2.0) % 2 == 0
	for e in led_mats:
		var m: StandardMaterial3D = e[0]
		var c: Color = e[1] if on else e[2]
		m.albedo_color = c
		m.emission = c
	if beacon_mat != null:
		beacon_mat.emission_energy_multiplier = 2.5 if on else 0.2
	if shield_mat != null:
		if game.breach:
			var on2: bool = int(t_node * 4.0) % 2 == 0
			shield_mat.albedo_color = Color(0.85, 0.1, 0.1) if on2 else Color(0.4, 0.06, 0.06)
		else:
			shield_mat.albedo_color = shield_mat.get_meta("normal") if shield_mat.has_meta("normal") else Color(0.5, 0.28, 0.75)
	if shield_ring != null:
		shield_ring.rotation.y += 0.03
	StationArt.animate(self, t_node, get_process_delta_time())
	alert_light.visible = game.breach and not game.outside
	if alert_light.visible:
		alert_light.light_energy = 2.0 + 2.0 * sin(t_node * 6.0)


func screen_of_tile(tx: int, ty: int, height: float = 2.6) -> Vector2:
	var wp := Vector3((float(tx) + 0.5) * T3, height, (float(ty) + 0.5) * T3)
	if game.outside:
		wp.y += ground_y(float(tx) + 0.5, float(ty) + 0.5)
	if cam.is_position_behind(wp):
		return Vector2(-1000.0, -1000.0)
	var sp: Vector2 = cam.unproject_position(wp)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	return sp / vs * game._mv()
