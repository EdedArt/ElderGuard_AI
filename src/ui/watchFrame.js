import { appConfig } from '../config/app.config.js';
import { onLanguageChange, t } from '../i18n/index.js';

const { defaultSize, minSize, maxSize } = appConfig.watch;

export function clampWatchSize(size) {
  if (!Number.isFinite(size)) return defaultSize;
  return Math.min(maxSize, Math.max(minSize, size));
}

export function createWatchFrame({ size = defaultSize } = {}) {
  const frame = document.createElement('div');
  frame.className = 'watch-frame';
  frame.style.setProperty('--watch-size', `${clampWatchSize(size)}px`);

  const screen = document.createElement('div');
  screen.className = 'watch-frame__screen';
  frame.append(screen);

  const render = () => {
    screen.textContent = t('watch.placeholder');
  };
  onLanguageChange(render);
  render();

  return frame;
}
