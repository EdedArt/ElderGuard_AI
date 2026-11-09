import { telemetryConfig } from '../config/telemetry.config.js';

const MS_PER_MINUTE = 60000;

// Time between heartbeats, or 0 when there is no valid heart rate to animate.
export function heartbeatIntervalMs(bpm) {
  return Number.isFinite(bpm) && bpm > 0 ? Math.round(MS_PER_MINUTE / bpm) : 0;
}

export function batteryPercent(level) {
  return Math.round(level);
}

export function batteryState(level, config = telemetryConfig.battery) {
  if (level <= config.criticalLevel) return 'critical';
  if (level <= config.lowLevel) return 'low';
  return 'normal';
}

export function gpsState(gps) {
  return gps.signal ? 'ok' : 'lost';
}

// The status changes worth announcing between two states, never routine readings.
export function statusChanges(previous, next) {
  const changes = [];

  const previousBattery = batteryState(batteryPercent(previous.battery.level));
  const nextBattery = batteryState(batteryPercent(next.battery.level));
  if (nextBattery !== previousBattery) {
    if (nextBattery === 'low') changes.push('batteryLow');
    if (nextBattery === 'critical') changes.push('batteryCritical');
  }

  const previousGps = gpsState(previous.gps);
  const nextGps = gpsState(next.gps);
  if (nextGps !== previousGps) changes.push(nextGps === 'lost' ? 'gpsLost' : 'gpsRestored');

  return changes;
}
