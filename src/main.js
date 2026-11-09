import './styles/tokens.css';
import './styles/base.css';
import './styles/layout.css';
import './styles/watch.css';
import './styles/watchface.css';
import './styles/simulator.css';
import { createDevice } from './core/device.js';
import { createFallSimulation } from './simulator/fallSimulation.js';
import { createSimulatorPanel } from './simulator/simulatorPanel.js';
import { createLanguageToggle } from './ui/languageToggle.js';
import { createPageLayout } from './ui/pageLayout.js';
import { createThemeToggle } from './ui/themeToggle.js';
import { createWatchFrame } from './ui/watchFrame.js';
import { createWatchface } from './ui/watchface.js';

const device = createDevice();

const { root, headerActions, watchArea, simulatorArea } = createPageLayout();
headerActions.append(createLanguageToggle(), createThemeToggle());
watchArea.append(
  createWatchFrame({ content: createWatchface({ ...device, onStart: device.start }) }),
);
simulatorArea.append(createSimulatorPanel({ device }));
document.querySelector('#app').append(root);

// Removed from production builds. The simulator panel will take over this job for the demo.
if (import.meta.env.DEV) {
  window.elderguard = createFallSimulation({ engine: device.engine });
}
