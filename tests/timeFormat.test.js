import { describe, expect, it } from 'vitest';
import { formatShortDate, formatTime } from '../src/core/timeFormat.js';

// Sunday, November 8, 2026, in the local time zone.
const afternoon = new Date(2026, 10, 8, 14, 5);
const morning = new Date(2026, 10, 8, 7, 9);
const midnight = new Date(2026, 10, 8, 0, 0);

describe('formatTime', () => {
  it('uses 24-hour HH:MM in Spanish', () => {
    expect(formatTime(afternoon, 'es')).toBe('14:05');
    expect(formatTime(morning, 'es')).toBe('07:09');
  });

  it('uses HH:MM in English too', () => {
    expect(formatTime(afternoon, 'en')).toBe('14:05');
    expect(formatTime(morning, 'en')).toBe('07:09');
  });

  it('shows midnight as 00:00, never 24:00', () => {
    expect(formatTime(midnight, 'es')).toBe('00:00');
    expect(formatTime(midnight, 'en')).toBe('00:00');
  });
});

describe('formatShortDate', () => {
  it('uses Spanish weekday and month names', () => {
    const date = formatShortDate(afternoon, 'es');
    expect(date).toContain('dom');
    expect(date).toContain('8');
    expect(date).toContain('nov');
  });

  it('uses English weekday and month names', () => {
    const date = formatShortDate(afternoon, 'en');
    expect(date).toContain('Sun');
    expect(date).toContain('8');
    expect(date).toContain('Nov');
  });
});
