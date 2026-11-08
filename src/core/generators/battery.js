import { telemetryConfig } from '../../config/telemetry.config.js';
import { roundTo } from '../math.js';

// Rounding keeps repeated subtraction from accumulating floating point error.
const LEVEL_DECIMALS = 4;

export function nextBattery(current, { config = telemetryConfig.battery } = {}) {
  return {
    level: Math.max(0, roundTo(current.level - config.drainPerTick, LEVEL_DECIMALS)),
    charging: false,
  };
}
