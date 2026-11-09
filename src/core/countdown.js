import { createEventEmitter } from './eventEmitter.js';

const TICK_MS = 1000;

const browserTimer = {
  start: (callback, intervalMs) => setInterval(callback, intervalMs),
  stop: (id) => clearInterval(id),
};

// Counts down whole seconds. Ticks report the remaining seconds, from the starting value to 0.
export function createCountdown({ timer = browserTimer } = {}) {
  const emitter = createEventEmitter();
  let timerId = null;
  let remaining = 0;

  const isRunning = () => timerId !== null;

  const stop = () => {
    if (isRunning()) timer.stop(timerId);
    timerId = null;
  };

  const report = () => {
    emitter.emit('tick', remaining);
    // A tick listener may have cancelled the countdown, which must then not complete.
    if (remaining === 0 && isRunning()) {
      stop();
      emitter.emit('complete');
    }
  };

  return {
    isRunning,

    // Ignored while running, so a second start can never restart or double the countdown.
    start(seconds) {
      if (isRunning()) return;
      remaining = seconds;
      timerId = timer.start(() => {
        remaining -= 1;
        report();
      }, TICK_MS);
      report();
    },

    cancel: stop,

    onTick: (listener) => emitter.on('tick', listener),
    onComplete: (listener) => emitter.on('complete', listener),
  };
}
