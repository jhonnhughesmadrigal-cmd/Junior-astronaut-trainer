extends Control

const MAX_DAYS: int = 30
const DAY_START: int = 360 # 06:00
const NIGHT_START: int = 1200 # 20:00
const BED_FROM: int = 1080 # 18:00
const BASE_DRAIN: Dictionary = {"oxygen": 38.4, "energy": 33.3, "food": 30.7, "water": 23.0, "shield": 15.4, "morale": 17.9}
const SLEEP_MULT: Dictionary = {"oxygen": 0.8, "energy": 0.6, "food": 0.5, "water": 0.5, "shield": 1.0, "morale": 0.0}
const LUNAR_NIGHT_EXTRA: float = 2.5
const SHIELD_LOW_MORALE: float = 12.0
const BREACH_OXY: float = 14.0
const BREACH_MORALE: float = 4.0
const ILL_MORALE: float = 10.0
const NIGHT_ENERGY_PER_H: float = 6.0
const NIGHT_MORALE_PER_H: float = 8.0
const SLEEP_MORALE_PER_H: float = 1.0
const TILE: int = 40
const VIEW_W: int = 16
const VIEW_H: int = 10
const MOVE_SPEED: float = 220.0
const MOVE_TPS: float = 2.6 # casillas por segundo al caminar (antes 4,2: demasiado rapido)
const SPRINT_MULT: float = 1.4
const PLAYER_R: float = 0.3
const MOUSE_BASE: float = 0.0024
const TURN_RATE: float = 2.6
const REACH: float = 1.7
const SAVE_PATH: String = "user://savegame.json"
const SETTINGS_PATH: String = "user://settings.cfg"
const EXT_W: int = 120
const EXT_H: int = 84
const BASE_X0: int = 57
const BASE_Y0: int = 66
const MINI_SCALE: float = 1.5
const TIME_SCALE: float = 1.0 # minutos de juego por segundo real (1 h de juego = 60 s)
const TASK_SPEED: float = 20.0 # minutos de juego por segundo real al hacer una tarea (x20)
const CRAFT_SPEED: float = 40.0 # al fabricar y mejorar (x40)
const NODE_RESPAWN_DAYS: int = 5
const DOOR_FRONT: Vector2i = Vector2i(13, 8)

var NAMES: Dictionary = {
	"oxygen": Lang.t("Oxígeno"), "energy": Lang.t("Energía"), "food": Lang.t("Comida"),
	"water": Lang.t("Agua"), "shield": Lang.t("Escudo anti-radiación"), "morale": Lang.t("Moral")
}

var MAT_NAMES: Dictionary = {"scrap": Lang.t("Chatarra"), "polymer": Lang.t("Polímero"), "circuits": Lang.t("Circuitos")}

var ACTIONS: Array = [
	{"name": Lang.t("Reparar soporte vital"), "mins": 60, "fx": {"oxygen": 18, "energy": -4}},
	{"name": Lang.t("Mantener paneles solares"), "mins": 60, "fx": {"energy": 20}},
	{"name": Lang.t("Cultivar en invernadero"), "mins": 90, "fx": {"food": 18, "water": -4, "energy": -3}},
	{"name": Lang.t("Reciclar agua"), "mins": 60, "fx": {"water": 18, "energy": -3}},
	{"name": Lang.t("Reforzar escudo anti-radiación"), "mins": 60, "fx": {"shield": 15, "energy": -3}},
	{"name": Lang.t("Tiempo de descanso"), "mins": 60, "fx": {"morale": 15}}
]

var RECIPES: Array = [
	{"id": "patch", "name": Lang.t("Kit de parche"), "mins": 90, "cost": {"scrap": 2, "polymer": 1}, "desc": Lang.t("sella brechas de meteoritos")},
	{"id": "medkit", "name": Lang.t("Botiquín"), "mins": 60, "cost": {"polymer": 1, "circuits": 1}, "desc": Lang.t("cura enfermedades (habla con PAM)")},
	{"id": "repair", "name": Lang.t("Reparador de circuitos"), "mins": 120, "cost": {"scrap": 1, "circuits": 2}, "desc": Lang.t("reduce el daño de fallas eléctricas")},
	{"id": "filter", "name": Lang.t("Filtro de polvo"), "mins": 90, "cost": {"scrap": 1, "polymer": 2}, "desc": Lang.t("reduce el daño de las tormentas de polvo")},
	{"id": "map", "name": Lang.t("Mapa de navegación"), "mins": 120, "cost": {"scrap": 1, "polymer": 1, "circuits": 1}, "desc": Lang.t("mapa del mundo (Tab) y minimapa; se fabrica una sola vez")}
]

var DIFFICULTIES: Array = [
	# g_*: cuanto crece cada cosa al llegar al ultimo dia (0 = no crece): gasto, eventos, material que se pierde, dias extra de reaparicion
	{"name": Lang.t("Fácil"), "drain": 0.8, "nightmare": 0.15, "sev": 0.8, "events": 0.45, "g_drain": 0.15, "g_ev": 0.3, "g_mat": 0.0, "r_add": 0},
	{"name": Lang.t("Normal"), "drain": 1.0, "nightmare": 0.35, "sev": 1.0, "events": 0.6, "g_drain": 0.35, "g_ev": 0.5, "g_mat": 0.15, "r_add": 1},
	{"name": Lang.t("Difícil"), "drain": 1.15, "nightmare": 0.6, "sev": 1.25, "events": 0.75, "g_drain": 0.55, "g_ev": 0.7, "g_mat": 0.3, "r_add": 3},
	{"name": Lang.t("Extremo"), "drain": 1.3, "nightmare": 0.7, "sev": 1.5, "events": 0.8, "g_drain": 0.8, "g_ev": 0.9, "g_mat": 0.55, "r_add": 6}
]

# Pesadillas y situaciones incómodas al dormir: [quien, texto]
var NIGHTMARES: Array = [
	{"title": Lang.t("Pesadilla: la esclusa"), "morale": 12, "lines": [
		["Narración", Lang.t("Sueñas que la esclusa no abre y el aire se agota mientras golpeas la puerta.")],
		["Wilson", Lang.t("Solo fue un sueño... solo un sueño.")]]},
	{"title": Lang.t("Pesadilla: el silencio"), "morale": 10, "lines": [
		["Narración", Lang.t("Sueñas que Control deja de responder. Nadie en la Tierra recuerda que estás aquí.")],
		["Wilson", Lang.t("Control sí responde. Sí responde.")]]},
	{"title": Lang.t("Pesadilla: el rescate"), "morale": 14, "lines": [
		["Narración", Lang.t("Sueñas que la nave de rescate pasa de largo, cada vez más pequeña en el cielo.")],
		["Wilson", Lang.t("Faltan días. Llegará.")]]},
	{"title": Lang.t("Ruidos en la noche"), "morale": 6, "lines": [
		["Narración", Lang.t("Un crujido metálico en el casco te despierta. Es dilatación térmica, pero ya no puedes dormir.")],
		["Wilson", Lang.t("Es solo el metal enfriándose. Eso espero.")]]},
	{"title": Lang.t("Discusión en el pasillo"), "morale": 7, "lines": [
		["Narración", Lang.t("Oyes a ENOC y a la Dra. YARISBEL discutir en voz baja sobre las raciones.")],
		["Wilson", Lang.t("Todos estamos al límite. Mañana hablaré con ellos.")]]},
	{"title": "Nostalgia", "morale": 8, "lines": [
		["Narración", Lang.t("Despiertas pensando en casa. La Tierra es solo una luz diminuta en el cielo.")],
		["Wilson", Lang.t("Treinta días. Después, café de verdad.")]]},
	{"title": Lang.t("Falsa alarma"), "morale": 6, "lines": [
		["Narración", Lang.t("Un sensor de presión salta sin motivo y te lanzas de la cama con el corazón a mil.")],
		["ENOC", Lang.t("Falsa alarma, Wilson. Vuelve a dormir... si puedes.")]]}
]

var UNCOMFORTABLE: Array = [
	Lang.t("Un crujido metálico en el casco te eriza la piel. Es dilatación térmica, pero no ayuda."),
	Lang.t("Las luces de emergencia parpadean un segundo. Nadie dice nada."),
	Lang.t("Oyes a alguien llorar en voz baja en otro módulo."),
	Lang.t("El silencio de la base a esta hora es abrumador."),
	Lang.t("Un sensor salta sin motivo. Falsa alarma, pero el corazón se acelera.")
]

# Zonas del mundo exterior. Los lugares son reales (estilizados, no a escala);
# "Restos del cargamento" y el campamento son ficción del juego.
var ZONES_LUNA: Array = [
	{"name": Lang.t("Llanura del Campamento Perseo"), "desc": Lang.t("Zona de la base (ficción del juego)"), "kind": "base", "cx": 60, "cy": 67, "rx": 1, "ry": 1, "lx": -1, "ly": -1, "lm": "", "ground": [0.60, 0.60, 0.63], "rock": [0.40, 0.40, 0.44], "dens": [0.05, 0.02, 0.008, 0.004], "facts": []},
	{"name": Lang.t("Mar de la Tranquilidad"), "desc": Lang.t("Llanura basáltica. Sitio del Apolo 11"), "kind": "plain", "cx": 24, "cy": 50, "rx": 17, "ry": 11, "lx": 24, "ly": 50, "lm": "apollo", "ground": [0.44, 0.44, 0.50], "rock": [0.30, 0.30, 0.35], "dens": [0.04, 0.035, 0.0, 0.004],
		"facts": [Lang.t("El Apolo 11 alunizó en el Mar de la Tranquilidad el 20 de julio de 1969. Se eligió por su terreno llano y liso."), Lang.t("Los 'mares' lunares son grandes llanuras de lava antigua y solidificada, por eso se ven oscuros desde la Tierra.")]},
	{"name": Lang.t("Monte Malapert"), "desc": Lang.t("Macizo cerca del polo sur"), "kind": "mountain", "cx": 22, "cy": 72, "rx": 11, "ry": 9, "lx": 22, "ly": 64, "lm": "plaque", "ground": [0.68, 0.68, 0.70], "rock": [0.50, 0.50, 0.54], "dens": [0.07, 0.03, 0.0, 0.0],
		"facts": [Lang.t("Malapert es un macizo cerca del polo sur lunar. Su cima recibe luz solar durante la mayor parte del año (cerca del 90%)."), Lang.t("Desde allí la Tierra se ve casi todo el tiempo, por eso se ha propuesto como lugar para antenas de comunicaciones.")]},
	{"name": Lang.t("Cráter Shackleton"), "desc": Lang.t("Cráter del polo sur con suelo en sombra"), "kind": "crater", "cx": 96, "cy": 70, "rx": 13, "ry": 11, "lx": 96, "ly": 70, "lm": "plaque", "ground": [0.28, 0.31, 0.40], "rock": [0.20, 0.22, 0.30], "dens": [0.03, 0.01, 0.05, 0.0],
		"facts": [Lang.t("Shackleton mide unos 21 km de diámetro y unos 4 km de profundidad, casi en el mismo polo sur de la Luna."), Lang.t("Su interior nunca recibe luz solar directa. Hay indicios de hielo de agua en el fondo, pero no se ha confirmado.")]},
	{"name": Lang.t("Cráter Tycho"), "desc": Lang.t("Cráter joven con rayos brillantes"), "kind": "crater", "peak": 0.1, "cx": 94, "cy": 30, "rx": 16, "ry": 13, "lx": 94, "ly": 38, "lm": "plaque", "ground": [0.72, 0.72, 0.74], "rock": [0.55, 0.55, 0.58], "dens": [0.04, 0.04, 0.0, 0.0],
		"facts": [Lang.t("Tycho mide unos 85 km de diámetro y tiene unos 100 millones de años: es joven para la Luna."), Lang.t("De su borde salen rayos brillantes de material expulsado, que se extienden a más de 2.000 km.")]},
	{"name": Lang.t("Valle Taurus-Littrow"), "desc": Lang.t("Valle del Apolo 17"), "kind": "valley", "cx": 26, "cy": 20, "rx": 18, "ry": 12, "lx": 26, "ly": 20, "lm": "apollo", "ground": [0.55, 0.54, 0.52], "rock": [0.40, 0.39, 0.38], "dens": [0.04, 0.03, 0.0, 0.0],
		"facts": [Lang.t("En este valle alunizó el Apolo 17 en diciembre de 1972, la última misión tripulada que ha pisado la Luna hasta ahora."), Lang.t("Lo rodean macizos montañosos de unos 2.000 m de altura. Los astronautas encontraron suelo de color anaranjado.")]},
	{"name": Lang.t("Restos del cargamento"), "desc": Lang.t("Nave de reabastecimiento (ficción del juego)"), "kind": "wreck", "cx": 60, "cy": 44, "rx": 11, "ry": 8, "lx": 60, "ly": 44, "lm": "wreck", "ground": [0.58, 0.58, 0.60], "rock": [0.40, 0.40, 0.44], "dens": [0.07, 0.02, 0.0, 0.06],
		"facts": [Lang.t("Fragmentos de la nave de reabastecimiento que falló. Es parte de la historia del juego, no un lugar real."), Lang.t("Entre los restos todavía quedan piezas aprovechables.")]}
]

var ZONES_MARTE: Array = [
	{"name": Lang.t("Llanura del Campamento Perseo"), "desc": Lang.t("Zona de la base (ficción del juego)"), "kind": "base", "cx": 60, "cy": 67, "rx": 1, "ry": 1, "lx": -1, "ly": -1, "lm": "", "ground": [0.72, 0.41, 0.27], "rock": [0.45, 0.24, 0.17], "dens": [0.05, 0.02, 0.008, 0.004], "facts": []},
	{"name": Lang.t("Cráter Jezero"), "desc": Lang.t("Antiguo lago con delta (Perseverance)"), "kind": "crater", "cx": 26, "cy": 50, "rx": 14, "ry": 11, "lx": 26, "ly": 52, "lm": "rover", "ground": [0.62, 0.40, 0.32], "rock": [0.45, 0.26, 0.20], "dens": [0.05, 0.03, 0.0, 0.01],
		"facts": [Lang.t("Jezero mide unos 45 km de diámetro. Hace más de 3.000 millones de años tuvo un lago alimentado por un río, que formó un delta."), Lang.t("El rover Perseverance aterrizó aquí el 18 de febrero de 2021 para buscar señales de vida antigua y guardar muestras de roca.")]},
	{"name": Lang.t("Cráter Gale y Monte Sharp"), "desc": Lang.t("Cráter con una montaña central (Curiosity)"), "kind": "crater", "peak": 0.12, "cx": 94, "cy": 48, "rx": 16, "ry": 12, "lx": 94, "ly": 56, "lm": "rover", "ground": [0.70, 0.46, 0.31], "rock": [0.50, 0.30, 0.20], "dens": [0.05, 0.03, 0.0, 0.01],
		"facts": [Lang.t("Gale mide unos 154 km de diámetro y en su centro se alza el Monte Sharp, de unos 5,5 km de altura sobre el suelo del cráter."), Lang.t("El rover Curiosity aterrizó aquí en agosto de 2012 y halló evidencias de que hubo lagos y arroyos hace miles de millones de años.")]},
	{"name": Lang.t("Valles Marineris"), "desc": Lang.t("El mayor sistema de cañones conocido"), "kind": "canyon", "cx": 62, "cy": 30, "rx": 26, "ry": 7, "lx": 62, "ly": 36, "lm": "plaque", "ground": [0.60, 0.32, 0.22], "rock": [0.40, 0.20, 0.14], "dens": [0.05, 0.05, 0.0, 0.0],
		"facts": [Lang.t("Valles Marineris se extiende unos 4.000 km, una distancia parecida al ancho de Estados Unidos, y llega a unos 6-7 km de profundidad."), Lang.t("Recorre cerca del 20% de la circunferencia de Marte. La sonda Mariner 9 lo descubrió en 1971 y de ahí viene su nombre.")]},
	{"name": Lang.t("Olympus Mons"), "desc": Lang.t("El volcán más alto del Sistema Solar"), "kind": "volcano", "cx": 20, "cy": 16, "rx": 15, "ry": 13, "lx": 20, "ly": 28, "lm": "plaque", "ground": [0.76, 0.50, 0.35], "rock": [0.52, 0.32, 0.22], "dens": [0.06, 0.03, 0.0, 0.0],
		"facts": [Lang.t("Olympus Mons tiene más de 20 km de altura, unas 2,5 veces el Everest, y unos 600 km de ancho."), Lang.t("Es un volcán de escudo con laderas muy suaves, de apenas unos pocos grados de pendiente.")]},
	{"name": Lang.t("Hellas Planitia"), "desc": Lang.t("Enorme cuenca de impacto"), "kind": "basin", "cx": 96, "cy": 72, "rx": 16, "ry": 9, "lx": 96, "ly": 72, "lm": "plaque", "ground": [0.80, 0.60, 0.47], "rock": [0.58, 0.40, 0.30], "dens": [0.04, 0.03, 0.01, 0.0],
		"facts": [Lang.t("Hellas mide unos 2.300 km de diámetro y unos 7 km de profundidad: es la mayor cuenca de impacto bien conservada de Marte."), Lang.t("Se formó hace unos 4.000 millones de años. En su fondo la presión del aire es mayor que en el resto del planeta.")]},
	{"name": Lang.t("Casquete polar norte"), "desc": Lang.t("Capas de hielo de agua y polvo"), "kind": "ice", "cx": 60, "cy": 6, "rx": 38, "ry": 5, "lx": 60, "ly": 6, "lm": "plaque", "ground": [0.88, 0.91, 0.95], "rock": [0.65, 0.70, 0.78], "dens": [0.02, 0.0, 0.14, 0.0],
		"facts": [Lang.t("El casquete polar norte es una pila de capas de hielo de agua y polvo, de hasta unos 3 km de grosor y unos 1.000 km de diámetro."), Lang.t("En invierno se cubre con una capa fina de hielo de dióxido de carbono que se evapora en verano.")]},
	{"name": Lang.t("Restos del cargamento"), "desc": Lang.t("Nave de reabastecimiento (ficción del juego)"), "kind": "wreck", "cx": 60, "cy": 48, "rx": 11, "ry": 8, "lx": 60, "ly": 48, "lm": "wreck", "ground": [0.70, 0.40, 0.27], "rock": [0.45, 0.24, 0.17], "dens": [0.07, 0.02, 0.0, 0.06],
		"facts": [Lang.t("Fragmentos de la nave de reabastecimiento que falló. Es parte de la historia del juego, no un lugar real."), Lang.t("Entre los restos todavía quedan piezas aprovechables.")]}
]

var ENDINGS: Dictionary = {
	"heroes": {"title": Lang.t("Los héroes de Perseo"), "desc": Lang.t("Sistemas estables, tripulación sana y herramientas de sobra. La base de Wilson se estudiará como ejemplo de gestión y de ingenio.")},
	"hilo": {"title": Lang.t("Por un hilo"), "desc": Lang.t("Sobrevivieron, pero un recurso quedó casi en cero. Un día más y habría sido otra historia.")},
	"ingenio": {"title": Lang.t("El ingenio de Wilson"), "desc": Lang.t("Entre herramientas fabricadas y salidas a la superficie, Wilson demostró que improvisar también es una forma de ciencia.")},
	"unidos": {"title": Lang.t("Más que una tripulación"), "desc": Lang.t("La moral y la amistad sostuvieron al equipo cuando los sistemas flaqueaban.")},
	"supervivientes": {"title": Lang.t("Supervivientes"), "desc": Lang.t("Cumplieron la misión: los cuatro siguen con vida cuando llega el rescate.")},
	"fail_oxygen": {"title": Lang.t("Sin aire"), "desc": Lang.t("Te quedaste sin oxígeno. El soporte vital es lo primero que hay que proteger.")},
	"fail_energy": {"title": Lang.t("Apagón total"), "desc": Lang.t("Sin energía, todos los sistemas se apagaron. Sin energía no hay soporte vital.")},
	"fail_food": {"title": Lang.t("Hambruna"), "desc": Lang.t("Se acabó la comida. Producir alimentos en el hábitat es clave para misiones largas.")},
	"fail_water": {"title": Lang.t("Sequía"), "desc": Lang.t("Sin agua no hay vida. Reciclarla es esencial.")},
	"fail_shield": {"title": Lang.t("Radiación letal"), "desc": Lang.t("La radiación enfermó a la tripulación. Fuera de la Tierra no hay protección natural.")},
	"fail_morale": {"title": Lang.t("Colapso moral"), "desc": Lang.t("La moral colapsó. El estado psicológico de la tripulación también es un recurso.")}
}

var ENDING_EPILOGUE: Dictionary = {
	"heroes": Lang.t("Cuando la nave de rescate acopló, Control pidió el informe de la base. Wilson sonrió: «Todo en verde». En la Tierra, los ingenieros estudiaron los registros de Perseo durante años."),
	"hilo": Lang.t("En el último día los indicadores parpadeaban en rojo y nadie dijo nada. Solo cuando sintieron el golpe del acople pudieron respirar. Habían llegado por un hilo."),
	"ingenio": Lang.t("Con chatarra, polímero y circuitos, Wilson convirtió los restos del cargamento en la salvación de la base. En la Tierra lo llamaron «el botánico que arreglaba todo»."),
	"unidos": Lang.t("Cuando fallaba la energía, alguien contaba una historia. Cuando escaseaba la comida, alguien cocinaba con lo que había. Al llegar el rescate, ninguno quería ser el primero en subir."),
	"supervivientes": Lang.t("Treinta días, cuatro personas. Cuando se abrió la escotilla de la nave de rescate, el cansancio era enorme, pero estaban todos."),
	"fail_oxygen": Lang.t("El aire se fue acabando sin hacer ruido. La misión terminó antes de que llegara el rescate."),
	"fail_energy": Lang.t("Una a una, las luces de la base se apagaron. Sin energía, ningún otro sistema pudo seguir funcionando."),
	"fail_food": Lang.t("El invernadero no dio abasto y las raciones se acabaron. La misión terminó antes de que llegara el rescate."),
	"fail_water": Lang.t("Los reciclajes no alcanzaron y los depósitos se vaciaron. La misión terminó antes de que llegara el rescate."),
	"fail_shield": Lang.t("El escudo cedió y la radiación hizo el resto. La tripulación tuvo que ser evacuada demasiado tarde."),
	"fail_morale": Lang.t("Nadie quería seguir. Cuando la moral se rompe, la tripulación deja de cuidar los sistemas que la mantienen viva.")
}

var ENDING_TIP: Dictionary = {
	"fail_oxygen": Lang.t("Para la próxima: repara el soporte vital antes de que el oxígeno baje de 40 y sella las brechas enseguida con un kit de parche."),
	"fail_energy": Lang.t("Para la próxima: mantén los paneles solares, sobre todo antes de la noche y de las tormentas, cuando producen menos."),
	"fail_food": Lang.t("Para la próxima: cultiva en el invernadero con regularidad. Recuerda que consume algo de agua y energía."),
	"fail_water": Lang.t("Para la próxima: recicla agua antes de que se acerque a cero; el invernadero también la consume."),
	"fail_shield": Lang.t("Para la próxima: refuerza el escudo después de llamaradas y brechas. Un escudo bajo también hunde la moral."),
	"fail_morale": Lang.t("Para la próxima: descansa, habla con la tripulación, duerme de noche y fabrica botiquines para las enfermedades.")
}

# Mapa interior: # pared, . piso, P inicio, B cama, D esclusa
# O soporte vital, S solar, G invernadero, W agua, R escudo, C descanso
# T banco de trabajo, A radio, a/k/l = tripulación
const MAP: Array = [
	"################",
	"#O...S...G.T.W.#",
	"#..............#",
	"#......##......#",
	"#.............A#",
	"#..a.......k...#",
	"#R....P.......C#",
	"#..............#",
	"#......B...l...#",
	"#############D##"
]

var stations: Dictionary = {
	"O": {"action": 0}, "S": {"action": 1}, "G": {"action": 2},
	"W": {"action": 3}, "R": {"action": 4}, "C": {"action": 5}
}

var npcs: Dictionary = {
	"a": {
		"who": "Dra. YARISBEL", "suit": Color(1.0, 0.62, 0.3),
		"domain": ["oxygen", "energy", "food", "water", "shield", "morale"],
		"warn": Lang.t("Wilson, el nivel de %s está muy bajo. Prioricemos eso antes de que sea una emergencia."),
		"flavor": [
			Lang.t("Tres acciones por día. Úsalas con cabeza fría."),
			Lang.t("Control confirma que el rescate sigue en camino."),
			Lang.t("La disciplina es lo que mantiene viva a una tripulación.")
		]
	},
	"k": {
		"who": "ENOC", "suit": Color(0.3, 0.8, 0.8),
		"domain": ["oxygen", "energy", "water"],
		"warn": Lang.t("Ojo, Wilson: el nivel de %s está peligrosamente bajo. Los sistemas no perdonan."),
		"flavor": [
			Lang.t("Los sistemas funcionan, aunque hacen ruidos que prefiero no investigar."),
			Lang.t("Si la energía es la sangre de la base, el oxígeno es su pulso."),
			Lang.t("Con un buen banco de trabajo se arregla casi todo.")
		]
	},
	"l": {
		"who": "PAM", "suit": Color(0.85, 0.5, 0.75),
		"domain": ["morale", "food", "shield"],
		"warn": Lang.t("Wilson, me preocupa el nivel de %s. Cuida a la gente antes de que se note."),
		"flavor": [
			Lang.t("Dormir bien también es parte de la misión."),
			Lang.t("Un invernadero vivo hace más por la moral que cualquier discurso."),
			Lang.t("Estoy bien. Un poco cansada, pero bien.")
		]
	}
}

var speaker_colors: Dictionary = {
	"Wilson": Color(0.7, 0.95, 1.0), "Dra. YARISBEL": Color(1.0, 0.7, 0.4),
	"ENOC": Color(0.4, 0.9, 0.9), "PAM": Color(0.95, 0.6, 0.85),
	"Control": Color(0.6, 0.75, 1.0), "Narración": Color(0.75, 0.75, 0.8),
	"Cama": Color(1.0, 0.9, 0.5), "Banco de trabajo": Color(1.0, 0.85, 0.4)
}

var bar_colors: Dictionary = {
	"oxygen": Color(0.4, 0.7, 1.0), "energy": Color(1.0, 0.85, 0.25),
	"food": Color(0.4, 0.85, 0.4), "water": Color(0.3, 0.85, 0.95),
	"shield": Color(0.7, 0.45, 0.95), "morale": Color(1.0, 0.6, 0.35)
}

# estado de partida
var location: String = ""
var day: int = 1
var clock: int = DAY_START
var difficulty: int = 1
var night_acc: int = 0
var slept_tonight: bool = false
var night_warned: bool = false
var awake_min: int = 0
var fatigue_warned: bool = false
var pending_nightmare: Dictionary = {}
var res: Dictionary = {}
var inv: Dictionary = {}
var tools: Dictionary = {}
# ---- mejoras (sistema incremental) ----
const STATION_DRAIN_CUT: float = 0.10   # cada nivel de una estacion reduce 10 % el gasto de su recurso
const STATION_BOOST: float = 0.25       # y aumenta 25 % lo que produce al usarla
const MAX_UPG: int = 3
const STACK_MAT: int = 8
const STACK_TOOL: Dictionary = {"patch": 3, "medkit": 3, "repair": 2, "filter": 2, "map": 1}
const HOLDABLE: Array = ["patch"]
const SUIT_O2_BASE: float = 240.0       # minutos de juego de aire del traje (nivel 0)
const SUIT_O2_PER_LVL: float = 60.0
const STAM_BASE: float = 100.0
const STAM_PER_LVL: float = 35.0
const STAM_DRAIN: float = 10.0          # por segundo corriendo
const STAM_REGEN: float = 8.0
const RES_STATION: Dictionary = {"oxygen": "O", "energy": "S", "food": "G", "water": "W", "shield": "R", "morale": "C"}
const ACTION_STATION: Array = ["O", "S", "G", "W", "R", "C"]
var st_lvl: Dictionary = {"O": 0, "S": 0, "G": 0, "W": 0, "R": 0, "C": 0}
var pack_lvl: int = 0
var suit_lvl_o2: int = 0
var suit_lvl_st: int = 0
var suit_o2: float = 240.0
var suit_warn: int = 0
var stamina: float = 100.0
var exhausted: bool = false
var sprint_frame: bool = false
var held: String = ""
var upg_pending: Dictionary = {}
# obra en curso (la hace ENOC): {ch, left, total, lvl}
var build: Dictionary = {}
var enoc_px: Vector2 = Vector2(-1, -1)
var enoc_work: bool = false
var enoc_move: bool = false
var enoc_dir: Vector2 = Vector2(0, 1)
var enoc_snd: float = 0.0
const ENOC_SPEED: float = 110.0
var pack_ui: Control = null
var bench_ui: Control = null
# minijuegos del banco de trabajo y panel de explicaciones (arriba)
var mg: Control = null
var craft_pending: int = -1
var topinfo: PanelContainer = null
var ti_title: Label = null
var ti_text: RichTextLabel = null
var ti_hint: Label = null
var ti_pages: Array = []
var ti_idx: int = 0
var ti_after: Callable = Callable()
var stats: Dictionary = {}
var depleted: Dictionary = {}
var story_seen: Dictionary = {}
var shown_facts: Dictionary = {}
var talked_today: Dictionary = {}
var storm_left: int = 0
var ill_days: int = 0
var breach: bool = false
var outside: bool = false
var time_acc: float = 0.0
var task_left: float = 0.0
var task_total: float = 1.0
var task_speed: float = 20.0
var task_is_craft: bool = false
var task_kind: String = ""
var nasa: Node = null
var nasa_key: String = "DEMO_KEY"
var learned_day: int = -1
var learn_correct: int = 0

