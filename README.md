# ElderGuard AI

Simulador web de un smartwatch para la seguridad de personas mayores. Es un proyecto universitario que se puede demostrar por completo en el navegador, sin necesidad de un reloj físico.

## Funcionalidades

- Detección de caídas.
- Detección de frecuencia cardíaca anormal en reposo.
- Alertas a la familia con ubicación GPS, simuladas (no se hace ninguna llamada de red).
- Panel externo para simular los datos de los sensores.
- Interfaz de alto contraste (WCAG AAA) con botones muy grandes y poco texto, pensada para personas mayores.

Estado actual: versión 1.0.0, con todas las funcionalidades anteriores, tema claro/oscuro e interfaz en español e inglés.

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
4. El botón `Cancelar` cierra esa pantalla, devuelve el reloj al modo `monitoring` y emite el evento `sos:cancelled`.

Mantener pulsado es difícil con un lector de pantalla, así que existe una alternativa: un botón `Pedir ayuda` que solo se ve al recibir el foco y abre una confirmación dentro del reloj (`Sí, pedir ayuda` o `No`). Al confirmar se activa el mismo flujo de SOS.

Al activarse, se envía una alerta simulada a los contactos de emergencia y la pantalla roja los muestra junto con las coordenadas. Consulta [Alertas de emergencia](#alertas-de-emergencia).

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

La función reproduce el mismo escenario de caída que usa el panel del simulador: inyecta un impacto durante 1 segundo y luego quietud mediante las anulaciones del motor, por lo que se ejecuta el detector real de principio a fin. La cuenta regresiva aparece entre 5 y 6 segundos después de que empieza la quietud (entre 6 y 7 segundos después de llamar a la función), porque el detector exige 5 segundos de quietud y la comprueba en cada ciclo de 1 segundo. Solo existe en desarrollo y no se incluye en la versión de producción.

## Frecuencia cardíaca anormal

Un corazón rápido es normal al moverse y no preocupa si dura un momento. Por eso el reloj solo avisa cuando se mantiene alto **en reposo**. La lógica está en `src/core/heartRateAnomalyDetector.js` y, como la de las caídas, recibe el tiempo dentro de cada muestra.

Los valores están en `src/config/heartRateAnomaly.config.js`:

| Parámetro             | Valor  | Significado                                                                             |
| --------------------- | ------ | --------------------------------------------------------------------------------------- |
| `bpmThreshold`        | 120    | Por encima de este valor, la frecuencia cardíaca se considera alta.                     |
| `sustainedDurationMs` | 8000   | Tiempo que debe mantenerse alta, en reposo, para avisar.                                |
| `stillnessToleranceG` | 0,15 g | Distancia máxima a 1 g que aún se considera reposo, igual que en el detector de caídas. |

```text
              alta y en reposo
  ┌─────────┐ ───────────────> ┌───────────┐  durante 8 s  ┌─────────┐
  │ normal  │                  │ elevated  │ ────────────> │ warning │
  └─────────┘ <─────────────── └───────────┘               └─────────┘
       ^        baja o movimiento                               │
       └─────────────────────────────────────────────────────────┘
                 baja o movimiento (emite "resolved")
```

Al avisar, se emite `heartRate:anomaly` y `deviceStatus.healthAlert` pasa a `high-heart-rate`. Mientras dure, el reloj muestra en ámbar `Ritmo cardíaco alto en reposo` en el lugar de la fecha, y los lectores de pantalla lo anuncian una sola vez.

**No interrumpe nada.** `deviceStatus.mode` no cambia y este detector funciona en paralelo al de caídas, en cualquier modo. Si ocurre una caída, la cuenta regresiva cubre la pantalla y sigue su curso; al cancelarla, el aviso sigue ahí si la condición continúa.

## Alertas de emergencia

**Es una simulación: no se hace ninguna llamada de red ni se envía nada a nadie.** El despachador solo registra la alerta en memoria y avisa a la interfaz. Un sistema real sustituiría ese registro por el envío a un servicio de mensajería. Los contactos de `src/config/contacts.config.js` son ficticios, con números 555-01xx reservados para ficción.

### Qué genera una alerta

| Origen                 | Condición                                                   | Tipo              | ¿Cuenta regresiva?           |
| ---------------------- | ----------------------------------------------------------- | ----------------- | ---------------------------- |
| Caída                  | La cuenta regresiva llega a cero (`sos:triggered`, `fall`)  | `fall`            | Sí, de la caída              |
| SOS manual             | Pulsación larga o `Pedir ayuda` (`sos:triggered`, `manual`) | `manual-sos`      | No                           |
| Ritmo cardíaco crítico | Más de 160 LPM en reposo durante 8 segundos                 | `high-heart-rate` | No: es de salud, no de caída |

El ritmo crítico reutiliza el mismo detector con un umbral más alto (`criticalHeartRateConfig`), y se envía una sola alerta por episodio. No abre la pantalla de SOS ni cambia el modo del reloj: el aviso pasa a rojo y dice `Ritmo crítico: familia avisada`.

No generan alerta: un tropiezo, una caída cancelada a tiempo, un pico breve de pulso, un pulso alto en movimiento ni un aviso de 120 a 160 LPM que se resuelve.

### Contenido

`buildAlertPayload` (`src/core/alertPayload.js`) es una función pura que copia los datos del momento, de modo que una alerta registrada no cambia aunque la ubicación o la batería cambien después:

```js
{
  type: 'fall',                                  // 'fall' | 'manual-sos' | 'high-heart-rate'
  timestamp: 1794239354551,
  gps: { lat, lng, accuracy, signal },           // Sin señal, es la última posición conocida
  heartRate: 72,
  batteryLevel: 98,
  contacts: [{ name, relationship, phone }],
}
```

### Flujo

```text
sos:triggered (caída o manual) ──┐
                                 ├─> buildAlertPayload ─> registro ─> alert:dispatched ─┬─> Pantalla de SOS
Ritmo crítico sostenido ─────────┘                                                      ├─> Historial del panel
                                                                                        └─> Registro del panel
```

`src/core/alertDispatcher.js` ofrece `on(evento, función)`, `getAlerts()`, `isCriticalActive()` y `reset()`. La pantalla de SOS muestra los contactos avisados y las coordenadas enviadas, e indica `Última posición` si no hay señal de GPS.

## Panel de demostración

El panel `Modo demostración` es la herramienta del presentador. Está fuera del reloj, tiene un marco punteado y un color propio para no confundirlo con lo que ve la persona mayor, y queda debajo del reloj en pantallas angostas. Se contrae con el botón `Contraer` y recuerda ese estado al recargar.

Hasta que se toca `Toca para iniciar` en el reloj, sus controles están desactivados y muestra el aviso `Inicia el reloj primero`.

Ningún control cambia la interfaz directamente. Todos pasan por las anulaciones del motor y por la lógica real de alertas, de modo que lo que se ve en la demostración es el detector funcionando de verdad.

### Controles

**Escenarios.** Solo se ejecuta uno a la vez; iniciar otro detiene el que esté en curso.

| Control                        | Qué hace                                                                                                                                                                                                                           |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Simular caída`                | Impacto de 4,4 g durante 1 segundo y luego quietud. La cuenta regresiva aparece entre 5 y 6 segundos después de que empieza la quietud, es decir, entre 6 y 7 segundos tras pulsar.                                                |
| `Tropiezo (falsa alarma)`      | Impacto de 2,9 g seguido de movimiento normal durante 5 segundos. El detector marca `Impacto` y vuelve a `En espera` sin alertar.                                                                                                  |
| `Ritmo cardíaco alto (140)`    | Mantiene 140 LPM con el acelerómetro quieto. A los 8 o 9 segundos aparece en el reloj el aviso `Ritmo cardíaco alto en reposo`. No envía ninguna alerta.                                                                           |
| `Ritmo cardíaco crítico (170)` | Mantiene 170 LPM con el acelerómetro quieto. A los 8 o 9 segundos se envía una alerta simulada sin cuenta regresiva, y el aviso del reloj pasa a rojo: `Ritmo crítico: familia avisada`.                                           |
| `Batería baja (15 %)`          | Mantiene la batería en 15 %.                                                                                                                                                                                                       |
| `Batería crítica (5 %)`        | Mantiene la batería en 5 %.                                                                                                                                                                                                        |
| `Restaurar batería (100 %)`    | Devuelve la batería a 100 %, y esta vuelve a descargarse sola.                                                                                                                                                                     |
| `Perder GPS`                   | Quita la señal y conserva la última posición. El botón pasa a `Recuperar GPS`.                                                                                                                                                     |
| `Reiniciar todo`               | Detiene el escenario, quita todas las anulaciones, reinicia los detectores, cierra la cuenta regresiva, el SOS o la pregunta `¿Pedir ayuda?`, vacía el historial de alertas y deja el reloj en vigilancia con la batería al 100 %. |

**Sensores manuales.** Hay un deslizador para la frecuencia cardíaca (de 40 a 180 LPM) y uno para cada eje del acelerómetro (de −4 a 4 g), cada uno con su interruptor `Manual`. Con el interruptor apagado, el deslizador sigue la lectura real. Con el interruptor encendido, su valor es la lectura del sensor, y al apagarlo se vuelve a la generación automática. Los ejes del acelerómetro que sigan en automático quedan en su valor de reposo mientras otro eje esté en manual.

Los deslizadores también pasan por el detector real: llevar un eje a 4 g produce un impacto de verdad. Un escenario que use un sensor apaga el interruptor de ese sensor, y encender un interruptor detiene el escenario que esté usando el mismo sensor.

**Estado.** Muestra en vivo el estado del detector de caídas (`En espera`, `Impacto`, `Inmovilidad` o `Caída confirmada`, cada uno con su color) y todas las lecturas: frecuencia cardíaca, acelerómetro y magnitud, GPS y señal, batería y modo del reloj. El estado `Caída confirmada` se mantiene mientras dura la alerta que provocó.

**Alertas a la familia.** Lista de las alertas simuladas, de la más reciente a la más antigua, con su tipo, hora, contactos y coordenadas: lo que habría recibido la familia. Solo se vacía con `Reiniciar todo`.

**Registro.** Lista con hora, de la más reciente a la más antigua y con un máximo de 50 entradas: escenarios iniciados, terminados y detenidos, escenarios activados y restablecidos, caídas detectadas y canceladas, SOS activados con su motivo, SOS cancelados, avisos de ritmo cardíaco, alertas enviadas, cambios de batería y de GPS, y reinicios. `Borrar registro` la vacía.

Los escenarios que se mantienen en el tiempo (ritmo cardíaco, batería y GPS) se anotan como `activado` al pulsarlos, y como `restablecido` solo cuando dejan de estar en vigor, no al terminar de aplicarse.

### Atajos de teclado

El botón `?` muestra esta misma lista. Los atajos funcionan aunque el panel esté contraído, pero no antes de iniciar el reloj ni mientras se escribe en un campo de texto.

| Atajo   | Acción                 |
| ------- | ---------------------- |
| `Alt+1` | Simular caída          |
| `Alt+2` | Tropiezo               |
| `Alt+3` | Ritmo cardíaco alto    |
| `Alt+4` | Batería baja           |
| `Alt+5` | Perder o recuperar GPS |
| `Alt+6` | Ritmo cardíaco crítico |
| `Alt+0` | Reiniciar todo         |

### Guion de defensa (5 a 6 minutos)

Antes de empezar, abre la página con `npm run dev`, elige el idioma y el tema, y deja a la vista el reloj y el panel. Los únicos toques en el reloj son iniciar y las respuestas de la persona (`ESTOY BIEN` y `Cancelar`); todo lo demás se hace desde el panel.

| Tiempo | Paso                   | Qué hacer                                                                             | Qué decir o señalar                                                                                                                                                                                      |
| ------ | ---------------------- | ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0:00   | Iniciar el reloj       | Señala los controles desactivados y toca `Toca para iniciar` en el reloj.             | El primer toque desbloquea el audio y pone en marcha la telemetría.                                                                                                                                      |
| 0:20   | Lecturas normales      | No toques nada durante unos segundos.                                                 | Hora, batería, GPS y pulso en el reloj; en `Estado`, las lecturas cambian cada segundo, la magnitud ronda 1 g y el detector sigue `En espera`.                                                           |
| 0:40   | Tropiezo               | Pulsa `Tropiezo (falsa alarma)` (`Alt+2`) y espera unos 6 segundos.                   | El detector marca `Impacto` y vuelve a `En espera`. El reloj no alerta: un golpe seguido de movimiento no es una caída.                                                                                  |
| 1:10   | Caída con cancelación  | Pulsa `Simular caída` (`Alt+1`). Cuando aparezca `¿Te caíste?`, pulsa `ESTOY BIEN`.   | Secuencia `Impacto`, `Inmovilidad`, `Caída confirmada`. Hay 10 segundos para cancelar, con pitidos. Al cancelar no sale ninguna alerta: el historial sigue vacío.                                        |
| 1:50   | Caída hasta el SOS     | Pulsa `Simular caída` de nuevo y no toques nada hasta que aparezca `Pidiendo ayuda…`. | Unos 17 segundos en total. Quien no puede responder también recibe ayuda. La pantalla roja muestra los contactos avisados y las coordenadas enviadas. Aclara que es una simulación, sin llamadas de red. |
| 2:40   | Cerrar el SOS          | Pulsa `Cancelar` en el reloj.                                                         | El reloj vuelve a la vigilancia, pero la alerta queda en `Alertas a la familia`.                                                                                                                         |
| 2:55   | Ritmo cardíaco alto    | Pulsa `Ritmo cardíaco alto (140)` (`Alt+3`) y espera 8 o 9 segundos.                  | Aparece en ámbar `Ritmo cardíaco alto en reposo`. Es un aviso: el reloj sigue funcionando, no pide nada y no envía ninguna alerta. Un pico breve o el movimiento no lo activan.                          |
| 3:30   | Ritmo cardíaco crítico | Pulsa `Ritmo cardíaco crítico (170)` (`Alt+6`) y espera 8 o 9 segundos.               | El aviso pasa a rojo: `Ritmo crítico: familia avisada`. La alerta sale sola y sin cuenta regresiva, porque es de salud y no una caída.                                                                   |
| 4:10   | Batería                | Pulsa `Batería baja` (`Alt+4`) y `Batería crítica`.                                   | El indicador pasa a ámbar y a rojo. El registro anota `Escenario activado`, y `restablecido` solo al quitarlo.                                                                                           |
| 4:30   | GPS                    | Pulsa `Perder GPS` (`Alt+5`) y luego `Recuperar GPS`.                                 | El reloj muestra `Sin GPS`. Los lectores de pantalla anuncian estos cambios de estado, nunca cada lectura.                                                                                               |
| 4:50   | Historial de alertas   | Señala `Alertas a la familia`.                                                        | Hay dos alertas, la de la caída y la del ritmo crítico, con su hora, contactos y coordenadas: esto es lo que habría recibido la familia.                                                                 |
| 5:20   | Reiniciar              | Pulsa `Reiniciar todo` (`Alt+0`).                                                     | Todo vuelve al estado inicial: sin avisos, batería al 100 %, detector `En espera` e historial vacío.                                                                                                     |

## Arquitectura de telemetría

Como no hay un reloj físico, los datos de los sensores se simulan. Todo este código está en `src/core`, es JavaScript puro sin acceso al DOM y recibe su función aleatoria por parámetro, de modo que las pruebas son deterministas. Los valores (intervalo, rangos, ruido, ubicación y batería) se configuran en `src/config/telemetry.config.js`.

```text
Generadores ──> Motor de simulación ──> Store ──> Interfaz (suscriptores)
                       ^
                       └── Anulaciones (panel de demostración)
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
  deviceStatus: { mode: 'monitoring', lastUpdate: null, healthAlert: null }, // lastUpdate: marca de tiempo tras el primer ciclo; healthAlert: 'high-heart-rate' durante un aviso
}
```

### Anulaciones (overrides)

El panel de demostración usa las anulaciones para inyectar eventos sin tocar los generadores. Mientras un sensor (`heartRate`, `accelerometer`, `gps` o `battery`) tiene una anulación, su generador no se ejecuta y se usa el valor indicado. El valor se aplica de inmediato y los demás sensores siguen generándose con normalidad.

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
