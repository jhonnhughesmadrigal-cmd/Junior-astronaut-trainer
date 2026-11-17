extends RefCounted
# v41 — Frases cortas de la tripulacion durante los eventos (bocadillos sobre la cabeza, event_fx.gd).
# Claves en espanol (Lang.t); el ingles va en lang_en.gd. "*" = cualquier tripulante.
# a = Dra. YARISBEL (medica), k = ENOC (tecnico), l = PAM (comandante).

const LINES: Dictionary = {
	"meteor": {
		"l": ["¡Impacto! ¡Todos a sus puestos!", "¡Brecha en el casco! Wilson, hay que sellarla."],
		"k": ["¡Perdemos presión! Busca el kit de parche.", "Oigo el aire salir… ¡rápido!"],
		"a": ["¿Alguien está herido?", "Respiren despacio, no gasten aire."],
	},
	"breach": {
		"l": ["La brecha sigue abierta.", "Cada hora perdemos oxígeno."],
		"k": ["Ese silbido no me gusta nada.", "Hay que sellar esa brecha ya."],
		"a": ["Nos estamos quedando sin aire.", "Wilson, el casco primero."],
	},
	"sealed": {
		"l": ["¡Brecha sellada! Buen trabajo.", "Presión estable. Respiremos."],
		"k": ["¡Ni un silbido más!", "Ese parche aguantará."],
		"a": ["Uf… ya respiro tranquila.", "¡Bien hecho, Wilson!"],
	},
	"micro": {
		"*": ["¿Oyeron ese golpe?", "Algo pequeño golpeó el casco.", "Micrometeorito… revisemos los equipos."],
	},
	"storm_warn": {
		"l": ["Se acerca una tormenta de polvo.", "Preparen los paneles: viene polvo."],
		"k": ["El viento arrastra polvo fino.", "Hay que limpiar los paneles después."],
		"a": ["Mejor no salir cuando llegue.", "Que nadie se quede fuera."],
	},
	"storm": {
		"l": ["No se ve nada ahí fuera.", "Los paneles casi no dan energía."],
		"k": ["El polvo tapa los paneles solares.", "Escucha el viento en el casco…"],
		"a": ["Quedémonos dentro.", "El polvo raya los visores."],
	},
	"flare": {
		"l": ["¡Erupción solar! Todos al refugio.", "Radiación alta: suban el escudo."],
		"k": ["El escudo está trabajando a tope.", "Los sensores marcan radiación."],
		"a": ["Nada de salidas hasta que pase.", "Protejamos la cabeza y el cuerpo."],
	},
	"medical": {
		"sick": ["*cof cof* No me encuentro bien…", "Siento mareo…", "Me duele la cabeza…", "Creo que tengo fiebre."],
		"a": ["Déjame examinarte.", "Necesito un botiquín.", "Descansa, por favor."],
		"*": ["¿Estás bien?", "Ánimo, te pondrás bien."],
	},
	"sick": {
		"sick": ["*cof cof*", "Necesito descansar…", "Todo me da vueltas…"],
		"a": ["Sigue en reposo.", "Un botiquín ayudaría."],
	},
	"power": {
		"k": ["¡Fallo eléctrico! Voy a revisar.", "Saltaron los circuitos."],
		"l": ["Ahorremos energía.", "Las luces parpadean…"],
		"a": ["Sin energía no hay soporte vital.", "¿Se va a apagar todo?"],
	},
	"oxygen": {
		"*": ["El aire huele raro.", "Revisemos el soporte vital.", "El nivel de oxígeno baja."],
	},
	"water": {
		"*": ["Hay una fuga de agua.", "Cuidado, el suelo está mojado.", "El reciclador hace ruidos raros."],
	},
	"harvest": {
		"*": ["¡Qué cosecha!", "¡Comida fresca!", "Las plantas crecen de maravilla."],
	},
	"message": {
		"*": ["¡Mensaje de la Tierra!", "¡Nos mandan ánimos!", "¡Saludos desde casa!"],
	},
	"plague": {
		"*": ["Las plantas se están secando…", "Una plaga en el invernadero…", "Perdimos parte de la cosecha."],
	},
	"salvage": {
		"k": ["¡Mira lo que encontré!", "Estas piezas nos servirán."],
		"*": ["¡Buen hallazgo, ENOC!", "Más chatarra para el banco."],
	},
}


# Una frase para el tripulante ch en el evento kind ("" si no hay). sick = el tripulante enfermo.
static func pick(kind: String, ch: String, sick: bool, rng: RandomNumberGenerator) -> String:
	if not LINES.has(kind):
		return ""
	var d: Dictionary = LINES[kind]
	var key: String = ""
	if sick and d.has("sick"):
		key = "sick"
	elif d.has(ch):
		key = ch
	elif d.has("*"):
		key = "*"
	if key == "":
		return ""
	var arr: Array = d[key]
	return Lang.t(str(arr[rng.randi_range(0, arr.size() - 1)]))
