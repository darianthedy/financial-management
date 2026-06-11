import { format, parse, addMonths, subMonths, getDaysInMonth, getDate } from "date-fns";

export function getCurrentYearMonth(): string {
  return format(new Date(), "yyyy-MM");
}

export function navigateMonth(yearMonth: string, offset: number): string {
  const date = parse(yearMonth, "yyyy-MM", new Date());
  const target =
    offset > 0 ? addMonths(date, offset) : subMonths(date, Math.abs(offset));
  return format(target, "yyyy-MM");
}

export function formatYearMonth(yearMonth: string): string {
  const date = parse(yearMonth, "yyyy-MM", new Date());
  return format(date, "MMMM yyyy");
}

export function yearMonthOf(isoDate: string): string {
  // isoDate is a DATE string like "2026-06-03"
  return isoDate.slice(0, 7);
}

export function formatDate(isoDate: string): string {
  const date = parse(isoDate, "yyyy-MM-dd", new Date());
  return format(date, "MMM d, yyyy");
}

export function todayIso(): string {
  return format(new Date(), "yyyy-MM-dd");
}

export function isCurrentYearMonth(yearMonth: string): boolean {
  return yearMonth === getCurrentYearMonth();
}

/**
 * Inclusive start / exclusive end ISO dates for a month, for range-filtering the
 * transactions table by its `date` column. `date` is 'YYYY-MM-DD' so lexical
 * gte/lt bounds work; endExclusive is the first day of the next month.
 */
export function monthDateRange(yearMonth: string): {
  start: string;
  endExclusive: string;
} {
  return {
    start: `${yearMonth}-01`,
    endExclusive: `${navigateMonth(yearMonth, 1)}-01`,
  };
}

/**
 * Fraction of the given month elapsed as of today, in (0, 1].
 * - Current month: today's day-of-month ÷ days in month.
 * - Past (completed) months: 1 (fully elapsed).
 * - Future months: 0 (not started).
 * Callers projecting from this must still guard against a 0 return early on.
 */
export function monthElapsedFraction(yearMonth: string): number {
  const current = getCurrentYearMonth();
  if (yearMonth === current) {
    const date = parse(yearMonth, "yyyy-MM", new Date());
    return getDate(new Date()) / getDaysInMonth(date);
  }
  return yearMonth < current ? 1 : 0;
}