# estado de ejecución
var rng := RandomNumberGenerator.new()
var playing: bool = false
var mode: int = 0 # 0 juego, 1 diálogo, 2 confirmar dormir, 3 pausa, 4 banco de trabajo
var player: Vector2i = Vector2i.ZERO
var player_px: Vector2 = Vector2.ZERO
var facing: Vector2i = Vector2i(0, 1)
var pos_f: Vector2 = Vector2(6.5, 6.5)
var heading: float = PI
var pitch: float = -0.05
var step_dist: float = 0.0
var mouse_sens: float = 1.0
var moving: bool = false
# salto y caida (solo en el exterior)
const JUMP_CLEAR: float = 0.3          # altura (m) desde la que se pasa por encima de rocas y objetos
# Gravedad real en la superficie (NASA, fichas de datos de la Luna y de Marte):
# Luna 1.62 m/s2, Marte 3.73 m/s2. La velocidad de despegue (JUMP_V0) es un valor de juego,
# igual en ambos mundos: el mismo esfuerzo da un salto mas alto y largo en la Luna.
const G_MOON: float = 1.62
const G_MARS: float = 3.73
const JUMP_V0: float = 1.7             # m/s (valor de juego)
const FALL_DEPTH: float = 3.0          # m de profundidad que se cae en un hueco (valor de juego)
const SLOPE_MULT: float = 0.7          # velocidad al caminar por laderas, bordes de crater y montanas
var FALL_TIME: float = 1.1             # segundos de caida: t = raiz(2*profundidad/g), se recalcula al caer
var jump_z: float = 0.0                # altura del salto en metros (negativa al caer)
var jump_vz: float = 0.0
var airborne: bool = false
var fall_t: float = -1.0               # >= 0 mientras cae
var safe_pos: Vector2 = Vector2.ZERO   # ultimo suelo firme, lejos de huecos
var jump_hinted: bool = false
var t_anim: float = 0.0
var flash_t: float = 0.0
var shake_t: float = 0.0
var alarm_t: float = 0.0
var ext_rows: Array = []
var ext_spawn: Vector2i = Vector2i(BASE_X0 + 2, BASE_Y0 + 3)
var zone_ids: PackedByteArray = PackedByteArray()
var explored: PackedByteArray = PackedByteArray()
var zone_ground: Array = []
var zone_rock: Array = []
var zones_seen: Dictionary = {}
var studied: Dictionary = {}
var diary: Dictionary = {}   # zona -> {"seen": [dia, minuto], "study": [dia, minuto]}
var diary_ui: Control = null
var diary_text: RichTextLabel = null
var learned: Dictionary = {} # materiales ya explicados (primera vez)
var cur_zone: int = -1
var zone_banner_t: float = 0.0
var zone_banner_name: String = ""
var zone_banner_desc: String = ""
var mini_img: Image
var mini_tex: ImageTexture
var mini_dirty: bool = false
var mini_view: Control
var map_overlay: Control
var map_canvas: Control
var map_labels: Control
var map_legend: RichTextLabel
var vp3d: SubViewport
var view3d = null
var view3d_on: bool = true
var v3_check: CheckButton
var cam_mode: int = 0
var cam_opt: OptionButton
var cam_banner_t: float = 0.0
var ui = null
var in_menu: bool = true
var menu_loc: String = "Luna"
var preview_built: String = ""
var display_mode: int = 0
var win_idx: int = -1
var ui_scale_idx: int = 1
var vsync_on: bool = true
var show_fps: bool = false
var quality: int = 2          # 0 Baja, 1 Media, 2 Alta, 3 Personalizada
var tex_quality: int = 2
var shadow_q: int = 2         # 0 apagadas, 1 bajas, 2 altas
var aa_mode: int = 2          # 0 apagado, 1 MSAA 2x, 2 MSAA 4x
var render_scale: float = 1.0 # 0.5 - 1.0
var fps_idx: int = 0          # indice en FPS_CAPS
var fx_idx: int = 2           # efectos/particulas: 0 pocos, 1 medios, 2 todos
var sky_idx: int = 2          # estrellas
var glow_on: bool = true
var haze_on: bool = true
var bright: float = 1.0       # 0.8 - 1.2
const FPS_CAPS: Array = [0, 30, 60, 120]
const FX_FACTOR: Array = [0.3, 0.6, 1.0]
const STAR_COUNTS: Array = [350, 800, 1500]
const PRESETS: Array = [
	{"shadow_q": 0, "aa_mode": 0, "render_scale": 0.6, "fps_idx": 0, "fx_idx": 0, "sky_idx": 0, "glow_on": false, "haze_on": false, "tex_quality": 0},
	{"shadow_q": 1, "aa_mode": 1, "render_scale": 0.85, "fps_idx": 0, "fx_idx": 1, "sky_idx": 1, "glow_on": false, "haze_on": true, "tex_quality": 1},
	{"shadow_q": 2, "aa_mode": 2, "render_scale": 1.0, "fps_idx": 0, "fx_idx": 2, "sky_idx": 2, "glow_on": true, "haze_on": true, "tex_quality": 2}]
var shadows_on: bool = true
var auto_quality: bool = true # baja la calidad sola si el juego va lento (ver _perf_check)
var perf_t: float = 0.0
var perf_n: int = 0
var perf_skip: float = 6.0
var perf_drops: int = 0
var history: Array = []
const WIN_PRESETS: Array = [Vector2i(1100, 650), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]
const UI_SCALES: Array = [0.85, 1.0]
var CAM_NAMES: Array = [Lang.t("Tercera persona"), Lang.t("Primera persona"), Lang.t("Detrás del personaje"), Lang.t("Vista aérea")]

# diálogo
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: RichTextLabel
var dlg_hint: Label
var dlg_queue: Array = []
var dlg_after: Callable = Callable()
var typing: bool = false
var type_pos: float = 0.0
var type_total: int = 0
var last_blip: int = 0
var choice_active: bool = false
var choice_data: Array = []

# pausa / opciones
var pause_overlay: Control
var pause_title: Label
var pause_msg: Label
var help_box: RichTextLabel
var btn_continue: Button
var btn_save: Button
var btn_menu: Button
var fs_check: CheckButton
var diff_option: OptionButton
var pause_from_game: bool = true

# ajustes
var music_vol: float = 0.8
var sfx_vol: float = 0.8
var fullscreen: bool = false
var endings_seen: Array = []

# audio
var music: AudioStreamPlayer
var sfx_pool: Array = []
var sfx_idx: int = 0
var sfx_cache: Dictionary = {}
var current_music: String = ""
var music_fade: Tween
var muted: bool = false

# UI de juego
var root_box: VBoxContainer
var root_margin: MarginContainer
var ending_art: Control
var ending_active: bool = false
var show_tutorial: bool = true
var easy_read: bool = false
var ach_done: Dictionary = {}
var tut: Control = null
var bars: Dictionary = {}
var header: Label
var inv_label: Label
var inv_icons: Control
var log_box: RichTextLabel
var map_view: Control


func _ready() -> void:
	rng.randomize()
	_load_settings()
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	root_margin = margin
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)
	_build_dialog()
	_build_topinfo()
	_build_minigames()
	_build_pack()
	_build_bench()
	_build_pause()
	_setup_audio()
	_apply_volumes()
	nasa = (load("res://nasa_data.gd") as GDScript).new() as Node
	nasa.set("key", nasa_key)
	add_child(nasa)
	nasa.connect("updated", _on_nasa_updated)
	_build_world_map_ui()
	_build_diary_ui()
	_build_tutor()
	vp3d = SubViewport.new()
	vp3d.size = Vector2i(960, 600)
	vp3d.own_world_3d = true
	vp3d.msaa_3d = Viewport.MSAA_4X
	vp3d.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp3d)
	view3d = Node3D.new()
	view3d.set_script(load("res://view3d.gd"))
	view3d.game = self
	vp3d.add_child(view3d)
	ui = Node.new()
	ui.set_script(load("res://ui_pages.gd"))
	ui.game = self
	add_child(ui)
	ui.build_all()
	_init_window()
	_apply_quality()
	get_window().size_changed.connect(_on_window_resized)
	_show_menu()
	if _is_web():
		_web_ready()


func _web_ready() -> void:
	# Avisa a la pagina web (web_shell.html) de que el menu ya esta listo: quita la pantalla de carga.
	await get_tree().process_frame
	await get_tree().process_frame
	JavaScriptBridge.eval("if (window.perseoReady) { window.perseoReady(); }", true)


# ---------- AJUSTES ----------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		# primera ejecucion en el navegador: calidad Media (WebGL y equipos escolares suelen ir justos)
		if _is_web():
			quality = 1
			for k in PRESETS[1]:
				set(k, PRESETS[1][k])
		return
	music_vol = float(cfg.get_value("audio", "music", 0.8))
	sfx_vol = float(cfg.get_value("audio", "sfx", 0.8))
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	display_mode = clampi(int(cfg.get_value("video", "display_mode", 1 if fullscreen else 0)), 0, 2)
	win_idx = clampi(int(cfg.get_value("video", "win_idx", -1)), -1, WIN_PRESETS.size() - 1)
	ui_scale_idx = clampi(int(cfg.get_value("video", "ui_scale", 1)), 0, UI_SCALES.size() - 1)
	vsync_on = bool(cfg.get_value("video", "vsync", true))
	show_fps = bool(cfg.get_value("video", "show_fps", false))
	quality = clampi(int(cfg.get_value("video", "quality", 2)), 0, 3)
	tex_quality = clampi(int(cfg.get_value("video", "tex_quality", 2)), 0, 2)
	shadow_q = clampi(int(cfg.get_value("video", "shadow_q", 2)), 0, 2)
	aa_mode = clampi(int(cfg.get_value("video", "aa_mode", 2)), 0, 2)
	render_scale = clampf(float(cfg.get_value("video", "render_scale", 1.0)), 0.5, 1.0)
	fps_idx = clampi(int(cfg.get_value("video", "fps_idx", 0)), 0, FPS_CAPS.size() - 1)
	fx_idx = clampi(int(cfg.get_value("video", "fx_idx", 2)), 0, 2)
	sky_idx = clampi(int(cfg.get_value("video", "sky_idx", 2)), 0, 2)
	glow_on = bool(cfg.get_value("video", "glow_on", true))
	haze_on = bool(cfg.get_value("video", "haze_on", true))
	bright = clampf(float(cfg.get_value("video", "bright", 1.0)), 0.8, 1.2)
	difficulty = clampi(int(cfg.get_value("game", "difficulty", 1)), 0, DIFFICULTIES.size() - 1)
	view3d_on = bool(cfg.get_value("video", "view3d", true))
	cam_mode = clampi(int(cfg.get_value("video", "cam_mode", 0)), 0, 3)
	mouse_sens = clampf(float(cfg.get_value("game", "mouse_sens", 1.0)), 0.3, 2.0)
	show_tutorial = bool(cfg.get_value("game", "tutorial", true))
	easy_read = bool(cfg.get_value("game", "easy_read", false))
	var ach: Variant = cfg.get_value("game", "achievements", [])
	if ach is Array:
		for a in ach:
			ach_done[str(a)] = true
	auto_quality = bool(cfg.get_value("video", "auto_quality", true))
	if str(cfg.get_value("game", "lang", "")) in ["es", "en"]:
		Lang.code = str(cfg.get_value("game", "lang"))
	nasa_key = str(cfg.get_value("nasa", "key", "DEMO_KEY"))
	var e: Variant = cfg.get_value("game", "endings", [])
	if e is Array:
		endings_seen = e


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_vol)
	cfg.set_value("audio", "sfx", sfx_vol)
	cfg.set_value("video", "fullscreen", display_mode == 1)
	cfg.set_value("video", "display_mode", display_mode)
	cfg.set_value("video", "win_idx", win_idx)
	cfg.set_value("video", "ui_scale", ui_scale_idx)
	cfg.set_value("video", "vsync", vsync_on)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "auto_quality", auto_quality)
	cfg.set_value("video", "tex_quality", tex_quality)
	cfg.set_value("video", "shadow_q", shadow_q)
	cfg.set_value("video", "aa_mode", aa_mode)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "fps_idx", fps_idx)
	cfg.set_value("video", "fx_idx", fx_idx)
	cfg.set_value("video", "sky_idx", sky_idx)
	cfg.set_value("video", "glow_on", glow_on)
	cfg.set_value("video", "haze_on", haze_on)
	cfg.set_value("video", "bright", bright)
	cfg.set_value("video", "view3d", view3d_on)
	cfg.set_value("video", "cam_mode", cam_mode)
	cfg.set_value("game", "mouse_sens", mouse_sens)
	cfg.set_value("game", "tutorial", show_tutorial)
	cfg.set_value("game", "easy_read", easy_read)
	cfg.set_value("game", "achievements", ach_done.keys())
	cfg.set_value("game", "lang", Lang.code)
	cfg.set_value("nasa", "key", nasa_key)
	cfg.set_value("game", "endings", endings_seen)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.save(SETTINGS_PATH)


func _set_fullscreen(on: bool) -> void:
	_set_display_mode(1 if on else 0)


func _perf_check(delta: float) -> void:
	# Mide los FPS reales en ventanas de 4 s; si van por debajo de 22 baja un escalon la calidad
	# (Alta -> Media -> Baja). Solo con un preset activo y si la opcion esta marcada.
	if not auto_quality or quality <= 0 or quality >= 3 or perf_drops >= 2:
		return
	if perf_skip > 0.0:
		perf_skip -= delta
		return
	if delta > 0.5 or not get_window().has_focus():
		perf_t = 0.0
		perf_n = 0
		return
	perf_t += delta
	perf_n += 1
	if perf_t < 4.0:
		return
	var fps: float = float(perf_n) / perf_t
	perf_t = 0.0
	perf_n = 0
	if fps < 22.0:
		perf_drops += 1
		_set_quality(quality - 1)
		var names: Array = [Lang.t("Baja"), Lang.t("Media"), Lang.t("Alta")]
		_log(Lang.t("[color=orange]Rendimiento bajo (%d FPS): calidad gráfica bajada a «%s». Puedes cambiarla en Opciones.[/color]") % [int(fps), names[quality]])


func _notification(what: int) -> void:
	# En escritorio, con la ventana en segundo plano se limita a 15 FPS para no gastar bateria.
	if _is_web():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = 15
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Engine.max_fps = int(FPS_CAPS[fps_idx])


func _is_web() -> bool:
	return OS.has_feature("web")


func _headless() -> bool:
	# true cuando no se puede controlar la ventana (sin pantalla o dentro del navegador)
	return DisplayServer.get_name() == "headless" or OS.has_feature("web")


func _screen_rect() -> Rect2i:
	var sc: int = DisplayServer.window_get_current_screen()
	return Rect2i(DisplayServer.screen_get_position(sc), DisplayServer.screen_get_size(sc))


func _usable_rect() -> Rect2i:
	var sc: int = DisplayServer.window_get_current_screen()
	var r: Rect2i = DisplayServer.screen_get_usable_rect(sc)
	if r.size.x < 200 or r.size.y < 200:
		return _screen_rect()
	return r


func _usable_size() -> Vector2i:
	return _usable_rect().size


func _screen_size() -> Vector2i:
	return _screen_rect().size


func _init_window() -> void:
	var w: Window = get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.content_scale_size = Vector2i(1100, 650)
	w.min_size = Vector2i(960, 560)
	w.content_scale_factor = UI_SCALES[ui_scale_idx]
	_apply_display()


func _apply_window_size() -> void:
	if _headless():
		return
	var w: Window = get_window()
	var u: Rect2i = _usable_rect()
	var target: Vector2i = Vector2i(int(float(u.size.x) * 0.82), int(float(u.size.y) * 0.82))
	if win_idx >= 0 and win_idx < WIN_PRESETS.size():
		target = WIN_PRESETS[win_idx]
	target.x = clampi(target.x, 960, maxi(u.size.x, 960))
	target.y = clampi(target.y, 560, maxi(u.size.y, 560))
	w.size = target
	w.position = u.position + (u.size - target) / 2


func _apply_display() -> void:
	fullscreen = display_mode == 1
	if _is_web():
		# en el navegador solo se alterna pantalla completa (requiere un clic del usuario)
		get_window().mode = Window.MODE_FULLSCREEN if display_mode == 1 else Window.MODE_WINDOWED
		return
	if _headless():
		return
	var w: Window = get_window()
	match display_mode:
		1:
			w.borderless = false
			w.mode = Window.MODE_FULLSCREEN
		2:
			w.mode = Window.MODE_WINDOWED
			w.borderless = true
			var r: Rect2i = _screen_rect()
			w.position = r.position
			w.size = r.size
		_:
			w.mode = Window.MODE_WINDOWED
			w.borderless = false
			_apply_window_size()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)


func _set_display_mode(i: int) -> void:
	display_mode = clampi(i, 0, 2)
	_apply_display()
	if ui != null:
		ui.sync_options()
	_save_settings()


func _set_win_idx(i: int) -> void:
	win_idx = i
	if display_mode == 0:
		_apply_window_size()
	if ui != null:
		ui.update_screen_info()
	_save_settings()


func _set_ui_scale(i: int) -> void:
	ui_scale_idx = clampi(i, 0, UI_SCALES.size() - 1)
	get_window().content_scale_factor = UI_SCALES[ui_scale_idx]
	_save_settings()


func _set_vsync(on: bool) -> void:
	vsync_on = on
	if not _headless():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	_save_settings()


func _set_quality(i: int) -> void:
	# preset: 0 Baja, 1 Media, 2 Alta (3 = Personalizada, no cambia nada)
	quality = clampi(i, 0, 3)
	if quality < 3:
		var pr: Dictionary = PRESETS[quality]
		for k in pr:
			set(k, pr[k])
		if view3d != null and is_instance_valid(view3d) and view3d.exterior != null:
			view3d.apply_textures()
	_apply_quality()
	_save_settings()


func _set_gfx(key: String, value: Variant) -> void:
	# cambia un ajuste individual y detecta si coincide con un preset
	set(key, value)
	quality = 3
	for pi in PRESETS.size():
		var same: bool = true
		for k in PRESETS[pi]:
			if not is_equal_approx(float(get(k)), float(PRESETS[pi][k])):
				same = false
				break
		if same:
			quality = pi
	if key == "tex_quality" and view3d != null and is_instance_valid(view3d) and view3d.exterior != null:
		view3d.apply_textures()
	_apply_quality()
	_save_settings()
	if ui != null:
		ui.sync_options()


func _set_tex_quality(i: int) -> void:
	_set_gfx("tex_quality", clampi(i, 0, 2))


func _apply_quality() -> void:
	shadows_on = shadow_q > 0
	if vp3d != null:
		vp3d.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][aa_mode]
	Engine.max_fps = int(FPS_CAPS[fps_idx])
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][shadow_q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][shadow_q])
	_fit_viewports()
	if view3d != null and is_instance_valid(view3d) and view3d.has_method("apply_gfx"):
		view3d.apply_gfx()


func _mv() -> Vector2:
	if map_view != null and is_instance_valid(map_view) and map_view.size.x > 8.0 and map_view.size.y > 8.0:
		return map_view.size
	return Vector2(VIEW_W * TILE, VIEW_H * TILE)


func _fit_viewports() -> void:
	if vp3d == null:
		return
	var base: Vector2 = size if in_menu else _mv()
	var sc: float = render_scale
	var nw: int = maxi(int(base.x * sc), 320)
	var nh: int = maxi(int(base.y * sc), 200)
	if vp3d.size != Vector2i(nw, nh):
		vp3d.size = Vector2i(nw, nh)


func _on_window_resized() -> void:
	_fit_viewports()
	if ui != null:
		ui.update_screen_info()


func _on_map_resized() -> void:
	_fit_viewports()
	if mini_view != null and is_instance_valid(mini_view):
		mini_view.position = Vector2(_mv().x - mini_view.size.x - 8.0, 8.0)


func _reset_options() -> void:
	display_mode = 0
	win_idx = -1
	ui_scale_idx = 1
	vsync_on = true
	show_fps = false
	quality = 2
	auto_quality = true
	perf_drops = 0
	for k in PRESETS[2]:
		set(k, PRESETS[2][k])
	bright = 1.0
	music_vol = 0.8
	sfx_vol = 0.8
	mouse_sens = 1.0
	view3d_on = true
	cam_mode = 0
	get_window().content_scale_factor = UI_SCALES[ui_scale_idx]
	_apply_display()
	_apply_quality()
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	if music != null:
		music.volume_db = -9.0 + linear_to_db(maxf(music_vol, 0.0001))


# ---------- AUDIO ----------

func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music.finished.connect(_on_music_finished)
	add_child(music)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)


func _load_wav(nm: String) -> AudioStream:
	if sfx_cache.has(nm):
		return sfx_cache[nm]
	var path: String = "res://audio/%s.wav" % nm
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	sfx_cache[nm] = s
	return s


func _sfx(nm: String, db: float = -4.0) -> void:
	if sfx_vol <= 0.001:
		return
	var s: AudioStream = _load_wav(nm)
	if s == null:
		return
	var p: AudioStreamPlayer = sfx_pool[sfx_idx]
	sfx_idx = (sfx_idx + 1) % sfx_pool.size()
	p.stream = s
	p.volume_db = db + linear_to_db(sfx_vol)
	p.play()


func _wanted_music() -> String:
	var sfx_loc: String = "moon" if location == "Luna" else "mars"
	if not outside:
		return "music_" + sfx_loc # base: tema calmado
	if _is_night_clock():
		return "music_night_" + sfx_loc # exterior de noche: ritmo mas rapido
	return "music_day_" + sfx_loc # exterior de dia: calmado, con otro color


func _music_db() -> float:
	return -9.0 + linear_to_db(maxf(music_vol, 0.0001))


func _play_music(nm: String) -> void:
	if nm == current_music:
		return
	current_music = nm
	if music_fade != null and music_fade.is_valid():
		music_fade.kill()
	var s: AudioStream = _load_wav(nm)
	if s == null:
		music.stop()
		return
	if music.playing and music_vol > 0.001 and is_inside_tree():
		music_fade = create_tween()
		music_fade.tween_property(music, "volume_db", -50.0, 0.35)
		music_fade.tween_callback(_swap_music.bind(s))
		music_fade.tween_property(music, "volume_db", _music_db(), 0.8)
	else:
		music.volume_db = _music_db()
		music.stream = s
		music.play()


func _swap_music(s: AudioStream) -> void:
	music.stream = s
	music.play()


func _on_music_finished() -> void:
	if current_music != "":
		music.play()


# ---------- UI BASE ----------

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _panel_style() -> StyleBoxFlat:
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.09, 0.1, 0.17)
	ps.set_corner_radius_all(10)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.25, 0.3, 0.5)
	ps.set_content_margin_all(12)
	return ps


func _build_dialog() -> void:
	dlg = PanelContainer.new()
	var st: StyleBoxFlat = _panel_style()
	st.bg_color = Color(0.05, 0.06, 0.12, 0.96)
	st.border_color = Color(0.5, 0.7, 1.0)
	dlg.add_theme_stylebox_override("panel", st)
	dlg.anchor_left = 0.0
	dlg.anchor_right = 1.0
	dlg.anchor_top = 1.0
	dlg.anchor_bottom = 1.0
	dlg.offset_left = 24.0
	dlg.offset_right = -24.0
	dlg.offset_top = -190.0
	dlg.offset_bottom = -20.0
	dlg.visible = false
	add_child(dlg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	dlg.add_child(v)
	dlg_name = Label.new()
	dlg_name.add_theme_font_size_override("font_size", 20)
	v.add_child(dlg_name)
	dlg_text = RichTextLabel.new()
	dlg_text.bbcode_enabled = true
	dlg_text.add_theme_font_size_override("normal_font_size", 18)
	dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dlg_text.custom_minimum_size = Vector2(0, 80)
	v.add_child(dlg_text)
	dlg_hint = Label.new()
	dlg_hint.add_theme_font_size_override("font_size", 14)
	dlg_hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	v.add_child(dlg_hint)


func _build_pack() -> void:
	pack_ui = Control.new()
	pack_ui.set_script(load("res://backpack.gd"))
	pack_ui.set("game", self)
	pack_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	pack_ui.z_index = 58
	add_child(pack_ui)
	pack_ui.connect("closed", _on_pack_closed)


func _build_bench() -> void:
	bench_ui = Control.new()
	bench_ui.set_script(load("res://workbench.gd"))
	bench_ui.set("game", self)
	bench_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	bench_ui.z_index = 58
	add_child(bench_ui)
	bench_ui.connect("closed", _on_bench_closed)


func _on_bench_closed() -> void:
	if mode == 4:
		mode = 0


func _open_pack() -> void:
	if mode != 0 or airborne or fall_t >= 0.0:
		return
	mode = 10
	pack_ui.call("open")


func _on_pack_closed() -> void:
	if mode == 10:
		mode = 0


func _build_minigames() -> void:
	mg = Control.new()
	mg.set_script(load("res://minigames.gd"))
	mg.set("game", self)
	mg.set_anchors_preset(Control.PRESET_FULL_RECT)
	mg.z_index = 60
	add_child(mg)
	mg.connect("done", _on_mg_done)


func _build_topinfo() -> void:
	topinfo = PanelContainer.new()
	var st: StyleBoxFlat = _panel_style()
	st.bg_color = Color(0.06, 0.07, 0.14, 0.97)
	st.border_color = Color(1.0, 0.82, 0.3)
	st.set_border_width_all(3)
	st.set_content_margin_all(16)
	topinfo.add_theme_stylebox_override("panel", st)
	topinfo.anchor_left = 0.0
	topinfo.anchor_right = 1.0
	topinfo.anchor_top = 0.0
	topinfo.anchor_bottom = 0.0
	topinfo.offset_left = 70.0
	topinfo.offset_right = -70.0
	topinfo.offset_top = 14.0
	topinfo.mouse_filter = Control.MOUSE_FILTER_STOP
	topinfo.z_index = 55
	topinfo.visible = false
	topinfo.gui_input.connect(_topinfo_gui)
	add_child(topinfo)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	topinfo.add_child(v)
	ti_title = Label.new()
	ti_title.add_theme_font_size_override("font_size", 24)
	ti_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	v.add_child(ti_title)
	ti_text = RichTextLabel.new()
	ti_text.bbcode_enabled = true
	ti_text.fit_content = true
	ti_text.scroll_active = false
	ti_text.add_theme_font_size_override("normal_font_size", 20)
	ti_text.custom_minimum_size = Vector2(0, 60)
	v.add_child(ti_text)
	ti_hint = Label.new()
	ti_hint.add_theme_font_size_override("font_size", 15)
	ti_hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95))
	v.add_child(ti_hint)


