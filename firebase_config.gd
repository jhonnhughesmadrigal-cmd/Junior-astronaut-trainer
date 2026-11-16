extends RefCounted
# v36 — Configuración de Firebase (rellenar con los datos de TU proyecto).
# Dónde encontrarlos: consola de Firebase → ⚙ Configuración del proyecto → General → «Tus apps» → app web.
#   API_KEY   = apiKey      (p. ej. "AIza...")
#   PROJECT_ID = projectId  (p. ej. "mision-perseo-12345")
# La apiKey de una app web de Firebase no es una contraseña: identifica el proyecto y va dentro del
# juego en todo caso. La seguridad la dan las reglas de Firestore (firebase/firestore.rules).
# Si se dejan vacíos, el juego funciona como en v35: perfiles solo en este dispositivo.

const API_KEY: String = ""
const PROJECT_ID: String = ""
