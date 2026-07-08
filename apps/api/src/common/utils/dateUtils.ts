export function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

export function format(date: Date, fmt: string): string {
  // Simple ISO-like format
  const pad = (n: number) => n.toString().padStart(2, '0');
  return fmt
    .replace('YYYY', date.getFullYear().toString())
    .replace('MM', pad(date.getMonth() + 1))
    .replace('DD', pad(date.getDate()))
    .replace('HH', pad(date.getHours()))
    .replace('mm', pad(date.getMinutes()));
}

export function parseISO(dateStr: string): Date {
  return new Date(dateStr);
}

export function isAfter(date: Date, dateToCompare: Date): boolean {
  return date > dateToCompare;
}

export function isBefore(date: Date, dateToCompare: Date): boolean {
  return date < dateToCompare;
}

export function eachMinuteOfInterval(
  interval: { start: Date; end: Date },
  options?: { step?: number },
): Date[] {
  const step = options?.step ?? 1;
  const result: Date[] = [];
  let current = new Date(interval.start);
  while (current <= interval.end) {
    result.push(new Date(current));
    current = addMinutes(current, step);
  }
  return result;
}

export function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

export function endOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}
