# ElderGuard AI

Simulador web de un smartwatch para la seguridad de personas mayores. Es un proyecto universitario que se puede demostrar por completo en el navegador, sin necesidad de un reloj físico.

## Funcionalidades planeadas

- Detección de caídas.
- Detección de frecuencia cardíaca anormal.
- Alertas SOS con ubicación GPS simulada.
- Panel externo para simular los datos de los sensores.
- Interfaz de alto contraste (WCAG AAA) con botones muy grandes y poco texto, pensada para personas mayores.

Estado actual: estructura base del proyecto, pantalla circular del reloj, panel del simulador (por ahora vacío), cambio de tema claro/oscuro e interfaz en español e inglés.

## Tema e idioma

La aplicación abre en tema claro y en español, sin importar la configuración del sistema. Ambas opciones se cambian con los botones del encabezado, y la elección se conserva al recargar la página:

- **Idioma:** pulsa `ES` para español o `EN` para inglés. El botón resaltado indica el idioma actual.
- **Tema:** pulsa `Tema oscuro` o `Tema claro` (`Dark theme` o `Light theme` en inglés). El botón muestra el tema al que se va a cambiar.

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
