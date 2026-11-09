import { formatShortDate, formatTime } from '../core/timeFormat.js';
import { getLanguage, onLanguageChange, t } from '../i18n/index.js';

const UPDATE_INTERVAL_MS = 1000;

export function createWatchClock({ now = () => new Date() } = {}) {
  const root = document.createElement('div');
  root.className = 'watch-clock';
  root.setAttribute('role', 'timer');

  const reading = document.createElement('div');
  reading.className = 'watch-clock__reading';
  const time = document.createElement('span');
  time.className = 'watch-clock__time';
  const period = document.createElement('span');
  period.className = 'watch-clock__period';
  reading.append(time, period);
  const date = document.createElement('div');
  date.className = 'watch-clock__date';
  root.append(reading, date);

  const render = () => {
    const current = now();
    const formatted = formatTime(current);
    time.textContent = formatted.time;
    period.textContent = t(`watch.clock.${formatted.period}`);
    date.textContent = formatShortDate(current, getLanguage());
    root.setAttribute('aria-label', t('watch.clock.label'));
  };

  onLanguageChange(render);
  setInterval(render, UPDATE_INTERVAL_MS);
  render();

  return root;
}
