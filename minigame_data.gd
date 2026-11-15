extends RefCounted
# Datos de los minijuegos del banco de trabajo (generado por gen_mg.py; textos en español con traducción en lang_en.gd).
# Los casos clinicos son situaciones de juego basadas en problemas de salud reales en misiones espaciales; no son consejo medico.

static func cases() -> Array:
	return [
		{
			"title": Lang.t("Mareo de adaptación"),
			"sym": Lang.t("ENOC lleva dos días con náuseas, vómitos, dolor de cabeza y siente que todo da vueltas cuando mueve rápido la cabeza. Hace poco cambió de gravedad. No tiene fiebre."),
			"q1": Lang.t("¿Qué le pasa?"),
			"h1": Lang.t("Pista: lo marea sobre todo mover la cabeza. ¿Qué órgano ayuda a mantener el equilibrio?"),
			"w1": Lang.t("El oído interno nos dice hacia dónde está «abajo». Al cambiar de gravedad se confunde. Es común en los primeros días del espacio y suele mejorar en pocos días."),
			"q2": Lang.t("¿Qué debe llevar el botiquín para ayudarlo?"),
			"h2": Lang.t("Pista: hay que calmar el estómago y no agitar el oído interno."),
			"w2": Lang.t("Calmar las náuseas, hidratarse y moverse despacio es lo más útil mientras el cuerpo se adapta."),
			"o1": [Lang.t("Mareo de adaptación: el oído interno se confunde con la nueva gravedad"), Lang.t("Intoxicación por polvo de la superficie"), Lang.t("Deshidratación por trabajar con el traje"), Lang.t("Falta de oxígeno en el módulo")],
			"o2": [Lang.t("Medicina contra las náuseas, agua y reposo con movimientos lentos de cabeza"), Lang.t("Una venda elástica"), Lang.t("Una manta térmica"), Lang.t("Gotas para los ojos")],
		},
		{
			"title": Lang.t("Deshidratación"),
			"sym": Lang.t("La Dra. YARISBEL trabajó seis horas con el traje. Tiene mucha sed, la boca seca, la orina muy oscura, dolor de cabeza y cansancio. No tiene fiebre ni heridas."),
			"q1": Lang.t("¿Qué le pasa?"),
			"h1": Lang.t("Pista: sed + orina oscura son señales de que al cuerpo le falta algo muy simple."),
			"w1": Lang.t("La orina oscura y la sed intensa indican que el cuerpo necesita agua. En el espacio el agua es tan valiosa que se recicla."),
			"q2": Lang.t("¿Qué lleva el botiquín?"),
			"h2": Lang.t("Pista: hay que reponer lo que se perdió: agua y sales."),
			"w2": Lang.t("Beber despacio agua con sales repone lo perdido. El café no repone el agua."),
			"o1": [Lang.t("Deshidratación: perdió más agua de la que bebió"), Lang.t("Una infección en la piel"), Lang.t("Hipotermia"), Lang.t("Mareo de adaptación")],
			"o2": [Lang.t("Agua con sales (electrolitos) para beber poco a poco, y descanso"), Lang.t("Café bien cargado"), Lang.t("Una gasa estéril"), Lang.t("Una venda de compresión")],
		},
		{
			"title": Lang.t("Irritación por polvo"),
			"sym": Lang.t("PAM estornuda, tiene los ojos rojos y llorosos y la garganta irritada. Acaba de entrar de la superficie sin limpiar bien su traje. No tiene fiebre."),
			"q1": Lang.t("¿Qué le pasa?"),
			"h1": Lang.t("Pista: ojos, nariz y garganta son por donde entra el polvo."),
			"w1": Lang.t("El polvo es muy fino y se pega al traje. Algunos astronautas de las misiones Apolo tuvieron estornudos y ojos irritados por el polvo lunar."),
			"q2": Lang.t("¿Qué lleva el botiquín?"),
			"h2": Lang.t("Pista: hay que sacar el polvo de los ojos y evitar traerlo al aire de la base."),
			"w2": Lang.t("Lavar los ojos, filtrar el aire y limpiar los trajes evita que el polvo siga irritando."),
			"o1": [Lang.t("Irritación por el polvo de la superficie, parecida a una alergia"), Lang.t("Una quemadura"), Lang.t("Una torcedura"), Lang.t("Mareo de adaptación")],
			"o2": [Lang.t("Suero para lavar los ojos y un filtro de aire; limpiar el traje antes de entrar"), Lang.t("Hielo directo sobre la cara"), Lang.t("Una venda elástica"), Lang.t("Una manta térmica")],
		},
		{
			"title": Lang.t("Exceso de dióxido de carbono"),
			"sym": Lang.t("En el módulo de dormir, ENOC y PAM tienen dolor de cabeza, mucho sueño y respiran más rápido. El filtro de CO2 lleva semanas sin cambiarse."),
			"q1": Lang.t("¿Qué les pasa?"),
			"h1": Lang.t("Pista: los dos sienten lo mismo en el mismo lugar. Mira qué dice el último dato."),
			"w1": Lang.t("Al respirar sacamos CO2. Si el filtro falla, se acumula y da dolor de cabeza y sueño. En la Estación Espacial se vigila mucho el CO2."),
			"q2": Lang.t("¿Qué debe hacer el equipo?"),
			"h2": Lang.t("Pista: la pastilla no quita la causa. ¿Qué hay que arreglar?"),
			"w2": Lang.t("Hay que quitar la causa: aire limpio y filtro nuevo. Sin eso el dolor de cabeza vuelve."),
			"o1": [Lang.t("Exceso de dióxido de carbono en el aire"), Lang.t("Falta de comida"), Lang.t("Una infección de herida"), Lang.t("Quemaduras de sol")],
			"o2": [Lang.t("Salir a aire fresco, ventilar y cambiar el filtro de CO2"), Lang.t("Tomar una pastilla y seguir durmiendo"), Lang.t("Beber más agua y nada más"), Lang.t("Poner una manta térmica")],
		},
		{
			"title": Lang.t("Herida infectada"),
			"sym": Lang.t("La Dra. YARISBEL se cortó la mano con una chapa hace tres días. Hoy la herida está roja, caliente, hinchada y con pus, y tiene un poco de fiebre."),
			"q1": Lang.t("¿Qué le pasa?"),
			"h1": Lang.t("Pista: pus, calor y fiebre después de un corte."),
			"w1": Lang.t("Enrojecimiento, calor, hinchazón, pus y fiebre son señales de infección."),
			"q2": Lang.t("¿Qué lleva el botiquín?"),
			"h2": Lang.t("Pista: primero hay que limpiar y proteger."),
			"w2": Lang.t("Limpiar, cubrir con material estéril y tratar según indique la doctora evita que la infección empeore. En una base lejos de la Tierra no hay hospital cerca."),
			"o1": [Lang.t("La herida se infectó con bacterias"), Lang.t("Es una quemadura"), Lang.t("Es una congelación"), Lang.t("Es mareo de adaptación")],
			"o2": [Lang.t("Antiséptico, gasa estéril y el tratamiento que indique la doctora"), Lang.t("Taparla sin limpiarla"), Lang.t("Frío intenso sobre la herida"), Lang.t("Frotarla con polvo de la superficie")],
		},
		{
			"title": Lang.t("Quemadura"),
			"sym": Lang.t("ENOC tocó sin querer un radiador muy caliente. Tiene la piel roja y dolorida con una ampolla pequeña en la palma de la mano."),
			"q1": Lang.t("¿Qué le pasa?"),
			"h1": Lang.t("Pista: piel roja, ampolla y un objeto muy caliente."),
			"w1": Lang.t("Una ampolla pequeña con piel roja es una quemadura leve."),
			"q2": Lang.t("¿Qué lleva el botiquín?"),
			"h2": Lang.t("Pista: el hielo muy frío también daña la piel."),
			"w2": Lang.t("El agua fresca baja el calor sin dañar más. La ampolla protege la piel de abajo: no se revienta."),
			"o1": [Lang.t("Una quemadura leve"), Lang.t("Congelación"), Lang.t("Una alergia"), Lang.t("Exceso de CO2")],
			"o2": [Lang.t("Enfriar con agua fresca unos minutos y cubrir con gasa limpia sin reventar la ampolla"), Lang.t("Hielo directo sobre la piel"), Lang.t("Reventar la ampolla"), Lang.t("Dejarlo al aire sin tocarlo")],
		},
		{
			"title": Lang.t("Hipotermia"),
			"sym": Lang.t("Después de una noche fuera con el traje averiado, PAM tiembla sin parar, tiene manos y pies helados y habla lento y confundida."),
			"q1": Lang.t("¿Qué le pasa?"),
			"h1": Lang.t("Pista: tiembla, está helada y confundida."),
			"w1": Lang.t("Cuando el cuerpo pierde calor más rápido de lo que lo produce, tiembla y puede confundirse. La noche en la Luna y en Marte es muy fría."),
			"q2": Lang.t("¿Qué lleva el botiquín?"),
			"h2": Lang.t("Pista: primero hay que dejar de perder calor."),
			"w2": Lang.t("Hay que abrigarla y calentarla despacio, en un lugar protegido. Frotar fuerte o salir de nuevo empeora las cosas."),
			"o1": [Lang.t("Hipotermia: su cuerpo perdió demasiado calor"), Lang.t("Insolación"), Lang.t("Deshidratación"), Lang.t("Una torcedura")],
			"o2": [Lang.t("Entrarla al refugio, mantas térmicas y una bebida tibia"), Lang.t("Frotarle las manos con mucha fuerza"), Lang.t("Dejarla caminar fuera para entrar en calor"), Lang.t("Una gasa estéril")],
		},
		{
			"title": Lang.t("Esguince de tobillo"),
			"sym": Lang.t("Al caer en un hueco, ENOC se torció el tobillo: está hinchado y duele al apoyar el pie, pero el pie conserva su forma normal."),
			"q1": Lang.t("¿Qué le pasa?"),
			"h1": Lang.t("Pista: golpe en el tobillo, hinchazón y dolor al apoyar."),
			"w1": Lang.t("Torcerse el tobillo estira los ligamentos y los inflama."),
			"q2": Lang.t("¿Qué lleva el botiquín?"),
			"h2": Lang.t("Pista: hay que proteger el tobillo mientras se recupera."),
			"w2": Lang.t("Reposo, compresión, elevar y frío ayudan a bajar la hinchazón. Un golpe fuerte o una forma rara del pie requeriría revisar si hay fractura."),
			"o1": [Lang.t("Un esguince: se estiraron los ligamentos del tobillo"), Lang.t("Una infección"), Lang.t("Mareo de adaptación"), Lang.t("Hipotermia")],
			"o2": [Lang.t("Reposo, vendaje de compresión, pie elevado y frío envuelto en tela"), Lang.t("Seguir caminando como si nada"), Lang.t("Un masaje muy fuerte"), Lang.t("Quitar el vendaje y correr")],
		},
		{
			"title": Lang.t("Problemas de sueño"),
			"sym": Lang.t("Desde que llegó a la base, la Dra. YARISBEL duerme mal, se despierta a mitad de la noche y está irritable y distraída. El día y la noche de aquí no se parecen a los de la Tierra."),
			"q1": Lang.t("¿Qué le pasa?"),
			"h1": Lang.t("Pista: el problema es cuándo duerme, no una herida."),
			"w1": Lang.t("El cuerpo se guía por la luz para saber cuándo dormir. En Marte, un día (sol) dura unos 24 h 39 min, y en la Luna el día y la noche duran unas dos semanas cada uno. Por eso los equipos usan horarios fijos."),
			"q2": Lang.t("¿Qué lleva el botiquín?"),
			"h2": Lang.t("Pista: el cuerpo se ajusta con la luz y con los horarios."),
			"w2": Lang.t("Un horario regular y luz a la hora correcta ayudan a reajustar el reloj interno."),
			"o1": [Lang.t("Su reloj interno está desajustado: le cuesta dormir a su hora"), Lang.t("Tiene una infección"), Lang.t("Tiene una quemadura"), Lang.t("Se torció un tobillo")],
			"o2": [Lang.t("Horario fijo, luz brillante de día y oscuridad total para dormir"), Lang.t("Más café por la noche"), Lang.t("Dormir con todas las luces encendidas"), Lang.t("Quitar el reloj de la base")],
		},
	]

