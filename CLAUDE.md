# Misión Perseo — guía para Claude Code

Juego educativo 3D (Godot 4.7.2 desde v39, GDScript, export web) para niños de 7–12 años, NASA Space Apps.
Zadiel mantiene vivos a 4 tripulantes 30 días en la Luna o Marte. Español/inglés. Arte y audio generados por código.

## Reglas del proyecto (del dueño)
- La verdad y la precisión van antes que ser útil. No inventes fuentes, cifras ni nombres de API; si dudas, di que hay que verificar. Datos de la NASA: marcar como aproximados ("≈") y citar la ficha real (nssdc.gsfc.nasa.gov/planetary/factsheet).
- Responder en español.
- Tras cada cambio: regenerar el zip web y el zip del proyecto, y hacer commit en `releases/`.
- Todo texto visible usa `Lang.t("texto en español")`; el inglés va en `lang_en.gd` con la misma clave exacta.
- Sin logotipos de la NASA. Arte/audio originales o con licencia documentada (Inter: SIL OFL 1.1).
- No inflar `main.gd`: componentes nuevos en módulos propios.

## Estructura clave
- `design_system.gd` (DS): paleta, espaciado, radios, fuentes Inter, iconos SVG por código, `DS.make_theme()`. Toda UI nueva debe usar DS.
- `hud_ui.gd`, `menu_art.gd` (planetas/paisajes procedurales), `ui_pages.gd` (menú, misión, opciones), `backpack.gd`, `workbench.gd`, `tutor.gd`, `diag_ui.gd`.
- `view3d.gd`: mundo 3D (iluminación, terreno, base, personajes, partículas, presets de calidad Bajo/Medio/Alto). `ext_tex.gd` / `int_tex.gd` / `space_tex.gd`: texturas procedurales. v28: `terrain3d.gd`, `world_look.gd`, `base_look.gd`, `world_fx.gd`, `crew_look.gd`.
- `ui_screens.gd` (pantallas con DS) y `ui_motion.gd` (microinteracciones).
- v30 `touch_ui.gd`: controles táctiles; simulan las teclas de `binds` con `Input.parse_input_event` (no tocar `main.gd` para el táctil).
- v39 Modelos de Blender: `tools/blender/` (`bkit.py` utilidades, `astronaut.py`, `stations.py`; se ejecutan con `blender --background --factory-startup --python tools/blender/<script>.py -- <salida>`). Generan `art/3d/astronaut.glb` y `art/3d/base/station_X.glb` (O S G W R C B T A D). `crew_model.gd` carga el astronauta (mismas articulaciones que `_make_astronaut`: las poses por código no cambian; los materiales se sustituyen por nombre, así el color de rol sigue en `crew_look.gd`). `station_art.gd` carga las estaciones (`_build_glb`): nodos `anim_*` y materiales `screen_*`, `core`, `led_*`, `shield_band`, `glass`, `water`, `solar_cell` (ver cabecera de `stations.py`). Las estaciones reaccionan mientras Zadiel las usa (modo 5) y destellan al terminar. Si falta un `.glb`, se usa el modelo por código.
- v41 Eventos visibles: `event_fx.gd` (hijo de view3d; efectos persistentes segun el estado —brecha, tormenta, erupcion, fugas, apagon, enfermo—, poses de evento via `crew_poses.gd`, bocadillos con frases de `event_lines.gd`, velos de pantalla en una capa al principio de `map_view`), `cinema.gd` (cinematicas: modo 16 = reloj detenido; `view3d.cine_out` muestra exterior/interior; se saltan con E/Esc). main.gd solo llama `_efx("tipo")` en cada evento. Salto y recogida: animaciones de Blender (`tools/blender/anims.py` → `art/3d/anim/`, `crew_anims.gd`). Finales: `ending_cine.gd` (escena 3D en vivo con el mundo de la partida; nave `art/3d/fx/rescue_ship.glb`). Sonidos: `tools/gen_sfx_events.py`. Ver DATOS.md v41.
- v40 Exterior de Blender: `tools/blender/collectables.py` → `art/3d/material_{scrap,crate,ice}.glb` (los coloca `collect_glb.gd` con `ChunkMM`; materiales `rock_tint` = color de la zona, `led`, `*_vc` = color por vértice); `tools/blender/landmarks.py` → `art/3d/ext/landmark_{apollo,rover,plaque,wreck}.glb` y `airlock_ext.glb` (los carga `ext_art.gd`). `ExtArt.merge_static` fusiona por material las piezas fijas del exterior (164 → 36). Si falta un `.glb`, modelo por código. Ver DATOS.md v40.
- v38 `interior_look.gd`: estructura, tuberías, equipo de pared, luces del interior y `merge_static` (fusiona piezas fijas por material: menos llamadas de dibujo). Parte alta de los muros bajos solo en cámaras cercanas (nodo del techo).
- v37 Android: preset «Android» en `export_presets.cfg` (paquete `com.misionperseo.juego`), `mobile_os.gd` (botón «Atrás» = Esc, guardar en segundo plano), icono `art/app/` (`tools/gen_icon.gd`). Guía: `docs/ANDROID_APK.md`. La clave de firma de release NO está en el repo (se pasa con `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`). Privacidad: `docs/PRIVACIDAD.md` (borrador para la escuela).
- v36 Firebase: `firebase.gd` (REST: Auth + Firestore), `firebase_config.gd` (API_KEY/PROJECT_ID vacíos = modo local), `firebase/firestore.rules`. Guía: `docs/FIREBASE_SETUP.md`. Admin = documento `admins/{uid}` creado a mano. Emulador: `cd firebase && npx firebase-tools emulators:start --only auth,firestore --project demo-mision-perseo` y `FIREBASE_EMULATOR=127.0.0.1`.
- v35 perfiles: `profiles.gd` (educativa estudiante/docente, personal, invitado; guardado por perfil vía `main.SAVE_PATH`; clases con código `PER-XXXX` sin servidor) y `profile_ui.gd`. Verificar correos, avisar al admin y sincronizar entre dispositivos NECESITA servidor (no hecho; ver DATOS.md v35).
- v34 `item_icons.gd`: iconos SVG de materiales y herramientas (estilo de la referencia de Ludo.ai); los usa `inv_icons.gd` si no hay PNG en `art/icons/`.
- v33 `station_art.gd`: estaciones O, S, R, C, T, A, D con el estilo de la referencia de Ludo.ai (por código) y sus animaciones (`animate()`, llamado desde `view3d._update_props`). Un `.glb` en `art/3d/station_X.glb` sigue teniendo prioridad.
- v32 `mg_new.gd`: minijuegos del banco «Sellar la fuga» (parche), «Capas del filtro» (filtro) y «Rompecabezas orbital» (mapa); `minigames.gd` los delega por `kind`.
- v31 `ui_fit.gd`: escala automática en móviles, encaje de paneles que no caben, aviso de girar. Ojo: en xvfb la ventana no pasa de 1280×720; para simular un móvil usa `TOUCH=1 UI_SCALE=1.35` a 1280x720 (lienzo 856×481).
- v29 Misiones de clase: `lesson_data.gd` (catálogo, solo datos verificados con fuente), `lessons.gd` (motor; tiempo detenido y sin guardar), `lesson_ui.gd` (página del menú). Guía docente generada: `godot --headless --path . --script res://tools/gen_guia.gd` → `docs/GUIA_DOCENTE.md`.
- `main.gd`: orquestador; modos de juego 0 juego, 1 diálogo, 2 sueño, 3 pausa, 4 banco, 5 tarea, 6 mapa, 7 minijuego, 8 info, 9 mejora, 10 mochila, 11 diario, 12 logros, 13 fundido, 14 diagnóstico.
- `emergency*.gd`: sistema de emergencias (v26). `DATOS.md`: datos, fuentes y límites.

