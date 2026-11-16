# Misión Perseo — Privacidad (BORRADOR para revisar con la escuela)

> Esto **no es asesoría legal**. Es un borrador para que la escuela (y, si hace falta, su asesoría jurídica) lo revise y adapte. Las obligaciones dependen del país y de la normativa que aplique a la escuela (por ejemplo COPPA en EE. UU., el RGPD en la Unión Europea o la ley de protección de datos de tu país). No he comprobado qué ley aplica en tu caso.

## Lo que guarda el juego (comprobado en el código, v37)
| Dónde | Qué | Cuándo |
|---|---|---|
| Dispositivo (`user://profiles.cfg`, `user://save_<id>.json`) | perfiles del dispositivo (tipo, correo si lo hay, rol, clases; con cuenta en la nube, también el token de sesión para no pedir la contraseña cada vez), partidas, opciones | siempre que no se juegue como invitado |
| Dispositivo, modo invitado | partida temporal (`user://save_guest.json`) | se borra al volver a abrir el juego |
| Firebase Authentication (Google) | correo y contraseña (Google guarda la contraseña protegida con hash; el juego no la conserva), estado de verificación del correo | solo si se crea una cuenta en la nube |
| Cloud Firestore (Google) `users/{uid}` | correo, tipo de cuenta, rol, códigos de clase, estado de docente | ídem |
| `teacher_requests/{uid}` | nombre y escuela del docente, correo | solo docentes que piden verificación |
| `saves/{uid}` | la partida | al guardar con cuenta en la nube |

No hay publicidad, ni analítica, ni chat entre jugadores, ni fotos, ni ubicación. Las reglas de Firestore (`firebase/firestore.rules`) solo dejan a cada usuario leer sus propios datos; el administrador puede leer las fichas de usuario y las solicitudes de docente (no las partidas) y solo puede cambiar el estado de docente.

Los alumnos pueden jugar **sin dar ningún correo** (invitado o perfil local) y unirse a una clase con el código `PER-XXXX`, que no envía nada a ningún servidor.

## Aviso dentro del juego (v37)
Al crear una cuenta en la nube aparece:
> «Tu correo y tu partida se guardan en servidores de Google (Firebase) para que puedas jugar en otros dispositivos. Pide permiso a tu familia o a tu docente antes de crear la cuenta.»

## Borrador de aviso para familias
> **Misión Perseo** es un juego educativo sobre la Luna y Marte. Se puede jugar sin cuenta. Si la familia o la escuela lo autorizan, el alumno puede crear una cuenta con su correo para guardar la partida en la nube y seguir en otro dispositivo.
> Con la cuenta se guardan: el correo, el tipo de cuenta y la partida. Se almacenan en Google Firebase. No se usan para publicidad ni se comparten con terceros.
> Para borrar la cuenta y sus datos, escriba a: **[correo de contacto de la escuela o del responsable]**.
> Responsable del tratamiento: **[nombre]**. Fecha: **[fecha]**.

## Pendiente (decisiones de la escuela o del responsable)
1. Decidir si los menores pueden crear cuentas con correo, o si solo los docentes las usan y los alumnos juegan con perfil local y código de clase (la opción con menos datos).
2. Consentimiento de las familias, si la normativa aplicable lo exige.
3. Un correo de contacto para pedir el borrado de datos. Hoy el borrado se hace a mano en la consola de Firebase (Authentication → usuario → Eliminar, y sus documentos en Firestore). Un botón «Borrar mi cuenta» dentro del juego **no está hecho**.
4. Región de los datos: se eligió al crear la base de datos en Firestore; compruébala en la consola si la normativa exige una región concreta.
5. Revisar los términos actuales de Firebase y de Google para uso educativo o con menores (pueden haber cambiado; no los he verificado).
