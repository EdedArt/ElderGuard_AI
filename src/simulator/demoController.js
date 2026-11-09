import { scenarios } from './scenarios.js';

const overridesSensor = (scenario, sensor) =>
  scenario.steps.some(({ setOverride }) => setOverride?.sensor === sensor);

// What the panel can do to the device, with no user interface. Every action goes through the engine
// overrides or the alert logic, so what the audience sees is the real watch reacting.
export function createDemoController({ device }) {
  const { fall, scenarioRunner: runner } = device;

  // Generated readings count as lying still, so a stumble cut short would turn into a fall alert.
  // A sequence left unfinished is not something the wearer did, so the detector forgets it.
  runner.onEnd(({ scenario, completed }) => {
    if (!completed && overridesSensor(scenario, 'accelerometer')) fall.resetDetector();
  });

  return {
    runScenario: (id) => runner.run(scenarios[id]),
  };
}
