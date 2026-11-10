# ElderGuard AI para Wear OS

Aplicación nativa de ElderGuard AI para relojes con Wear OS, escrita en Kotlin con Jetpack Compose para Wear OS. Es un proyecto de Gradle independiente: no usa `npm` ni comparte código con el simulador web de `src/`.

Estado actual: esfera del reloj. La aplicación simula los sensores y muestra la hora, la frecuencia cardíaca, la batería, el GPS y un botón SOS que se activa manteniéndolo pulsado. Abre en español; el inglés se elige en una segunda pantalla.

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
5. La aplicación se abre sola y muestra la esfera del reloj, con valores que cambian cada segundo. También queda en la lista de aplicaciones del reloj.

## Compilar desde la terminal (opcional)

Desde PowerShell, dentro de `wear-app`:

```powershell
.\gradlew.bat tasks          # Comprueba que el proyecto es válido
.\gradlew.bat assembleDebug  # Genera el APK de depuración
.\gradlew.bat test           # Ejecuta todas las pruebas en la JVM, sin emulador
```

El resultado de las pruebas queda en `app\build\reports\tests\testDebugUnitTest\index.html`.

Si no está definida la variable `ANDROID_HOME`, crea un archivo `local.properties` en `wear-app` con la ruta del SDK, por ejemplo `sdk.dir=D\:\\Android\\Sdk`. Android Studio lo crea solo; no se sube al repositorio.

El APK queda en `app\build\outputs\apk\debug\app-debug.apk`.

## Esfera del reloj

Reproduce la pantalla del reloj de la aplicación web (sección _Pantalla del reloj_ del README principal) con los componentes de Compose para Wear OS. El código está en `app/src/main/java/com/elderguard/ai/ui`.

Una pantalla redonda de 1,2 pulgadas no tiene espacio para todo a un tamaño legible, así que el contenido está en una `ScalingLazyColumn`: la lista de Wear OS que se desplaza con la corona o deslizando el dedo y reduce los elementos cerca del borde curvo. De arriba abajo:

- **Estado:** batería con ícono y porcentaje, y GPS con ícono y `GPS` o `Sin GPS`.
- **Hora:** en formato de 12 horas en ambos idiomas, con `a. m.`/`p. m.` en español y `AM`/`PM` en inglés, y la fecha corta (`dom, 8 nov` o `Sun, Nov 8`). Se actualiza cada segundo. Al desplazar la lista hasta que la hora grande deja de verse, aparece la hora pequeña curvada en el borde superior (`TimeText`), con el mismo formato.
- **Frecuencia cardíaca:** corazón y pulsaciones en cifras grandes.
- **SOS:** el botón rojo, que ocupa unas tres cuartas partes del ancho de la pantalla.

Al abrir, la hora queda centrada; para llegar al botón SOS se desplaza la lista hacia arriba.

### Colores

La aplicación usa el tema oscuro estándar de Wear OS: el fondo negro ahorra batería en las pantallas OLED de los relojes. Por eso, a diferencia de la versión web, no hay tema claro. Los colores son los del tema oscuro de la web (`src/styles/tokens.css`), y una prueba comprueba que cada combinación de texto y fondo alcanza el contraste 7:1 de WCAG AAA.

| Indicador | Normal | Aviso | Crítico |
| --------- | ------ | ----- | ------- |
| Batería | Verde (más de 20 %) | Ámbar (20 % o menos) | Rojo (10 % o menos) |
| GPS | Verde (con señal) | Ámbar (`Sin GPS`) | — |

Igual que en la web, el estado de la batería se calcula con el porcentaje redondeado que se muestra, para que el color siempre coincida con el número.

### Botón SOS

Funciona como en la web, para evitar activaciones accidentales:

1. Un toque simple no hace nada.
2. Mantén pulsado el botón durante 2 segundos. Un anillo blanco se va llenando a su alrededor y el reloj vibra levemente al empezar.
3. Si sueltas antes de tiempo, se cancela y aparece durante 2 segundos el aviso `Mantén presionado` (`Hold to call for help`) en la parte superior de la pantalla, donde el dedo no lo tapa. Si el gesto se convierte en un desplazamiento de la lista, se cancela sin mostrar el aviso.
4. Al completar los 2 segundos, sin necesidad de soltar, el reloj vibra y aparece la pantalla roja `Pidiendo ayuda…` (`Calling for help…`). El estado `deviceStatus.mode` del store pasa a `Sos`.
5. El botón `Cancelar` cierra esa pantalla y devuelve el modo a `Monitoring`. Mientras la pantalla roja está abierta, no se puede tocar ni desplazar nada de lo que hay detrás.

