import { contactsConfig } from '../config/contacts.config.js';
import { batteryPercent } from './watchStatus.js';

const TYPE_BY_REASON = Object.freeze({
  fall: 'fall',
  manual: 'manual-sos',
  'high-heart-rate': 'high-heart-rate',
});

// What the family would receive. Pure, and a copy of everything: a recorded alert must keep saying
// what was true when it went out, whatever happens to the state afterwards.
export function buildAlertPayload({ state, reason, timestamp, contacts = contactsConfig }) {
  if (!Object.hasOwn(TYPE_BY_REASON, reason)) throw new Error(`Unknown alert reason: ${reason}`);

  return {
    type: TYPE_BY_REASON[reason],
    timestamp,
    gps: structuredClone(state.gps),
    heartRate: state.heartRate,
    batteryLevel: batteryPercent(state.battery.level),
    contacts: structuredClone(contacts),
  };
}
