import { onLanguageChange, t } from '../i18n/index.js';

const TITLE_ID = 'sos-screen-title';
const DETAILS_ID = 'sos-screen-details';
const COORDINATE_DECIMALS = 5;
const SOS_ALERT_TYPES = ['fall', 'manual-sos'];

const contactNames = ({ contacts }) => contacts.map(({ name }) => name).join(', ');

function locationText({ gps }) {
  return t(gps.signal ? 'sos.location' : 'sos.lastLocation', {
    lat: gps.lat.toFixed(COORDINATE_DECIMALS),
    lng: gps.lng.toFixed(COORDINATE_DECIMALS),
  });
}

export function createSosScreen({ store, alerts, announce, onCancel, lock, returnFocusTo }) {
  const root = document.createElement('div');
  root.className = 'sos-screen';
  root.setAttribute('role', 'alertdialog');
  root.setAttribute('aria-modal', 'true');
  root.setAttribute('aria-labelledby', TITLE_ID);
  root.setAttribute('aria-describedby', DETAILS_ID);

  const title = document.createElement('p');
  title.id = TITLE_ID;
  title.className = 'sos-screen__title';

  const details = document.createElement('div');
  details.id = DETAILS_ID;
  details.className = 'sos-screen__details';
  const notifiedLabel = document.createElement('p');
  const notifiedNames = document.createElement('p');
  notifiedNames.className = 'sos-screen__contacts';
  const location = document.createElement('p');
  location.className = 'sos-screen__location';
  details.append(notifiedLabel, notifiedNames, location);

  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'sos-screen__cancel';
  cancel.addEventListener('click', onCancel);
  root.append(title, details, cancel);

  let active = false;
  let alert = null;

  const renderDetails = () => {
    details.hidden = alert === null;
    if (alert === null) return;
    notifiedLabel.textContent = t('sos.notified');
    // One element per name, so a line never breaks in the middle of one.
    notifiedNames.replaceChildren(
      ...alert.contacts
        .map(({ name }, index) => {
          const contact = document.createElement('span');
          contact.className = 'sos-screen__contact';
          contact.textContent = name;
          return index === 0 ? contact : [', ', contact];
        })
        .flat(),
    );
    location.textContent = locationText(alert);
  };

  const render = ({ deviceStatus }) => {
    const nextActive = deviceStatus.mode === 'sos';
    root.hidden = !nextActive;
    lock.set('sos', nextActive);

    if (nextActive !== active) (nextActive ? cancel : returnFocusTo).focus();
    active = nextActive;

    // The next SOS must not show this one's details while its own alert is on the way.
    if (!nextActive && alert !== null) {
      alert = null;
      renderDetails();
    }
  };
  const renderText = () => {
    title.textContent = t('sos.active');
    cancel.textContent = t('sos.cancel');
    renderDetails();
  };

  store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('deviceStatus')) render(state);
  });
  // A health alert sent during an SOS is not what this screen is reporting.
  alerts.on('alert:dispatched', (dispatched) => {
    if (!SOS_ALERT_TYPES.includes(dispatched.type)) return;
    alert = dispatched;
    renderDetails();
    // The dialog had the focus before this text existed, so nothing has read it out yet.
    announce(t('sos.notifiedAnnounce', { names: contactNames(alert) }));
  });
  onLanguageChange(renderText);
  render(store.getState());
  renderText();

  return root;
}
