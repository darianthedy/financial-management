import { format, parse, addMonths, subMonths, getDaysInMonth, getDate, endOfMonth, isValid } from "date-fns";

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
  // Guard against empty/partial input: a native date input reports "" while a
  // segment is mid-edit, which parses to an Invalid Date that format() throws on.
  const date = parse(yearMonth, "yyyy-MM", new Date());
  return isValid(date) ? format(date, "MMMM yyyy") : "";
}

export function yearMonthOf(isoDate: string): string {
  // isoDate is a DATE string like "2026-06-03"
  return isoDate.slice(0, 7);
}

/** Abbreviated month label for a 'YYYY-MM', e.g. "Jul" (for compact axes). */
export function formatYearMonthShort(yearMonth: string): string {
  const date = parse(yearMonth, "yyyy-MM", new Date());
  return isValid(date) ? format(date, "MMM") : "";
}

export function formatDate(isoDate: string): string {
  // Same guard as formatYearMonth: an incomplete/typed date can parse to an
  // Invalid Date, which format() throws on.
  const date = parse(isoDate, "yyyy-MM-dd", new Date());
  return isValid(date) ? format(date, "MMM d, yyyy") : "";
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
 * Inclusive ISO date bounds for a month, suited to the transactions list's
 * `from`/`to` date filter (which matches the `date` column with gte/lte). The
 * end is the month's LAST day — not the next month's first — so the month
 * window derived from `to` (`to.slice(0, 7)`, used to scope the budget /
 * fixed-expense facets) stays within this month.
 */
export function monthDateBounds(yearMonth: string): { from: string; to: string } {
  const date = parse(yearMonth, "yyyy-MM", new Date());
  return {
    from: `${yearMonth}-01`,
    to: format(endOfMonth(date), "yyyy-MM-dd"),
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
