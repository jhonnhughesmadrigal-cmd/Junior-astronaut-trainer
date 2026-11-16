# Misión Perseo — APK para Android (v37, actualizado en v38)

## Instalar el APK en una tableta o un móvil
1. Copia `MisionPerseo_v38.apk` (o la versión más reciente de `releases/`) al dispositivo (cable USB, Google Drive, correo…).
2. Ábrelo desde el gestor de archivos. Android pedirá permitir «instalar apps de origen desconocido» para esa app (el nombre exacto del ajuste cambia según la marca y la versión de Android).
3. Instalar → Abrir. El juego va en horizontal y a pantalla completa.

Requisitos del APK: Android 5.0 o superior (minSdk 21, targetSdk 34), procesador ARM de 32 o 64 bits. Tamaño ≈ 54 MB.
Como el juego usa el renderizador Compatibility (OpenGL ES 3.0), un dispositivo sin OpenGL ES 3.0 no podrá ejecutarlo.

**No se ha probado en un dispositivo real.** Lo comprobado aquí: el APK se exporta, la firma es válida (`apksigner verify`: v1, v2 y v3), el manifiesto declara el paquete, la versión, los permisos y las arquitecturas, y la lógica nueva para móviles pasa sus pruebas en escritorio (`tests/t_mobile.gd`, 12/12). Falta medir en dispositivos: rendimiento, tamaño de los textos, teclado en pantalla y el botón «Atrás».

## Qué hace distinto en Android
- **Botón «Atrás»** (`mobile_os.gd`): Godot cierra la app por defecto; ahora hace lo mismo que Esc (cerrar el panel abierto, pausa, volver a la portada). En la portada hay que pulsarlo dos veces para salir.
- **Segundo plano**: al cambiar de app se guarda la partida (Android puede cerrar apps en segundo plano sin avisar).
- **Escala de la interfaz** (`ui_fit.gd`): en Android se calcula con los dp reales de la pantalla (`screen_get_dpi`), igual que en el navegador del móvil.
- **Controles táctiles**: se activan solos si hay pantalla táctil (como en v30).
- **Internet**: permisos `INTERNET` y `ACCESS_NETWORK_STATE`, necesarios para las cuentas en la nube (Firebase).
- **v38 — Calidad «Media» la primera vez** (como en el navegador): la «Alta» (MSAA 4×, sombras 4096, resolución completa) es probablemente demasiado para una tablet escolar. Se puede cambiar en Opciones.
- **v38 — Teclado en pantalla**: si tapa el campo de texto activo (correo, contraseña), el panel sube lo justo y vuelve a su sitio al cerrarlo.
- **v38 — Menos llamadas de dibujo dentro de la base**: las piezas fijas del interior se fusionan por material (≈ 13–15 % menos llamadas que en v37, medido en escritorio; no medido en un móvil).
- **Copia de seguridad de Android desactivada** (`user_data_backup/allow=false`): las partidas locales no se suben a la copia de Google; la sincronización entre dispositivos va por la cuenta del juego.

## Datos del paquete
| Campo | Valor |
|---|---|
| Paquete | `com.misionperseo.juego` (no se puede cambiar después de publicar sin perder las actualizaciones) |
| Nombre | Misión Perseo |
| Versión | `version/code=38`, `version/name=0.38` (sube `version/code` en cada APK nuevo) |
| Orientación | horizontal con sensor (`display/window/handheld/orientation=4`) |
| Icono | `art/app/*.png`, generado por código con `tools/gen_icon.gd` |

## La firma (muy importante)
- Los APK (desde v37) están firmados con una clave de *release* creada en esta sesión (`perseo-release.keystore`, alias `perseo`). **No está en el repositorio** (es secreta).
- Guárdala con su contraseña en un lugar seguro (y una copia de respaldo). Si se pierde, los APK futuros llevarán otra firma y Android no dejará actualizar: habrá que desinstalar, y se pierden las partidas que solo estén en el dispositivo.
- Huellas del certificado (no son secretas; Firebase las pide para el inicio con Google en Android):
  - SHA-1: `E0:7D:14:63:0A:F9:91:6A:B2:74:C4:F6:2A:6B:55:3A:9C:9E:B5:43`
  - SHA-256: `0B:46:EC:26:07:7B:68:73:1D:B9:C6:CC:62:C3:6F:BD:3D:B5:C8:8F:7F:70:78:27:68:59:80:5E:FA:77:69:43`
- Para publicar en Google Play hace falta además una cuenta de desarrollador y normalmente un paquete AAB en lugar de APK (requiere la «compilación con Gradle» de Godot). No está hecho; revisa los requisitos actuales de Google Play, que cambian con frecuencia (por ejemplo, el targetSdk mínimo exigido y las políticas para apps dirigidas a niños).

## Volver a generar el APK
Necesitas Godot 4.4.1 con las plantillas de exportación, el Android SDK (build-tools 34) y Java 17 o superior. En Godot: Editor → Configuración del editor → Exportar → Android → rutas del SDK y de Java.

Desde la terminal, sin escribir la contraseña en ningún archivo del proyecto:
```bash
godot --headless --import --path .
```
```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/ruta/perseo-release.keystore GODOT_ANDROID_KEYSTORE_RELEASE_USER=perseo GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='la-contraseña' godot --headless --path . --export-release Android build/MisionPerseo.apk
```
APK de depuración (firma de prueba, solo para probar): `godot --headless --path . --export-debug Android build/MisionPerseo-debug.apk`.

Comprobar el resultado:
```bash
~/android-sdk/build-tools/34.0.0/apksigner verify --print-certs build/MisionPerseo.apk
```
```bash
~/android-sdk/build-tools/34.0.0/aapt2 dump badging build/MisionPerseo.apk | grep -E "package|sdkVersion|permission|native-code"
```

Con un dispositivo conectado por USB (depuración USB activada): `adb install -r build/MisionPerseo.apk` y `adb logcat -s godot` para ver errores.

## Avisos conocidos
- `aapt2` avisa de `mipmap/themed_icon` sin archivo: viene de la plantilla de Godot 4.4.1 (icono temático de Android 13). No se ha comprobado si tiene efecto en algún launcher.
