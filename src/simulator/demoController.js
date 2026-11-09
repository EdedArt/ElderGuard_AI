import { telemetryConfig } from '../config/telemetry.config.js';
import { scenarios } from './scenarios.js';

const overridesSensor = (scenario, sensor) =>
  scenario.steps.some(({ setOverride }) => setOverride?.sensor === sensor);

// What the panel can do to the device, with no user interface. Every action goes through the engine
// overrides or the alert logic, so what the audience sees is the real watch reacting.
export function createDemoController({ device }) {
  const { engine, fall, scenarioRunner: runner } = device;

  // Writes a reading right away and hands the sensor straight back to its generator.
  const applyOnce = (sensor, value) => {
    engine.setOverride(sensor, value);
    engine.clearOverride(sensor);
  };

  // Generated readings count as lying still, so a stumble cut short would turn into a fall alert.
  // A sequence left unfinished is not something the wearer did, so the detector forgets it.
  runner.onEnd(({ scenario, completed }) => {
    if (!completed && overridesSensor(scenario, 'accelerometer')) fall.resetDetector();
  });

  return {
    runScenario: (id) => runner.run(scenarios[id]),

    restoreBattery: () => applyOnce('battery', { level: telemetryConfig.battery.startLevel }),

    toggleGps() {
      if (device.store.getState().gps.signal) runner.run(scenarios.gpsLost);
      else applyOnce('gps', { signal: true });
    },
  };
}
