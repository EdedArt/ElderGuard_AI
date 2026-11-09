import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createCountdown } from '../src/core/countdown.js';

// A hand-driven timer, to show that the countdown does not depend on the browser clock.
function createManualTimer() {
  const callbacks = new Map();
  let nextId = 1;
  return {
    start(callback) {
      callbacks.set(nextId, callback);
      nextId += 1;
      return nextId - 1;
    },
    stop: (id) => callbacks.delete(id),
    fire: () => [...callbacks.values()].forEach((callback) => callback()),
    active: () => callbacks.size,
  };
}

let timer;
let countdown;
let ticks;
let complete;

beforeEach(() => {
  timer = createManualTimer();
  countdown = createCountdown({ timer });
  ticks = [];
  complete = vi.fn();
  countdown.onTick((remaining) => ticks.push(remaining));
  countdown.onComplete(complete);
});

describe('start', () => {
  it('is not running until started', () => {
    expect(countdown.isRunning()).toBe(false);
    expect(ticks).toEqual([]);
  });

  it('reports the starting value right away', () => {
    countdown.start(3);
    expect(ticks).toEqual([3]);
    expect(countdown.isRunning()).toBe(true);
  });

  it('counts down to 0 and then completes once', () => {
    countdown.start(3);
    timer.fire();
    timer.fire();
    expect(complete).not.toHaveBeenCalled();

    timer.fire();
    expect(ticks).toEqual([3, 2, 1, 0]);
    expect(complete).toHaveBeenCalledTimes(1);
    expect(countdown.isRunning()).toBe(false);
    expect(timer.active()).toBe(0);
  });

  it('ignores a second start while running', () => {
    countdown.start(3);
    timer.fire();
    countdown.start(10);

    expect(ticks).toEqual([3, 2]);
    expect(timer.active()).toBe(1);
  });

  it('can start again after completing', () => {
    countdown.start(1);
    timer.fire();
    countdown.start(1);
    timer.fire();
    expect(complete).toHaveBeenCalledTimes(2);
  });

  it('completes right away from 0', () => {
    countdown.start(0);
    expect(ticks).toEqual([0]);
    expect(complete).toHaveBeenCalledTimes(1);
    expect(timer.active()).toBe(0);
  });
});

describe('cancel', () => {
  it('stops the ticks and never completes', () => {
    countdown.start(3);
    timer.fire();
    countdown.cancel();
    timer.fire();

    expect(ticks).toEqual([3, 2]);
    expect(complete).not.toHaveBeenCalled();
    expect(countdown.isRunning()).toBe(false);
    expect(timer.active()).toBe(0);
  });

  it('does nothing when not running', () => {
    expect(() => countdown.cancel()).not.toThrow();
  });

  it('allows a new start from the full value', () => {
    countdown.start(3);
    timer.fire();
    countdown.cancel();
    ticks.length = 0;

    countdown.start(3);
    expect(ticks).toEqual([3]);
  });

  it('prevents completion when cancelled from the last tick', () => {
    countdown.onTick((remaining) => {
      if (remaining === 0) countdown.cancel();
    });
    countdown.start(1);
    timer.fire();
    expect(complete).not.toHaveBeenCalled();
  });
});

describe('listeners', () => {
  it('can be removed', () => {
    const tick = vi.fn();
    const stop = vi.fn();
    countdown.onTick(tick)();
    countdown.onComplete(stop)();

    countdown.start(0);

    expect(tick).not.toHaveBeenCalled();
    expect(stop).not.toHaveBeenCalled();
  });
});

describe('with the default browser timer', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('ticks once per second', () => {
    const real = createCountdown();
    const seen = [];
    real.onTick((remaining) => seen.push(remaining));

    real.start(2);
    vi.advanceTimersByTime(999);
    expect(seen).toEqual([2]);

    vi.advanceTimersByTime(1);
    expect(seen).toEqual([2, 1]);

    vi.advanceTimersByTime(5000);
    expect(seen).toEqual([2, 1, 0]);
  });
});
