import { telemetryConfig } from '../config/telemetry.config.js';
import { createEventEmitter } from '../core/eventEmitter.js';
import { scenarios } from './scenarios.js';

const AXES = ['x', 'y', 'z'];

const sensorOf = (channel) => (AXES.includes(channel) ? 'accelerometer' : channel);

const overridesSensor = (scenario, sensor) =>
  scenario.steps.some(({ setOverride }) => setOverride?.sensor === sensor);

// What the panel can do to the device, with no user interface. Every action goes through the engine
// overrides or the alert logic, so what the audience sees is the real watch reacting.
export function createDemoController({ device }) {
  const { engine, fall, scenarioRunner: runner } = device;
  const emitter = createEventEmitter();
  // Manual values by channel: heartRate, x, y or z.
  const manual = new Map();
  // Scenarios still in force after ending, by the sensor that keeps them so.
  const held = new Map();

  // Writes a reading right away and hands the sensor straight back to its generator.
  const applyOnce = (sensor, value) => {
    engine.setOverride(sensor, value);
    engine.clearOverride(sensor);
  };

  // The engine overrides a whole sensor, so an axis left on automatic sits at its resting value.
  const applyManualAccelerometer = () => {
    if (!AXES.some((axis) => manual.has(axis))) {
      engine.clearOverride('accelerometer');
      return;
    }
    const { rest } = telemetryConfig.accelerometer;
    const reading = {};
    for (const axis of AXES) reading[axis] = manual.has(axis) ? manual.get(axis) : rest[axis];
    engine.setOverride('accelerometer', reading);
  };

  const applyManual = (channel) => {
    if (sensorOf(channel) === 'accelerometer') applyManualAccelerometer();
    else if (manual.has(channel)) engine.setOverride(channel, manual.get(channel));
    else engine.clearOverride(channel);
  };

  const hasManualValue = (sensor) =>
    [...manual.keys()].some((channel) => sensorOf(channel) === sensor);

  // A held scenario is over: hands back what else it had overridden, unless someone else now uses it.
  const releaseHeld = (sensor) => {
    const scenario = held.get(sensor);
    if (!scenario) return;
    held.delete(sensor);

    const current = runner.getCurrent();
    for (const { setOverride } of scenario.steps) {
      if (!setOverride || setOverride.sensor === sensor) continue;
      const inUse =
        hasManualValue(setOverride.sensor) ||
        (current && overridesSensor(current, setOverride.sensor));
      if (!inUse) engine.clearOverride(setOverride.sensor);
    }
    emitter.emit('scenario-restored', { scenario });
  };

  // One held scenario replacing another on the same sensor restores nothing: the sensor stays held.
  runner.onStart(({ scenario }) => {
    if (scenario.holds) held.set(scenario.holds, scenario);
  });

  // Generated readings count as lying still, so a stumble cut short would turn into a fall alert.
  // A sequence left unfinished is not something the wearer did, so the detector forgets it.
  runner.onEnd(({ scenario, completed }) => {
    if (!completed && overridesSensor(scenario, 'accelerometer')) fall.resetDetector();
  });

  // A scenario takes the sensors it uses away from manual control, so the switches must not go on
  // claiming otherwise.
  runner.onStep(({ step }) => {
    if (!step.setOverride) return;
    const released = [...manual.keys()].filter(
      (channel) => sensorOf(channel) === step.setOverride.sensor,
    );
    for (const channel of released) manual.delete(channel);
    if (released.length > 0) emitter.emit('manual-change');
  });

  return {
    runScenario: (id) => runner.run(scenarios[id]),

    restoreBattery() {
      applyOnce('battery', { level: telemetryConfig.battery.startLevel });
      releaseHeld('battery');
    },

    toggleGps() {
      if (device.store.getState().gps.signal) runner.run(scenarios.gpsLost);
      else {
        applyOnce('gps', { signal: true });
        releaseHeld('gps');
      }
    },

    isManual: (channel) => manual.has(channel),

    // Taking over a sensor ends a scenario using it, which would otherwise clear the manual value.
    setManual(channel, value) {
      const current = runner.getCurrent();
      if (current && overridesSensor(current, sensorOf(channel))) runner.stop();
      manual.set(channel, value);
      applyManual(channel);
      releaseHeld(sensorOf(channel));
    },

    releaseManual(channel) {
      manual.delete(channel);
      applyManual(channel);
    },

    // Back to the state the watch started in, ending the alerts through their own logic.
    resetAll() {
      runner.stop();
      manual.clear();
      engine.clearAllOverrides();
      for (const sensor of [...held.keys()]) releaseHeld(sensor);
      fall.cancel();
      device.sos.cancel();
      device.sos.dismissRequest();
      fall.resetDetector();
      device.heartRateMonitor.reset();
      device.store.reset();
      emitter.emit('manual-change');
      emitter.emit('reset');
    },

    onManualChange: (listener) => emitter.on('manual-change', listener),
    onReset: (listener) => emitter.on('reset', listener),
    onScenarioRestored: (listener) => emitter.on('scenario-restored', listener),
  };
}
