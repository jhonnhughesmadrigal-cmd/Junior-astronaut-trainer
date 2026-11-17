# Misión Perseo — Prompts para generar arte con Ludo.ai (u otra herramienta)

Lista preparada en v32. Los nombres de archivo y tamaños salen de `ART_GUIDE.md`: si el archivo existe en `art/3d/` o `art/icons/`, el juego lo usa en lugar del modelo hecho por código; si no, sigue con el de código.

**Antes de empezar (no lo pude verificar yo):** revisa en Ludo.ai qué formatos exporta (lo ideal es **GLB** para 3D y **PNG con fondo transparente** para iconos) y sus condiciones de uso para un proyecto escolar o de concurso. Cuando lo sepas, hay que anotarlo en `DATOS.md` (licencia de los recursos).

Los prompts están en inglés porque estas herramientas suelen entenderlo mejor; debajo de cada uno va qué es en español.

## 1. Estilo común (añádelo al final de TODOS los prompts 3D)

```
Style: stylized low-poly game asset, clean shapes, matte PBR materials, soft realistic proportions, color palette of warm white, graphite grey and muted amber accents, no logos, no text, no flags of real countries, no NASA insignia, single object centered on a neutral background, front view facing the camera.
```

Para que todo se vea coherente: genera todos los objetos en la misma sesión, con el mismo estilo, y descarta los que salgan con brillos de neón o muchos colores saturados (el juego busca un aspecto sobrio).

## 2. Modelos que el juego ya sabe cargar (sin tocar código) → `art/3d/`

El juego centra el modelo, lo apoya en el suelo y lo escala para que su lado mayor mida el tamaño indicado. No lo gira: si queda de espaldas, se corrige en código.

### Materiales recolectables (hay cientos en el mapa: modelos ligeros, < 5.000 triángulos)

| Archivo | Tamaño mayor | Prompt |
|---|---|---|
| `material_scrap.glb` | 1,3 m | `A small pile of bent metal scrap from a crashed spacecraft: twisted aluminum panels, a broken bracket, a few bolts, lying on the ground.` — chatarra metálica |
| `material_crate.glb` | 1,35 m | `A rugged cargo crate from a supply spacecraft, cube-shaped, reinforced edges, handles, a small warning light on one corner, slightly dusty.` — caja de cargamento (da polímero y circuitos) |
| `material_ice.glb` | 1,7 m | `A cluster of pale blue water-ice crystals sticking out of grey rocky ground, translucent, a few sharp prisms of different heights.` — cristales de hielo de agua |

### Estaciones de la base (una de cada una; pueden ser más detalladas, idealmente < 20.000 triángulos — cifra orientativa mía)

| Archivo | Tamaño mayor | Prompt |
|---|---|---|
| `station_O.glb` | 2,8 m | `Life support machine for a space habitat: two tall oxygen tanks connected to a control unit with pipes, valves and a small screen.` — soporte vital (oxígeno) |
| `station_S.glb` | 2,5 m | `Solar power control station: a tilted solar panel on a sturdy stand with a battery box and cables at its base.` — panel solar |
| `station_G.glb` | 2,1 m | `Indoor hydroponic greenhouse rack for a space base: shelves with small green plants under soft grow lights, transparent cover.` — invernadero |
| `station_W.glb` | 2,2 m | `Water recycling machine for a space station: a cylindrical tank with filters, pipes and a small control panel.` — reciclador de agua |
| `station_R.glb` | 2,3 m | `Radiation shield generator: a compact machine with a ring-shaped coil on top, heavy base and status panel.` — generador del escudo |
| `station_C.glb` | 1,9 m | `A small cozy rest area for astronauts: a padded two-seat sofa with a side table, simple and functional.` — zona de descanso |
| `station_B.glb` | 2,5 m | `A compact astronaut bunk bed for a space habitat, padded mattress, straps, small reading light.` — cama |
| `station_T.glb` | 1,9 m | `A sturdy workbench for a space base with drawers, a tool panel on the back and a small vise.` — banco de trabajo (el frente con cajones debe mirar hacia la cámara) |
| `station_A.glb` | 2,3 m | `A communication station with a radio console, microphone and a small dish antenna on a mast.` — radio / antena |
| `station_D.glb` | 3,4 m | `An airlock door module for a space habitat: thick hatch door, frame with warning stripes in muted amber, control panel next to it.` — esclusa |

Nota: un modelo importado sustituye por completo al de código, así que se pierden los detalles animados del de código (por ejemplo, el anillo que gira en el escudo) y los cambios visuales de las mejoras de estación.

## 3. Iconos (PNG transparente, cuadrado, 128×128) → `art/icons/`

Se ven a unos 22 px en el HUD: silueta muy clara, pocos detalles. Estilo común para iconos:

```
Style: flat game icon, simple bold silhouette, 2-3 colors from a palette of warm white, graphite and muted amber, transparent background, centered, no text, readable at very small size.
```

| Archivo | Prompt |
|---|---|
| `scrap.png` | `Icon of a piece of bent metal scrap.` — chatarra |
| `polymer.png` | `Icon of a stack of flexible plastic polymer sheets.` — polímero |
| `circuits.png` | `Icon of a small green circuit board with chips.` — circuitos |
| `patch.png` | `Icon of a patch kit: a square patch with a tube of sealant.` — kit de parche |
| `medkit.png` | `Icon of a white first aid kit with a simple cross.` — botiquín |
| `repair.png` | `Icon of a soldering tool next to a small circuit.` — reparador de circuitos |
| `filter.png` | `Icon of a round air filter with layered mesh.` — filtro de polvo |
| `map.png` | `Icon of a folded map with a location pin.` — mapa de navegación |

## 4. Objetos nuevos (necesitan código para aparecer en el juego)

Si los generas, preparo el código para cargarlos (hueco, nombre, tamaño y posición). Mismo estilo común del apartado 1.

| Archivo propuesto | Tamaño mayor | Dónde iría | Prompt |
|---|---|---|---|
| `deco_rover.glb` | 3,5 m | junto a la base (exterior) | `A small six-wheeled exploration rover for a lunar or martian base, open frame, camera mast, solar panel on top, no markings.` |
| `deco_lander.glb` | 6 m | plataforma de aterrizaje | `A compact cargo landing craft standing on four legs, simple cylindrical body, landing engine below, no markings.` |
| `deco_tanks.glb` | 2,6 m | exterior, junto a la base | `A rack of three horizontal gas storage tanks on a metal frame with pipes.` |
| `deco_solar_array.glb` | 4 m | exterior, lado norte | `A row of three tilted solar panels on a low metal frame connected by cables.` |
| `deco_plants.glb` | 0,8 m | invernadero (interior) | `A small hydroponic tray with lettuce and herb seedlings growing in a white plastic container.` |
| `tool_wrench.glb` | 0,35 m | en la mano del astronauta | `A chunky space wrench tool, oversized grip for gloved hands.` |

Los personajes (Zadiel, Yarisbel, Ing. Enoc y la Com. Pam) no se pueden sustituir todavía: el juego no carga personajes con esqueleto y animaciones; sería un trabajo aparte.

## 5. Después de generar

1. Descarga los archivos con el **nombre exacto** de las tablas.
2. Cópialos a `art/3d/` (modelos) o `art/icons/` (iconos) y abre el proyecto en Godot para que los importe.
3. Haz capturas (o pídeselo a Claude Code) y revisa: tamaño, orientación, que no brillen como neón y que se distingan bien la Luna y Marte.
4. Anota en `DATOS.md` la herramienta usada y su licencia.
