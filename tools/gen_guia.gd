extends SceneTree
# Genera docs/GUIA_DOCENTE.md a partir de lesson_data.gd (asi la guia y el juego no se desincronizan).
# Uso: godot --headless --path . --script res://tools/gen_guia.gd
const LessonData = preload("res://lesson_data.gd")
const KIND: Dictionary = {"goto": "Ir a un lugar", "observe": "Observar unos segundos", "jump": "Saltar y medir el tiempo en el aire", "ice": "Recoger hielo", "exit": "Salir por la esclusa"}

func _initialize() -> void:
	var t: String = "# Misión Perseo — Guía docente de las Misiones de clase\n\n"
	t += "> Archivo generado con `tools/gen_guia.gd` a partir de `lesson_data.gd`. No editar a mano: cambia el catálogo y vuelve a generarlo.\n\n"
	t += "## Cómo se usan\n\n"
	t += "1. En el menú principal, pulsa **Misiones de clase**.\n2. Filtra por **tema** (Gravedad, Agua, Historia, Energía, Geología, Atmósfera) y por **mundo** (Luna o Marte).\n3. Pulsa una tarjeta: el alumno empieza junto a la base (o dentro, según la misión) y una tarjeta arriba a la derecha le dice qué hacer. Los lugares lejanos se marcan con una columna de luz.\n4. Al terminar los pasos aparece un cuestionario. Si se equivoca, puede volver a intentarlo (no hay castigo); se cuentan las respuestas correctas **a la primera**.\n5. El resumen muestra *Lo que aprendiste* y las fuentes. Las misiones completadas quedan marcadas como **Hecha** en ese ordenador.\n\n"
	t += "**Importante:** durante una misión de clase el tiempo del juego está detenido (no se gastan recursos, no hay emergencias) y **no se modifica la partida guardada** del alumno. Para salir antes: [Esc] → «Guardar y salir al menú» (en una misión no guarda nada).\n\n"
	t += "**Sobre los datos:** las cifras con «≈» son aproximadas y se verificaron en las fuentes citadas (NASA) en noviembre de 2026; conviene revisarlas antes de usarlas en una evaluación. Lo que el juego simplifica (velocidad del salto, posiciones en el mapa, tamaño de los lugares) son valores de juego, no datos reales: el mapa está estilizado y no está a escala.\n\n"
	t += "## Resumen\n\n| Misión | Mundo | Tema | Duración |\n|---|---|---|---|\n"
	for m in LessonData.MISSIONS:
		t += "| %s | %s | %s | ≈ %d min |\n" % [m["title"], m["loc"], m["topic"], int(m["mins"])]
	for m in LessonData.MISSIONS:
		t += "\n---\n\n## %s\n\n**Mundo:** %s · **Tema:** %s · **Duración:** ≈ %d min · **Identificador:** `%s`\n\n" % [m["title"], m["loc"], m["topic"], int(m["mins"]), m["id"]]
		t += "%s\n\n**Pasos para el alumno**\n\n" % m["card"]
		var i: int = 1
		for st in m["steps"]:
			t += "%d. %s *(%s)*\n" % [i, st["text"], KIND.get(st["kind"], st["kind"])]
			i += 1
		t += "\n**Preguntas** (la respuesta correcta en negrita)\n\n"
		var qi: int = 1
		for q in m["quiz"]:
			t += "%d. %s\n" % [qi, q["q"]]
			for j in (q["a"] as Array).size():
				var a: String = str(q["a"][j])
				t += "   - %s\n" % (("**" + a + "**") if j == int(q["ok"]) else a)
			t += "   - *Explicación:* %s\n" % q["why"]
			qi += 1
		t += "\n**Lo que aprendiste**\n\n"
		for l in m["learned"]:
			t += "- %s\n" % l
		t += "\n**Fuentes**\n\n"
		for s in m["sources"]:
			t += "- [%s](%s)\n" % [s[0], s[1]]
	t += "\n---\n\nIdeas para clase (sugerencias, no probadas con alumnos): pedir que anoten el tiempo de sus saltos en la Luna y en Marte y los comparen; que expliquen con sus palabras una frase de *Lo que aprendiste*; que busquen la fuente citada y encuentren el dato.\n"
	var f := FileAccess.open("res://docs/GUIA_DOCENTE.md", FileAccess.WRITE)
	f.store_string(t)
	f.close()
	print("guia generada: ", t.length(), " caracteres")
	quit()
