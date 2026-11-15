# Datos reales usados en el juego (verificar siempre en la fuente original)

- Noche lunar ~14 días terrestres: NASA NTRS, "Mission Design and Implementation Considerations for Lunar Night Survival"
  https://ntrs.nasa.gov/api/citations/20190000997/downloads/20190000997.pdf
- Agua en la ISS (~1 galón/día por astronauta, ~98% recuperado): NASA ECLSS fact sheet
  https://www.nasa.gov/wp-content/uploads/2025/08/g-657270-59-hp-environmental-control-and-life-support-system-eclss.pdf
- Radiación en Marte (0.67 mSv/día superficie, 1.8 mSv/día viaje) y ISS (0.4-1.0 mSv/día): mediciones RAD de Curiosity (Hassler et al., Science, 2013)
  https://www.space.com/18753-mars-radiation-manned-mission.html
- Tormentas de polvo en Marte y rover Opportunity (2018): NASA vía divulgación
  https://www.nationalgeographic.com/science/article/mars-rover-opportunity-dust-storm-nasa-space-science

# NO son datos reales (números de diseño del juego)
Consumos diarios (-6 oxígeno, -5 comida, etc.), efectos de cada acción, y probabilidades de eventos.

# Historia
Historia y diálogos originales, inspirados en la premisa general de la película The Martian (2015): astronauta(s) que deben sobrevivir en otro mundo con recursos limitados. Los personajes (Wilson, Dra. Osei, Kenji, Lucía) son inventados para este proyecto.

# Audio
Música y efectos generados por código (Python/numpy) para este proyecto: carpeta audio/. Se pueden reemplazar por archivos propios con el mismo nombre.

# Fase 5
Guardado: user://savegame.json (autoguardado al comenzar cada día y al salir al menú desde la pausa). Ajustes: user://settings.cfg.
Los materiales, herramientas, eventos y la exploración del exterior son mecánicas de diseño del juego, no datos reales.

# Fase 6: reloj y noche
Se eliminaron las acciones por dia. El tiempo avanza con las acciones (estaciones 1-1.5 h, fabricar 1-2 h, hablar 10 min, caminar 1 min por casilla, exterior 2 min por paso).
Dia de la base: 06:00-20:00 normal; 20:00-06:00 noche (si sigues despierto bajan energia y moral). Se puede dormir desde las 18:00 hasta las 06:00.
Dificultad (Facil/Normal/Dificil): cambia el gasto de recursos, la frecuencia de eventos y de pesadillas.
Las pesadillas, el cansancio y el horario de la base son mecanicas de diseño, no datos cientificos. El horario es una rutina de la base (como en la ISS) y es independiente de la noche lunar de ~14 dias.
Los guardados de la fase 5 no son compatibles (formato v2).

# Fase 6 (actualizada): reloj en tiempo real
El tiempo corre solo: 1 hora de juego cada 30 s reales (TIME_SCALE). Se pausa en dialogos y menus. Caminar no gasta tiempo.
Las tareas aceleran el tiempo: estaciones/hablar/recoger x10 (TASK_SPEED) y fabricar herramientas x30 (CRAFT_SPEED).
El exterior ya no tiene limite de pasos.
El gasto de recursos (BASE_DRAIN) se calibro con un bot de prueba; son numeros de diseño, no datos cientificos.

# Fase 7: mundo amplio con zonas reales
Los lugares son reales pero el mapa esta ESTILIZADO (no a escala ni en su posicion real). "Restos del cargamento" y el "Campamento Perseo" son ficcion del juego.
Verifica siempre las cifras en la fuente original; son aproximadas y pueden haberse actualizado.

## Luna
- Mar de la Tranquilidad / Apolo 11 (20 jul 1969): https://en.wikipedia.org/wiki/Apollo_17 y https://en.wikipedia.org/wiki/Taurus%E2%80%93Littrow (misiones Apolo)
- Valle Taurus-Littrow / Apolo 17 (dic 1972, ultima mision tripulada en alunizar hasta ahora; verificar novedades de Artemis): https://en.wikipedia.org/wiki/Taurus%E2%80%93Littrow
- Cráter Shackleton (~21 km de diametro, ~4 km de profundidad, suelo en sombra permanente, indicios de hielo no confirmados): consultas a NASA/LRO y Sky & Telescope
- Cráter Tycho (~85 km, ~100 millones de anos, rayos de mas de 2.000 km): https://en.wikipedia.org/wiki/Tycho_(lunar_crater) y https://www.britannica.com/print/article/611436
- Monte Malapert (luz solar ~90% del ano, vista casi continua de la Tierra): https://www.technewsworld.com/story/the-moon-may-soon-become-a-stargazer-78526.html

## Marte
- Cráter Jezero (~45 km; Perseverance aterrizo el 18 feb 2021): https://en.wikipedia.org/wiki/Jezero_(crater)
- Cráter Gale y Monte Sharp (~154 km; Monte Sharp ~5,5 km; Curiosity, ago 2012): https://en.wikipedia.org/wiki/Gale_(crater) y https://en.wikipedia.org/wiki/Mount_Sharp
- Valles Marineris (~4.000 km, hasta ~6-7 km de profundidad, ~20% de la circunferencia): https://science.nasa.gov/resource/mars-canyon-with-los-angeles-for-scale/
- Olympus Mons (>20 km de altura, ~600 km de ancho): https://science.nasa.gov/mars/facts/olympus-mons/
- Hellas Planitia (~2.300 km de diametro, ~7 km de profundidad): https://www.guinnessworldrecords.com/world-records/601678-largest-impact-basin-on-mars
- Casquete polar norte (hielo de agua y polvo, hasta ~3 km de espesor): https://astrobiology.com/2019/05/23/massive-ice-discovery-opens-a-window-into-mars-history/

## Sobre la "estacion de asteroides"
No se encontro ninguna estacion de asteroides en la superficie lunar. Lo mas cercano es el Gateway, una estacion planeada en ORBITA lunar; reportes de marzo de 2026 indican que la NASA la pauso: https://sharjah24.ae/en/Articles/2026/03/24/NASA-pauses-Gateway-lunar-space-station-project

## Mecanicas de diseno (no son datos cientificos)
Materiales por zona, el mapa de navegacion fabricable, la niebla de exploracion y la recompensa de moral al estudiar una placa.

