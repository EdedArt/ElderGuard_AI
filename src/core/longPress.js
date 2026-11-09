export function createLongPress({ durationMs, onComplete }) {
  let timer = null;

  return {
    start() {
      if (timer !== null) return;
      timer = setTimeout(() => {
        timer = null;
        onComplete();
      }, durationMs);
    },

    cancel() {
      clearTimeout(timer);
      timer = null;
    },

    isActive: () => timer !== null,
  };
}
