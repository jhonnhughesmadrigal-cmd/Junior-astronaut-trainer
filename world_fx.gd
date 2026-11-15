extends Node3D
# v28 — Particulas discretas del exterior (solo dibujo).
#  - Polvo de los pasos: en la Luna no hay aire, asi que el polvo sale en arcos y cae con la
#    gravedad lunar (1,62 m/s^2, ficha NSSDC de la NASA) sin quedar flotando; en Marte cae con
#    3,73 m/s^2 y el aire lo frena y lo arrastra con el viento. La forma y la cantidad son de juego.
#  - Nube al aterrizar de un salto.
#  - Destellos suaves sobre el hielo cuando hay luz de sol.
# La cantidad sigue la opcion "Efectos" (FX_FACTOR); en calidad baja no hay destellos.

const SpaceTex = preload("res://space_tex.gd")
const G_MOON: float = 1.62
const G_MARS: float = 3.73

var v: Node3D = null          # view3d
var moon: bool = true
var steps: CPUParticles3D = null
var land: CPUParticles3D = null
var glints: CPUParticles3D = null
var step_mat: StandardMaterial3D = null
var was_air: bool = false
var base_col: Color = Color.WHITE


func setup(view: Node3D, is_moon: bool, ice_points: PackedVector3Array) -> void:
	v = view
	moon = is_moon
	var k: float = float(v.game.FX_FACTOR[clampi(int(v.game.fx_idx), 0, 2)])
	base_col = Color(0.62, 0.62, 0.63) if moon else Color(0.7, 0.46, 0.32)
	step_mat = _sprite_mat(SpaceTex.glow_sprite(32, 0.02))
	steps = _make(maxi(6, int(36.0 * k)), 1.5 if moon else 2.4)
	steps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steps.emission_sphere_radius = 0.18
	steps.direction = Vector3(0, 1, 0)
	steps.spread = 55.0
	steps.initial_velocity_min = 0.9 if moon else 0.4
	steps.initial_velocity_max = 1.7 if moon else 0.9
	steps.gravity = Vector3(0, -G_MOON, 0) if moon else Vector3(0.5, -G_MARS * 0.12, 0.18)
	steps.damping_min = 0.0 if moon else 0.6
	steps.damping_max = 0.0 if moon else 1.2
	steps.scale_amount_min = 0.25
	steps.scale_amount_max = 0.55 if moon else 0.9
	steps.color_ramp = _ramp(0.55 if moon else 0.35)
	land = _make(maxi(6, int(22.0 * k)), 1.4 if moon else 2.4)
	land.one_shot = true
	land.explosiveness = 0.95
	land.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	land.emission_ring_axis = Vector3.UP
	land.emission_ring_radius = 0.35
	land.emission_ring_inner_radius = 0.2
	land.emission_ring_height = 0.05
	land.direction = Vector3(0, 0.5, 0)
	land.spread = 80.0
	land.initial_velocity_min = 1.0
	land.initial_velocity_max = 1.9
	land.gravity = steps.gravity
	land.damping_min = steps.damping_min
	land.damping_max = steps.damping_max
	land.scale_amount_min = 0.3
	land.scale_amount_max = 0.7 if moon else 1.1
	land.color_ramp = steps.color_ramp
	if int(v.game.fx_idx) > 0 and ice_points.size() > 0:
		glints = CPUParticles3D.new()
		glints.amount = mini(ice_points.size(), int(40.0 * k))
		glints.lifetime = 1.6
		glints.randomness = 1.0
		glints.local_coords = false
		glints.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		glints.emission_points = ice_points
		glints.gravity = Vector3.ZERO
		glints.initial_velocity_min = 0.0
		glints.initial_velocity_max = 0.0
		glints.scale_amount_min = 0.2
		glints.scale_amount_max = 0.45
		glints.color_ramp = _ramp(0.9, true)
		glints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		var gm: StandardMaterial3D = _sprite_mat(SpaceTex.glow_sprite(32, 0.3))
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.albedo_color = Color(0.85, 0.95, 1.0)
		q.material = gm
		glints.mesh = q
		add_child(glints)


func _sprite_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


func _ramp(alpha: float, twinkle: bool = false) -> Gradient:
	var g := Gradient.new()
	if twinkle:
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, alpha), Color(1, 1, 1, 0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, alpha), Color(1, 1, 1, 0)])
	return g


func _make(amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	q.material = step_mat
	p.mesh = q
	add_child(p)
	return p


func update(_delta: float, daylight: float) -> void:
	if v == null or steps == null:
		return
	var g = v.game
	var out: bool = bool(g.outside) and not bool(v.menu_mode)
	visible = out
	if not out:
		steps.emitting = false
		was_air = false
		return
	var pf: Vector2 = g.pos_f
	var feet := Vector3(pf.x * 2.0, v.ground_y(pf.x, pf.y) + 0.08, pf.y * 2.0)
	var air: bool = bool(g.airborne) or float(g.jump_z) > 0.05
	steps.position = feet
	steps.emitting = bool(g.moving) and not air and float(g.fall_t) < 0.0
	steps.speed_scale = 1.5 if g.bind_down("sprint") else 1.0
	if was_air and not air:
		land.position = feet
		land.restart()
	was_air = air
	# el polvo refleja la luz del dia (de noche casi no se ve)
	var b: float = lerpf(0.35, 1.0, daylight)
	var c := Color(base_col.r * b, base_col.g * b, base_col.b * b)
	steps.color = c
	land.color = c
	if glints != null:
		glints.emitting = daylight > 0.25
