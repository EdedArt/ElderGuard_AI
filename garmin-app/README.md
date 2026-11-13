# ElderGuard AI para Garmin (Connect IQ)

Aplicación de ElderGuard AI para relojes Garmin, escrita en Monkey C con el SDK de Connect IQ. Es la versión que se instala en el **Garmin Forerunner 165** prestado para la sustentación. Es un proyecto independiente: no usa `npm` ni Gradle y no comparte código con la versión web (`src/`) ni con la de Wear OS (`wear-app/`), que sirven como especificación de lo que hay que portar.

Estado actual: estructura del proyecto. La aplicación muestra `ElderGuard AI` centrado en la pantalla, en blanco sobre negro.

Compilado y probado en el simulador con el **SDK de Connect IQ 9.3.0** para el Forerunner 165 (`fr165`, nivel de API 5.2). Aún no se ha instalado en el reloj real.

## Dispositivo

| Dato | Valor |
| ---- | ----- |
| Reloj | Garmin Forerunner 165 (identificador de producto `fr165`) |
| Pantalla | Redonda, AMOLED, táctil, 390 × 390 píxeles |
| Nivel de API de Connect IQ | 5.2 (`minApiLevel="5.2.0"` en `manifest.xml`) |
| Ícono de la aplicación | 54 × 54 píxeles |
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
│   │   └── launcher_icon.png     # Ícono de la lista de aplicaciones (54 × 54)
│   └── strings/strings.xml
└── resources-eng/                # Textos en inglés
    └── strings/strings.xml
```

Ningún texto visible está escrito en el código: todos salen de `strings.xml`. El reloj elige `resources-eng` cuando su idioma es inglés y `resources` (español) en cualquier otro caso.

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
2. `monkeydo` envía la aplicación al simulador y la abre en el Forerunner 165. El título de la ventana muestra `Forerunner® 165 (5.2.0)`, y en la pantalla del reloj aparece `ElderGuard AI` centrado, en blanco sobre negro.
3. `monkeydo` se queda abierto mostrando la salida de la aplicación (`System.println`). Pulsa `Ctrl+C` para cerrarlo. El simulador sigue abierto y se puede reutilizar: después de recompilar basta con volver a ejecutar `monkeydo`.

La primera vez, Windows puede preguntar si `simulator` puede acceder a la red. `monkeydo` se comunica con el simulador dentro del propio equipo, así que la aplicación se abre aunque no se dé ese permiso.

En el simulador, un clic en la pantalla equivale a tocarla, y los botones dibujados alrededor del reloj se pueden pulsar. El menú **Simulation** permite simular los sensores (frecuencia cardíaca, acelerómetro, GPS); se usará en las fases siguientes.

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

## Pendientes

- **Instalación en el reloj real**: los pasos del apartado 3 aún no se han probado con el Forerunner 165 físico. Hay que confirmar la ruta de la carpeta `Apps` y dónde aparece la aplicación en el menú del reloj.
- **Permisos**: ninguno por ahora. Las fases de telemetría necesitarán `Sensor` (frecuencia cardíaca y acelerómetro) y `Positioning` (GPS) en `manifest.xml`.
- **Forerunner 165 Music**: es otro dispositivo (`fr165m`). Si hiciera falta, se añade como otro `<iq:product>` en `manifest.xml`.