# Explicacion arriba de la pantalla (paginas). Pausa el juego hasta cerrarla.
func _top_info(title: String, pages: Array, after: Callable = Callable()) -> void:
	if pages.is_empty():
		if after.is_valid():
			after.call()
		return
	ti_pages = pages.duplicate()
	ti_idx = 0
	ti_after = after
	ti_title.text = Lang.t("¡Nuevo!") + "  " + title
	mode = 8
	dlg.visible = false
	topinfo.visible = true
	_ti_show()
	_sfx("next", -8.0)
	topinfo.offset_top = -160.0
	var tw: Tween = create_tween()
	tw.tween_property(topinfo, "offset_top", 14.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ti_show() -> void:
	ti_text.text = str(ti_pages[ti_idx])
	ti_hint.text = Lang.t("[E] / clic: continuar   ·   [Esc]: saltar") + ("      " + Lang.t("%d de %d") % [ti_idx + 1, ti_pages.size()] if ti_pages.size() > 1 else "")
	topinfo.size.y = 0.0
	topinfo.call_deferred("set_size", Vector2(topinfo.size.x, 0.0))


func _ti_next(skip: bool = false) -> void:
	ti_idx += 1
	if skip or ti_idx >= ti_pages.size():
		topinfo.visible = false
		mode = 0
		var cb: Callable = ti_after
		ti_after = Callable()
		if cb.is_valid():
			cb.call()
		return
	_sfx("next", -8.0)
	_ti_show()


func _topinfo_gui(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mode == 8:
		_ti_next()


func _input_topinfo(k: InputEventKey) -> void:
	if k.keycode == KEY_ESCAPE:
		_ti_next(true)
	elif k.keycode == KEY_E or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE:
		_ti_next()


func _slider_row(text: String, val: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := _label(text, 16)
	l.custom_minimum_size = Vector2(130, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 24)
	s.value_changed.connect(cb)
	row.add_child(s)
	return row


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _build_pause() -> void:
	pause_overlay = Control.new()
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	add_child(pause_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	pause_title = _label(Lang.t("PAUSA"), 30)
	v.add_child(pause_title)
	v.add_child(HSeparator.new())
	btn_continue = _button(Lang.t("Continuar"), _close_pause)
	v.add_child(btn_continue)
	v.add_child(_button(Lang.t("Controles  (F1)"), _on_pause_controls))
	v.add_child(_button(Lang.t("Estadísticas  (F2)"), _on_pause_stats))
	v.add_child(_button(Lang.t("Opciones"), _on_pause_options))
	v.add_child(_button(Lang.t("Aprende · datos NASA"), _on_pause_learn))
	v.add_child(_button(Lang.t("Repetir tutorial guiado"), _on_pause_tutorial))
	v.add_child(_button(Lang.t("Reglas del juego"), _on_help_pressed))
	help_box = RichTextLabel.new()
	help_box.bbcode_enabled = true
	help_box.add_theme_font_size_override("normal_font_size", 14)
	help_box.custom_minimum_size = Vector2(0, 170)
	help_box.visible = false
	help_box.text = _help_text()
	v.add_child(help_box)
	btn_save = _button(Lang.t("Guardar partida"), _on_save_pressed)
	v.add_child(btn_save)
	btn_menu = _button(Lang.t("Guardar y salir al menú"), _on_pause_menu)
	v.add_child(btn_menu)
	pause_msg = _label("", 14)
	v.add_child(pause_msg)


func _help_text() -> String:
	return Lang.t("[b]Objetivo:[/b] sobrevive %d días hasta que llegue el rescate.\n[b]Reloj:[/b] el tiempo corre solo (1 hora de juego cada 60 s) y se pausa en diálogos y menús. Las tareas aceleran el tiempo: estaciones x20 y fabricar o mejorar x40.\n[b]Noche:[/b] desde las 20:00. Si sigues despierto bajan la energía y la moral, y pueden ocurrir situaciones incómodas. Duerme en la cama desde las 18:00 hasta las 06:00 (a veces hay pesadillas). Si no duermes te desplomas a las 06:00; tras 16 h despierto tus acciones rinden menos.\n[b]Exterior:[/b] la esclusa da a un mundo amplio con zonas reales, sin límite de pasos. Las placas (E) dan datos reales y +3 de moral. Fabrica el Mapa de navegación para usar Tab y el minimapa. El material reaparece tras %d días.\n[b]Herramientas:[/b] banco de trabajo. Parche: sella brechas (generador de escudo). Botiquín: cura enfermedad (habla con PAM). Reparador: reduce fallas eléctricas. Filtro: reduce tormentas de polvo.\n[b]Alerta roja:[/b] una brecha drena oxígeno hasta sellarla.\n[b]Controles:[/b] pulsa F1.") % [MAX_DAYS, NODE_RESPAWN_DAYS]


func _on_cam_selected(i: int) -> void:
	_set_cam_mode(i)


func _set_cam_mode(i: int) -> void:
	cam_mode = clampi(i, 0, CAM_NAMES.size() - 1)
	if cam_opt != null:
		cam_opt.select(cam_mode)
	cam_banner_t = 2.2
	_save_settings()


func _cycle_cam() -> void:
	_set_cam_mode((cam_mode + 1) % CAM_NAMES.size())
	_log(Lang.t("Cámara: %s.") % CAM_NAMES[cam_mode])


func _rel_controls() -> bool:
	return view3d_on and view3d != null and (cam_mode == 1 or cam_mode == 2)


func _set_player_tile(t: Vector2i, face: Vector2i = Vector2i(0, -1)) -> void:
	player = t
	pos_f = Vector2(float(t.x) + 0.5, float(t.y) + 0.5)
	player_px = Vector2(t * TILE)
	facing = face
	heading = atan2(-float(face.x), -float(face.y))
	moving = false
	step_dist = 0.0
	_reset_jump()


func _cardinal_of(h: float) -> Vector2i:
	var f: Vector2 = Vector2(-sin(h), -cos(h))
	if absf(f.x) > absf(f.y):
		return Vector2i(1 if f.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if f.y > 0.0 else -1)


func _can_stand(p: Vector2) -> bool:
	var air: bool = jump_z >= JUMP_CLEAR
	for ox in [-PLAYER_R, PLAYER_R]:
		for oy in [-PLAYER_R, PLAYER_R]:
			var tx: int = floori(p.x + ox)
			var ty: int = floori(p.y + oy)
			var ch: String = _tile(Vector2i(tx, ty))
			if ch == "." or ch == "P" or ch == "X":
				continue
			# fuera, el relieve (bordes de crater, montanas, volcan, paredes de valle) se puede escalar;
			# solo el borde del mundo bloquea
			if ch == "#" and outside and tx > 0 and ty > 0 and tx < EXT_W - 1 and ty < EXT_H - 1:
				continue
			# en el aire se pasa por encima de rocas, vetas, hielo y cristales
			if air and (ch == "r" or ch == "m" or ch == "i" or ch == "c"):
				continue
			# una veta, hielo o cargamento ya recogido deja de bloquear el paso
			if (ch == "m" or ch == "i" or ch == "c") and _is_depleted(floori(p.x + ox), floori(p.y + oy)):
				continue
			return false
	return true


# ---------- salto y caida ----------

func _jump_params() -> Vector2:
	# (velocidad inicial en m/s, gravedad real en m/s2): en la Luna el mismo salto llega mas alto y dura mas
	return Vector2(JUMP_V0, G_MOON if location == "Luna" else G_MARS)


func _start_jump() -> void:
	if not outside or airborne or fall_t >= 0.0 or mode != 0:
		return
	var jp: Vector2 = _jump_params()
	airborne = true
	jump_vz = jp.x
	_sfx("jump", -8.0)


func _reset_jump() -> void:
	jump_z = 0.0
	jump_vz = 0.0
	airborne = false
	fall_t = -1.0
	safe_pos = pos_f


func _tile_is_pit(p: Vector2) -> bool:
	# solo cuenta como hueco cuando estas bien adentro: las cuatro esquinas a 0,4 casillas tambien son hueco
	# (el borde se puede pisar; asi no caes antes de llegar al centro oscuro)
	for ox in [-0.4, 0.4]:
		for oy in [-0.4, 0.4]:
			if _tile(Vector2i(floori(p.x + ox), floori(p.y + oy))) != "X":
				return false
	return true


func _nearest_standable(p: Vector2) -> Vector2:
	var best: Vector2 = safe_pos
	var best_d: float = 1e9
	var r: float = 0.0
	while r <= 3.0:
		for k in 16:
			var an: float = TAU * float(k) / 16.0
			var q: Vector2 = p + Vector2(cos(an), sin(an)) * r
			if _can_stand(q) and not _tile_is_pit(q):
				var d: float = q.distance_to(p)
				if d < best_d:
					best_d = d
					best = q
		if best_d < 1e8:
			break
		r += 0.25
	return best


func _start_fall() -> void:
	FALL_TIME = sqrt(2.0 * FALL_DEPTH / _jump_params().y)
	fall_t = 0.0
	airborne = false
	jump_vz = 0.0
	moving = false
	shake_t = 0.5
	_sfx("fall", -6.0)


func _update_jump(delta: float) -> void:
	if not playing or not outside:
		if jump_z != 0.0 or airborne or fall_t >= 0.0:
			_reset_jump()
		return
	if fall_t >= 0.0:
		fall_t += delta
		jump_z = -0.5 * _jump_params().y * fall_t * fall_t
		if fall_t >= FALL_TIME:
			pos_f = safe_pos
			player = Vector2i(floori(pos_f.x), floori(pos_f.y))
			player_px = (pos_f - Vector2(0.5, 0.5)) * float(TILE)
			jump_z = 0.0
			fall_t = -1.0
			flash_t = 0.6
			stats["falls"] = int(stats.get("falls", 0)) + 1
			_add("morale", -3)
			_add("energy", -2)
			_log(Lang.t("[color=orange]Caíste en un hueco y volviste al último suelo firme. Salta con [Espacio] para cruzarlos.[/color]"))
			_refresh()
		return
	if airborne:
		var jp: Vector2 = _jump_params()
		jump_vz -= jp.y * delta
		jump_z += jump_vz * delta
		if jump_z <= 0.0:
			jump_z = 0.0
			airborne = false
			jump_vz = 0.0
			if _tile_is_pit(pos_f):
				_start_fall()
				return
			if not _can_stand(pos_f):
				pos_f = _nearest_standable(pos_f)
				player = Vector2i(floori(pos_f.x), floori(pos_f.y))
				player_px = (pos_f - Vector2(0.5, 0.5)) * float(TILE)
			_sfx("step", -9.0)
		return
	# si un material se renueva justo bajo tus pies, te saca al suelo libre mas cercano
	if not _can_stand(pos_f):
		pos_f = _nearest_standable(pos_f)
		player = Vector2i(floori(pos_f.x), floori(pos_f.y))
		player_px = (pos_f - Vector2(0.5, 0.5)) * float(TILE)
	# en el suelo: si el centro pisa un hueco, cae; si no, recuerda el suelo firme
	if _tile_is_pit(pos_f):
		_start_fall()
		return
	if moving or pos_f.distance_to(safe_pos) > 1.0:
		var near_pit: bool = false
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if _tile(Vector2i(floori(pos_f.x) + ox, floori(pos_f.y) + oy)) == "X":
					near_pit = true
		if not near_pit and _can_stand(pos_f):
			safe_pos = pos_f


# vector de deseo (en coordenadas del mapa) segun el modo de control
func _wish_vector(fwd: float, strafe: float, ax: float, ay: float) -> Vector2:
	if _rel_controls():
		var fv: Vector2 = Vector2(-sin(heading), -cos(heading))
		var rv: Vector2 = Vector2(-fv.y, fv.x)
		return fv * fwd + rv * strafe
	return Vector2(ax, ay)


func _move_player(delta: float, wish: Vector2, sprint: bool) -> void:
	if wish.length() < 0.01:
		moving = false
		return
	var dirv: Vector2 = wish.normalized()
	if not _rel_controls():
		var th: float = atan2(-dirv.x, -dirv.y)
		heading = lerp_angle(heading, th, 1.0 - exp(-16.0 * delta))
	var spr: bool = sprint
	if outside and (exhausted or stamina <= 0.0):
		spr = false
	var speed: float = MOVE_TPS * (SPRINT_MULT if spr else 1.0)
	if outside and _tile(player) == "#":
		speed *= SLOPE_MULT
	var dist: float = speed * delta
	var n: int = maxi(int(ceil(dist / 0.15)), 1)
	var sub: Vector2 = dirv * dist / float(n)
	var start: Vector2 = pos_f
	for i in n:
		if _can_stand(Vector2(pos_f.x + sub.x, pos_f.y)):
			pos_f.x += sub.x
		if _can_stand(Vector2(pos_f.x, pos_f.y + sub.y)):
			pos_f.y += sub.y
	var moved: float = pos_f.distance_to(start)
	if spr and outside and moved > 0.0:
		sprint_frame = true
		stamina -= STAM_DRAIN * delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			_log(Lang.t("[color=orange]Te quedaste sin aliento: camina un momento para recuperar el aguante.[/color]"))
	stats["distance"] += moved
	moving = moved > dist * 0.2
	player_px = (pos_f - Vector2(0.5, 0.5)) * float(TILE)
	var nt := Vector2i(floori(pos_f.x), floori(pos_f.y))
	if nt != player:
		player = nt
		if outside:
			_mark_explored(player, 7)
			_check_zone()
	facing = _cardinal_of(heading)
	step_dist += moved
	if step_dist >= 0.85:
		step_dist = 0.0
		_sfx("step", -12.0)


func _poll_and_move(delta: float) -> void:
	var up: bool = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var lf: bool = Input.is_physical_key_pressed(KEY_A)
	var rt: bool = Input.is_physical_key_pressed(KEY_D)
	var al: bool = Input.is_physical_key_pressed(KEY_LEFT)
	var ar: bool = Input.is_physical_key_pressed(KEY_RIGHT)
	var sprint: bool = Input.is_physical_key_pressed(KEY_SHIFT)
	var fwd: float = (1.0 if up else 0.0) - (1.0 if down else 0.0)
	if _rel_controls():
		var turn: float = (1.0 if al else 0.0) - (1.0 if ar else 0.0)
		if turn != 0.0:
			heading = wrapf(heading + turn * TURN_RATE * delta, -PI, PI)
			facing = _cardinal_of(heading)
		var strafe: float = (1.0 if rt else 0.0) - (1.0 if lf else 0.0)
		_move_player(delta, _wish_vector(fwd, strafe, 0.0, 0.0), sprint)
	else:
		var ax: float = (1.0 if (rt or ar) else 0.0) - (1.0 if (lf or al) else 0.0)
		_move_player(delta, Vector2(ax, -fwd), sprint)


func _mouse_look(rel: Vector2) -> void:
	heading = wrapf(heading - rel.x * MOUSE_BASE * mouse_sens, -PI, PI)
	pitch = clampf(pitch - rel.y * MOUSE_BASE * mouse_sens, -1.0, 0.9)
	facing = _cardinal_of(heading)


func _want_mouse_capture() -> bool:
	return playing and view3d_on and view3d != null and (cam_mode == 1 or cam_mode == 2) and (mode == 0 or mode == 5) and not _any_overlay()


func _apply_mouse_mode() -> void:
	var want: Input.MouseMode = Input.MOUSE_MODE_CAPTURED if _want_mouse_capture() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _interactable(ch: String) -> bool:
	if outside:
		return ch == "D" or ch == "m" or ch == "c" or ch == "i" or ch == "L"
	return ch == "B" or ch == "T" or ch == "A" or ch == "D" or stations.has(ch) or npcs.has(ch)


# casilla interactuable que tienes enfrente (cono de ~57 grados, alcance 1,7 casillas)
func _find_target() -> Vector2i:
	var fwd: Vector2 = Vector2(-sin(heading), -cos(heading))
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = 1000.0
	for ty in range(player.y - 2, player.y + 3):
		for tx in range(player.x - 2, player.x + 3):
			var ch: String = _tile(Vector2i(tx, ty))
			if not _interactable(ch):
				continue
			var v: Vector2 = Vector2(float(tx) + 0.5, float(ty) + 0.5) - pos_f
			var dist: float = v.length()
			if dist > REACH:
				continue
			var ang: float = absf(fwd.angle_to(v / maxf(dist, 0.001)))
			if ang > 1.0:
				continue
			var score: float = ang + dist * 0.35
			if score < best_score:
				best_score = score
				best = Vector2i(tx, ty)
	return best


func _on_v3_toggled(on: bool) -> void:
	_set_view3d(on)


func _set_view3d(on: bool) -> void:
	view3d_on = on
	if ui != null:
		ui.sync_options()
	_save_settings()


func _on_help_pressed() -> void:
	help_box.visible = not help_box.visible


func _on_save_pressed() -> void:
	if _save_game():
		pause_msg.text = Lang.t("Partida guardada.")
	else:
		pause_msg.text = Lang.t("No se pudo guardar la partida.")


func _on_pause_menu() -> void:
	_save_game()
	_close_pause()
	_show_menu()


func _on_pause_controls() -> void:
	ui.open_controls()


func _on_pause_stats() -> void:
	ui.open_stats()


func _on_pause_options() -> void:
	ui.open_options()


func _any_overlay() -> bool:
	if pause_overlay != null and pause_overlay.visible:
		return true
	if ui == null:
		return false
	return ui.options_overlay.visible or ui.controls_overlay.visible or ui.stats_overlay.visible or ui.learn_overlay.visible


func _overlay_opened() -> void:
	if playing and mode == 0:
		mode = 3


func _overlay_closed() -> void:
	if playing and mode == 3 and not _any_overlay():
		mode = 0


func _close_top_overlay() -> void:
	if ui.options_overlay.visible:
		ui.close_options()
	elif ui.controls_overlay.visible:
		ui.close_controls()
	elif ui.stats_overlay.visible:
		ui.close_stats()
	elif ui.learn_overlay.visible:
		ui.close_learn()
	elif pause_overlay.visible:
		_close_pause()


func _open_pause(_from_game: bool = true) -> void:
	pause_msg.text = ""
	help_box.visible = false
	pause_overlay.visible = true
	_overlay_opened()
	btn_continue.grab_focus()


func _close_pause() -> void:
	pause_overlay.visible = false
	_save_settings()
	_overlay_closed()


func _clear() -> void:
	ending_active = false
	if ending_art != null and is_instance_valid(ending_art):
		ending_art.queue_free()
	ending_art = null
	if root_margin != null:
		for side in ["left", "right", "top", "bottom"]:
			root_margin.add_theme_constant_override("margin_" + side, 16)
	for c in root_box.get_children():
		c.queue_free()
	bars.clear()
	map_view = null
	mini_view = null
	header = null
	inv_label = null
	inv_icons = null
	log_box = null


func _show_menu() -> void:
	playing = false
	mode = 0
	in_menu = true
	dlg.visible = false
	_clear()
	_play_music("music_menu")
	menu_loc = location if location != "" else "Luna"
	preview_built = ""
	_menu_preview(menu_loc)
	_fit_viewports()
	ui.open_menu("main")


func _menu_preview(loc: String) -> void:
	menu_loc = loc
	location = loc
	outside = true
	breach = false
	storm_left = 0
	day = 1
	clock = 1095
	if preview_built != loc:
		preview_built = loc
		_build_exterior()
		_build_minimap()
		view3d.setup()
	view3d.set_menu(true)


func _save_summary() -> String:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = parsed
	var ck: int = int(d.get("clock", 360))
	var out: String = Lang.t("Día %d/%d · %s · %s · %02d:%02d") % [int(d.get("day", 1)), MAX_DAYS, Lang.loc(str(d.get("location", ""))), DIFFICULTIES[clampi(int(d.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)]["name"], floori(float(ck) / 60.0), ck % 60]
	var ups: int = 0
	var sl: Variant = d.get("st_lvl", {})
	if typeof(sl) == TYPE_DICTIONARY:
		for k in (sl as Dictionary).keys():
			ups += int((sl as Dictionary)[k])
	var stt: Variant = d.get("stats", {})
	var tools_built: int = 0
	if typeof(stt) == TYPE_DICTIONARY:
		tools_built = int((stt as Dictionary).get("tools_built", 0))
	var rs: Variant = d.get("res", {})
	var vitals: String = ""
	if typeof(rs) == TYPE_DICTIONARY and (rs as Dictionary).has("oxygen"):
		vitals = Lang.t("Oxígeno %d%% · Moral %d%%") % [int((rs as Dictionary).get("oxygen", 0)), int((rs as Dictionary).get("morale", 0))]
	out += Lang.t("\nLugares visitados: %d · estudiados: %d · mejoras: %d · herramientas: %d") % [(d.get("zones_seen", []) as Array).size(), (d.get("studied", []) as Array).size(), ups, tools_built]
	out += Lang.t("\nEstás %s") % (Lang.t("fuera de la base") if bool(d.get("outside", false)) else Lang.t("dentro de la base"))
	if vitals != "":
		out += " · " + vitals
	var when: String = str(d.get("saved_at", ""))
	if when != "":
		out += Lang.t("\nGuardado: %s") % when.replace("T", " ")
	else:
		out += Lang.t("\nGuardado: fecha desconocida (partida antigua)")
	return out


func _on_difficulty(i: int) -> void:
	difficulty = i
	_save_settings()


func _save_compatible() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	return int(d.get("version", 0)) == 2


func _default_stats() -> Dictionary:
	return {"tools_built": 0, "expeditions": 0, "talks": 0, "collected": 0, "bad_events": 0, "breach_days": 0, "nightmares": 0, "collapses": 0, "upgrades": 0, "minigames": 0, "landmarks": 0, "distance": 0.0, "play_time": 0.0, "choices": {}}


func _find_start() -> Vector2i:
	for y in MAP.size():
		var row: String = MAP[y]
		var x: int = row.find("P")
		if x != -1:
			return Vector2i(x, y)
	return Vector2i(6, 6)


func _new_game(loc: String) -> void:
	in_menu = false
	perf_skip = 6.0
	perf_t = 0.0
	perf_n = 0
	preview_built = ""
	ui.close_menu()
	location = loc
	day = 1
	clock = DAY_START
	night_acc = 0
	slept_tonight = false
	night_warned = false
	awake_min = 0
	fatigue_warned = false
	pending_nightmare = {}
	storm_left = 0
	ill_days = 0
	breach = false
	outside = false
	time_acc = 0.0
	task_left = 0.0
	inv = {"scrap": 0, "polymer": 0, "circuits": 0}
	tools = {"patch": 0, "medkit": 0, "repair": 0, "filter": 0, "map": 0}
	st_lvl = {"O": 0, "S": 0, "G": 0, "W": 0, "R": 0, "C": 0}
	pack_lvl = 0
	suit_lvl_o2 = 0
	suit_lvl_st = 0
	suit_o2 = _suit_max()
	suit_warn = 0
	stamina = _stam_max()
	exhausted = false
	held = ""
	upg_pending = {}
	build = {}
	enoc_px = Vector2(-1, -1)
	depleted.clear()
	story_seen.clear()
	shown_facts.clear()
	talked_today.clear()
	stats = _default_stats()
	res = {"oxygen": 80.0, "energy": 80.0, "food": 80.0, "water": 80.0, "shield": 70.0, "morale": 80.0}
	history = [{"day": 1, "res": res.duplicate()}]
	_set_player_tile(_find_start(), Vector2i(0, 1))
	flash_t = 0.0
	shake_t = 0.0
	zones_seen.clear()
	studied.clear()
	diary.clear()
	learned.clear()
	cur_zone = -1
	zone_banner_t = 0.0
	_build_exterior()
	_build_minimap()
	view3d.setup()
	view3d.set_menu(false)
	_build_game_ui()
	playing = true
	mode = 0
	_play_music(_wanted_music())
	_log(Lang.t("Base establecida en %s. Son las 06:00. Wilson al mando.") % Lang.loc(location))
	learned_day = -1
	if nasa != null:
		nasa.call("fetch", false)
	_refresh()
	_save_game()
	_story_for_day(1)
	if show_tutorial:
		tut.call("start")
	else:
		tut.call("skip_silent")


func _on_nasa_updated() -> void:
	if playing and nasa != null and str(nasa.get("status")) == "ok":
		_log("[color=cyan]%s[/color]" % str(nasa.call("daily_line")))


func _build_tutor() -> void:
	tut = Control.new()
	tut.set_script(load("res://tutor.gd"))
	tut.set("game", self)
	add_child(tut)


func _on_pause_learn() -> void:
	ui.open_learn()


func _on_pause_tutorial() -> void:
	_close_pause()
	tut.call("start")


func _hud_style(a: float = 0.62) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.12, a)
	sb.border_color = Color(0.3, 0.42, 0.62, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _build_game_ui() -> void:
	_clear()
	if root_margin != null:
		for side in ["left", "right", "top", "bottom"]:
			root_margin.add_theme_constant_override("margin_" + side, 0)

	# La vista del juego ocupa TODA la ventana; el HUD flota encima.
	map_view = Control.new()
	map_view.custom_minimum_size = Vector2(VIEW_W * TILE, VIEW_H * TILE)
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.clip_contents = true
	mini_view = Control.new()
	mini_view.custom_minimum_size = Vector2(EXT_W, EXT_H) * MINI_SCALE
	mini_view.size = Vector2(EXT_W, EXT_H) * MINI_SCALE
	mini_view.position = Vector2(float(VIEW_W * TILE) - float(EXT_W) * MINI_SCALE - 8.0, 8.0)
	mini_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mini_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_view.visible = false
	mini_view.draw.connect(_draw_minimap_node.bind(mini_view))
	map_view.add_child(mini_view)
	map_view.resized.connect(_on_map_resized)
	map_view.draw.connect(_on_map_draw.bind(map_view))
	root_box.add_child(map_view)

	# --- HUD arriba a la izquierda: dia/hora + recursos principales ---
	var hud := PanelContainer.new()
	hud.add_theme_stylebox_override("panel", _hud_style())
	hud.position = Vector2(10, 10)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.add_child(hud)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(side)
	header = _label("", 14)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.custom_minimum_size = Vector2(236, 0)
	side.add_child(header)
	var short: Dictionary = {"oxygen": Lang.t("Oxígeno"), "energy": Lang.t("Energía"), "food": Lang.t("Comida"), "water": Lang.t("Agua"), "shield": Lang.t("Escudo"), "morale": Lang.t("Moral")}
	for k in NAMES:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(short.get(k, NAMES[k]), 13)
		l.custom_minimum_size = Vector2(66, 0)
		row.add_child(l)
		var b := ProgressBar.new()
		b.max_value = 100
		b.show_percentage = false
		b.custom_minimum_size = Vector2(130, 12)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = bar_colors[k]
		fill.set_corner_radius_all(3)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.14, 0.15, 0.24, 0.8)
		back.set_corner_radius_all(3)
		b.add_theme_stylebox_override("fill", fill)
		b.add_theme_stylebox_override("background", back)
		row.add_child(b)
		side.add_child(row)
		bars[k] = b
	inv_label = _label("", 12)
	inv_label.visible = false # el texto queda oculto; el HUD usa iconos
	side.add_child(inv_label)
	inv_icons = (load("res://inv_icons.gd") as GDScript).new() as Control
	inv_icons.set("game", self)
	side.add_child(inv_icons)

	# --- Botones abajo a la derecha ---
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	brow.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	brow.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	brow.grow_vertical = Control.GROW_DIRECTION_BEGIN
	brow.offset_right = -10
	brow.offset_bottom = -10
	map_view.add_child(brow)
	var b1 := Button.new()
	b1.text = Lang.t("Controles  F1")
	b1.focus_mode = Control.FOCUS_NONE
	b1.pressed.connect(_on_hud_controls)
	brow.add_child(b1)
	var b2 := Button.new()
	b2.text = Lang.t("Estadísticas  F2")
	b2.focus_mode = Control.FOCUS_NONE
	b2.pressed.connect(_on_hud_stats)
	brow.add_child(b2)

	# --- Registro de mensajes abajo a la izquierda (translucido) ---
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", _hud_style(0.5))
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	log_panel.offset_left = 10
	log_panel.offset_bottom = -10
	log_panel.offset_right = 520
	log_panel.offset_top = -108
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.add_child(log_panel)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_panel.add_child(log_box)


func _on_hud_controls() -> void:
	if playing and mode == 0:
		ui.open_controls()


func _on_hud_stats() -> void:
	if playing and mode == 0:
		ui.open_stats()


func _is_night() -> bool:
	# La noche lunar dura ~14 días terrestres (NASA). Aquí: días 9 a 22.
	return location == "Luna" and day >= 9 and day <= 22


func _process(delta: float) -> void:
	t_anim += delta
	if vp3d != null:
		var want: int = SubViewport.UPDATE_ALWAYS if (((playing and view3d_on) or in_menu) and view3d != null) else SubViewport.UPDATE_DISABLED
		if in_menu and not playing and Engine.get_process_frames() % 2 == 1:
			want = SubViewport.UPDATE_DISABLED # el fondo del menu se redibuja a la mitad de FPS
		if int(vp3d.render_target_update_mode) != want:
			vp3d.render_target_update_mode = want as SubViewport.UpdateMode
	if playing:
		_update_enoc(delta)
	if tut != null:
		tut.call("tick", delta)
	flash_t = maxf(flash_t - delta * 1.5, 0.0)
	shake_t = maxf(shake_t - delta * 1.2, 0.0)
	zone_banner_t = maxf(zone_banner_t - delta, 0.0)
	cam_banner_t = maxf(cam_banner_t - delta, 0.0)
	_apply_mouse_mode()
	if playing and view3d_on:
		_perf_check(delta)
	if playing:
		stats["play_time"] += delta
		_play_music(_wanted_music())
	if typing:
		type_pos += delta * 45.0
		var shown: int = int(type_pos)
		if shown >= type_total:
			typing = false
			dlg_text.visible_characters = -1
		else:
			dlg_text.visible_characters = shown
			if shown - last_blip >= 3:
				last_blip = shown
				_sfx("blip", -14.0)
	if playing and map_view != null:
		if mode == 5:
			var adv: float = minf(task_speed * delta, task_left)
			task_left -= adv
			time_acc += adv
			_run_time_acc()
			if playing and mode == 5 and task_left <= 0.001:
				_finish_task()
		elif mode == 0:
			time_acc += delta * TIME_SCALE
			_run_time_acc()
	if not playing or map_view == null:
		return
	if breach and mode != 3:
		alarm_t += delta
		if alarm_t >= 4.0:
			alarm_t = 0.0
			_sfx("alarm", -10.0)
		if bars.has("shield"):
			var pulse: float = 0.5 + 0.5 * sin(t_anim * 6.0)
			bars["shield"].modulate = Color(1.0, 0.3 + 0.4 * pulse, 0.3 + 0.4 * pulse)
	_update_jump(delta)
	_stamina_regen(delta)
	if mode == 0 and fall_t < 0.0:
		_poll_and_move(delta)
	else:
		moving = false
	if mini_dirty and mini_tex != null:
		mini_tex.update(mini_img)
		mini_dirty = false
	if mini_view != null:
		var show_mini: bool = outside and int(tools["map"]) > 0
		mini_view.visible = show_mini
		if show_mini:
			mini_view.queue_redraw()
	if mode == 6 and map_canvas != null:
		map_canvas.queue_redraw()
		map_labels.queue_redraw()
	map_view.queue_redraw()


# ---------- EXTERIOR ----------

func _zones() -> Array:
	if location == "Marte":
		return ZONES_MARTE
	return ZONES_LUNA


func _zone_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= EXT_W or y >= EXT_H or zone_ids.size() != EXT_W * EXT_H:
		return 0
	return zone_ids[y * EXT_W + x]


func _zcol(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))


func _build_exterior() -> void:
	_bake_clear()
	var zs: Array = _zones()
	var g := RandomNumberGenerator.new()
	g.seed = 20260614 if location == "Marte" else 20260613
	var n: int = EXT_W * EXT_H
	zone_ids = PackedByteArray()
	zone_ids.resize(n)
	explored = PackedByteArray()
	explored.resize(n)
	zone_ground = []
	zone_rock = []
	for zc in zs:
		zone_ground.append(_zcol(zc["ground"]))
		zone_rock.append(_zcol(zc["rock"]))
	var dmap := PackedFloat32Array()
	dmap.resize(n)
	dmap.fill(2.0)
	for zi in range(1, zs.size()):
		var zz: Dictionary = zs[zi]
		var zcx: float = float(zz["cx"])
		var zcy: float = float(zz["cy"])
		var zrx: float = float(zz["rx"])
		var zry: float = float(zz["ry"])
		for y in range(maxi(int(zcy - zry) - 1, 1), mini(int(zcy + zry) + 2, EXT_H - 1)):
			for x in range(maxi(int(zcx - zrx) - 1, 1), mini(int(zcx + zrx) + 2, EXT_W - 1)):
				var ddx: float = (float(x) - zcx) / zrx
				var ddy: float = (float(y) - zcy) / zry
				var dd: float = ddx * ddx + ddy * ddy + (g.randf() - 0.5) * 0.1
				if dd <= 1.0:
					zone_ids[y * EXT_W + x] = zi
					dmap[y * EXT_W + x] = dd
	var t: Array = []
	t.resize(n)
	t.fill(".")
	for y in range(1, EXT_H - 1):
		for x in range(1, EXT_W - 1):
			var i: int = y * EXT_W + x
			var zid: int = zone_ids[i]
			var z: Dictionary = zs[zid]
			var kind: String = z["kind"]
			var d: float = dmap[i]
			var cx: float = float(z["cx"])
			var cy: float = float(z["cy"])
			var c: String = "."
			match kind:
				"crater", "valley":
					var ax: float = (float(x) - cx) / float(z["rx"])
					var ay: float = (float(y) - cy) / float(z["ry"])
					var ang: float = atan2(ay, ax)
					if d > 0.78:
						var gap: bool = absf(sin(ang * 2.0)) < 0.2
						if kind == "valley":
							gap = absf(cos(ang)) > 0.55
						if not gap:
							c = "#"
					elif d < float(z.get("peak", 0.0)):
						c = "#"
				"mountain":
					if d < 0.28:
						c = "#"
				"volcano":
					if d < 0.5:
						c = "#"
				"canyon":
					var ty: float = cy + sin(float(x) * 0.12) * 2.0
					var hw: float = 2.4 + sin(float(x) * 0.3) * 0.7
					var off: float = absf(float(y) - ty)
					if off < hw:
						if x % 22 >= 3:
							c = "X"
					elif off < hw + 2.0 and g.randf() < 0.1:
						c = "m"
			if c == ".":
				var dens: Array = z["dens"]
				var r: float = g.randf()
				var acc: float = float(dens[0])
				if r < acc:
					c = "r"
				else:
					acc += float(dens[1])
					if r < acc:
						c = "m"
					else:
						acc += float(dens[2])
						if r < acc:
							c = "i"
						else:
							acc += float(dens[3])
							if r < acc:
								c = "c"
			t[i] = c
	for x in EXT_W:
		t[x] = "#"
		t[(EXT_H - 1) * EXT_W + x] = "#"
	for y in EXT_H:
		t[y * EXT_W] = "#"
		t[y * EXT_W + EXT_W - 1] = "#"
	# huecos pequenos (fisuras) que se cruzan saltando: 2 a 3 casillas de ancho
	var pg := RandomNumberGenerator.new()
	pg.seed = 777
	for zi in range(1, zs.size()):
		var pz: Dictionary = zs[zi]
		if pz["kind"] == "canyon" or pz["kind"] == "ice":
			continue
		var npits: int = int(float(pz["rx"]) * float(pz["ry"]) / 40.0)
		for pn in npits:
			var pang: float = pg.randf() * TAU
			var prad: float = sqrt(pg.randf()) * 0.7
			var pcx: float = float(pz["cx"]) + cos(pang) * prad * float(pz["rx"])
			var pcy: float = float(pz["cy"]) + sin(pang) * prad * float(pz["ry"])
			var pr: float = pg.randf_range(1.15, 1.75)
			if absf(pcx - float(BASE_X0 + 3)) < 16.0 and absf(pcy - float(BASE_Y0 + 2)) < 12.0:
				continue
			if Vector2(pcx - float(pz["lx"]), pcy - float(pz["ly"])).length() < 6.0:
				continue
			var clear: bool = true
			for qy in range(int(pcy - 3.0), int(pcy + 4.0)):
				for qx in range(int(pcx - 3.0), int(pcx + 4.0)):
					if qx < 2 or qy < 2 or qx >= EXT_W - 2 or qy >= EXT_H - 2 or t[qy * EXT_W + qx] == "#":
						clear = false
			if not clear:
				continue
			for qy in range(int(pcy - 3.0), int(pcy + 4.0)):
				for qx in range(int(pcx - 3.0), int(pcx + 4.0)):
					if Vector2(float(qx) + 0.5 - pcx, float(qy) + 0.5 - pcy).length() <= pr:
						t[qy * EXT_W + qx] = "X"
	# placas informativas (una por zona)
	for zi in range(1, zs.size()):
		var lz: Dictionary = zs[zi]
		var lx: int = int(lz["lx"])
		var ly: int = int(lz["ly"])
		for ddy in range(-1, 2):
			for ddx in range(-1, 2):
				var nx: int = lx + ddx
				var ny: int = ly + ddy
				if nx > 0 and ny > 0 and nx < EXT_W - 1 and ny < EXT_H - 1:
					t[ny * EXT_W + nx] = "."
		t[ly * EXT_W + lx] = "L"
		zone_ids[ly * EXT_W + lx] = zi
	# campamento
	for y in range(BASE_Y0 - 6, BASE_Y0 + 9):
		for x in range(BASE_X0 - 7, BASE_X0 + 14):
			t[y * EXT_W + x] = "."
			zone_ids[y * EXT_W + x] = 0
	for y in range(BASE_Y0 - 1, BASE_Y0 + 3):
		for x in range(BASE_X0 - 3, BASE_X0 + 7):
			t[y * EXT_W + x] = "H"
	t[(BASE_Y0 + 2) * EXT_W + BASE_X0 + 2] = "D"
	# material garantizado cerca del campamento
	var fixed: Array = [[BASE_X0 + 9, BASE_Y0 + 4, "m"], [BASE_X0 - 5, BASE_Y0 + 5, "m"], [BASE_X0 + 8, BASE_Y0 - 6, "m"], [BASE_X0 + 3, BASE_Y0 - 7, "c"], [BASE_X0 - 3, BASE_Y0 - 9, "c"], [BASE_X0 - 9, BASE_Y0 - 1, "i"], [BASE_X0 + 13, BASE_Y0 - 2, "i"]]
	for f in fixed:
		var fx: int = f[0]
		var fy: int = f[1]
		for ddy in range(-1, 2):
			for ddx in range(-1, 2):
				t[(fy + ddy) * EXT_W + fx + ddx] = "."
		t[fy * EXT_W + fx] = f[2]
	var rows: Array = []
	for y in EXT_H:
		var parts := PackedStringArray()
		for x in EXT_W:
			parts.append(t[y * EXT_W + x])
		rows.append("".join(parts))
	ext_rows = rows
	ext_spawn = Vector2i(BASE_X0 + 2, BASE_Y0 + 3)


func _mini_color(x: int, y: int) -> Color:
	var row: String = ext_rows[y]
	var ch: String = row[x]
	var i: int = y * EXT_W + x
	var zid: int = zone_ids[i]
	var gcol: Color = zone_ground[zid]
	var rcol: Color = zone_rock[zid]
	var c: Color = gcol
	match ch:
		"#":
			c = rcol.darkened(0.35)
		"X":
			c = Color(0.1, 0.06, 0.05)
		"r":
			c = rcol
		"m":
			c = Color(0.85, 0.9, 1.0)
		"i":
			c = Color(0.55, 0.85, 1.0)
		"c":
			c = Color(1.0, 0.85, 0.2)
		"H", "D":
			c = Color(0.8, 0.85, 0.95)
		"L":
			c = Color(1.0, 1.0, 1.0)
	if explored[i] == 0:
		c = c.darkened(0.55)
	return c


func _build_minimap() -> void:
	mini_img = Image.create(EXT_W, EXT_H, false, Image.FORMAT_RGBA8)
	for y in EXT_H:
		for x in EXT_W:
			mini_img.set_pixel(x, y, _mini_color(x, y))
	mini_tex = ImageTexture.create_from_image(mini_img)
	mini_dirty = false


func _mark_explored(c: Vector2i, r: int) -> void:
	if explored.size() != EXT_W * EXT_H:
		return
	for y in range(maxi(c.y - r, 0), mini(c.y + r + 1, EXT_H)):
		for x in range(maxi(c.x - r, 0), mini(c.x + r + 1, EXT_W)):
			var dx: int = x - c.x
			var dy: int = y - c.y
			if dx * dx + dy * dy > r * r:
				continue
			var i: int = y * EXT_W + x
			if explored[i] == 0:
				explored[i] = 1
				if mini_img != null:
					mini_img.set_pixel(x, y, _mini_color(x, y))
					mini_dirty = true


func _check_zone() -> void:
	var zid: int = _zone_at(player.x, player.y)
	if zid == cur_zone:
		return
	cur_zone = zid
	var zs: Array = _zones()
	var z: Dictionary = zs[zid]
	zone_banner_name = z["name"]
	zone_banner_desc = z["desc"]
	zone_banner_t = 4.0
	if not zones_seen.has(zid):
		zones_seen[zid] = true
		_diary_note(zid, "seen")
		_log(Lang.t("[color=cyan]Nueva zona: %s.[/color]") % z["name"])
		_sfx("next", -6.0)


func _read_landmark(np: Vector2i) -> void:
	var zid: int = _zone_at(np.x, np.y)
	var zs: Array = _zones()
	var z: Dictionary = zs[zid]
	var lines: Array = [_l("Narración", z["name"])]
	for f in z["facts"]:
		lines.append(_l("Narración", f))
	var first: bool = not studied.has(zid)
	if first:
		lines.append(_l("Narración", Lang.t("Estudiar este lugar te inspira (+3 moral).")))
	_sfx("interact")
	_fx("ring", "", Color(0.6, 0.85, 1.0))
	_start_dialog(lines, _landmark_after.bind(zid, first))


func _landmark_after(zid: int, first: bool) -> void:
	if first:
		studied[zid] = true
		_diary_note(zid, "study")
		stats["landmarks"] += 1
		_add("morale", 3)
		var zs: Array = _zones()
		var z: Dictionary = zs[zid]
		_log(Lang.t("[color=cyan][b]Lugar estudiado:[/b] %s[/color]") % z["name"])
		_sfx("good", -8.0)
	_refresh()
	_start_task(15.0, TASK_SPEED)


# ---------- diario de exploracion (J) ----------

func _diary_note(zid: int, what: String) -> void:
	var e: Dictionary = diary.get(zid, {})
	if not e.has(what):
		e[what] = [day, clock]
	diary[zid] = e


func _diary_when(e: Dictionary, what: String) -> String:
	if not e.has(what):
		return ""
	var a: Array = e[what]
	var ck: int = int(a[1])
	return Lang.t("día %d, %02d:%02d") % [int(a[0]), floori(float(ck) / 60.0), ck % 60]


func _build_diary_ui() -> void:
	diary_ui = Control.new()
	diary_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	diary_ui.visible = false
	diary_ui.z_index = 57
	add_child(diary_ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	diary_ui.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	diary_ui.add_child(cc)
	var panel := PanelContainer.new()
	var ps: StyleBoxFlat = _panel_style()
	ps.bg_color = Color(0.93, 0.88, 0.74)
	ps.border_color = Color(0.45, 0.3, 0.15)
	ps.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel", ps)
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title: Label = _label(Lang.t("DIARIO DE EXPLORACIÓN"), 22)
	title.add_theme_color_override("font_color", Color(0.3, 0.17, 0.07))
	vb.add_child(title)
	diary_text = RichTextLabel.new()
	diary_text.bbcode_enabled = true
	diary_text.scroll_active = true
	diary_text.add_theme_font_size_override("normal_font_size", 15)
	diary_text.add_theme_font_size_override("bold_font_size", 15)
	diary_text.add_theme_color_override("default_color", Color(0.18, 0.12, 0.08))
	diary_text.custom_minimum_size = Vector2(700, 440)
	vb.add_child(diary_text)
	var hint: Label = _label(Lang.t("[J] o [Esc]: cerrar · [↑][↓]: desplazar"), 13)
	hint.add_theme_color_override("font_color", Color(0.4, 0.28, 0.15))
	vb.add_child(hint)


func _diary_content() -> String:
	var zs: Array = _zones()
	var t: String = Lang.t("[b]Día %d de %d[/b] · %s · %s\n") % [day, MAX_DAYS, Lang.loc(location), _clock_text()]
	var seen_n: int = 0
	var study_n: int = 0
	for zi in range(1, zs.size()):
		if zones_seen.has(zi):
			seen_n += 1
		if studied.has(zi):
			study_n += 1
	t += Lang.t("Lugares visitados: %d de %d · Lugares estudiados: %d de %d\n\n") % [seen_n, zs.size() - 1, study_n, zs.size() - 1]
	for zi in range(1, zs.size()):
		var z: Dictionary = zs[zi]
		var e: Dictionary = diary.get(zi, {})
		if not zones_seen.has(zi):
			t += "[color=#8a7a66][b]?????[/b] — %s[/color]\n\n" % Lang.t("lugar por descubrir")
			continue
		t += "[b]%s[/b]\n" % z["name"]
		t += "[i]%s[/i]\n" % z["desc"]
		var w: String = _diary_when(e, "seen")
		if w != "":
			t += Lang.t("• Llegaste el %s.\n") % w
		else:
			t += Lang.t("• Visitado (anotado antes del diario).\n")
		if studied.has(zi):
			var ws: String = _diary_when(e, "study")
			if ws != "":
				t += Lang.t("• Estudiaste la placa el %s:\n") % ws
			else:
				t += Lang.t("• Estudiaste la placa:\n")
			for f in z["facts"]:
				t += "   – %s\n" % f
		else:
			t += Lang.t("• Aún no has leído su placa (acércate y pulsa E).\n")
		t += "\n"
	t += Lang.t("[b]Tus números[/b]\n")
	t += Lang.t("• Casillas recorridas: %d\n") % int(stats.get("distance", 0.0))
	t += Lang.t("• Expediciones fuera de la base: %d\n") % int(stats.get("expeditions", 0))
	t += Lang.t("• Materiales recogidos: %d\n") % int(stats.get("collected", 0))
	t += Lang.t("• Herramientas fabricadas: %d\n") % int(stats.get("tools_built", 0))
	t += Lang.t("• Mejoras terminadas: %d\n") % int(stats.get("upgrades", 0))
	t += Lang.t("• Conversaciones: %d\n") % int(stats.get("talks", 0))
	return t


func _open_diary() -> void:
	if mode != 0 or airborne or fall_t >= 0.0:
		return
	mode = 11
	diary_text.text = _diary_content()
	diary_text.scroll_to_line(0)
	diary_ui.visible = true
	_sfx("next", -6.0)


func _close_diary() -> void:
	diary_ui.visible = false
	if mode == 11:
		mode = 0


func _input_diary(k: InputEventKey) -> void:
	match k.keycode:
		KEY_J, KEY_ESCAPE:
			_close_diary()
		KEY_DOWN:
			diary_text.get_v_scroll_bar().value += 60.0
		KEY_UP:
			diary_text.get_v_scroll_bar().value -= 60.0


# ---------- mapa del mundo (Tab) ----------

func _build_world_map_ui() -> void:
	map_overlay = Control.new()
	map_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_overlay.visible = false
	add_child(map_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_overlay.add_child(cc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	cc.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	map_canvas = Control.new()
	map_canvas.custom_minimum_size = Vector2(EXT_W * 6, EXT_H * 6)
	map_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_canvas.draw.connect(_draw_world_map)
	hb.add_child(map_canvas)
	map_labels = Control.new()
	map_labels.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_labels.draw.connect(_draw_world_labels)
	map_canvas.add_child(map_labels)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(270, 0)
	side.add_theme_constant_override("separation", 8)
	hb.add_child(side)
	side.add_child(_label(Lang.t("MAPA DE NAVEGACIÓN"), 20))
	map_legend = RichTextLabel.new()
	map_legend.bbcode_enabled = true
	map_legend.add_theme_font_size_override("normal_font_size", 14)
	map_legend.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_legend.custom_minimum_size = Vector2(0, 430)
	side.add_child(map_legend)
	side.add_child(_label(Lang.t("[Tab] o [Esc]: cerrar"), 13))


func _open_world_map() -> void:
	if int(tools["map"]) <= 0:
		_sfx("error")
		_log(Lang.t("[color=orange]Aún no tienes un mapa. Fabrica un Mapa de navegación en el banco de trabajo.[/color]"))
		return
	mode = 6
	_update_legend()
	map_overlay.visible = true
	_sfx("next", -6.0)


func _close_world_map() -> void:
	map_overlay.visible = false
	if mode == 6:
		mode = 0


func _input_map(k: InputEventKey) -> void:
	if k.keycode == KEY_TAB or k.keycode == KEY_ESCAPE:
		_close_world_map()


func _update_legend() -> void:
	var zs: Array = _zones()
	var t: String = Lang.t("[b]Zonas[/b]\nVistas por satélite. Lo que ya exploraste se ve con más detalle.\n\n")
	for zi in zs.size():
		var z: Dictionary = zs[zi]
		var col: Color = zone_ground[zi]
		var st: String = Lang.t("por explorar")
		if zi == 0:
			st = "campamento"
		elif studied.has(zi):
			st = "estudiada"
		elif zones_seen.has(zi):
			st = "visitada"
		t += "[bgcolor=#%s]   [/bgcolor] %s - %s\n" % [col.to_html(false), z["name"], st]
	t += Lang.t("\n[b]Marcadores[/b]\nPunto blanco: placa informativa. Punto amarillo: lugar ya estudiado. Parpadeante: tú.")
	map_legend.text = t


func _draw_world_map() -> void:
	if mini_tex == null:
		return
	var sc: float = 6.0
	var full := Rect2(Vector2.ZERO, Vector2(EXT_W, EXT_H) * sc)
	map_canvas.draw_texture_rect(mini_tex, full, false)
	map_canvas.draw_rect(full, Color(0.5, 0.7, 1.0, 0.8), false, 2.0)
	map_canvas.draw_rect(Rect2(Vector2(BASE_X0 - 3, BASE_Y0 - 1) * sc, Vector2(10, 4) * sc), Color(0.9, 0.95, 1.0), false, 2.0)


func _draw_world_labels() -> void:
	var sc: float = 6.0
	var font: Font = ThemeDB.fallback_font
	var zs: Array = _zones()
	for zi in zs.size():
		var z: Dictionary = zs[zi]
		var pos: Vector2 = Vector2(float(z["cx"]), float(z["cy"])) * sc
		if zi == 0:
			pos = Vector2(float(BASE_X0 + 3), float(BASE_Y0 + 5)) * sc
		else:
			var col: Color = Color(0.95, 0.95, 0.95)
			if studied.has(zi):
				col = Color(1.0, 0.9, 0.3)
			map_labels.draw_circle(Vector2(float(z["lx"]) + 0.5, float(z["ly"]) + 0.5) * sc, 4.0, col)
		var nm: String = z["name"]
		var sz: Vector2 = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var tp: Vector2 = pos + Vector2(-sz.x / 2.0, -10.0)
		tp.x = clampf(tp.x, 4.0, float(EXT_W) * sc - sz.x - 4.0)
		tp.y = clampf(tp.y, 14.0, float(EXT_H) * sc - 6.0)
		map_labels.draw_string(font, tp + Vector2(1, 1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.95))
		map_labels.draw_string(font, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
	var pp: Vector2 = Vector2(float(BASE_X0 + 2), float(BASE_Y0 + 3))
	if outside:
		pp = player_px / float(TILE)
	pp = (pp + Vector2(0.5, 0.5)) * sc
	var blink: bool = int(t_anim * 3.0) % 2 == 0
	map_labels.draw_circle(pp, 6.0, Color(1.0, 0.25, 0.2) if blink else Color(1.0, 0.9, 0.2))
	map_labels.draw_arc(pp, 9.0, 0.0, TAU, 20, Color.WHITE, 2.0)


func _draw_minimap_node(node: Control) -> void:
	if node != mini_view or mini_tex == null:
		return
	var sc: float = MINI_SCALE
	var full := Rect2(Vector2.ZERO, Vector2(EXT_W, EXT_H) * sc)
	mini_view.draw_rect(Rect2(Vector2(-3, -3), full.size + Vector2(6, 6)), Color(0.02, 0.03, 0.08, 0.92))
	mini_view.draw_texture_rect(mini_tex, full, false)
	mini_view.draw_rect(full, Color(0.5, 0.7, 1.0, 0.9), false, 1.0)
	var cam: Vector2 = _cam_offset() / float(TILE)
	mini_view.draw_rect(Rect2(cam * sc, (_mv() / float(TILE)) * sc), Color(1, 1, 1, 0.85), false, 1.0)
	mini_view.draw_rect(Rect2((Vector2(BASE_X0 - 3, BASE_Y0 - 1) * sc), Vector2(10, 4) * sc), Color(0.9, 0.95, 1.0), false, 1.0)
	var pp: Vector2 = (player_px / float(TILE) + Vector2(0.5, 0.5)) * sc
	var blink: bool = int(t_anim * 3.0) % 2 == 0
	mini_view.draw_rect(Rect2(pp - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.25, 0.2) if blink else Color(1.0, 0.9, 0.2))


func _node_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func _is_depleted(x: int, y: int) -> bool:
	var k: String = _node_key(x, y)
	if not depleted.has(k):
		return false
	if day - int(depleted[k]) >= _respawn_days():
		depleted.erase(k)
		return false
	return true


func _door_inside() -> void:
	outside = true
	_set_player_tile(ext_spawn, Vector2i(0, 1))   # al salir se mira hacia afuera (sur), de espaldas a la base
	stats["expeditions"] += 1
	_mark_explored(player, 8)
	cur_zone = -1
	_check_zone()
	_sfx("airlock")
	_fx("ring", "", Color(0.6, 0.85, 1.0))
	_log(Lang.t("Sales a la superficie (ciclo de esclusa: 10 min)."))
	if not jump_hinted:
		jump_hinted = true
		_log(Lang.t("[color=#7fd0ff]Pista: pulsa [Espacio] para saltar. Sirve para cruzar huecos oscuros y pasar sobre rocas.[/color]"))
	if not learned.has("suit"):
		learned["suit"] = true
		_top_info(Lang.t("Tu traje"), [
			Lang.t("Afuera respiras el aire de tu traje (barra azul arriba). Se gasta mientras estás en la superficie, más rápido en tormentas de polvo. Si se acaba, te desmayas y pierdes 2 horas. Al volver a la esclusa se recarga con un poco del oxígeno de la base."),
			Lang.t("Con [Shift] corres, pero gastas aguante (barra amarilla). Si te quedas sin aliento, camina un momento. En el banco de trabajo puedes mejorar el tanque, el aguante y la mochila con materiales.")], _start_task.bind(10.0, TASK_SPEED))
		return
	_start_task(10.0, TASK_SPEED)


func _exit_eva() -> void:
	outside = false
	_set_player_tile(DOOR_FRONT, Vector2i(0, -1))
	cur_zone = -1
	_sfx("airlock")
	_fx("ring", "", Color(0.6, 0.85, 1.0))
	_add("oxygen", -3)
	_add("shield", -2)
	_log(Lang.t("Regresas por la esclusa (-3 oxígeno por el ciclo de aire, -2 escudo por exposición)."))
	_refill_suit()
	_start_task(10.0, TASK_SPEED)


func _gather(ch: String, np: Vector2i) -> void:
	if _is_depleted(np.x, np.y):
		_sfx("error")
		var left: int = _respawn_days() - (day - int(depleted[_node_key(np.x, np.y)]))
		_log(Lang.t("[color=orange]Zona ya recogida. Habrá más material en %d día(s).[/color]") % left)
		return
	var kind: String = "grab"
	# cuanto sale depende de la dificultad y del dia (cada vez menos material)
	var n_scrap: int = 0
	var n_pol: int = 0
	var n_cir: int = 0
	match ch:
		"m":
			n_scrap = _yield(2)
		"c":
			n_pol = _yield(1)
			n_cir = _yield(1)
	if not _pack_room({"scrap": n_scrap, "polymer": n_pol, "circuits": n_cir}):
		_sfx("error")
		_log(Lang.t("[color=orange]Mochila llena: usa o fabrica algo antes de recoger más (o mejora la mochila en el banco de trabajo).[/color]"))
		return
	match ch:
		"m":
			inv["scrap"] += n_scrap
			if n_scrap > 0:
				_log(Lang.t("Recoges chatarra metálica (+%d chatarra, 30 min).") % n_scrap)
				_fx("grab", Lang.t("+%d chatarra") % n_scrap, Color(0.78, 0.8, 0.88), "scrap")
			else:
				_log(Lang.t("[color=orange]La veta está casi agotada: no encuentras chatarra útil (30 min).[/color]"))
		"c":
			inv["polymer"] += n_pol
			inv["circuits"] += n_cir
			if n_pol + n_cir > 0:
				_log(Lang.t("Rescatas piezas del cargamento perdido (+%d polímero, +%d circuitos, 30 min).") % [n_pol, n_cir])
				_fx("grab", Lang.t("+%d polímero  +%d circuitos") % [n_pol, n_cir], Color(1.0, 0.8, 0.4), "polymer")
				if n_cir > 0:
					_fly_hud("circuits")
			else:
				_log(Lang.t("[color=orange]El cargamento está dañado: no rescatas nada útil (30 min).[/color]"))
		"i":
			_add("water", 10)
			_log(Lang.t("Extraes hielo de agua (+10 agua, 30 min)."))
			kind = "mine"
			_fx("mine", Lang.t("+10 agua"), Color(0.6, 0.9, 1.0))
	depleted[_node_key(np.x, np.y)] = day
	stats["collected"] += 1
	_sfx("pickup")
	var lkey: String = {"m": "scrap", "c": "cargo", "i": "ice_" + location}[ch]
	if not learned.has(lkey):
		learned[lkey] = true
		_top_info(_learn_title(lkey), _learn_texts(lkey), _start_task.bind(30.0, TASK_SPEED, kind))
		return
	_start_task(30.0, TASK_SPEED, kind)


# Explicacion breve la primera vez que recoges cada material. Datos con fuente:
#  - LCROSS (Cabeus, 5,6 % +/- 2,9 % de hielo en masa): space.com, "LCROSS 10 year anniversary".
#  - Phoenix 2008 (hielo que se evapora en la zanja): JPL/NASA, "Bright chunks at Phoenix Lander's Mars site must have been ice".
#  - Hielo enterrado en Utopia Planitia (SHARAD/MRO): space.com, "Mars ice more water than Lake Superior".
#  - MOXIE (unos 122 g de oxigeno en 16 pruebas): ScienceAlert, "NASA confirms breathable oxygen really can be extracted on Mars".
#  - Regolito (ilmenita; hierro, silicio, aluminio, titanio, vidrio): NASA NTRS 20170001458 (Muscatello, 2017).
#  - Impresion 3D en la ISS, repuestos y ReFabricator: NASA, "3D printing in space: long-duration spaceflight applications"; Astronomy.com (2019).
func _learn_title(key: String) -> String:
	if key == "scrap":
		return Lang.t("Chatarra metálica")
	if key == "cargo":
		return Lang.t("Cargamento perdido")
	return Lang.t("Hielo de agua")


func _learn_texts(key: String) -> Array:
	var L: Array = []
	match key:
		"scrap":
			L = [
				Lang.t("Chatarra metálica: en la base el metal se reutiliza para reparar y fabricar piezas."),
				Lang.t("El suelo de la Luna (regolito) tiene minerales como la ilmenita, que contiene hierro y titanio. Según una presentación técnica de la NASA (2017), al extraer oxígeno de estos minerales también se pueden obtener hierro, silicio, aluminio, titanio y vidrio."),
			]
		"cargo":
			L = [
				Lang.t("Piezas del cargamento perdido: los polímeros (plásticos técnicos) y los circuitos vienen de la nave de reabastecimiento que falló. Esa nave es ficción del juego."),
				Lang.t("En la realidad, la Estación Espacial Internacional necesita más de 7.000 libras (más de 3.000 kg) de repuestos al año. La NASA dice que ese sistema no sirve para la Luna ni para Marte: allí habrá que fabricar piezas y herramientas."),
				Lang.t("Por eso se prueba hacerlo en el espacio: desde 2014 hay una impresora 3D en la Estación que imprime con plástico, y el ReFabricator (de Tethers Unlimited) recicla plástico de embalajes y piezas viejas para convertirlo otra vez en material de impresión."),
				Lang.t("En el juego, los circuitos son lo más difícil de reponer: cuida cada uno."),
			]
		"ice_Luna":
			L = [
				Lang.t("Hielo de agua: en la superficie de la Luna el agua no se mantiene líquida, pero hay hielo escondido en cráteres cercanos a los polos donde nunca llega la luz del Sol."),
				Lang.t("En 2009, la misión LCROSS de la NASA lanzó una etapa de cohete contra el cráter Cabeus, cerca del polo sur, y analizó la nube de polvo: el suelo tenía cerca de 5,6 % de hielo de agua en masa (con un margen de error de ±2,9 %)."),
				Lang.t("El hielo se calienta para derretirlo y se limpia para beber. Con electricidad también se puede separar (electrólisis) en hidrógeno y oxígeno."),
			]
		_:
			L = [
				Lang.t("Hielo de agua: Marte tiene casquetes polares de hielo y también hielo enterrado bajo el suelo."),
				Lang.t("En 2008, la sonda Phoenix de la NASA excavó una zanja en Marte y dejó a la vista trozos brillantes que desaparecieron en pocos días: era hielo de agua que se evaporaba."),
				Lang.t("Después, el radar SHARAD del orbitador MRO encontró en Utopia Planitia (entre 39° y 49° de latitud norte) una capa de hielo de 80 a 170 m de grosor bajo 1 a 10 m de suelo, con tanta agua como el lago Superior."),
				Lang.t("Y en Marte ya se produjo oxígeno: el experimento MOXIE del rover Perseverance separó el dióxido de carbono del aire y obtuvo unos 122 g de oxígeno en 16 pruebas, lo que una persona respira en unas 4 horas."),
			]
	return L


# ---------- DIBUJO ----------

func _hf(x: int, y: int, salt: int) -> float:
	return float(absi(hash(Vector3i(x, y, salt))) % 1000) / 1000.0


func _cam_offset() -> Vector2:
	var view: Vector2 = _mv()
	if not outside:
		var room: Vector2 = Vector2(VIEW_W * TILE, VIEW_H * TILE)
		return -Vector2(maxf((view.x - room.x) / 2.0, 0.0), maxf((view.y - room.y) / 2.0, 0.0)).floor()
	var world: Vector2 = Vector2(EXT_W * TILE, EXT_H * TILE)
	var c: Vector2 = player_px + Vector2(TILE, TILE) / 2.0 - view / 2.0
	c.x = clampf(c.x, 0.0, world.x - view.x)
	c.y = clampf(c.y, 0.0, world.y - view.y)
	return c


func _on_map_draw(node: Control) -> void:
	if map_view == null or node != map_view:
		return
	_draw_map()


func _draw_map() -> void:
	cv = map_view
	var sk: Vector2 = Vector2.ZERO
	if shake_t > 0.0:
		sk = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_t * 7.0
	var use3d: bool = view3d_on and view3d != null
	var sz: Vector2 = _mv()
	var font: Font = ThemeDB.fallback_font
	if use3d:
		map_view.draw_texture_rect(vp3d.get_texture(), Rect2(Vector2.ZERO, sz), false)
		if cam_mode == 1:
			_draw_visor_hud()
	else:
		if outside:
			_draw_exterior(sk)
		else:
			_draw_interior(sk)
		map_view.draw_set_transform(Vector2.ZERO)
		var dl: Color = _daylight_overlay()
		if dl.a > 0.0:
			map_view.draw_rect(Rect2(Vector2.ZERO, sz), dl)
		if _is_night():
			map_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.05, 0.25, 0.42))
		if storm_left > 0:
			map_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.4, 0.22, 0.1, 0.42))
	if breach and not outside:
		var pulse: float = 0.5 + 0.5 * sin(t_anim * 5.0)
		map_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.9, 0.05, 0.05, 0.08 + 0.12 * pulse))
		map_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.1, 0.1, 0.4 + 0.5 * pulse), false, 6.0)
		var banner := Rect2(sz.x / 2.0 - 120.0, sz.y - 40.0, 240.0, 30.0)
		map_view.draw_rect(banner, Color(0.12, 0.0, 0.0, 0.85))
		map_view.draw_rect(banner, Color(1.0, 0.2, 0.2, 0.5 + 0.5 * pulse), false, 2.0)
		map_view.draw_string(font, banner.position + Vector2(20.0, 22.0), Lang.t("ALERTA ROJA: BRECHA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.4, 0.4))
	if flash_t > 0.0:
		map_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.85, 0.7, flash_t * 0.6))
	_draw_clock_hud()
	_draw_hand_hud()
	_draw_build_hud()
	if show_fps:
		map_view.draw_string(font, Vector2(sz.x / 2.0 + 92.0, 30.0), "FPS %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 1.0, 0.7))
	if outside:
		_draw_outdoor_hud()
	if cam_banner_t > 0.0 and use3d:
		_draw_cam_banner()
	if mode == 0:
		_draw_caption()


func _daylight_overlay() -> Color:
	if _is_night_clock():
		return Color(0.02, 0.04, 0.24, 0.4)
	if clock >= BED_FROM:
		var t: float = float(clock - BED_FROM) / 120.0
		return Color(0.9, 0.45, 0.15, 0.03 + 0.1 * t)
	return Color(0, 0, 0, 0)


func _draw_visor_hud() -> void:
	var sz: Vector2 = _mv()
	var font: Font = ThemeDB.fallback_font
	for i in 26:
		var f: float = 1.0 - float(i) / 26.0
		var a: float = 0.4 * f * f
		map_view.draw_rect(Rect2(Vector2(float(i) * 2.0 + 1.0, float(i) * 2.0 + 1.0), sz - Vector2(float(i) * 4.0 + 2.0, float(i) * 4.0 + 2.0)), Color(0.0, 0.02, 0.06, a), false, 2.0)
	map_view.draw_rect(Rect2(Vector2(3, 3), sz - Vector2(6, 6)), Color(0.5, 0.75, 1.0, 0.25), false, 2.0)
	map_view.draw_circle(sz / 2.0, 2.5, Color(1, 1, 1, 0.6))
	map_view.draw_arc(sz / 2.0, 9.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.5)
	var names8: Array = [Lang.t("Norte"), Lang.t("Noroeste"), Lang.t("Oeste"), Lang.t("Suroeste"), Lang.t("Sur"), Lang.t("Sureste"), Lang.t("Este"), Lang.t("Noreste")]
	var card: String = names8[int(round(fposmod(heading, TAU) / (PI / 4.0))) % 8]
	var w: Vector2 = font.get_string_size(Lang.t("Rumbo: ") + card, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var br := Rect2(sz.x / 2.0 - w.x / 2.0 - 8.0, 8.0, w.x + 16.0, 24.0)
	map_view.draw_rect(br, Color(0.04, 0.06, 0.12, 0.7))
	map_view.draw_string(font, br.position + Vector2(8.0, 17.0), Lang.t("Rumbo: ") + card, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.92, 1.0))


func _draw_cam_banner() -> void:
	var sz: Vector2 = _mv()
	var font: Font = ThemeDB.fallback_font
	var t: String = Lang.t("Cámara: ") + CAM_NAMES[cam_mode]
	var w: Vector2 = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var a: float = clampf(cam_banner_t, 0.0, 1.0)
	var br := Rect2(sz.x / 2.0 - w.x / 2.0 - 12.0, 40.0, w.x + 24.0, 28.0)
	map_view.draw_rect(br, Color(0.04, 0.05, 0.1, 0.85 * a))
	map_view.draw_rect(br, Color(0.5, 0.8, 1.0, 0.8 * a), false, 1.5)
	map_view.draw_string(font, br.position + Vector2(12.0, 19.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, a))


func _draw_outdoor_hud() -> void:
	var font: Font = ThemeDB.fallback_font
	var sz: Vector2 = _mv()
	var base_c: Vector2 = Vector2(float(BASE_X0 + 2), float(BASE_Y0 + 2))
	var v: Vector2 = base_c - player_px / float(TILE)
	var box := Rect2(sz.x / 2.0 - 80.0, 8.0, 160.0, 34.0)
	map_view.draw_rect(box, Color(0.05, 0.06, 0.12, 0.85))
	map_view.draw_rect(box, Color(0.5, 0.7, 1.0, 0.6), false, 1.0)
	var ctr: Vector2 = box.position + Vector2(18.0, 17.0)
	if v.length() > 0.5:
		var dir: Vector2 = v.normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		map_view.draw_colored_polygon(PackedVector2Array([ctr + dir * 12.0, ctr - dir * 7.0 + perp * 7.0, ctr - dir * 3.0, ctr - dir * 7.0 - perp * 7.0]), Color(1.0, 0.85, 0.3))
	map_view.draw_string(font, box.position + Vector2(38.0, 22.0), Lang.t("Base: %d casillas") % int(v.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	_draw_suit_bars(font, sz)
	if zone_banner_t > 0.0:
		var a: float = clampf(zone_banner_t, 0.0, 1.0)
		var w1: Vector2 = font.get_string_size(zone_banner_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var w2: Vector2 = font.get_string_size(zone_banner_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var bw: float = maxf(w1.x, w2.x) + 28.0
		var br := Rect2(sz.x / 2.0 + 40.0 - bw / 2.0, sz.y - 74.0, bw, 52.0)
		map_view.draw_rect(br, Color(0.04, 0.05, 0.1, 0.9 * a))
		map_view.draw_rect(br, Color(0.5, 0.8, 1.0, 0.8 * a), false, 1.5)
		map_view.draw_string(font, br.position + Vector2(14.0, 24.0), zone_banner_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 1.0, 1.0, a))
		map_view.draw_string(font, br.position + Vector2(14.0, 43.0), zone_banner_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.85, 1.0, a))


func _draw_suit_bars(font: Font, sz: Vector2) -> void:
	var x: float = sz.x / 2.0 - 80.0
	var items: Array = [
		[Lang.t("Aire del traje"), suit_o2 / _suit_max(), Color(0.45, 0.75, 1.0), "%d min" % int(suit_o2)],
		[Lang.t("Aguante"), stamina / _stam_max(), Color(1.0, 0.82, 0.3) if not exhausted else Color(1.0, 0.4, 0.3), ""]
	]
	for i in items.size():
		var it: Array = items[i]
		var r := Rect2(x, 46.0 + float(i) * 20.0, 160.0, 16.0)
		map_view.draw_rect(r, Color(0.05, 0.06, 0.12, 0.85))
		var f: float = clampf(float(it[1]), 0.0, 1.0)
		var col: Color = it[2]
		if i == 0 and f < 0.25:
			col = Color(1.0, 0.35, 0.3) if int(t_anim * 4.0) % 2 == 0 else Color(1.0, 0.7, 0.3)
		map_view.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2((r.size.x - 2.0) * f, r.size.y - 2.0)), col)
		map_view.draw_rect(r, Color(0.5, 0.7, 1.0, 0.6), false, 1.0)
		map_view.draw_string(font, r.position + Vector2(5.0, 12.0), "%s %s" % [str(it[0]), str(it[3])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.05, 0.1) if f > 0.5 else Color.WHITE)


func _draw_build_hud() -> void:
	if build.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var sz: Vector2 = _mv()
	var box := Rect2(sz.x - 232.0, sz.y - 170.0, 224.0, 38.0)
	map_view.draw_rect(box, Color(0.05, 0.06, 0.12, 0.88))
	map_view.draw_rect(box, Color(1.0, 0.75, 0.2, 0.85), false, 1.5)
	map_view.draw_string(font, box.position + Vector2(8.0, 15.0), Lang.t("Obra: %s (nv. %d)") % [_station_name(str(build["ch"])), int(build["lvl"])], HORIZONTAL_ALIGNMENT_LEFT, 208.0, 12, Color(1.0, 0.92, 0.65))
	var fr: float = 1.0 - float(build["left"]) / float(maxi(int(build["total"]), 1))
	map_view.draw_rect(Rect2(box.position + Vector2(8.0, 22.0), Vector2(150.0, 8.0)), Color(0.2, 0.22, 0.3))
	map_view.draw_rect(Rect2(box.position + Vector2(8.0, 22.0), Vector2(150.0 * clampf(fr, 0.0, 1.0), 8.0)), Color(1.0, 0.75, 0.2))
	map_view.draw_string(font, box.position + Vector2(166.0, 30.0), Lang.t("%d min") % int(build["left"]), HORIZONTAL_ALIGNMENT_LEFT, 50.0, 12, Color.WHITE)


func _draw_hand_hud() -> void:
	if held == "":
		return
	var font: Font = ThemeDB.fallback_font
	var sz: Vector2 = _mv()
	var box := Rect2(sz.x - 172.0, sz.y - 128.0, 164.0, 30.0)
	map_view.draw_rect(box, Color(0.05, 0.06, 0.12, 0.85))
	map_view.draw_rect(box, Color(1.0, 0.85, 0.3, 0.8), false, 1.5)
	var c: Vector2 = box.position + Vector2(17.0, 15.0)
	map_view.draw_rect(Rect2(c + Vector2(-8, -8), Vector2(16, 16)), Color(0.95, 0.55, 0.2))
	map_view.draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), Color(1, 1, 1, 0.6), 1.5)
	map_view.draw_line(c + Vector2(8, -8), c + Vector2(-8, 8), Color(1, 1, 1, 0.6), 1.5)
	map_view.draw_string(font, box.position + Vector2(36.0, 20.0), Lang.t("En mano: %s") % _tool_name(held), HORIZONTAL_ALIGNMENT_LEFT, 124.0, 13, Color(1.0, 0.95, 0.7))


