import { appConfig } from '../config/app.config.js';
import { onLanguageChange, t } from '../i18n/index.js';

export function createPageLayout() {
  const root = document.createElement('div');
  root.className = 'page';

  const header = document.createElement('header');
  header.className = 'page__header';
  const heading = document.createElement('h1');
  const headerActions = document.createElement('div');
  headerActions.className = 'page__header-actions';
  header.append(heading, headerActions);

  const main = document.createElement('main');
  main.className = 'page__main';
  const watchArea = document.createElement('section');
  watchArea.className = 'page__watch-area';
  const simulatorArea = document.createElement('div');
  simulatorArea.className = 'page__simulator-area';
  main.append(watchArea, simulatorArea);

  const render = () => {
    document.title = t('app.title', { name: appConfig.name });
    heading.textContent = t('header.title', { name: appConfig.name });
    watchArea.setAttribute('aria-label', t('watch.areaLabel'));
  };
  onLanguageChange(render);
  render();

  root.append(header, main);
  return { root, headerActions, watchArea, simulatorArea };
}