El botón no usa el `Button` de Material porque su propio manejo del toque competiría con el gesto de mantener pulsado. Es un `Box` circular con la semántica de un botón, y los lectores de pantalla lo anuncian como `SOS, auxilio. Mantén pulsado 2 segundos para pedir ayuda`.

Todavía no existen la alternativa para lectores de pantalla de la versión web (el botón `Pedir ayuda` con confirmación) ni el envío simulado de alertas a los contactos.

### Idioma

La aplicación abre en español sin importar el idioma del reloj. Para cambiarlo:

1. En la esfera, desliza el dedo de derecha a izquierda. Los puntos de la parte inferior indican que hay una segunda pantalla.
2. Pulsa `ES` (Español) o `EN` (English). El botón resaltado en azul es el idioma actual.
3. Todo el texto cambia al instante, sin reiniciar la aplicación. Para volver a la esfera, desliza de izquierda a derecha.

Cada idioma aparece con su nombre en ese mismo idioma, para que quien lo haya cambiado por error encuentre el suyo. La elección se guarda en `SharedPreferences` y se conserva al cerrar la aplicación; si el almacenamiento falla, la aplicación sigue en español sin cerrarse.

Deslizar de izquierda a derecha en la esfera es el gesto de Wear OS para cerrar una aplicación, y no se ha cambiado. Por eso la pantalla de idioma está a la derecha de la esfera y no a su izquierda.

Los textos están en `res/values/strings.xml` (español, el idioma por defecto) y `res/values-en/strings.xml` (inglés). `ProvideAppLanguage` sustituye el idioma del sistema por el de la aplicación en todo lo que se dibuja debajo.

## Arquitectura de telemetría

Es una traducción a Kotlin del motor de la aplicación web (`src/core/telemetryStore.js`, `src/core/generators` y `src/core/simulationEngine.js`), con los mismos umbrales y el mismo comportamiento descritos en la sección _Arquitectura de telemetría_ del README principal. El código está en `app/src/main/java/com/elderguard/ai/telemetry` y los valores en `config/TelemetryConfig.kt`, que refleja `src/config/telemetry.config.js`. Si se cambia un valor en un lado, hay que cambiarlo también en el otro.

```text
Generadores ──> SimulationEngine ──> TelemetryStore (StateFlow) ──> Interfaz Compose
                       ^
                       └── Anulaciones (escenarios de demostración, fase N5)
```

### Modelo de estado

`TelemetryState` reúne todos los datos de los sensores en un único objeto inmutable (`data class`). Cada cambio crea una copia nueva con `copy(...)`; nada se modifica en el lugar.

```kotlin
TelemetryState(
    heartRate = HeartRate(bpm = 70),                         // LPM
    accelerometer = Accelerometer(x = 0.0, y = 0.0, z = 1.0), // g; .magnitude da el total
    gps = Gps(lat, lng, accuracy = 3.0, signal = true),        // accuracy en metros
    battery = Battery(level = 100.0, charging = false),        // level de 0 a 100
    deviceStatus = DeviceStatus(mode = DeviceMode.Monitoring, lastUpdate = null),
)
```

`DeviceMode` puede ser `Monitoring`, `FallCountdown` o `Sos`. `lastUpdate` es la hora del último ciclo en milisegundos, o `null` antes del primero.

### Store

`TelemetryStore` expone el estado como un `StateFlow<TelemetryState>`: un valor observable que siempre tiene un valor actual (`state.value`) y avisa a quien lo recoja de cada valor nuevo. Reemplaza el `subscribe` de la versión web, y como ella solo avisa cuando el estado cambia de verdad.

- `update { it.copy(...) }` combina los cambios con el estado actual; los campos que no se mencionan se conservan. Es atómico aunque se llame desde varios hilos.
- `reset()` restaura el estado inicial.

### Generadores

