import { describe, expect, it } from 'vitest';
import { formatShortDate, formatTime } from '../src/core/timeFormat.js';

// Sunday, November 8, 2026, in the local time zone.
const afternoon = new Date(2026, 10, 8, 14, 5);
const morning = new Date(2026, 10, 8, 7, 9);
const midnight = new Date(2026, 10, 8, 0, 0);
const noon = new Date(2026, 10, 8, 12, 0);

describe('formatTime', () => {
  it('uses a 12-hour clock without a leading zero', () => {
    expect(formatTime(afternoon)).toEqual({ time: '2:05', period: 'pm' });
    expect(formatTime(morning)).toEqual({ time: '7:09', period: 'am' });
  });

  it('shows midnight as 12:00 am, never 0:00', () => {
    expect(formatTime(midnight)).toEqual({ time: '12:00', period: 'am' });
  });

  it('shows noon as 12:00 pm', () => {
    expect(formatTime(noon)).toEqual({ time: '12:00', period: 'pm' });
  });

  it('switches period at the last minute of the morning and of the day', () => {
    expect(formatTime(new Date(2026, 10, 8, 11, 59)).period).toBe('am');
    expect(formatTime(new Date(2026, 10, 8, 23, 59))).toEqual({ time: '11:59', period: 'pm' });
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
