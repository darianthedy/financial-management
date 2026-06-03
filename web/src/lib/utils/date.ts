import { format, parse, addMonths, subMonths } from "date-fns";

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
