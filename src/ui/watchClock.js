import { formatShortDate, formatTime } from '../core/timeFormat.js';
import { getLanguage, onLanguageChange } from '../i18n/index.js';

const UPDATE_INTERVAL_MS = 1000;

export function createWatchClock({ now = () => new Date() } = {}) {
  const root = document.createElement('div');
  root.className = 'watch-clock';

  const time = document.createElement('div');
  time.className = 'watch-clock__time';
  const date = document.createElement('div');
  date.className = 'watch-clock__date';
  root.append(time, date);

  const render = () => {
    const current = now();
    time.textContent = formatTime(current, getLanguage());
    date.textContent = formatShortDate(current, getLanguage());
  };

  onLanguageChange(render);
  setInterval(render, UPDATE_INTERVAL_MS);
  render();

  return root;
}
