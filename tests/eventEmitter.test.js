import { describe, expect, it, vi } from 'vitest';
import { createEventEmitter } from '../src/core/eventEmitter.js';

describe('createEventEmitter', () => {
  it('passes all emitted arguments to listeners of that event only', () => {
    const emitter = createEventEmitter();
    const listener = vi.fn();
    const other = vi.fn();
    emitter.on('a', listener);
    emitter.on('b', other);

    emitter.emit('a', 1, 'two');

    expect(listener).toHaveBeenCalledWith(1, 'two');
    expect(other).not.toHaveBeenCalled();
  });

  it('does nothing when emitting an event without listeners', () => {
    expect(() => createEventEmitter().emit('nothing')).not.toThrow();
  });

  it('stops calling a listener after its unsubscribe function runs', () => {
    const emitter = createEventEmitter();
    const listener = vi.fn();
    const unsubscribe = emitter.on('a', listener);

    unsubscribe();
    emitter.emit('a');

    expect(listener).not.toHaveBeenCalled();
    expect(unsubscribe).not.toThrow();
  });

  it('stops calling a listener after off', () => {
    const emitter = createEventEmitter();
    const listener = vi.fn();
    emitter.on('a', listener);

    emitter.off('a', listener);
    emitter.emit('a');

    expect(listener).not.toHaveBeenCalled();
    expect(() => emitter.off('unknown', listener)).not.toThrow();
  });

  it('calls a once listener a single time', () => {
    const emitter = createEventEmitter();
    const listener = vi.fn();
    emitter.once('a', listener);

    emitter.emit('a', 1);
    emitter.emit('a', 2);

    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener).toHaveBeenCalledWith(1);
  });

  it('lets a once listener be cancelled with off or its unsubscribe function', () => {
    const emitter = createEventEmitter();
    const viaOff = vi.fn();
    const viaUnsubscribe = vi.fn();
    emitter.once('a', viaOff);
    const unsubscribe = emitter.once('a', viaUnsubscribe);

    emitter.off('a', viaOff);
    unsubscribe();
    emitter.emit('a');

    expect(viaOff).not.toHaveBeenCalled();
    expect(viaUnsubscribe).not.toHaveBeenCalled();
  });

  it('keeps the remaining listeners running when one unsubscribes during emit', () => {
    const emitter = createEventEmitter();
    const second = vi.fn();
    const unsubscribe = emitter.on('a', () => unsubscribe());
    emitter.on('a', second);

    emitter.emit('a');

    expect(second).toHaveBeenCalledTimes(1);
  });

  it('does not call a listener added during emit until the next emit', () => {
    const emitter = createEventEmitter();
    const late = vi.fn();
    emitter.once('a', () => emitter.on('a', late));

    emitter.emit('a');
    expect(late).not.toHaveBeenCalled();

    emitter.emit('a');
    expect(late).toHaveBeenCalledTimes(1);
  });
});
