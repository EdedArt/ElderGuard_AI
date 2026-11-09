import './styles/tokens.css';
import './styles/base.css';
import './styles/layout.css';
import './styles/watch.css';
import './styles/watchface.css';
import { createSimulationEngine } from './core/simulationEngine.js';
import { createSosController } from './core/sosController.js';
import { createTelemetryStore } from './core/telemetryStore.js';
import { createSimulatorPanel } from './simulator/simulatorPanel.js';
import { createLanguageToggle } from './ui/languageToggle.js';
import { createPageLayout } from './ui/pageLayout.js';
import { createThemeToggle } from './ui/themeToggle.js';
import { createWatchFrame } from './ui/watchFrame.js';
import { createWatchface } from './ui/watchface.js';

const store = createTelemetryStore();
const engine = createSimulationEngine({ store });
const sos = createSosController({ store });

const { root, headerActions, watchArea, simulatorArea } = createPageLayout();
headerActions.append(createLanguageToggle(), createThemeToggle());
watchArea.append(createWatchFrame({ content: createWatchface({ store, sos }) }));
simulatorArea.append(createSimulatorPanel());
document.querySelector('#app').append(root);

engine.start();
