import { createEventEmitter } from './eventEmitter.js';

const MODE_SOS = 'sos';
const MODE_MONITORING = 'monitoring';

export function createSosController({ store, now = Date.now }) {
  const emitter = createEventEmitter();

  const isActive = () => store.getState().deviceStatus.mode === MODE_SOS;

  return {
    isActive,
    on: emitter.on,
    off: emitter.off,

    trigger({ reason }) {
      if (isActive()) return;
      store.update({ deviceStatus: { mode: MODE_SOS } });
      emitter.emit('sos:triggered', { reason, timestamp: now(), gps: store.getState().gps });
    },

    // Takes back the question of whether to ask for help, if the watch is showing it.
    dismissRequest: () => emitter.emit('sos:request-dismissed'),

    cancel() {
      if (!isActive()) return;
      store.update({ deviceStatus: { mode: MODE_MONITORING } });
      emitter.emit('sos:cancelled', { timestamp: now() });
    },
  };
}