Funciones puras en `telemetry/generators` que calculan la siguiente lectura de cada sensor. Reciben un `kotlin.random.Random`, así que las pruebas usan uno con semilla fija y obtienen siempre los mismos valores. El redondeo imita a `Math.round` de JavaScript para que ambas aplicaciones den los mismos números.

- **Frecuencia cardíaca:** caminata aleatoria de valores enteros dentro del rango de reposo (60 a 80 LPM), con cambios de hasta 2 LPM por ciclo.
- **Acelerómetro:** 1 g en el eje z con un ruido de hasta 0,02 g por eje.
- **GPS:** pequeña deriva alrededor de las coordenadas base (Bogotá), sin alejarse más de unos 22 m.
- **Batería:** baja 0,01 % por ciclo y nunca queda por debajo de 0.

### Motor de simulación

`SimulationEngine` ejecuta los generadores cada segundo dentro de una corrutina y escribe todas las lecturas en el store en una sola actualización. Se controla con `start()`, `stop()` e `isRunning`. Vive en un `TelemetryViewModel` que lo arranca al crearse la actividad, conserva la simulación si Android vuelve a crear la actividad (por ejemplo, al cambiar el idioma o el tamaño de letra del sistema) y lo detiene al cerrarse la aplicación.

### Anulaciones (overrides)

Mientras un sensor tiene una anulación, su generador no se ejecuta y se usa el valor indicado; los demás siguen generándose. El valor se aplica de inmediato, sin esperar al siguiente ciclo. En la fase N5 los escenarios de demostración dentro del reloj (caída, frecuencia cardíaca anormal, pérdida de señal) usarán esta misma interfaz.

```kotlin
engine.setOverride(Sensor.HEART_RATE, HeartRate(150))                  // Frecuencia cardíaca anormal
engine.setOverride(Sensor.ACCELEROMETER, Accelerometer(2.5, 1.8, 3.2)) // Impacto
engine.setPartialOverride(Sensor.GPS) { it.copy(signal = false) }      // Cambio parcial: pérdida de señal

engine.clearOverride(Sensor.HEART_RATE) // Ese sensor vuelve a generarse en el siguiente ciclo
engine.clearAllOverrides()              // Todos vuelven a generarse
```

A diferencia de la versión web, los sensores no son textos sino constantes de `Sensor`, de modo que el compilador rechaza un sensor desconocido o un valor del tipo equivocado.

## Pruebas

Están en `app/src/test` y se ejecutan con `.\gradlew.bat test`, sin emulador.

- **Lógica:** store, generadores, motor, estados de batería y GPS, formato de la hora, colores e idioma. Las del motor usan el tiempo virtual de `kotlinx-coroutines-test` (`runTest`, `advanceTimeBy`), el equivalente de los temporizadores falsos de Vitest: un segundo de simulación pasa al instante.
- **Interfaz:** pruebas de Compose (`createComposeRule`) que se ejecutan en la JVM gracias a [Robolectric](https://robolectric.org), que simula Android en un reloj redondo de 192 dp. Con `mainClock.autoAdvance = false`, el tiempo solo avanza cuando la prueba lo pide, así que los 2 segundos del botón SOS no se esperan de verdad. Cubren la hora, los colores de batería y GPS, la activación y la cancelación del SOS, el aviso `Mantén presionado` y el cambio de idioma.

La primera vez que se ejecutan, Robolectric descarga una versión de Android para la JVM (unos 100 MB). Solo se ejecutan en la variante de depuración, la única que incluye la actividad vacía donde se dibujan las pruebas de interfaz.

## Problemas conocidos

- **Ruta con caracteres no ASCII.** El repositorio está dentro de una carpeta llamada `Diseño…`, y en Windows el Android Gradle Plugin rechaza por defecto esas rutas. `gradle.properties` desactiva esa comprobación (`android.overridePathCheck=true`) y se verificó que la compilación completa funciona. Si aun así aparece algún error de rutas, clona el repositorio en una ruta solo con letras sin acentos, como `D:\ElderGuard_AI`.
- **`Filename too long` en `git status`.** Son avisos de Git sobre archivos de compilación muy profundos dentro de `build/`, que de todos modos se ignoran. Se quitan con `git config core.longpaths true`.
