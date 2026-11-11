# ElderGuard AI para Garmin (Connect IQ)

Aplicación de ElderGuard AI para relojes Garmin, escrita en Monkey C con el SDK de Connect IQ. Es la versión que se instala en el **Garmin Forerunner 165** prestado para la sustentación. Es un proyecto independiente: no usa `npm` ni Gradle y no comparte código con la versión web (`src/`) ni con la de Wear OS (`wear-app/`), que sirven como especificación de lo que hay que portar.

Estado actual: estructura del proyecto. La aplicación muestra `ElderGuard AI` centrado en la pantalla, en blanco sobre negro.

> **Aún no se ha compilado.** El SDK de Connect IQ no estaba instalado cuando se creó esta estructura. La primera compilación puede requerir pequeños ajustes; ver _Pendientes_ al final.

## Dispositivo

| Dato | Valor |
| ---- | ----- |
| Reloj | Garmin Forerunner 165 (identificador de producto `fr165`) |
| Pantalla | Redonda, AMOLED, táctil, 390 × 390 píxeles |
| Sensores | Acelerómetro, frecuencia cardíaca óptica, GPS |

## Estructura

```text
garmin-app/
├── manifest.xml                  # Tipo de aplicación, dispositivo, idiomas, permisos e ID
├── monkey.jungle                 # Configuración de compilación
├── source/
│   ├── App.mc                    # Clase ElderGuardApp (Application.AppBase): punto de entrada
│   └── MainView.mc               # Clase MainView (WatchUi.View): primera pantalla
├── resources/                    # Recursos por defecto, en español
│   ├── drawables/
│   │   ├── drawables.xml
│   │   └── launcher_icon.png     # Ícono de la lista de aplicaciones
│   └── strings/strings.xml
└── resources-eng/                # Textos en inglés
    └── strings/strings.xml
```

Ningún texto visible está escrito en el código: todos salen de `strings.xml`. El reloj elige `resources-eng` cuando su idioma es inglés y `resources` (español) en cualquier otro caso.

## Requisitos

Se instalan una sola vez:

