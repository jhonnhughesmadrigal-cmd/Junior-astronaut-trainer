extends RefCounted
# v29 — Catalogo de "Misiones de clase": lecciones cortas (3-5 min) que el docente elige por tema.
# Todo el texto esta en espanol y se traduce con Lang.t() (ingles en lang_en.gd).
# DATOS: solo cifras verificadas en la fuente citada durante la sesion de v29 (ver DATOS.md, seccion v29).
# Los valores marcados como "de juego" (velocidad del salto, posiciones en el mapa) NO son datos reales.
#
# Campos de cada mision:
#  id, loc ("Luna"/"Marte"), topic (clave de TOPICS), title, card (resumen de la tarjeta), mins (duracion aprox.)
#  start: "outside" (fuera, junto a la esclusa) o "inside" (dentro de la base)
#  steps: lista de pasos. kind: "goto" (ir a un lugar), "observe" (quedarse cerca unos segundos),
#         "jump" (saltar n veces y medir el tiempo en el aire), "ice" (recoger hielo), "exit" (salir por la esclusa)
#         zone: nombre en espanol de la zona del mapa (su placa), o "panels" (paneles solares de la base)
#  storm: true -> se ve una tormenta de polvo (solo visual en la mision)
#  quiz: [{q, a: [3 opciones], ok: indice correcto, why: explicacion}]
#  learned: lo que aprendiste (3 frases); sources: [[texto, url]]

const TOPICS: Array = ["Gravedad", "Agua", "Historia espacial", "Energía", "Geología", "Atmósfera"]
const TOPIC_ICON: Dictionary = {"Gravedad": "planet", "Agua": "water", "Historia espacial": "book", "Energía": "energy", "Geología": "map", "Atmósfera": "oxygen"}

const SRC_MOON: Array = ["Ficha de la Luna (NASA NSSDC)", "https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html"]
const SRC_MARS: Array = ["Ficha de Marte (NASA NSSDC)", "https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html"]

