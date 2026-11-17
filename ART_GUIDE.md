# Guía de arte: qué generar e importar (Ludo.ai u otra herramienta)

Los archivos se copian tal cual a `art/3d/` y `art/icons/` con los NOMBRES EXACTOS de abajo.
Si falta alguno, el juego usa el modelo dibujado por código. Abre el proyecto en Godot para que los importe.

## 1. Modelos 3D (.glb) -> carpeta `art/3d/`
Formato recomendado: **GLB** (incluye texturas PBR). Los OBJ/STL/PLY no llevan texturas.
El juego normaliza el modelo: lo centra, lo apoya en el suelo y lo escala para que su dimensión MAYOR mida el tamaño indicado.
Conviene un modelo ligero (idealmente menos de ~5.000 triángulos en los recolectables, porque en el mapa hay cientos).

| Archivo                  | Qué es                                                   | Tamaño mayor | Cantidad en el mapa (Luna / Marte) |
|--------------------------|----------------------------------------------------------|--------------|------------------------------------|
| material_scrap.glb       | Chatarra metálica (da 2 chatarra)                        | 1,3 m        | 230 / 207                          |
| material_crate.glb       | Caja de cargamento (da 1 polímero + 1 circuitos)         | 1,35 m       | 40 / 51                            |
| material_ice.glb         | Cristales de hielo de agua (da 10 de agua)               | 1,7 m        | 67 / 149                           |
| station_O.glb            | Soporte vital (tanque de oxígeno)                        | 2,8 m        | 1                                  |
| station_S.glb            | Panel solar                                              | 2,5 m        | 1                                  |
| station_G.glb            | Invernadero                                              | 2,1 m        | 1                                  |
| station_W.glb            | Reciclador de agua                                       | 2,2 m        | 1                                  |
| station_R.glb            | Generador del escudo anti-radiación                      | 2,3 m        | 1                                  |
| station_C.glb            | Zona de descanso (sofá)                                  | 1,9 m        | 1                                  |
| station_B.glb            | Cama                                                     | 2,5 m        | 1                                  |
| station_T.glb            | Banco de trabajo                                         | 1,9 m        | 1                                  |
| station_A.glb            | Radio / antena                                           | 2,3 m        | 1                                  |
| station_D.glb            | Esclusa (puerta exterior)                                | 3,4 m        | 1                                  |

Notas:
- Los modelos importados reemplazan por completo al modelo de código. Las animaciones/luces propias del modelo de código (por ejemplo el anillo giratorio del escudo) no se aplican a un modelo importado.
- Orientación: no giro los modelos. Si alguno queda de espaldas a donde debería mirar, avísame y lo roto en código.
- Los materiales recolectables se ocultan al recogerlos y reaparecen a los 5 días, igual que ahora.

## 2. Iconos 2D (.png) -> carpeta `art/icons/`
PNG con fondo transparente, cuadrados, recomendado 128x128 (se muestran a ~22 px en el HUD, así que deben leerse bien muy pequeños: silueta clara, pocos detalles).

| Archivo        | Qué es                                  |
|----------------|-----------------------------------------|
| scrap.png      | Chatarra                                |
| polymer.png    | Polímero                                |
| circuits.png   | Circuitos                               |
| patch.png      | Kit de parche                           |
| medkit.png     | Botiquín                                |
| repair.png     | Reparador de circuitos                  |
| filter.png     | Filtro de polvo                         |
| map.png        | Mapa de navegación                      |

## 3. Personajes
v39: el astronauta se modela en Blender con `tools/blender/astronaut.py` -> `art/3d/astronaut.glb`. No usa esqueleto: cada pieza cuelga de un nodo con el nombre de su articulación (rig, body, head, pack, ant, arm_l, elb_l, arm_r, elb_r, leg_l, kn_l, leg_r, kn_r), y las acciones (trabajar, fabricar, recoger, hablar, correr...) siguen animándose por código.
Las estaciones del interior se modelan con `tools/blender/stations.py` -> `art/3d/base/station_X.glb` (conservan sus animaciones). Un `art/3d/station_X.glb` (Ludo.ai u otro) sigue teniendo prioridad, pero pierde las animaciones.

## Consejos para que todo se vea coherente
- Usa el mismo estilo (por ejemplo "low poly, estilo caricatura, colores limpios") y la misma paleta en todas las generaciones.
- Revisa los términos y licencia de uso de la herramienta (Ludo.ai u otra) antes de entregar el proyecto: no pude comprobar las condiciones de uso comercial/escolar.
