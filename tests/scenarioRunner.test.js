import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createScenarioRunner } from '../src/core/scenarioRunner.js';

const set = (atMs, sensor, value) => ({ atMs, setOverride: { sensor, value } });
const clear = (atMs, sensor) => ({ atMs, clearOverride: sensor });

// Fires only when told to, and keeps track of what is still pending.
function createManualTimer() {
  const pending = new Map();
  let nextId = 1;
  return {
    pending,
    start(callback, delayMs) {
      const id = nextId;
      nextId += 1;
      pending.set(id, { callback, delayMs });
      return id;
    },
    stop: (id) => pending.delete(id),
    fireNext() {
      const [id, { callback, delayMs }] = pending.entries().next().value;
      pending.delete(id);
      callback();
      return delayMs;
    },
  };
}

let engine;
let timer;
let runner;

beforeEach(() => {
  engine = { setOverride: vi.fn(), clearOverride: vi.fn() };
  timer = createManualTimer();
  runner = createScenarioRunner({ engine, timer });
});

describe('run', () => {
  it('applies the steps due at 0 right away', () => {
    runner.run({ id: 'a', steps: [set(0, 'heartRate', 140)] });
    expect(engine.setOverride).toHaveBeenCalledWith('heartRate', 140);
  });

  it('keeps later steps waiting until their time, using the gap between steps', () => {
    runner.run({
      id: 'a',
      steps: [set(0, 'heartRate', 140), set(1000, 'heartRate', 150), clear(2500, 'heartRate')],
    });
    expect(engine.setOverride).toHaveBeenCalledTimes(1);
    expect(engine.clearOverride).not.toHaveBeenCalled();

    expect(timer.fireNext()).toBe(1000);
    expect(engine.setOverride).toHaveBeenLastCalledWith('heartRate', 150);
    expect(engine.clearOverride).not.toHaveBeenCalled();

    expect(timer.fireNext()).toBe(1500);
    expect(engine.clearOverride).toHaveBeenCalledWith('heartRate');
  });

  it('applies steps in time order, keeping the written order within the same time', () => {
    const order = [];
    engine.setOverride.mockImplementation((sensor, value) => order.push(value));
    runner.run({
      id: 'a',
      steps: [set(100, 'heartRate', 3), set(0, 'heartRate', 1), set(0, 'heartRate', 2)],
    });
    timer.fireNext();
    expect(order).toEqual([1, 2, 3]);
  });

  it('runs all the steps sharing a time in a single timer', () => {
    runner.run({ id: 'a', steps: [set(100, 'heartRate', 1), set(100, 'battery', { level: 5 })] });
    timer.fireNext();
    expect(engine.setOverride).toHaveBeenCalledTimes(2);
    expect(timer.pending.size).toBe(0);
  });

  it('does not change the scenario it was given', () => {
    const steps = [set(100, 'heartRate', 2), set(0, 'heartRate', 1)];
    runner.run({ id: 'a', steps });
    expect(steps.map(({ atMs }) => atMs)).toEqual([100, 0]);
  });
});

describe('events', () => {
  it('reports the start, each applied step and the end, in that order', () => {
    const events = [];
    const scenario = { id: 'a', steps: [set(0, 'heartRate', 1), clear(10, 'heartRate')] };
    runner.onStart(() => events.push('start'));
    runner.onStep(({ step }) => events.push(`step ${step.atMs}`));
    runner.onEnd(() => events.push('end'));

    runner.run(scenario);
    expect(events).toEqual(['start', 'step 0']);

    timer.fireNext();
    expect(events).toEqual(['start', 'step 0', 'step 10', 'end']);
  });

  it('gives the scenario to listeners, and tells a finished one from a stopped one', () => {
    const ended = vi.fn();
    runner.onEnd(ended);
    const finished = { id: 'finished', steps: [set(0, 'heartRate', 1)] };
    const stopped = { id: 'stopped', steps: [set(10, 'heartRate', 1)] };

    runner.run(finished);
    expect(ended).toHaveBeenLastCalledWith({ scenario: finished, completed: true });

    runner.run(stopped);
    runner.stop();
    expect(ended).toHaveBeenLastCalledWith({ scenario: stopped, completed: false });
  });

  it('lets a listener unsubscribe', () => {
    const listener = vi.fn();
    const unsubscribe = runner.onStep(listener);
    unsubscribe();
    runner.run({ id: 'a', steps: [set(0, 'heartRate', 1)] });
    expect(listener).not.toHaveBeenCalled();
  });
});

