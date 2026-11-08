import { appConfig } from '../config/app.config.js';

const { defaultSize, minSize, maxSize } = appConfig.watch;

export function clampWatchSize(size) {
  if (!Number.isFinite(size)) return defaultSize;
  return Math.min(maxSize, Math.max(minSize, size));
}

export function createWatchFrame({ size = defaultSize, content } = {}) {
  const frame = document.createElement('div');
  frame.className = 'watch-frame';
  frame.style.setProperty('--watch-size', `${clampWatchSize(size)}px`);

  const screen = document.createElement('div');
  screen.className = 'watch-frame__screen';
  if (content) screen.append(content);
  frame.append(screen);

  return frame;
}