static func tool_info(id: String) -> Dictionary:
	match id:
		"patch":
			return {"title": Lang.t("Kit de parche"), "pages": [Lang.t("Para qué sirve: sella las brechas que abren los meteoritos en el casco. Si hay ALERTA ROJA, sin parche pierdes oxígeno cada día. Cómo se usa: ve al generador de escudo y pulsa [E] para sellar la brecha."), Lang.t("En la realidad: los módulos de la Estación Espacial Internacional tienen capas protectoras contra micrometeoritos y la tripulación tiene procedimientos para reparar fugas.")]}
		"medkit":
			return {"title": Lang.t("Botiquín"), "pages": [Lang.t("Para qué sirve: cura una enfermedad de la tripulación. Cómo se usa: si hay enfermos, habla con PAM y ella lo usa. Cada botiquín cura una vez."), Lang.t("En la realidad: la tripulación entrena primeros auxilios, y en Marte la señal tarda varios minutos en llegar a la Tierra: no se puede esperar a que un médico responda.")]}
		"repair":
			return {"title": Lang.t("Reparador de circuitos"), "pages": [Lang.t("Para qué sirve: reduce el daño cuando una falla eléctrica o un cortocircuito golpea la base. Cómo se usa: se gasta solo cuando ocurre la falla; basta con tenerlo en el inventario."), Lang.t("En la realidad: el polvo se pega a los equipos y puede dañar conexiones, por eso las misiones llevan repuestos y herramientas para reparar electrónica.")]}
		"filter":
			return {"title": Lang.t("Filtro de polvo"), "pages": [Lang.t("Para qué sirve: reduce el daño de las tormentas de polvo. Cómo se usa: se gasta solo cuando llega una tormenta; basta con tenerlo en el inventario."), Lang.t("En la realidad: en Marte las tormentas de polvo pueden cubrir todo el planeta. En 2018 una tormenta dejó sin luz solar al rover Opportunity y se perdió el contacto con él.")]}
		"map":
			return {"title": Lang.t("Mapa de navegación"), "pages": [Lang.t("Para qué sirve: te muestra el mundo (tecla [Tab]) y activa el minimapa. Cómo se usa: ábrelo con [Tab] para ver las zonas y los lugares explorados. Solo se fabrica una vez."), Lang.t("En la realidad: no hay GPS en la Luna ni en Marte. Los mapas se hacen con fotos de satélites que orbitan, como el Lunar Reconnaissance Orbiter (Luna) y el Mars Reconnaissance Orbiter (Marte).")]}
	return {}