func _draw_clock_hud() -> void:
	var font: Font = ThemeDB.fallback_font
	var sz: Vector2 = _mv()
	var box := Rect2(sz.x - 172.0, sz.y - 92.0, 164.0, 30.0)
	map_view.draw_rect(box, Color(0.05, 0.06, 0.12, 0.85))
	map_view.draw_rect(box, Color(0.5, 0.7, 1.0, 0.6), false, 1.0)
	var ic: Vector2 = box.position + Vector2(17.0, 15.0)
	if _is_night_clock():
		map_view.draw_circle(ic, 8.0, Color(0.92, 0.94, 1.0))
		map_view.draw_circle(ic + Vector2(4.0, -2.0), 7.0, Color(0.05, 0.06, 0.12))
	else:
		map_view.draw_circle(ic, 6.0, Color(1.0, 0.85, 0.25))
		for i in 8:
			var a: float = TAU * float(i) / 8.0
			map_view.draw_line(ic + Vector2(cos(a), sin(a)) * 8.0, ic + Vector2(cos(a), sin(a)) * 11.0, Color(1.0, 0.85, 0.25), 2.0)
	var tcol: Color = Color.WHITE
	if mode == 5:
		tcol = Color(1.0, 0.85, 0.3)
	map_view.draw_string(font, box.position + Vector2(36.0, 21.0), Lang.t("Día %d  %s") % [day, _clock_text()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tcol)
	if mode == 5:
		var pb := Rect2(sz.x - 172.0, sz.y - 116.0, 164.0, 20.0)
		var frac: float = clampf(1.0 - task_left / maxf(task_total, 0.001), 0.0, 1.0)
		var label: String = Lang.t("Fabricando") if task_is_craft else Lang.t("Trabajando")
		map_view.draw_rect(pb, Color(0.05, 0.06, 0.12, 0.9))
		map_view.draw_rect(Rect2(pb.position + Vector2(2, 2), Vector2(160.0 * frac, 16.0)), Color(1.0, 0.75, 0.2))
		map_view.draw_rect(pb, Color(1.0, 0.85, 0.3, 0.7), false, 1.0)
		map_view.draw_string(font, pb.position + Vector2(8.0, 15.0), "%s  x%d" % [label, int(task_speed / TIME_SCALE)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _draw_interior(sk: Vector2) -> void:
	map_view.draw_set_transform(sk - _cam_offset())
	var moon: bool = location == "Luna"
	var tex: Texture2D = _bake_interior_tex()
	if tex != null:
		map_view.draw_texture(tex, Vector2.ZERO)
		for t in _prop_tiles():
			var tp: Vector2i = t
			_draw_prop(MAP[tp.y][tp.x], Vector2(tp.x * TILE, tp.y * TILE), tp.x)
	else:
		var base_floor: Color = Color(0.46, 0.48, 0.56)
		if not moon:
			base_floor = Color(0.56, 0.37, 0.31)
		for y in MAP.size():
			var row: String = MAP[y]
			for x in row.length():
				var ch: String = row[x]
				var p: Vector2 = Vector2(x * TILE, y * TILE)
				if ch == "#":
					_draw_wall(x, y, p, moon)
				else:
					_draw_floor(x, y, p, base_floor)
					_draw_prop(ch, p, x)
	_draw_player_2d()


func _draw_exterior(sk: Vector2) -> void:
	var moon: bool = location == "Luna"
	var view: Vector2 = _mv()
	var cam: Vector2 = _cam_offset().floor() # entero: los bloques cacheados no se ven borrosos ni dejan costuras
	map_view.draw_set_transform(-cam + sk)
	var x0: int = maxi(int(cam.x / TILE), 0)
	var x1: int = mini(int((cam.x + view.x) / TILE) + 1, EXT_W - 1)
	var y0: int = maxi(int(cam.y / TILE), 0)
	var y1: int = mini(int((cam.y + view.y) / TILE) + 1, EXT_H - 1)
	var cs: int = BAKE_CH
	if dyn_tiles.is_empty():
		_bake_index()
	# Bloques nuevos: pocos por fotograma (el bloque visible primero, luego los de alrededor por adelantado)
	bake_budget = 4 if bake_ext.size() < 12 else 1
	var cx0: int = x0 / cs
	var cx1: int = x1 / cs
	var cy0: int = y0 / cs
	var cy1: int = y1 / cs
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var tex: Texture2D = _ext_chunk_tex(cx, cy)
			var tx0: int = maxi(cx * cs, x0)
			var tx1: int = mini(cx * cs + cs - 1, x1)
			var ty0: int = maxi(cy * cs, y0)
			var ty1: int = mini(cy * cs + cs - 1, y1)
			if tex != null:
				map_view.draw_texture(tex, Vector2(cx * cs * TILE, cy * cs * TILE))
				for t in dyn_tiles.get(Vector2i(cx, cy), []):
					var dt: Vector2i = t
					if dt.x >= tx0 and dt.x <= tx1 and dt.y >= ty0 and dt.y <= ty1:
						_draw_outdoor_tile(ext_rows[dt.y][dt.x], dt.x, dt.y, Vector2(dt.x * TILE, dt.y * TILE), moon, 2)
			else:
				# aun no esta listo: color plano del terreno (barato) en vez de dibujar casilla a casilla
				var zg: Color = zone_ground[_zone_at(mini(cx * cs + cs / 2, EXT_W - 1), mini(cy * cs + cs / 2, EXT_H - 1))] if not zone_ground.is_empty() else Color(0.4, 0.4, 0.42)
				map_view.draw_rect(Rect2(float(cx * cs * TILE), float(cy * cs * TILE), float(cs * TILE), float(cs * TILE)), zg.darkened(0.15))
	# precarga de los bloques que estan a punto de entrar en pantalla
	if bake_budget > 0:
		var mx: int = (EXT_W - 1) / cs
		var my: int = (EXT_H - 1) / cs
		for cy in range(maxi(cy0 - PRE_R, 0), mini(cy1 + PRE_R, my) + 1):
			for cx in range(maxi(cx0 - PRE_R, 0), mini(cx1 + PRE_R, mx) + 1):
				if bake_budget <= 0:
					break
				if not bake_ext.has(Vector2i(cx, cy)):
					_ext_chunk_tex(cx, cy)
	_draw_base_ext_2d()
	var c0: Vector2 = Vector2(float(BASE_X0 + 2) * TILE, float(BASE_Y0 - 1) * TILE)
	var dome := PackedVector2Array()
	for i in 17:
		var a: float = PI + PI * float(i) / 16.0
		dome.append(c0 + Vector2(cos(a), sin(a)) * 70.0)
	map_view.draw_colored_polygon(dome, Color(0.7, 0.85, 0.95, 0.5))
	map_view.draw_polyline(dome, Color(0.9, 0.97, 1.0), 3.0)
	_draw_player_2d()


# ---------- CACHE DE LA VISTA 2D ----------
# Dibujar ~450 casillas con 5-10 primitivas cada una en GDScript cada fotograma era lo que
# hacia lenta la vista 2D (sobre todo en el navegador). El terreno fijo se dibuja una sola vez
# en texturas (bloques de BAKE_CH x BAKE_CH casillas, creados bajo demanda); cada fotograma solo
# se copian esas texturas y se dibujan los objetos que cambian (cajas, vetas, hielo, placas).

const BAKE_CH: int = 6
const BAKE_MAX: int = 200
const PRE_R: int = 3 # anillo de bloques que se hornean por adelantado en los fotogramas libres
var bake_budget: int = 0
var cv: CanvasItem = null
var bake_ext: Dictionary = {}
var bake_in: Dictionary = {}
var dyn_tiles: Dictionary = {}
var prop_cache: Array = []


func _bake_clear() -> void:
	for k in bake_ext:
		(bake_ext[k]["vp"] as SubViewport).queue_free()
	bake_ext.clear()
	if not bake_in.is_empty():
		(bake_in["vp"] as SubViewport).queue_free()
		bake_in.clear()
	dyn_tiles.clear()


func _bake_index() -> void:
	dyn_tiles.clear()
	if ext_rows.size() == EXT_H:
		for y in EXT_H:
			var row: String = ext_rows[y]
			for x in EXT_W:
				var ch: String = row[x]
				if ch == "m" or ch == "c" or ch == "i" or ch == "L":
					var key := Vector2i(x / BAKE_CH, y / BAKE_CH)
					if not dyn_tiles.has(key):
						dyn_tiles[key] = []
					dyn_tiles[key].append(Vector2i(x, y))


func _make_bake_vp(w: int, h: int, cb: Callable) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(w, h)
	c.draw.connect(cb.bind(c))
	vp.add_child(c)
	add_child(vp)
	return {"vp": vp, "wait": 2, "used": Engine.get_process_frames()}


func _ext_chunk_tex(cx: int, cy: int) -> Texture2D:
	var key := Vector2i(cx, cy)
	var ent: Dictionary = bake_ext.get(key, {})
	if ent.is_empty():
		if bake_budget <= 0:
			return null
		bake_budget -= 1
		if bake_ext.size() >= BAKE_MAX:
			var oldest: Vector2i = key
			var oldest_use: int = 1 << 60
			for k in bake_ext:
				if int(bake_ext[k]["used"]) < oldest_use:
					oldest_use = int(bake_ext[k]["used"])
					oldest = k
			(bake_ext[oldest]["vp"] as SubViewport).queue_free()
			bake_ext.erase(oldest)
		var px: int = BAKE_CH * TILE + 1
		bake_ext[key] = _make_bake_vp(px, px, _bake_ext_draw.bind(cx, cy))
		return null
	ent["used"] = Engine.get_process_frames()
	if int(ent["wait"]) > 0:
		ent["wait"] = int(ent["wait"]) - 1
		return null
	return (ent["vp"] as SubViewport).get_texture()


func _bake_ext_draw(c: Control, cx: int, cy: int) -> void:
	cv = c
	var moon: bool = location == "Luna"
	var x0: int = cx * BAKE_CH
	var y0: int = cy * BAKE_CH
	for y in range(y0, mini(y0 + BAKE_CH + 1, EXT_H)):
		var row: String = ext_rows[y]
		for x in range(x0, mini(x0 + BAKE_CH + 1, EXT_W)):
			_draw_outdoor_tile(row[x], x, y, Vector2((x - x0) * TILE, (y - y0) * TILE), moon, 1)
	cv = map_view


func _bake_interior_tex() -> Texture2D:
	if not bake_in.is_empty() and bake_in.get("loc", "") != location:
		(bake_in["vp"] as SubViewport).queue_free()
		bake_in.clear()
	if bake_in.is_empty():
		var w: int = String(MAP[0]).length() * TILE
		var h: int = MAP.size() * TILE
		bake_in = _make_bake_vp(w, h, _bake_int_draw)
		bake_in["loc"] = location
		return null
	if int(bake_in["wait"]) > 0:
		bake_in["wait"] = int(bake_in["wait"]) - 1
		return null
	return (bake_in["vp"] as SubViewport).get_texture()


func _bake_int_draw(c: Control) -> void:
	cv = c
	var moon: bool = location == "Luna"
	var base_floor: Color = Color(0.46, 0.48, 0.56)
	if not moon:
		base_floor = Color(0.56, 0.37, 0.31)
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var p: Vector2 = Vector2(x * TILE, y * TILE)
			if row[x] == "#":
				_draw_wall(x, y, p, moon)
			else:
				_draw_floor(x, y, p, base_floor)
	cv = map_view


func _prop_tiles() -> Array:
	if prop_cache.is_empty():
		for y in MAP.size():
			var row: String = MAP[y]
			for x in row.length():
				var ch: String = row[x]
				if ch != "#" and ch != "." and ch != "P":
					prop_cache.append(Vector2i(x, y))
	return prop_cache


func _draw_ground(x: int, y: int, p: Vector2, ground: Color, crater: bool) -> void:
	var shade: float = (_hf(x, y, 1) - 0.5) * 0.1
	cv.draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(ground.r + shade, ground.g + shade, ground.b + shade))
	for i in 4:
		var sp: Vector2 = p + Vector2(_hf(x, y, 10 + i) * 36.0 + 2.0, _hf(x, y, 20 + i) * 36.0 + 2.0)
		cv.draw_circle(sp, 1.3, Color(0, 0, 0, 0.16))
	if crater and _hf(x, y, 7) < 0.06:
		var cc: Vector2 = p + Vector2(20, 20)
		cv.draw_circle(cc, 13, ground.darkened(0.12))
		cv.draw_arc(cc, 13, 0.0, TAU, 20, ground.lightened(0.15), 2.0)


func _draw_landmark(zid: int, p: Vector2) -> void:
	var zs: Array = _zones()
	var lm: String = zs[zid]["lm"]
	cv.draw_rect(Rect2(p + Vector2(6, 33), Vector2(28, 4)), Color(0, 0, 0, 0.25))
	match lm:
		"apollo":
			var gold: Color = Color(0.92, 0.75, 0.25)
			cv.draw_line(p + Vector2(10, 33), p + Vector2(15, 22), Color(0.7, 0.7, 0.75), 2.0)
			cv.draw_line(p + Vector2(27, 33), p + Vector2(22, 22), Color(0.7, 0.7, 0.75), 2.0)
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(11, 12), p + Vector2(25, 12), p + Vector2(29, 17), p + Vector2(29, 24), p + Vector2(7, 24), p + Vector2(7, 17)]), gold)
			cv.draw_rect(Rect2(p + Vector2(13, 14), Vector2(10, 6)), Color(0.15, 0.2, 0.3))
			cv.draw_line(p + Vector2(18, 12), p + Vector2(18, 5), Color(0.8, 0.8, 0.85), 2.0)
			cv.draw_line(p + Vector2(33, 33), p + Vector2(33, 8), Color(0.9, 0.9, 0.9), 2.0)
			cv.draw_rect(Rect2(p + Vector2(33, 8), Vector2(6, 6)), Color(0.95, 0.95, 0.95))
		"rover":
			cv.draw_rect(Rect2(p + Vector2(7, 18), Vector2(26, 8)), Color(0.88, 0.88, 0.9))
			cv.draw_rect(Rect2(p + Vector2(9, 14), Vector2(12, 4)), Color(0.1, 0.2, 0.55))
			for wx in [11, 20, 29]:
				cv.draw_circle(p + Vector2(float(wx), 29.0), 4.0, Color(0.15, 0.15, 0.18))
			cv.draw_line(p + Vector2(26, 18), p + Vector2(26, 8), Color(0.7, 0.7, 0.75), 2.0)
			cv.draw_rect(Rect2(p + Vector2(22, 5), Vector2(8, 4)), Color(0.3, 0.35, 0.45))
		"plaque":
			cv.draw_rect(Rect2(p + Vector2(14, 14), Vector2(12, 20)), Color(0.55, 0.57, 0.65))
			cv.draw_rect(Rect2(p + Vector2(14, 14), Vector2(12, 20)), Color(0.8, 0.85, 0.95), false, 1.5)
			cv.draw_line(p + Vector2(17, 20), p + Vector2(23, 20), Color(0.2, 0.22, 0.3), 2.0)
			cv.draw_line(p + Vector2(17, 25), p + Vector2(23, 25), Color(0.2, 0.22, 0.3), 2.0)
			var on: bool = int(t_anim * 2.0) % 2 == 0
			cv.draw_circle(p + Vector2(20, 9), 4.0, Color(0.3, 0.9, 1.0) if on else Color(0.1, 0.4, 0.5))
		"wreck":
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(5, 33), p + Vector2(10, 17), p + Vector2(24, 21), p + Vector2(19, 34)]), Color(0.75, 0.45, 0.2))
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(20, 30), p + Vector2(26, 14), p + Vector2(35, 18), p + Vector2(33, 33)]), Color(0.6, 0.62, 0.68))
			cv.draw_line(p + Vector2(10, 17), p + Vector2(16, 9), Color(0.5, 0.5, 0.55), 2.0)


