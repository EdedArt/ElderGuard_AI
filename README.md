# ElderGuard AI

Simulador web de un smartwatch para la seguridad de personas mayores. Es un proyecto universitario que se puede demostrar por completo en el navegador, sin necesidad de un reloj físico.

## Funcionalidades planeadas

- Detección de caídas.
- Detección de frecuencia cardíaca anormal.
- Alertas SOS con ubicación GPS simulada.
- Panel externo para simular los datos de los sensores.
- Interfaz de alto contraste (WCAG AAA) con botones muy grandes y poco texto, pensada para personas mayores.

Estado actual: estructura base del proyecto, pantalla circular del reloj, panel del simulador (por ahora vacío), cambio de tema claro/oscuro, interfaz en español e inglés, motor de telemetría simulada, pantalla del reloj con datos en vivo, botón SOS y detección de caídas con cuenta regresiva.

## Tema e idioma

La aplicación abre en tema claro y en español, sin importar la configuración del sistema. Ambas opciones se cambian con los botones del encabezado, y la elección se conserva al recargar la página:

- **Idioma:** pulsa `ES` para español o `EN` para inglés. El botón resaltado indica el idioma actual.
- **Tema:** pulsa `Tema oscuro` o `Tema claro` (`Dark theme` o `Light theme` en inglés). El botón muestra el tema al que se va a cambiar.

## Pantalla de inicio

Al abrir la página, el reloj muestra el botón `Toca para iniciar`. Los navegadores no permiten reproducir sonido hasta que la persona interactúa con la página, y la alerta de caída necesita el suyo, así que ese primer toque desbloquea el audio. También es lo que pone en marcha la telemetría: antes de tocarlo no se generan lecturas. Los botones de tema e idioma están fuera del reloj y se pueden usar en todo momento.

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
3. Al completar los 2 segundos aparece la pantalla roja `Pidiendo ayuda…`. El estado `deviceStatus.mode` cambia a `sos` y se emite el evento `sos:triggered` con el motivo (`reason`, que es `manual` en este caso y `fall` si viene de una caída), la hora y la ubicación.
4. El botón `Cancelar` cierra esa pantalla y devuelve el reloj al modo `monitoring`.

Mantener pulsado es difícil con un lector de pantalla, así que existe una alternativa: un botón `Pedir ayuda` que solo se ve al recibir el foco y abre una confirmación dentro del reloj (`Sí, pedir ayuda` o `No`). Al confirmar se activa el mismo flujo de SOS.

Por ahora no se envía ninguna alerta: el envío real se agregará en una fase posterior, escuchando ese evento.

## Detección de caídas

El reloj analiza el acelerómetro para reconocer una caída. La lógica está en `src/core`: es JavaScript puro, no usa el DOM y recibe el tiempo dentro de cada muestra, de modo que cualquier escenario se puede reproducir en una prueba.

### Magnitud de la aceleración

El reloj puede estar en cualquier posición, así que no se analiza cada eje por separado, sino la aceleración total:

```text
magnitud = √(x² + y² + z²)
```

En reposo, la magnitud es de aproximadamente 1 g (la gravedad), sea cual sea la orientación del reloj.

### Umbrales

Están en `src/config/fallDetection.config.js`:

| Parámetro                 | Valor  | Significado                                                        |
| ------------------------- | ------ | ------------------------------------------------------------------ |
| `impactThresholdG`        | 2,5 g  | Magnitud mínima que se considera un impacto.                       |
| `immobilityToleranceG`    | 0,15 g | Distancia máxima a 1 g que aún se considera quietud (0,85 a 1,15). |
| `immobilityDurationMs`    | 5000   | Tiempo que debe durar la quietud para confirmar la caída.          |
| `immobilityStartWindowMs` | 3000   | Tiempo máximo tras el impacto para que empiece la quietud.         |
| `countdownSeconds`        | 10     | Tiempo que tiene la persona para cancelar la alerta.               |
| `urgentSeconds`           | 3      | Últimos segundos, en los que la alerta se vuelve más insistente.   |

### Máquina de estados

