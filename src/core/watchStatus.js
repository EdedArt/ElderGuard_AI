const MS_PER_MINUTE = 60000;

// Time between heartbeats, or 0 when there is no valid heart rate to animate.
export function heartbeatIntervalMs(bpm) {
  return Number.isFinite(bpm) && bpm > 0 ? Math.round(MS_PER_MINUTE / bpm) : 0;
}
