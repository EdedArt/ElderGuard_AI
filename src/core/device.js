import { createAudioPlayer } from './audioPlayer.js';
import { createCountdown } from './countdown.js';
import { createEventEmitter } from './eventEmitter.js';
import { createFallMonitor } from './fallMonitor.js';
import { createHeartRateMonitor } from './heartRateMonitor.js';
import { createScenarioRunner } from './scenarioRunner.js';
import { createSimulationEngine } from './simulationEngine.js';
import { createSosController } from './sosController.js';
import { createTelemetryStore } from './telemetryStore.js';

// Everything the watch runs on, wired together, with no user interface.
export function createDevice({ createAudioContext } = {}) {
  const emitter = createEventEmitter();
  const store = createTelemetryStore();
  const engine = createSimulationEngine({ store });
  const sos = createSosController({ store });
  const countdown = createCountdown();
  const fall = createFallMonitor({ store, sos, countdown });
  const heartRateMonitor = createHeartRateMonitor({ store });
  const audio = createAudioPlayer({ createContext: createAudioContext });
  const scenarioRunner = createScenarioRunner({ engine });

  countdown.onTick(audio.playCountdownBeep);

  return {
    store,
    engine,
    sos,
    countdown,
    fall,
    heartRateMonitor,
    audio,
    scenarioRunner,

    // Call this from a user gesture, which the browser requires to allow audio.
    start() {
      audio.unlock();
      engine.start();
      emitter.emit('started');
    },

    onStart: (listener) => emitter.on('started', listener),
  };
}