## Cómo probar
- Sintaxis: `godot --headless --check-only --script res://main.gd --path .`
- Lógica (debe dar 94/94): copia `tests/t_emg.gd` a la raíz y ejecuta `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_emg.gd`. **Ojo (v28): `tests/t_emg.gd` no está en el repositorio**; hay que recuperarlo de quien lo tenga.
- Huella de lógica (v28): copia `tests/t_logic.gd` a la raíz y ejecuta `LOGIC_OUT=/tmp/l.txt xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_logic.gd`. Compara el md5 ("HUELLA") con el del commit anterior: si la lógica no cambia, debe coincidir (v28: `9d5ba3a6…`).
- Capturas: copia `tests/t_ui.gd` a la raíz y usa `tools/shot.sh 1280x720 menu new hud_mars out_moon out_mars pack bench map pause diag` (salida en /tmp/shots), o en paralelo `JOBS=3 tools/shots_all.sh <carpeta> 1920x1080 <estados...>`. Estados extra: stc_O stc_S stc_R stc_C stc_T stc_A stc_D (estaciones con cámara fija), hud_lv3, opts credits howto endings end_win end_lose hud_moon crew_moon far_moon far_mars out_moon_low out_mars_low night_moon storm_mars ach; v40: lm_apollo lm_plaque lm_wreck lm_rover base_moon base_mars (puntos de interés y base desde fuera). `t_ui` activa la vista 3D solo en memoria (`VIEW3D=0` para no hacerlo).
- Misiones de clase (debe dar 75/75): copia `tests/t_lessons.gd` a la raíz y ejecuta `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_lessons.gd` (también con `LANG_CODE=en`). Al añadir una misión, regenera la guía docente.
- Táctil (debe dar 22/22): `tests/t_touch.gd`. v40: ya no depende de los ajustes guardados (vista 3D solo en memoria) ni de los FPS (aterriza a Zadiel antes de probar la mochila).
- Eventos v41 (debe dar 82/82): `tests/t_events.gd` (recursos, animaciones, poses, traducciones de las frases, cada evento, cinematica que congela el reloj/se salta/termina sola, los 11 finales en 3D). Capturas: estados `ev_meteor ev_breach ev_breach_out ev_sick ev_flare ev_power ev_harvest ev_micro ev_jump` (Luna), `ev_storm ev_storm_in ev_storm_cine` (Marte) con `EV_FRAME=<fotograma>`; finales con `END_ID=<final> EV_FRAME=<fotograma>` y estado `end_win`.
- Exterior v40 (debe dar 26/26, también con `LOC=Marte`): `tests/t_exterior.gd` (modelos, recoger/reaparecer con `.glb`, tinte de zona, puntos de interés, esclusa, fusión, firma de imágenes de `nasa_data`).
- Modelos de Blender (debe dar 32/32): `tests/t_stations.gd` (carga, piezas animables y reacción de cada estación al usarla).
- Móvil/Android (debe dar 14/14): `tests/t_mobile.gd`. APK: `godot --headless --path . --export-debug Android build/x.apk` y `apksigner verify` (SDK en `~/android-sdk`).
- Firebase con emulador (deben dar 26/26 y 14/14): `FIREBASE_EMULATOR=127.0.0.1` + `tests/t_firebase.gd` (headless) y `tests/t_fbflow.gd` (xvfb).
- Perfiles (debe dar 19/19): `tests/t_profiles.gd` (borra `user://profiles.cfg`). Capturas: `prof_choose prof_email prof_role prof_teacher prof_student prof_newclass prof_lessons`.
- Minijuegos del banco (debe dar 14/14): `tests/t_minigames.gd`. Capturas: estados `mg_patch mg_filter mg_map`. Capturas con controles táctiles: `TOUCH=1` en `tools/shots_all.sh`; escala de interfaz simulada: `UI_SCALE=1.25`.
- Coste relativo: `tests/t_perf.gd` (primitivas, llamadas de dibujo y recuento de la escena; `LOC=Luna Q=2`, `INSIDE=1` dentro de la base, `SNAP=/ruta.png` guarda lo que ve). v40: no depende de los ajustes (vista 3D y cámara fija en memoria), dentro mira el interior de verdad y fuera mira a la base. v40 Luna: fuera 227/234/239 llamadas (v39: 348/359/364), dentro 331/813/898 (Q=0/1/2). Las cifras anteriores a v40 se tomaron con la prueba antigua y no son comparables.
- macOS (sin xvfb): las pruebas y capturas funcionan igual quitando `xvfb-run -a`; abren una ventana. Las capturas salen al doble de tamaño en pantallas Retina.
- Web: `godot --headless --import`, luego `--export-release Web web/index.html`, servir con HTTP y revisar con Playwright (verificar fuentes e iconos SVG).
- El viewport del proyecto es 1100×650 (canvas_items, aspect expand): comprobar 1920×1080, 1600×900, 1366×768, 1280×720 y 1024×600.

