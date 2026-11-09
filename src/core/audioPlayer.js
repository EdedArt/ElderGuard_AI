function createBrowserAudioContext() {
  const AudioContextClass = globalThis.AudioContext ?? globalThis.webkitAudioContext;
  return AudioContextClass ? new AudioContextClass() : null;
}

// Sound is a helpful extra, never a requirement: without it, every call quietly does nothing.
export function createAudioPlayer({ createContext = createBrowserAudioContext } = {}) {
  let context = null;

  return {
    // Browsers only allow audio after a user gesture, so call this from one.
    unlock() {
      try {
        context ??= createContext();
        context?.resume()?.catch(() => {});
      } catch {
        context = null;
      }
    },

    isUnlocked: () => context !== null,
  };
}