1. **[Visual Studio Code](https://code.visualstudio.com/)**.
2. **Java**: el compilador de Monkey C funciona con Java. Si no está instalado, instala un JDK reciente (por ejemplo, [Eclipse Temurin](https://adoptium.net/) 17 o superior).
3. **SDK Manager de Connect IQ**: descárgalo desde la página del SDK en [developer.garmin.com/connect-iq](https://developer.garmin.com/connect-iq/sdk/), ábrelo e inicia sesión con una cuenta de Garmin.
   - En la pestaña **SDK**, descarga la versión más reciente y márcala como activa.
   - En la pestaña **Devices**, busca **Forerunner 165** y descárgalo. Sin este paso, ni el simulador ni la compilación conocen el reloj.
4. **Extensión Monkey C** para VS Code, publicada por Garmin: en VS Code abre **Extensiones** (`Ctrl+Shift+X`), busca `Monkey C` e instálala.
5. **Clave de desarrollador**: Connect IQ firma cada compilación. En VS Code pulsa `Ctrl+Shift+P` y ejecuta **Monkey C: Generate a Developer Key**. Guárdala **fuera del repositorio** (por ejemplo, en `Documentos\garmin\developer_key.der`); `.gitignore` ignora cualquier clave dentro de `garmin-app/`, pero no debe subirse nunca.
6. Comprueba la instalación con **Monkey C: Verify Installation** (`Ctrl+Shift+P`). Debe encontrar el SDK, Java y la clave.

## 1. Abrir el proyecto en VS Code

1. **File > Open Folder…** y elige la carpeta **`garmin-app`** dentro del repositorio.
   - **No** abras la raíz del repositorio: la extensión busca `manifest.xml` y `monkey.jungle` en la carpeta abierta.
2. La extensión se activa sola al ver los archivos `.mc`. Si es la primera vez, puede pedir la ruta de la clave de desarrollador: indica la que generaste.
3. **Una sola vez, antes de la primera compilación:** genera el ID real de la aplicación con `Ctrl+Shift+P` > **Monkey C: Regenerate UUID** (nombre por confirmar con el SDK instalado). Sustituye el ID provisional `00000000000000000000000000000000` de `manifest.xml`. Haz commit del cambio: el ID debe ser siempre el mismo para que el reloj reconozca la aplicación como la misma.

## 2. Elegir el Forerunner 165

El reloj ya está elegido en `manifest.xml` (`<iq:product id="fr165"/>`). Para comprobarlo o cambiarlo:

1. `Ctrl+Shift+P` > **Monkey C: Edit Products**.
2. Marca **Forerunner 165** y desmarca cualquier otro.

Si el Forerunner 165 no aparece en la lista, falta descargarlo en la pestaña **Devices** del SDK Manager.

## 3. Compilar y ejecutar en el simulador

Es el equivalente del botón **Run** de Android Studio en `wear-app`.

1. Abre `source/App.mc` (cualquier archivo `.mc` sirve).
2. Pulsa **Run > Run Without Debugging** (`Ctrl+F5`), o **Run > Start Debugging** (`F5`) para depurar.
3. Si pregunta por el dispositivo, elige **Forerunner 165**.
4. La extensión compila el proyecto y abre el **simulador de Connect IQ**, una ventana con la imagen del reloj. La aplicación se abre sola y muestra `ElderGuard AI` en el centro.
5. Los errores de compilación aparecen en el panel **Problems** (`Ctrl+Shift+M`) y en la terminal.

En el simulador:

- Un clic en la pantalla equivale a tocarla, y los botones laterales del reloj dibujado se pueden pulsar.
- **Settings > Language** cambia el idioma del reloj simulado, para ver los textos en inglés.
- El menú **Simulation** permite simular los sensores (frecuencia cardíaca, acelerómetro, GPS). Se usará en las fases siguientes.

## 4. Instalar en el reloj por USB (sustentación)

1. `Ctrl+Shift+P` > **Monkey C: Build for Device** y elige **Forerunner 165**. Pide una carpeta de salida: elige `garmin-app/bin`, que Git ignora. Genera el archivo `ElderGuardAI.prg` (el nombre puede variar).
2. Conecta el reloj al computador con su cable USB. En Windows aparece como dispositivo portátil **Forerunner 165** en el Explorador de archivos (no como unidad con letra).
3. Abre **Forerunner 165 > Internal Storage > GARMIN > Apps** y copia ahí el archivo `.prg`.
4. Expulsa el reloj desde el Explorador y desconéctalo. El reloj instala la aplicación al desconectarse.
5. En el reloj, abre la lista de aplicaciones y busca **ElderGuard AI** (en el Forerunner 165, desde la esfera, botón de inicio y luego el menú de actividades y aplicaciones; la ruta exacta depende del firmware).

Para actualizarla, repite los pasos: el `.prg` nuevo reemplaza al anterior mientras el ID de la aplicación no cambie. Para desinstalarla, borra el `.prg` de `GARMIN/Apps`.

Antes de la sustentación conviene hacer una prueba completa en el reloj real, porque el simulador no reproduce exactamente el rendimiento, los sensores ni el brillo de la pantalla AMOLED.

## Pendientes

Valores que dependen del SDK o de la cuenta de Garmin y deben revisarse en la primera compilación:

- **ID de la aplicación** (`manifest.xml`): es provisional. Generarlo como se indica en el paso 1.
- **`minApiLevel`** (`manifest.xml`): `3.2.0` es una estimación conservadora. Comprobar en el SDK Manager el nivel de API que admite el Forerunner 165.
- **Identificador del producto**: `fr165`. Confirmar que coincide con la carpeta del dispositivo en el SDK (existe también una variante con música, que tendría otro identificador).
- **Permisos**: ninguno por ahora. Las fases de telemetría necesitarán `Sensor` (frecuencia cardíaca y acelerómetro) y `Positioning` (GPS).
- **Ícono**: `launcher_icon.png` mide 70 × 70 píxeles. Si el compilador avisa de otro tamaño para el Forerunner 165, ajustarlo.
- **Nombres de comandos y menús**: algunos nombres de comandos de la extensión y de menús del reloj de esta guía no se han podido comprobar sin el SDK; confirmarlos y corregir esta guía.
