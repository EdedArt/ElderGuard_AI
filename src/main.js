import './styles/tokens.css';
import './styles/base.css';
import { appConfig } from './config/app.config.js';

document.title = appConfig.name;
document.querySelector('#app').textContent = appConfig.name;
