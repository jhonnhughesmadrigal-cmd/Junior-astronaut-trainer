extends RefCounted
# Datos de las emergencias (v26). Aqui solo hay DATOS; la logica esta en emergency.gd y la pantalla en diag_ui.gd.
# Todos los textos estan en espanol y se traducen con Lang.t() al mostrarlos (la traduccion esta en lang_en.gd).
# Los numeros de las lecturas son de SIMULACION: se calculan con el estado real del juego, pero no son mediciones reales.

# Sistemas con condicion de mantenimiento (0-100). "crew" no tiene condicion.
const SYS_ORDER: Array = ["life", "power", "water", "filters", "ext"]
const SYS_NAMES: Dictionary = {
	"life": "Soporte vital", "power": "Sistema eléctrico", "water": "Reciclador de agua",
	"filters": "Filtros de aire", "ext": "Equipos exteriores", "crew": "Tripulación"
}
# que accion de estacion (indice en ACTIONS de main.gd) da un poco de mantenimiento a cada sistema
const ACTION_MAINT: Dictionary = {0: "life", 1: "power", 3: "water", 4: "ext"}

# Parametros por dificultad (0 Facil, 1 Normal, 2 Dificil, 3 Extremo)
const CONSULT_MINS: Array = [0, 3, 5, 8]          # tiempo que cuesta consultar un instrumento
const WRONG_DIAG_MINS: Array = [0, 10, 15, 20]    # tiempo perdido por una hipotesis equivocada
const HYP_COUNT: Array = [3, 4, 4, 5]             # hipotesis que se muestran (1 correcta + el resto distractores)
const MIN_CONSULTS: Array = [1, 2, 2, 3]          # lecturas que hay que consultar antes de diagnosticar
const DEADLINE_MULT: Array = [1.6, 1.0, 0.75, 0.55]
const FLARE_MINS: Array = [210, 150, 120, 90]     # minutos desde el aviso de la llamarada hasta que llega

const INSTR: Dictionary = {
	"pressure": "Presión del módulo", "o2": "Oxígeno y consumo", "co2": "CO₂ del aire", "sensors": "Sensores de presión", "filters": "Estado de los filtros",
	"grid": "Carga de la red", "gen": "Generación solar", "lines": "Líneas eléctricas", "sys": "Sistemas afectados", "maint_power": "Mantenimiento eléctrico",
	"tank": "Reserva y balance de agua", "recycler": "Reciclador", "pipes": "Conductos", "usage": "Consumo de la tripulación", "maint_water": "Mantenimiento del agua",
	"status": "Estado de la tripulación", "symptoms": "Síntomas", "ask": "Consultar a la Dra. YARISBEL", "kit": "Botiquín disponible",
	"rad": "Nivel de radiación", "shield": "Escudo de la base", "plan": "Pronóstico", "solar": "Paneles y energía"
}

