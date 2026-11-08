import './styles/tokens.css';
import './styles/base.css';
import './styles/layout.css';
import { appConfig } from './config/app.config.js';
import { createSimulatorPanel } from './simulator/simulatorPanel.js';
import { createPageLayout } from './ui/pageLayout.js';

document.title = appConfig.name;

const { root, simulatorArea } = createPageLayout({ title: appConfig.name });
simulatorArea.append(createSimulatorPanel());
document.querySelector('#app').append(root);
