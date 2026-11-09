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

    trigger() {
      if (isActive()) return;
      store.update({ deviceStatus: { mode: MODE_SOS } });
      emitter.emit('sos:triggered', { timestamp: now(), gps: store.getState().gps });
    },

    cancel() {
      if (!isActive()) return;
      store.update({ deviceStatus: { mode: MODE_MONITORING } });
    },
  };
}