const KINDS: Dictionary = {
	"oxygen": {
		"cat": "tech", "sys": "life", "owner": "ENOC",
		"name": "Alarma de presión y oxígeno",
		"alert": "ALERTA DE PRESIÓN — HAB-01",
		"intro": "El sistema detecta una lectura de presión anormal y el oxígeno disponible baja más rápido de lo normal.",
		"advice": "ENOC: «Compara las lecturas entre sí. Si dos instrumentos independientes coinciden, probablemente no es un error de lectura. Y mira qué más cambia: la presión, el CO₂ o solo el consumo.»",
		"instr": ["pressure", "o2", "co2", "sensors", "filters"],
		"causes": {
			"leak": {
				"n": "Fuga en el módulo HAB-01 (una brecha en el casco)",
				"no": "Una fuga haría bajar la presión de verdad y los dos sensores lo confirmarían. Las lecturas no son coherentes con eso.",
				"what": "La presión de HAB-01 bajó y el oxígeno se escapaba por una brecha en el casco.",
				"why": "Un impacto abrió una grieta en la pared presurizada. El aire de adentro sale hacia el vacío exterior.",
				"learn": "En una base presurizada, una caída sostenida de la presión puede indicar una fuga. Por eso se comparan varios sensores y se actúa rápido: el aire es el recurso más urgente.",
				"tip": "Revisa la presión y compara dos sensores antes de elegir una reparación, y ten siempre un kit de parche fabricado."
			},
			"filter": {
				"n": "Filtro saturado del depurador de CO₂",
				"no": "Si el filtro estuviera saturado, el CO₂ estaría alto. En las lecturas el CO₂ está normal.",
				"what": "El aire se volvió pesado: el depurador de CO₂ no limpiaba bien y el aire útil bajaba.",
				"why": "El polvo y el desgaste saturaron el filtro, así que el CO₂ se acumulaba aunque la presión era normal.",
				"learn": "Respirar produce CO₂ y hay que retirarlo del aire. Si el filtro falla, el CO₂ sube y da dolor de cabeza y sueño, aunque la presión sea normal.",
				"tip": "Cambia o limpia los filtros antes de que se saturen y haz mantenimiento del soporte vital con regularidad."
			},
			"sensor": {
				"n": "Error de lectura de un sensor",
				"no": "Si fuera solo un sensor defectuoso, el otro sensor mostraría una presión normal. Aquí los dos indican lo mismo.",
				"what": "Un sensor dio una presión falsa y disparó la alarma, pero el aire de la base estaba bien.",
				"why": "Un sensor se descalibró por el desgaste. Los demás instrumentos mostraban una base normal.",
				"learn": "Los sistemas críticos usan sensores redundantes: si uno no coincide con los demás, lo más probable es que ese sensor esté fallando.",
				"tip": "Antes de gastar materiales en una reparación grande, contrasta siempre una lectura con otro instrumento independiente."
			},
			"recycler": {
				"n": "Fallo del reciclador de aire",
				"no": "El reciclador de aire está funcionando con normalidad en las lecturas, así que no explica lo que ves.",
				"what": "", "why": "", "learn": "", "tip": ""
			}
		},
		"ivs": [
			{"id": "patch", "n": "Sellar la fuga con el kit de parche", "d": "Reparación definitiva. Usa el minijuego de sellar la fuga y gasta el kit.", "fixes": ["leak"], "mins": 45, "tool": "patch", "mg": "patch", "q": "full"},
			{"id": "isolate", "n": "Aislar HAB-01 y cerrar su escotilla", "d": "Rápido y sin materiales, pero pierdes un módulo y queda daño en el casco.", "fixes": ["leak"], "mins": 20, "q": "partial"},
			{"id": "filter_tool", "n": "Cambiar el cartucho con un filtro de polvo fabricado", "d": "Rápido. Gasta el filtro de polvo.", "fixes": ["filter"], "mins": 20, "tool": "filter", "q": "full"},
			{"id": "filter_hand", "n": "Limpiar el filtro a mano", "d": "Más lento. Gasta 1 polímero.", "fixes": ["filter"], "mins": 40, "needs": {"polymer": 1}, "q": "full"},
			{"id": "recalibrate", "n": "Recalibrar el sensor y compararlo con el otro", "d": "Corto y sin materiales.", "fixes": ["sensor"], "mins": 10, "q": "full"},
			{"id": "reset", "n": "Reiniciar todo el soporte vital", "d": "Parece lo más seguro, pero tarda y puede dejar sin energía un rato.", "fixes": [], "mins": 30, "q": "none", "fx": {"energy": -4}}
		],
		"drain": {"filter": {"oxygen": 8.0}}
	},
	"power": {
		"cat": "tech", "sys": "power", "owner": "ENOC",
		"name": "Anomalía en la red eléctrica",
		"alert": "ALERTA ELÉCTRICA — RED PRINCIPAL",
		"intro": "La red eléctrica presenta anomalías: hay cortes y la energía disponible está cayendo.",
		"advice": "ENOC: «Mira cuánta carga lleva la red frente a su capacidad y compara con lo que generan los paneles. Si la carga es normal y la generación baja, el problema no está en la red.»",
		"instr": ["grid", "gen", "lines", "sys", "maint_power"],
		"causes": {
			"circuit": {
				"n": "Un circuito dañado (cortocircuito en una línea)",
				"no": "Si hubiera un circuito dañado, una línea concreta aparecería con falla. Las líneas se ven normales.",
				"what": "Una línea de la red tuvo un cortocircuito y dejó sin energía a parte de las estaciones.",
				"why": "El desgaste de un componente provocó un cortocircuito. La protección cortó esa línea para evitar un incendio.",
				"learn": "Un cortocircuito ocurre cuando la corriente toma un camino no previsto. Las protecciones cortan la línea dañada y hay que localizarla y repararla.",
				"tip": "Haz mantenimiento eléctrico antes de que el sistema se deteriore y fabrica un reparador de circuitos."
			},
			"overload": {
				"n": "Sobrecarga de la distribución (demasiados consumos a la vez)",
				"no": "Una sobrecarga mostraría la carga de la red por encima de su capacidad. Aquí la carga es normal.",
				"what": "Demasiados equipos consumían a la vez y la red superó su capacidad, con cortes intermitentes.",
				"why": "La red está diseñada para una carga máxima. Al superarla, las protecciones cortan estaciones para no dañarse.",
				"learn": "La energía disponible es limitada. Repartir los consumos a lo largo del día evita sobrecargas y es parte de la planificación energética.",
				"tip": "No dejes todas las estaciones trabajando a la vez y vigila la carga de la red cuando la energía esté baja."
			},
			"panel": {
				"n": "Paneles solares sucios o degradados",
				"no": "Si fueran los paneles, la generación solar estaría muy por debajo de lo esperado. Aquí la generación es normal.",
				"what": "Los paneles solares producían mucho menos de lo esperado y la energía se agotaba.",
				"why": "El polvo y el desgaste cubrían los paneles, así que captaban menos luz.",
				"learn": "El polvo reduce la energía que producen los paneles. En Marte, las tormentas de polvo pueden bajar mucho la generación; limpiar y mantener los paneles ayuda.",
				"tip": "Limpia los paneles con regularidad, sobre todo antes de las tormentas de polvo y de la noche lunar."
			},
			"sensor": {
				"n": "Error del medidor de energía",
				"no": "Si fuera el medidor, la generación y la carga calculadas no explicarían los cortes reales. Hay una causa real.",
				"what": "", "why": "", "learn": "", "tip": ""
			}
		},
		"ivs": [
			{"id": "use_repairer", "n": "Usar el reparador de circuitos", "d": "Rápido y seguro. Gasta el reparador.", "fixes": ["circuit"], "mins": 20, "tool": "repair", "q": "full"},
			{"id": "repair_hand", "n": "Reparar el componente a mano", "d": "Lento. Gasta 1 circuito y 1 chatarra.", "fixes": ["circuit"], "mins": 50, "needs": {"circuits": 1, "scrap": 1}, "q": "full"},
			{"id": "isolate_line", "n": "Aislar la línea dañada", "d": "Rápido y sin materiales, pero esa línea queda fuera de servicio.", "fixes": ["circuit"], "mins": 20, "q": "partial"},
			{"id": "shed_load", "n": "Redistribuir y escalonar la carga", "d": "Sin materiales. Reparte los consumos en el tiempo.", "fixes": ["overload"], "mins": 25, "q": "full"},
			{"id": "clean_panels", "n": "Limpiar y revisar los paneles solares", "d": "Sin materiales. Mejora también el mantenimiento eléctrico.", "fixes": ["panel"], "mins": 45, "q": "full"},
			{"id": "reset_grid", "n": "Reiniciar toda la red", "d": "Parece rápido, pero no arregla la causa y consume energía.", "fixes": [], "mins": 20, "q": "none", "fx": {"energy": -5}}
		],
		"drain": {"circuit": {"energy": 9.0}, "overload": {"energy": 6.0}, "panel": {"energy": 7.0}}
	},
	"water": {
		"cat": "tech", "sys": "water", "owner": "ENOC",
		"name": "El agua no cuadra",
		"alert": "ALERTA DE AGUA — BALANCE ANORMAL",
		"intro": "El sistema de control detecta que la cantidad de agua no coincide con lo producido y consumido: falta agua.",
		"advice": "ENOC: «Separa dos preguntas: ¿se está yendo el agua (pérdida física) o el reciclador está produciendo menos? Los conductos y el reciclador te lo dicen.»",
		"instr": ["tank", "recycler", "pipes", "usage", "maint_water"],
		"causes": {
			"leak": {
				"n": "Fuga física en un conducto",
				"no": "Una fuga dejaría humedad y menor presión en un conducto. Los conductos están secos y con presión normal.",
				"what": "Un conducto del agua tenía una fuga y se perdía agua de la reserva.",
				"why": "El desgaste de un tramo de tubería provocó una grieta por donde salía el agua.",
				"learn": "El agua es tan valiosa en el espacio que se recicla casi toda. Una fuga es una pérdida real y hay que aislar el tramo y repararlo.",
				"tip": "Revisa los conductos y haz mantenimiento del sistema de agua antes de que se desgaste."
			},
			"recycler": {
				"n": "Avería del reciclador de agua",
				"no": "Si fallara el reciclador, su rendimiento estaría bajo. El reciclador funciona casi al máximo.",
				"what": "El reciclador producía mucha menos agua limpia y la reserva bajaba más rápido.",
				"why": "Un componente del reciclador se desgastó y recuperaba menos agua de la usada.",
				"learn": "En la Estación Espacial Internacional el sistema de agua recupera la mayor parte del agua usada. Si el reciclador falla, la reserva se agota mucho antes.",
				"tip": "Haz mantenimiento del reciclador con regularidad: es lo que hace posible vivir con poca agua."
			},
			"consumption": {
				"n": "La tripulación consume más agua de lo normal",
				"no": "El consumo de la tripulación está dentro de lo esperado, así que no explica la diferencia.",
				"what": "", "why": "", "learn": "", "tip": ""
			},
			"sensor": {
				"n": "Error del medidor de nivel del tanque",
				"no": "El balance de agua medido coincide con la caída real de la reserva, así que el medidor no falla.",
				"what": "", "why": "", "learn": "", "tip": ""
			}
		},
		"ivs": [
			{"id": "patch_pipe", "n": "Reparar el conducto con chatarra y polímero", "d": "Reparación definitiva. Gasta 1 chatarra y 1 polímero.", "fixes": ["leak"], "mins": 40, "needs": {"scrap": 1, "polymer": 1}, "q": "full"},
			{"id": "isolate_pipe", "n": "Aislar el tramo con fuga", "d": "Rápido y sin materiales, pero ese tramo queda cerrado y el sistema rinde menos.", "fixes": ["leak"], "mins": 15, "q": "partial"},
			{"id": "fix_recycler", "n": "Revisar y restaurar el reciclador", "d": "Rápido. Gasta 1 circuito.", "fixes": ["recycler"], "mins": 35, "needs": {"circuits": 1}, "q": "full"},
			{"id": "flush_recycler", "n": "Lavar y reiniciar el reciclador", "d": "Sin materiales, pero lleva más tiempo.", "fixes": ["recycler"], "mins": 60, "q": "full"},
			{"id": "ration", "n": "Racionar el agua de la tripulación", "d": "No repara nada: solo oculta el problema y baja la moral.", "fixes": [], "mins": 10, "q": "none", "fx": {"morale": -5}}
		],
		"drain": {"leak": {"water": 12.0}, "recycler": {"water": 7.0}}
	},
	"flare": {
		"cat": "env", "sys": "ext", "owner": "PAM",
		"name": "Tormenta solar en camino",
		"alert": "ALERTA SOLAR — LLAMARADA DETECTADA",
		"intro": "Se detectó una llamarada solar. En unas horas llegará una oleada de radiación y puedes prepararte antes del impacto.",
		"advice": "PAM: «El escudo reduce la radiación y las zonas protegidas reducen más. Decide rápido: el tiempo que queda es limitado, y reforzar o refugiarse cuesta tiempo.»",
		"instr": ["rad", "shield", "plan"],
		"causes": {},
		"ivs": [
			{"id": "shelter", "n": "Refugiarse en la zona protegida de la base", "d": "La radiación que recibes baja a una cuarta parte. Pierdes tiempo y algo de moral.", "mit": 0.25, "mins": 60, "q": "full", "fx": {"morale": -2}},
			{"id": "reinforce", "n": "Reforzar el escudo antes del impacto", "d": "Sube el escudo y reduce el daño a un 60 %. Gasta un poco de energía.", "mit": 0.6, "mins": 45, "q": "full", "fx": {"shield": 10, "energy": -3}},
			{"id": "ignore", "n": "Seguir trabajando", "d": "No pierdes tiempo, pero recibes toda la radiación.", "mit": 1.0, "mins": 0, "q": "none"}
		],
		"lesson": {
			"what": "Una llamarada solar lanzó una oleada de radiación hacia la base.",
			"why": "El Sol libera a veces energía y partículas de golpe. En la Luna y en Marte no hay un campo magnético global ni una atmósfera gruesa que frene la radiación (en Marte la atmósfera es muy delgada).",
			"learn": "La radiación se reduce con blindaje y con zonas protegidas. Por eso los astronautas se refugian en las áreas más protegidas durante una tormenta solar.",
			"tip": "Mantén el escudo alto y, cuando llegue el aviso, decide pronto: refugiarte a tiempo vale más que reaccionar después."
		}
	},
	"storm": {
		"cat": "env", "sys": "power", "owner": "PAM", "mars": true,
		"name": "Tormenta de polvo en camino",
		"alert": "ALERTA METEOROLÓGICA — TORMENTA DE POLVO",
		"intro": "El pronóstico indica una tormenta de polvo que llegará a la base. Cubrirá los paneles y bajará la energía.",
		"advice": "PAM: «Si los paneles están limpios y los filtros listos, el golpe será menor. Prioriza la energía: es lo primero que se resiente.»",
		"instr": ["plan", "solar", "filters"],
		"causes": {},
		"ivs": [
			{"id": "panels", "n": "Limpiar y revisar los paneles solares", "d": "Reduce el daño a un 60 % y mejora el mantenimiento eléctrico.", "mit": 0.6, "mins": 60, "q": "full"},
			{"id": "filter_use", "n": "Instalar un filtro de polvo", "d": "Reduce el daño a la mitad y acorta la tormenta. Gasta el filtro de polvo.", "mit": 0.5, "mins": 20, "tool": "filter", "q": "full"},
			{"id": "wait", "n": "No hacer nada", "d": "Sin preparación, la tormenta golpea con toda su fuerza.", "mit": 1.0, "mins": 0, "q": "none"}
		],
		"lesson": {
			"what": "Una tormenta de polvo cubrió los paneles solares y redujo la energía.",
			"why": "El polvo en el aire bloquea la luz y se deposita sobre los paneles, que producen menos electricidad. En 2018 una tormenta global dejó sin energía al rover Opportunity.",
			"learn": "Las tormentas de polvo marcianas pueden durar días y reducir mucho la generación solar. Anticiparlas permite limpiar los paneles y ahorrar energía.",
			"tip": "Cuando veas el pronóstico, limpia los paneles, ten un filtro listo y no dejes la energía baja antes de que llegue."
		}
	},
	"medical": {
		"cat": "med", "sys": "crew", "owner": "Dra. YARISBEL",
		"name": "Tripulante con síntomas anormales",
		"alert": "ALERTA MÉDICA — TRIPULANTE CON SÍNTOMAS ANORMALES",
		"intro": "Un tripulante presenta síntomas y necesita atención. Reúne información, identifica qué le pasa y decide cómo ayudarlo.",
		"advice": "",
		"instr": ["status", "symptoms", "ask", "kit"],
		"causes": {},
		"ivs": []
	}
}

