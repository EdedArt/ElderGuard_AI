# ElderGuard AI para Garmin (Connect IQ)

Aplicación de ElderGuard AI para relojes Garmin, escrita en Monkey C con el SDK de Connect IQ. Es la versión que se instala en el **Garmin Forerunner 165** prestado para la sustentación. Es un proyecto independiente: no usa `npm` ni Gradle y no comparte código con la versión web (`src/`) ni con la de Wear OS (`wear-app/`), que sirven como especificación de lo que hay que portar.

Estado actual: esfera del reloj. La aplicación muestra la batería y el GPS, la hora en formato de 12 horas, la fecha, la frecuencia cardíaca y un botón SOS que se activa manteniéndolo pulsado 2 segundos, con la telemetría simulada de la fase anterior. Está en español por defecto y se puede cambiar a inglés desde el reloj.

Compilado y probado en el simulador con el **SDK de Connect IQ 9.3.0** para el Forerunner 165 (`fr165`, nivel de API 5.2). Aún no se ha instalado en el reloj real.

## Dispositivo

| Dato | Valor |
| ---- | ----- |
| Reloj | Garmin Forerunner 165 (identificador de producto `fr165`) |
| Pantalla | Redonda, AMOLED, táctil, 390 × 390 píxeles, 16 bits de color |
| Botones | 5: LIGHT, UP, DOWN, START/STOP y BACK (las aplicaciones reciben los cuatro últimos) |
| Nivel de API de Connect IQ | 5.2 (`minApiLevel="5.2.0"` en `manifest.xml`) |
| Ícono de la aplicación | 54 × 54 píxeles |
| Sensores | Acelerómetro, frecuencia cardíaca óptica, GPS |

## Estructura

```text
garmin-app/
├── manifest.xml                  # Tipo de aplicación, dispositivo, idiomas, permisos e ID
├── monkey.jungle                 # Configuración de compilación (código en source/ y test/)
├── source/
│   ├── App.mc                    # ElderGuardApp: punto de entrada; crea el almacén, el motor y el idioma
│   ├── config/
│   │   └── TelemetryConfig.mc    # Constantes de la simulación (telemetry.config.js)
│   ├── i18n/
│   │   └── LanguagePreference.mc # Idioma elegido (es/en), guardado en Application.Storage
│   ├── sos/
│   │   ├── SosHold.mc            # SosConfig y la pulsación de 2 segundos (longPress.js)
│   │   └── SosController.mc      # Activa y cancela el SOS (sosController.js)
│   ├── telemetry/
│   │   ├── TelemetryModels.mc    # Lecturas: HeartRate, Accelerometer, Gps, Battery, DeviceStatus
│   │   ├── TelemetryStore.mc     # TelemetryState y TelemetryStore (telemetryStore.js)
│   │   ├── GeneratorMath.mc      # RandomSource y redondeo (math.js)
│   │   ├── Generators.mc         # Generadores de cada sensor (generators/)
│   │   ├── SimulationEngine.mc   # Motor con Timer (simulationEngine.js)
│   │   └── WatchStatus.mc        # Estado de la batería y del GPS (watchStatus.js)
│   └── ui/
│       ├── WatchfaceView.mc      # La esfera: dibuja las partes con los datos del almacén
│       ├── WatchfaceLayout.mc    # Posiciones dentro del círculo de 390 × 390
│       ├── WatchfaceController.mc # Lógica de la pulsación del SOS y su temporizador
│       ├── WatchfaceDelegate.mc  # Botones y toques de la esfera
│       ├── drawables/
│       │   └── WatchfaceDrawables.mc # Batería, GPS, reloj, pulso, botón SOS, avisos
│       ├── SosView.mc            # Pantalla roja «Pidiendo ayuda…» y su delegado
│       ├── LanguageMenu.mc       # Pantalla de idioma (Menu2)
│       ├── TimeFormat.mc         # Hora de 12 horas y fecha corta (timeFormat.js)
│       └── WatchColors.mc        # Colores del tema oscuro
├── test/                         # Pruebas unitarias (Run No Evil)
├── resources/
│   ├── drawables/
│   │   ├── drawables.xml
│   │   └── launcher_icon.png     # Ícono de la lista de aplicaciones (54 × 54)
│   └── strings/
│       ├── strings.xml           # Textos en español
│       └── strings-eng.xml       # Los mismos textos en inglés
```

