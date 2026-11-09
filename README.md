# ElderGuard AI

Simulador web de un smartwatch para la seguridad de personas mayores. Es un proyecto universitario que se puede demostrar por completo en el navegador, sin necesidad de un reloj físico.

## Funcionalidades planeadas

- Detección de caídas.
- Detección de frecuencia cardíaca anormal.
- Alertas SOS con ubicación GPS simulada.
- Panel externo para simular los datos de los sensores.
- Interfaz de alto contraste (WCAG AAA) con botones muy grandes y poco texto, pensada para personas mayores.

Estado actual: estructura base del proyecto, pantalla circular del reloj, panel del simulador (por ahora vacío), cambio de tema claro/oscuro, interfaz en español e inglés, motor de telemetría simulada, pantalla del reloj con datos en vivo y botón SOS.

## Tema e idioma

La aplicación abre en tema claro y en español, sin importar la configuración del sistema. Ambas opciones se cambian con los botones del encabezado, y la elección se conserva al recargar la página:

- **Idioma:** pulsa `ES` para español o `EN` para inglés. El botón resaltado indica el idioma actual.
- **Tema:** pulsa `Tema oscuro` o `Tema claro` (`Dark theme` o `Light theme` en inglés). El botón muestra el tema al que se va a cambiar.

## Pantalla del reloj

Todo el contenido queda dentro del área segura del círculo y se escala con el tamaño del reloj. La pantalla tiene tres zonas:

- **Arriba, estado:** batería con ícono y porcentaje, y GPS con ícono y etiqueta.
  - Batería: verde por encima de 20 %, ámbar con 20 % o menos y rojo con 10 % o menos.
  - GPS: muestra `GPS` con señal y `Sin GPS` en ámbar sin ella.
- **Centro, datos:** hora en formato de 12 horas con una etiqueta pequeña (`a. m.`/`p. m.` en español, `AM`/`PM` en inglés), fecha corta y frecuencia cardíaca. El corazón late al ritmo de las pulsaciones, salvo si el sistema pide reducir el movimiento.
- **Abajo, SOS:** botón rojo grande con la palabra `SOS` y la etiqueta `AUXILIO`.

Los lectores de pantalla solo anuncian los cambios de estado (batería baja, pérdida o recuperación del GPS), nunca cada lectura.

### Botón SOS

Para evitar activaciones accidentales, un toque simple no hace nada:

1. Mantén pulsado el botón durante 2 segundos con el dedo, el ratón o las teclas `Enter` o `Espacio`. Un anillo se va llenando alrededor del botón y, si el dispositivo lo permite, este vibra.
2. Si sueltas antes de tiempo, se cancela y el reloj muestra durante 2 segundos el recordatorio `Mantén presionado`.
3. Al completar los 2 segundos aparece la pantalla roja `Pidiendo ayuda…`. El estado `deviceStatus.mode` cambia a `sos` y se emite el evento `sos:triggered` con la hora y la ubicación.
4. El botón `Cancelar` cierra esa pantalla y devuelve el reloj al modo `monitoring`.

Por ahora no se envía ninguna alerta: el envío real se agregará en una fase posterior, escuchando ese evento.

## Arquitectura de telemetría

Como no hay un reloj físico, los datos de los sensores se simulan. Todo este código está en `src/core`, es JavaScript puro sin acceso al DOM y recibe su función aleatoria por parámetro, de modo que las pruebas son deterministas. Los valores (intervalo, rangos, ruido, ubicación y batería) se configuran en `src/config/telemetry.config.js`.

```text
Generadores ──> Motor de simulación ──> Store ──> Interfaz (suscriptores)
                       ^
                       └── Anulaciones (futuro panel de demostración)
```

- **Store (`telemetryStore.js`):** guarda el estado central y es la única fuente de datos para la interfaz. `getState()` devuelve una copia, `update(partial)` combina los cambios y avisa a los suscriptores con el estado nuevo y las claves que cambiaron, `subscribe(listener)` devuelve la función para cancelar la suscripción y `reset()` restaura el estado inicial.
- **Generadores (`generators/`):** funciones puras que calculan la siguiente lectura de cada sensor.
  - Frecuencia cardíaca: caminata aleatoria con valores enteros dentro del rango de reposo y cambios suaves.
  - Acelerómetro: valores cercanos a 1 g de magnitud total con poco ruido.
  - GPS: pequeña deriva alrededor de las coordenadas base.
  - Batería: baja una cantidad fija en cada ciclo y nunca queda por debajo de 0.
- **Motor (`simulationEngine.js`):** cada segundo ejecuta los generadores y escribe todas las lecturas en el store en una sola actualización. Se controla con `start()`, `stop()` e `isRunning()`.

### Forma del estado

```js
{
  heartRate: 70,                                 // LPM (latidos por minuto)
  accelerometer: { x: 0, y: 0, z: 1 },           // g
  gps: { lat, lng, accuracy, signal: true },     // accuracy en metros
  battery: { level: 100, charging: false },      // level de 0 a 100
  deviceStatus: { mode: 'monitoring', lastUpdate: null }, // marca de tiempo tras el primer ciclo
}
```

### Anulaciones (overrides)

El futuro panel de demostración usará las anulaciones para inyectar eventos sin tocar los generadores. Mientras un sensor (`heartRate`, `accelerometer`, `gps` o `battery`) tiene una anulación, su generador no se ejecuta y se usa el valor indicado. El valor se aplica de inmediato y los demás sensores siguen generándose con normalidad.

```js
engine.setOverride('heartRate', 150); // Simula una frecuencia cardíaca anormal
engine.setOverride('accelerometer', { x: 2.5, y: 1.8, z: 3.2 }); // Simula un impacto
engine.setOverride('gps', { signal: false }); // Valor parcial: simula la pérdida de señal

engine.clearOverride('heartRate'); // Ese sensor vuelve a generarse en el siguiente ciclo
engine.clearAllOverrides(); // Todos los sensores vuelven a generarse
```

Al quitar una anulación, la frecuencia cardíaca y el GPS regresan a su rango normal, mientras que la batería continúa bajando desde el último nivel.

## Stack

- [Vite](https://vite.dev/) con JavaScript puro (módulos ES), sin backend, frameworks ni APIs externas.
- CSS puro con propiedades personalizadas (design tokens).
- [Vitest](https://vitest.dev/) para las pruebas.
- ESLint (configuración plana) y Prettier para el análisis estático y el formato.

## Comandos

```powershell
npm install      # Instala las dependencias
npm run dev      # Inicia el servidor de desarrollo
npm test         # Ejecuta las pruebas una sola vez
npm run lint     # Revisa el código con ESLint
npm run format   # Da formato al código con Prettier
npm run build    # Genera la versión de producción en dist/
npm run preview  # Sirve localmente la versión de producción
```

## Estructura de carpetas

```text
├── public/          Archivos estáticos
├── src/
│   ├── config/      Umbrales y configuración de la aplicación
│   ├── core/        Telemetría, detectores y lógica de alertas (JS puro y testeable)
│   ├── i18n/        Traducciones al español y al inglés
│   ├── simulator/   Panel externo del simulador de sensores
│   ├── styles/      Design tokens y estilos globales
│   ├── ui/          Componentes de la interfaz del reloj
│   └── main.js      Punto de entrada
├── tests/           Pruebas unitarias
└── index.html
```
