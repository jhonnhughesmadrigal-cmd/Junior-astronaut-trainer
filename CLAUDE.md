# Misión Perseo — guía para Claude Code

Juego educativo 3D (Godot 4.4.1, GDScript, export web) para niños de 7–12 años, NASA Space Apps.
Wilson mantiene vivos a 4 tripulantes 30 días en la Luna o Marte. Español/inglés. Arte y audio generados por código.

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
- Capturas: copia `tests/t_ui.gd` a la raíz y usa `tools/shot.sh 1280x720 menu new hud_mars out_moon out_mars pack bench map pause diag` (salida en /tmp/shots), o en paralelo `JOBS=3 tools/shots_all.sh <carpeta> 1920x1080 <estados...>`. Estados extra: stc_O stc_S stc_R stc_C stc_T stc_A stc_D (estaciones con cámara fija), hud_lv3, opts credits howto endings end_win end_lose hud_moon crew_moon far_moon far_mars out_moon_low out_mars_low night_moon storm_mars ach.
- Misiones de clase (debe dar 75/75): copia `tests/t_lessons.gd` a la raíz y ejecuta `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_lessons.gd` (también con `LANG_CODE=en`). Al añadir una misión, regenera la guía docente.
- Táctil (debe dar 22/22): `tests/t_touch.gd`.
- Minijuegos del banco (debe dar 14/14): `tests/t_minigames.gd`. Capturas: estados `mg_patch mg_filter mg_map`. Capturas con controles táctiles: `TOUCH=1` en `tools/shots_all.sh`; escala de interfaz simulada: `UI_SCALE=1.25`.
- Coste relativo: `tests/t_perf.gd` (primitivas y llamadas de dibujo; `LOC=Luna Q=2`).
- Web: `godot --headless --import`, luego `--export-release Web web/index.html`, servir con HTTP y revisar con Playwright (verificar fuentes e iconos SVG).
- El viewport del proyecto es 1100×650 (canvas_items, aspect expand): comprobar 1920×1080, 1600×900, 1366×768, 1280×720 y 1024×600.

## Trabajo visual
Hecho en v27: sistema de diseño, menú, selección de misión, HUD, diálogos, mochila, banco, diario, logros, mapa, pausa, gradación de color por mundo.
Hecho en v28 (ver DATOS.md): terreno subdividido (`terrain3d.gd`), luz por mundo (`world_look.gd`), casco y detalles de la base (`base_look.gd`), partículas (`world_fx.gd`), trajes (`crew_look.gd`), Cómo jugar/Créditos/Finales/pantalla de final con DS (`ui_screens.gd`), microinteracciones (`ui_motion.gd`).
Hecho en v29: Misiones de clase (9 lecciones, menú docente, cuestionario, resumen con fuentes).
Pendiente:
0. Hecho en v30–v31: control táctil e interfaz adaptable a móviles. Pendiente: textos de paneles que nombran teclas, prueba en dispositivos reales, más misiones y pruebas con alumnos.
1. Verificar táctil, rendimiento real en GPU/navegador y revisión humana del inglés (nada de esto está medido).
2. Interior de la base: mismo nivel de materiales que el exterior (solo se retocaron remaches y color del suelo).
3. Personajes: siguen hechos con primitivas; un modelo por piezas más orgánico mejoraría los primeros planos.
4. Recuperar `tests/t_emg.gd` (94 pruebas).
Criterio: menos ruido visual, mejores materiales, más profundidad, identidad consistente; sin neón ni efectos recargados.

## Skills útiles
Si tu instalación de Claude Code tiene skills de diseño visual/frontend (p. ej. una de dirección estética o de arte/3D), úsalas para el punto 1–4. Comprueba con `/skills` cuáles existen realmente; no asumas nombres.
