import { telemetryConfig } from '../../config/telemetry.config.js';
import { clamp, randomOffset, roundTo } from '../math.js';

export function nextHeartRate(
  current,
  { config = telemetryConfig.heartRate, random = Math.random } = {},
) {
  const { restingMin, restingMax, noise } = config;
  const step = roundTo(randomOffset(random, noise), 0);
  return clamp(current + step, restingMin, restingMax);
}