```text
                     magnitud ≥ 2,5 g
        ┌────────┐ ─────────────────────> ┌──────────┐
   ┌──> │  idle  │                        │  impact  │ <──┐
   │    └────────┘ <───────────────────── └──────────┘    │
   │         ^      pasan más de 3 s          │           │ nuevo impacto
   │         │      sin quietud               │ quietud   │ (≥ 2,5 g)
   │         │                                │ a tiempo  │
   │         │ movimiento                     v           │
   │         │ (fuera de 1 g ± 0,15)   ┌──────────────┐   │
   │         └──────────────────────── │  immobility  │ ──┘
   │                                   └──────────────┘
   │ reset()                                  │
   │                                          │ quietud durante 5 s
   │                                          v
   │                                   ┌─────────────┐
   └────────────────────────────────── │  confirmed  │
                                       └─────────────┘
```

- **`idle`:** vigilancia normal. Solo un impacto hace avanzar al detector; la quietud por sí sola no significa nada.
- **`impact`:** hubo un golpe. La quietud debe empezar en los siguientes 3 segundos; si no, se descarta y se vuelve a `idle`.
- **`immobility`:** la persona está quieta. Cualquier movimiento devuelve a `idle`; un nuevo impacto reinicia la secuencia desde ese momento, para no perder una caída real después de un tropiezo.
- **`confirmed`:** la quietud duró 5 segundos. El detector ignora las muestras hasta que se llama a `reset()`.

La API es `process(muestra)`, `getState()`, `reset()` y `onConfirmed(función)`. Cada muestra tiene la forma `{ accelerometer, timestamp }`.

### Por qué se exigen el impacto y la inmovilidad

Cada señal por separado aparece muchas veces al día en una vida normal, y una falsa alarma constante haría que la persona dejara de confiar en el reloj o de usarlo. Solo la combinación de ambas describe una caída: un golpe fuerte seguido de una persona que ya no se mueve.

| Situación                                   | Impacto | Inmovilidad | ¿Alerta? |
| ------------------------------------------- | ------- | ----------- | -------- |
| Caída real                                  | Sí      | Sí          | Sí       |
| Golpear la mano con la mesa y seguir        | Sí      | No          | No       |
| Dormir, ver televisión, descansar           | No      | Sí          | No       |
| Sentarse despacio                           | No      | Sí          | No       |
| Golpe, varios segundos de actividad y calma | Sí      | Tarde       | No       |

### Ventana de 10 segundos para cancelar

Aun con ambas condiciones puede haber falsos positivos, por ejemplo si el reloj cae sobre una mesa mientras nadie lo lleva puesto. Por eso, una caída confirmada no pide ayuda de inmediato:

1. `deviceStatus.mode` cambia a `fall-countdown` y se emite el evento `fall:detected`.
2. El reloj muestra `¿Te caíste?`, los segundos restantes, un anillo que se vacía y el botón `ESTOY BIEN`. Suena un pitido cada segundo y, si el dispositivo lo permite, vibra.
3. En los últimos 3 segundos, la pantalla pasa a rojo y los pitidos son más agudos y más rápidos.
4. Si la persona pulsa `ESTOY BIEN`, se emite `fall:cancelled`, el detector se reinicia y el reloj vuelve a `monitoring`.
5. Si llega a cero, se abre la pantalla de SOS y se emite `sos:triggered` con `reason: 'fall'`. Esta espera protege también a quien no puede responder, porque la alerta sale sola.

Mientras hay una cuenta regresiva o un SOS activo, el detector no procesa muestras, de modo que no puede iniciarse una segunda alerta encima de la primera.

Para los lectores de pantalla, el foco pasa al botón `ESTOY BIEN`, que también responde a `Enter` y `Espacio`. Se anuncia solo una vez al inicio y en cada uno de los últimos 3 segundos, para no tapar lo demás con un número cada segundo.

### Probar una caída en desarrollo

Con `npm run dev`, después de tocar `Toca para iniciar`, se puede ejecutar esto en la consola del navegador:

```js
window.elderguard.simulateFall();
```

La función inyecta un impacto y luego quietud mediante las anulaciones del motor, por lo que se ejecuta el detector real de principio a fin: la cuenta regresiva aparece entre 5 y 6 segundos después, porque el detector exige 5 segundos de quietud y la comprueba en cada ciclo de 1 segundo. Solo existe en desarrollo y no se incluye en la versión de producción. El panel del simulador la reemplazará en la demostración.

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
