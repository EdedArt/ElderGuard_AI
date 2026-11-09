// Vibration is a helpful extra: most computers and some phones do not support it.
export function vibrate(pattern) {
  if (typeof navigator.vibrate === 'function') navigator.vibrate(pattern);
}