# Consejos de PAM y ENOC para los mensajes de coordinacion al aparecer una emergencia
const COORD: Dictionary = {
	"oxygen": "PAM: «Prioridad: el aire. Revisa los instrumentos del soporte vital antes de gastar materiales.»",
	"power": "PAM: «Prioridad: la energía. Que todo lo demás espere hasta saber de dónde viene el problema.»",
	"water": "PAM: «Prioridad: no perder agua. Primero hay que saber si se pierde o se produce menos.»",
	"flare": "PAM: «Tormenta solar en camino. Decidamos pronto cómo protegernos.»",
	"storm": "PAM: «Tormenta de polvo en camino. Preparemos los paneles y cuidemos la energía.»",
	"medical": "PAM: «La Dra. YARISBEL puede guiarnos. Los síntomas primero, el tratamiento después.»"
}


static func kind_def(k: String) -> Dictionary:
	return KINDS.get(k, {})


# Causas que se muestran como hipotesis: la verdadera + distractores (solo las que tienen texto "no")
static func hypothesis_ids(k: String, true_cause: String, n: int, rng: RandomNumberGenerator) -> Array:
	var causes: Dictionary = (KINDS[k]["causes"] as Dictionary)
	var others: Array = []
	for c in causes.keys():
		if str(c) != true_cause:
			others.append(str(c))
	# mezcla estable con el generador del juego
	for i in range(others.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = others[i]
		others[i] = others[j]
		others[j] = tmp
	var out: Array = [true_cause]
	for c in others:
		if out.size() >= n:
			break
		out.append(c)
	for i in range(out.size() - 1, 0, -1):
		var j2: int = rng.randi_range(0, i)
		var t2: String = out[i]
		out[i] = out[j2]
		out[j2] = t2
	return out


static func iv_def(k: String, iv_id: String) -> Dictionary:
	for iv in (KINDS[k]["ivs"] as Array):
		if str(iv["id"]) == iv_id:
			return iv
	return {}