# part: 0 = todo, 1 = solo lo estatico (se guarda en la cache), 2 = solo lo que cambia (cajas, vetas, hielo, placas)
func _draw_outdoor_tile(ch: String, x: int, y: int, p: Vector2, _moon: bool, part: int = 0) -> void:
	var do_s: bool = part != 2
	var do_d: bool = part != 1
	var zid: int = _zone_at(x, y)
	var ground: Color = zone_ground[zid]
	var rock: Color = zone_rock[zid]
	if ch == "#":
		if do_s:
			cv.draw_rect(Rect2(p, Vector2(TILE, TILE)), rock.darkened(0.45))
			var pts := PackedVector2Array([p + Vector2(0, 40), p + Vector2(4.0 + _hf(x, y, 1) * 12.0, 10), p + Vector2(20, 2.0 + _hf(x, y, 2) * 8.0), p + Vector2(34, 12), p + Vector2(40, 40)])
			cv.draw_colored_polygon(pts, rock)
			cv.draw_line(pts[1], pts[2], rock.lightened(0.3), 2.0)
		return
	if ch == "X":
		if do_s:
			cv.draw_rect(Rect2(p, Vector2(TILE, TILE)), rock.darkened(0.75))
			if _tile(Vector2i(x, y - 1)) != "X":
				cv.draw_rect(Rect2(p, Vector2(TILE, 8)), rock.darkened(0.45))
				cv.draw_line(p, p + Vector2(TILE, 0), rock.lightened(0.2), 2.0)
			if _tile(Vector2i(x, y + 1)) != "X":
				cv.draw_line(p + Vector2(0, TILE - 1), p + Vector2(TILE, TILE - 1), rock.lightened(0.1), 2.0)
			for k in 3:
				cv.draw_circle(p + Vector2(_hf(x, y, 60 + k) * 36.0 + 2.0, _hf(x, y, 70 + k) * 36.0 + 2.0), 3.0, Color(0, 0, 0, 0.25))
		return
	if ch == "H" or ch == "D":
		if do_s:
			cv.draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0.32, 0.35, 0.44))
			cv.draw_rect(Rect2(p + Vector2(1, 1), Vector2(38, 38)), Color(0.5, 0.54, 0.64))
			cv.draw_rect(Rect2(p + Vector2(1, 24), Vector2(38, 15)), Color(0.42, 0.46, 0.57))
			cv.draw_line(p + Vector2(1, 24), p + Vector2(39, 24), Color(0.28, 0.3, 0.38), 1.5)
			for rv in 2:
				cv.draw_circle(p + Vector2(5.0 + float(rv) * 30.0, 30.0), 1.5, Color(0.8, 0.84, 0.92))
			if _tile(Vector2i(x, y - 1)) != "H":
				cv.draw_rect(Rect2(p, Vector2(TILE, 5)), Color(0.82, 0.86, 0.96))
				cv.draw_line(p + Vector2(0, 5), p + Vector2(40, 5), Color(0.25, 0.28, 0.36), 1.5)
			if ch == "H" and (x + BASE_X0) % 2 == 0:
				cv.draw_rect(Rect2(p + Vector2(8, 9), Vector2(24, 11)), Color(0.15, 0.17, 0.25))
				cv.draw_rect(Rect2(p + Vector2(10, 11), Vector2(20, 7)), Color(1.0, 0.9, 0.5, 0.9) if _hf(x, y, 5) < 0.8 else Color(0.5, 0.8, 1.0, 0.85))
			if ch == "D":
				cv.draw_rect(Rect2(p + Vector2(6, 4), Vector2(28, 36)), Color(0.18, 0.2, 0.27))
				for i in range(0, 4):
					cv.draw_rect(Rect2(p + Vector2(6, 6 + i * 8), Vector2(28, 4)), Color(0.95, 0.8, 0.1, 0.8))
				cv.draw_circle(p + Vector2(20, 3), 3, Color(0.2, 1.0, 0.4))
		return
	if do_s:
		_draw_ground(x, y, p, ground, ch == ".")
	if ch == "L":
		if do_d:
			_draw_landmark(zid, p)
		return
	var dyn: bool = ch == "m" or ch == "c" or ch == "i"
	if dyn and not do_d:
		return
	if not dyn and not do_s:
		return
	if dyn and _is_depleted(x, y):
		cv.draw_circle(p + Vector2(20, 26), 5, rock.darkened(0.2))
		cv.draw_circle(p + Vector2(13, 29), 3, rock.darkened(0.1))
		return
	if ch != ".":
		cv.draw_rect(Rect2(p + Vector2(6, 33), Vector2(28, 4)), Color(0, 0, 0, 0.22))
	match ch:
		"r":
			cv.draw_circle(p + Vector2(20, 24), 14, rock)
			cv.draw_circle(p + Vector2(16, 20), 6, rock.lightened(0.15))
		"m":
			var poly := PackedVector2Array([p + Vector2(6, 34), p + Vector2(10, 14), p + Vector2(24, 8), p + Vector2(34, 22), p + Vector2(32, 34)])
			cv.draw_colored_polygon(poly, rock.darkened(0.25))
			for i in 4:
				cv.draw_circle(p + Vector2(12.0 + _hf(x, y, 40 + i) * 18.0, 14.0 + _hf(x, y, 50 + i) * 16.0), 1.8, Color(0.85, 0.9, 1.0))
			cv.draw_circle(p + Vector2(22, 20), 2.0, Color(0.9, 0.75, 0.3))
		"c":
			cv.draw_rect(Rect2(p + Vector2(7, 12), Vector2(26, 22)), Color(0.78, 0.72, 0.3))
			cv.draw_rect(Rect2(p + Vector2(7, 12), Vector2(26, 22)), Color(0.3, 0.27, 0.1), false, 2.0)
			cv.draw_line(p + Vector2(7, 20), p + Vector2(33, 20), Color(0.3, 0.27, 0.1), 2.0)
			cv.draw_line(p + Vector2(20, 12), p + Vector2(20, 34), Color(0.3, 0.27, 0.1), 2.0)
			var on: bool = int(t_anim * 2.0 + float(x)) % 2 == 0
			cv.draw_circle(p + Vector2(30, 10), 2.5, Color(1.0, 0.3, 0.2) if on else Color(0.4, 0.1, 0.1))
		"i":
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(8, 34), p + Vector2(14, 12), p + Vector2(20, 34)]), Color(0.7, 0.9, 1.0))
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(16, 34), p + Vector2(24, 6), p + Vector2(32, 34)]), Color(0.55, 0.85, 1.0))
			cv.draw_line(p + Vector2(24, 8), p + Vector2(22, 28), Color(1, 1, 1, 0.7), 2.0)


func _draw_floor(x: int, y: int, p: Vector2, base: Color) -> void:
	var shade: float = (_hf(x, y, 1) - 0.5) * 0.08
	var c: Color = Color(base.r + shade, base.g + shade, base.b + shade)
	cv.draw_rect(Rect2(p, Vector2(TILE, TILE)), c)
	cv.draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0, 0, 0, 0.18), false, 1.0)
	cv.draw_line(p + Vector2(1, 1), p + Vector2(TILE - 1, 1), Color(1, 1, 1, 0.07), 1.0)
	for i in 3:
		var sp: Vector2 = p + Vector2(_hf(x, y, 10 + i) * 36.0 + 2.0, _hf(x, y, 20 + i) * 36.0 + 2.0)
		cv.draw_circle(sp, 1.2, Color(0, 0, 0, 0.18))


func _draw_wall(x: int, y: int, p: Vector2, moon: bool) -> void:
	cv.draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0.2, 0.22, 0.3))
	if y == 0 and x % 3 == 1 and x > 0 and x < 15:
		_draw_window(x, p, moon)
		return
	cv.draw_rect(Rect2(p + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)), Color(0.26, 0.29, 0.38))
	cv.draw_line(p + Vector2(2, 2), p + Vector2(TILE - 2, 2), Color(0.45, 0.5, 0.62), 2.0)
	cv.draw_line(p + Vector2(2, TILE - 2), p + Vector2(TILE - 2, TILE - 2), Color(0.1, 0.11, 0.16), 2.0)
	for c in [Vector2(6, 6), Vector2(34, 6), Vector2(6, 34), Vector2(34, 34)]:
		var off: Vector2 = c
		cv.draw_circle(p + off, 1.5, Color(0.6, 0.65, 0.75))


func _draw_window(x: int, p: Vector2, moon: bool) -> void:
	var w := Rect2(p + Vector2(3, 3), Vector2(TILE - 6, TILE - 6))
	if moon:
		cv.draw_rect(w, Color(0.02, 0.02, 0.06))
		for i in 6:
			cv.draw_circle(w.position + Vector2(_hf(x, 0, 30 + i) * w.size.x, _hf(x, 0, 40 + i) * (w.size.y - 12.0)), 0.9, Color(1, 1, 1, 0.9))
		if x == 7:
			cv.draw_circle(w.position + Vector2(22, 12), 7, Color(0.2, 0.45, 0.9))
			cv.draw_circle(w.position + Vector2(20, 11), 3, Color(0.3, 0.7, 0.4))
		cv.draw_rect(Rect2(w.position + Vector2(0, w.size.y - 8), Vector2(w.size.x, 8)), Color(0.5, 0.5, 0.54))
	else:
		cv.draw_rect(w, Color(0.85, 0.55, 0.4))
		cv.draw_circle(w.position + Vector2(24, 10), 3, Color(1, 0.9, 0.7))
		cv.draw_rect(Rect2(w.position + Vector2(0, w.size.y - 10), Vector2(w.size.x, 10)), Color(0.55, 0.28, 0.2))
	cv.draw_rect(w, Color(0.7, 0.75, 0.85), false, 2.0)