# Fase 8: render 3D
- La logica del juego no cambia: solo se reemplazo el DIBUJO del mundo (view3d.gd). El HUD, dialogos y menus siguen en 2D encima.
- Todo se construye por codigo con formas primitivas (cajas, cilindros, esferas, capsulas); no usa modelos ni imagenes externas.
- Terreno con relieve generado de las mismas zonas (crateres hundidos con borde, volcan, montana, canon profundo). Alturas en metros: 1 casilla = 2 m.
- Luz y cielo siguen el reloj del juego: sol de 06:00 a 20:00 (arco sur), luz de la Tierra de noche, noche lunar sin sol, niebla de polvo en tormentas de Marte, estrellas y la Tierra en el cielo lunar.
- Renderer: "Compatibility" (gl_compatibility) para que funcione en equipos modestos. Se puede cambiar a Forward+ en Configuracion del proyecto > Rendering (no probado).
- Controles: V alterna vista 3D/2D (guardado en ajustes), rueda del raton = zoom de camara.
- El color del suelo lunar en 3D se oscurece (el regolito real es gris oscuro); los colores de las zonas son estilizados.

# Camaras (fase 8)
Tecla C (o el menu de pausa) cambia entre cuatro camaras 3D:
1. Tercera persona (por defecto): camara fija con el norte arriba; WASD absoluto.
2. Primera persona: ojos del casco (1,62 m), campo de vision amplio, viñeta de visor, mira y rumbo. W avanza hacia donde miras, S retrocede, A/D giran 90 grados. E usa lo que tienes enfrente.
3. Detras del personaje: camara de persecucion que gira con el personaje; mismos controles relativos.
4. Vista aerea: camara cenital alta; WASD absoluto.
La rueda del raton hace zoom en las vistas 1, 3 y 4 (no en primera persona). V vuelve a la vista 2D clasica (controles absolutos).
El juego sigue siendo por casillas: la primera persona gira en pasos de 90 grados y avanza de casilla en casilla.

# Movimiento libre y raton (fase 8, revision)
- El jugador ya no se mueve de casilla en casilla: tiene posicion continua (decimales), caminar a 4,2 casillas/s (unos 8 m/s del mundo 3D) y Shift para correr (x1,55).
- Colisiones por circulo (radio 0,3 casillas) contra casillas solidas, con deslizamiento a lo largo de las paredes.
- Los objetos del mundo siguen siendo por casillas. Para interactuar, E usa lo que tienes ENFRENTE: la casilla interactuable dentro de un cono de ~57 grados y a menos de 1,7 casillas (el cartel [E] indica cual).
- Controles absolutos (tercera persona fija, vista aerea, vista 2D): WASD o flechas mueven en las 8 direcciones y el personaje se gira hacia donde camina.
- Controles relativos (primera persona y detras del personaje): el RATON gira la mirada (en primera persona tambien arriba/abajo, con limites), W/S avanzan y retroceden, A/D se desplazan de lado, flechas izquierda/derecha tambien giran.
- El raton se captura solo en primera persona y detras del personaje cuando no hay dialogo, menu o pausa. La sensibilidad se ajusta en la pausa.

# Versión alfa 0.1: interfaz y escalado
- Menú principal nuevo (Continuar, Nueva misión con destino/dificultad, Cómo jugar, Finales, Opciones, Créditos, Salir) sobre una vista 3D orbitando la base.
- En el juego: F1 = controles, F2 = estadísticas (con gráfica por día), F3 = FPS, F11 = cambia modo de pantalla. Los botones "Controles" y "Estadísticas" están en el panel lateral.
- Opciones: modo de pantalla (ventana / pantalla completa / sin bordes), tamaño de ventana, escala de interfaz, VSync, calidad gráfica (baja/media/alta).
- Escalado: resolución base 1100x650, modo canvas_items con aspecto "expand" (se adapta a la proporción de la pantalla).
- Verificado con capturas SOLO en 1920x1080 y 1280x720 (más 1100x650 y proporciones extra en pruebas previas). Probado en Godot 4.4.1, no en 4.7.2.
- Alfa 0.1b: la vista del juego ocupa toda la ventana; recursos, inventario, registro y botones F1/F2 son un HUD translúcido encima (ya no hay panel lateral).

# Alfa 0.2: tutorial, outro y finales
- Tutorial "Día 0" (8 páginas): se muestra al empezar cada misión (se puede desactivar con la casilla de la última página), y se reabre desde la pausa o desde "Cómo jugar". Los datos reales que menciona (noche lunar de ~14 días, tormentas de polvo en Marte) son los ya citados arriba; los números de las estaciones y herramientas son de diseño del juego.
- Pantalla propia con ilustración animada (dibujada por código) para cada uno de los 11 finales, con epílogo original; los finales de derrota añaden un consejo.
- Música de outro generada por código (tools: numpy): music_outro_win.wav (victorias) y music_outro_lose.wav (derrotas). Comienza ~2 s después del jingle del final.

# Alfa 0.3: música según la situación
- Base (interior), de día o de noche: music_moon / music_mars (calmada).
- Exterior de día: music_day_moon / music_day_mars (calmada, con otro color: arpegio suave a ~75 bpm).
- Exterior de noche (20:00-06:00): music_night_moon / music_night_mars (120 bpm, bombo, bajo y arpegio rápido, para dar sensación de apuro).
- Cambio con fundido corto al cruzar la esclusa o al cambiar la hora. Generadas por código: tools/gen_music2.py (numpy).

