import { onLanguageChange, t } from '../i18n/index.js';

const HEALTH_ALERT_HIGH = 'high-heart-rate';

const WARNING_ICON = `
  <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
    <path fill="currentColor" fill-rule="evenodd" d="M12 2 1 21h22L12 2Zm-1.250 7h2.500v6.500h-2.500V9Zm0 8h2.500v2.500h-2.500V17Z" />
  </svg>
`;

function bannerLevel({ deviceStatus }, alerts) {
  if (alerts.isCriticalActive()) return 'critical';
  return deviceStatus.healthAlert === HEALTH_ALERT_HIGH ? 'high' : null;
}

// A warning, not an alert: the wearer can read it and go on, and everything else keeps working.
// It is also the only place where the wearer learns that a critical alert went out, since that one
// has no screen of its own.
export function createHeartRateBanner({ store, alerts, announce }) {
  const root = document.createElement('div');
  root.className = 'heart-rate-banner';

  const icon = document.createElement('span');
  icon.className = 'heart-rate-banner__icon';
  icon.innerHTML = WARNING_ICON;
  const text = document.createElement('span');
  root.append(icon, text);

  let level = null;

  const renderText = () => {
    text.textContent = level === null ? '' : t(`watch.heartRateAlert.${level}`);
  };

  const render = (state) => {
    const nextLevel = bannerLevel(state, alerts);
    if (nextLevel === level) return;
    level = nextLevel;

    root.hidden = level === null;
    root.classList.toggle('heart-rate-banner--critical', level === 'critical');
    renderText();
    // Through the page's status announcer, which stays readable while an alert covers the watch.
    if (level !== null) announce(text.textContent);
  };

  // On every change: the critical state can end with nothing but the heart rate changing.
  store.subscribe(render);
  onLanguageChange(renderText);
  root.hidden = true;
  render(store.getState());

  return root;
}
