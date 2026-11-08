import { telemetryConfig } from '../config/telemetry.config.js';
import { nextAccelerometer } from './generators/accelerometer.js';
import { nextBattery } from './generators/battery.js';
import { nextGps } from './generators/gps.js';
import { nextHeartRate } from './generators/heartRate.js';

export function createSimulationEngine({
  store,
  config = telemetryConfig,
  random = Math.random,
  now = Date.now,
}) {
  const generators = {
    heartRate: (state) => nextHeartRate(state.heartRate, { config: config.heartRate, random }),
    accelerometer: () => nextAccelerometer({ config: config.accelerometer, random }),
    gps: (state) => nextGps(state.gps, { config: config.gps, random }),
    battery: (state) => nextBattery(state.battery, { config: config.battery }),
  };
  const overrides = new Map();
  let timer = null;

  const assertSensor = (sensor) => {
    if (!Object.hasOwn(generators, sensor)) throw new Error(`Unknown sensor: ${sensor}`);
  };

  const tick = () => {
    const state = store.getState();
    const partial = { deviceStatus: { lastUpdate: now() } };
    for (const [sensor, generate] of Object.entries(generators)) {
      partial[sensor] = overrides.has(sensor) ? overrides.get(sensor) : generate(state);
    }
    store.update(partial);
  };

  return {
    start() {
      if (timer === null) timer = setInterval(tick, config.tickIntervalMs);
    },

    stop() {
      clearInterval(timer);
      timer = null;
    },

    isRunning: () => timer !== null,

    // Applied right away so an injected event does not wait for the next tick.
    setOverride(sensor, value) {
      assertSensor(sensor);
      overrides.set(sensor, structuredClone(value));
      store.update({ [sensor]: value });
    },

    clearOverride(sensor) {
      assertSensor(sensor);
      overrides.delete(sensor);
    },

    clearAllOverrides() {
      overrides.clear();
    },
  };
}
