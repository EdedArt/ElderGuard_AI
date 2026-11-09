import { onLanguageChange, t } from '../i18n/index.js';
import { alertLocationText } from '../ui/alertLocation.js';
import { formatTime } from './eventLog.js';

function contactText({ name, relationship }) {
  return t('simulator.alerts.contact', {
    name,
    relationship: t(`contacts.relationship.${relationship}`),
  });
}

function createEntry(alert) {
  const item = document.createElement('li');
  item.className = 'alert-history__entry';
  item.dataset.type = alert.type;

  const heading = document.createElement('p');
  heading.className = 'alert-history__heading';
  const type = document.createElement('span');
  type.textContent = t(`simulator.alerts.type.${alert.type}`);
  const time = document.createElement('time');
  time.textContent = formatTime(alert.timestamp);
  heading.append(type, time);

  const contacts = document.createElement('p');
  contacts.textContent = alert.contacts.map(contactText).join(', ');
  const location = document.createElement('p');
  location.textContent = alertLocationText(alert);

  item.append(heading, contacts, location);
  return item;
}

// What would have gone to the family, apart from the log of everything that happened.
export function createAlertHistory({ alerts }) {
  const root = document.createElement('div');
  root.className = 'alert-history';

  const empty = document.createElement('p');
  empty.className = 'alert-history__empty';
  const list = document.createElement('ol');
  list.className = 'alert-history__list';
  // The list scrolls, which a keyboard user can only do once it can take the focus.
  list.tabIndex = 0;
  root.append(empty, list);

  const render = () => {
    const recorded = alerts.getAlerts();
    list.setAttribute('aria-label', t('simulator.sections.alerts'));
    empty.textContent = t('simulator.alerts.empty');
    empty.hidden = recorded.length > 0;
    list.hidden = recorded.length === 0;
    list.replaceChildren(...recorded.reverse().map(createEntry));
  };

  alerts.on('alert:dispatched', render);
  alerts.on('alerts:cleared', render);
  onLanguageChange(render);
  render();

  return root;
}
