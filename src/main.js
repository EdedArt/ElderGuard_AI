import './styles/tokens.css';
import './styles/base.css';
import './styles/layout.css';
import './styles/watch.css';
import { appConfig } from './config/app.config.js';
import { createSimulatorPanel } from './simulator/simulatorPanel.js';
import { createPageLayout } from './ui/pageLayout.js';
import { createWatchFrame } from './ui/watchFrame.js';

document.title = appConfig.name;

const { root, watchArea, simulatorArea } = createPageLayout({ title: appConfig.name });
watchArea.append(createWatchFrame());
simulatorArea.append(createSimulatorPanel());
document.querySelector('#app').append(root);
