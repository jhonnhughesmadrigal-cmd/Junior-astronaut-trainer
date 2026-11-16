# Misión Perseo — Activar Firebase (cuentas en la nube)

El juego ya trae todo lo necesario (v36). Falta **tu proyecto de Firebase**, que solo puedes crear tú con tu cuenta de Google. Mientras `firebase_config.gd` esté vacío, el juego funciona como antes: perfiles solo en el dispositivo.

Todo funciona en el **plan gratuito (Spark)**: Authentication (correo y contraseña, correo de verificación) y Cloud Firestore. Revisa en firebase.google.com/pricing los límites actuales del plan gratuito, porque pueden cambiar.

> Los nombres de menús y botones de la consola pueden variar un poco: Google cambia la interfaz con frecuencia.

## 1. Crear el proyecto
1. Entra en https://console.firebase.google.com con tu cuenta de Google.
2. «Crear un proyecto» (o «Agregar proyecto») → nombre, por ejemplo `mision-perseo`. Google Analytics no hace falta.

## 2. Activar el inicio de sesión con correo
1. Menú **Compilación → Authentication → Comenzar**.
2. Pestaña **Método de acceso** → **Correo electrónico/contraseña** → Habilitar → Guardar.
3. (Opcional) Pestaña **Plantillas**: cambia el idioma del correo de verificación a español.

## 3. Crear la base de datos
1. **Compilación → Firestore Database → Crear base de datos**.
2. Elige una ubicación cercana y empieza en **modo de producción**.
3. Pestaña **Reglas**: borra lo que haya, pega el contenido de `firebase/firestore.rules` de este repositorio y pulsa **Publicar**.
   (Alternativa con terminal: `npx firebase-tools deploy --only firestore:rules` desde la carpeta `firebase/`, tras `firebase login` y `firebase use <tu-proyecto>`).

## 4. Registrar la app web y copiar la configuración
1. ⚙ **Configuración del proyecto → General → Tus apps → icono `</>` (Web)** → nombre «Misión Perseo» → Registrar.
2. Copia **apiKey** y **projectId** de la configuración que aparece.
3. Pégalos en `firebase_config.gd`:
   ```
   const API_KEY: String = "AIza..."
   const PROJECT_ID: String = "mision-perseo-xxxx"
   ```
   (o pásaselos a Claude para que los ponga). La apiKey de una app web de Firebase no es secreta: identifica el proyecto; la seguridad la dan las reglas.

## 5. Hacerte administrador (para aprobar docentes)
1. Abre el juego y crea tu cuenta con tu correo (Cuenta personal → Crear cuenta).
2. En la consola: **Authentication → Usuarios** → copia tu **UID** (columna «UID de usuario»).
3. En **Firestore Database → Datos → Iniciar colección** → ID de colección `admins` → ID del documento: tu UID → añade un campo cualquiera (p. ej. `nota` = `admin`) → Guardar.
4. En el juego: **Perfil** → aparece «Administración: solicitudes de docentes». Ahí apruebas o rechazas.

Tu correo no aparece en el código ni en el repositorio: el administrador se reconoce por ese documento.

## 6. Avisos por correo cuando llega una solicitud (opcional, de pago)
Enviar un correo automático al administrador necesita **Cloud Functions**, que exige el plan **Blaze** (pago por uso, con cuota gratuita). Sin eso, revisa las solicitudes en el panel de administración del juego. Si más adelante pasas a Blaze, se puede añadir una función que te envíe un correo por cada solicitud nueva.

## 7. Privacidad (importante)
El juego es para niños de 7–12 años. Pedir correos y guardar partidas de menores tiene obligaciones legales que dependen del país (por ejemplo COPPA en EE. UU. o el RGPD en Europa). Esto no es asesoría legal: revísalo con la escuela antes de usarlo con alumnos reales. Lo que guarda el juego en Firestore: correo, tipo de cuenta y rol, clases (códigos), nombre y escuela del docente, y la partida.

## 8. Probar sin un proyecto real (para desarrolladores)
```
cd firebase && npx firebase-tools emulators:start --only auth,firestore --project demo-mision-perseo
```
y en otra terminal, desde la raíz: `FIREBASE_EMULATOR=127.0.0.1 godot --path .` (el juego usará el emulador). Pruebas: `tests/t_firebase.gd` y `tests/t_fbflow.gd`.
