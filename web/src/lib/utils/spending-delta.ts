import type { SpendingByCategory } from "@/lib/types/database";

export interface SpendingDelta {
  category_id: string;
  category_name: string;
  icon: string | null;
  color: string | null;
  /** This month's spend for the category (0 if it had none). */
  current: number;
  /** Last month's spend for the category (0 if it had none). */
  previous: number;
  /** current − previous. Positive = spent more than last month. */
  delta: number;
  /** Percent change vs last month, or null when there's no prior basis. */
  deltaPct: number | null;
  /** Category appeared this month but had no spend last month. */
  isNew: boolean;
}

/**
 * Join this month's and last month's spending-by-category over the UNION of
 * categories so a category present in only one month is still represented
 * (its missing side counts as 0). Sorted by biggest absolute increase first,
 * which is exactly the order the "biggest movers" card wants.
 */
export function computeSpendingDeltas(
  current: SpendingByCategory[],
  previous: SpendingByCategory[],
): SpendingDelta[] {
  const curById = new Map(current.map((c) => [c.category_id, c]));
  const prevById = new Map(previous.map((p) => [p.category_id, p]));
  const ids = new Set([...curById.keys(), ...prevById.keys()]);

  const deltas: SpendingDelta[] = [];
  for (const id of ids) {
    const cur = curById.get(id);
    const prev = prevById.get(id);
    // At least one side exists (id came from the union), so meta is defined.
    const meta = (cur ?? prev)!;
    const currentAmount = cur?.total_amount ?? 0;
    const previousAmount = prev?.total_amount ?? 0;
    deltas.push({
      category_id: id,
      category_name: meta.category_name,
      icon: meta.icon,
      color: meta.color,
      current: currentAmount,
      previous: previousAmount,
      delta: currentAmount - previousAmount,
      deltaPct:
        previousAmount > 0
          ? ((currentAmount - previousAmount) / previousAmount) * 100
          : null,
      isNew: previousAmount === 0 && currentAmount > 0,
    });
  }
  return deltas.sort((a, b) => b.delta - a.delta);
}