func _draw_prop(ch: String, p: Vector2, tx: int) -> void:
	if ch == "." or ch == "P":
		return
	if npcs.has(ch):
		var n: Dictionary = npcs[ch]
		var bob: float = sin(t_anim * 2.0 + float(tx)) * 1.0
		if ch == "k":
			_draw_enoc_2d(n["suit"])
			return
		_draw_astronaut(p + Vector2(0, bob), n["suit"], Vector2i(0, 1), false)
		return
	if ch != "D":
		map_view.draw_rect(Rect2(p + Vector2(6, 33), Vector2(28, 4)), Color(0, 0, 0, 0.25))
	match ch:
		"O":
			map_view.draw_rect(Rect2(p + Vector2(9, 8), Vector2(22, 24)), Color(0.6, 0.82, 1.0))
			map_view.draw_circle(p + Vector2(20, 8), 11, Color(0.6, 0.82, 1.0))
			map_view.draw_circle(p + Vector2(20, 32), 11, Color(0.5, 0.72, 0.95))
			map_view.draw_rect(Rect2(p + Vector2(9, 17), Vector2(22, 8)), Color(0.15, 0.4, 0.8))
			map_view.draw_string(ThemeDB.fallback_font, p + Vector2(13, 24), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
			map_view.draw_rect(Rect2(p + Vector2(17, 0), Vector2(6, 4)), Color(0.8, 0.8, 0.85))
		"S":
			map_view.draw_line(p + Vector2(20, 34), p + Vector2(20, 22), Color(0.6, 0.6, 0.65), 3.0)
			map_view.draw_rect(Rect2(p + Vector2(12, 33), Vector2(16, 3)), Color(0.5, 0.5, 0.55))
			var q := PackedVector2Array([p + Vector2(4, 26), p + Vector2(34, 26), p + Vector2(37, 6), p + Vector2(7, 6)])
			map_view.draw_colored_polygon(q, Color(0.1, 0.2, 0.55))
			for i in range(1, 4):
				var t: float = float(i) / 4.0
				map_view.draw_line(q[0].lerp(q[1], t), q[3].lerp(q[2], t), Color(0.5, 0.6, 0.9, 0.7), 1.0)
			map_view.draw_line(q[0].lerp(q[3], 0.5), q[1].lerp(q[2], 0.5), Color(0.5, 0.6, 0.9, 0.7), 1.0)
			map_view.draw_polyline(PackedVector2Array([q[0], q[1], q[2], q[3], q[0]]), Color(0.8, 0.85, 1.0), 1.5)
		"G":
			var pts := PackedVector2Array()
			for i in 13:
				var a: float = PI + PI * float(i) / 12.0
				pts.append(p + Vector2(20, 26) + Vector2(cos(a), sin(a)) * 14.0)
			map_view.draw_colored_polygon(pts, Color(0.55, 0.95, 0.75, 0.65))
			map_view.draw_rect(Rect2(p + Vector2(6, 26), Vector2(28, 8)), Color(0.35, 0.3, 0.3))
			map_view.draw_line(p + Vector2(20, 26), p + Vector2(20, 15), Color(0.2, 0.6, 0.2), 2.0)
			map_view.draw_circle(p + Vector2(16, 17), 3.5, Color(0.2, 0.7, 0.25))
			map_view.draw_circle(p + Vector2(24, 15), 3.5, Color(0.25, 0.8, 0.3))
			map_view.draw_polyline(pts, Color(0.85, 1.0, 0.95), 2.0)
		"W":
			map_view.draw_rect(Rect2(p + Vector2(8, 16), Vector2(24, 20)), Color(0.75, 0.82, 0.9))
			map_view.draw_rect(Rect2(p + Vector2(10, 22), Vector2(20, 12)), Color(0.2, 0.5, 0.9))
			map_view.draw_line(p + Vector2(10, 26), p + Vector2(30, 26), Color(0.6, 0.8, 1.0), 2.0)
			map_view.draw_rect(Rect2(p + Vector2(8, 16), Vector2(24, 20)), Color(0.4, 0.45, 0.55), false, 2.0)
			map_view.draw_colored_polygon(PackedVector2Array([p + Vector2(20, 1), p + Vector2(24, 9), p + Vector2(16, 9)]), Color(0.3, 0.7, 1.0))
			map_view.draw_circle(p + Vector2(20, 10), 4.5, Color(0.3, 0.7, 1.0))
		"R":
			var ctr: Vector2 = p + Vector2(20, 20)
			var sh := PackedVector2Array([p + Vector2(20, 3), p + Vector2(35, 9), p + Vector2(33, 26), p + Vector2(20, 37), p + Vector2(7, 26), p + Vector2(5, 9)])
			var body_col: Color = Color(0.5, 0.28, 0.75)
			var core_col: Color = Color(0.7, 0.45, 0.95)
			if breach:
				var on_r: bool = int(t_anim * 4.0) % 2 == 0
				body_col = Color(0.8, 0.1, 0.1) if on_r else Color(0.45, 0.08, 0.08)
				core_col = Color(1.0, 0.35, 0.3)
			map_view.draw_colored_polygon(sh, body_col)
			var inner := PackedVector2Array()
			for pt in sh:
				inner.append(ctr.lerp(pt, 0.7))
			map_view.draw_colored_polygon(inner, core_col)
			map_view.draw_circle(ctr, 6, Color(1.0, 0.85, 0.2))
			map_view.draw_circle(ctr, 2, Color(0.1, 0.1, 0.1))
		"C":
			map_view.draw_rect(Rect2(p + Vector2(5, 14), Vector2(30, 10)), Color(0.85, 0.45, 0.3))
			map_view.draw_rect(Rect2(p + Vector2(5, 24), Vector2(30, 9)), Color(1.0, 0.65, 0.45))
			map_view.draw_rect(Rect2(p + Vector2(3, 18), Vector2(4, 15)), Color(0.6, 0.3, 0.2))
			map_view.draw_rect(Rect2(p + Vector2(33, 18), Vector2(4, 15)), Color(0.6, 0.3, 0.2))
			map_view.draw_circle(p + Vector2(20, 7), 4, Color(1.0, 0.4, 0.5))
		"B":
			map_view.draw_rect(Rect2(p + Vector2(4, 8), Vector2(32, 26)), Color(0.55, 0.58, 0.68))
			map_view.draw_rect(Rect2(p + Vector2(6, 10), Vector2(28, 22)), Color(0.3, 0.45, 0.8))
			map_view.draw_rect(Rect2(p + Vector2(8, 12), Vector2(11, 8)), Color(0.95, 0.95, 1.0))
			map_view.draw_line(p + Vector2(6, 24), p + Vector2(34, 24), Color(0.2, 0.3, 0.6), 2.0)
		"T":
			map_view.draw_rect(Rect2(p + Vector2(4, 16), Vector2(32, 6)), Color(0.55, 0.57, 0.62))
			map_view.draw_rect(Rect2(p + Vector2(6, 22), Vector2(4, 12)), Color(0.35, 0.37, 0.42))
			map_view.draw_rect(Rect2(p + Vector2(30, 22), Vector2(4, 12)), Color(0.35, 0.37, 0.42))
			map_view.draw_circle(p + Vector2(14, 11), 5, Color(0.8, 0.7, 0.2))
			map_view.draw_circle(p + Vector2(14, 11), 2, Color(0.2, 0.2, 0.25))
			map_view.draw_line(p + Vector2(24, 15), p + Vector2(31, 6), Color(0.6, 0.4, 0.2), 3.0)
			map_view.draw_rect(Rect2(p + Vector2(28, 3), Vector2(8, 5)), Color(0.5, 0.5, 0.55))
		"A":
			map_view.draw_rect(Rect2(p + Vector2(8, 24), Vector2(24, 10)), Color(0.3, 0.33, 0.4))
			map_view.draw_line(p + Vector2(20, 24), p + Vector2(20, 12), Color(0.7, 0.7, 0.75), 2.0)
			map_view.draw_colored_polygon(PackedVector2Array([p + Vector2(10, 6), p + Vector2(30, 6), p + Vector2(20, 14)]), Color(0.85, 0.85, 0.9))
			var blink: bool = int(t_anim * 2.0) % 2 == 0
			map_view.draw_circle(p + Vector2(28, 29), 2.5, Color(0.2, 1.0, 0.3) if blink else Color(0.1, 0.3, 0.1))
		"D":
			map_view.draw_rect(Rect2(p + Vector2(4, 2), Vector2(32, 36)), Color(0.35, 0.38, 0.45))
			map_view.draw_rect(Rect2(p + Vector2(8, 6), Vector2(24, 32)), Color(0.18, 0.2, 0.27))
			for i in range(0, 4):
				map_view.draw_rect(Rect2(p + Vector2(8, 6 + i * 8), Vector2(24, 4)), Color(0.95, 0.8, 0.1, 0.8))
			map_view.draw_circle(p + Vector2(20, 4), 3, Color(0.2, 1.0, 0.4))
	if stations.has(ch):
		_draw_station_lvl(ch, p)


func _draw_enoc_2d(suit: Color) -> void:
	var p: Vector2 = enoc_px
	if enoc_px.x < 0.0:
		p = _enoc_home()
	var bob: float = 0.0
	if enoc_move:
		bob = absf(sin(t_anim * 12.0)) * 2.0
	_draw_astronaut(p + Vector2(0, -bob), suit, Vector2i(0, 1), false)
	if enoc_work:
		var sw: float = (sin(t_anim * 10.0) + 1.0) * 0.5
		var side: float = 1.0 if enoc_dir.x >= 0.0 else -1.0
		var hand: Vector2 = p + Vector2(20.0 + 10.0 * side, 22.0)
		var tip: Vector2 = hand + Vector2(6.0 * side, -14.0 + 20.0 * sw)
		map_view.draw_line(hand, tip, Color(0.6, 0.4, 0.2), 3.0)
		map_view.draw_rect(Rect2(tip - Vector2(5, 3), Vector2(10, 6)), Color(0.7, 0.72, 0.8))
		if sw > 0.85:
			for i in 4:
				var a: float = TAU * float(i) / 4.0 + t_anim * 3.0
				map_view.draw_circle(tip + Vector2(cos(a), sin(a)) * 7.0, 1.8, Color(1.0, 0.85, 0.3))


func _draw_station_lvl(ch: String, p: Vector2) -> void:
	var lv: int = int(st_lvl.get(ch, 0))
	var gold: Color = Color(1.0, 0.82, 0.25)
	if lv > 0:
		for i in lv:
			map_view.draw_circle(p + Vector2(11.0 + float(i) * 9.0, 38.0), 2.6, gold)
		match ch:
			"O":
				map_view.draw_circle(p + Vector2(36, 26), 4.5, Color(0.6, 0.82, 1.0))
				if lv >= 2:
					map_view.draw_circle(p + Vector2(4, 26), 4.5, Color(0.6, 0.82, 1.0))
				if lv >= 3:
					map_view.draw_rect(Rect2(p + Vector2(9, 12), Vector2(22, 3)), gold)
					map_view.draw_rect(Rect2(p + Vector2(9, 27), Vector2(22, 3)), gold)
			"S":
				map_view.draw_rect(Rect2(p + Vector2(31, 28), Vector2(8, 6)), Color(0.15, 0.3, 0.7))
				if lv >= 2:
					map_view.draw_rect(Rect2(p + Vector2(1, 28), Vector2(8, 6)), Color(0.15, 0.3, 0.7))
				if lv >= 3:
					map_view.draw_circle(p + Vector2(20, 3), 3.0, Color(0.5, 0.9, 1.0))
					map_view.draw_arc(p + Vector2(20, 3), 6.0, 0.0, TAU, 12, Color(0.5, 0.9, 1.0, 0.6), 1.0)
			"G":
				map_view.draw_circle(p + Vector2(34, 30), 4.0, Color(0.3, 0.8, 0.35))
				if lv >= 2:
					map_view.draw_rect(Rect2(p + Vector2(6, 2), Vector2(28, 3)), Color(0.8, 0.35, 0.95))
				if lv >= 3:
					for i in 3:
						map_view.draw_circle(p + Vector2(12.0 + float(i) * 8.0, 22.0), 2.2, Color(0.95, 0.25, 0.25))
			"W":
				map_view.draw_rect(Rect2(p + Vector2(33, 22), Vector2(6, 12)), Color(0.3, 0.6, 0.95))
				if lv >= 2:
					map_view.draw_line(p + Vector2(32, 26), p + Vector2(24, 12), Color(0.7, 0.75, 0.85), 2.0)
				if lv >= 3:
					map_view.draw_circle(p + Vector2(6, 30), 3.0, Color(0.3, 1.0, 0.5))
			"R":
				map_view.draw_arc(p + Vector2(20, 20), 18.0, 0.0, TAU, 24, Color(0.75, 0.5, 1.0, 0.8), 2.0)
				if lv >= 2:
					map_view.draw_arc(p + Vector2(20, 20), 14.0, 0.0, TAU, 24, Color(0.9, 0.7, 1.0, 0.8), 2.0)
				if lv >= 3:
					map_view.draw_circle(p + Vector2(20, 20), 21.0, Color(0.75, 0.5, 1.0, 0.18))
			"C":
				map_view.draw_circle(p + Vector2(3, 14), 3.0, Color(1.0, 0.9, 0.5))
				if lv >= 2:
					map_view.draw_rect(Rect2(p + Vector2(8, 34), Vector2(24, 4)), Color(0.55, 0.3, 0.5))
				if lv >= 3:
					for i in 5:
						map_view.draw_circle(p + Vector2(4.0 + float(i) * 8.0, 11.0), 1.8, Color(1.0, 0.85, 0.4) if (i + int(t_anim * 2.0)) % 2 == 0 else Color(1.0, 0.5, 0.5))
	if not build.is_empty() and str(build["ch"]) == ch:
		var yel: Color = Color(1.0, 0.8, 0.1)
		map_view.draw_rect(Rect2(p + Vector2(0, 0), Vector2(40, 40)), Color(0, 0, 0, 0.18))
		map_view.draw_rect(Rect2(p + Vector2(1, 1), Vector2(38, 38)), yel, false, 2.0)
		map_view.draw_line(p + Vector2(1, 1), p + Vector2(39, 39), yel, 2.0)
		map_view.draw_line(p + Vector2(39, 1), p + Vector2(1, 39), yel, 2.0)


func _draw_base_ext_2d() -> void:
	# piezas que aparecen alrededor de la base segun el nivel de cada estacion (dinamico, barato)
	var T: float = float(TILE)
	var bx: float = float(BASE_X0)
	var by: float = float(BASE_Y0)
	var metal: Color = Color(0.72, 0.75, 0.82)
	# paneles solares: 2 de base + 2 por nivel
	var np: int = 2 + 2 * int(st_lvl["S"])
	for i in np:
		var q: Vector2 = Vector2((bx - 2.0 + float(i) * 1.25) * T, (by - 3.0) * T)
		map_view.draw_line(q + Vector2(20, 40), q + Vector2(20, 26), metal.darkened(0.3), 3.0)
		var poly := PackedVector2Array([q + Vector2(2, 28), q + Vector2(38, 28), q + Vector2(40, 8), q + Vector2(4, 8)])
		map_view.draw_colored_polygon(poly, Color(0.1, 0.2, 0.55))
		map_view.draw_line(q + Vector2(21, 8), q + Vector2(20, 28), Color(0.5, 0.6, 0.9, 0.7), 1.0)
		map_view.draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color(0.8, 0.85, 1.0), 1.5)
	# tanques de oxigeno (oeste)
	for i in int(st_lvl["O"]):
		var q2: Vector2 = Vector2((bx - 6.0) * T, (by - 0.6 + float(i) * 1.2) * T)
		map_view.draw_rect(Rect2(q2 + Vector2(4, 8), Vector2(32, 24)), Color(0.6, 0.82, 1.0))
		map_view.draw_circle(q2 + Vector2(4, 20), 12, Color(0.55, 0.78, 0.98))
		map_view.draw_circle(q2 + Vector2(36, 20), 12, Color(0.55, 0.78, 0.98))
		map_view.draw_rect(Rect2(q2 + Vector2(16, 8), Vector2(6, 24)), Color(0.15, 0.4, 0.8))
		map_view.draw_line(q2 + Vector2(40, 20), q2 + Vector2(60, 20), metal, 3.0)
	# invernadero (cupula verde sobre el techo)
	var gl: int = int(st_lvl["G"])
	if gl > 0:
		var gc: Vector2 = Vector2((bx + 4.5) * T, (by - 1.0) * T)
		var gr: float = 20.0 + 9.0 * float(gl)
		var gp := PackedVector2Array()
		for i in 15:
			var a: float = PI + PI * float(i) / 14.0
			gp.append(gc + Vector2(cos(a), sin(a)) * gr)
		map_view.draw_colored_polygon(gp, Color(0.5, 0.95, 0.7, 0.45))
		map_view.draw_polyline(gp, Color(0.85, 1.0, 0.95), 2.0)
		for i in gl + 1:
			map_view.draw_circle(gc + Vector2(-gr * 0.5 + float(i) * gr * 0.5, -6.0), 4.0, Color(0.25, 0.75, 0.3))
	# torre de agua (este)
	var wl: int = int(st_lvl["W"])
	if wl > 0:
		for i in wl:
			var wq: Vector2 = Vector2((bx + 8.8 + float(i) * 1.3) * T, (by - 0.6) * T)
			map_view.draw_line(wq + Vector2(8, 40), wq + Vector2(14, 20), metal.darkened(0.3), 3.0)
			map_view.draw_line(wq + Vector2(32, 40), wq + Vector2(26, 20), metal.darkened(0.3), 3.0)
			map_view.draw_circle(wq + Vector2(20, 14), 14, Color(0.3, 0.6, 0.95))
			map_view.draw_arc(wq + Vector2(20, 14), 14, 0.0, TAU, 20, Color(0.8, 0.9, 1.0), 2.0)
	# pilonas del escudo
	var rl: int = int(st_lvl["R"])
	if rl > 0:
		var pyl: Array = [Vector2(bx - 4.2, by - 2.0), Vector2(bx + 7.2, by - 2.0)]
		if rl >= 2:
			pyl.append(Vector2(bx - 4.2, by + 3.4))
			pyl.append(Vector2(bx + 7.2, by + 3.4))
		for pv in pyl:
			var rq: Vector2 = (pv as Vector2) * T
			map_view.draw_rect(Rect2(rq + Vector2(16, 8), Vector2(8, 30)), Color(0.45, 0.28, 0.7))
			map_view.draw_circle(rq + Vector2(20, 6), 6.0, Color(0.85, 0.65, 1.0))
		if rl >= 3:
			map_view.draw_arc(Vector2((bx + 1.5) * T, (by + 1.0) * T), 6.4 * T, 0.0, TAU, 48, Color(0.75, 0.5, 1.0, 0.35), 3.0)
	# mirador del area de descanso (cupula en el techo, oeste)
	var cl: int = int(st_lvl["C"])
	if cl > 0:
		var cc: Vector2 = Vector2((bx - 1.5) * T, (by - 1.0) * T)
		var cr: float = 12.0 + 6.0 * float(cl)
		var cp := PackedVector2Array()
		for i in 13:
			var a2: float = PI + PI * float(i) / 12.0
			cp.append(cc + Vector2(cos(a2), sin(a2)) * cr)
		map_view.draw_colored_polygon(cp, Color(1.0, 0.7, 0.5, 0.45))
		map_view.draw_polyline(cp, Color(1.0, 0.9, 0.8), 2.0)
		if cl >= 3:
			map_view.draw_line(cc + Vector2(0, -4), cc + Vector2(16, -22), Color(0.85, 0.85, 0.9), 3.0)
		if cl >= 2:
			map_view.draw_circle(cc + Vector2(-cr - 8.0, 14.0), 3.0, Color(1.0, 0.9, 0.5))
			map_view.draw_circle(cc + Vector2(cr + 8.0, 14.0), 3.0, Color(1.0, 0.9, 0.5))


func _draw_player_2d() -> void:
	# en la vista 2D el salto se ve como un desplazamiento hacia arriba con sombra en el suelo
	if outside and (jump_z != 0.0 or fall_t >= 0.0):
		var c: Vector2 = player_px + Vector2(TILE, TILE) / 2.0 + Vector2(0, TILE * 0.35)
		var sc: float = clampf(1.0 - absf(jump_z) * 0.25, 0.3, 1.0)
		map_view.draw_circle(c, 10.0 * sc, Color(0, 0, 0, 0.35))
		if fall_t >= 0.0 and fall_t > FALL_TIME * 0.5:
			return
		_draw_astronaut(player_px + Vector2(0, -jump_z * 26.0), Color(0.97, 0.97, 1.0), facing, moving)
	else:
		_draw_astronaut(player_px, Color(0.97, 0.97, 1.0), facing, moving)


func _draw_astronaut(pos: Vector2, suit: Color, face: Vector2i, walking: bool) -> void:
	var p: Vector2 = pos
	var bob: float = 0.0
	if walking:
		bob = absf(sin(t_anim * 14.0)) * 3.0
	map_view.draw_circle(p + Vector2(20, 35), 8, Color(0, 0, 0, 0.25))
	p.y -= bob
	map_view.draw_rect(Rect2(p + Vector2(10, 19), Vector2(5, 11)), Color(0.6, 0.62, 0.7))
	map_view.draw_rect(Rect2(p + Vector2(14, 19), Vector2(13, 12)), suit)
	map_view.draw_rect(Rect2(p + Vector2(14, 31), Vector2(5, 5)), suit.darkened(0.2))
	map_view.draw_rect(Rect2(p + Vector2(22, 31), Vector2(5, 5)), suit.darkened(0.2))
	map_view.draw_rect(Rect2(p + Vector2(17, 23), Vector2(7, 4)), Color(0.9, 0.3, 0.3))
	map_view.draw_circle(p + Vector2(20, 14), 9, Color(0.97, 0.97, 1.0))
	if face.y >= 0:
		var vo: Vector2 = Vector2(face.x * 3, face.y * 2)
		map_view.draw_circle(p + Vector2(20, 14) + vo, 6, Color(0.1, 0.22, 0.45))
		map_view.draw_circle(p + Vector2(22, 12) + vo, 1.6, Color(0.7, 0.9, 1.0))


func _station_text(ch: String) -> String:
	var a: Dictionary = ACTIONS[stations[ch]["action"]]
	var parts := PackedStringArray()
	for k in a["fx"]:
		var v: int = a["fx"][k]
		var sign_str: String = "+" if v > 0 else ""
		parts.append("%s %s%d" % [NAMES[k], sign_str, v])
	return "%s  (%s)  - %s" % [a["name"], ", ".join(parts), _fmt_dur(int(a["mins"]))]


func _target_text() -> String:
	var np: Vector2i = _find_target()
	if np.x < 0:
		return ""
	var ch: String = _tile(np)
	if outside:
		match ch:
			"D":
				return Lang.t("[E] Volver a la base")
			"L":
				var lzs: Array = _zones()
				return Lang.t("[E] Leer la placa: %s (15 min)") % lzs[_zone_at(np.x, np.y)]["name"]
			"m", "c", "i":
				if _is_depleted(np.x, np.y):
					return Lang.t("Zona ya recogida (se renueva en unos días)")
				var what: String = Lang.t("Recoger chatarra (+2)")
				if ch == "c":
					what = Lang.t("Rescatar cargamento (+1 polímero, +1 circuitos)")
				elif ch == "i":
					what = Lang.t("Extraer hielo (+10 agua)")
				return Lang.t("[E] %s  - 30 min") % what
		return ""
	if stations.has(ch):
		var t: String = "[E] " + _station_text(ch)
		if not build.is_empty() and str(build["ch"]) == ch:
			return Lang.t("EN OBRA: ENOC trabaja aquí (%d min restantes)") % int(build["left"])
		if int(st_lvl[ch]) < MAX_UPG:
			t += Lang.t("   [U] Mejorar")
		if ch == "R" and breach:
			t += Lang.t("  ¡BRECHA! Parches: %d") % tools["patch"]
		return t
	match ch:
		"T":
			return Lang.t("[E] Banco de trabajo: fabricar herramientas (consume tiempo)")
		"A":
			return Lang.t("[E] Radio: hablar con Control")
		"D":
			return Lang.t("[E] Esclusa: salir a la superficie (10 min)")
		"B":
			if clock >= BED_FROM or clock < DAY_START:
				return Lang.t("[E] Cama: dormir hasta las 06:00")
			return Lang.t("Cama (puedes dormir desde las 18:00)")
	if npcs.has(ch):
		var n: Dictionary = npcs[ch]
		return Lang.t("[E] Hablar con %s (10 min)") % n["who"]
	return ""


