import { telemetryConfig } from '../../config/telemetry.config.js';
import { clamp, randomOffset, roundTo } from '../math.js';

const COORDINATE_DECIMALS = 6;

function drift(current, base, { drift: step, maxDrift }, random) {
  const moved = clamp(current + randomOffset(random, step), base - maxDrift, base + maxDrift);
  return roundTo(moved, COORDINATE_DECIMALS);
}

export function nextGps(current, { config = telemetryConfig.gps, random = Math.random } = {}) {
  const { baseLat, baseLng, accuracyMin, accuracyMax } = config;
  return {
    lat: drift(current.lat, baseLat, config, random),
    lng: drift(current.lng, baseLng, config, random),
    accuracy: roundTo(accuracyMin + random() * (accuracyMax - accuracyMin), 1),
    signal: true,
  };
}