describe('isRunning', () => {
  it('is true only while steps remain', () => {
    expect(runner.isRunning()).toBe(false);
    runner.run({ id: 'a', steps: [set(0, 'heartRate', 1), clear(10, 'heartRate')] });
    expect(runner.isRunning()).toBe(true);
    expect(runner.getCurrent().id).toBe('a');

    timer.fireNext();
    expect(runner.isRunning()).toBe(false);
    expect(runner.getCurrent()).toBeNull();
  });

  it('is already false inside the end listener', () => {
    let runningAtEnd = null;
    runner.onEnd(() => {
      runningAtEnd = runner.isRunning();
    });
    runner.run({ id: 'a', steps: [set(0, 'heartRate', 1)] });
    expect(runningAtEnd).toBe(false);
  });

  it('ends at once for a scenario without steps', () => {
    const ended = vi.fn();
    runner.onEnd(ended);
    runner.run({ id: 'a', steps: [] });
    expect(ended).toHaveBeenCalledTimes(1);
    expect(runner.isRunning()).toBe(false);
  });
});

describe('leftover overrides', () => {
  it('keeps what a scenario left set when it ends by itself', () => {
    runner.run({ id: 'a', steps: [set(0, 'battery', { level: 15 })] });
    expect(engine.clearOverride).not.toHaveBeenCalled();
  });

  it('clears what a stopped scenario had set, but nothing it had not reached', () => {
    runner.run({
      id: 'a',
      steps: [set(0, 'accelerometer', {}), set(10, 'heartRate', 1)],
    });
    runner.stop();

    expect(engine.clearOverride.mock.calls).toEqual([['accelerometer']]);
  });

  it('does not clear twice what the scenario already cleared', () => {
    runner.run({
      id: 'a',
      steps: [set(0, 'accelerometer', {}), clear(10, 'accelerometer'), set(20, 'heartRate', 1)],
    });
    timer.fireNext();
    engine.clearOverride.mockClear();

    runner.stop();
    expect(engine.clearOverride).not.toHaveBeenCalled();
  });
});

describe('stop', () => {
  it('drops the pending steps', () => {
    runner.run({ id: 'a', steps: [set(10, 'heartRate', 1)] });
    expect(timer.pending.size).toBe(1);

    runner.stop();
    expect(timer.pending.size).toBe(0);
    expect(runner.isRunning()).toBe(false);
    expect(engine.setOverride).not.toHaveBeenCalled();
  });

  it('does nothing when no scenario is running', () => {
    const ended = vi.fn();
    runner.onEnd(ended);
    runner.stop();
    expect(ended).not.toHaveBeenCalled();
  });

  it('can be called from a step listener, which skips the remaining steps', () => {
    runner.onStep(() => runner.stop());
    runner.run({ id: 'a', steps: [set(0, 'heartRate', 1), set(0, 'heartRate', 2)] });

    expect(engine.setOverride).toHaveBeenCalledTimes(1);
    expect(runner.isRunning()).toBe(false);
  });
});

describe('one scenario at a time', () => {
  it('replaces the running scenario, which ends first and leaves no pending steps', () => {
    const events = [];
    runner.onEnd(({ scenario, completed }) => events.push(`end ${scenario.id} ${completed}`));
    runner.onStart(({ scenario }) => events.push(`start ${scenario.id}`));

    runner.run({ id: 'a', steps: [set(0, 'accelerometer', {}), set(10, 'heartRate', 1)] });
    runner.run({ id: 'b', steps: [set(10, 'battery', { level: 5 })] });

    expect(events).toEqual(['start a', 'end a false', 'start b']);
    expect(engine.clearOverride).toHaveBeenCalledWith('accelerometer');
    expect(runner.getCurrent().id).toBe('b');
    expect(timer.pending.size).toBe(1);

    timer.fireNext();
    expect(engine.setOverride).toHaveBeenLastCalledWith('battery', { level: 5 });
    expect(engine.setOverride).not.toHaveBeenCalledWith('heartRate', 1);
  });

  it('can run another scenario from an end listener', () => {
    const next = { id: 'next', steps: [set(10, 'heartRate', 1)] };
    const unsubscribe = runner.onEnd(() => {
      unsubscribe();
      runner.run(next);
    });
    runner.run({ id: 'first', steps: [] });

    expect(runner.getCurrent()).toBe(next);
  });
});

describe('timing', () => {
  it('uses real timers by default', () => {
    vi.useFakeTimers();
    try {
      const realTimeRunner = createScenarioRunner({ engine });
      realTimeRunner.run({ id: 'a', steps: [set(500, 'heartRate', 1)] });

      vi.advanceTimersByTime(499);
      expect(engine.setOverride).not.toHaveBeenCalled();
      vi.advanceTimersByTime(1);
      expect(engine.setOverride).toHaveBeenCalledTimes(1);
    } finally {
      vi.useRealTimers();
    }
  });
});
