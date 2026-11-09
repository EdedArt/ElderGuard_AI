// Disables the watchface behind overlays. Several overlays share the same background, so it stays
// disabled until the last one lets go, whatever order they open and close in.
export function createBackgroundLock(elements) {
  const holders = new Set();

  return {
    set(holder, held) {
      if (held) holders.add(holder);
      else holders.delete(holder);
      for (const element of elements) element.toggleAttribute('inert', holders.size > 0);
    },
  };
}
