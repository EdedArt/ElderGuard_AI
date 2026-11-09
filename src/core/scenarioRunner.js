import { createEventEmitter } from './eventEmitter.js';

const browserTimer = {
  start: (callback, delayMs) => setTimeout(callback, delayMs),
  stop: (id) => clearTimeout(id),
};

// Plays a scenario, a list of timed steps, through the engine overrides:
//   { id, steps: [{ atMs, setOverride: { sensor, value } }, { atMs, clearOverride: sensor }] }
//
// Steps due at 0 run right away, so an injected event does not wait for a timer. A scenario that
// ends by itself leaves in place any override it has not cleared, which is how "stay on low
// battery" is written. One that gets stopped is cut short, so it clears what it had set.
export function createScenarioRunner({ engine, timer = browserTimer }) {
  const emitter = createEventEmitter();
  let current = null;

  const apply = (run, step) => {
    if (step.setOverride) {
      engine.setOverride(step.setOverride.sensor, step.setOverride.value);
      run.overridden.add(step.setOverride.sensor);
    }
    if (step.clearOverride) {
      engine.clearOverride(step.clearOverride);
      run.overridden.delete(step.clearOverride);
    }
  };

  const advance = (run) => {
    // A step listener may have stopped this run, or replaced it with another one.
    while (current === run && run.nextIndex < run.steps.length) {
      const step = run.steps[run.nextIndex];
      if (step.atMs > run.elapsedMs) {
        run.timerId = timer.start(() => {
          run.timerId = null;
          run.elapsedMs = step.atMs;
          advance(run);
        }, step.atMs - run.elapsedMs);
        return;
      }
      run.nextIndex += 1;
      apply(run, step);
      emitter.emit('step', { scenario: run.scenario, step });
    }

    if (current === run) {
      current = null;
      emitter.emit('end', { scenario: run.scenario, completed: true });
    }
  };

  const stop = () => {
    if (current === null) return;
    const run = current;
    current = null;
    if (run.timerId !== null) timer.stop(run.timerId);
    for (const sensor of run.overridden) engine.clearOverride(sensor);
    emitter.emit('end', { scenario: run.scenario, completed: false });
  };

  return {
    // Only one at a time: a new scenario replaces the one in progress.
    run(scenario) {
      stop();
      const run = {
        scenario,
        steps: [...scenario.steps].sort((a, b) => a.atMs - b.atMs),
        nextIndex: 0,
        elapsedMs: 0,
        timerId: null,
        overridden: new Set(),
      };
      current = run;
      emitter.emit('start', { scenario });
      advance(run);
    },

    stop,

    isRunning: () => current !== null,
    getCurrent: () => current?.scenario ?? null,

    onStart: (listener) => emitter.on('start', listener),
    onStep: (listener) => emitter.on('step', listener),
    onEnd: (listener) => emitter.on('end', listener),
  };
}