func _draw_caption() -> void:
	var text: String = _target_text()
	if text == "":
		return
	var font: Font = ThemeDB.fallback_font
	var np: Vector2i = _find_target()
	var tp: Vector2 = Vector2(np * TILE) - _cam_offset()
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var box := Rect2(tp + Vector2(TILE / 2.0 - sz.x / 2.0 - 6.0, -26.0), sz + Vector2(12, 8))
	if view3d_on and view3d != null and cam_mode == 1:
		box = Rect2(Vector2(_mv().x / 2.0 - sz.x / 2.0 - 6.0, _mv().y / 2.0 + 34.0), sz + Vector2(12, 8))
		tp = Vector2(box.position.x, box.position.y)
	elif view3d_on and view3d != null:
		var sp: Vector2 = view3d.screen_of_tile(np.x, np.y)
		if sp.x < -500.0:
			return
		tp = sp - Vector2(float(TILE) / 2.0, 14.0 + float(TILE) / 2.0)
		box = Rect2(tp + Vector2(TILE / 2.0 - sz.x / 2.0 - 6.0, -26.0), sz + Vector2(12, 8))
	box.position.x = clampf(box.position.x, 2.0, _mv().x - box.size.x - 2.0)
	if box.position.y < 2.0:
		box.position.y = tp.y + TILE + 4.0
	map_view.draw_rect(box, Color(0.04, 0.05, 0.1, 0.92))
	map_view.draw_rect(box, Color(0.5, 0.7, 1.0), false, 1.0)
	map_view.draw_string(font, box.position + Vector2(6, sz.y - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


# ---------- DIÁLOGOS ----------

func _l(who: String, text: String) -> Dictionary:
	return {"who": who, "text": text}


func _easy_split(lines: Array) -> Array:
	# lectura facil: frases cortas, una idea por pantalla
	var out: Array = []
	var re := RegEx.new()
	re.compile("(?<=[.!?])\\s+")
	for ln in lines:
		if ln.has("choice") or not ln.has("text") or str(ln["text"]).contains("["):
			out.append(ln)
			continue
		var txt: String = str(ln["text"]).replace("Dra. ", "Dra.\u00a0").replace("Dr. ", "Dr.\u00a0")
		var parts: PackedStringArray = re.sub(txt, "\u0001", true).split("\u0001")
		var cur: String = ""
		for p in parts:
			if cur != "" and cur.length() + p.length() > 85:
				var d: Dictionary = ln.duplicate()
				d["text"] = cur.strip_edges().replace("\u00a0", " ")
				out.append(d)
				cur = ""
			cur += p + " "
		if cur.strip_edges() != "":
			var d2: Dictionary = ln.duplicate()
			d2["text"] = cur.strip_edges().replace("\u00a0", " ")
			out.append(d2)
	return out


func _start_dialog(lines: Array, after: Callable = Callable()) -> void:
	dlg.offset_top = -190.0 if not easy_read else -230.0
	dlg_text.add_theme_font_size_override("normal_font_size", 26 if easy_read else 18)
	dlg_name.add_theme_font_size_override("font_size", 26 if easy_read else 20)
	if easy_read:
		lines = _easy_split(lines)
	dlg_queue = lines.duplicate()
	dlg_after = after
	mode = 1
	dlg.visible = true
	_next_line()


func _show_text(who: String, text: String) -> void:
	dlg_name.text = Lang.speaker(who)
	var col: Color = Color(0.9, 0.9, 0.9)
	if speaker_colors.has(who):
		col = speaker_colors[who]
	dlg_name.add_theme_color_override("font_color", col)
	dlg_text.text = text
	dlg_text.visible_characters = 0
	type_pos = 0.0
	type_total = text.length()
	last_blip = 0
	typing = true


func _next_line() -> void:
	if dlg_queue.is_empty():
		_end_dialog()
		return
	var line: Dictionary = dlg_queue.pop_front()
	if line.has("choice"):
		choice_active = true
		choice_data = line["choice"]
		var t: String = line["text"]
		for i in choice_data.size():
			t += "\n[%d] %s" % [i + 1, choice_data[i]["label"]]
		_show_text(line["who"], t)
		dlg_hint.text = Lang.t("Elige con 1 o 2")
		return
	choice_active = false
	_show_text(line["who"], line["text"])
	dlg_hint.text = Lang.t("[E] continuar")


func _end_dialog() -> void:
	typing = false
	dlg.visible = false
	mode = 5 if task_left > 0.0 else 0
	if dlg_after.is_valid():
		var cb: Callable = dlg_after
		dlg_after = Callable()
		cb.call()


func _pick_choice(i: int) -> void:
	if i >= choice_data.size():
		return
	var c: Dictionary = choice_data[i]
	choice_active = false
	for k in c["fx"]:
		_add(k, c["fx"][k])
	if c.has("tag"):
		var tg: Array = c["tag"]
		var ch_dict: Dictionary = stats["choices"]
		ch_dict[tg[0]] = tg[1]
	_log(Lang.t("[color=yellow]Decisión: %s[/color]") % c["label"])
	_refresh()
	_sfx("interact")
	_fx("ring", "", Color(0.6, 0.85, 1.0))
	dlg_queue = c["reply"].duplicate()
	_next_line()


func _input_dialog(k: InputEventKey) -> void:
	if choice_active:
		if k.keycode == KEY_1:
			_pick_choice(0)
		elif k.keycode == KEY_2:
			_pick_choice(1)
		return
	if k.keycode == KEY_E or k.keycode == KEY_ENTER or k.keycode == KEY_SPACE:
		if typing:
			typing = false
			dlg_text.visible_characters = -1
		else:
			_sfx("next", -8.0)
			_next_line()


func _ask_sleep() -> void:
	if not (clock >= BED_FROM or clock < DAY_START):
		_sfx("error")
		_log(Lang.t("[color=orange]Aún no tienes sueño. Puedes dormir desde las 18:00.[/color]"))
		return
	mode = 2
	dlg.visible = true
	var hrs: String = _fmt_dur(posmod(DAY_START - clock, 1440))
	_show_text("Cama", Lang.t("Son las %s. ¿Dormir hasta las 06:00 (%s)?") % [_clock_text(), hrs])
	dlg_hint.text = Lang.t("[E] Dormir      [Esc] Cancelar")


func _input_confirm(k: InputEventKey) -> void:
	if k.keycode == KEY_E:
		dlg.visible = false
		typing = false
		mode = 0
		_sleep()
	elif k.keycode == KEY_ESCAPE:
		dlg.visible = false
		typing = false
		mode = 0


func _talk(ch: String) -> void:
	var n: Dictionary = npcs[ch]
	var lines: Array = []
	var bonus: bool = false
	stats["talks"] += 1
	if ch == "l" and ill_days > 0 and tools["medkit"] > 0:
		tools["medkit"] -= 1
		ill_days = 0
		_add("morale", 20)
		_sfx("good")
		_log(Lang.t("[color=lime]PAM usa el botiquín: la enfermedad desaparece (+20 moral).[/color]"))
		lines.append(_l("PAM", Lang.t("Con el botiquín que fabricaste puedo tratarlos ahora mismo. Gracias, Wilson.")))
		lines.append(_l("Narración", Lang.t("El equipo se recupera. Enfermedad curada.")))
		_refresh()
		_start_dialog(lines, _talk_after.bind(false))
		return
	if ch == "l" and ill_days > 0:
		lines.append(_l("PAM", Lang.t("Hay enfermos en la base. Necesito un botiquín: polímero y circuitos. Búscalos afuera y fabrícalo en el banco de trabajo.")))
	else:
		var worst_k: String = ""
		var worst_v: float = 101.0
		for k in n["domain"]:
			if res[k] < worst_v:
				worst_v = res[k]
				worst_k = k
		if worst_v < 40.0:
			var rn: String = NAMES[worst_k]
			var warn: String = n["warn"]
			lines.append(_l(n["who"], warn % rn.to_lower()))
		else:
			var fl: Array = n["flavor"]
			lines.append(_l(n["who"], fl[rng.randi_range(0, fl.size() - 1)]))
	if not talked_today.has(ch):
		talked_today[ch] = true
		lines.append(_l("Narración", Lang.t("Charlar con la tripulación te anima un poco (+3 moral).")))
		bonus = true
	_sfx("interact")
	_fx("ring", "", Color(0.6, 0.85, 1.0))
	_start_dialog(lines, _talk_after.bind(bonus))


func _talk_after(bonus: bool) -> void:
	if bonus:
		_add("morale", 3)
		_sfx("good", -8.0)
	_refresh()
	_start_task(10.0, TASK_SPEED)


func _radio() -> void:
	var lines: Array = []
	var left: int = MAX_DAYS - day
	if breach:
		lines.append(_l("Control", Lang.t("Perseo, vemos la brecha en su escudo. Fabriquen un kit de parche en el banco de trabajo y séllenla desde el generador de escudo.")))
	elif ill_days > 0:
		lines.append(_l("Control", Lang.t("Perseo, nos reportan enfermos. Un botiquín ayudará: hablen con PAM una vez que lo fabriquen.")))
	elif _is_night():
		lines.append(_l("Control", Lang.t("La noche lunar sigue. Los paneles rinden poco: planifiquen la energía. Rescate en %d días.") % left))
	elif storm_left > 0:
		lines.append(_l("Control", Lang.t("El polvo sigue en el aire. Un filtro de polvo reduce el daño. Rescate en %d días.") % left))
	elif _is_night_clock():
		lines.append(_l("Control", Lang.t("Perseo, es de noche en su turno. Descansen: el sueño también mantiene viva a la tripulación. Rescate en %d días.") % left))
	else:
		lines.append(_l("Control", Lang.t("Todo en orden por ahora, Perseo. El rescate llegará en %d días. Mantengan los sistemas estables.") % left))
	var bonus: bool = false
	if not talked_today.has("radio"):
		talked_today["radio"] = true
		lines.append(_l("Narración", Lang.t("Hablar con la Tierra te sube un poco el ánimo (+2 moral).")))
		bonus = true
	_sfx("interact")
	_fx("ring", "", Color(0.6, 0.85, 1.0))
	_start_dialog(lines, _radio_after.bind(bonus))


func _radio_after(bonus: bool) -> void:
	if bonus:
		_add("morale", 2)
	_refresh()
	_start_task(10.0, TASK_SPEED)


# ---------- BANCO DE TRABAJO ----------

func _can_craft(r: Dictionary) -> bool:
	for k in r["cost"]:
		if int(inv[k]) < int(r["cost"][k]):
			return false
	return true


func _open_craft() -> void:
	mode = 4
	dlg.visible = false
	bench_ui.call("open")


func _craft(i: int) -> void:
	var r: Dictionary = RECIPES[i]
	if r["id"] == "map" and int(tools["map"]) > 0:
		_sfx("error")
		_log(Lang.t("[color=orange]Ya tienes un mapa de navegación.[/color]"))
		return
	if not _can_craft(r):
		_sfx("error")
		return
	var neg: Dictionary = {}
	for k in r["cost"]:
		neg[k] = -int(r["cost"][k])
	if _slots_used(neg, {r["id"]: 1}) > _pack_cap():
		_sfx("error")
		_log(Lang.t("[color=orange]Mochila llena: no cabe lo que quieres fabricar. Mejórala en el banco de trabajo.[/color]"))
		return
	# primero el minijuego; los materiales solo se gastan si lo superas
	craft_pending = i
	mode = 7
	dlg.visible = false
	dlg.offset_top = -190.0
	bench_ui.visible = false
	mg.call("begin", r["id"], r["name"])


func _on_mg_done(ok: bool, mistakes: int) -> void:
	if not upg_pending.is_empty():
		_upg_done(ok)
		return
	var i: int = craft_pending
	craft_pending = -1
	if mode != 7 or i < 0:
		return
	if not ok:
		_open_craft()
		return
	var r: Dictionary = RECIPES[i]
	if not _can_craft(r):
		_open_craft()
		return
	for k in r["cost"]:
		inv[k] = int(inv[k]) - int(r["cost"][k])
	tools[r["id"]] += 1
	stats["tools_built"] += 1
	stats["minigames"] = int(stats.get("minigames", 0)) + 1
	_sfx("craft")
	_log(Lang.t("Fabricas: %s (%s). El tiempo se acelera mientras trabajas.") % [r["name"], _fmt_dur(int(r["mins"]))])
	if mistakes == 0:
		_log("[color=lime]" + Lang.t("Minijuego superado sin errores: ¡perfecto!") + "[/color]")
	else:
		_log(Lang.t("Minijuego superado con %d error(es).") % mistakes)
	_fx("craft", "", Color(1.0, 0.8, 0.3))
	_refresh()
	_close_craft()
	var go: Callable = _start_task.bind(float(r["mins"]), CRAFT_SPEED)
	var lk: String = "tool_" + str(r["id"])
	if not learned.has(lk):
		learned[lk] = true
		var info: Dictionary = (load("res://minigame_data.gd") as GDScript).call("tool_info", r["id"])
		if not info.is_empty():
			_top_info(str(info["title"]), info["pages"], go)
			return
	go.call()


func _close_craft() -> void:
	dlg.visible = false
	dlg.offset_top = -190.0
	bench_ui.visible = false
	mode = 0


func _input_craft(k: InputEventKey) -> void:
	bench_ui.call("handle_key", k)


# ---------- MEJORAS, MOCHILA Y TRAJE (sistema incremental) ----------

func _station_name(ch: String) -> String:
	match ch:
		"O":
			return Lang.t("Tanques de oxígeno")
		"S":
			return Lang.t("Paneles solares")
		"G":
			return Lang.t("Invernadero")
		"W":
			return Lang.t("Reciclador de agua")
		"R":
			return Lang.t("Generador de escudo")
	return Lang.t("Área de descanso")


func _upg_cost(id: String, lv_next: int) -> Dictionary:
	# [chatarra, polimero, circuitos] por nivel. Cada estacion pide mezclas distintas.
	var t: Dictionary = {
		"O": [[4, 3, 0], [6, 5, 1], [8, 8, 3]],
		"S": [[4, 0, 2], [6, 2, 4], [8, 4, 7]],
		"G": [[6, 2, 0], [9, 4, 1], [12, 6, 2]],
		"W": [[6, 0, 1], [9, 2, 3], [12, 3, 5]],
		"R": [[5, 0, 2], [8, 0, 4], [12, 3, 6]],
		"C": [[3, 3, 0], [5, 5, 1], [7, 8, 2]],
		"suit_o2": [[3, 2, 0], [5, 4, 1], [8, 6, 3]],
		"suit_st": [[3, 2, 1], [5, 3, 2], [7, 5, 4]],
		"pack": [[4, 3, 0], [6, 5, 1], [9, 7, 2]]
	}
	var row: Array = t[id][clampi(lv_next, 1, MAX_UPG) - 1]
	var c: Dictionary = {}
	if int(row[0]) > 0:
		c["scrap"] = int(row[0])
	if int(row[1]) > 0:
		c["polymer"] = int(row[1])
	if int(row[2]) > 0:
		c["circuits"] = int(row[2])
	return c


func _cost_text(c: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in c:
		parts.append("%d %s" % [int(c[k]), str(MAT_NAMES[k]).to_lower()])
	return ", ".join(parts)


func _can_pay(c: Dictionary) -> bool:
	for k in c:
		if int(inv[k]) < int(c[k]):
			return false
	return true


func _pay(c: Dictionary) -> void:
	for k in c:
		inv[k] = int(inv[k]) - int(c[k])


func _upg_level(id: String) -> int:
	match id:
		"suit_o2":
			return suit_lvl_o2
		"suit_st":
			return suit_lvl_st
	return pack_lvl


func _suit_max() -> float:
	return SUIT_O2_BASE + SUIT_O2_PER_LVL * float(suit_lvl_o2)


func _stam_max() -> float:
	return STAM_BASE + STAM_PER_LVL * float(suit_lvl_st)


func _pack_cap() -> int:
	return 8 + 4 * pack_lvl


func _slots_used(extra_inv: Dictionary = {}, extra_tools: Dictionary = {}) -> int:
	var n: int = 0
	for k in inv:
		n += int(ceil(float(maxi(int(inv[k]) + int(extra_inv.get(k, 0)), 0)) / float(STACK_MAT)))
	for k in tools:
		n += int(ceil(float(maxi(int(tools[k]) + int(extra_tools.get(k, 0)), 0)) / float(STACK_TOOL.get(k, 1))))
	return n


func _pack_room(extra_inv: Dictionary) -> bool:
	return _slots_used(extra_inv) <= _pack_cap()


# ---- objeto en la mano ----
func _cycle_hold() -> void:
	var opts: Array = [""]
	for h in HOLDABLE:
		if int(tools.get(h, 0)) > 0:
			opts.append(h)
	if opts.size() == 1:
		_log(Lang.t("[color=orange]No tienes nada que sostener: fabrica un kit de parche.[/color]"))
		_sfx("error")
		return
	_hold(str(opts[(opts.find(held) + 1) % opts.size()]))


func _hold(id: String) -> void:
	held = id
	_sfx("blip")
	if id == "":
		_log(Lang.t("Guardas el objeto en la mochila."))
	else:
		_log(Lang.t("En la mano: %s.") % _tool_name(id))
	_refresh()


func _tool_name(id: String) -> String:
	for r in RECIPES:
		if r["id"] == id:
			return str(r["name"])
	return id


# ---- ENOC: el obrero de la base ----
func _map_find(ch: String) -> Vector2i:
	for y in MAP.size():
		var x: int = String(MAP[y]).find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _enoc_home() -> Vector2:
	var t: Vector2i = _map_find("k")
	return Vector2(float(t.x * TILE), float(t.y * TILE))


func _enoc_work_tile(ch: String) -> Vector2i:
	var st: Vector2i = _map_find(ch)
	for o in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		var q: Vector2i = st + o
		if q.y >= 0 and q.y < MAP.size() and q.x >= 0 and q.x < String(MAP[q.y]).length():
			var c: String = String(MAP[q.y])[q.x]
			if c == "." or c == "k":
				return q
	return st


func _update_enoc(delta: float) -> void:
	if enoc_px.x < 0.0:
		enoc_px = _enoc_home()
	var target: Vector2 = _enoc_home()
	var st_t: Vector2i = Vector2i(-1, -1)
	if not build.is_empty():
		st_t = _map_find(str(build["ch"]))
		var wt: Vector2i = _enoc_work_tile(str(build["ch"]))
		target = Vector2(float(wt.x * TILE), float(wt.y * TILE))
	var d: Vector2 = target - enoc_px
	if d.length() > 2.0:
		enoc_move = true
		enoc_work = false
		var stp: Vector2 = d.normalized() * minf(ENOC_SPEED * delta, d.length())
		enoc_px += stp
		enoc_dir = d.normalized()
	else:
		enoc_px = target
		enoc_move = false
		enoc_work = not build.is_empty()
		if enoc_work:
			var fd: Vector2 = Vector2(float(st_t.x * TILE), float(st_t.y * TILE)) - enoc_px
			if fd.length() > 1.0:
				enoc_dir = fd.normalized()
			enoc_snd -= delta
			if enoc_snd <= 0.0 and not outside:
				enoc_snd = 0.55
				_sfx("blip", -13.0)
				if view3d != null and view3d_on:
					view3d.call("enoc_spark")


# ---- mejora de estaciones: [U] frente a la estacion; la obra la hace ENOC ----
func _build_mins(lvl: int) -> int:
	return 60 * lvl


func _open_upgrade(ch: String) -> void:
	var lv: int = int(st_lvl[ch])
	if lv >= MAX_UPG:
		_sfx("good")
		_log(Lang.t("[color=lime]%s ya está al nivel máximo.[/color]") % _station_name(ch))
		return
	if not build.is_empty():
		_sfx("error")
		_log(Lang.t("[color=orange]ENOC ya está trabajando en una obra. Solo puede con una a la vez.[/color]"))
		return
	var cost: Dictionary = _upg_cost(ch, lv + 1)
	upg_pending = {"kind": "station", "id": ch}
	var t: String = Lang.t("Nivel %d → %d. Cuesta: %s. Obra de ENOC: %d min de juego (la estación no se puede usar mientras tanto). Beneficio total: gasta un %d %% menos y rinde un %d %% más; además cambia su aspecto.") % [lv, lv + 1, _cost_text(cost), _build_mins(lv + 1), int(STATION_DRAIN_CUT * 100.0 * float(lv + 1)), int(STATION_BOOST * 100.0 * float(lv + 1))]
	if not _can_pay(cost):
		t += Lang.t("  [faltan materiales]")
	mode = 9
	dlg.offset_top = -190.0
	dlg.visible = true
	dlg_name.text = Lang.t("Mejorar: %s") % _station_name(ch)
	dlg_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	dlg_hint.text = Lang.t("[E] Encargar la obra a ENOC      [Esc] Cancelar")
	typing = false
	dlg_text.text = t
	dlg_text.visible_characters = -1


func _input_upgrade(k: InputEventKey) -> void:
	if k.keycode == KEY_ESCAPE:
		upg_pending = {}
		dlg.visible = false
		mode = 0
	elif k.keycode == KEY_E or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		var ch: String = str(upg_pending.get("id", ""))
		if ch == "" or not _can_pay(_upg_cost(ch, int(st_lvl[ch]) + 1)):
			_sfx("error")
			return
		upg_pending = {}
		dlg.visible = false
		mode = 0
		_start_build(ch)


func _try_upgrade() -> void:
	if outside:
		return
	var np: Vector2i = _find_target()
	if np.x < 0:
		return
	var ch: String = _tile(np)
	if stations.has(ch):
		_open_upgrade(ch)
	else:
		_log(Lang.t("Para mejorar, ponte frente a una estación y pulsa [U]."))
		_sfx("error")


func _start_build(ch: String) -> void:
	var lv: int = int(st_lvl[ch]) + 1
	_pay(_upg_cost(ch, lv))
	build = {"ch": ch, "left": _build_mins(lv), "total": _build_mins(lv), "lvl": lv}
	_sfx("craft")
	_fx("craft", "", Color(1.0, 0.8, 0.3))
	_log(Lang.t("[color=lime]ENOC empieza la obra de %s (nivel %d). Durará %d minutos de juego.[/color]") % [_station_name(ch), lv, _build_mins(lv)])
	if view3d != null:
		view3d.call("set_build", ch)
	_refresh()
	if not learned.has("build"):
		learned["build"] = true
		_top_info(Lang.t("Mejoras"), [
			Lang.t("Para qué sirve: cada mejora (3 niveles por estación) hace que esa estación gaste menos y rinda más, y cambia su aspecto. También crece el exterior de la base."),
			Lang.t("Cómo funciona: ponte frente a la estación y pulsa [U]. Paga materiales distintos en cada una. ENOC la construye en segundo plano: martilla y suelda mientras tú sigues jugando. La estación no se puede usar en obra.")], Callable())


func _progress_build(step: int) -> void:
	if build.is_empty():
		return
	build["left"] = int(build["left"]) - step
	if int(build["left"]) > 0:
		return
	var ch: String = str(build["ch"])
	var lv: int = int(build["lvl"])
	build = {}
	st_lvl[ch] = lv
	stats["upgrades"] = int(stats.get("upgrades", 0)) + 1
	_sfx("good")
	_fx("craft", "", Color(1.0, 0.8, 0.3))
	_log(Lang.t("[color=lime]¡Obra terminada! %s al nivel %d: gasta un %d %% menos y rinde un %d %% más.[/color]") % [_station_name(ch), lv, int(STATION_DRAIN_CUT * 100.0 * float(lv)), int(STATION_BOOST * 100.0 * float(lv))])
	if view3d != null:
		view3d.call("refresh_station", ch)
		view3d.call("set_build", "")
	map_view.queue_redraw()


# ---- mejoras del traje y la mochila (banco de trabajo, solo materiales) ----
func _upgrade_suit(idx: int) -> void:
	var ids: Array = ["suit_o2", "suit_st", "pack"]
	var id: String = ids[idx]
	var lv: int = _upg_level(id)
	if lv >= MAX_UPG:
		_sfx("error")
		return
	var cost: Dictionary = _upg_cost(id, lv + 1)
	if not _can_pay(cost):
		_sfx("error")
		return
	upg_pending = {"kind": "suit", "id": id}
	mode = 7
	bench_ui.visible = false
	dlg.visible = false
	dlg.offset_top = -190.0
	mg.call("begin", "upg_shapes", "")


func _upg_done(ok: bool) -> void:
	var p: Dictionary = upg_pending
	upg_pending = {}
	if not ok:
		if str(p.get("kind", "")) == "suit":
			_open_craft()
		else:
			mode = 0
		return
	var id: String = str(p["id"])
	var go: Callable = _start_task.bind(45.0, CRAFT_SPEED)
	var msg: String = ""
	if true:
		var lv2: int = _upg_level(id) + 1
		_pay(_upg_cost(id, lv2))
		match id:
			"suit_o2":
				suit_lvl_o2 = lv2
				suit_o2 = _suit_max()
				msg = Lang.t("Tanque del traje nivel %d: ahora tienes %d minutos de aire.") % [lv2, int(_suit_max())]
			"suit_st":
				suit_lvl_st = lv2
				stamina = _stam_max()
				msg = Lang.t("Aguante del traje nivel %d: puedes correr más tiempo y te recuperas más rápido.") % lv2
			_:
				pack_lvl = lv2
				msg = Lang.t("Mochila nivel %d: ahora tiene %d casillas.") % [lv2, _pack_cap()]
		_close_craft_if_open()
	stats["upgrades"] = int(stats.get("upgrades", 0)) + 1
	_sfx("craft")
	_fx("craft", "", Color(1.0, 0.8, 0.3))
	_log("[color=lime]" + msg + "[/color]")
	_refresh()
	if not learned.has("upgrades"):
		learned["upgrades"] = true
		_top_info(Lang.t("Mejoras del traje y la mochila"), [
			Lang.t("Para qué sirve: el tanque da más minutos de aire fuera de la base, el aguante te deja correr más con [Shift] y la mochila tiene más casillas."),
			Lang.t("Por qué importa: con los días el gasto sube, hay más eventos y la superficie da menos material. Sin mejoras tendrás que salir a buscar más cosas.")], go)
		return
	go.call()


func _close_craft_if_open() -> void:
	bench_ui.visible = false
	dlg.visible = false
	dlg.offset_top = -190.0
	mode = 0


# ---- traje: aire y aguante ----
func _refill_suit() -> void:
	var cost: float = 6.0 * (1.0 - suit_o2 / _suit_max())
	if cost > 0.5:
		_add("oxygen", -cost)
		_log(Lang.t("Recargas el traje: -%d oxígeno de la base.") % int(round(cost)))
	suit_o2 = _suit_max()
	suit_warn = 0
	stamina = _stam_max()
	exhausted = false


func _suit_drain(step: int) -> bool:
	var k: float = 1.5 if storm_left > 0 else 1.0
	suit_o2 -= float(step) * k
	var pct: float = suit_o2 / _suit_max()
	if pct <= 0.25 and suit_warn < 1:
		suit_warn = 1
		_sfx("bad", -8.0)
		_log(Lang.t("[color=orange]El aire del traje está al 25 %: vuelve a la base.[/color]"))
	if pct <= 0.1 and suit_warn < 2:
		suit_warn = 2
		_sfx("alarm", -10.0)
		_log(Lang.t("[color=red]¡Aire del traje casi agotado! Vuelve a la esclusa ya.[/color]"))
	if suit_o2 <= 0.0:
		_suit_collapse()
		return true
	return false


func _suit_collapse() -> void:
	stats["collapses"] = int(stats["collapses"]) + 1
	outside = false
	_set_player_tile(DOOR_FRONT, Vector2i(0, -1))
	cur_zone = -1
	task_left = 0.0
	task_kind = ""
	if mode == 5:
		mode = 0
	suit_o2 = _suit_max() * 0.4
	suit_warn = 0
	stamina = _stam_max() * 0.5
	exhausted = false
	_add("morale", -10)
	_add("energy", -10)
	_add("oxygen", -8)
	flash_t = 1.0
	shake_t = 0.6
	_sfx("bad")
	_log(Lang.t("[color=red]¡Te quedaste sin aire! ENOC te arrastra a la esclusa. Pierdes 2 horas recuperándote (-10 moral, -10 energía, -8 oxígeno). Mejora el tanque del traje.[/color]"))


func _stamina_regen(delta: float) -> void:
	if not playing:
		return
	if not sprint_frame:
		stamina = minf(_stam_max(), stamina + (STAM_REGEN + 2.0 * float(suit_lvl_st)) * delta)
		if exhausted and stamina >= 0.3 * _stam_max():
			exhausted = false
	sprint_frame = false


# ---------- HISTORIA ----------

func _story_for_day(d: int) -> void:
	story_seen[d] = true
	var lines: Array = _story_lines(d)
	if lines.is_empty():
		return
	_start_dialog(lines)


func _story_lines(d: int) -> Array:
	var mars: bool = location == "Marte"
	var place: String = Lang.t("Marte") if mars else Lang.t("la Luna")
	match d:
		1:
			return [
				_l("Narración", Lang.t("Misión Perseo, día 1. Cuatro astronautas viven en una base en %s.") % place),
				_l("Control", Lang.t("Perseo, aquí Control. Malas noticias: la nave de reabastecimiento sufrió una falla y no llegará.")),
				_l("Control", Lang.t("La nave de rescate sale de inmediato, pero tardará %d días en alcanzarlos.") % MAX_DAYS),
				_l("Dra. YARISBEL", Lang.t("Entendido, Control. Wilson, eres nuestro ingeniero y botánico. Necesito que esta base aguante un mes.")),
				_l("Wilson", Lang.t("Treinta días. He cultivado tomates con menos. Dame herramientas y un poco de optimismo.")),
				_l("ENOC", Lang.t("Yo vigilo el oxígeno, pero tú decides en qué gastamos la energía.")),
				_l("PAM", Lang.t("Y yo me encargo de que nadie pierda la cabeza. Hablen conmigo, con ENOC, con quien sea: ayuda.")),
				_l("Narración", Lang.t("Muévete con WASD. Mira una estación y presiona E para usarla. Cada acción consume tiempo: vigila el reloj en la esquina del mapa.")),
				_l("Narración", Lang.t("A las 20:00 empieza la noche. Si sigues despierto, bajan la energía y la moral. Puedes dormir en la cama desde las 18:00, aunque a veces hay pesadillas. Esc abre la pausa."))
			]
		3:
			return [
				_l("ENOC", Lang.t("Wilson, parte del cargamento perdido cayó cerca de la base: chatarra, polímeros, circuitos.")),
				_l("Wilson", Lang.t("Con eso y el banco de trabajo puedo fabricar herramientas para reparar casi cualquier cosa.")),
				_l("ENOC", Lang.t("La esclusa está en la esquina sur. Allá afuera el reloj sigue corriendo, así que no te distraigas.")),
				_l("Narración", Lang.t("Sal por la esclusa (mira la puerta y presiona E). Puedes explorar sin límite de pasos, pero el tiempo sigue corriendo. Recoge material y fabrica herramientas en el banco de trabajo."))
			]
		4:
			return [
				_l("Control", Lang.t("Perseo, tenemos imágenes de satélite de varias zonas cerca de su base. Fabriquen un mapa de navegación en el banco de trabajo para ubicarse.")),
				_l("Wilson", Lang.t("Con un mapa podré ver el terreno completo, mis rutas y cuánto me he alejado de la base.")),
				_l("Narración", Lang.t("Con el mapa (tecla Tab) verás todo el mundo y un minimapa. Cada zona tiene una placa con datos reales: acércate y presiona E."))
			]
		5:
			return [
				_l("ENOC", Lang.t("Wilson, los filtros de aire ya muestran desgaste. Si el oxígeno baja de 40, avísame.")),
				_l("Wilson", Lang.t("Anotado. Prefiero que las alarmas sigan apagadas."))
			]
		9:
			if mars:
				return [
					_l("Control", Lang.t("Perseo, los orbitadores ven polvo levantándose en su región. Prepárense para tormentas.")),
					_l("Wilson", Lang.t("Los paneles solares van a sufrir. Un filtro de polvo no vendría mal."))
				]
			return [
				_l("Control", Lang.t("Perseo, empieza la noche lunar: unos 14 días sin luz solar. Prioricen la energía.")),
				_l("Wilson", Lang.t("Entendido. Apagaremos las luces que no sirvan... bueno, casi todas."))
			]
		12:
			return [
				_l("Dra. YARISBEL", Lang.t("Wilson, la comida va justa. Necesito tu decisión: ¿reducimos raciones o cuidamos el ánimo del equipo?")),
				{"who": "Wilson", "text": Lang.t("Mi decisión:"), "choice": [
					{"label": Lang.t("Reducir raciones (+10 comida, -8 moral)"), "fx": {"food": 10, "morale": -8}, "tag": ["d12", "reducir"],
						"reply": [_l("PAM", Lang.t("Será duro, pero es lo más sensato. Yo vigilaré a todos."))]},
					{"label": Lang.t("Mantener raciones (+6 moral, -8 comida)"), "fx": {"morale": 6, "food": -8}, "tag": ["d12", "mantener"],
						"reply": [_l("ENOC", Lang.t("Esa es la actitud. Ya me quejaré del hambre más tarde."))]}
				]}
			]
		16:
			return [
				_l("PAM", Lang.t("Llevamos más de dos semanas encerrados. ENOC está muy callado.")),
				_l("PAM", Lang.t("Charlar con la tripulación sube la moral. No lo subestimes.")),
				_l("Wilson", Lang.t("Tomo nota: el equipo también es un recurso."))
			]
		20:
			return [
				_l("Control", Lang.t("Perseo, la nave de rescate cruzó el punto sin retorno. Diez días.")),
				_l("Wilson", Lang.t("Diez días. Ya casi huelo el aire fresco... filtrado, claro."))
			]
		22:
			return [
				_l("ENOC", Lang.t("Wilson, el sistema de agua tiene una grieta. Puedo repararla ahora, pero cuesta energía. O arriesgarnos a que aguante.")),
				{"who": "Wilson", "text": Lang.t("Mi decisión:"), "choice": [
					{"label": Lang.t("Reparar ahora (-8 energía, +10 agua)"), "fx": {"energy": -8, "water": 10}, "tag": ["d22", "reparar"],
						"reply": [_l("ENOC", Lang.t("Hecho. Un problema menos, aunque la batería lo siente."))]},
					{"label": Lang.t("Arriesgarse (+5 energía, -10 agua)"), "fx": {"energy": 5, "water": -10}, "tag": ["d22", "arriesgar"],
						"reply": [_l("ENOC", Lang.t("Cruzaré los dedos... y los cables."))]}
				]}
			]
		26:
			return [
				_l("Dra. YARISBEL", Lang.t("Cuatro días, Wilson. Pase lo que pase, gracias por no rendirte.")),
				_l("Wilson", Lang.t("Todavía no se acaba. Nadie baja la guardia."))
			]
	return []


func _ending_lines(eid: String) -> Array:
	var lines: Array = [
		_l("Control", Lang.t("Perseo, aquí Control. La nave de rescate está en órbita y lista para el acoplamiento.")),
		_l("Dra. YARISBEL", Lang.t("Lo logramos. Cuatro personas, treinta días y una base que no se rindió.")),
		_l("ENOC", Lang.t("Mis filtros jamás me habían caído tan bien.")),
		_l("PAM", Lang.t("Wilson, tu invernadero nos mantuvo con ánimo... y con comida."))
	]
	match eid:
		"heroes":
			lines.append(_l("Control", Lang.t("Informe final: sistemas estables, equipo sano y herramientas de sobra. Perseo será estudiada en las academias.")))
		"hilo":
			lines.append(_l("Dra. YARISBEL", Lang.t("Estuvimos a un paso del desastre. No lo olvidaremos.")))
		"ingenio":
			lines.append(_l("ENOC", Lang.t("Jamás vi a alguien fabricar tanto con tan poco.")))
		"unidos":
			lines.append(_l("PAM", Lang.t("Más que una tripulación, somos una familia.")))
		_:
			lines.append(_l("Dra. YARISBEL", Lang.t("Sobrevivimos. A veces eso es suficiente.")))
	lines.append(_l("Wilson", Lang.t("Para la próxima misión, pedimos más repuestos y menos suspenso.")))
	lines.append(_l("Narración", Lang.t("Misión Perseo: cumplida.")))
	return lines


func _pick_ending() -> String:
	var total: float = 0.0
	var lowest: float = 101.0
	for k in NAMES:
		total += res[k]
		lowest = minf(lowest, res[k])
	var avg: float = total / float(NAMES.size())
	if avg >= 65.0 and lowest >= 40.0 and int(stats["tools_built"]) >= 3:
		return "heroes"
	if lowest < 20.0:
		return "hilo"
	if int(stats["tools_built"]) >= 4 or int(stats["expeditions"]) >= 8:
		return "ingenio"
	if res["morale"] >= 70.0 and int(stats["talks"]) >= 10:
		return "unidos"
	return "supervivientes"


# ---------- ENTRADA ----------

func _input(event: InputEvent) -> void:
	var mmo := event as InputEventMouseMotion
	if mmo != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and playing and (mode == 0 or mode == 5):
			_mouse_look(mmo.relative)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and view3d_on and view3d != null and playing and (mode == 0 or mode == 5) and not _any_overlay():
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			view3d.zoom_by(-0.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			view3d.zoom_by(0.1)
		return
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	if k.keycode == KEY_F11:
		if not k.echo:
			_set_display_mode(0 if display_mode != 0 else 1)
		return
	if k.keycode == KEY_F3:
		if not k.echo:
			show_fps = not show_fps
			if ui != null:
				ui.sync_options()
		return
	if _any_overlay():
		if not k.echo:
			if k.keycode == KEY_ESCAPE:
				_close_top_overlay()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_F1:
				if ui.controls_overlay.visible:
					ui.close_controls()
				elif not ui.options_overlay.visible:
					ui.open_controls()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_F2:
				if ui.stats_overlay.visible:
					ui.close_stats()
				elif not ui.options_overlay.visible:
					ui.open_stats()
				get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_M and not k.echo:
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
		return
	if k.keycode == KEY_C and not k.echo and playing and mode == 0 and view3d_on and view3d != null:
		_cycle_cam()
		get_viewport().set_input_as_handled()
		return
	if (k.keycode == KEY_F1 or k.keycode == KEY_F2) and not k.echo and playing and mode == 0:
		if k.keycode == KEY_F1:
			ui.open_controls()
		else:
			ui.open_stats()
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_V and not k.echo and playing and mode == 0:
		_set_view3d(not view3d_on)
		_log(Lang.t("Vista %s.") % ("3D" if view3d_on else "2D"))
		get_viewport().set_input_as_handled()
		return
	if playing and tut != null and bool(tut.call("handle_skip_key", k)):
		get_viewport().set_input_as_handled()
		return
	if not playing:
		if in_menu and ui != null and k.keycode == KEY_ESCAPE and not k.echo and ui.cur_page != "main":
			ui.show_page("main")
		return
	match mode:
		1:
			if not k.echo:
				_input_dialog(k)
		2:
			if not k.echo:
				_input_confirm(k)
		4:
			if not k.echo:
				_input_craft(k)
		5:
			pass
		6:
			if not k.echo:
				_input_map(k)
		7:
			if not k.echo:
				mg.call("handle_key", k)
		9:
			if not k.echo:
				_input_upgrade(k)
		10:
			if not k.echo:
				pack_ui.call("handle_key", k)
		11:
			if not k.echo:
				_input_diary(k)
		12:
			if not k.echo:
				tut.call("handle_key", k)
		8:
			if not k.echo:
				_input_topinfo(k)
		_:
			_input_play(k)
	get_viewport().set_input_as_handled()


func _input_play(k: InputEventKey) -> void:
	match k.keycode:
		KEY_SPACE:
			if not k.echo:
				_start_jump()
		KEY_E:
			if not k.echo and not airborne and fall_t < 0.0:
				_interact()
		KEY_U:
			if not k.echo and not airborne and fall_t < 0.0:
				_try_upgrade()
		KEY_I:
			if not k.echo:
				_open_pack()
		KEY_Q:
			if not k.echo:
				_cycle_hold()
		KEY_TAB:
			if not k.echo:
				_open_world_map()
		KEY_J:
			if not k.echo:
				_open_diary()
		KEY_K:
			if not k.echo:
				tut.call("open_panel")
		KEY_ESCAPE:
			if not k.echo:
				_open_pause(true)


func _cur_rows() -> Array:
	if outside:
		return ext_rows
	return MAP


func _tile(p: Vector2i) -> String:
	var rows: Array = _cur_rows()
	if p.y < 0 or p.y >= rows.size():
		return "#"
	var row: String = rows[p.y]
	if p.x < 0 or p.x >= row.length():
		return "#"
	if not build.is_empty() and not outside and row[p.x] == "k":
		return "." # ENOC esta en la obra: su casilla queda libre
	return row[p.x]


func _interact() -> void:
	var np: Vector2i = _find_target()
	if np.x < 0:
		return
	var ch: String = _tile(np)
	if outside:
		if ch == "D":
			_exit_eva()
		elif ch == "m" or ch == "c" or ch == "i":
			_gather(ch, np)
		elif ch == "L":
			_read_landmark(np)
		return
	match ch:
		"B":
			_ask_sleep()
		"T":
			_open_craft()
		"A":
			_radio()
		"D":
			_door_inside()
		_:
			if stations.has(ch):
				_use_station(ch)
			elif npcs.has(ch):
				_talk(ch)


func _use_station(ch: String) -> void:
	var st: Dictionary = stations[ch]
	tut.call("event", "station")
	if not build.is_empty() and str(build["ch"]) == ch:
		_sfx("error")
		_log(Lang.t("[color=orange]%s está en obra: ENOC está trabajando. Espera a que termine.[/color]") % _station_name(ch))
		return
	_sfx("interact")
	_fx("ring", "", Color(0.6, 0.85, 1.0))
	if ch == "R" and breach:
		if tools["patch"] > 0:
			tools["patch"] -= 1
			breach = false
			_add("shield", 10)
			_sfx("craft")
			_log(Lang.t("[color=lime]Sellas la brecha con el kit de parche. Alerta roja desactivada (+10 escudo).[/color]"))
		else:
			_log(Lang.t("[color=orange]La brecha sigue abierta: fabrica un kit de parche en el banco de trabajo.[/color]"))
	_show_fact(ch)
	_do_action(st["action"])


func _show_fact(ch: String) -> void:
	if shown_facts.has(ch):
		return
	var f: String = ""
	match ch:
		"S":
			if location == "Luna":
				f = Lang.t("La noche lunar dura ~14 días terrestres, y los paneles solares no generan energía en ese tiempo. La NASA estudia energía nuclear (radioisótopos y fisión) para sobrevivirla.")
			else:
				f = Lang.t("Las tormentas de polvo de Marte bloquean la luz y cubren los paneles. En 2018 una tormenta global obligó al rover Opportunity, que usaba energía solar, a hibernar.")
		"W":
			f = Lang.t("En la ISS cada astronauta necesita ~1 galón (~3.8 L) de agua al día, y el sistema recupera ~98% del agua (antes 93-94%). Fuente: NASA.")
		"R":
			f = Lang.t("El rover Curiosity midió ~0.67 mSv/día en la superficie de Marte y ~1.8 mSv/día durante el viaje. La ISS recibe entre 0.4 y 1.0 mSv/día. Fuente: Hassler et al., Science 2013.")
	if f != "":
		shown_facts[ch] = true
		_log(Lang.t("[color=cyan][b]Dato real:[/b] %s[/color]") % f)


# ---------- GUARDADO ----------

func _save_game() -> bool:
	var data: Dictionary = {
		"version": 2, "saved_at": Time.get_datetime_string_from_system(false, true), "location": location, "day": day, "clock": clock, "difficulty": difficulty, "night_acc": night_acc,
		"slept": slept_tonight, "night_warned": night_warned, "awake": awake_min, "fatigue_warned": fatigue_warned, "res": res,
		"player": [player.x, player.y], "facing": [facing.x, facing.y],
		"outside": outside, "storm_left": storm_left,
		"ill_days": ill_days, "breach": breach, "inv": inv, "tools": tools,
		"st_lvl": st_lvl, "build": build, "pack_lvl": pack_lvl, "suit_lvl_o2": suit_lvl_o2, "suit_lvl_st": suit_lvl_st, "suit_o2": suit_o2, "stamina": stamina, "held": held,
		"shown_facts": shown_facts.keys(), "talked_today": talked_today.keys(),
		"story_seen": story_seen.keys(), "depleted": depleted, "stats": stats,
		"zones_seen": zones_seen.keys(), "studied": studied.keys(), "diary": diary, "learned": learned.keys(), "explored": Marshalls.raw_to_base64(explored), "history": history
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != 2:
		return false
	location = str(d["location"])
	day = int(d["day"])
	clock = int(d["clock"])
	difficulty = clampi(int(d["difficulty"]), 0, DIFFICULTIES.size() - 1)
	night_acc = int(d["night_acc"])
	slept_tonight = bool(d["slept"])
	night_warned = bool(d["night_warned"])
	awake_min = int(d.get("awake", 0))
	fatigue_warned = bool(d.get("fatigue_warned", false))
	pending_nightmare = {}
	res = {}
	for k in d["res"]:
		res[k] = float(d["res"][k])
	inv = {"scrap": 0, "polymer": 0, "circuits": 0}
	for k in d["inv"]:
		inv[k] = int(d["inv"][k])
	tools = {"patch": 0, "medkit": 0, "repair": 0, "filter": 0, "map": 0}
	for k in d["tools"]:
		tools[k] = int(d["tools"][k])
	st_lvl = {"O": 0, "S": 0, "G": 0, "W": 0, "R": 0, "C": 0}
	var sl: Dictionary = d.get("st_lvl", {})
	for k in sl:
		if st_lvl.has(k):
			st_lvl[k] = clampi(int(sl[k]), 0, MAX_UPG)
	pack_lvl = clampi(int(d.get("pack_lvl", 0)), 0, MAX_UPG)
	suit_lvl_o2 = clampi(int(d.get("suit_lvl_o2", 0)), 0, MAX_UPG)
	suit_lvl_st = clampi(int(d.get("suit_lvl_st", 0)), 0, MAX_UPG)
	suit_o2 = clampf(float(d.get("suit_o2", _suit_max())), 1.0, _suit_max())
	stamina = clampf(float(d.get("stamina", _stam_max())), 0.0, _stam_max())
	suit_warn = 0
	exhausted = false
	held = str(d.get("held", ""))
	build = {}
	var bd: Dictionary = d.get("build", {})
	if bd.has("ch") and stations.has(str(bd["ch"])):
		build = {"ch": str(bd["ch"]), "left": int(bd.get("left", 60)), "total": int(bd.get("total", 60)), "lvl": int(bd.get("lvl", 1))}
	upg_pending = {}
	var pl: Array = d["player"]
	player = Vector2i(int(pl[0]), int(pl[1]))
	var fc: Array = d["facing"]
	facing = Vector2i(int(fc[0]), int(fc[1]))
	outside = bool(d["outside"])
	time_acc = 0.0
	task_left = 0.0
	storm_left = int(d["storm_left"])
	ill_days = int(d["ill_days"])
	breach = bool(d["breach"])
	shown_facts = {}
	for k in d["shown_facts"]:
		shown_facts[str(k)] = true
	talked_today = {}
	for k in d["talked_today"]:
		talked_today[str(k)] = true
	story_seen = {}
	for k in d["story_seen"]:
		story_seen[int(k)] = true
	depleted = d["depleted"]
	stats = _default_stats()
	var sv: Dictionary = d["stats"]
	for k in stats:
		if sv.has(k):
			stats[k] = sv[k]
	_set_player_tile(player, facing)
	flash_t = 0.0
	shake_t = 0.0
	cur_zone = -1
	zone_banner_t = 0.0
	_build_exterior()
	zones_seen = {}
	for k in d.get("zones_seen", []):
		zones_seen[int(k)] = true
	learned = {}
	for k in d.get("learned", []):
		learned[str(k)] = true
	studied = {}
	for k in d.get("studied", []):
		studied[int(k)] = true
	diary = {}
	var dd: Variant = d.get("diary", {})
	if typeof(dd) == TYPE_DICTIONARY:
		for k in (dd as Dictionary).keys():
			var e: Variant = (dd as Dictionary)[k]
			if typeof(e) == TYPE_DICTIONARY:
				var ne: Dictionary = {}
				for kk in (e as Dictionary).keys():
					var arr: Variant = (e as Dictionary)[kk]
					if typeof(arr) == TYPE_ARRAY and (arr as Array).size() == 2:
						ne[str(kk)] = [int(arr[0]), int(arr[1])]
				diary[int(k)] = ne
	var ex: Variant = d.get("explored", "")
	if typeof(ex) == TYPE_STRING and str(ex) != "":
		var raw: PackedByteArray = Marshalls.base64_to_raw(str(ex))
		if raw.size() == EXT_W * EXT_H:
			explored = raw
	_build_minimap()
	view3d.setup()
	view3d.set_menu(false)
	history = []
	for h in d.get("history", []):
		history.append({"day": int(h["day"]), "res": h["res"]})
	return true


func _continue_game() -> void:
	if not _load_game():
		return
	in_menu = false
	preview_built = ""
	ui.close_menu()
	_build_game_ui()
	playing = true
	mode = 0
	_play_music(_wanted_music())
	_log(Lang.t("Partida cargada. Día %d en %s.") % [day, Lang.loc(location)])
	_refresh()
	if not story_seen.has(day):
		_story_for_day(day)


# ---------- SIMULACIÓN ----------

func _log(t: String) -> void:
	if log_box == null or not is_instance_valid(log_box):
		return
	log_box.append_text(t + "\n")


func _add(k: String, v: float) -> void:
	res[k] = clampf(res[k] + v, 0.0, 100.0)


func _refresh() -> void:
	if header == null or not is_instance_valid(header):
		return
	var tags: String = ""
	if _is_night():
		tags += Lang.t("  [NOCHE LUNAR]")
	if storm_left > 0:
		tags += Lang.t("  [TORMENTA DE POLVO]")
	if breach:
		tags += Lang.t("  [ALERTA ROJA: BRECHA]")
	if ill_days > 0:
		tags += Lang.t("  [ENFERMEDAD]")
	if _efficiency() < 1.0:
		tags += Lang.t("  [CANSADO]")
	if outside:
		tags += "  [EVA]"
	header.text = Lang.t("Día %d / %d  |  %s (%s)  |  %s  |  %s%s") % [day, MAX_DAYS, _clock_text(), _phase_name(), Lang.loc(location), DIFFICULTIES[difficulty]["name"], tags]
	if breach:
		header.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		header.remove_theme_color_override("font_color")
	for k in bars:
		bars[k].value = res[k]
		bars[k].modulate = Color(1, 0.55, 0.55) if res[k] < 30.0 else Color.WHITE
	inv_label.text = Lang.t("Materiales: Chatarra %d | Polímero %d | Circuitos %d\nHerramientas: Parche %d | Botiquín %d | Reparador %d | Filtro %d | Mapa: %s") % [inv["scrap"], inv["polymer"], inv["circuits"], tools["patch"], tools["medkit"], tools["repair"], tools["filter"], ("sí" if int(tools["map"]) > 0 else "no")]
	if held != "" and int(tools.get(held, 0)) <= 0:
		held = ""
	if inv_icons != null and is_instance_valid(inv_icons):
		inv_icons.call("refresh")


func _fx(kind: String, text: String, col: Color, mat: String = "") -> void:
	if view3d != null and is_instance_valid(view3d) and view3d_on:
		view3d.fx_event(kind, text, col)
	if mat != "":
		_fly_hud(mat)


func _fly_hud(id: String) -> void:
	if inv_icons != null and is_instance_valid(inv_icons):
		inv_icons.call("fly", id)


func _start_task(mins: float, speed: float, kind: String = "") -> void:
	if mins <= 0.0 or not playing:
		return
	task_left = mins
	task_total = mins
	task_speed = speed
	task_is_craft = speed >= CRAFT_SPEED
	task_kind = kind if kind != "" else ("craft" if task_is_craft else "")
	mode = 5
	dlg.visible = false


func _finish_task() -> void:
	var was_craft: bool = task_is_craft
	var kind_done: String = task_kind
	task_left = 0.0
	task_kind = ""
	if playing and kind_done == "craft":
		_fx("done", Lang.t("¡Listo!"), Color(1.0, 0.85, 0.4))
	elif playing and kind_done == "press":
		_fx("done", "", Color(0.5, 0.9, 1.0))
	if mode == 5:
		mode = 0
	if playing and was_craft and mode == 0:
		_open_craft()


func _run_time_acc() -> void:
	var guard: int = 0
	while time_acc >= 1.0 and playing and guard < 400:
		time_acc -= 1.0
		guard += 1
		_advance_time(1)
		if mode != 0 and mode != 5:
			break
	if not playing:
		time_acc = 0.0
	elif time_acc > 20.0:
		time_acc = 20.0


func _fmt_dur(mins: int) -> String:
	if mins < 60:
		return "%d min" % mins
	var h: int = floori(float(mins) / 60.0)
	var m: int = mins % 60
	if m == 0:
		return "%d h" % h
	return "%d h %02d" % [h, m]


func _clock_text() -> String:
	return "%02d:%02d" % [floori(float(clock) / 60.0), clock % 60]


func _is_night_clock() -> bool:
	return clock >= NIGHT_START or clock < DAY_START


func _phase_name() -> String:
	if _is_night_clock():
		return Lang.t("Noche")
	if clock < 720:
		return Lang.t("Mañana")
	if clock < BED_FROM:
		return Lang.t("Tarde")
	return Lang.t("Atardecer")


func _diff() -> Dictionary:
	return DIFFICULTIES[difficulty]


# ---------- DIFICULTAD INCREMENTAL ----------
# p va de 0 (dia 1) a 1 (ultimo dia). Con el tiempo gastas mas, pasan mas eventos y el material rinde menos.
func _prog() -> float:
	return clampf(float(day - 1) / float(MAX_DAYS - 1), 0.0, 1.0)


func _drain_k() -> float:
	return float(_diff()["drain"]) * (1.0 + _prog() * float(_diff()["g_drain"]))


func _events_p() -> float:
	return minf(float(_diff()["events"]) * (1.0 + _prog() * float(_diff()["g_ev"])), 0.97)


func _mat_k() -> float:
	return 1.0 - _prog() * float(_diff()["g_mat"])


func _respawn_days() -> int:
	return NODE_RESPAWN_DAYS + roundi(_prog() * float(_diff()["r_add"]))


# redondeo al azar: 2 * 0,7 = 1,4 -> 1 o 2 (en promedio 1,4)
func _yield(n: int) -> int:
	var f: float = float(n) * _mat_k()
	var base: int = floori(f)
	return base + (1 if rng.randf() < f - float(base) else 0)


func _efficiency() -> float:
	var fatigue: float = clampf(float(awake_min - 960) / 960.0, 0.0, 1.0)
	return 1.0 - 0.5 * fatigue


func _solar_penalty() -> bool:
	return _is_night() or storm_left > 0 or (location == "Marte" and _is_night_clock())


func _do_action(i: int) -> void:
	var a: Dictionary = ACTIONS[i]
	var factor: float = 1.0
	if i == 1 and _solar_penalty():
		factor = 0.6
		_log(Lang.t("[color=orange]Producción solar reducida (sin luz directa o con polvo): 60%.[/color]"))
	var eff: float = _efficiency()
	if eff < 1.0:
		_log(Lang.t("[color=orange]Estás cansado: tus acciones rinden un %d%%.[/color]") % int(eff * 100.0))
	var slv: int = int(st_lvl.get(ACTION_STATION[i], 0))
	var boost: float = 1.0 + STATION_BOOST * float(slv)
	for k in a["fx"]:
		var v: float = float(a["fx"][k])
		if v > 0.0:
			v *= factor * eff * boost
		_add(k, v)
	_log("• %s (%s)" % [a["name"], _fmt_dur(int(a["mins"]))])
	var parts: PackedStringArray = PackedStringArray()
	for k2 in a["fx"]:
		var v2: float = float(a["fx"][k2])
		if v2 > 0.0:
			parts.append("+%d %s" % [int(round(v2 * factor * eff * boost)), str(NAMES[k2]).split(" ")[0].to_lower()])
	_fx("press", " ".join(parts), Color(0.55, 0.95, 0.7))
	_refresh()
	_start_task(float(a["mins"]), TASK_SPEED, "press")


func _advance_time(mins: int, asleep: bool = false) -> void:
	var left: int = mins
	while left > 0 and playing:
		var step: int = mini(left, 10)
		left -= step
		var before: int = clock
		clock += step
		if clock >= 1440:
			clock -= 1440
		_tick(step, asleep)
		_progress_build(step)
		if _check_loss():
			return
		if outside and not asleep and _suit_drain(step):
			left += 120
		if not asleep:
			awake_min += step
			if awake_min >= 960 and not fatigue_warned:
				fatigue_warned = true
				_log(Lang.t("[color=orange]Llevas 16 horas despierto: el cansancio hará que tus acciones rindan menos. Conviene dormir.[/color]"))
			if before < 1170 and clock >= 1170 and clock < 1440 and not night_warned:
				night_warned = true
				_log(Lang.t("[color=orange]Se acerca la noche: desde las 20:00, si sigues despierto bajan la energía y la moral.[/color]"))
			if before < NIGHT_START and clock >= NIGHT_START and clock < 1440:
				_log(Lang.t("[color=orange]Son las 20:00. Comienza la noche: considera dormir.[/color]"))
			if _is_night_clock():
				night_acc += step
				if night_acc >= 60:
					night_acc -= 60
					_uncomfortable()
		if before < DAY_START and clock >= DAY_START:
			if _new_day():
				return
	_refresh()


func _tick(step: int, asleep: bool) -> void:
	var f: float = float(step) / 1440.0 * _drain_k()
	for k in BASE_DRAIN:
		var mult: float = 1.0
		if asleep:
			mult = float(SLEEP_MULT[k])
		mult *= 1.0 - STATION_DRAIN_CUT * float(st_lvl.get(RES_STATION[k], 0))
		_add(k, -float(BASE_DRAIN[k]) * f * mult)
	if _is_night():
		_add("energy", -LUNAR_NIGHT_EXTRA * f)
	if res["shield"] < 30.0:
		_add("morale", -SHIELD_LOW_MORALE * f)
	if breach:
		_add("oxygen", -BREACH_OXY * f)
		_add("morale", -BREACH_MORALE * f)
	if ill_days > 0:
		_add("morale", -ILL_MORALE * f)
	var hrs: float = float(step) / 60.0
	if asleep:
		_add("morale", SLEEP_MORALE_PER_H * hrs)
	elif _is_night_clock():
		var dm: float = _drain_k()
		_add("energy", -NIGHT_ENERGY_PER_H * hrs * dm)
		_add("morale", -NIGHT_MORALE_PER_H * hrs * dm)


func _check_loss() -> bool:
	for k in NAMES:
		if res[k] <= 0.0:
			_finish(false, "fail_" + k)
			return true
	return false


func _uncomfortable() -> void:
	var chance: float = 0.18 * float(_diff()["nightmare"]) / 0.35
	if rng.randf() >= chance:
		return
	var pen: float = 3.0 * float(_diff()["sev"])
	_add("morale", -pen)
	_log(Lang.t("[color=violet]%s (-%d moral).[/color]") % [UNCOMFORTABLE[rng.randi_range(0, UNCOMFORTABLE.size() - 1)], int(pen)])


func _roll_nightmare() -> Dictionary:
	var chance: float = float(_diff()["nightmare"])
	if res["morale"] < 40.0:
		chance *= 1.5
	if talked_today.has("l"):
		chance *= 0.6
	chance = clampf(chance, 0.05, 0.9)
	if rng.randf() >= chance:
		return {}
	return NIGHTMARES[rng.randi_range(0, NIGHTMARES.size() - 1)]


func _sleep() -> void:
	var mins: int = posmod(DAY_START - clock, 1440)
	if mins <= 0:
		mins = 1440
	slept_tonight = true
	awake_min = 0
	fatigue_warned = false
	pending_nightmare = _roll_nightmare()
	if not pending_nightmare.is_empty():
		stats["nightmares"] += 1
	_sfx("sleep")
	_log(Lang.t("Te acuestas a las %s. Dormirás hasta las 06:00.") % _clock_text())
	_advance_time(mins, true)


func _new_day() -> bool:
	if day >= MAX_DAYS:
		var eid: String = _pick_ending()
		_start_dialog(_ending_lines(eid), _finish.bind(true, eid))
		return true
	day += 1
	talked_today.clear()
	night_acc = 0
	night_warned = false
	if storm_left > 0:
		storm_left -= 1
	var lines: Array = []
	_log(Lang.t("[b]— Amanece el día %d (06:00) —[/b]") % day)
	if not pending_nightmare.is_empty():
		var n: Dictionary = pending_nightmare
		var pen: float = float(n["morale"]) * float(_diff()["sev"])
		_add("morale", -pen)
		lines.append(_l("Narración", n["title"]))
		for ln in n["lines"]:
			lines.append(_l(ln[0], ln[1]))
		lines.append(_l("Narración", Lang.t("Dormiste mal: -%d moral.") % int(pen)))
		_log(Lang.t("[color=violet]%s (-%d moral).[/color]") % [n["title"], int(pen)])
	elif not slept_tonight:
		_add("morale", -10)
		_add("energy", -5)
		stats["collapses"] += 1
		awake_min = 600
		fatigue_warned = false
		lines.append(_l("Narración", Lang.t("Llevas toda la noche sin dormir. Te desplomas de cansancio y despiertas con el cuerpo molido.")))
		lines.append(_l("Wilson", Lang.t("Nota mental: dormir no es opcional.")))
		_log(Lang.t("[color=red]Agotamiento: pasaste la noche en vela (-10 moral, -5 energía).[/color]"))
	else:
		_log(Lang.t("[color=lime]Dormiste bien.[/color]"))
	pending_nightmare = {}
	slept_tonight = false
	if ill_days > 0:
		ill_days -= 1
		if ill_days <= 0:
			_log(Lang.t("[color=lime]La enfermedad cede por sí sola.[/color]"))
	history.append({"day": day, "res": res.duplicate()})
	if history.size() > 40:
		history.remove_at(0)
	_random_event()
	# mas eventos cuanto mas avanza la mision
	var p2: float = _prog()
	if p2 > 0.34 and rng.randf() < (p2 - 0.34) * float(_diff()["g_ev"]) * 0.8:
		_random_event()
	if day == 8 or day == 15 or day == 22:
		lines.append(_l("Control", Lang.t("Perseo, la situación empeora: se esperan más fallas y tormentas, el material de la superficie rinde menos y la base gasta más recursos. Mejoren sus estaciones y su traje.")))
		_sfx("alarm", -12.0)
	if _check_loss():
		return true
	_refresh()
	_save_game()
	story_seen[day] = true
	lines.append_array(_story_lines(day))
	if not lines.is_empty():
		_start_dialog(lines)
	return false


func _weighted(w: Array) -> int:
	var total: float = 0.0
	for x in w:
		total += x
	var r: float = rng.randf() * total
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return 0


func _dust_storm() -> void:
	var dmg: float = 15.0
	storm_left = 2
	if tools["filter"] > 0:
		tools["filter"] -= 1
		dmg = 5.0
		storm_left = 1
		_log(Lang.t("[color=yellow]Usas el filtro de polvo: el daño de la tormenta se reduce.[/color]"))
	_add("energy", -dmg)
	_sfx("bad")
	_log(Lang.t("[color=orange]Tormenta de polvo: bloquea la luz y cubre los paneles (-%d energía, solar reducido).[/color]") % int(dmg))


func _electric_hit(dmg: float, nm: String) -> void:
	var d: float = dmg
	if tools["repair"] > 0:
		tools["repair"] -= 1
		d = dmg * 0.3
		_log(Lang.t("[color=yellow]%s: usas el reparador de circuitos y limitas el daño.[/color]") % nm)
	_add("energy", -d)
	_sfx("bad")
	stats["bad_events"] += 1
	_log(Lang.t("[color=orange]%s: se pierde energía (-%d).[/color]") % [nm, int(d)])


func _random_event() -> void:
	if location == "Marte" and rng.randf() < 0.25:
		_dust_storm()
		return
	if rng.randf() > _events_p():
		return
	var w: Array = [
		2.0, 2.0, 2.0, 2.0, 1.0,
		1.5 if day >= 3 else 0.0,
		0.8 if (day >= 6 and not breach) else 0.0,
		1.0 if day >= 4 else 0.0,
		1.0 if day >= 4 else 0.0,
		1.0 if day >= 5 else 0.0,
		1.0
	]
	match _weighted(w):
		0:
			_add("shield", -15)
			_sfx("bad")
			_log(Lang.t("[color=red]Llamarada solar: aumenta la radiación (-15 escudo).[/color]"))
		1:
			_add("oxygen", -12)
			_sfx("bad")
			_log(Lang.t("[color=red]Micrometeorito: pequeña fuga de aire (-12 oxígeno).[/color]"))
		2:
			_electric_hit(10.0, Lang.t("Falla de equipo"))
		3:
			_add("food", 12)
			_sfx("good")
			_log(Lang.t("[color=green]Cosecha excelente en el invernadero (+12 comida).[/color]"))
		4:
			_add("morale", 10)
			_sfx("good")
			_log(Lang.t("[color=green]Mensaje de la Tierra: sube la moral (+10 moral).[/color]"))
		5:
			_add("morale", -25)
			ill_days = 3
			flash_t = 0.6
			_sfx("bad")
			stats["bad_events"] += 1
			_log(Lang.t("[color=red]Brote de enfermedad: parte de la tripulación cae enferma (-25 moral y -4 más por día). Un botiquín ayuda: habla con PAM.[/color]"))
		6:
			_add("shield", -40)
			breach = true
			flash_t = 1.0
			shake_t = 1.0
			alarm_t = 0.0
			_sfx("bad")
			_sfx("alarm", -8.0)
			stats["bad_events"] += 1
			_log(Lang.t("[color=red][b]METEORO DIRECTO:[/b] daño crítico al escudo (-40) y brecha en el casco. ¡ALERTA ROJA! Pierdes oxígeno cada día hasta sellarla con un kit de parche.[/color]"))
		7:
			_electric_hit(25.0, Lang.t("Cortocircuito"))
		8:
			_add("water", -20)
			_sfx("bad")
			stats["bad_events"] += 1
			_log(Lang.t("[color=red]Fuga en el sistema de agua (-20 agua).[/color]"))
		9:
			_add("food", -25)
			_sfx("bad")
			stats["bad_events"] += 1
			_log(Lang.t("[color=red]Plaga en los cultivos (-25 comida).[/color]"))
		10:
			inv["scrap"] += 2
			_sfx("good")
			_log(Lang.t("[color=green]Un compañero rescata piezas útiles de los desechos (+2 chatarra).[/color]"))


func _finish(won: bool, eid: String) -> void:
	playing = false
	task_left = 0.0
	mode = 0
	dlg_queue.clear()
	dlg_after = Callable()
	choice_active = false
	dlg.visible = false
	_sfx("win" if won else "lose", -2.0)
	if not endings_seen.has(eid):
		endings_seen.append(eid)
		_save_settings()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_clear()
	ending_active = true
	music.stop()
	current_music = ""
	var music_name: String = "music_outro_win" if won else "music_outro_lose"
	get_tree().create_timer(2.2).timeout.connect(_start_outro_music.bind(music_name))
	_build_ending_screen(won, eid)


func _start_outro_music(nm: String) -> void:
	if ending_active:
		_play_music(nm)


func _build_ending_screen(won: bool, eid: String) -> void:
	var e: Dictionary = ENDINGS[eid]
	ending_art = (load("res://ending_art.gd") as GDScript).new() as Control
	add_child(ending_art)
	move_child(ending_art, 1)
	ending_art.call("setup", eid, location)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(spacer)
	var cc := CenterContainer.new()
	root_box.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(860, 0)
	var st: StyleBoxFlat = _panel_style()
	st.bg_color = Color(0.05, 0.06, 0.12, 0.9)
	pc.add_theme_stylebox_override("panel", st)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	# --- página 1: historia ---
	var p1 := VBoxContainer.new()
	p1.add_theme_constant_override("separation", 8)
	v.add_child(p1)
	var tl: Label = _label(Lang.t("¡MISIÓN CUMPLIDA!") if won else Lang.t("MISIÓN FALLIDA"), 30)
	tl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7) if won else Color(1.0, 0.5, 0.45))
	p1.add_child(tl)
	p1.add_child(_label(Lang.t("Final: %s") % e["title"], 22))
	p1.add_child(_label(e["desc"], 16))
	var epi: Label = _label(ENDING_EPILOGUE[eid], 15)
	epi.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	p1.add_child(epi)
	if ENDING_TIP.has(eid):
		var tip: Label = _label(ENDING_TIP[eid], 14)
		tip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		p1.add_child(tip)
	p1.add_child(_label(Lang.t("Finales descubiertos: %d / %d") % [endings_seen.size(), ENDINGS.size()], 14))
	# --- página 2: estadísticas ---
	var p2 := VBoxContainer.new()
	p2.add_theme_constant_override("separation", 6)
	p2.visible = false
	v.add_child(p2)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	p2.add_child(hb)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.custom_minimum_size = Vector2(380, 250)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.text = ui.stats_bbcode()
	hb.add_child(rt)
	var rv := VBoxContainer.new()
	rv.custom_minimum_size = Vector2(380, 0)
	hb.add_child(rv)
	rv.add_child(_label(Lang.t("Recursos por día"), 15))
	rv.add_child(ui.make_chart(230.0))
	v.add_child(HSeparator.new())
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	v.add_child(br)
	var bt: Button = _button(Lang.t("Ver estadísticas"), Callable())
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.pressed.connect(_toggle_ending_page.bind(p1, p2, bt))
	br.add_child(bt)
	var b1: Button = _button(Lang.t("Volver al menú"), _show_menu)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(b1)
	var b2: Button = _button(Lang.t("Jugar de nuevo"), _new_game.bind(location))
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(b2)


func _toggle_ending_page(p1: Control, p2: Control, bt: Button) -> void:
	p2.visible = not p2.visible
	p1.visible = not p2.visible
	bt.text = Lang.t("Ver historia") if p2.visible else Lang.t("Ver estadísticas")