Ningún texto visible está escrito en el código: todos salen de `strings.xml` y `strings-eng.xml`. Connect IQ solo sabe elegir los textos según el idioma del reloj (con carpetas como `resources-eng`), pero aquí el idioma lo elige la persona dentro de la aplicación. Por eso los dos idiomas son recursos por defecto: cada texto en español tiene su versión en inglés con el mismo identificador y `En` al final (`SosActive` y `SosActiveEn`), y `LanguagePreference.text(Rez.Strings.X, Rez.Strings.XEn)` carga el del idioma elegido. Como cada uso pide los dos identificadores, el compilador no deja olvidar ninguno de los dos idiomas.

## Requisitos

Se instalan una sola vez:

1. **Java**: el compilador de Monkey C funciona con Java. Probado con Eclipse Temurin 17 ([adoptium.net](https://adoptium.net/)).
2. **SDK Manager de Connect IQ**: descárgalo desde [developer.garmin.com/connect-iq/sdk](https://developer.garmin.com/connect-iq/sdk/), ábrelo e inicia sesión con una cuenta de Garmin.
   - En la pestaña **SDK**, descarga la versión **9.3.0** (o posterior) y márcala como activa.
   - En la pestaña **Devices**, descarga **Forerunner 165**. Sin este paso, ni el compilador ni el simulador conocen el reloj.
3. **SDK en el `PATH`**: añade la carpeta `bin` del SDK al `PATH` de Windows para usar `monkeyc`, `connectiq` y `monkeydo` desde la terminal. Con la instalación por defecto es:
   `C:\Users\<usuario>\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.3.0-<fecha>-<hash>\bin`
   Compruébalo en una terminal nueva con `monkeyc --version` (debe mostrar `Connect IQ Compiler version: 9.3.0`).
4. **Clave de desarrollador**: `monkeyc` firma **todas** las compilaciones, también las del simulador, y el SDK no genera la clave solo. Créala una vez y guárdala **fuera del repositorio**, en `%USERPROFILE%\Documents\garmin\developer_key.der` (clave RSA de 4096 bits en formato PKCS#8 DER). Hay dos formas:
   - En VS Code, con la extensión **Monkey C** de Garmin: `Ctrl+Shift+P` > **Monkey C: Generate a Developer Key**.
   - Desde Git Bash, con el OpenSSL incluido en Git for Windows:

     ```bash
     mkdir -p ~/Documents/garmin && cd ~/Documents/garmin
     openssl genrsa -out developer_key.pem 4096
     openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
     rm developer_key.pem
     ```

   `.gitignore` ignora cualquier clave dentro de `garmin-app/`, pero no debe subirse nunca. Usa siempre la misma clave: el reloj no acepta como actualización una versión firmada con una clave distinta a la de la versión instalada.

El ID de la aplicación ya está fijado en `manifest.xml` y **no debe cambiarse**: si cambia, el reloj trata la nueva versión como una aplicación distinta. Para instalar por USB no hace falta un ID asignado por la tienda de Garmin.

## 1. Compilar (PowerShell)

Desde la carpeta `garmin-app`:

```powershell
cd garmin-app
monkeyc -f monkey.jungle -d fr165 -o bin\ElderGuardAI.prg -y "$env:USERPROFILE\Documents\garmin\developer_key.der" -w -l 3
```

| Opción | Significado |
| ------ | ----------- |
| `-f monkey.jungle` | Configuración del proyecto (manifiesto, código en `source/`, recursos en `resources*/`) |
| `-d fr165` | Dispositivo de destino: Forerunner 165 |
| `-o bin\ElderGuardAI.prg` | Archivo de salida. `bin/` está en `.gitignore` |
| `-y …developer_key.der` | Clave con la que se firma la compilación |
| `-w` | Muestra las advertencias del compilador |
| `-l 3` | Comprobación de tipos estricta |

Debe terminar con `BUILD SUCCESSFUL` y sin advertencias. El mismo `ElderGuardAI.prg` sirve para el simulador y para el reloj.

## 2. Ejecutar en el simulador

```powershell
connectiq
monkeydo bin\ElderGuardAI.prg fr165
```

1. `connectiq` abre el **simulador de Connect IQ** en otra ventana y devuelve el control a la terminal. Espera unos segundos a que aparezca la ventana antes del paso siguiente.
2. `monkeydo` envía la aplicación al simulador y la abre en el Forerunner 165. El título de la ventana muestra `Forerunner® 165 (5.2.0)`, y en la pantalla del reloj aparece la esfera en español: `100 %` y `GPS` en verde, la hora (por ejemplo `11:43 p. m.`), la fecha (`jue, 12 nov`), el pulso (`68 LPM`), que cambia cada segundo, y el botón rojo `SOS` / `AUXILIO`.
3. `monkeydo` se queda abierto mostrando la salida de la aplicación (`System.println`). Pulsa `Ctrl+C` para cerrarlo. El simulador sigue abierto y se puede reutilizar: después de recompilar basta con volver a ejecutar `monkeydo`.

La primera vez, Windows puede preguntar si `simulator` puede acceder a la red. `monkeydo` se comunica con el simulador dentro del propio equipo, así que la aplicación se abre aunque no se dé ese permiso.

En el simulador, un clic en la pantalla equivale a tocarla, y los botones dibujados alrededor del reloj se pueden pulsar o mantener pulsados con el ratón (por ejemplo, mantener `START` 2 segundos activa el SOS). El menú **Simulation** permite simular los sensores (frecuencia cardíaca, acelerómetro, GPS); se usará en las fases siguientes.

### Alternativa: VS Code

Con la extensión **Monkey C** de Garmin y la carpeta **`garmin-app`** abierta (no la raíz del repositorio), **Run > Run Without Debugging** (`Ctrl+F5`) compila y abre el simulador; si pregunta por el dispositivo, elige **Forerunner 165**. La primera vez pide la ruta de la clave de desarrollador. La forma comprobada son los comandos de terminal de los pasos 1 y 2.

## 3. Instalar en el reloj por USB (sustentación)

1. Compila con el comando del paso 1. El archivo que se instala es `garmin-app\bin\ElderGuardAI.prg`.
2. Conecta el reloj al computador con su cable USB. En Windows aparece como dispositivo portátil **Forerunner 165** en el Explorador de archivos (no como unidad con letra).
3. Abre **Forerunner 165 > Internal Storage > GARMIN > Apps** y copia ahí `ElderGuardAI.prg`. Es la carpeta `GARMIN/APPS` que indica la documentación de Connect IQ para instalar aplicaciones a mano.
4. Expulsa el reloj desde el Explorador y desconéctalo. El reloj instala la aplicación al desconectarse.
5. En el reloj, busca **ElderGuard AI** en la lista de aplicaciones.

Para actualizarla, repite los pasos: el `.prg` nuevo reemplaza al anterior porque el ID de la aplicación y la clave no cambian. Para desinstalarla, borra el `.prg` de `GARMIN/Apps`.

Antes de la sustentación conviene hacer una prueba completa en el reloj real, porque el simulador no reproduce exactamente el rendimiento, los sensores ni el brillo de la pantalla AMOLED.

## Arquitectura de telemetría

Es la misma que en la versión web (`src/core`) y en la de Wear OS (`wear-app`), con los mismos valores de `telemetry.config.js`: frecuencia cardíaca en reposo entre 60 y 80 LPM, acelerómetro en reposo de 1 g, posición de ejemplo en Bogotá y batería que baja un 0,01 % por segundo. Por ahora los sensores son simulados; los del reloj se conectarán en fases posteriores.

```text
SimulationEngine ──tick cada segundo──▶ TelemetryStore ──avisa a los oyentes──▶ WatchfaceView / SosView
  (Timer + generadores)                  (estado actual)                         (requestUpdate)
```

### Modelo de estado

- **`TelemetryState`** reúne todo lo que sabe el reloj en un momento: `heartRate`, `accelerometer`, `gps`, `battery` y `deviceStatus`. `TelemetryState.initial()` es el estado antes del primer tick: 70 LPM, 1 g en el eje z, la posición base con señal y la batería al 100 %.
- Cada lectura es una clase pequeña (`HeartRate`, `Accelerometer`, `Gps`, `Battery`, `DeviceStatus`) que **no se modifica** una vez creada: una lectura nueva es un objeto nuevo. Monkey C no tiene campos de solo lectura, así que es una convención, y es lo que permite compartir las lecturas sin copiarlas. Cada clase define `equals()`, para distinguir un cambio real de un valor repetido.
- Los valores con decimales son `Double`: `Float` es de 32 bits y no alcanza para coordenadas con 6 decimales.
- **`DeviceMode`** (`MODE_MONITORING`, `MODE_FALL_COUNTDOWN`, `MODE_SOS`) y **`HealthAlert`** son `enum` con nombre en lugar de textos como en la versión web: son constantes enteras que no ocupan memoria en cada uso y que la comprobación de tipos estricta (`-l 3`) verifica, igual que las constantes de la propia API de Connect IQ.

### Almacén (`TelemetryStore`)

Monkey C no tiene flujos reactivos como `StateFlow`, así que el almacén usa el patrón observador:

- `register(oyente)` y `unregister(oyente)`. Un oyente es un objeto `Method` (`method(:nombre)`), el mismo tipo de callback que usan `Timer` y el resto de la API.
- `update(estado)` reemplaza el estado y avisa a los oyentes con una copia del estado nuevo y la lista de partes que cambiaron (`StateKey`). Si nada cambió, no avisa. Para cambiar una parte: `var next = store.getState(); next.heartRate = new HeartRate(90); store.update(next);`.
- `getState()` y `update()` trabajan con copias, así que nadie puede cambiar el almacén sin pasar por `update()`.
- `reset()` vuelve al estado inicial.
- Si un oyente llama a `update()`, el aviso nuevo espera a que termine la ronda actual, para que ningún oyente reciba los estados desordenados.

### Generadores

`Generators` calcula la siguiente lectura de cada sensor a partir de la actual, con el mismo comportamiento y redondeo que las otras versiones:

| Generador | Comportamiento |
| --------- | -------------- |
| `nextHeartRate` | Paseo aleatorio de LPM enteros, de ±2 como máximo por tick, dentro de 60–80 |
| `nextAccelerometer` | Reposo (0, 0, 1 g) más un ruido de ±0,02 g por eje, con 2 decimales |
| `nextGps` | Deriva de ±0,00002° por tick, a menos de 0,0002° de la base, con 6 decimales; precisión entre 3 y 8 m |
| `nextBattery` | Baja 0,01 % por tick, con 4 decimales, sin pasar de 0 |

El azar llega como parámetro, un `RandomSource`, que usa `Math.rand()`. `Math.srand(semilla)` hace que `Math.rand()` repita la misma secuencia, y las pruebas lo usan para obtener siempre los mismos valores. `GeneratorMath.roundTo` redondea con `floor(x + 0.5)`, como `Math.round` de JavaScript, porque la documentación de `Math.round` de Monkey C no dice cómo redondea los negativos.

### Motor (`SimulationEngine`)

- `start()` crea un `Timer.Timer` que llama a `tick()` cada segundo. Iniciarlo dos veces no tiene efecto. `stop()` lo detiene y lo libera, porque cada aplicación solo puede tener unos pocos `Timer`.
- Cada tick ejecuta los cuatro generadores y escribe todas las lecturas y la hora (`deviceStatus.lastUpdate`, en milisegundos) en una sola actualización del almacén.
- `setOverride(sensor, valor)` fija el valor de un sensor y lo aplica en el acto, sin esperar al tick. Lanza `InvalidValueException` si el valor no corresponde a ese sensor. `clearOverride(sensor)` y `clearAllOverrides()` vuelven a generar desde el valor actual. Se usarán en los escenarios de demostración.
- `ElderGuardApp` crea el almacén y el motor, inicia el motor en `onStart()` y lo detiene en `onStop()`, como el ViewModel de la versión de Wear OS.

### Pantalla y consumo de batería

La esfera no tiene un temporizador para redibujarse. Mientras está visible (`onShow()`), escucha al almacén, y cada aviso solo llama a `WatchUi.requestUpdate()`: el sistema junta las peticiones y llama a `onUpdate()` una vez. Como el almacén solo avisa si algo cambió, la pantalla se dibuja como mucho una vez por tick, lo que también mantiene la hora al día, y deja de escuchar en `onHide()`. El único temporizador extra es el de la pulsación del SOS (ver más abajo), que solo funciona mientras se mantiene pulsado o se ve el aviso. El fondo es negro porque en la pantalla AMOLED los píxeles negros están apagados.

## Botones y pantalla táctil del Forerunner 165

El Forerunner 165 tiene pantalla táctil y cinco botones. Se comprobó con los archivos del dispositivo en el SDK y en el simulador qué recibe la aplicación de cada uno:

| Entrada | Lo que recibe la aplicación | Uso en ElderGuard AI |
| ------- | --------------------------- | -------------------- |
| START/STOP (arriba a la derecha) | `onKeyPressed` al bajar y `onKeyReleased` al soltar (`KEY_ENTER`), así que se puede medir cuánto se mantiene | **SOS**: mantener 2 segundos |
| BACK (abajo a la derecha) | `onBack` | Cancelar el SOS; en la esfera, salir de la aplicación (lo normal en Garmin) |
| UP (izquierda, centro) | Mantenerlo pulsado da `onMenu`, el menú en todos los relojes Garmin | Abrir la pantalla de idioma |
| DOWN (abajo a la izquierda) | `onNextPage` | Abrir la pantalla de idioma |
| LIGHT (arriba a la izquierda) | Nada: lo reserva el sistema | — |
| Dedo quieto en la pantalla | No hay eventos de arrastre: el sistema envía `onHold` alrededor de 1 segundo después del toque y `onRelease` al levantarlo | **SOS**: mantener el dedo en el círculo rojo |
| Toque corto | `onSelect` y luego `onTap` | En el círculo rojo, muestra el aviso «Mantén presionado» |
| Deslizar hacia arriba | `onNextPage` | Abrir la pantalla de idioma |

Por eso **el botón START es la forma principal de pedir ayuda**: en todos los relojes Garmin es el que inicia y confirma, se encuentra sin mirar y funciona con las manos mojadas o con guantes, y la aplicación sabe exactamente cuándo baja y cuándo sube. Mantener el dedo en el botón SOS de la pantalla también funciona, como en las otras versiones.

## Esfera del reloj

Reproduce las tres zonas de la esfera web y la de Wear OS, dentro del círculo de 390 × 390 (`WatchfaceLayout`):

- **Arriba, estado:** batería con ícono y porcentaje, y GPS con ícono y etiqueta.
  - Batería: verde por encima de 20 %, ámbar con 20 % o menos y rojo con 10 % o menos, calculado sobre el porcentaje redondeado que se muestra.
  - GPS: `GPS` en verde con señal y `Sin GPS` en ámbar sin ella.
- **Centro, datos:** la hora en formato de 12 horas en los dos idiomas, con `a. m.`/`p. m.` en español y `AM`/`PM` en inglés; la fecha corta (`jue, 12 nov` / `Thu, Nov 12`), y la frecuencia cardíaca con un corazón (`68 LPM` / `68 BPM`). El corazón no late como en la web: una animación continua obligaría a redibujar la pantalla muchas veces por segundo.
- **Abajo, SOS:** círculo rojo grande con `SOS` y `AUXILIO` (`HELP`), y un arco rojo en el borde de la pantalla junto al botón START, la señal que usan las aplicaciones de Garmin para indicar qué botón hace algo.

Cada parte es un `WatchUi.Drawable` (`BatteryIndicator`, `GpsIndicator`, `ClockDisplay`, `HeartRateIndicator`, `SosButton`, `ButtonHintArc`, `HoldHint`) que la vista llena con los datos del almacén y dibuja. Los íconos se dibujan con primitivas (`fillCircle`, `fillPolygon`…), sin imágenes.

Los colores son los del tema oscuro de las otras versiones (`WatchColors`). Todos los pares de texto y fondo alcanzan el contraste AAA de 7:1, también después de reducirlos a los 16 bits de color de la pantalla; el más ajustado es el blanco sobre el rojo del SOS (7,38:1, y 7,08:1 en pantalla).

## Botón SOS

Un toque o una pulsación corta no hacen nada, para evitar activaciones accidentales:

1. Mantén pulsado **START** durante 2 segundos, o mantén el dedo sobre el círculo rojo. El círculo se vuelve blanco con letras rojas al instante, un anillo blanco se va llenando a su alrededor en el sentido de las agujas del reloj, y el reloj vibra brevemente.
2. Si sueltas antes de tiempo, o solo tocas el círculo, se cancela y aparece durante 2 segundos el aviso `Mantén presionado` (`Hold to call for help`) en el centro de la pantalla, donde el dedo no lo tapa.
3. Al completar los 2 segundos, sin esperar a soltar, el reloj vibra y aparece la pantalla roja `Pidiendo ayuda…` (`Calling for help…`). El estado `deviceStatus.mode` cambia a `MODE_SOS`.
4. El botón `Cancelar` de esa pantalla, o el botón **BACK** (señalado con un arco blanco en el borde), la cierra y devuelve el reloj al modo `MODE_MONITORING`. START no hace nada en esa pantalla, para que soltarlo después de activar el SOS no la cierre.

Con el dedo, el sistema solo avisa de que hay un dedo quieto alrededor de 1 segundo después del toque (`onHold`), así que el anillo empieza a llenarse a partir de ese momento: en la pantalla hacen falta unos 3 segundos en total. Con START son exactamente 2.

La pantalla SOS reacciona al estado, como en la versión web: la esfera la abre cuando el modo pasa a `MODE_SOS` y ella se cierra cuando deja de serlo. `SosHold` guarda la pulsación (con tiempos que recibe como parámetro, para las pruebas), `WatchfaceController` tiene el temporizador de 100 ms que mueve el anillo y comprueba si se completó, y solo funciona mientras hay algo que animar, y `SosController` cambia el modo en el almacén.

## Idioma

La aplicación abre en español, sea cual sea el idioma del reloj. Para cambiarlo:

1. En la esfera, **mantén pulsado UP** (el gesto de menú de todos los relojes Garmin), o pulsa **DOWN**, o desliza el dedo hacia arriba.
2. Aparece la lista `Idioma` (`Menu2`, la lista nativa de los ajustes de Garmin), con `Español` y `English`, cada uno escrito en su propio idioma para que lo encuentre quien lo cambió por error. El actual está seleccionado y marcado como `Actual` (`Current`).
3. Elige con UP/DOWN y START, o tocando la opción. La esfera vuelve al instante en el idioma elegido. BACK cierra la lista sin cambiar nada.

La elección se guarda en `Application.Storage` y se mantiene al cerrar y volver a abrir la aplicación. Si el almacenamiento falla, la aplicación no se cierra: al leer, usa el español, y al guardar, el cambio vale hasta que se cierre.

## Pruebas unitarias

El SDK de Connect IQ incluye **Run No Evil**, un sistema de pruebas unitarias (módulo `Toybox.Test`). Por eso esta versión tiene pruebas automáticas, como la web (Vitest) y la de Wear OS (JUnit), en lugar de comprobar los valores a mano en la consola:

- Las pruebas están en `test/`. Son funciones marcadas con `(:test)` que reciben un `Logger` y devuelven `true` si pasan; usan `Test.assert` y `Test.assertEqual`.
- Traducen los casos principales de las pruebas de la versión web y la de Wear OS: almacén, generadores, motor, idioma, formato de hora, estado de batería y GPS, colores y contraste, pulsación del SOS, y la esfera con su interacción. En total, 81 pruebas.
- La esfera no se puede comprobar píxel a píxel, porque Run No Evil no permite leer la imagen dibujada. Se dibuja en una imagen fuera de pantalla de 390 × 390 y se comprueba que cada parte, medida con las fuentes reales y el texto más ancho de cada idioma, cabe en el círculo; que la vista pone los textos y colores correctos en cada estado, y que todos los estados se dibujan sin errores.
- La interacción se prueba llamando a los métodos que usan los delegados para los botones y los toques, con un reloj falso, así que la pulsación de 2 segundos no hace esperar.
- Todo lo de `test/` lleva `(:test)`, así que el compilador solo lo incluye con la opción `-t` y lo deja fuera del `.prg` normal.
- Se ejecutan **dentro del simulador**; no hay forma de ejecutarlas sin él.
- Las pruebas no pueden esperar al temporizador, así que llaman a `tick()` directamente. Que el temporizador funcione se comprueba viendo cómo cambia el pulso en la esfera del simulador.
- Recorren 1000 pasos en lugar de los 5000 de las pruebas web, porque el simulador corta el código que tarda demasiado.

Desde `garmin-app`, con el simulador abierto (`connectiq`):

```powershell
monkeyc -f monkey.jungle -d fr165 -o bin\ElderGuardAI-test.prg -y "$env:USERPROFILE\Documents\garmin\developer_key.der" -w -l 3 -t
monkeydo bin\ElderGuardAI-test.prg fr165 /t
```

La salida muestra cada prueba con `PASS`, `FAIL` o `ERROR`, y termina con un resumen como `PASSED (passed=81, failed=0, errors=0)`. Para ejecutar una sola prueba, añade su nombre después de `/t`.

## Pendientes

- **Instalación en el reloj real**: los pasos del apartado 3 aún no se han probado con el Forerunner 165 físico. Hay que confirmar la ruta de la carpeta `Apps` y dónde aparece la aplicación en el menú del reloj.
- **Permisos**: ninguno por ahora, porque la telemetría es simulada. Para leer los sensores reales harán falta `Sensor` (frecuencia cardíaca y acelerómetro) y `Positioning` (GPS) en `manifest.xml`.
- **Pulsación con el dedo en el reloj real**: el retardo de `onHold` (alrededor de 1 segundo en el simulador) puede ser distinto en el Forerunner 165 físico. Con START la pulsación siempre dura exactamente 2 segundos.
- **Forerunner 165 Music**: es otro dispositivo (`fr165m`). Si hiciera falta, se añade como otro `<iq:product>` en `manifest.xml`.
