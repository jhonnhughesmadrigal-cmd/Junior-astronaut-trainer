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
- `view3d.gd`: mundo 3D (iluminación, terreno, base, personajes, partículas, presets de calidad Bajo/Medio/Alto). `ext_tex.gd` / `int_tex.gd` / `space_tex.gd`: texturas procedurales.
- `main.gd`: orquestador; modos de juego 0 juego, 1 diálogo, 2 sueño, 3 pausa, 4 banco, 5 tarea, 6 mapa, 7 minijuego, 8 info, 9 mejora, 10 mochila, 11 diario, 12 logros, 13 fundido, 14 diagnóstico.
- `emergency*.gd`: sistema de emergencias (v26). `DATOS.md`: datos, fuentes y límites.

## Cómo probar
- Sintaxis: `godot --headless --check-only --script res://main.gd --path .`
- Lógica (debe dar 94/94): copia `tests/t_emg.gd` a la raíz y ejecuta `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://t_emg.gd`
- Capturas: copia `tests/t_ui.gd` a la raíz y usa `tools/shot.sh 1280x720 menu new hud_mars out_moon out_mars pack bench map pause diag`.
- Web: `godot --headless --import`, luego `--export-release Web web/index.html`, servir con HTTP y revisar con Playwright (verificar fuentes e iconos SVG).
- El viewport del proyecto es 1100×650 (canvas_items, aspect expand): comprobar 1920×1080, 1600×900, 1366×768, 1280×720 y 1024×600.

## Trabajo visual pendiente (prioridad)
Hecho en v27: sistema de diseño, menú, selección de misión, HUD, diálogos, mochila, banco, diario, logros, mapa, pausa, gradación de color por mundo.
Pendiente, sin hacer:
1. **Mundo 3D (lo más importante):** terreno con más relieve y variación (regolito/cráteres/rocas en la Luna; suelo rojo, dunas y profundidad en Marte), materiales con rugosidad/metal/normal, detalles de la base, objetos, partículas discretas (polvo, destellos), iluminación y sombras mejores. Límite: renderer Compatibility y web; mantener los presets de calidad funcionando.
2. Personajes (mantener a Wilson, YARISBEL, ENOC y PAM): mejor modelado/materiales.
3. Rediseñar opciones, créditos, cómo jugar y pantallas de finales con DS.
4. Microinteracciones y animaciones (hover, transiciones, desbloqueo de logros).
5. Verificar táctil, rendimiento real en GPU/navegador y revisión humana del inglés (nada de esto está medido).
Criterio: menos ruido visual, mejores materiales, más profundidad, identidad consistente; sin neón ni efectos recargados.

## Skills útiles
Si tu instalación de Claude Code tiene skills de diseño visual/frontend (p. ej. una de dirección estética o de arte/3D), úsalas para el punto 1–4. Comprueba con `/skills` cuáles existen realmente; no asumas nombres.
