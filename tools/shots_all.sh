#!/bin/bash
# Lanza varias capturas en paralelo. Uso: tools/shots_all.sh <dir_salida> <RES> estado1 estado2 ...
# Requiere t_ui.gd en la raiz (cp tests/t_ui.gd .), Godot 4.4.1 (variable GODOT) y xvfb.
G=${GODOT:-godot}
OUT=$1; shift; R=$1; shift
mkdir -p "$OUT"
J=${JOBS:-4}
for s in "$@"; do
  ( RES=$R SHOTS=$s SHOT_DIR=$OUT xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --rendering-driver opengl3 --script res://t_ui.gd 2>&1 | grep -iE "script error|parse error|   at: res|^captura" | head -4 ) &
  while [ "$(jobs -r | wc -l)" -ge "$J" ]; do wait -n; done
done
wait
