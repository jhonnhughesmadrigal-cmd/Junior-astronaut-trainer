extends RefCounted
# v28 — Materiales de los trajes de la tripulacion (Zadiel, Dra. Yarisbel, Ing. Enoc, Com. Pam).
# Inspiracion general en trajes EVA reales (casco duro brillante, visor dorado, franjas de color
# para distinguir a cada astronauta); diseno propio, sin logotipos.

# color de rol (franjas y parche): mismo que antes para no cambiar la identidad de cada uno
const ROLE: Dictionary = {
	"wilson": Color(0.93, 0.52, 0.18),   # naranja
	"a": Color(0.82, 0.22, 0.22),        # Dra. Yarisbel (medica): rojo
	"k": Color(0.16, 0.52, 0.6),         # Ing. Enoc: azul petroleo
	"l": Color(0.9, 0.74, 0.24),         # Com. Pam (comandante): dorado
}


static func role_color(role: String, fallback: Color) -> Color:
	return ROLE.get(role, fallback)


# casco: cascara dura, blanca y lisa (mas brillante que la tela)
static func helmet(c: Color = Color(0.95, 0.95, 0.94)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.24
	m.metallic = 0.0
	m.metallic_specular = 0.6
	m.disable_receive_shadows = true
	m.rim_enabled = true
	m.rim = 0.2
	m.rim_tint = 0.4
	return m


# visor dorado: reflejo metalico oscuro con un brillo leve (no emite como un neon)
static func visor() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.44, 0.16)
	m.metallic = 0.92
	m.roughness = 0.07
	m.metallic_specular = 0.8
	m.emission_enabled = true
	m.emission = Color(0.55, 0.38, 0.14)
	m.emission_energy_multiplier = 0.12
	m.disable_receive_shadows = true
	return m


# rodamientos (hombro, cadera, cuello): metal satinado
static func bearing() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.56, 0.58, 0.62)
	m.metallic = 0.8
	m.roughness = 0.32
	m.disable_receive_shadows = true
	return m
