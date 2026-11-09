import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createLongPress } from '../src/core/longPress.js';

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('createLongPress', () => {
  it('completes once the duration has passed, not before', () => {
    const onComplete = vi.fn();
    const press = createLongPress({ durationMs: 2000, onComplete });

    press.start();
    expect(press.isActive()).toBe(true);
    vi.advanceTimersByTime(1999);
    expect(onComplete).not.toHaveBeenCalled();

    vi.advanceTimersByTime(1);
    expect(onComplete).toHaveBeenCalledTimes(1);
    expect(press.isActive()).toBe(false);
  });

  it('does not complete when cancelled early', () => {
    const onComplete = vi.fn();
    const press = createLongPress({ durationMs: 2000, onComplete });

    press.start();
    vi.advanceTimersByTime(1000);
    press.cancel();
    vi.advanceTimersByTime(5000);

    expect(onComplete).not.toHaveBeenCalled();
    expect(press.isActive()).toBe(false);
  });

  it('does not restart the countdown when started again', () => {
    const onComplete = vi.fn();
    const press = createLongPress({ durationMs: 2000, onComplete });

    press.start();
    vi.advanceTimersByTime(1500);
    press.start();
    vi.advanceTimersByTime(500);

    expect(onComplete).toHaveBeenCalledTimes(1);
  });

  it('starts over after a cancel', () => {
    const onComplete = vi.fn();
    const press = createLongPress({ durationMs: 2000, onComplete });

    press.start();
    vi.advanceTimersByTime(1500);
    press.cancel();
    press.start();
    vi.advanceTimersByTime(1999);
    expect(onComplete).not.toHaveBeenCalled();

    vi.advanceTimersByTime(1);
    expect(onComplete).toHaveBeenCalledTimes(1);
  });

  it('can be cancelled when idle', () => {
    const press = createLongPress({ durationMs: 2000, onComplete: () => {} });
    expect(() => press.cancel()).not.toThrow();
  });
});
