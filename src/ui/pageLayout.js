export function createPageLayout({ title }) {
  const root = document.createElement('div');
  root.className = 'page';

  const header = document.createElement('header');
  header.className = 'page__header';
  const heading = document.createElement('h1');
  heading.textContent = title;
  const headerActions = document.createElement('div');
  headerActions.className = 'page__header-actions';
  header.append(heading, headerActions);

  const main = document.createElement('main');
  main.className = 'page__main';
  const watchArea = document.createElement('section');
  watchArea.className = 'page__watch-area';
  watchArea.setAttribute('aria-label', 'Smartwatch');
  const simulatorArea = document.createElement('div');
  simulatorArea.className = 'page__simulator-area';
  main.append(watchArea, simulatorArea);

  root.append(header, main);
  return { root, headerActions, watchArea, simulatorArea };
}
