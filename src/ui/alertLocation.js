import { t } from '../i18n/index.js';

const COORDINATE_DECIMALS = 5;

// Where an alert says the person is, which may only be the last position known.
export function alertLocationText({ gps }) {
  return t(gps.signal ? 'sos.location' : 'sos.lastLocation', {
    lat: gps.lat.toFixed(COORDINATE_DECIMALS),
    lng: gps.lng.toFixed(COORDINATE_DECIMALS),
  });
}
