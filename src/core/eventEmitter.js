export function createEventEmitter() {
  const listeners = new Map();

  // Entries are replaced, never mutated, so an emit in progress keeps a stable list.
  const add = (event, entry) => {
    listeners.set(event, [...(listeners.get(event) ?? []), entry]);
    return () => remove(event, entry);
  };

  const remove = (event, entry) => {
    const remaining = (listeners.get(event) ?? []).filter((candidate) => candidate !== entry);
    if (remaining.length > 0) listeners.set(event, remaining);
    else listeners.delete(event);
  };

  return {
    on(event, listener) {
      return add(event, { listener, once: false });
    },

    once(event, listener) {
      return add(event, { listener, once: true });
    },

    off(event, listener) {
      const entry = listeners.get(event)?.find((candidate) => candidate.listener === listener);
      if (entry) remove(event, entry);
    },

    emit(event, ...args) {
      for (const entry of listeners.get(event) ?? []) {
        if (entry.once) remove(event, entry);
        entry.listener(...args);
      }
    },
  };
}