const MISSIONS: Array = [
	{
		"id": "moon_jump", "loc": "Luna", "topic": "Gravedad", "mins": 3,
		"title": "Saltar en la Luna",
		"card": "Salta y mide cuánto tiempo pasas en el aire con la gravedad lunar.",
		"start": "outside",
		"steps": [
			{"kind": "jump", "n": 3, "text": "Pulsa [Espacio] para saltar 3 veces. Mira cuánto tiempo estás en el aire."},
		],
		"quiz": [
			{"q": "¿Por qué en la Luna pasas más tiempo en el aire que en la Tierra?", "a": ["Porque la gravedad de la Luna es más débil", "Porque en la Luna hace más frío", "Porque el traje espacial flota"], "ok": 0,
				"why": "La gravedad en la superficie de la Luna es de ≈ 1,62 m/s², unas 6 veces menor que la de la Tierra (≈ 9,80 m/s²). Te atrae con menos fuerza, así que tardas más en volver al suelo."},
			{"q": "Si en la Tierra pesas 30 kg, ¿cuánto marcaría la misma báscula en la Luna (más o menos)?", "a": ["Unos 5 kg", "Unos 30 kg", "Unos 180 kg"], "ok": 0,
				"why": "Tu masa no cambia, pero la Luna te atrae unas 6 veces menos (≈ 0,165 veces la gravedad de la Tierra): 30 × 0,165 ≈ 5."},
		],
		"learned": ["La gravedad de la Luna es ≈ 1,62 m/s², unas 6 veces menor que la de la Tierra.", "Con el mismo impulso, en la Luna subes más alto y tardas más en caer.", "Tu masa es la misma en todas partes; lo que cambia es tu peso."],
		"sources": [SRC_MOON],
	},
	{
		"id": "moon_apollo", "loc": "Luna", "topic": "Historia espacial", "mins": 4,
		"title": "Las huellas del Apolo 11",
		"card": "Viaja al Mar de la Tranquilidad, donde alunizaron las primeras personas.",
		"start": "outside",
		"steps": [
			{"kind": "goto", "zone": "Mar de la Tranquilidad", "text": "Camina hasta la placa del Mar de la Tranquilidad. Sigue la columna de luz."},
			{"kind": "observe", "zone": "Mar de la Tranquilidad", "secs": 3.0, "text": "Quédate junto a la placa y observa el lugar."},
		],
		"quiz": [
			{"q": "¿En qué fecha alunizó el Apolo 11?", "a": ["20 de julio de 1969", "12 de abril de 1961", "18 de febrero de 2021"], "ok": 0,
				"why": "El módulo lunar Eagle del Apolo 11 alunizó el 20 de julio de 1969 en el Mar de la Tranquilidad."},
			{"q": "¿Qué fue especial de esa misión?", "a": ["Fueron las primeras personas en caminar sobre la Luna", "Fue el primer robot en Marte", "Fue la primera estación espacial"], "ok": 0,
				"why": "Neil Armstrong y Buzz Aldrin fueron las primeras personas en caminar sobre la Luna."},
		],
		"learned": ["El Apolo 11 alunizó el 20 de julio de 1969.", "Lo hizo en el Mar de la Tranquilidad, una gran llanura oscura.", "Armstrong y Aldrin fueron las primeras personas en caminar sobre la Luna."],
		"sources": [["Apollo 11 Mission Overview (NASA)", "https://www.nasa.gov/missions/apollo/apollo-11/apollo-11-mission-overview/"]],
	},
	{
		"id": "moon_ice", "loc": "Luna", "topic": "Agua", "mins": 5,
		"title": "Hielo en la sombra",
		"card": "Busca hielo en un cráter del polo sur donde el Sol casi nunca llega.",
		"start": "outside",
		"steps": [
			{"kind": "goto", "zone": "Cráter Shackleton", "text": "Ve al cráter Shackleton, cerca del polo sur. Sigue la columna de luz."},
			{"kind": "ice", "text": "Busca cristales de hielo cerca del cráter y recoge uno con [E]."},
		],
		"quiz": [
			{"q": "¿Por qué puede haber hielo en algunos cráteres del polo sur de la Luna?", "a": ["Porque su fondo está siempre a la sombra y muy frío", "Porque llueve en la Luna", "Porque allí hay mares de agua líquida"], "ok": 0,
				"why": "Algunos cráteres cerca de los polos tienen zonas en sombra permanente: el Sol nunca las ilumina y están tan frías que el hielo de agua puede durar mucho tiempo."},
			{"q": "En 2009, la misión LCROSS de la NASA chocó a propósito contra un cráter en sombra. ¿Qué encontró?", "a": ["Agua", "Oro", "Lava"], "ok": 0,
				"why": "LCROSS impactó en el cráter Cabeus (polo sur) el 9 de octubre de 2009 y detectó agua en un cráter en sombra permanente."},
		],
		"learned": ["Hay cráteres de los polos lunares cuyo fondo nunca recibe luz del Sol.", "La misión LCROSS (2009) detectó agua en uno de ellos: el cráter Cabeus.", "Encontrar agua en la Luna es importante para futuras bases."],
		"sources": [["LCROSS (NASA Science)", "https://science.nasa.gov/mission/lcross/"], ["Lunar impact (NASA JPL)", "https://www.jpl.nasa.gov/news/lunar-impact-may-impact-lunar-science-for-years-to-come/"]],
	},
	{
		"id": "moon_night", "loc": "Luna", "topic": "Energía", "mins": 4,
		"title": "El día y la noche lunar",
		"card": "Revisa los paneles solares y descubre cuánto dura una noche en la Luna.",
		"start": "outside",
		"steps": [
			{"kind": "goto", "zone": "panels", "text": "Rodea la base y ve a los paneles solares (lado norte)."},
			{"kind": "observe", "zone": "panels", "secs": 3.0, "text": "Observa los paneles: dan energía solo cuando les llega la luz del Sol."},
		],
		"quiz": [
			{"q": "Desde un lugar de la Luna, ¿cuánto tarda el Sol en volver a la misma posición en el cielo?", "a": ["Unos 29,5 días terrestres", "24 horas", "Un año"], "ok": 0,
				"why": "El periodo sinódico de la Luna es de ≈ 29,53 días: por eso, en muchos lugares hay unas dos semanas de luz y unas dos semanas de oscuridad."},
			{"q": "¿Qué problema tiene una base con paneles solares durante la noche lunar?", "a": ["No recibe luz y debe guardar energía en baterías", "Los paneles se derriten", "No hay ningún problema"], "ok": 0,
				"why": "Sin luz, los paneles no producen electricidad. La base necesita baterías u otra fuente de energía para aguantar unas dos semanas."},
		],
		"learned": ["Un ciclo de día y noche en la Luna dura ≈ 29,5 días terrestres.", "La noche lunar dura unas dos semanas en muchos lugares.", "En el ecuador lunar la temperatura va de ≈ −178 °C a ≈ +117 °C (95 K a 390 K)."],
		"sources": [SRC_MOON],
	},
	{
		"id": "mars_jump", "loc": "Marte", "topic": "Gravedad", "mins": 3,
		"title": "Saltar en Marte",
		"card": "Compara tus saltos en Marte con los de la Luna y la Tierra.",
		"start": "outside",
		"steps": [
			{"kind": "jump", "n": 3, "text": "Pulsa [Espacio] para saltar 3 veces. ¿Pasas más o menos tiempo en el aire que en la Luna?"},
		],
		"quiz": [
			{"q": "¿Dónde es más fuerte la gravedad?", "a": ["En la Tierra", "En Marte", "En la Luna"], "ok": 0,
				"why": "Gravedad en la superficie: Tierra ≈ 9,8 m/s², Marte ≈ 3,73 m/s², Luna ≈ 1,62 m/s²."},
			{"q": "La gravedad de Marte es aproximadamente…", "a": ["El 38 % de la de la Tierra", "El doble que la de la Tierra", "Igual que la de la Luna"], "ok": 0,
				"why": "La gravedad media en la superficie de Marte es ≈ 3,73 m/s², unas 0,38 veces la de la Tierra."},
		],
		"learned": ["La gravedad de Marte es ≈ 3,73 m/s² (≈ 38 % de la terrestre).", "Es más del doble que la de la Luna, por eso los saltos son más cortos.", "En el juego, el mismo salto dura ≈ 2,1 s en la Luna, ≈ 0,9 s en Marte y duraría ≈ 0,35 s en la Tierra."],
		"sources": [SRC_MARS, SRC_MOON],
	},
	{
		"id": "mars_jezero", "loc": "Marte", "topic": "Agua", "mins": 4,
		"title": "Un lago antiguo en Jezero",
		"card": "Visita el cráter donde aterrizó Perseverance, que hace mucho tuvo un lago.",
		"start": "outside",
		"steps": [
			{"kind": "goto", "zone": "Cráter Jezero", "text": "Camina hasta el cráter Jezero. Sigue la columna de luz."},
			{"kind": "observe", "zone": "Cráter Jezero", "secs": 3.0, "text": "Observa el lugar: aquí hubo un lago y un río formó un delta."},
		],
		"quiz": [
			{"q": "¿Qué había en el cráter Jezero hace más de 3.500 millones de años?", "a": ["Un lago alimentado por ríos", "Un volcán activo", "Un océano de hielo de CO₂"], "ok": 0,
				"why": "Según la NASA, ríos desbordaron el borde del cráter y formaron un lago; todavía se ven los restos de un delta."},
			{"q": "¿Qué robot de la NASA aterrizó en Jezero el 18 de febrero de 2021?", "a": ["Perseverance", "Opportunity", "Apolo 11"], "ok": 0,
				"why": "El rover Perseverance aterrizó en Jezero el 18 de febrero de 2021 para estudiar el antiguo lago y buscar señales de vida pasada."},
		],
		"learned": ["El cráter Jezero mide ≈ 45 km de ancho.", "Hace más de 3.500 millones de años tuvo un lago con un delta.", "Perseverance aterrizó allí el 18 de febrero de 2021 y busca señales de vida antigua."],
		"sources": [["Mars 2020: Perseverance (NASA Science)", "https://science.nasa.gov/mission/mars-2020-perseverance/"]],
	},
	{
		"id": "mars_olympus", "loc": "Marte", "topic": "Geología", "mins": 5,
		"title": "El volcán gigante",
		"card": "Llega al pie del Olympus Mons, el volcán más grande del Sistema Solar.",
		"start": "outside",
		"steps": [
			{"kind": "goto", "zone": "Olympus Mons", "text": "Viaja hasta la placa del Olympus Mons. Sigue la columna de luz."},
			{"kind": "observe", "zone": "Olympus Mons", "secs": 3.0, "text": "Mira hacia la montaña. En la realidad es tan ancha que no se vería entera desde aquí."},
		],
		"quiz": [
			{"q": "¿Qué es el Olympus Mons?", "a": ["El volcán más grande del Sistema Solar", "Un cráter de impacto", "Una nave espacial"], "ok": 0,
				"why": "La NASA lo describe como el volcán más grande del Sistema Solar."},
			{"q": "Desde su base hasta la cima, el Olympus Mons mide más de…", "a": ["≈ 40 km", "≈ 4 km", "≈ 400 m"], "ok": 0,
				"why": "La NASA indica que mide más de 25 millas (≈ 40 km) de la base a la cima, y su base tiene casi 550 km de ancho."},
		],
		"learned": ["El Olympus Mons es el volcán más grande del Sistema Solar.", "Mide más de ≈ 40 km de la base a la cima (según la NASA).", "Su base tiene casi 550 km de ancho."],
		"sources": [["Mars: Facts (NASA Science)", "https://science.nasa.gov/mars/facts/"], ["A Traverse Across the Summit of Olympus Mons (NASA)", "https://science.nasa.gov/photojournal/a-traverse-across-the-summit-of-olympus-mons/"]],
	},
	{
		"id": "mars_storm", "loc": "Marte", "topic": "Energía", "mins": 4,
		"title": "Tormenta de polvo",
		"card": "Revisa los paneles durante una tormenta y descubre qué le pasó a Opportunity.",
		"start": "outside", "storm": true,
		"steps": [
			{"kind": "goto", "zone": "panels", "text": "Hay una tormenta de polvo. Rodea la base y ve a los paneles solares (lado norte)."},
			{"kind": "observe", "zone": "panels", "secs": 3.0, "text": "Observa: el polvo tapa el Sol y cubre los paneles."},
		],
		"quiz": [
			{"q": "¿Por qué una tormenta de polvo es peligrosa para un robot solar?", "a": ["Porque el polvo tapa la luz del Sol y los paneles producen menos energía", "Porque el polvo es radiactivo", "Porque el viento lo arrastra al espacio"], "ok": 0,
				"why": "El polvo en el aire y sobre los paneles reduce la luz que llega: hay menos energía para cargar las baterías."},
			{"q": "¿Qué le pasó al rover Opportunity en 2018?", "a": ["Una tormenta que cubrió todo Marte lo dejó sin energía y dejó de comunicarse", "Lo recogió una nave y volvió a la Tierra", "Se cayó en el Olympus Mons"], "ok": 0,
				"why": "En 2018, una tormenta de polvo que envolvió todo el planeta bloqueó la luz del Sol durante meses y Opportunity quedó en silencio."},
		],
		"learned": ["En Marte hay tormentas de polvo que pueden cubrir todo el planeta.", "En 2018, una de ellas dejó sin energía al rover Opportunity.", "En tormentas, los landers Viking midieron vientos de ≈ 17–30 m/s."],
		"sources": [["Opportunity (NASA Science)", "https://science.nasa.gov/mission/mer-opportunity/"], ["Mars Rover Mission Comes to an End (NASA JPL Edu)", "https://www.jpl.nasa.gov/edu/resources/teachable-moment/mars-rover-mission-comes-to-an-end-but-science-legacy-live-on/"], SRC_MARS],
	},
	{
		"id": "mars_air", "loc": "Marte", "topic": "Atmósfera", "mins": 3,
		"title": "¿Se puede respirar en Marte?",
		"card": "Sal por la esclusa y descubre por qué el traje es imprescindible.",
		"start": "inside",
		"steps": [
			{"kind": "exit", "text": "Ve a la esclusa (la puerta de la base) y pulsa [E] para salir con el traje."},
		],
		"quiz": [
			{"q": "¿De qué está hecho principalmente el aire de Marte?", "a": ["Dióxido de carbono (CO₂)", "Oxígeno", "Vapor de agua"], "ok": 0,
				"why": "La atmósfera de Marte es ≈ 95 % dióxido de carbono y solo ≈ 0,16 % oxígeno."},
			{"q": "¿Por qué los astronautas necesitan el traje en Marte?", "a": ["Por el aire sin oxígeno respirable, la presión muy baja y el frío", "Solo por el calor", "No lo necesitan"], "ok": 0,
				"why": "La presión en la superficie es de ≈ 6,36 mbar (menos del 1 % de la terrestre), casi no hay oxígeno y la temperatura media es de ≈ −59 °C."},
		],
		"learned": ["El aire de Marte es ≈ 95 % CO₂ y solo ≈ 0,16 % oxígeno.", "La presión es de ≈ 6,36 mbar, menos del 1 % de la de la Tierra.", "La temperatura media es de ≈ −59 °C: hace falta un traje que dé aire, presión y calor."],
		"sources": [SRC_MARS],
	},
]


static func by_id(id: String) -> Dictionary:
	for m in MISSIONS:
		if str(m["id"]) == id:
			return m
	return {}
