import { onLanguageChange, t } from '../i18n/index.js';

const HEALTH_ALERT_HIGH = 'high-heart-rate';

const WARNING_ICON = `
  <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
    <path fill="currentColor" fill-rule="evenodd" d="M12 2 1 21h22L12 2Zm-1.250 7h2.500v6.500h-2.500V9Zm0 8h2.500v2.500h-2.500V17Z" />
  </svg>
`;

// A warning, not an alert: the wearer can read it and go on, and everything else keeps working.
export function createHeartRateBanner({ store, announce }) {
  const root = document.createElement('div');
  root.className = 'heart-rate-banner';

  const icon = document.createElement('span');
  icon.className = 'heart-rate-banner__icon';
  icon.innerHTML = WARNING_ICON;
  const text = document.createElement('span');
  root.append(icon, text);

  let active = false;

  const renderText = () => {
    text.textContent = t('watch.heartRateAlert.high');
  };

  const render = ({ deviceStatus }) => {
    const nextActive = deviceStatus.healthAlert === HEALTH_ALERT_HIGH;
    root.hidden = !nextActive;
    // Through the page's status announcer, which stays readable while an alert covers the watch.
    if (nextActive && !active) announce(text.textContent);
    active = nextActive;
  };

  store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('deviceStatus')) render(state);
  });
  onLanguageChange(renderText);
  renderText();
  render(store.getState());

  return root;
}
