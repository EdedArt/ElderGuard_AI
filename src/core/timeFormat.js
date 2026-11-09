// 12-hour time in every language. The period is a key, so its label comes from the dictionaries.
export function formatTime(date) {
  const hours = date.getHours();
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return { time: `${hours % 12 || 12}:${minutes}`, period: hours < 12 ? 'am' : 'pm' };
}

// Short weekday, day and month, for example "dom, 8 nov" or "Sun, Nov 8".
export function formatShortDate(date, language) {
  return new Intl.DateTimeFormat(language, {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  }).format(date);
}
