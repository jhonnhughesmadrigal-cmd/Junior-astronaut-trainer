#!/bin/bash
# Capturas de pantalla de la UI/3D con el renderizador por software.
# Uso: tools/shot.sh 1280x720 menu new hud_mars out_moon out_mars pack bench map pause diag
# Requiere: Godot 4.4.1 (variable GODOT) y xvfb. Salida: /tmp/shots/<estado>_<RES>.png
# Antes: copia tests/t_ui.gd a la raiz del proyecto (los t_*.gd no van en el export).
G=${GODOT:-godot}
R=$1; shift
for s in "$@"; do
  RES=$R SHOTS=$s xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --rendering-driver opengl3 --script res://t_ui.gd 2>&1 | grep -i "script error\|   at: res" | head -3
done
