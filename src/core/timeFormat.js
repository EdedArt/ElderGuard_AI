// HH:MM in 24-hour format, with two-digit hours in every language.
export function formatTime(date, language) {
  return new Intl.DateTimeFormat(language, {
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(date);
}

// Short weekday, day and month, for example "dom, 8 nov" or "Sun, Nov 8".
export function formatShortDate(date, language) {
  return new Intl.DateTimeFormat(language, {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  }).format(date);
}
