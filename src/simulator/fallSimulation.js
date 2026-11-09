import { createScenarioRunner } from '../core/scenarioRunner.js';
import { scenarios } from './scenarios.js';

// Development helper. It plays the same fall scenario as the panel, so there is only one fall.
export function createFallSimulation({ engine, runner = createScenarioRunner({ engine }) }) {
  return {
    simulateFall() {
      if (!engine.isRunning()) {
        console.warn('simulateFall: tap the start button on the watch first.');
        return false;
      }

      runner.run(scenarios.fall);
      return true;
    },
  };
}
