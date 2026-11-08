import { telemetryConfig } from '../../config/telemetry.config.js';
import { randomOffset, roundTo } from '../math.js';

export function nextAccelerometer({
  config = telemetryConfig.accelerometer,
  random = Math.random,
} = {}) {
  const { rest, noise } = config;
  return {
    x: roundTo(rest.x + randomOffset(random, noise), 2),
    y: roundTo(rest.y + randomOffset(random, noise), 2),
    z: roundTo(rest.z + randomOffset(random, noise), 2),
  };
}

export function accelerometerMagnitude({ x, y, z }) {
  return Math.hypot(x, y, z);
}