# Alfa 0.4: visuales
- Trajes y animaciones de los personajes rediseñados (por código): casco con visor reflectante, mochila de soporte vital, panel del pecho, articulaciones y botas; poses de caminar, correr, trabajar en estación, fabricar, recoger y hablar. Marcas de rol por personaje (Lucía con cruz médica).
- HUD con iconos para materiales y herramientas (dibujados por código; sustituibles por art/icons/*.png).
- Soporte para modelos .glb importados (art/3d/...) en materiales recolectables y estaciones. Ver ART_GUIDE.md.

## Alfa 0.5 — Aprende (datos NASA) y animaciones de acciones

### Datos en vivo (nasa_data.gd)
- Solo se usa el endpoint APOD de api.nasa.gov: `https://api.nasa.gov/planetary/apod?api_key=...` (documentación del repositorio oficial github.com/nasa/apod-api). Campos leídos: title, explanation, url, media_type, date, copyright.
- Clave: DEMO_KEY por defecto; límites documentados en la página de autenticación de api.nasa.gov: DEMO_KEY 30 peticiones/hora y 50/día por IP; clave registrada 1.000/hora. El jugador puede escribir su propia clave (menú Pausa → Aprende · datos NASA).
- NO se verificaron (y por eso NO se usan) otros endpoints: DONKI (erupciones solares), NeoWs (asteroides), Mars Rover Photos ni el catálogo data.nasa.gov. No pude abrir su documentación desde el entorno de desarrollo.
- IMPORTANTE: las llamadas reales a la API NO se pudieron probar desde el entorno de desarrollo (sin acceso a internet). Se probó el análisis de la respuesta con datos simulados, los errores (sin conexión, 429, clave rechazada) y la recuperación con caché. Prueba en tu equipo con conexión.
- La nota del repositorio apod-api menciona un cambio de endpoint previsto (1 dic 2026): si deja de funcionar, revisa la documentación actual en api.nasa.gov.
- El texto de APOD llega en inglés tal como lo publica la NASA; algunas imágenes tienen derechos de autor (el campo copyright se muestra).

### Lección de supervivencia (8 preguntas, sin conexión)
Conocimiento general; las cifras son aproximadas y deben verificarse en fuentes de la NASA:
- Noche lunar ~14 días terrestres (ver NTRS arriba).
- Falta de atmósfera densa/campo magnético global en la Luna → más exposición a partículas solares.
- Atmósfera marciana mayormente CO₂; MOXIE (Perseverance) produjo oxígeno a partir de CO₂.
- Día marciano (sol) ~24 h 39 min (aprox.).
- Hielo de agua en cráteres polares en sombra: misión LCROSS (2009) detectó agua.
- Opportunity y la tormenta de polvo global de 2018 (energía solar bloqueada).
- Reciclaje de agua en la ISS (~98 %, cifra de divulgación NASA; verificar la actual).
- Recomendación de refugiarse ante una erupción solar intensa.
No tengo una fuente verificada con URL exacta para cada pregunta; trátalas como material didáctico, no como cita científica.

### Animaciones de acciones
- Recoger chatarra/piezas ("grab"): agacharse, alcanzar, levantar y guardar; pieza que vuela a la mochila e ícono que vuela al HUD y rebota.
- Picar hielo ("mine"): tres golpes con chispas de hielo.
- Pulsar/operar estaciones ("press"): brazo extendido, toques con anillo de pulso.
- Fabricar ("craft"): chispas continuas y destello "¡Listo!".
- Textos flotantes "+N recurso", anillos en puertas/esclusa e interacciones.

## Alfa 0.6 — Personajes y texturas del exterior
- Personajes: torso/pelvis/cuello y hombros rediseñados para que todas las partes estén unidas; visor dorado brillante; materiales del traje sin sombra propia (sin manchas dentadas).
- Rocas, vetas de metal, hielo y cajas de polímero: texturas y mallas generadas por código (ext_tex.gd), sin imágenes externas. Opciones → Gráficos → "Texturas del exterior": Sencillas / Detalladas / Alta (con relieve). El cambio de textura es inmediato; la forma de las rocas cambia al iniciar una misión nueva.

## Alfa 0.7 — Nombres, gráficos y web
- Tripulación renombrada: Dra. YARISBEL (antes Osei), ENOC (antes Kenji), PAM (antes Lucía). Etiquetas de nombre sobre cada personaje.
- Gráficos: sombras, MSAA, escala de render, FPS, efectos, estrellas, glow, niebla, brillo, presets. FXAA NO se ofrece: en el renderizador Compatibilidad no produjo cambio visible en la prueba (Godot 4.4.1).
- Web: export_presets.cfg incluye el preset "Web" (sin hilos). Ver LEEME_WEB.txt en la carpeta web.

## Alfa 0.8 — Suelo con cráteres, salto y caída
- Suelo: cráteres con relieve real (cuenco + borde) y textura/normal map generada por código (ext_tex.gd `make_ground`), más grano fino repetido. Luna ~99 cráteres, Marte ~59. Opciones → Gráficos → "Texturas del exterior" controla el detalle (Sencillas = sin textura de suelo).
- Los cráteres del suelo son decoración jugable (se camina por dentro). La forma y la cantidad son del juego, NO son un mapa real de la Luna ni de Marte.
- Salto con [Espacio] (solo afuera). Se puede pasar sobre rocas, vetas, hielo y cristales si el salto supera 0,4 m. Huecos/fisuras: 2–3 casillas (Valles Marineris: banda ancha con puentes). Si el centro del jugador pisa un hueco, cae, vuelve al último suelo firme y pierde 3 de moral y 2 de energía.
- Gravedad: ver «Alfa 0.9.4» (valores reales de la NASA para Luna y Marte).
- Pruebas: Godot 4.4.1, render por software, sin GPU real. Probado: caída sin saltar, cruce de un hueco de 3 casillas saltando, rocas bloqueadas sin salto y pasadas con salto, vista 2D y que no se salta dentro de la base. NO probado: sensación de control con teclado real, rendimiento en GPU, Godot 4.7.2.

## Alfa 0.9 — Inglés y optimización
- Idiomas: Español / English. Primera ejecución: idioma del sistema (escritorio) o del navegador (web); `en*` → inglés, cualquier otro → español. Se cambia desde el menú principal (botones Español/English; recarga la escena) y queda guardado en settings.cfg. En Opciones → Juego el selector se desactiva durante una partida.
- Cómo funciona: el texto original en español es la clave. `Lang.t("texto")` (lang.gd) devuelve el mismo texto o su traducción de `lang_en.gd` (~720 entradas). Si falta una traducción se ve el texto en español. Para añadir/corregir inglés, editar solo `lang_en.gd`.
- Las traducciones al inglés las escribí yo (Claude) y NO han sido revisadas por una persona. Los datos de la NASA (placas, preguntas del Aprende, lecciones) conservan las mismas cifras que en español, pero la redacción en inglés conviene que la revise alguien antes de usarla en clase.
- Los nombres de personajes no se traducen (Wilson, ENOC, PAM, Control); "Dra. YARISBEL" se muestra como "Dr. YARISBEL" y "Narración/Banco de trabajo/Cama" como "Narration/Workbench/Bed". Los textos que vienen de api.nasa.gov (APOD) ya son en inglés (texto original de la NASA).
- Optimización (medido en Godot 4.4.1 con render por software; NO hay medición en GPU real):
  - Rocas, vetas, hielo, cajas y guijarros se dibujan en bloques de 12x12 casillas en vez de un único MultiMesh gigante, así el motor descarta lo que no se ve (y sus sombras). Triángulos por fotograma en el exterior (calidad Alta): ~1,08 M → ~0,22–0,38 M según la posición; menú: ~1,03 M → ~0,38 M. Las llamadas de dibujo suben (255–290 → 300–570).
  - Textura del suelo (cráteres): perfil radial tabulado en vez de calcular cada píxel; ~2,2 veces más rápido (≈0,7 s → ≈0,3 s con 10 px/casilla, en este equipo). Diferencia con la versión anterior: media 0,01–0,05 de 255.
  - Menú: el fondo 3D se redibuja a la mitad de FPS. Escritorio: con la ventana sin foco se limita a 15 FPS (no probado en pantalla real).
  - Calidad automática (Opciones → Gráficos): si durante 4 s el juego va a menos de 22 FPS baja un escalón (Alta→Media→Baja), máximo 2 veces; solo con un preset activo. Probado bajo render por software (bajó a Media y a Baja). Los umbrales (22 FPS, 4 s) son una elección mía, no un estándar.
  - Web: primera ejecución en calidad Media; servidor.py envía gzip (index.wasm 43,7 MB → 9,5 MB; descarga total ≈ 45 MB → ≈ 11,5 MB, medido con gzip nivel 6). El tamaño del .wasm lo fija la plantilla de exportación estándar de Godot.
- Aviso conocido (ya existía en 0.8): al construir las pantallas de final aparecen 80 mensajes "Invalid polygon data, triangulation failed" en la consola (arte de ending_art.gd con polígonos degenerados en esta prueba). No impide jugar; sin diagnosticar la causa.
- Pendiente de probar: Godot 4.7.2, GPU real, teclado real, navegadores distintos de Chromium, detección de idioma en Firefox/Safari, datos en vivo de api.nasa.gov desde el navegador (CORS).

## Alfa 0.9.1 — Vista 2D sin lag
- Causa: cada fotograma se dibujaban ~450 casillas (5–10 primitivas cada una, con funciones de GDScript) → ~14,6 ms de script y ~2.860 llamadas de dibujo por fotograma (medido en Godot 4.4.1; en el navegador el GDScript corre más lento, así que ahí pesa más).
- Solución: el terreno fijo se dibuja una vez en texturas (bloques de 12x12 casillas, creados bajo demanda, máximo 30 en memoria ≈ 28 MB; el interior de la base es una sola textura). Cada fotograma solo copia esas texturas y dibuja lo que cambia (cajas, vetas, hielo, placas, personajes, jugador). Mientras un bloque nuevo se prepara (2 fotogramas) se dibuja casilla a casilla como antes.
- Resultado medido: `_draw_map` exterior 14,6 ms → ~0,8 ms; interior → ~0,4 ms; llamadas de dibujo 2.859 → 180 y tiempo por fotograma 77,7 → 20,4 ms (render por software, Godot 4.4.1). Web (Chromium con render por software, vista 2D dentro de la base): 5,8 → 9,3 FPS. Son cifras relativas: NO hay medición en GPU real ni en un PC escolar.
- Cambios visibles: la cámara 2D exterior se ajusta a píxeles enteros (hasta 1 px de diferencia al moverse); con "Tamaño de la interfaz" 0,85 los bloques se escalan con filtro lineal (puede verse un poco más suave que antes). La comparación pixel a pixel con la versión anterior solo difiere por ese desplazamiento y por animaciones.

## Alfa 0.9.2 — Pantalla de carga web
- La página web ya no muestra el cargador de Godot: `web_shell.html` (plantilla HTML propia, configurada en `export_presets.cfg`) dibuja una pantalla "Misión Perseo" con luna, barra de progreso y consejos, en español o inglés según el idioma del navegador.
- El juego avisa a la página con `window.perseoReady()` (main.gd, `_web_ready`) cuando el menú ya se ve; entonces la pantalla se desvanece. Si el juego no avisa, se retira sola a los 90 s.
- `project.godot`: `boot_splash/show_image=false` y fondo oscuro (también quita el logo de Godot al abrir en escritorio).

## Alfa 0.9.3 — Lag 2D, materiales sin colisión y explicaciones
- Vista 2D: bloques de terreno de 6x6 casillas, creados de a uno por fotograma y por adelantado alrededor de la pantalla; mientras un bloque no esta listo se pinta un color plano en vez de dibujar casilla a casilla. Medido en Chromium (render por CPU): picos maximos de ~550-730 ms a ~170-185 ms.
- Chatarra, hielo y cargamento ya recogidos dejan de bloquear el paso. Si el material se renueva bajo el jugador, se le mueve al suelo libre mas cercano.
- La primera vez que se recoge cada material (chatarra, cargamento, hielo de la Luna, hielo de Marte) sale una explicacion corta (`_learn_lines` en main.gd). Se guarda en la partida (`learned`). Las fuentes estan en el comentario sobre la funcion:
  - LCROSS/Cabeus 5,6 % ± 2,9 % de hielo en masa (space.com); Phoenix 2008 (JPL/NASA); hielo enterrado en Utopia Planitia con SHARAD (space.com); MOXIE ~122 g en 16 pruebas (ScienceAlert, citando a NASA); regolito/ilmenita (NASA NTRS 20170001458); repuestos de la ISS y ReFabricator (nasa.gov; Astronomy.com 2019).
  - "Cargamento perdido" y la dificultad de reponer circuitos son ficcion del juego (asi se indica en el texto).

## Alfa 0.9.4 — Relieve caminable y gravedad real
- Gravedad (NASA): Luna 1,62 m/s² (nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html; también "1/6 de la terrestre" en science.nasa.gov/moon/facts) y Marte 3,73 m/s² de media en superficie (nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html, ~0,38 de la terrestre). Verificado en esas fichas durante esta sesión.
- La velocidad de despegue (1,7 m/s, igual en ambos mundos) y la profundidad de caída (3 m) son valores de juego, no datos de la NASA. Con ellos (física v²/2g y 2v/g): Luna sube ~0,87 m y está ~2,1 s en el aire; Marte ~0,37 m y ~0,91 s (medido en el juego). Caída a un hueco: t = √(2·3/g) → Luna 1,92 s, Marte 1,27 s.
- Relieve `#` (bordes de cráter, montañas, volcán, paredes de valle) ahora se camina (solo el borde del mundo bloquea) con 70 % de velocidad. En 3D el jugador sigue la altura del terreno; en 2D se ve igual que antes (casilla de pared).
- Vista 2D: precarga de 3 bloques de margen (hasta 200 bloques ≈ 46 MB). El dibujo 2D en sí cuesta ~1 ms de GDScript por fotograma; los tirones al moverse eran la creación de bloques nuevos. `view3d._process` ya no corre en 2D (ahorro medido ~0,3 ms).

## Alfa 0.9.5 — Velocidad, bajadas y huecos
- Velocidad al caminar 4,2 → 2,6 casillas/s (5,2 m/s en 3D; sigue siendo un valor de juego, no real); correr ×1,4 (3,6 casillas/s).
- La altura del jugador en 3D se suaviza (exp. 12/s) para que las bajadas de colinas no den saltos bruscos.
- Un hueco solo hace caer cuando las cuatro esquinas a 0,4 casillas del centro del jugador también son hueco; el borde se pisa sin caer (medido: cae ~0,4 casillas dentro del borde).

## Alfa 0.9.6 — Minijuegos del banco de trabajo y explicaciones arriba
- Fabricar ya no es instantáneo: cada herramienta abre un minijuego y los materiales solo se gastan si lo superas (Esc cancela sin gastar nada). Kit de parche = conectar 4 cables por color; Reparador de circuitos = conectar 5 piezas por color Y forma (dos son del mismo color); Botiquín = diagnóstico en 2 pasos (qué enfermedad es y qué debe llevar el botiquín) con 9 casos distintos que no se repiten hasta agotarse; Filtro de polvo = memoria de patrón (4 luces, 5 rondas); Mapa = memoria de patrón (5 luces, 6 rondas). Los errores no castigan, solo se cuentan (y se muestran en el registro).
- Las explicaciones de «para qué sirve / cómo se usa / en la realidad» de cada herramienta salen la primera vez que la fabricas, en un panel dorado ARRIBA de la pantalla (también las de chatarra, cargamento y hielo, que antes salían abajo). El juego queda en pausa hasta pulsar [E]/clic; [Esc] salta.
- Casos clínicos (minigame_data.gd): mareo de adaptación, deshidratación, irritación por polvo, exceso de CO2, herida infectada, quemadura, hipotermia, esguince, problemas de sueño. SON SITUACIONES DE JUEGO basadas en problemas de salud reales en misiones espaciales, simplificadas para niños; no son consejo médico ni dosis. Fuentes: en esta sesión solo comprobé por búsqueda que existen publicaciones/artículos sobre (a) «lunar hay fever» (irritación por polvo lunar en Apolo; p. ej. Stony Brook Medicine y Futurity), (b) mareo espacial (NASA NTRS, varios informes) y (c) CO2 elevado y dolores de cabeza en la ISS (NASA NTRS 20100036637 y la hoja técnica OCHMO-TB-004 de NASA). NO leí esos documentos completos: los textos del juego son resúmenes generales y conviene que un docente o médico los revise.
- Datos reales en los textos de las herramientas (revisar antes de publicar): Opportunity perdió contacto en 2018 tras una tormenta de polvo global; un sol marciano dura ~24 h 39 min; LRO (Luna) y MRO (Marte) son orbitadores que fotografían la superficie; la ISS usa capas protectoras contra micrometeoritos. Sin documento citado en esta sesión para ellos (los conozco de memoria).


## Alfa 0.9.7 — Sistema incremental, mochila y obras de ENOC

Todo esto es **mecánica de diseño del juego, no datos científicos**. Los números son valores de partida para equilibrar; **no se han probado jugando de verdad** (solo con scripts automáticos), así que conviene ajustarlos tras partidas reales.

### Ritmo del tiempo
- `TIME_SCALE` 1.0: 1 hora de juego ≈ 60 s reales (antes ≈ 12 s). Tareas x5 (`TASK_SPEED`) y fabricar/mejorar x10 (`CRAFT_SPEED`).

### Dificultad que sube con los días
- `_prog()` va de 0 a 1 a lo largo de `MAX_DAYS` (30). Multiplica: gasto de recursos (`_drain_k`), probabilidad de eventos (`_events_p`, y desde el día ~10 un segundo evento diario), material que da la superficie (`_mat_k`, baja con los días) y días de renovación de los puntos de material (`_respawn_days`).
- Cuatro dificultades: Fácil, Normal, Difícil y **Extremo** (más gasto, más eventos y menos material). Cada una tiene `g_drain`, `g_ev`, `g_mat`, `r_add` en `DIFFICULTIES`.
- Resultado medido con script (día 30): gasto x0.92 (Fácil) / x1.35 (Normal) / x1.78 (Difícil) / x2.34 (Extremo); material x1.0 / 0.85 / 0.70 / 0.45.

### Mochila y objeto en la mano
- Casillas: 8 + 4 por nivel de mochila (máx. 3 niveles). Apilado: 8 materiales por casilla; herramientas según `STACK_TOOL`.
- Tecla [I] abre la mochila; [Q] o clic cambia el objeto en la mano. Hoy solo el kit de parche se puede sostener (es el único objeto que se usa "a mano"); no hay otros objetos sostenibles.
- Si la mochila no tiene espacio, no se recoge ni se fabrica.

### Traje
- Aire del traje: 240 min de juego + 60 por nivel. Si llega a 0 afuera: desmayo (pierdes 120 min, moral y energía) y apareces en la esclusa. Al volver a la base se recarga gastando hasta 6 de oxígeno de la base.
- Aguante (correr con [Shift]): 100 + 35 por nivel; gasto 10/s corriendo, recuperación 8/s (+2 por nivel).
- Mejoras del traje y la mochila: en el banco de trabajo, solo con materiales (teclas 6–8), con minijuego de cables.

### Mejoras de estaciones (3 niveles cada una)
- Se piden con [U] frente a la estación; **solo materiales**, distintos en cada una (sin herramienta especial). Costes `[chatarra, polímero, circuitos]` por nivel en `_upg_cost`:
  O [4,3,0] [6,5,1] [8,8,3] · S [4,0,2] [6,2,4] [8,4,7] · G [6,2,0] [9,4,1] [12,6,2] · W [6,0,1] [9,2,3] [12,3,5] · R [5,0,2] [8,0,4] [12,3,6] · C [3,3,0] [5,5,1] [7,8,2].
- Efecto por nivel: la estación gasta un 10 % menos de su recurso (`STATION_DRAIN_CUT`) y rinde un 25 % más al usarla (`STATION_BOOST`).
- Obra en segundo plano a cargo de **ENOC**: 60 / 120 / 180 minutos de juego (`_build_mins`). Solo una obra a la vez; la estación no se puede usar mientras está en obra; el tiempo avanza también durmiendo. Se guarda y se carga con la partida.
- Visual: cada nivel cambia el modelo de la estación en 3D y 2D (tanques extra, paneles, lámparas, pilonas, anillos, etc.), y mientras dura la obra se ve un andamio amarillo y a ENOC martillando con chispas.
- Exterior de la base rediseñado y más grande (10 x 4 casillas en vez de 6 x 3, con módulos laterales, cúpula, marquesina en la esclusa y balizas) que **crece con las mejoras**: más paneles solares, tanques de oxígeno, invernadero en el techo, torre de agua, pilonas y anillo del escudo, y mirador.

## Alfa 0.9.8 — Interior, cámara y Diario
- Interior con texturas procedurales (int_tex.gd) según la calidad de texturas: 0 = colores lisos, 1 = 128 px, 2 = 512 px + relieve (normal map). Suelo (placas de 2 m con remaches), paredes (paneles, zócalo con franjas, rejillas, luces) y techo (placas de 1 m).
- Cámara dentro de la base limitada al volumen interior (ya no atraviesa techo ni paredes).
- Diario de exploración (tecla J): lugares visitados/estudiados con día y hora, datos de las placas leídas y estadísticas. Se guarda en la partida.
- Pruebas: solo con render por software (sin GPU real ni navegadores); textos en inglés sin revisar.

## Alfa 0.9.9 — Tutorial guiado, lectura fácil y logros
- El texto largo del "Día 0" se reemplazó por un tutorial guiado de 7 pasos que se completa jugando (moverse, cámara, hablar, estación, mochila, diario, esclusa). Se puede saltar con [N] o con el botón; se repite desde la pausa y se activa/desactiva en Opciones.
- Modo de lectura fácil (Opciones): letra más grande y diálogos partidos en frases cortas (los que llevan formato especial no se parten).
- 13 logros con insignias dibujadas por código, aviso al desbloquear y panel con [K]. Se guardan en los ajustes (valen para todas las partidas).
- Rediseño visual de cama, banco de trabajo, radio, puerta de la esclusa y trajes (solo aspecto).
- Pendiente de verificar: la radio no se vio de frente en las pruebas; sin GPU real ni navegadores; textos en inglés sin revisar.

## Alfa 0.9.10 — Trajes más suaves
- Luz de borde suave en la tela, trama de tela con costuras acolchadas (textura según calidad: lisa / 128 px / 256 px + relieve), juntas acolchadas en codos y rodillas, botas más redondeadas, mochila y antena como piezas móviles.
- Animación: suavizado independiente de los FPS, balanceo de cadera, giro del torso contra la cadera, la cabeza compensa la inclinación y la mochila y la antena se mueven con retraso.
- No se importó ningún pack de animaciones externo (ver notas de la sesión).

## Alfa 0.9.11 — Espacio
- Estrellas: destellos suaves con colores y tamaños variados (hasta 1500 según la calidad del cielo) y una Vía Láctea con polvo oscuro, todo generado por código (space_tex.gd).
- Tierra: esfera con continentes, nubes que se mueven, fase de luz, brillo del océano, atmósfera, luces de ciudades en la parte oscura y halo azul. Solo se ve desde la Luna.
- Ventanas de la base: cielo con estrellas, Vía Láctea, horizonte con colinas y la Tierra en una ventana (imagen fija, no cambia con la hora).
- Los continentes son inventados (ruido procedural), no el mapa real de la Tierra. Probado solo con render por software.

## Alfa 0.9.12 — Marte más cálido
- Sol anaranjado más intenso, cielo ocre/caramelo, luz ambiente cálida, bruma de polvo algo más densa y polvo tibio que el viento arrastra cerca del suelo (más intenso en tormentas).
- Color del suelo: se dejó rojizo-anaranjado (aprox. 72/41/27 en RGB). No está calibrado con datos de la NASA; es una elección artística. Conviene compararlo con fotos de las misiones reales antes de afirmar que es exacto.

## Alfa 0.9.12.1 — Correcciones
- Mochila: el panel ahora es más alto y el texto de ayuda queda a la izquierda, debajo de las casillas, sin cruzarse con la columna de "Equipo y mejoras".
- Al salir de la nave el jugador mira hacia afuera (de espaldas a la base). La cámara en tercera persona ya no entra en el casco: si lo atraviesa, se coloca a un lado del jugador.
- Limitación conocida: al salir, el jugador queda bajo el techo de la esclusa y desde ese lado puede taparlo un poste hasta que camine unos pasos.

### 0.9.13 Banco de trabajo (v24)
- El banco (`T`) se gira 180°: está contra la pared norte y ahora su frente (cajones) mira al jugador; el panel de herramientas queda contra la pared.
- Nueva interfaz `workbench.gd` (modo 4), parecida a la mochila: tarjetas para las 5 recetas y las 3 mejoras del equipo, panel de detalle con materiales "tienes de necesitas" (verde/rojo), tiempo y botón Fabricar/Mejorar. Teclado: flechas o [1-8], [Enter], [Esc]; ratón: clic elige, doble clic o botón fabrica.
- Corrige el viejo mapeo de teclas del menú de texto (6 apuntaba a una receta inexistente). Probado solo con capturas por software.

### 0.9.14 Tareas más ágiles (v24.1)
- `TASK_SPEED` 5 → 20 y `CRAFT_SPEED` 10 → 40 (minutos de juego por segundo real durante una tarea). Una tarea de 30 min pasa de 6 s a 1,5 s; fabricar 90 min, de 9 s a ~2,3 s. El gasto por minuto de juego no cambia, solo se acorta la espera real. Ajustable en las dos constantes de `main.gd`. Sin probar con jugadores: es un ajuste a ojo según tu comentario.

### 0.9.15 Opción de velocidad de tareas (v24.2)
- Opciones > Velocidad de las tareas: Lenta (x5/x10, la de antes), Normal (x20/x40, por defecto), Rápida (x50/x100), Muy rápida (x120/x240). Es un multiplicador (0,25 / 1 / 2,5 / 6) sobre `TASK_SPEED` y `CRAFT_SPEED`; se guarda en la configuración (`task_speed`). Solo cambia la espera real, no el gasto por minuto de juego. Verificado el cálculo de velocidades por script; la apariencia de la opción no se vio en captura.

### 0.9.16 Recogida, esclusa y fundido (v24.3)
- Recoger: el material ya no desaparece al empezar; sigue visible hasta que el astronauta lo levanta (50 % de la tarea al recoger, 80 % al picar hielo). En ese momento salen las piezas volando, el texto y el icono del HUD. Antes el material y el efecto se adelantaban y la animación seguía sola hasta el final (`fx_hold`, `_flush_fx_hold`).
- Entrar y salir de la esclusa: la pantalla se oscurece y se aclara (≈0,9 s en total), sin animación de trabajo; el ciclo de 10 min de juego se suma de golpe (`_fade_through`, `_airlock_cycle`, modo 13).
- La salida aparece 2 casillas al sur de la puerta (`ext_spawn` Y0+4): antes caía dentro de la estructura de la esclusa (marquesina y puerta).
- Probado con script y capturas por software (el fundido se vio en negro; no medí la suavidad con GPU real).

### 0.9.17 Roles de la tripulación (v24.4)
- Wilson: ingeniero y botánico. Dra. YARISBEL: médica (aplica el botiquín, avisa de comida, agua y moral; cruz blanca en el parche del traje). ENOC: técnico de sistemas (oxígeno, energía, agua; construye las obras). PAM: comandante (avisa de oxígeno, energía, escudo y moral; parche dorado). Las líneas de historia y finales se reasignaron a quien encaja con su rol. El rol se ve al mirar a cada uno ("Hablar con Dra. YARISBEL, médica").
- Los síntomas de enfermedad en los minijuegos siguen nombrando a PAM como paciente (no es un rol). Verificado solo por carga del juego, no revisé cada diálogo en pantalla.

### 0.9.18 Diálogos graciosos de ENOC (v24.5)
- ENOC suma 13 frases de humor sobre su tema (sistemas, oxígeno, energía, agua, herramientas) a las 3 que tenía; al hablar con él, cuando nada está bajo, dice una al azar. Son chistes de diseño del juego, sin datos científicos. Interpreté "tema claro" como "el tema de ENOC"; si te referías a otra cosa, dímelo. Textos en inglés sin revisar.

### 0.9.19 Controles, carga, HUD e inventario (v25)
- Controles reasignables (Opciones > Controles): 17 acciones (mover, correr, saltar, usar, mejorar, mochila, objeto en mano, mapa, diario, logros, chat, cámara, vista, silencio). Se guardan en la configuración (`[controls]`); si una tecla ya está en uso, se intercambian. Fijos: flechas, Esc, F1, F2, F3, F11, Enter y las teclas de los menús (E/Enter en diálogos). Se guardan como código de tecla físico: en teclados no QWERTY el nombre mostrado sigue la distribución del usuario (no probado en otras distribuciones).
- Clic del ratón: izquierdo = usar lo de enfrente, derecho = mejorar la estación (por defecto); cada uno se puede cambiar (usar, mejorar, saltar, mochila, objeto en mano, nada). Solo actúa jugando, sin menús abiertos.
- Pantalla de carga con consejos al empezar partida, continuar y cambiar de destino en el menú (`loading_run`). Mientras se construye el mundo la pantalla se congela (un solo hilo): la barra marca etapas, no progreso real.
- La pista de mejorar sale en una segunda línea, en dorado, debajo del texto principal.
- Cámara de salida: al cruzar la esclusa se recoloca de golpe detrás del jugador; si el casco o la marquesina estorban, sube casi encima del jugador (antes se ponía de lado).
- Chat inferior: se oculta y muestra con T. Quitados los botones F1/F2 de la esquina (las teclas y el menú de pausa siguen).
- Aviso rápido arriba al cambiar de momento: amanece/de día (06:00), de tarde (12:00), atardece (18:00), de noche (20:00) y muy de noche (00:00).
- Inventario: muñeco 3D de Wilson con su traje (como el de Minecraft), gira solo y se arrastra con el ratón. Usa otro mundo 3D en un SubViewport; no medí su costo en navegadores.

### 0.9.20 Emergencias, diagnóstico y registro de incidentes (v26)
- Archivos nuevos: `emergency_data.gd` (datos de cada emergencia), `emergency.gd` (gestor central), `diag_ui.gd` (Centro de diagnóstico, tecla H reasignable, modo 14). Estados de cada incidente: Normal, Detectada, Investigación, Diagnóstico, Intervención, Verificación, Resuelta, Fallida.
- Emergencias: fuga de oxígeno/brecha (causas: fuga real, filtro saturado, sensor defectuoso, fallo del reciclador), cortocircuito (circuito dañado, sobrecarga, paneles sucios, medidor), falla de agua (fuga física, avería del reciclador, mayor consumo, medidor), emergencia médica (usa el brote de enfermedad, el botiquín, a la Dra. YARISBEL y los casos clínicos del minijuego), llamarada solar (aviso con horas, refugiarse/reforzar escudo) y tormenta de polvo marciana (pronóstico y preparación; solo en Marte). Los micrometeoritos dañan según el estado de los equipos exteriores.
- Mantenimiento preventivo: 5 sistemas (soporte vital, eléctrico, reciclador de agua, filtros, equipos exteriores) con estado 0–100 %. Riesgo = 0,5 + 1,5·(1−estado/100) sobre las probabilidades de evento; bajo 35 % hay fallos por desgaste. Nunca baja el riesgo a cero. Cada mantenimiento cuesta 45 min y 1 chatarra o polímero. La dificultad cambia el costo de consultar, el número de hipótesis, las lecturas mínimas, los plazos y el desgaste.
- Historial persistente (`emerg` dentro de la partida; versión de guardado sigue en 2; las partidas v25 con brecha o enfermedad se migran a incidentes al cargar). Informe educativo de 5 bloques que cambia según tus acciones.
- Simplificaciones (son de juego, no datos medidos): presión normal 98–103 kPa, CO₂ 0,3 % vs 0,9 %, porcentajes de carga de red, tiempos de aviso de llamarada y tormenta, y la fracción de daño evitado al refugiarse (25 %) o reforzar (60 %). Los ejemplos reales mencionados (agua reciclada en la ISS, tormenta global de 2018 y el rover Opportunity) son conocimiento general que no verifiqué de nuevo contra una fuente en esta versión: conviene revisarlos. La emergencia médica no es una simulación clínica profesional. Textos en inglés sin revisión humana.
- Límites: con la dificultad Extremo la causa "fallo eléctrico" ofrece 4 hipótesis (solo hay 4 causas definidas, aunque la tabla pide 5). El balance real de dificultad con jugadores no está probado.


## v27 — Rediseño visual (sistema de diseño, interfaces, mundo 3D)

**Sistema de diseño** (`design_system.gd`): paleta (azul noche, azul petróleo, grafito, blanco cálido, cian solo como acento, verde/ámbar/rojo para estados), espaciado, radios, tipografía Inter (4 tamaños base), 22 iconos SVG propios dibujados por código (sin dependencias externas), tema central `DS.make_theme()`.

**Módulos nuevos:** `design_system.gd`, `hud_ui.gd` (HUD compacto), `menu_art.gd` (planetas y paisajes procedurales con FastNoiseLite). `main.gd` solo orquesta.

**Pantallas rediseñadas:** menú, selección de misión/dificultad (tarjetas Luna/Marte), HUD, diálogos como comunicación de misión, mochila, banco de trabajo, diario, mapa (etiquetas con fondo, indicador de posición), logros, centro de diagnóstico (datos reales del juego), pausa.

**Mundo 3D:** gradación de color por mundo (Marte menos saturado y con más contraste; Luna neutra) con `Environment.adjustment_*`. La iluminación diferenciada Luna/Marte, materiales, partículas y presets de calidad ya existían y se conservaron.

**Licencias:** fuente Inter (SIL Open Font License 1.1, subconjunto latino en `fonts/`). Arte y audio generados por código; sin logotipos de la NASA.

**Datos de las tarjetas de misión (aproximados, "≈"):** Luna: gravedad 1,62 m/s², temperatura ecuatorial ~95–390 K; Marte: gravedad 3,73 m/s², presión ~6,36 mb (~0,6 % de la terrestre), temperatura media ~−59 °C. Fuentes: https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html y https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html. Verifique en la fuente primaria antes de citar.

**Límites conocidos:** el rendimiento real en GPU/navegador de usuarios no se midió (solo pruebas en renderizador por software); no se hicieron nuevos modelos 3D ni normal maps; el control táctil no se probó; la revisión del texto en inglés es automática de cobertura (0 claves sin traducir), no una revisión humana.


## v28 — Gráficos: mundo 3D, tripulación, pantallas con DS y microinteracciones

Solo cambia el **dibujo**: la lógica del juego no se tocó (ver «Verificación»). Todo el arte nuevo está generado por código; sin modelos, imágenes ni sonidos externos y sin logotipos de la NASA.

**Módulos nuevos** (main.gd no crece: pasa de 6.147 a ~6.080 líneas porque la pantalla de final se movió a un módulo):
- `terrain3d.gd`: terreno subdividido (2 vértices por casilla = cada 1 m en calidad Media/Alta; 1 por casilla en Baja), en bloques de 24×24 casillas para descartar lo que no se ve. Cráteres con perfil continuo (antes escalonado por casilla). Rocas facetadas (`rock_mesh`): en la Luna más redondeadas, en Marte más planas y angulosas.
- `world_look.gd`: luz, sombras y gradación de cada mundo. Luna: cielo negro, sol blanco y duro, sombras nítidas, casi sin luz de relleno y sin niebla. Marte: luz cálida más difusa, sombras más suaves, bruma y color tierra/óxido menos saturado.
- `base_look.gd`: casco de la base con paneles, juntas y remaches (textura + relieve procedural, triplanar), plataforma de aterrizaje, cables por el suelo, equipo junto al muro y bandera de la misión (diseño propio con colores de la paleta, sin logotipos).
- `world_fx.gd`: polvo al caminar, nube al aterrizar de un salto y destellos suaves sobre el hielo (solo con luz de sol; desactivados en calidad Baja).
- `crew_look.gd`: materiales de los trajes (casco duro brillante, visor dorado reflectante, rodamientos metálicos, franjas de color por astronauta).
- `ui_screens.gd`: Cómo jugar (teclas agrupadas), Créditos (tarjetas), lista de Finales (progreso y tarjetas) y pantalla de final de partida, con el sistema de diseño.
- `ui_motion.gd`: microinteracciones (hover y pulsación de botones, fundido corto de paneles).
- `tests/t_ui.gd`, `tests/t_logic.gd`, `tests/t_perf.gd`, `tools/shots_all.sh`: herramientas de prueba (ver «Verificación»).

**Decisiones artísticas (NO son datos medidos):**
- Luna y Marte: colores de luz, cantidad de luz ambiente, exposición, desenfoque de sombras y gradación (`world_look.gd`). El suelo de Marte en 3D se oscurece y desatura un poco respecto al color de zona (tono tierra/óxido); no está calibrado con fotos de las misiones.
- El arco del sol en 3D es más lateral (este-oeste) y algo más bajo (máx. ~40° en la Luna, ~38° en Marte) para que las sombras crucen la vista y den relieve. No representa la posición real del Sol en ningún lugar concreto.
- Dunas de Marte (orientadas con el mismo viento que el polvo), "mares" oscuros y eyecciones claras alrededor de algunos cráteres de la Luna, cráteres secundarios (~150 en la Luna, ~40 en Marte) y microcráteres solo en la textura: formas y cantidades de juego, no un mapa real.
- La bandera no ondea en la Luna (no hay aire que la mueva; queda tensada por una barra). Es conocimiento general que no verifiqué con una fuente en esta sesión.

**Física usada en las partículas** (valores ya citados en «Alfa 0.9.4»): el polvo de los pasos cae con la gravedad de cada mundo — Luna 1,62 m/s² (nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html) y Marte 3,73 m/s² (nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html). En la Luna no hay frenado del aire (el polvo sale en arcos y cae); en Marte se frena y lo arrastra el viento. La forma, la cantidad y el frenado son de juego.

**Correcciones de fallos anteriores encontrados al revisar:**
- El sprite de polvo de Marte se veía como cuadrados: `glow_sprite(32, 0.0)` usa `smoothstep(0, 0, d)`, que vale 1 en casi todo el sprite. Ahora se usa un núcleo de 0,02. El polvo ya no va pegado a la cámara sino alrededor del jugador.
- La noche lunar era azul intenso; ahora la luz de la Tierra y el ambiente nocturno son más neutros.
- Ventanas, balizas, LEDs de los trajes, visor y franjas de la esclusa emitían demasiado (efecto neón): emisión reducida.
- Remaches del suelo interior casi blancos (mucho ruido): ahora discretos.
- Opciones: el panel no cabía en pantallas bajas (el botón «Cerrar» quedaba fuera); la pestaña Pantalla ahora se desplaza.
- Faltaban 58 traducciones al inglés (p. ej. «Día %d / %d», roles de los hablantes, tarjetas de destino de «Nueva misión», banco de trabajo y mochila). Añadidas en `lang_en.gd`. Siguen sin revisión de una persona nativa.

**Verificación (Godot 4.4.1, render por software con xvfb y SwiftShader; sin GPU real):**
- `tests/t_emg.gd` (94 pruebas) **no está en el repositorio** ni en los zips de `releases/`, así que no se pudo ejecutar. En su lugar, `tests/t_logic.gd` simula 16 partidas con semilla fija (Luna/Marte × 4 dificultades × con y sin reposición de recursos, 8 días) y escribe una huella del estado cada hora de juego (recursos, día, reloj, inventario, herramientas, tormenta, enfermedad, brecha y el historial completo de emergencias). Huella del código original (commit ead1d75) y de v28: idénticas (md5 `9d5ba3a6…`, 1.722 líneas). Esto comprueba que la lógica no cambió en esos recorridos; no sustituye a las 94 pruebas originales.
- Capturas antes/después a 1920×1080, 1366×768 y 1024×600 (`tests/t_ui.gd` + `tools/shots_all.sh`).
- Exportación web (preset «Web», sin hilos) y prueba en Chromium con Playwright: carga en ~11 s (servidor local, render por software), fuente Inter e iconos SVG visibles, páginas del menú correctas. En la consola aparecen errores `keyboard_get_keycode_from_physical: Not supported by this display server` que vienen de los nombres de tecla de los controles reasignables (v25), no de v28; no impiden jugar.
- Coste medido con `tests/t_perf.gd` (render por software, cifras solo relativas), exterior junto a la base, 1280×720:
  - Alta: primitivas visibles Luna ~150 k → ~202 k (+35 %), Marte ~147 k → ~179 k (+22 %); llamadas de dibujo ~580 → ~673 (+16 %); primitivas de sombra +3 %.
  - Baja: primitivas casi iguales (~103 k → ~106 k Luna); llamadas de dibujo ~290 → ~350 (bloques de terreno y piedras sueltas).
  - Crear la partida: Luna Alta ~160 → ~270 ms; Marte Alta ~1,0 → ~1,1 s (en este equipo; en el navegador será más lento).

**No medido / pendiente:** rendimiento en GPU real y en PCs escolares o tabletas; control táctil; navegadores distintos de Chromium; revisión humana del inglés; si la calidad automática baja de escalón antes por el coste extra en equipos lentos. La forma de las rocas y la resolución del terreno se aplican al empezar una misión nueva (como antes).