## Trabajo visual
Hecho en v27: sistema de diseño, menú, selección de misión, HUD, diálogos, mochila, banco, diario, logros, mapa, pausa, gradación de color por mundo.
Hecho en v28 (ver DATOS.md): terreno subdividido (`terrain3d.gd`), luz por mundo (`world_look.gd`), casco y detalles de la base (`base_look.gd`), partículas (`world_fx.gd`), trajes (`crew_look.gd`), Cómo jugar/Créditos/Finales/pantalla de final con DS (`ui_screens.gd`), microinteracciones (`ui_motion.gd`).
Hecho en v29: Misiones de clase (9 lecciones, menú docente, cuestionario, resumen con fuentes).
Pendiente:
0. Hecho en v30–v31: control táctil e interfaz adaptable a móviles. Pendiente: textos de paneles que nombran teclas, prueba en dispositivos reales, más misiones y pruebas con alumnos.
1. Verificar táctil, rendimiento real en GPU/navegador y revisión humana del inglés (nada de esto está medido).
2. Hecho en v38: interior de la base (ver DATOS.md v38). Pendiente: medir en tabletas reales el coste de sus 5 luces.
3. Hecho en v39: astronauta y estaciones modelados en Blender (ver arriba). Pendiente: medir en tabletas reales; personajes sin rostro (casco con visor opaco, a propósito).
3b. Hecho en v40: recolectables, puntos de interés y esclusa exterior en Blender; exterior fusionado por material (−35 % llamadas fuera). Probado en Chrome (zip web). v41: eventos visibles, cinemáticas, salto/recogida de Blender y finales 3D. Pendiente: casco de la base en Blender (hoy solo fusionado), rocas/relieve (siguen por código), Safari/Firefox y medir FPS en tabletas.
4. Recuperar `tests/t_emg.gd` (94 pruebas).
Criterio: menos ruido visual, mejores materiales, más profundidad, identidad consistente; sin neón ni efectos recargados.

## Skills útiles
Si tu instalación de Claude Code tiene skills de diseño visual/frontend (p. ej. una de dirección estética o de arte/3D), úsalas para el punto 1–4. Comprueba con `/skills` cuáles existen realmente; no asumas nombres.
