# ElderGuard AI para Wear OS

Aplicación nativa de ElderGuard AI para relojes con Wear OS, escrita en Kotlin con Jetpack Compose para Wear OS. Es un proyecto de Gradle independiente: no usa `npm` ni comparte código con el simulador web de `src/`.

Estado actual: estructura inicial. La aplicación abre y muestra `ElderGuard AI` centrado en la pantalla redonda.

## Requisitos

- [Android Studio](https://developer.android.com/studio) en una versión reciente. Incluye su propio JDK, así que no hace falta instalar Java aparte.
- **Conexión a internet la primera vez** que se abre el proyecto: Android Studio descarga Gradle 8.7 y las dependencias (Android Gradle Plugin, Kotlin y Compose para Wear OS). Son varios cientos de MB y puede tardar varios minutos. Después funciona sin conexión.

Versiones del proyecto: `compileSdk` y `targetSdk` 34 (Android 14, Wear OS 5) y `minSdk` 26.

## 1. Abrir el proyecto en Android Studio

1. Clona el repositorio, si aún no lo tienes.
2. Abre Android Studio. En la pantalla de bienvenida pulsa **Open** (o, con otro proyecto abierto, **File > Open…**).
3. Selecciona la carpeta **`wear-app`** dentro del repositorio y pulsa **OK**.
   - **No** selecciones la raíz del repositorio: allí está el proyecto web y Android Studio no encontrará ningún proyecto de Android.
   - Se reconoce la carpeta correcta porque contiene `settings.gradle.kts` y `gradlew.bat`.
4. Si pregunta **Trust Gradle Project?**, pulsa **Trust Project**.
5. Espera a que termine la sincronización de Gradle (_Gradle sync_). El progreso se ve en la barra inferior. Termina cuando la ventana **Build** muestra `BUILD SUCCESSFUL` o la barra inferior deja de mostrar tareas.
6. Si Android Studio ofrece instalar componentes del SDK que falten (por ejemplo, **Android SDK Platform 34**), acepta.
7. Si ofrece actualizar el Android Gradle Plugin con el _AGP Upgrade Assistant_, puedes ignorarlo por ahora: el proyecto está probado con las versiones que tiene.

## 2. Crear el emulador de Wear OS

Solo se hace una vez.

1. Abre **Tools > Device Manager** (o el ícono de teléfono con el logo de Android en la barra lateral derecha).
2. Pulsa **+** y luego **Create Virtual Device…**.
3. En **Category**, elige **Wear OS** y selecciona un dispositivo redondo, por ejemplo **Wear OS Small Round**. Pulsa **Next**.
4. En la imagen del sistema, elige **API 34** (_Wear OS 5_), la variante **x86_64** en computadoras Intel o AMD. Si aparece el ícono de descarga junto a ella, púlsalo y espera a que termine. Pulsa **Next**.
5. Deja el resto como está y pulsa **Finish**.

## 3. Ejecutar la aplicación

1. En la barra superior, comprueba que la configuración de ejecución sea **app**.
2. En la lista de dispositivos, junto a ella, elige el emulador que creaste.
3. Pulsa **Run** (el triángulo verde) o `Shift+F10`.
4. Espera a que el emulador arranque, a que se compile la aplicación y a que se instale. La primera vez que arranca, el emulador pasa por pantallas como `Starting…` o la de carga de batería: espera a que terminen, porque pueden quedar delante de la aplicación.
5. La aplicación se abre sola y muestra `ElderGuard AI` en el centro. También queda en la lista de aplicaciones del reloj.

## Compilar desde la terminal (opcional)

Desde PowerShell, dentro de `wear-app`:

```powershell
.\gradlew.bat tasks          # Comprueba que el proyecto es válido
.\gradlew.bat assembleDebug  # Genera el APK de depuración
```

Si no está definida la variable `ANDROID_HOME`, crea un archivo `local.properties` en `wear-app` con la ruta del SDK, por ejemplo `sdk.dir=D\:\\Android\\Sdk`. Android Studio lo crea solo; no se sube al repositorio.

El APK queda en `app\build\outputs\apk\debug\app-debug.apk`.

## Problemas conocidos

- **Ruta con caracteres no ASCII.** El repositorio está dentro de una carpeta llamada `Diseño…`, y en Windows el Android Gradle Plugin rechaza por defecto esas rutas. `gradle.properties` desactiva esa comprobación (`android.overridePathCheck=true`) y se verificó que la compilación completa funciona. Si aun así aparece algún error de rutas, clona el repositorio en una ruta solo con letras sin acentos, como `D:\ElderGuard_AI`.
- **`Filename too long` en `git status`.** Son avisos de Git sobre archivos de compilación muy profundos dentro de `build/`, que de todos modos se ignoran. Se quitan con `git config core.longpaths true`.
